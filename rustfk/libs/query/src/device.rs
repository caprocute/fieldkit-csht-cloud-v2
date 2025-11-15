use anyhow::Result;
use prost::Message;
use reqwest::header::HeaderMap;
use reqwest::RequestBuilder;
use serde::Deserialize;
use std::num::NonZeroU32;
use std::path::PathBuf;
use std::time::{Duration, UNIX_EPOCH};
use std::{io::Cursor, time::SystemTime};
use thiserror::Error;
use tokio::sync::mpsc::UnboundedSender;
use tokio_stream::{Stream, StreamExt};
use tokio_util::io::ReaderStream;
use tracing::*;

pub use protos::http::*;

use crate::BytesUploaded;

pub struct Client {
    client: reqwest::Client,
}

#[derive(Debug, Error)]
pub enum UpgradeError {
    #[error("Server error")]
    Server,
    #[error("Unknown error")]
    Other,
    #[error("SD card missing error")]
    SdCardMissing,
    #[error("SD card IO error")]
    SdCardIo,
    #[error("IO error")]
    Io(#[from] std::io::Error),
}

#[derive(Debug, Deserialize)]
#[allow(dead_code)]
pub struct UpgradeBody {
    #[serde(rename = "sdCard")]
    sd_card: Option<bool>,
    incomplete: Option<bool>,
    length: Option<bool>,
    unlink: Option<bool>,
    create: Option<bool>,
    success: Option<bool>,
    hash: Option<String>,
}

impl From<UpgradeBody> for UpgradeError {
    fn from(value: UpgradeBody) -> Self {
        if Some(true) == value.sd_card {
            UpgradeError::SdCardMissing
        } else if Some(true) == value.create {
            UpgradeError::SdCardIo
        } else if Some(true) == value.unlink {
            UpgradeError::SdCardIo
        } else {
            UpgradeError::Server
        }
    }
}

#[derive(Debug)]
pub enum SimpleSchedule {
    Every(Duration),
}

#[derive(Debug, Error)]
pub enum ScheduleError {
    #[error("Unsupported: {0}")]
    Unsupported(String),
}

impl TryFrom<protos::http::Schedule> for SimpleSchedule {
    type Error = ScheduleError;

    fn try_from(value: protos::http::Schedule) -> Result<Self, Self::Error> {
        if value.interval > 0 {
            Ok(Self::Every(Duration::from_secs(value.interval as u64)))
        } else {
            Err(ScheduleError::Unsupported(format!(
                "Unsupported schedule: {:?}",
                value,
            )))
        }
    }
}

impl Into<protos::http::Schedule> for SimpleSchedule {
    fn into(self) -> protos::http::Schedule {
        match self {
            SimpleSchedule::Every(duration) => protos::http::Schedule {
                interval: duration.as_secs() as u32,
                duration: 0,
                repeated: 0,
                jitter: 0,
                intervals: Vec::default(),
                cron: Vec::default(),
            },
        }
    }
}

#[derive(Debug, Default)]
pub struct ConfigureWifiTransmission {
    pub enabled: bool,
    pub token: Option<String>,
    pub url: Option<String>,
    pub schedule: Option<SimpleSchedule>,
}

impl Into<HttpQuery> for ConfigureWifiTransmission {
    fn into(self) -> HttpQuery {
        let wifi_transmission = WifiTransmission {
            modifying: true,
            url: self.url.unwrap_or_else(|| "".to_owned()),
            token: self.token.unwrap_or_else(|| "".to_owned()),
            enabled: self.enabled,
        };

        let mut query = HttpQuery::default();
        query.r#type = QueryType::QueryConfigure as i32;
        query.transmission = Some(Transmission {
            wifi: Some(wifi_transmission),
        });

        if let Some(schedule) = self.schedule {
            query.schedules = Some(Schedules {
                modifying: true,
                readings: None,
                lora: None,
                network: Some(schedule.into()),
                gps: None,
            })
        }

        query
    }
}

#[derive(Debug)]
pub struct WifiNetwork {
    pub ssid: Option<String>,
    pub password: Option<String>,
    pub default: bool,
    pub keeping: bool,
}

impl Into<protos::http::NetworkInfo> for WifiNetwork {
    fn into(self) -> protos::http::NetworkInfo {
        protos::http::NetworkInfo {
            ssid: self.ssid.unwrap_or_else(|| "".to_owned()),
            password: self.password.unwrap_or_else(|| "".to_owned()),
            keeping: self.keeping,
            preferred: self.default,
            create: false,
        }
    }
}

#[derive(Debug, Default)]
pub struct ConfigureWifiNetworks {
    pub networks: Vec<WifiNetwork>,
}

impl Into<HttpQuery> for ConfigureWifiNetworks {
    fn into(self) -> HttpQuery {
        let mut query = HttpQuery::default();
        query.r#type = QueryType::QueryConfigure as i32;
        query.network_settings = Some(NetworkSettings {
            connected: None,
            modifying: true,
            create_access_point: 0, // TODO Make optional via new parent type.
            mac_address: "".to_owned(), // TODO Make optional via new parent type.
            supports_udp: true,     // TODO Make optional via new parent type.
            networks: self.networks.into_iter().map(|n| n.into()).collect(),
        });

        query
    }
}

#[derive(Debug, Default)]
pub struct ConfigureLoraTransmission {
    pub enabled: bool,
    pub verify: bool,
    pub app_key: Option<Vec<u8>>,
    pub join_eui: Option<Vec<u8>>,
    pub band: Option<u32>,
    pub schedule: Option<SimpleSchedule>,
}

impl Into<HttpQuery> for ConfigureLoraTransmission {
    fn into(self) -> HttpQuery {
        let mut query = HttpQuery::default();
        query.r#type = QueryType::QueryConfigure as i32;
        query.lora_settings = Some(LoraSettings {
            available: true,
            modifying: true,
            clearing: false,
            verify: self.verify,
            frequency_band: self.band.unwrap_or(915),
            device_eui: Vec::default(),
            app_key: self.app_key.unwrap_or_default(),
            join_eui: self.join_eui.unwrap_or_default(),
            device_address: Vec::default(),
            network_session_key: Vec::default(),
            app_session_key: Vec::default(),
        });

        if let Some(schedule) = self.schedule {
            query.schedules = Some(Schedules {
                modifying: true,
                readings: None,
                lora: Some(schedule.into()),
                network: None,
                gps: None,
            })
        }

        query
    }
}

fn unix_time() -> Option<u64> {
    let start = SystemTime::now();
    start.duration_since(UNIX_EPOCH).map(|d| d.as_secs()).ok()
}

#[derive(Clone)]
struct BaseProgress(u64, u64);

impl BaseProgress {
    fn uploaded(&self, bytes: u64) -> BytesUploaded {
        BytesUploaded {
            bytes_uploaded: bytes + self.0,
            total_bytes: self.1,
        }
    }
}

struct FileUpload {
    addr: String,
    path: PathBuf,
    limited: Option<NonZeroU32>,
    file: String,
    swap: bool,
    progress: BaseProgress,
}

impl FileUpload {
    async fn upload(
        &self,
        sender: UnboundedSender<Result<BytesUploaded, UpgradeError>>,
    ) -> Result<()> {
        let file = tokio::fs::File::open(&self.path).await?;
        let bytes = file.metadata().await?.len();
        let mut reader_stream = ReaderStream::new(file);

        use governor::{Quota, RateLimiter};

        let lim = self.limited.map(|l| {
            let quota = Quota::per_second(l);
            RateLimiter::direct(quota)
        });

        let url = format!("http://{}/fk/v1/upload/firmware", self.addr);
        let url = format!("{}?fn={}", url, self.file);
        let url = if self.swap {
            format!("{}&swap=1", url)
        } else {
            url
        };

        let progress = self.progress.clone();
        let copying = sender.clone();
        let async_stream = async_stream::stream! {
            let mut uploaded = 0;

            let _log_drop = LogDrop::default();

            loop {
                let chunk = reader_stream.next().await ;

                match chunk {
                    Some(chunk) => {
                        match &chunk {
                            Ok(chunk) => {
                                uploaded = std::cmp::min(uploaded + (chunk.len() as u64), bytes);
                                match copying.send(Ok(progress.uploaded(uploaded))) {
                                    Err(e) => error!("upload: error {:?}", e),
                                    Ok(_) => {},
                                }

                                info!("upload: chunk {} bytes", chunk.len());
                            }
                            Err(e) => {
                                error!("upload: error {:?}", e);
                                break;
                            },
                        }

                        if let Some(lim) = &lim {
                            lim.until_ready().await;
                        }

                        yield chunk;
                    },
                    None => {
                        warn!("upload: none" );
                        break;
                    },
                }
            }

            info!("upload: stream finished");
        };

        info!(%url, "upload: {} bytes", bytes);

        let response = reqwest::Client::new()
            .post(&url)
            .header("content-length", format!("{}", bytes))
            .body(reqwest::Body::wrap_stream(async_stream))
            .send()
            .await;

        info!("upload: have response");

        match response {
            Ok(response) => {
                info!("upload: done {:?}", response.status());
                let server_error = response.status().is_server_error();
                let maybe_body: Result<UpgradeBody, _> = response.json().await;
                info!("upload: response {:?}", maybe_body);

                if server_error {
                    let upgrade_error: UpgradeError = if let Ok(body) = maybe_body {
                        info!("upload: response {:?}", body);
                        body.into()
                    } else {
                        UpgradeError::Server
                    };
                    match sender.send(Err(upgrade_error)) {
                        Err(e) => warn!("{:?}", e),
                        Ok(_) => {}
                    }
                }
            }
            Err(e) => warn!("{:?}", e),
        }

        Ok(())
    }
}

impl Client {
    pub fn new() -> Result<Self, reqwest::Error> {
        let mut headers = HeaderMap::new();
        let sdk_version = std::env!("CARGO_PKG_VERSION");
        let user_agent = format!("rustfk ({})", sdk_version);
        headers.insert(
            "user-agent",
            user_agent.parse().expect("invalid user-agent"),
        );

        let client = reqwest::ClientBuilder::new()
            .user_agent("rustfk")
            .connect_timeout(Duration::from_secs(3))
            .timeout(Duration::from_secs(2))
            .default_headers(headers)
            .build()?;

        Ok(Self { client })
    }

    pub async fn query_status(&self, addr: &str) -> Result<RawAndDecoded<HttpReply>> {
        let mut query = HttpQuery::default();
        query.r#type = QueryType::QueryStatus as i32;
        query.time = unix_time().unwrap_or(0);
        let encoded = query.encode_length_delimited_to_vec();
        let req = self.new_request(addr)?.body(encoded).build()?;
        self.execute(req).await
    }

    pub async fn query_readings(&self, addr: &str) -> Result<RawAndDecoded<HttpReply>> {
        let mut query = HttpQuery::default();
        query.r#type = QueryType::QueryGetReadings as i32;
        query.time = unix_time().unwrap_or(0);
        let encoded = query.encode_length_delimited_to_vec();
        let req = self.new_request(addr)?.body(encoded).build()?;
        self.execute(req).await
    }

    pub async fn configure(
        &self,
        addr: &str,
        query: impl Into<HttpQuery>,
    ) -> Result<RawAndDecoded<HttpReply>> {
        let query: HttpQuery = query.into();
        let encoded = query.encode_length_delimited_to_vec();
        let req = self.new_request(addr)?.body(encoded).build()?;
        self.execute(req).await
    }

    pub async fn configure_wifi_transmission(
        &self,
        addr: &str,
        configure: ConfigureWifiTransmission,
    ) -> Result<RawAndDecoded<HttpReply>> {
        self.configure(addr, configure).await
    }

    pub async fn configure_wifi_networks(
        &self,
        addr: &str,
        configure: ConfigureWifiNetworks,
    ) -> Result<RawAndDecoded<HttpReply>> {
        self.configure(addr, configure).await
    }

    pub async fn configure_lora_transmission(
        &self,
        addr: &str,
        configure: ConfigureLoraTransmission,
    ) -> Result<RawAndDecoded<HttpReply>> {
        self.configure(addr, configure).await
    }

    pub async fn clear_calibration(
        &self,
        addr: &str,
        module: usize,
    ) -> Result<RawAndDecoded<HttpReply>> {
        let mut query = ModuleHttpQuery::default();
        query.r#type = ModuleQueryType::ModuleQueryReset as i32;
        let encoded = query.encode_length_delimited_to_vec();
        let req = self
            .new_module_request(addr, module)?
            .body(encoded)
            .build()?;
        self.execute(req).await
    }

    pub async fn calibrate(
        &self,
        addr: &str,
        module: usize,
        data: &[u8],
    ) -> Result<RawAndDecoded<ModuleHttpReply>> {
        let mut query = ModuleHttpQuery::default();
        query.r#type = ModuleQueryType::ModuleQueryConfigure as i32;
        query.configuration = data.to_vec();
        let encoded = query.encode_length_delimited_to_vec();
        let req = self
            .new_module_request(addr, module)?
            .body(encoded)
            .build()?;
        self.execute(req).await
    }

    pub async fn upgrade(
        &self,
        addr: &str,
        options: UpgradeOptions,
    ) -> Result<impl Stream<Item = Result<BytesUploaded, UpgradeError>>, UpgradeError> {
        let bootloader_bytes = options.bootloader_size().await?;
        let total_bytes = options.total_size().await?;

        let (sender, recv) =
            tokio::sync::mpsc::unbounded_channel::<Result<BytesUploaded, UpgradeError>>();

        tokio::spawn({
            let addr = addr.to_owned();

            async move {
                let upload = FileUpload {
                    addr: addr.clone(),
                    path: options.bootloader.clone(),
                    limited: options.limited.clone(),
                    file: "fkbl-fkb-network.bin".to_owned(),
                    swap: false,
                    progress: BaseProgress(0, total_bytes),
                };

                match upload.upload(sender.clone()).await {
                    Ok(_) => {}
                    Err(e) => warn!("upload failed: {:?}", e),
                };

                tokio::time::sleep(Duration::from_secs(1)).await;

                let upload = FileUpload {
                    addr: addr.clone(),
                    path: options.main.clone(),
                    limited: options.limited.clone(),
                    file: "fk-bundled-fkb-network.bin".to_owned(),
                    swap: options.swap,
                    progress: BaseProgress(bootloader_bytes, total_bytes),
                };

                match upload.upload(sender).await {
                    Ok(_) => {}
                    Err(e) => warn!("upload failed: {:?}", e),
                };
            }
        });

        Ok(tokio_stream::wrappers::UnboundedReceiverStream::new(recv))
    }

    async fn execute<T: Message + Default>(
        &self,
        req: reqwest::Request,
    ) -> Result<RawAndDecoded<T>> {
        let url = req.url().clone();

        debug!("{} querying", &url);
        let response = self.client.execute(req).await?;
        let bytes = response.bytes().await?;

        debug!("{} queried, got {} bytes", &url, bytes.len());
        let decoded = T::decode_length_delimited(bytes.clone())?;
        Ok(RawAndDecoded {
            bytes: bytes.to_vec(),
            decoded,
        })
    }

    fn new_module_request(&self, addr: &str, module: usize) -> Result<RequestBuilder> {
        let url = format!("http://{}/fk/v1/modules/{}", addr, module);
        Ok(self.client.post(&url).timeout(Duration::from_secs(5)))
    }

    fn new_request(&self, addr: &str) -> Result<RequestBuilder> {
        let url = format!("http://{}/fk/v1", addr);
        Ok(self.client.post(&url).timeout(Duration::from_secs(5)))
    }
}

#[derive(Default, Clone)]
pub struct UpgradeOptions {
    pub bootloader: PathBuf,
    pub main: PathBuf,
    pub swap: bool,
    pub limited: Option<NonZeroU32>,
}

impl UpgradeOptions {
    async fn bootloader_size(&self) -> std::io::Result<u64> {
        let file = tokio::fs::File::open(&self.bootloader).await?;
        let md = file.metadata().await?;
        Ok(md.len())
    }

    async fn main_size(&self) -> std::io::Result<u64> {
        let file = tokio::fs::File::open(&self.main).await?;
        let md = file.metadata().await?;
        Ok(md.len())
    }

    async fn total_size(&self) -> std::io::Result<u64> {
        let bl_bytes = self.bootloader_size().await?;
        let main_bytes = self.main_size().await?;

        Ok(bl_bytes + main_bytes)
    }
}

pub struct RawAndDecoded<T> {
    pub bytes: Vec<u8>,
    pub decoded: T,
}

pub fn parse_http_reply(data: &[u8]) -> Result<HttpReply> {
    let mut cursor = Cursor::new(data);
    Ok(HttpReply::decode_length_delimited(&mut cursor)?)
}

#[derive(Default)]
pub struct LogDrop {}

impl Drop for LogDrop {
    fn drop(&mut self) {
        info!("dropped!");
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    pub fn test_parse_status() -> Result<()> {
        let data = include_bytes!("../examples/status_1.fkpb");
        let mut cursor = Cursor::new(data);
        let data = HttpReply::decode_length_delimited(&mut cursor)?;
        let status = data.status.unwrap();
        assert_eq!(status.identity.unwrap().device, "Early Impala 91");
        Ok(())
    }

    #[test]
    pub fn test_parse_status_with_logs() -> Result<()> {
        let data = include_bytes!("../examples/status_2_logs.fkpb");
        let mut cursor = Cursor::new(data);
        let data = HttpReply::decode_length_delimited(&mut cursor)?;
        let status = data.status.unwrap();
        assert_eq!(status.identity.unwrap().device, "Early Impala 91");
        assert_eq!(status.logs.len(), 32266);
        Ok(())
    }

    #[test]
    pub fn test_parse_status_with_readings() -> Result<()> {
        let data = include_bytes!("../examples/status_3_readings.fkpb");
        let mut cursor = Cursor::new(data);
        let data = HttpReply::decode_length_delimited(&mut cursor)?;
        let status = data.status.unwrap();
        assert_eq!(status.identity.unwrap().device, "Early Impala 91");
        let modules = &data.live_readings[0].modules;
        assert_eq!(modules.len(), 3);
        Ok(())
    }
}
