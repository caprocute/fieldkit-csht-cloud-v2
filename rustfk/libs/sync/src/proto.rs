use anyhow::{anyhow, Result};
use discovery::DeviceId;
use quick_protobuf::reader::BytesReader;
use quick_protobuf::writer::Writer;
use range_set_blaze::prelude::*;
use std::collections::HashMap;
use std::ops::RangeInclusive;
use tracing::*;

#[derive(PartialEq, Eq, Clone, Debug)]
pub struct RecordRange(pub RangeInclusive<u64>);

impl RecordRange {
    pub fn new(h: u64, t: u64) -> Self {
        Self(RangeInclusive::new(h, t))
    }

    pub fn to_set(&self) -> RangeSetBlaze<u64> {
        RangeSetBlaze::from_iter([self.head()..=self.tail()])
    }

    fn head(&self) -> u64 {
        *self.0.start()
    }

    fn tail(&self) -> u64 {
        *self.0.end()
    }
}

impl From<RecordRange> for RangeInclusive<u64> {
    fn from(val: RecordRange) -> Self {
        val.0
    }
}

impl From<&RangeInclusive<u64>> for RecordRange {
    fn from(value: &RangeInclusive<u64>) -> Self {
        RecordRange(value.clone())
    }
}

#[derive(Clone, Debug)]
pub struct NumberedRecord {
    pub number: u64,
    pub record: Record,
}

impl NumberedRecord {
    pub fn new(number: u64, record: Record) -> Self {
        Self { number, record }
    }

    pub fn bytes(&self) -> &[u8] {
        self.record.bytes()
    }

    pub fn to_delimited(&self) -> Result<Self> {
        Ok(Self {
            number: self.number,
            record: self.record.to_delimited()?,
        })
    }
}

#[derive(Debug)]
pub struct ReceivedRecords {
    pub sync_id: String,
    pub device_id: DeviceId,
    pub records: Vec<NumberedRecord>,
}

impl ReceivedRecords {
    // Note that ReceivedRecords are always sequential, as they're constructed
    // from incoming packets.
    pub fn range(&self) -> Option<RangeInclusive<u64>> {
        let numbers = self.records.iter().map(|r| r.number);
        let first = numbers.clone().min();
        let last = numbers.max();
        match (first, last) {
            (Some(first), Some(last)) => Some(first..=last),
            _ => None,
        }
    }

    pub fn iter(&self) -> impl Iterator<Item = &NumberedRecord> {
        self.records.iter()
    }

    pub fn len(&self) -> usize {
        self.records.len()
    }
}

#[derive(PartialEq, Eq, Clone)]
pub enum Record {
    Undelimited(Vec<u8>),
    Bytes(Vec<u8>),
}

impl std::fmt::Debug for Record {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Record::Undelimited(bytes) => f.debug_tuple("Undelimited").field(&bytes.len()).finish(),
            Record::Bytes(bytes) => f.debug_tuple("Bytes").field(&bytes.len()).finish(),
        }
    }
}

impl Record {
    pub fn bytes(&self) -> &[u8] {
        match self {
            Record::Undelimited(bytes) => bytes,
            Record::Bytes(bytes) => bytes,
        }
    }

    #[cfg(test)]
    pub fn new_all_zeros(len: usize) -> Self {
        let zeros: Vec<u8> = std::iter::repeat(0 as u8).take(len).collect();
        Self::Undelimited(zeros)
    }

    pub fn to_delimited(&self) -> Result<Record> {
        match self {
            Record::Undelimited(bytes) | Record::Bytes(bytes) => {
                let mut writing = Vec::new();
                {
                    let mut writer = Writer::new(&mut writing);
                    writer.write_bytes(&bytes)?;
                }
                Ok(Self::Bytes(writing))
            }
        }
    }

    #[cfg(test)]
    pub fn split_off(&self, at: usize) -> (Record, Record) {
        match self {
            Record::Bytes(bytes) => {
                let mut first = bytes.clone();
                let second = first.split_off(at);
                (Record::Bytes(first), Record::Bytes(second))
            }
            _ => todo!(),
        }
    }
}

#[derive(Debug, PartialEq, Eq, Clone)]
pub struct Identity {
    pub device_id: DeviceId,
    pub generation_id: String,
    pub name: String,
}

impl Identity {
    pub fn to_headers_map(&self) -> HashMap<String, String> {
        HashMap::from([
            ("Fk-DeviceId".to_owned(), self.device_id.0.clone()),
            ("Fk-Generation".to_owned(), self.generation_id.clone()),
            ("Fk-DeviceName".to_owned(), self.name.clone()),
        ])
    }

    pub fn from_bytes(bytes: &[u8]) -> Result<Identity> {
        use prost::Message;
        use protos::http::Identity as WireIdentity;
        let wire_identity = WireIdentity::decode(bytes)?;
        let device_id = DeviceId(hex::encode(wire_identity.device_id));
        let generation_id = hex::encode(wire_identity.generation_id);
        Ok(Identity {
            device_id,
            generation_id: generation_id,
            name: wire_identity.name,
        })
    }

    pub fn to_bytes(&self) -> Result<Vec<u8>> {
        use prost::Message;
        use protos::http::Identity as WireIdentity;
        let wire_identity = WireIdentity {
            device_id: hex::decode(self.device_id.0.clone())?,
            generation_id: hex::decode(self.generation_id.clone())?,
            name: self.name.clone(),
            ..Default::default()
        };
        Ok(wire_identity.encode_to_vec())
    }
}

#[derive(Debug, PartialEq, Eq)]
pub enum Message {
    Query,
    Statistics {
        nrecords: u64,
        identity: Identity,
    },
    Require(RecordRange),
    Records {
        head: u64,
        flags: u32,
        sequence: u32,
        records: Vec<Record>,
    },
    Batch {
        flags: u32,
        errors: u32,
    },
}

const FK_UDP_PROTOCOL_KIND_QUERY: u32 = 0;
const FK_UDP_PROTOCOL_KIND_STATISTICS: u32 = 1;
const FK_UDP_PROTOCOL_KIND_REQUIRE: u32 = 2;
const FK_UDP_PROTOCOL_KIND_RECORDS: u32 = 3;
const FK_UDP_PROTOCOL_KIND_BATCH: u32 = 4;

impl Message {
    pub fn numbered_records(&self) -> Result<Option<Vec<NumberedRecord>>> {
        match self {
            Message::Records {
                head,
                flags: _,
                sequence: _,
                records,
            } => Ok(Some(
                records
                    .into_iter()
                    .enumerate()
                    .map(|(i, r)| NumberedRecord::new(i as u64 + head, r.clone()))
                    .collect(),
            )),
            _ => Ok(None),
        }
    }

    pub(crate) fn write(&self, bytes: &mut Vec<u8>) -> Result<()> {
        let mut writer = Writer::new(bytes);

        match self {
            Message::Query => {
                writer.write_fixed32(FK_UDP_PROTOCOL_KIND_QUERY)?;
                Ok(())
            }
            Message::Statistics { nrecords, identity } => {
                let encoded = identity.to_bytes()?;

                writer.write_fixed32(FK_UDP_PROTOCOL_KIND_STATISTICS)?;
                writer.write_fixed32(*nrecords as u32)?;
                writer.write_bytes(&encoded)?;
                Ok(())
            }
            Message::Require(range) => {
                let nrecords = range.tail() - range.head() + 1;
                writer.write_fixed32(FK_UDP_PROTOCOL_KIND_REQUIRE)?;
                writer.write_fixed32(range.head() as u32)?;
                writer.write_fixed32(nrecords as u32)?;
                Ok(())
            }
            Message::Records {
                head,
                flags,
                sequence,
                records,
            } => {
                writer.write_fixed32(FK_UDP_PROTOCOL_KIND_RECORDS)?;
                writer.write_fixed32(*head as u32)?;
                writer.write_fixed32(*flags)?;
                writer.write_fixed32(*sequence)?;
                for record in records {
                    match record {
                        Record::Undelimited(bytes) => writer.write_bytes(bytes)?,
                        Record::Bytes(bytes) => {
                            // I really wish I could find a better way to do this.
                            for byte in bytes.iter() {
                                writer.write_u8(*byte)?;
                            }
                        }
                    }
                }
                Ok(())
            }
            Message::Batch { flags, errors } => {
                writer.write_fixed32(FK_UDP_PROTOCOL_KIND_BATCH)?;
                writer.write_fixed32(*flags)?;
                writer.write_fixed32(*errors as u32)?;
                Ok(())
            }
        }
    }

    pub(crate) fn log_received(&self) {
        match self {
            Message::Records {
                head: _head,
                flags: _flags,
                sequence: _sequence,
                records: _records,
            } => trace!("{:?}", self),
            _ => info!("{:?}", self),
        }
    }

    fn read_header(reader: &mut BytesReader, bytes: &[u8]) -> Result<(Self, Option<Vec<u8>>)> {
        let kind = reader.read_fixed32(bytes)?;

        match kind {
            FK_UDP_PROTOCOL_KIND_QUERY => Ok((Self::Query {}, None)),
            FK_UDP_PROTOCOL_KIND_STATISTICS => {
                let nrecords = reader.read_fixed32(bytes)? as u64;
                let identity_bytes = reader.read_bytes(bytes)?;
                let identity = Identity::from_bytes(identity_bytes)?;

                Ok((Self::Statistics { nrecords, identity }, None))
            }
            FK_UDP_PROTOCOL_KIND_REQUIRE => {
                let head = reader.read_fixed32(bytes)? as u64;
                let nrecords = reader.read_fixed32(bytes)? as u64;

                Ok((Self::Require(RecordRange::new(head, nrecords - 1)), None))
            }
            FK_UDP_PROTOCOL_KIND_RECORDS => {
                let head = reader.read_fixed32(bytes)? as u64;
                let flags = reader.read_fixed32(bytes)?;
                let sequence = reader.read_fixed32(bytes)?;
                let remaining = reader.len();
                let skip = bytes.len() - remaining;
                let payload = bytes[skip..].to_vec();

                Ok((
                    Self::Records {
                        head,
                        flags,
                        sequence,
                        records: Vec::new(),
                    },
                    Some(payload),
                ))
            }
            FK_UDP_PROTOCOL_KIND_BATCH => {
                let flags = reader.read_fixed32(bytes)?;
                let errors = reader.read_fixed32(bytes)?;

                Ok((Self::Batch { flags, errors }, None))
            }
            _ => todo!(),
        }
    }
}

#[derive(Default)]
pub(crate) struct MessageCodec {
    partial: Option<(u64, u32)>,
    buffered: Vec<u8>,
}

impl MessageCodec {
    pub(crate) fn try_read(&mut self, bytes: &[u8]) -> Result<Option<Message>> {
        let mut reader = BytesReader::from_bytes(bytes);

        let (header, payload) = Message::read_header(&mut reader, bytes)?;

        match payload {
            Some(payload) => match header {
                Message::Records {
                    head,
                    flags,
                    sequence,
                    records: _,
                } => {
                    if flags > 0 {
                        self.buffered.extend(payload);

                        match self.partial.clone() {
                            Some(partial) => {
                                if head != partial.0 {
                                    warn!(
                                        "Partial head mismatch ({} != {}) dropping",
                                        head, partial.0
                                    );
                                    self.reset();
                                }

                                if sequence != partial.1 + 1 {
                                    warn!(
                                        "Partial sequence mismatch ({} != {}) dropping",
                                        sequence, partial.1
                                    );
                                    self.reset();
                                }

                                let mut reader = BytesReader::from_bytes(&self.buffered);
                                let records = self.read_raw_records(&mut reader, &self.buffered)?;

                                match &records {
                                    Some(_) => {
                                        info!("Partial record #{}: Completed", head);
                                        self.reset();
                                    }
                                    None => {
                                        info!("Partial record #{}: Waiting for remainder", head);
                                    }
                                };

                                Ok(records.map(|records| Message::Records {
                                    head,
                                    flags: 0,
                                    sequence: 0,
                                    records,
                                }))
                            }
                            None => {
                                self.partial = Some((head, sequence));

                                // No need to try parsing as this is the first partial packet.
                                Ok(None)
                            }
                        }
                    } else {
                        let records = self.read_raw_records(&mut reader, bytes)?;

                        Ok(Some(Message::Records {
                            head,
                            flags,
                            sequence,
                            records: records.ok_or(anyhow!("Error parsing records"))?,
                        }))
                    }
                }
                _ => todo!(),
            },
            None => Ok(Some(header)),
        }
    }

    fn reset(&mut self) {
        self.partial = None;
        self.buffered.clear();
    }

    fn read_raw_records(
        &self,
        reader: &mut BytesReader,
        bytes: &[u8],
    ) -> Result<Option<Vec<Record>>> {
        let mut records = vec![];

        while !reader.is_eof() {
            match reader.read_bytes(bytes) {
                Ok(record) => records.push(Record::Undelimited(record.into())),
                Err(_) => return Ok(None),
            }
        }

        Ok(Some(records))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    pub fn test_serialization_query() -> Result<()> {
        let message = Message::Query;
        let mut buffer = Vec::new();
        message.write(&mut buffer)?;

        let mut codec = MessageCodec::default();

        assert_eq!(codec.try_read(&buffer)?, Some(Message::Query));

        Ok(())
    }

    #[test]
    pub fn test_serialization_statistics() -> Result<()> {
        let message = Message::Statistics {
            nrecords: 100,
            identity: Identity {
                device_id: DeviceId("0011aabbccddee".to_owned()),
                generation_id: "0011aabbccddee".to_owned(),
                name: "Name".to_owned(),
            },
        };
        let mut buffer = Vec::new();
        message.write(&mut buffer)?;

        let mut codec = MessageCodec::default();

        assert_eq!(
            codec.try_read(&buffer)?,
            Some(Message::Statistics {
                nrecords: 100,
                identity: Identity {
                    device_id: DeviceId("0011aabbccddee".to_owned()),
                    generation_id: "0011aabbccddee".to_owned(),
                    name: "Name".to_owned(),
                },
            })
        );

        Ok(())
    }

    #[test]
    pub fn test_serialization_batch() -> Result<()> {
        let message = Message::Batch {
            flags: 0xff,
            errors: 0xff,
        };
        let mut buffer = Vec::new();
        message.write(&mut buffer)?;

        let mut codec = MessageCodec::default();

        assert_eq!(
            codec.try_read(&buffer)?,
            Some(Message::Batch {
                flags: 0xff,
                errors: 0xff
            })
        );

        Ok(())
    }

    #[test]
    pub fn test_serialization_require() -> Result<()> {
        let message = Message::Require(RecordRange::new(0, 100));
        let mut buffer = Vec::new();
        message.write(&mut buffer)?;

        let mut codec = MessageCodec::default();

        assert_eq!(
            codec.try_read(&buffer)?,
            Some(Message::Require(RecordRange::new(0, 100)))
        );

        Ok(())
    }

    #[test]
    pub fn test_serialization_records_simple() -> Result<()> {
        let r1 = Record::new_all_zeros(166);
        let r2 = Record::new_all_zeros(212);
        let records = vec![r1, r2];
        let message = Message::Records {
            head: 32768,
            flags: 0,
            sequence: 0,
            records: records.clone(),
        };
        let mut buffer = Vec::new();
        message.write(&mut buffer)?;

        let mut codec = MessageCodec::default();

        assert_eq!(
            codec.try_read(&buffer)?,
            Some(Message::Records {
                head: 32768,
                flags: 0,
                sequence: 0,
                records: records
            })
        );

        Ok(())
    }

    #[test]
    pub fn test_serialization_records_partial() -> Result<()> {
        let original = Record::new_all_zeros(1024);
        let r1 = original.clone().to_delimited()?;
        let (first, second) = r1.split_off(386);

        let m1 = Message::Records {
            head: 32768,
            flags: 1,
            sequence: 0,
            records: vec![first],
        };
        let m2 = Message::Records {
            head: 32768,
            flags: 1,
            sequence: 1,
            records: vec![second],
        };

        let mut b1 = Vec::new();
        m1.write(&mut b1)?;
        let mut b2 = Vec::new();
        m2.write(&mut b2)?;

        let mut codec = MessageCodec::default();

        assert_eq!(codec.try_read(&b1)?, None);

        assert_eq!(
            codec.try_read(&b2)?,
            Some(Message::Records {
                head: 32768,
                flags: 0,
                sequence: 0,
                records: vec![original]
            })
        );

        Ok(())
    }
}
