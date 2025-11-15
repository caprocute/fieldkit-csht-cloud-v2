#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct DeviceLocation {
    #[prost(uint32, tag = "7")]
    pub enabled: u32,
    #[prost(uint32, tag = "1")]
    pub fix: u32,
    #[prost(int64, tag = "2")]
    pub time: i64,
    #[prost(float, tag = "3")]
    pub longitude: f32,
    #[prost(float, tag = "4")]
    pub latitude: f32,
    #[prost(float, tag = "5")]
    pub altitude: f32,
    #[prost(float, repeated, tag = "6")]
    pub coordinates: ::prost::alloc::vec::Vec<f32>,
    #[prost(uint32, tag = "8")]
    pub satellites: u32,
    #[prost(uint32, tag = "9")]
    pub hdop: u32,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct SensorReading {
    #[prost(uint64, tag = "1")]
    pub reading: u64,
    #[prost(int64, tag = "2")]
    pub time: i64,
    #[prost(uint32, tag = "3")]
    pub sensor: u32,
    #[prost(float, tag = "4")]
    pub value: f32,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct LoggedReading {
    #[prost(uint32, tag = "1")]
    pub version: u32,
    #[prost(message, optional, tag = "2")]
    pub location: ::core::option::Option<DeviceLocation>,
    #[prost(message, optional, tag = "3")]
    pub reading: ::core::option::Option<SensorReading>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct SensorAndValue {
    #[prost(uint32, tag = "1")]
    pub sensor: u32,
    #[prost(bool, tag = "6")]
    pub has_calibration: bool,
    #[prost(oneof = "sensor_and_value::Calibrated", tags = "4, 2")]
    pub calibrated: ::core::option::Option<sensor_and_value::Calibrated>,
    #[prost(oneof = "sensor_and_value::Uncalibrated", tags = "5, 3")]
    pub uncalibrated: ::core::option::Option<sensor_and_value::Uncalibrated>,
}
/// Nested message and enum types in `SensorAndValue`.
pub mod sensor_and_value {
    #[allow(clippy::derive_partial_eq_without_eq)]
    #[derive(Clone, PartialEq, ::prost::Oneof)]
    pub enum Calibrated {
        #[prost(bool, tag = "4")]
        CalibratedNull(bool),
        #[prost(float, tag = "2")]
        CalibratedValue(f32),
    }
    #[allow(clippy::derive_partial_eq_without_eq)]
    #[derive(Clone, PartialEq, ::prost::Oneof)]
    pub enum Uncalibrated {
        #[prost(bool, tag = "5")]
        UncalibratedNull(bool),
        #[prost(float, tag = "3")]
        UncalibratedValue(f32),
    }
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct ModuleHeader {
    #[prost(uint32, tag = "1")]
    pub manufacturer: u32,
    #[prost(uint32, tag = "2")]
    pub kind: u32,
    #[prost(uint32, tag = "3")]
    pub version: u32,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct ModuleInfo {
    #[prost(uint32, tag = "1")]
    pub position: u32,
    #[prost(uint32, tag = "2")]
    pub address: u32,
    #[prost(string, tag = "3")]
    pub name: ::prost::alloc::string::String,
    #[prost(message, optional, tag = "4")]
    pub header: ::core::option::Option<ModuleHeader>,
    #[prost(message, optional, tag = "5")]
    pub firmware: ::core::option::Option<Firmware>,
    #[prost(message, repeated, tag = "6")]
    pub sensors: ::prost::alloc::vec::Vec<SensorInfo>,
    #[prost(bytes = "vec", tag = "7")]
    pub id: ::prost::alloc::vec::Vec<u8>,
    #[prost(uint32, tag = "8")]
    pub flags: u32,
    #[prost(bytes = "vec", tag = "9")]
    pub configuration: ::prost::alloc::vec::Vec<u8>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct SensorInfo {
    #[prost(uint32, tag = "1")]
    pub number: u32,
    #[prost(string, tag = "2")]
    pub name: ::prost::alloc::string::String,
    #[prost(string, tag = "3")]
    pub unit_of_measure: ::prost::alloc::string::String,
    #[prost(string, tag = "5")]
    pub uncalibrated_unit_of_measure: ::prost::alloc::string::String,
    #[prost(uint32, tag = "4")]
    pub flags: u32,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct Firmware {
    #[prost(string, tag = "1")]
    pub version: ::prost::alloc::string::String,
    #[prost(string, tag = "2")]
    pub build: ::prost::alloc::string::String,
    #[prost(string, tag = "3")]
    pub number: ::prost::alloc::string::String,
    #[prost(uint64, tag = "4")]
    pub timestamp: u64,
    #[prost(string, tag = "5")]
    pub hash: ::prost::alloc::string::String,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct Metadata {
    #[prost(bytes = "vec", tag = "1")]
    pub device_id: ::prost::alloc::vec::Vec<u8>,
    #[prost(int64, tag = "2")]
    pub time: i64,
    #[prost(string, tag = "3")]
    pub git: ::prost::alloc::string::String,
    #[prost(string, tag = "7")]
    pub build: ::prost::alloc::string::String,
    #[prost(uint32, tag = "4")]
    pub reset_cause: u32,
    #[prost(message, repeated, tag = "5")]
    pub sensors: ::prost::alloc::vec::Vec<SensorInfo>,
    #[prost(message, repeated, tag = "6")]
    pub modules: ::prost::alloc::vec::Vec<ModuleInfo>,
    #[prost(message, optional, tag = "8")]
    pub firmware: ::core::option::Option<Firmware>,
    #[prost(bytes = "vec", tag = "9")]
    pub generation: ::prost::alloc::vec::Vec<u8>,
    #[prost(uint64, tag = "10")]
    pub record: u64,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct Status {
    #[prost(int64, tag = "1")]
    pub time: i64,
    #[prost(uint32, tag = "2")]
    pub uptime: u32,
    #[prost(float, tag = "3")]
    pub battery: f32,
    #[prost(uint32, tag = "4")]
    pub memory: u32,
    #[prost(uint64, tag = "5")]
    pub busy: u64,
    #[prost(uint64, tag = "6")]
    pub wifi_enabled: u64,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct LogMessage {
    #[prost(int64, tag = "1")]
    pub time: i64,
    #[prost(uint32, tag = "2")]
    pub uptime: u32,
    #[prost(uint32, tag = "3")]
    pub level: u32,
    #[prost(string, tag = "4")]
    pub facility: ::prost::alloc::string::String,
    #[prost(string, tag = "5")]
    pub message: ::prost::alloc::string::String,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct SensorGroup {
    #[prost(uint32, tag = "1")]
    pub module: u32,
    #[prost(int64, tag = "3")]
    pub time: i64,
    #[prost(message, repeated, tag = "2")]
    pub readings: ::prost::alloc::vec::Vec<SensorAndValue>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct Readings {
    #[prost(int64, tag = "1")]
    pub time: i64,
    #[prost(uint64, tag = "2")]
    pub reading: u64,
    #[prost(uint32, tag = "3")]
    pub flags: u32,
    #[prost(uint64, tag = "6")]
    pub meta: u64,
    #[prost(uint32, tag = "7")]
    pub uptime: u32,
    #[prost(message, optional, tag = "4")]
    pub location: ::core::option::Option<DeviceLocation>,
    #[prost(message, repeated, tag = "5")]
    pub sensor_groups: ::prost::alloc::vec::Vec<SensorGroup>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct Interval {
    #[prost(uint64, tag = "1")]
    pub start: u64,
    #[prost(uint64, tag = "2")]
    pub end: u64,
    #[prost(uint32, tag = "3")]
    pub interval: u32,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct JobSchedule {
    #[prost(bytes = "vec", tag = "1")]
    pub cron: ::prost::alloc::vec::Vec<u8>,
    #[prost(uint32, tag = "2")]
    pub interval: u32,
    #[prost(uint32, tag = "3")]
    pub repeated: u32,
    #[prost(uint32, tag = "4")]
    pub duration: u32,
    #[prost(uint32, tag = "5")]
    pub jitter: u32,
    #[prost(message, repeated, tag = "6")]
    pub intervals: ::prost::alloc::vec::Vec<Interval>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct Schedule {
    #[prost(message, optional, tag = "1")]
    pub readings: ::core::option::Option<JobSchedule>,
    #[prost(message, optional, tag = "2")]
    pub network: ::core::option::Option<JobSchedule>,
    #[prost(message, optional, tag = "3")]
    pub lora: ::core::option::Option<JobSchedule>,
    #[prost(message, optional, tag = "4")]
    pub gps: ::core::option::Option<JobSchedule>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct Identity {
    #[prost(string, tag = "1")]
    pub name: ::prost::alloc::string::String,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct Condition {
    #[prost(uint32, tag = "1")]
    pub flags: u32,
    #[prost(uint32, tag = "2")]
    pub recording: u32,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct NetworkInfo {
    #[prost(string, tag = "1")]
    pub ssid: ::prost::alloc::string::String,
    #[prost(string, tag = "2")]
    pub password: ::prost::alloc::string::String,
    #[prost(bool, tag = "3")]
    pub create: bool,
    #[prost(bool, tag = "4")]
    pub preferred: bool,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct WifiTransmission {
    #[prost(string, tag = "1")]
    pub url: ::prost::alloc::string::String,
    #[prost(string, tag = "2")]
    pub token: ::prost::alloc::string::String,
    #[prost(bool, tag = "3")]
    pub enabled: bool,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct TransmissionSettings {
    #[prost(message, optional, tag = "1")]
    pub wifi: ::core::option::Option<WifiTransmission>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct NetworkSettings {
    #[prost(message, repeated, tag = "1")]
    pub networks: ::prost::alloc::vec::Vec<NetworkInfo>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct LoraSettings {
    #[prost(bytes = "vec", tag = "1")]
    pub device_eui: ::prost::alloc::vec::Vec<u8>,
    #[prost(bytes = "vec", tag = "2")]
    pub app_key: ::prost::alloc::vec::Vec<u8>,
    #[prost(bytes = "vec", tag = "3")]
    pub join_eui: ::prost::alloc::vec::Vec<u8>,
    #[prost(uint32, tag = "4")]
    pub frequency_band: u32,
    #[prost(bytes = "vec", tag = "5")]
    pub device_address: ::prost::alloc::vec::Vec<u8>,
    #[prost(bytes = "vec", tag = "6")]
    pub network_session_key: ::prost::alloc::vec::Vec<u8>,
    #[prost(bytes = "vec", tag = "7")]
    pub app_session_key: ::prost::alloc::vec::Vec<u8>,
    #[prost(uint32, tag = "8")]
    pub uplink_counter: u32,
    #[prost(uint32, tag = "9")]
    pub downlink_counter: u32,
    #[prost(uint32, tag = "10")]
    pub rx_delay1: u32,
    #[prost(uint32, tag = "11")]
    pub rx_delay2: u32,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct EventDetails {
    #[prost(bytes = "vec", tag = "1")]
    pub data: ::prost::alloc::vec::Vec<u8>,
    #[prost(int32, repeated, tag = "2")]
    pub integers: ::prost::alloc::vec::Vec<i32>,
    #[prost(float, repeated, tag = "3")]
    pub reals: ::prost::alloc::vec::Vec<f32>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct Event {
    #[prost(enumeration = "EventSystem", tag = "1")]
    pub system: i32,
    #[prost(enumeration = "Severity", tag = "2")]
    pub severity: i32,
    #[prost(uint32, tag = "3")]
    pub code: u32,
    #[prost(uint32, tag = "4")]
    pub time: u32,
    #[prost(message, optional, tag = "5")]
    pub details: ::core::option::Option<EventDetails>,
    #[prost(bytes = "vec", tag = "6")]
    pub debug: ::prost::alloc::vec::Vec<u8>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct DataRecord {
    #[prost(message, optional, tag = "1")]
    pub logged_reading: ::core::option::Option<LoggedReading>,
    #[prost(message, optional, tag = "2")]
    pub metadata: ::core::option::Option<Metadata>,
    #[prost(message, optional, tag = "3")]
    pub log: ::core::option::Option<LogMessage>,
    #[prost(message, repeated, tag = "13")]
    pub logs: ::prost::alloc::vec::Vec<LogMessage>,
    #[prost(message, optional, tag = "4")]
    pub status: ::core::option::Option<Status>,
    #[prost(message, optional, tag = "5")]
    pub readings: ::core::option::Option<Readings>,
    #[prost(message, repeated, tag = "6")]
    pub modules: ::prost::alloc::vec::Vec<ModuleInfo>,
    #[prost(message, optional, tag = "7")]
    pub schedule: ::core::option::Option<Schedule>,
    #[prost(uint64, tag = "8")]
    pub meta: u64,
    #[prost(message, optional, tag = "9")]
    pub identity: ::core::option::Option<Identity>,
    #[prost(message, optional, tag = "10")]
    pub condition: ::core::option::Option<Condition>,
    #[prost(message, optional, tag = "11")]
    pub lora: ::core::option::Option<LoraSettings>,
    #[prost(message, optional, tag = "12")]
    pub network: ::core::option::Option<NetworkSettings>,
    #[prost(message, optional, tag = "14")]
    pub transmission: ::core::option::Option<TransmissionSettings>,
    #[prost(message, repeated, tag = "15")]
    pub events: ::prost::alloc::vec::Vec<Event>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct SignedRecord {
    #[prost(enumeration = "SignedRecordKind", tag = "1")]
    pub kind: i32,
    #[prost(int64, tag = "2")]
    pub time: i64,
    #[prost(bytes = "vec", tag = "3")]
    pub data: ::prost::alloc::vec::Vec<u8>,
    #[prost(bytes = "vec", tag = "4")]
    pub hash: ::prost::alloc::vec::Vec<u8>,
    #[prost(uint64, tag = "5")]
    pub record: u64,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct LoraRecord {
    #[prost(bytes = "vec", tag = "1")]
    pub device_id: ::prost::alloc::vec::Vec<u8>,
    #[prost(int64, tag = "2")]
    pub time: i64,
    #[prost(uint64, tag = "3")]
    pub number: u64,
    #[prost(uint32, tag = "4")]
    pub module: u32,
    #[prost(uint64, tag = "5")]
    pub sensor: u64,
    #[prost(float, repeated, tag = "6")]
    pub values: ::prost::alloc::vec::Vec<f32>,
    #[prost(bytes = "vec", tag = "7")]
    pub data: ::prost::alloc::vec::Vec<u8>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct CalibrationPoint {
    #[prost(float, repeated, tag = "1")]
    pub references: ::prost::alloc::vec::Vec<f32>,
    #[prost(float, repeated, tag = "2")]
    pub uncalibrated: ::prost::alloc::vec::Vec<f32>,
    #[prost(float, repeated, tag = "3")]
    pub factory: ::prost::alloc::vec::Vec<f32>,
    #[prost(bytes = "vec", repeated, tag = "4")]
    pub adc: ::prost::alloc::vec::Vec<::prost::alloc::vec::Vec<u8>>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct CalibrationCoefficients {
    #[prost(float, repeated, tag = "1")]
    pub values: ::prost::alloc::vec::Vec<f32>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct Calibration {
    #[prost(enumeration = "CurveType", tag = "1")]
    pub r#type: i32,
    #[prost(uint32, tag = "2")]
    pub time: u32,
    #[prost(uint32, tag = "6")]
    pub kind: u32,
    #[prost(message, repeated, tag = "3")]
    pub points: ::prost::alloc::vec::Vec<CalibrationPoint>,
    #[prost(message, optional, tag = "4")]
    pub coefficients: ::core::option::Option<CalibrationCoefficients>,
    #[prost(message, optional, tag = "5")]
    pub firmware: ::core::option::Option<Firmware>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct ModuleConfiguration {
    /// DEPRECATED
    #[prost(message, optional, tag = "1")]
    pub calibration: ::core::option::Option<Calibration>,
    #[prost(message, repeated, tag = "2")]
    pub calibrations: ::prost::alloc::vec::Vec<Calibration>,
}
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord, ::prost::Enumeration)]
#[repr(i32)]
pub enum DownloadFlags {
    ReadingFlagsNone = 0,
    ReadingFlagsNotRecording = 1,
    ReadingFlagsManual = 2,
}
impl DownloadFlags {
    /// String value of the enum field names used in the ProtoBuf definition.
    ///
    /// The values are not transformed in any way and thus are considered stable
    /// (if the ProtoBuf definition does not change) and safe for programmatic use.
    pub fn as_str_name(&self) -> &'static str {
        match self {
            DownloadFlags::ReadingFlagsNone => "READING_FLAGS_NONE",
            DownloadFlags::ReadingFlagsNotRecording => "READING_FLAGS_NOT_RECORDING",
            DownloadFlags::ReadingFlagsManual => "READING_FLAGS_MANUAL",
        }
    }
    /// Creates an enum from field names used in the ProtoBuf definition.
    pub fn from_str_name(value: &str) -> ::core::option::Option<Self> {
        match value {
            "READING_FLAGS_NONE" => Some(Self::ReadingFlagsNone),
            "READING_FLAGS_NOT_RECORDING" => Some(Self::ReadingFlagsNotRecording),
            "READING_FLAGS_MANUAL" => Some(Self::ReadingFlagsManual),
            _ => None,
        }
    }
}
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord, ::prost::Enumeration)]
#[repr(i32)]
pub enum ConditionFlags {
    None = 0,
    Recording = 1,
}
impl ConditionFlags {
    /// String value of the enum field names used in the ProtoBuf definition.
    ///
    /// The values are not transformed in any way and thus are considered stable
    /// (if the ProtoBuf definition does not change) and safe for programmatic use.
    pub fn as_str_name(&self) -> &'static str {
        match self {
            ConditionFlags::None => "CONDITION_FLAGS_NONE",
            ConditionFlags::Recording => "CONDITION_FLAGS_RECORDING",
        }
    }
    /// Creates an enum from field names used in the ProtoBuf definition.
    pub fn from_str_name(value: &str) -> ::core::option::Option<Self> {
        match value {
            "CONDITION_FLAGS_NONE" => Some(Self::None),
            "CONDITION_FLAGS_RECORDING" => Some(Self::Recording),
            _ => None,
        }
    }
}
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord, ::prost::Enumeration)]
#[repr(i32)]
pub enum EventSystem {
    None = 0,
    Restart = 1,
    Battery = 2,
    Memory = 3,
    Sensor = 4,
    Wifi = 5,
    Lora = 6,
    User = 7,
}
impl EventSystem {
    /// String value of the enum field names used in the ProtoBuf definition.
    ///
    /// The values are not transformed in any way and thus are considered stable
    /// (if the ProtoBuf definition does not change) and safe for programmatic use.
    pub fn as_str_name(&self) -> &'static str {
        match self {
            EventSystem::None => "EVENT_SYSTEM_NONE",
            EventSystem::Restart => "EVENT_SYSTEM_RESTART",
            EventSystem::Battery => "EVENT_SYSTEM_BATTERY",
            EventSystem::Memory => "EVENT_SYSTEM_MEMORY",
            EventSystem::Sensor => "EVENT_SYSTEM_SENSOR",
            EventSystem::Wifi => "EVENT_SYSTEM_WIFI",
            EventSystem::Lora => "EVENT_SYSTEM_LORA",
            EventSystem::User => "EVENT_SYSTEM_USER",
        }
    }
    /// Creates an enum from field names used in the ProtoBuf definition.
    pub fn from_str_name(value: &str) -> ::core::option::Option<Self> {
        match value {
            "EVENT_SYSTEM_NONE" => Some(Self::None),
            "EVENT_SYSTEM_RESTART" => Some(Self::Restart),
            "EVENT_SYSTEM_BATTERY" => Some(Self::Battery),
            "EVENT_SYSTEM_MEMORY" => Some(Self::Memory),
            "EVENT_SYSTEM_SENSOR" => Some(Self::Sensor),
            "EVENT_SYSTEM_WIFI" => Some(Self::Wifi),
            "EVENT_SYSTEM_LORA" => Some(Self::Lora),
            "EVENT_SYSTEM_USER" => Some(Self::User),
            _ => None,
        }
    }
}
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord, ::prost::Enumeration)]
#[repr(i32)]
pub enum Severity {
    Info = 0,
    Warning = 1,
    Error = 2,
}
impl Severity {
    /// String value of the enum field names used in the ProtoBuf definition.
    ///
    /// The values are not transformed in any way and thus are considered stable
    /// (if the ProtoBuf definition does not change) and safe for programmatic use.
    pub fn as_str_name(&self) -> &'static str {
        match self {
            Severity::Info => "SEVERITY_INFO",
            Severity::Warning => "SEVERITY_WARNING",
            Severity::Error => "SEVERITY_ERROR",
        }
    }
    /// Creates an enum from field names used in the ProtoBuf definition.
    pub fn from_str_name(value: &str) -> ::core::option::Option<Self> {
        match value {
            "SEVERITY_INFO" => Some(Self::Info),
            "SEVERITY_WARNING" => Some(Self::Warning),
            "SEVERITY_ERROR" => Some(Self::Error),
            _ => None,
        }
    }
}
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord, ::prost::Enumeration)]
#[repr(i32)]
pub enum SignedRecordKind {
    None = 0,
    Modules = 1,
    Schedule = 2,
    State = 3,
    RawState = 4,
    Events = 5,
    Other = 255,
}
impl SignedRecordKind {
    /// String value of the enum field names used in the ProtoBuf definition.
    ///
    /// The values are not transformed in any way and thus are considered stable
    /// (if the ProtoBuf definition does not change) and safe for programmatic use.
    pub fn as_str_name(&self) -> &'static str {
        match self {
            SignedRecordKind::None => "SIGNED_RECORD_KIND_NONE",
            SignedRecordKind::Modules => "SIGNED_RECORD_KIND_MODULES",
            SignedRecordKind::Schedule => "SIGNED_RECORD_KIND_SCHEDULE",
            SignedRecordKind::State => "SIGNED_RECORD_KIND_STATE",
            SignedRecordKind::RawState => "SIGNED_RECORD_KIND_RAW_STATE",
            SignedRecordKind::Events => "SIGNED_RECORD_KIND_EVENTS",
            SignedRecordKind::Other => "SIGNED_RECORD_KIND_OTHER",
        }
    }
    /// Creates an enum from field names used in the ProtoBuf definition.
    pub fn from_str_name(value: &str) -> ::core::option::Option<Self> {
        match value {
            "SIGNED_RECORD_KIND_NONE" => Some(Self::None),
            "SIGNED_RECORD_KIND_MODULES" => Some(Self::Modules),
            "SIGNED_RECORD_KIND_SCHEDULE" => Some(Self::Schedule),
            "SIGNED_RECORD_KIND_STATE" => Some(Self::State),
            "SIGNED_RECORD_KIND_RAW_STATE" => Some(Self::RawState),
            "SIGNED_RECORD_KIND_EVENTS" => Some(Self::Events),
            "SIGNED_RECORD_KIND_OTHER" => Some(Self::Other),
            _ => None,
        }
    }
}
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord, ::prost::Enumeration)]
#[repr(i32)]
pub enum CurveType {
    CurveNone = 0,
    CurveLinear = 1,
    CurvePower = 2,
    CurveLogarithmic = 3,
    CurveExponential = 4,
}
impl CurveType {
    /// String value of the enum field names used in the ProtoBuf definition.
    ///
    /// The values are not transformed in any way and thus are considered stable
    /// (if the ProtoBuf definition does not change) and safe for programmatic use.
    pub fn as_str_name(&self) -> &'static str {
        match self {
            CurveType::CurveNone => "CURVE_NONE",
            CurveType::CurveLinear => "CURVE_LINEAR",
            CurveType::CurvePower => "CURVE_POWER",
            CurveType::CurveLogarithmic => "CURVE_LOGARITHMIC",
            CurveType::CurveExponential => "CURVE_EXPONENTIAL",
        }
    }
    /// Creates an enum from field names used in the ProtoBuf definition.
    pub fn from_str_name(value: &str) -> ::core::option::Option<Self> {
        match value {
            "CURVE_NONE" => Some(Self::CurveNone),
            "CURVE_LINEAR" => Some(Self::CurveLinear),
            "CURVE_POWER" => Some(Self::CurvePower),
            "CURVE_LOGARITHMIC" => Some(Self::CurveLogarithmic),
            "CURVE_EXPONENTIAL" => Some(Self::CurveExponential),
            _ => None,
        }
    }
}
