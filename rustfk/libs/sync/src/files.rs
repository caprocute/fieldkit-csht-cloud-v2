use anyhow::{anyhow, Context, Result};
use chrono::Utc;
use itertools::*;
use quick_protobuf::Reader;
use std::{
    collections::HashMap,
    fs::OpenOptions,
    io::Write,
    ops::RangeInclusive,
    path::{Path, PathBuf},
    sync::Mutex,
};
use tracing::*;

use crate::{
    proto::{Identity, ReceivedRecords, Record},
    server::{Flushed, RecordSinkArchive},
    RecordsSink,
};
use discovery::DeviceId;
use protos::FileMeta;

struct Previous {
    path: PathBuf,
    range: RangeInclusive<u64>,
}

pub struct FilesRecordSink {
    base_path: PathBuf,
    previous: Mutex<HashMap<(DeviceId, String), Previous>>,
}

impl FilesRecordSink {
    pub fn new(base_path: &Path) -> Self {
        Self {
            base_path: base_path.to_owned(),
            previous: Default::default(),
        }
    }

    fn device_path(&self, device_id: &DeviceId) -> PathBuf {
        self.base_path.join(&device_id.0)
    }

    fn append(&self, records: &ReceivedRecords, file_path: &PathBuf) -> Result<()> {
        // We'll usually be in a tokio context......
        let mut writing = OpenOptions::new()
            .append(true)
            .create(true)
            .open(file_path)
            .with_context(|| format!("Creating {:?}", &file_path))?;

        for record in records.iter() {
            writing.write(record.to_delimited()?.bytes())?;
        }

        Ok(())
    }

    fn create_new(&self, records: &ReceivedRecords) -> Result<Option<PathBuf>> {
        let range = records
            .range()
            .ok_or(anyhow!("No range on received records"))?;

        let device_path = self.device_path(&records.device_id);

        let sync_path = device_path.join(&records.sync_id);

        match std::fs::metadata(sync_path.clone()) {
            Ok(md) => {
                if !md.is_dir() {
                    return Err(anyhow!("Unexpected not-a-directory"));
                }
            }
            Err(ref e) if e.kind() == std::io::ErrorKind::NotFound => {
                info!("Mkdir {}", sync_path.display());
                std::fs::create_dir_all(sync_path.clone())
                    .with_context(|| format!("Creating sync path {:?}", &sync_path))?;
            }
            Err(e) => Err(e)?,
        }

        let file_path = sync_path.join(format!("{}.fkpb", range.start()));

        if file_path.exists() {
            info!("Exists {:?}", file_path);

            Ok(None)
        } else {
            info!("Creating {:?}", file_path);

            self.append(records, &file_path)?;

            Ok(Some(file_path))
        }
    }

    fn join_files(
        &self,
        sync_id: &String,
        identity: &Identity,
        files: Vec<RecordsFile>,
    ) -> Result<(i64, i64)> {
        let device_path = self.device_path(&identity.device_id);
        let path = device_path.join(format!("{}.fkpb", sync_id));

        let mut writing = OpenOptions::new()
            .write(true)
            .create(true)
            .truncate(true)
            .open(&path)
            .with_context(|| format!("Creating {:?}", &path))?;

        let mut written = 0;
        let head = files.iter().next().map(|f| f.head).unwrap();
        for file in files.iter() {
            let skipping = written - file.head + head;
            if skipping < 0 {
                warn!(
                    "Head={} File={:?} FileHead={} Written={} Skip={}",
                    head,
                    file.path.file_name(),
                    file.head,
                    written,
                    skipping,
                );

                break;
            } else {
                info!(
                    "Head={} File={:?} FileHead={} Written={} Skip={}",
                    head,
                    file.path.file_name(),
                    file.head,
                    written,
                    skipping,
                );
            }

            let mut skipped = 0;
            let mut records_in_file = 0;
            let mut reader = Reader::from_file(&file.path)?;
            while let Some(record) = reader.read(|r, b| {
                if r.is_eof() {
                    Ok(None)
                } else {
                    Ok(Some(r.read_bytes(b)?))
                }
            })? {
                if skipped == skipping {
                    let record = Record::Undelimited(record.to_vec());
                    let record = record.to_delimited()?;
                    writing.write(record.bytes())?;
                    written += 1;
                } else {
                    skipped += 1;
                }
                records_in_file += 1;
            }

            debug!(
                "Head={} File={:?} FileHead={} Written={} Skip={}/{} InFile={}",
                head,
                file.path.file_name(),
                file.head,
                written,
                skipping,
                skipped,
                records_in_file
            );
        }

        info!("{} Flushed {} records", path.display(), written);

        Ok((head, written))
    }

    fn write_file_meta(
        &self,
        sync_id: &String,
        identity: &Identity,
        head_record: i64,
        total_records: i64,
    ) -> Result<()> {
        let device_path = self.device_path(&identity.device_id);
        let data_name = format!("{}.fkpb", sync_id);
        let path = device_path.join(format!("{}.json", &data_name));
        let tail = head_record + total_records - 1;

        let mut headers = identity.to_headers_map();
        // Yes, this appears to be "last record number" instead of "total number
        // of records" based on the firmware.
        headers.insert("Fk-Blocks".to_owned(), format!("{},{}", head_record, tail));
        headers.insert("Fk-Type".to_owned(), "data".to_owned());

        let fm = FileMeta {
            sync_id: sync_id.clone(),
            device_id: identity.device_id.clone().into(),
            generation_id: identity.generation_id.clone().into(),
            head: head_record,
            tail,
            data_name,
            headers,
            uploaded: None,
        };

        fm.save(&path)?;

        info!("{} Wrote", &path.display());

        Ok(())
    }
}

impl FilesRecordSink {
    pub fn delete_device_files(&self, device_id: &DeviceId) -> Result<()> {
        let device_path = self.device_path(&device_id);

        std::fs::remove_dir_all(&device_path)?;

        Ok(())
    }
}

#[derive(Debug)]
struct RecordsFile {
    path: PathBuf,
    head: i64,
}

impl RecordsFile {
    fn new(path: &PathBuf) -> Result<Self> {
        let name = path.file_name().expect("No file name on path");
        let head = name
            .to_os_string()
            .into_string()
            .map_err(|_| anyhow!("Quirky file name"))?
            .split(".")
            .next()
            .map(|v| Ok(v.parse()?))
            .unwrap_or(Err(anyhow!("Malformed record file name")))?;

        Ok(Self {
            path: path.clone(),
            head,
        })
    }
}

impl RecordsSink for FilesRecordSink {
    fn query_archives(&self) -> Result<Vec<RecordSinkArchive>> {
        let pattern = self.base_path.join("*/*.fkpb.json");
        let pattern = pattern.to_string_lossy();
        info!("Pattern: {:?}", &pattern);

        let found_metas = glob::glob(&pattern)?;
        let parsed = found_metas
            .into_iter()
            .map(|p| Ok(p?))
            .collect::<Result<Vec<_>>>()?
            .into_iter()
            .map(|p| Ok((p.clone(), FileMeta::load_from_json_sync(&p)?)))
            .collect::<Result<Vec<_>>>()?;
        info!("Parsed {:?} files", parsed.len());

        let parsed: Vec<_> = parsed
            .into_iter()
            .filter(|(path, meta)| {
                path.parent()
                    .map(|p| p.join(&meta.data_name).is_file())
                    .unwrap_or_default()
            })
            .collect();
        info!("Valid files: {:?}", parsed.len());

        let archives = parsed
            .into_iter()
            .map(|(path, meta)| RecordSinkArchive {
                device_id: meta.device_id.clone(),
                generation_id: meta
                    .generation_id
                    .clone()
                    .unwrap_or_else(|| "unknown".to_string()),
                path: path.to_string_lossy().to_string(),
                meta,
            })
            .collect();

        Ok(archives)
    }

    fn write(&self, records: &ReceivedRecords) -> Result<()> {
        let range = records
            .range()
            .ok_or(anyhow!("No range on received records"))?;

        let mut previous_by_key = self.previous.lock().expect("Lock error");
        let key = (records.device_id.clone(), records.sync_id.clone());
        let consecutive = previous_by_key
            .get_mut(&key)
            .map(|p| (*range.start() == *p.range.end() + 1, p));

        match consecutive {
            Some((true, previous)) => {
                self.append(records, &previous.path)?;

                previous.range = *previous.range.start()..=*range.end()
            }
            Some((false, p)) => match self.create_new(records)? {
                Some(file_path) => {
                    previous_by_key.insert(
                        key,
                        Previous {
                            path: file_path,
                            range,
                        },
                    );
                }
                None => {
                    warn!(
                        "Collision: File={:?} Received={:?} (Ignored)",
                        p.range, range
                    );
                }
            },
            None => match self.create_new(records)? {
                Some(file_path) => {
                    previous_by_key.insert(
                        key,
                        Previous {
                            path: file_path,
                            range,
                        },
                    );
                }
                None => {
                    error!("File exists, unexpected: Received={:?} (Ignored)", range);
                }
            },
        }

        Ok(())
    }

    fn flush(&self, sync_id: String, identity: Identity) -> Result<Flushed> {
        let device_path = self.device_path(&identity.device_id);
        let sync_path = device_path.join(&sync_id);

        info!("flushing {:?}", &sync_path);

        let files: Vec<_> = std::fs::read_dir(sync_path)?
            .map(|entry| Ok(RecordsFile::new(&entry?.path())?))
            .collect::<Result<Vec<_>>>()?
            .into_iter()
            .sorted_unstable_by_key(|r| r.head)
            .collect();

        let (head_record, total_records) = self.join_files(&sync_id, &identity, files)?;

        self.write_file_meta(&sync_id, &identity, head_record, total_records)?;

        Ok(Flushed {
            head_record,
            total_records,
        })
    }

    fn uploaded(&self, archive: String) -> Result<()> {
        info!("uploaded {:?}", archive);

        let path: PathBuf = archive.into();
        let mut meta = FileMeta::load_from_json_sync(&path)?;
        meta.uploaded = Some(Utc::now().timestamp_micros());
        meta.save(&path)?;

        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use discovery::DeviceId;
    use tempdir::TempDir;

    use crate::proto::{NumberedRecord, Record};

    use super::*;

    fn new_sink() -> Result<(FilesRecordSink, TempDir)> {
        let dir = TempDir::new("fk-tests-sync")?;

        Ok((FilesRecordSink::new(dir.path()), dir))
    }

    #[test]
    pub fn test_writes_initial_records() -> Result<()> {
        let (sink, _dir) = new_sink()?;

        let ids = Ids::default();
        sink.write(&ids.builder().records(1000).build())?;
        let flushed = sink.flush(ids.sync_id.clone(), ids.identity())?;

        assert_eq!(
            flushed,
            Flushed {
                head_record: 0,
                total_records: 1000
            }
        );

        Ok(())
    }

    #[test]
    pub fn test_writes_initial_records_with_gap() -> Result<()> {
        let (sink, _dir) = new_sink()?;

        let ids = Ids::default();
        sink.write(&ids.builder().first(500).gap(10).records(490).build())?;
        let flushed = sink.flush(ids.sync_id.clone(), ids.identity())?;

        assert_eq!(
            flushed,
            Flushed {
                head_record: 510,
                total_records: 490
            }
        );

        Ok(())
    }

    #[test]
    pub fn test_writes_additional_records() -> Result<()> {
        let (sink, _dir) = new_sink()?;

        let ids = Ids::default();
        sink.write(&ids.builder().records(1000).build())?;
        sink.write(&ids.builder().first(1000).records(1000).build())?;
        let flushed = sink.flush(ids.sync_id.clone(), ids.identity())?;

        assert_eq!(
            flushed,
            Flushed {
                head_record: 0,
                total_records: 2000
            }
        );

        Ok(())
    }

    #[test]
    pub fn test_writes_additional_records_with_gap() -> Result<()> {
        let (sink, _dir) = new_sink()?;

        let ids = Ids::default();
        sink.write(&ids.builder().records(1000).build())?;
        sink.write(&ids.builder().first(1500).gap(10).records(490).build())?;
        let flushed = sink.flush(ids.sync_id.clone(), ids.identity())?;

        assert_eq!(
            flushed,
            Flushed {
                head_record: 0,
                total_records: 1000
            }
        );

        Ok(())
    }

    #[test]
    pub fn test_writes_additional_records_with_multiple_gaps_one_overlapping() -> Result<()> {
        let (sink, _dir) = new_sink()?;

        let ids = Ids::default();
        sink.write(&ids.builder().records(1000).build())?;
        sink.write(&ids.builder().first(1100).records(100).build())?;
        sink.write(&ids.builder().first(1000).records(200).build())?;
        sink.write(&ids.builder().first(1500).records(500).build())?;
        let flushed = sink.flush(ids.sync_id.clone(), ids.identity())?;

        assert_eq!(
            flushed,
            Flushed {
                head_record: 0,
                total_records: 1200
            }
        );

        Ok(())
    }

    #[test]
    pub fn test_writes_additional_records_that_fill_earlier_gap() -> Result<()> {
        let (sink, _dir) = new_sink()?;

        let ids = Ids::default();
        sink.write(&ids.builder().first(1000).gap(100).records(900).build())?;
        sink.write(&ids.builder().first(1000).records(100).build())?;
        let flushed = sink.flush(ids.sync_id.clone(), ids.identity())?;

        assert_eq!(
            flushed,
            Flushed {
                head_record: 1000,
                total_records: 1000
            }
        );

        Ok(())
    }

    #[test]
    pub fn test_receives_same_starting_record_twice() -> Result<()> {
        let (sink, _dir) = new_sink()?;

        let ids = Ids::default();
        sink.write(&ids.builder().records(100).build())?;
        sink.write(&ids.builder().records(200).build())?;
        let flushed = sink.flush(ids.sync_id.clone(), ids.identity())?;

        assert_eq!(
            flushed,
            Flushed {
                head_record: 0,
                total_records: 100
            }
        );

        Ok(())
    }

    #[test]
    pub fn test_receives_duplicates() -> Result<()> {
        let (sink, _dir) = new_sink()?;

        let ids = Ids::default();
        sink.write(&ids.builder().records(200).build())?;
        sink.write(&ids.builder().gap(50).records(20).build())?;
        let flushed = sink.flush(ids.sync_id.clone(), ids.identity())?;

        assert_eq!(
            flushed,
            Flushed {
                head_record: 0,
                total_records: 200
            }
        );

        Ok(())
    }

    #[derive(Clone)]
    pub struct Ids {
        sync_id: String,
        device_id: DeviceId,
    }

    impl Ids {
        fn builder(&self) -> ReceivedRecordsBuilder {
            ReceivedRecordsBuilder::from(self.clone())
        }

        fn identity(&self) -> Identity {
            Identity {
                device_id: self.device_id.clone(),
                generation_id: "generation".to_owned(),
                name: "Station".to_owned(),
            }
        }
    }

    impl Default for Ids {
        fn default() -> Self {
            Self {
                sync_id: "sync_id".to_owned(),
                device_id: DeviceId("device".to_owned()),
            }
        }
    }

    pub struct ReceivedRecordsBuilder {
        sync_id: String,
        device_id: DeviceId,
        records: Vec<NumberedRecord>,
        number: usize,
    }

    impl From<Ids> for ReceivedRecordsBuilder {
        fn from(value: Ids) -> Self {
            Self {
                sync_id: value.sync_id.clone(),
                device_id: value.device_id.clone(),
                records: Vec::new(),
                number: 0,
            }
        }
    }

    impl ReceivedRecordsBuilder {
        fn build(self) -> ReceivedRecords {
            ReceivedRecords {
                sync_id: self.sync_id,
                device_id: self.device_id,
                records: self.records,
            }
        }

        fn first(self, number: usize) -> Self {
            Self {
                sync_id: self.sync_id,
                device_id: self.device_id,
                records: self.records,
                number,
            }
        }

        fn records(self, number: usize) -> Self {
            Self {
                sync_id: self.sync_id,
                device_id: self.device_id,
                records: (0..number)
                    .into_iter()
                    .map(|n| NumberedRecord {
                        number: (n + self.number) as u64,
                        record: Record::new_all_zeros(256)
                            .to_delimited()
                            .expect("Error creating delimited test record."),
                    })
                    .collect(),
                number: self.number + number,
            }
        }

        fn gap(self, number: usize) -> Self {
            Self {
                sync_id: self.sync_id,
                device_id: self.device_id,
                records: self.records,
                number: self.number + number,
            }
        }
    }

    #[ctor::ctor]
    fn log_test() {
        use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

        tracing_subscriber::registry()
            .with(tracing_subscriber::EnvFilter::new(
                std::env::var("RUST_LOG").unwrap_or_else(|_| "debug".into()),
            ))
            .with(tracing_subscriber::fmt::layer().with_thread_ids(true))
            .init();
    }
}
