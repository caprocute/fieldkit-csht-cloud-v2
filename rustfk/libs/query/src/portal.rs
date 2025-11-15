use anyhow::anyhow;
use anyhow::Result;
use base64::{engine::general_purpose, Engine};
use chrono::serde::ts_seconds::deserialize as from_ts;
use chrono::serde::ts_seconds::serialize as to_ts;
use chrono::{DateTime, NaiveDateTime, TimeZone, Utc};
use reqwest::IntoUrl;
use reqwest::{header::InvalidHeaderValue, header::ToStrError};
use reqwest::{
    header::{HeaderMap, HeaderName, HeaderValue},
    Request, Response,
};
use serde::{Deserialize, Deserializer, Serialize};
use serde_json::json;
use std::collections::HashMap;
use std::io::Write;
use std::path::PathBuf;
use std::{path::Path, time::Duration};
use thiserror::Error;
use tokio::fs::File;
use tokio_stream::Stream;
use tokio_stream::StreamExt;
use tokio_util::io::ReaderStream;
use tracing::{debug, info, warn};

use protos::FileMeta;

pub use reqwest::StatusCode;

use crate::BytesDownloaded;
use crate::BytesUploaded;

#[derive(Debug)]
pub struct Client {
    base_url: String,
    client: reqwest::Client,
}

impl Client {
    pub fn new(base_url: &str) -> Result<Self, PortalError> {
        Self::new_with_headers(base_url, HeaderMap::new())
    }

    pub fn new_with_headers(base_url: &str, mut headers: HeaderMap) -> Result<Self, PortalError> {
        let sdk_version = std::env!("CARGO_PKG_VERSION");
        let user_agent = format!("rustfk ({})", sdk_version);
        headers.insert("user-agent", user_agent.parse()?);

        let client = reqwest::ClientBuilder::new()
            .user_agent("rustfk")
            .connect_timeout(Duration::from_secs(5))
            .timeout(Duration::from_secs(30))
            .default_headers(headers)
            .build()?;

        Ok(Self {
            base_url: base_url.to_owned(),
            client,
        })
    }

    async fn execute_req(&self, req: Request) -> Result<Response, PortalError> {
        let url = req.url().clone();
        debug!("{} querying", &url);

        let response = self.client.execute(req).await?;

        let status = response.status();
        debug!("{} done querying ({:?})", &url, status);

        if status.is_success() {
            Ok(response)
        } else {
            Err(PortalError::HttpStatus(status))
        }
    }

    async fn build_get<U: IntoUrl>(&self, url: U) -> Result<Request, PortalError> {
        Ok(self
            .client
            .get(url)
            .timeout(Duration::from_secs(30))
            .build()?)
    }

    async fn build_post<U: IntoUrl, T>(&self, url: U, payload: T) -> Result<Request, PortalError>
    where
        T: Serialize,
    {
        Ok(self
            .client
            .post(url)
            .json(&payload)
            .timeout(Duration::from_secs(30))
            .build()?)
    }

    fn add_base(&self, path: &str) -> String {
        format!("{}{}", self.base_url, path)
    }

    fn response_to_tokens(&self, response: Response) -> Result<Tokens, PortalError> {
        if let Some(auth) = response.headers().get("authorization") {
            let token = auth.to_str()?.to_owned();
            Ok(Tokens { token })
        } else {
            Err(PortalError::NoAuthorizationHeader)
        }
    }

    pub async fn login(&self, payload: LoginPayload) -> Result<Tokens, PortalError> {
        let req = self.build_post(self.add_base("/login"), payload).await?;
        let response = self.execute_req(req).await?;

        self.response_to_tokens(response)
    }

    pub async fn register(&self, payload: RegisterPayload) -> Result<(), PortalError> {
        let req = self.build_post(self.add_base("/users"), payload).await?;
        let response = self.execute_req(req).await?;
        let _bytes = response.bytes().await?;

        Ok(())
    }

    pub async fn query_status(&self) -> Result<(), PortalError> {
        let req = self.build_get(self.add_base("/status")).await?;
        let response = self.execute_req(req).await?;
        let _bytes = response.bytes().await?;

        Ok(())
    }

    pub async fn use_refresh_token(&self, refresh_token: &str) -> Result<Tokens, PortalError> {
        let req = self
            .build_post(
                self.add_base("/refresh"),
                json!({ "refreshToken": refresh_token }),
            )
            .await?;
        let response = self.execute_req(req).await?;

        self.response_to_tokens(response)
    }

    pub async fn available_firmware(
        &self,
        filter: Option<FirmwareFilter>,
    ) -> Result<Vec<Firmware>> {
        let params = filter.map(|f| f.to_params()).unwrap_or_default();
        let url = reqwest::Url::parse_with_params(&self.add_base("/firmware"), &params)?;
        let req = self.build_get(url).await?;
        let response = self.execute_req(req).await?;
        let firmwares: Firmwares = response.json().await?;

        Ok(firmwares.firmwares)
    }

    pub async fn download_firmware(
        &self,
        firmware: &Firmware,
        path: &Path,
    ) -> Result<impl Stream<Item = Result<BytesDownloaded, PortalError>>, PortalError> {
        let response = reqwest::get(self.add_base(&firmware.url)).await?;
        let total_bytes = response
            .content_length()
            .ok_or_else(|| anyhow!("Missing Content-Length"))?;

        let mut file = std::fs::File::create(path)?;
        let mut stream = response.bytes_stream();
        let mut downloaded: u64 = 0;

        Ok(async_stream::try_stream! {
            while let Some(item) = stream.next().await {
                let chunk = item.or_else(|_| Err(anyhow!("Error while downloading firmware")))?;
                file.write_all(&chunk)?;

                downloaded = std::cmp::min(downloaded + (chunk.len() as u64), total_bytes);
                yield BytesDownloaded {
                    bytes_downloaded: downloaded,
                    total_bytes,
                };
            }
        })
    }

    pub fn to_authenticated(&self, token: Tokens) -> Result<AuthenticatedClient, PortalError> {
        AuthenticatedClient::new(&self.base_url, token)
    }
}

#[derive(Debug, Deserialize)]
struct Firmwares {
    firmwares: Vec<Firmware>,
}

#[derive(Debug, PartialEq, Eq, PartialOrd, Ord)]
pub struct EtagParts {
    pub module: String,
    pub profile: String,
    pub stamp: String,
}

#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord, Deserialize, Serialize)]
pub struct Etag(String);

impl Etag {
    pub fn parts(&self) -> Option<EtagParts> {
        let parts: Vec<_> = self.0.split("_").collect();
        if parts.len() == 4 {
            Some(EtagParts {
                module: parts[0].to_owned(),
                profile: parts[1].to_owned(),
                stamp: format!("{}_{}", parts[2], parts[3]),
            })
        } else {
            None
        }
    }
}

#[derive(Debug, Clone, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Firmware {
    pub id: i64,
    #[serde(deserialize_with = "deserialize_firmware_time")]
    pub time: DateTime<Utc>,
    pub etag: Etag,
    pub module: String,
    pub profile: String,
    pub version: String,
    pub url: String,
    pub build_number: i64,
    #[serde(deserialize_with = "from_ts", serialize_with = "to_ts")]
    pub build_time: DateTime<Utc>,
    pub meta: HashMap<String, String>,
}

#[derive(Debug, PartialEq, Eq, PartialOrd, Ord)]
pub enum ModuleKind {
    Core,
    Bootloader,
}

impl Firmware {
    pub fn module_kind(&self) -> Option<ModuleKind> {
        match self.module.as_str() {
            "fk-bl" => Some(ModuleKind::Bootloader),
            "fk-core" => Some(ModuleKind::Core),
            _ => None,
        }
    }
}

fn deserialize_firmware_time<'de, D>(deserializer: D) -> Result<DateTime<Utc>, D::Error>
where
    D: Deserializer<'de>,
{
    let s: String = Deserialize::deserialize(deserializer)?;

    DateTime::parse_from_rfc3339(&s)
        .map(|v| v.with_timezone(&Utc))
        .or_else(|_| {
            NaiveDateTime::parse_from_str(&s, "%Y-%m-%d %H:%M:%S.%f +0000")
                .or_else(|_| NaiveDateTime::parse_from_str(&s, "%Y-%m-%d %H:%M:%S.%f +0000 +0000"))
                .map_err(serde::de::Error::custom)
                .map(|v| Utc.from_utc_datetime(&v))
        })
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct AddStation {
    pub name: String,
    pub device_id: String,
    pub location_name: String,
    pub status_pb: String,
}

#[derive(Deserialize)]
pub struct Station {
    pub id: u32,
}

#[derive(Debug)]
pub struct AuthenticatedClient {
    tokens: Tokens,
    plain: Client,
}

impl AuthenticatedClient {
    pub fn new(base_url: &str, tokens: Tokens) -> Result<Self, PortalError> {
        let mut headers = HeaderMap::new();
        headers.insert("authorization", tokens.token.parse()?);

        Ok(Self {
            tokens,
            plain: Client::new_with_headers(base_url, headers)?,
        })
    }

    pub async fn query_ourselves(&self) -> Result<User, PortalError> {
        let req = self.plain.build_get(self.plain.add_base("/user")).await?;
        let response = self.plain.execute_req(req).await?;
        Ok(response.json().await?)
    }

    pub async fn issue_transmission_token(&self) -> Result<TransmissionToken, PortalError> {
        let req = self
            .plain
            .build_get(self.plain.add_base("/user/transmission-token"))
            .await?;
        let response = self.plain.execute_req(req).await?;
        Ok(response.json().await?)
    }

    pub async fn add_or_update_station(
        &self,
        station: AddStation,
    ) -> Result<Option<Station>, PortalError> {
        let req = self
            .plain
            .build_post(self.plain.add_base("/stations"), station)
            .await?;
        match self.plain.execute_req(req).await {
            Ok(response) => Ok(Some(response.json().await?)),
            Err(e) => match e {
                PortalError::HttpStatus(status) => {
                    if status.as_u16() == 400 {
                        Ok(None)
                    } else {
                        Err(e)
                    }
                }
                _ => Err(e),
            },
        }
    }

    pub async fn upload_readings(
        &self,
        path: &Path,
    ) -> Result<impl Stream<Item = Result<BytesUploaded, PortalError>>, PortalError> {
        let file_meta = FileMeta::load_from_json(&path).await?;
        let data_path =
            get_relative_to(path, &file_meta.data_name).ok_or(PortalError::UnexpectedError)?;

        let header_map: HeaderMap = file_meta
            .headers
            .into_iter()
            .map(|(k, v)| {
                Ok((
                    HeaderName::from_lowercase(k.to_lowercase().as_bytes())?,
                    HeaderValue::from_str(&v)?,
                ))
            })
            .collect::<Result<Vec<_>>>()?
            .into_iter()
            .collect();

        info!("headers {:?}", &header_map);

        let file = File::open(&data_path).await?;
        let md = file.metadata().await?;
        let total_bytes = md.len();

        let (sender, recv) =
            tokio::sync::mpsc::unbounded_channel::<Result<BytesUploaded, PortalError>>();

        let mut uploaded = 0;
        let mut reader_stream = ReaderStream::new(file);

        tokio::spawn({
            let url = self.plain.add_base("/ingestion");
            let token = self.tokens.token.clone();
            let copying = sender.clone();

            let async_stream = async_stream::stream! {
                while let Some(chunk) = reader_stream.next().await {
                    if let Ok(chunk) = &chunk {
                        uploaded = std::cmp::min(uploaded + (chunk.len() as u64), total_bytes);
                        match copying.send(Ok(BytesUploaded { bytes_uploaded: uploaded, total_bytes })) {
                            Err(e) => warn!("{:?}", e),
                            Ok(_) => {},
                        }
                    }
                    yield chunk;
                }
            };

            async move {
                info!(%url, "uploading {} bytes", total_bytes);

                let response = reqwest::Client::new()
                    .post(&url)
                    .headers(header_map)
                    .header("content-type", "application/octet-stream")
                    .header("content-length", format!("{}", total_bytes))
                    .header("authorization", token)
                    .body(reqwest::Body::wrap_stream(async_stream))
                    .send()
                    .await;

                match response {
                    Ok(response) => {
                        if response.status() != StatusCode::OK {
                            warn!("done {:?}", response.status());
                            match sender.send(Err(PortalError::HttpStatus(response.status()))) {
                                Err(e) => warn!("{:?}", e),
                                Ok(_) => {}
                            }
                        } else {
                            info!("done {:?}", response.status());
                        }
                    }
                    Err(e) => {
                        warn!("response error: {:?}", e);

                        match sender.send(Err(PortalError::General(anyhow!("{:?}", e)))) {
                            Err(e) => warn!("{:?}", e),
                            Ok(_) => {}
                        }
                    }
                }
            }
        });

        Ok(tokio_stream::wrappers::UnboundedReceiverStream::new(recv))
    }

    pub async fn available_firmware(
        &self,
        filter: Option<FirmwareFilter>,
    ) -> Result<Vec<Firmware>> {
        self.plain.available_firmware(filter).await
    }

    pub async fn query_admin_health(&self) -> Result<Health, PortalError> {
        let req = self
            .plain
            .build_get(self.plain.add_base("/admin/health"))
            .await?;
        let response = self.plain.execute_req(req).await?;
        Ok(response.json().await?)
    }
}

fn get_relative_to(anchor: &Path, relative: &str) -> Option<PathBuf> {
    let base = anchor.parent();
    base.map(|b| b.join(relative))
}

#[derive(Clone)]
pub struct Tokens {
    pub token: String,
}

impl std::fmt::Debug for Tokens {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_tuple("Token").field(&"SECRET").finish()
    }
}

#[derive(Debug, Serialize)]
pub struct LoginPayload {
    pub email: String,
    pub password: String,
}

impl LoginPayload {
    pub fn from_env() -> Result<Self, std::env::VarError> {
        let email = std::env::var("FK_EMAIL")?;
        let password = std::env::var("FK_PASSWORD")?;

        Ok(Self { email, password })
    }
}

#[derive(Debug, Serialize)]
pub struct RegisterPayload {
    pub name: String,
    pub email: String,
    pub password: String,
    pub tnc_accept: Option<bool>,
}

#[derive(Debug, Deserialize)]
pub struct User {
    pub id: u64,
    pub email: String,
    pub name: String,
    pub bio: String,
    pub photo: Option<Photo>,
}

#[derive(Debug, Deserialize)]
pub struct Photo {
    pub url: String,
}

#[derive(Clone, Debug, Deserialize)]
pub struct TransmissionToken {
    pub token: String,
    pub url: String,
}

#[derive(Debug, Deserialize, Clone)]
pub struct DecodedToken {
    pub email: String,
    pub exp: i64,
    pub iat: i64,
    pub refresh_token: String,
    pub scopes: Vec<String>,
    pub sub: u64,
}

impl DecodedToken {
    pub fn decode(token: &str) -> Result<DecodedToken, PortalError> {
        // Sorry, not sorry.
        token
            .split(".")
            .skip(1)
            .take(1)
            .map(|p| {
                Ok(std::str::from_utf8(&general_purpose::STANDARD_NO_PAD.decode(p)?)?.to_owned())
            })
            .collect::<Result<Vec<_>, PortalError>>()?
            .into_iter()
            .map(|p| Ok(serde_json::from_str::<DecodedToken>(p.as_str())?))
            .collect::<Result<Vec<_>, PortalError>>()?
            .into_iter()
            .next()
            .ok_or(PortalError::UnexpectedError)
    }

    pub fn issued(&self) -> DateTime<Utc> {
        Utc.timestamp_opt(self.iat, 0).unwrap()
    }

    pub fn expires(&self) -> DateTime<Utc> {
        Utc.timestamp_opt(self.exp, 0).unwrap()
    }

    pub fn remaining(&self) -> chrono::Duration {
        self.expires() - Utc::now()
    }
}

#[derive(Error, Debug)]
pub enum PortalError {
    #[error("HTTP error")]
    Request(#[from] reqwest::Error),
    #[error("IO error")]
    Io(#[from] std::io::Error),
    #[error("Invalid header value")]
    InvalidHeaderValue(#[from] InvalidHeaderValue),
    #[error("Conversion error")]
    ConversionError(#[from] ToStrError),
    #[error("HTTP status error")]
    HttpStatus(StatusCode),
    #[error("Base 64 error")]
    Base64Error(#[from] base64::DecodeError),
    #[error("UTF 8 error")]
    Utf8Error(#[from] std::str::Utf8Error),
    #[error("JSON error")]
    JsonError(#[from] serde_json::Error),
    #[error("Unexpected error")]
    UnexpectedError,
    #[error("Expected authorization header")]
    NoAuthorizationHeader,
    #[error("General error")]
    General(#[from] anyhow::Error),
}

#[derive(Debug)]
pub struct FirmwareFilter {
    pub module: Option<String>,
    pub profile: Option<String>,
    pub page: Option<usize>,
    pub page_size: Option<usize>,
}

impl FirmwareFilter {
    fn to_params(self) -> Vec<(String, String)> {
        self.module
            .map(|v| ("module".to_owned(), v))
            .into_iter()
            .chain(self.profile.map(|v| ("profile".to_owned(), v)))
            .chain(self.page.map(|v| ("page".to_owned(), format!("{}", v))))
            .chain(
                self.page_size
                    .map(|v| ("pageSize".to_owned(), format!("{}", v))),
            )
            .collect()
    }
}

#[derive(Debug, Deserialize)]
pub struct Health {
    pub queue: QueueHealth,
}

#[derive(Debug, Deserialize)]
pub struct QueueHealth {
    pub pending: i64,
    pub errors: i64,
}
