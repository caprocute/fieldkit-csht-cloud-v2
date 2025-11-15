#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct QueryCapabilities {
    #[prost(uint32, tag = "1")]
    pub version: u32,
    #[prost(uint32, tag = "2")]
    pub caller_time: u32,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct LiveValue {
    #[prost(bool, tag = "1")]
    pub valid: bool,
    #[prost(float, tag = "2")]
    pub value: f32,
    #[prost(float, tag = "3")]
    pub uncalibrated: f32,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct SensorCapabilities {
    #[prost(uint32, tag = "1")]
    pub number: u32,
    #[prost(uint32, tag = "2")]
    pub module: u32,
    #[prost(string, tag = "3")]
    pub name: ::prost::alloc::string::String,
    #[prost(uint32, tag = "4")]
    pub frequency: u32,
    #[prost(string, tag = "5")]
    pub unit_of_measure: ::prost::alloc::string::String,
    #[prost(string, tag = "9")]
    pub uncalibrated_unit_of_measure: ::prost::alloc::string::String,
    /// v2
    #[prost(string, tag = "6")]
    pub path: ::prost::alloc::string::String,
    #[prost(uint32, tag = "7")]
    pub flags: u32,
    #[prost(message, optional, tag = "8")]
    pub value: ::core::option::Option<LiveValue>,
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
pub struct ModuleCapabilities {
    #[prost(uint32, tag = "1")]
    pub position: u32,
    #[prost(string, tag = "2")]
    pub name: ::prost::alloc::string::String,
    #[prost(message, repeated, tag = "3")]
    pub sensors: ::prost::alloc::vec::Vec<SensorCapabilities>,
    /// v2
    #[prost(string, tag = "4")]
    pub path: ::prost::alloc::string::String,
    #[prost(uint32, tag = "5")]
    pub flags: u32,
    #[prost(bytes = "vec", tag = "6")]
    pub id: ::prost::alloc::vec::Vec<u8>,
    #[prost(message, optional, tag = "7")]
    pub header: ::core::option::Option<ModuleHeader>,
    #[prost(bytes = "vec", tag = "8")]
    pub configuration: ::prost::alloc::vec::Vec<u8>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct Capabilities {
    #[prost(uint32, tag = "1")]
    pub version: u32,
    #[prost(bytes = "vec", tag = "2")]
    pub device_id: ::prost::alloc::vec::Vec<u8>,
    #[prost(string, tag = "3")]
    pub name: ::prost::alloc::string::String,
    #[prost(message, repeated, tag = "4")]
    pub modules: ::prost::alloc::vec::Vec<ModuleCapabilities>,
    #[prost(message, repeated, tag = "5")]
    pub sensors: ::prost::alloc::vec::Vec<SensorCapabilities>,
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
    #[prost(bool, tag = "5")]
    pub keeping: bool,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct NetworkSettings {
    #[prost(int32, tag = "1")]
    pub create_access_point: i32,
    #[prost(message, optional, tag = "3")]
    pub connected: ::core::option::Option<NetworkInfo>,
    #[prost(string, tag = "4")]
    pub mac_address: ::prost::alloc::string::String,
    #[prost(bool, tag = "5")]
    pub modifying: bool,
    #[prost(bool, tag = "6")]
    pub supports_udp: bool,
    #[prost(message, repeated, tag = "2")]
    pub networks: ::prost::alloc::vec::Vec<NetworkInfo>,
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
    #[prost(uint64, tag = "6")]
    pub logical_address: u64,
    #[prost(string, tag = "7")]
    pub name: ::prost::alloc::string::String,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct Identity {
    #[prost(string, tag = "1")]
    pub device: ::prost::alloc::string::String,
    #[prost(string, tag = "2")]
    pub stream: ::prost::alloc::string::String,
    #[prost(bytes = "vec", tag = "3")]
    pub device_id: ::prost::alloc::vec::Vec<u8>,
    #[prost(string, tag = "4")]
    pub firmware: ::prost::alloc::string::String,
    #[prost(string, tag = "5")]
    pub build: ::prost::alloc::string::String,
    #[prost(string, tag = "8")]
    pub number: ::prost::alloc::string::String,
    /// v2
    #[prost(string, tag = "6")]
    pub name: ::prost::alloc::string::String,
    #[prost(bytes = "vec", tag = "7")]
    pub generation_id: ::prost::alloc::vec::Vec<u8>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct ConfigureSensorQuery {
    #[prost(uint32, tag = "1")]
    pub id: u32,
    #[prost(uint32, tag = "2")]
    pub frequency: u32,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct LiveDataPoll {
    #[prost(uint32, tag = "1")]
    pub interval: u32,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct LiveDataSample {
    #[prost(uint32, tag = "1")]
    pub sensor: u32,
    #[prost(uint64, tag = "2")]
    pub time: u64,
    #[prost(float, tag = "3")]
    pub value: f32,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct LiveData {
    #[prost(message, repeated, tag = "1")]
    pub samples: ::prost::alloc::vec::Vec<LiveDataSample>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct File {
    #[prost(uint32, tag = "1")]
    pub id: u32,
    #[prost(uint64, tag = "2")]
    pub time: u64,
    #[prost(uint64, tag = "3")]
    pub size: u64,
    #[prost(uint32, tag = "4")]
    pub version: u32,
    #[prost(string, tag = "5")]
    pub name: ::prost::alloc::string::String,
    #[prost(uint64, tag = "6")]
    pub maximum: u64,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct Files {
    #[prost(message, repeated, tag = "1")]
    pub files: ::prost::alloc::vec::Vec<File>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct DownloadFile {
    #[prost(uint32, tag = "1")]
    pub id: u32,
    #[prost(uint32, tag = "2")]
    pub offset: u32,
    #[prost(uint32, tag = "3")]
    pub length: u32,
    #[prost(uint32, tag = "4")]
    pub flags: u32,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct EraseFile {
    #[prost(uint32, tag = "1")]
    pub id: u32,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct FileData {
    #[prost(uint32, tag = "1")]
    pub offset: u32,
    #[prost(bytes = "vec", tag = "2")]
    pub data: ::prost::alloc::vec::Vec<u8>,
    #[prost(uint32, tag = "3")]
    pub size: u32,
    #[prost(uint32, tag = "4")]
    pub hash: u32,
    #[prost(uint32, tag = "5")]
    pub version: u32,
    #[prost(uint32, tag = "6")]
    pub id: u32,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct DeviceStatus {
    #[prost(uint32, tag = "1")]
    pub uptime: u32,
    #[prost(float, tag = "2")]
    pub battery_percentage: f32,
    #[prost(float, tag = "3")]
    pub battery_voltage: f32,
    #[prost(uint32, tag = "4")]
    pub gps_has_fix: u32,
    #[prost(uint32, tag = "5")]
    pub gps_satellites: u32,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct QueryModule {
    #[prost(uint32, tag = "1")]
    pub id: u32,
    #[prost(uint32, tag = "2")]
    pub address: u32,
    #[prost(bytes = "vec", tag = "3")]
    pub message: ::prost::alloc::vec::Vec<u8>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct ModuleReply {
    #[prost(uint32, tag = "1")]
    pub id: u32,
    #[prost(uint32, tag = "2")]
    pub address: u32,
    #[prost(bytes = "vec", tag = "3")]
    pub message: ::prost::alloc::vec::Vec<u8>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct WireMessageQuery {
    #[prost(enumeration = "QueryType", tag = "1")]
    pub r#type: i32,
    #[prost(message, optional, tag = "2")]
    pub query_capabilities: ::core::option::Option<QueryCapabilities>,
    #[prost(message, optional, tag = "3")]
    pub configure_sensor: ::core::option::Option<ConfigureSensorQuery>,
    #[prost(message, optional, tag = "8")]
    pub live_data_poll: ::core::option::Option<LiveDataPoll>,
    #[prost(message, optional, tag = "10")]
    pub download_file: ::core::option::Option<DownloadFile>,
    #[prost(message, optional, tag = "11")]
    pub erase_file: ::core::option::Option<EraseFile>,
    #[prost(message, optional, tag = "12")]
    pub network_settings: ::core::option::Option<NetworkSettings>,
    #[prost(message, optional, tag = "13")]
    pub identity: ::core::option::Option<Identity>,
    #[prost(message, optional, tag = "14")]
    pub module: ::core::option::Option<QueryModule>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct Error {
    #[prost(string, tag = "1")]
    pub message: ::prost::alloc::string::String,
    #[prost(uint32, tag = "2")]
    pub delay: u32,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct WireMessageReply {
    #[prost(enumeration = "ReplyType", tag = "1")]
    pub r#type: i32,
    #[prost(message, repeated, tag = "2")]
    pub errors: ::prost::alloc::vec::Vec<Error>,
    #[prost(message, optional, tag = "3")]
    pub capabilities: ::core::option::Option<Capabilities>,
    #[prost(message, optional, tag = "6")]
    pub live_data: ::core::option::Option<LiveData>,
    #[prost(message, optional, tag = "8")]
    pub files: ::core::option::Option<Files>,
    #[prost(message, optional, tag = "9")]
    pub file_data: ::core::option::Option<FileData>,
    #[prost(message, optional, tag = "10")]
    pub network_settings: ::core::option::Option<NetworkSettings>,
    #[prost(message, optional, tag = "11")]
    pub identity: ::core::option::Option<Identity>,
    #[prost(message, optional, tag = "12")]
    pub status: ::core::option::Option<DeviceStatus>,
    #[prost(message, optional, tag = "13")]
    pub module: ::core::option::Option<ModuleReply>,
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
pub struct Schedule {
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
pub struct Schedules {
    #[prost(bool, tag = "1")]
    pub modifying: bool,
    #[prost(message, optional, tag = "2")]
    pub readings: ::core::option::Option<Schedule>,
    #[prost(message, optional, tag = "3")]
    pub lora: ::core::option::Option<Schedule>,
    #[prost(message, optional, tag = "4")]
    pub network: ::core::option::Option<Schedule>,
    #[prost(message, optional, tag = "5")]
    pub gps: ::core::option::Option<Schedule>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct SelfCheck {
    #[prost(string, tag = "1")]
    pub key: ::prost::alloc::string::String,
    #[prost(uint32, tag = "2")]
    pub status: u32,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct HardwareStatus {
    #[prost(message, repeated, tag = "1")]
    pub self_checks: ::prost::alloc::vec::Vec<SelfCheck>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct GpsStatus {
    #[prost(uint32, tag = "7")]
    pub enabled: u32,
    #[prost(uint32, tag = "1")]
    pub fix: u32,
    #[prost(uint64, tag = "2")]
    pub time: u64,
    #[prost(uint32, tag = "3")]
    pub satellites: u32,
    #[prost(float, tag = "4")]
    pub longitude: f32,
    #[prost(float, tag = "5")]
    pub latitude: f32,
    #[prost(float, tag = "6")]
    pub altitude: f32,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct MemoryStatus {
    #[prost(uint32, tag = "1")]
    pub sram_available: u32,
    #[prost(uint32, tag = "2")]
    pub program_flash_available: u32,
    #[prost(uint32, tag = "3")]
    pub extended_memory_available: u32,
    #[prost(uint32, tag = "4")]
    pub data_memory_installed: u32,
    #[prost(uint32, tag = "5")]
    pub data_memory_used: u32,
    #[prost(float, tag = "6")]
    pub data_memory_consumption: f32,
    #[prost(message, repeated, tag = "7")]
    pub firmware: ::prost::alloc::vec::Vec<Firmware>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct BatteryStatus {
    #[prost(uint32, tag = "1")]
    pub voltage: u32,
    #[prost(uint32, tag = "2")]
    pub percentage: u32,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct SolarStatus {
    #[prost(uint32, tag = "1")]
    pub voltage: u32,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct PowerStatus {
    #[prost(message, optional, tag = "1")]
    pub battery: ::core::option::Option<BatteryStatus>,
    #[prost(message, optional, tag = "2")]
    pub solar: ::core::option::Option<SolarStatus>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct Status {
    #[prost(uint32, tag = "1")]
    pub version: u32,
    #[prost(uint32, tag = "2")]
    pub uptime: u32,
    #[prost(message, optional, tag = "3")]
    pub identity: ::core::option::Option<Identity>,
    #[prost(message, optional, tag = "4")]
    pub hardware: ::core::option::Option<HardwareStatus>,
    #[prost(message, optional, tag = "5")]
    pub power: ::core::option::Option<PowerStatus>,
    #[prost(message, optional, tag = "6")]
    pub memory: ::core::option::Option<MemoryStatus>,
    #[prost(message, optional, tag = "7")]
    pub gps: ::core::option::Option<GpsStatus>,
    #[prost(message, optional, tag = "8")]
    pub schedules: ::core::option::Option<Schedules>,
    #[prost(message, optional, tag = "9")]
    pub recording: ::core::option::Option<Recording>,
    #[prost(message, optional, tag = "10")]
    pub network: ::core::option::Option<NetworkSettings>,
    #[prost(uint64, tag = "11")]
    pub time: u64,
    #[prost(message, optional, tag = "12")]
    pub firmware: ::core::option::Option<Firmware>,
    #[prost(string, tag = "13")]
    pub logs: ::prost::alloc::string::String,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct Range {
    #[prost(uint32, tag = "1")]
    pub start: u32,
    #[prost(uint32, tag = "2")]
    pub end: u32,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct DownloadQuery {
    #[prost(uint32, tag = "1")]
    pub stream: u32,
    #[prost(message, repeated, tag = "3")]
    pub ranges: ::prost::alloc::vec::Vec<Range>,
    #[prost(uint32, repeated, tag = "4")]
    pub blocks: ::prost::alloc::vec::Vec<u32>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct Recording {
    #[prost(bool, tag = "1")]
    pub modifying: bool,
    #[prost(bool, tag = "2")]
    pub enabled: bool,
    #[prost(uint64, tag = "3")]
    pub started_time: u64,
    #[prost(message, optional, tag = "4")]
    pub location: ::core::option::Option<Location>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct LoraSettings {
    #[prost(bool, tag = "1")]
    pub available: bool,
    #[prost(bool, tag = "2")]
    pub modifying: bool,
    #[prost(bool, tag = "3")]
    pub clearing: bool,
    #[prost(bool, tag = "11")]
    pub verify: bool,
    #[prost(uint32, tag = "4")]
    pub frequency_band: u32,
    #[prost(bytes = "vec", tag = "5")]
    pub device_eui: ::prost::alloc::vec::Vec<u8>,
    #[prost(bytes = "vec", tag = "6")]
    pub app_key: ::prost::alloc::vec::Vec<u8>,
    #[prost(bytes = "vec", tag = "7")]
    pub join_eui: ::prost::alloc::vec::Vec<u8>,
    #[prost(bytes = "vec", tag = "8")]
    pub device_address: ::prost::alloc::vec::Vec<u8>,
    #[prost(bytes = "vec", tag = "9")]
    pub network_session_key: ::prost::alloc::vec::Vec<u8>,
    #[prost(bytes = "vec", tag = "10")]
    pub app_session_key: ::prost::alloc::vec::Vec<u8>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct Location {
    #[prost(bool, tag = "1")]
    pub modifying: bool,
    #[prost(float, tag = "2")]
    pub longitude: f32,
    #[prost(float, tag = "3")]
    pub latitude: f32,
    #[prost(uint64, tag = "4")]
    pub time: u64,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct WifiTransmission {
    #[prost(bool, tag = "1")]
    pub modifying: bool,
    #[prost(string, tag = "2")]
    pub url: ::prost::alloc::string::String,
    #[prost(string, tag = "3")]
    pub token: ::prost::alloc::string::String,
    #[prost(bool, tag = "4")]
    pub enabled: bool,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct Transmission {
    #[prost(message, optional, tag = "1")]
    pub wifi: ::core::option::Option<WifiTransmission>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct ListDirectory {
    #[prost(string, tag = "1")]
    pub path: ::prost::alloc::string::String,
    #[prost(uint32, tag = "2")]
    pub page: u32,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct HttpQuery {
    #[prost(enumeration = "QueryType", tag = "1")]
    pub r#type: i32,
    #[prost(message, optional, tag = "2")]
    pub identity: ::core::option::Option<Identity>,
    #[prost(message, optional, tag = "3")]
    pub recording: ::core::option::Option<Recording>,
    #[prost(message, optional, tag = "4")]
    pub schedules: ::core::option::Option<Schedules>,
    #[prost(message, optional, tag = "6")]
    pub network_settings: ::core::option::Option<NetworkSettings>,
    #[prost(message, optional, tag = "7")]
    pub lora_settings: ::core::option::Option<LoraSettings>,
    #[prost(message, optional, tag = "9")]
    pub locate: ::core::option::Option<Location>,
    #[prost(message, optional, tag = "10")]
    pub transmission: ::core::option::Option<Transmission>,
    #[prost(message, optional, tag = "11")]
    pub directory: ::core::option::Option<ListDirectory>,
    #[prost(uint32, tag = "5")]
    pub flags: u32,
    #[prost(uint64, tag = "8")]
    pub time: u64,
    #[prost(uint32, tag = "12")]
    pub counter: u32,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct DataStream {
    #[prost(uint32, tag = "1")]
    pub id: u32,
    #[prost(uint64, tag = "2")]
    pub time: u64,
    #[prost(uint64, tag = "3")]
    pub size: u64,
    #[prost(uint32, tag = "4")]
    pub version: u32,
    #[prost(uint64, tag = "5")]
    pub block: u64,
    #[prost(bytes = "vec", tag = "6")]
    pub hash: ::prost::alloc::vec::Vec<u8>,
    #[prost(string, tag = "7")]
    pub name: ::prost::alloc::string::String,
    #[prost(string, tag = "8")]
    pub path: ::prost::alloc::string::String,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct LiveSensorReading {
    #[prost(message, optional, tag = "1")]
    pub sensor: ::core::option::Option<SensorCapabilities>,
    #[prost(float, tag = "2")]
    pub value: f32,
    #[prost(float, tag = "3")]
    pub uncalibrated: f32,
    #[prost(float, tag = "4")]
    pub factory: f32,
    #[prost(bytes = "vec", tag = "5")]
    pub adc: ::prost::alloc::vec::Vec<u8>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct LiveModuleReadings {
    #[prost(message, optional, tag = "1")]
    pub module: ::core::option::Option<ModuleCapabilities>,
    #[prost(message, repeated, tag = "2")]
    pub readings: ::prost::alloc::vec::Vec<LiveSensorReading>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct LiveReadings {
    #[prost(uint64, tag = "1")]
    pub time: u64,
    #[prost(message, repeated, tag = "2")]
    pub modules: ::prost::alloc::vec::Vec<LiveModuleReadings>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct DirectoryEntry {
    #[prost(string, tag = "1")]
    pub name: ::prost::alloc::string::String,
    #[prost(string, tag = "2")]
    pub path: ::prost::alloc::string::String,
    #[prost(uint32, tag = "3")]
    pub size: u32,
    #[prost(bool, tag = "4")]
    pub directory: bool,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct DirectoryListing {
    #[prost(string, tag = "1")]
    pub path: ::prost::alloc::string::String,
    #[prost(uint32, tag = "3")]
    pub total_entries: u32,
    #[prost(message, repeated, tag = "2")]
    pub entries: ::prost::alloc::vec::Vec<DirectoryEntry>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct NearbyNetwork {
    #[prost(string, tag = "1")]
    pub ssid: ::prost::alloc::string::String,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct NearbyNetworks {
    #[prost(message, repeated, tag = "1")]
    pub networks: ::prost::alloc::vec::Vec<NearbyNetwork>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct HttpReply {
    #[prost(enumeration = "ReplyType", tag = "1")]
    pub r#type: i32,
    #[prost(message, repeated, tag = "2")]
    pub errors: ::prost::alloc::vec::Vec<Error>,
    #[prost(message, optional, tag = "3")]
    pub status: ::core::option::Option<Status>,
    #[prost(message, optional, tag = "4")]
    pub network_settings: ::core::option::Option<NetworkSettings>,
    #[prost(message, optional, tag = "8")]
    pub lora_settings: ::core::option::Option<LoraSettings>,
    #[prost(message, repeated, tag = "5")]
    pub modules: ::prost::alloc::vec::Vec<ModuleCapabilities>,
    #[prost(message, repeated, tag = "6")]
    pub streams: ::prost::alloc::vec::Vec<DataStream>,
    #[prost(message, repeated, tag = "7")]
    pub live_readings: ::prost::alloc::vec::Vec<LiveReadings>,
    #[prost(message, optional, tag = "9")]
    pub schedules: ::core::option::Option<Schedules>,
    #[prost(message, optional, tag = "10")]
    pub transmission: ::core::option::Option<Transmission>,
    #[prost(message, optional, tag = "11")]
    pub listing: ::core::option::Option<DirectoryListing>,
    #[prost(message, optional, tag = "12")]
    pub nearby_networks: ::core::option::Option<NearbyNetworks>,
    #[prost(bytes = "vec", tag = "13")]
    pub events: ::prost::alloc::vec::Vec<u8>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct ModuleHttpQuery {
    #[prost(enumeration = "ModuleQueryType", tag = "1")]
    pub r#type: i32,
    #[prost(message, repeated, tag = "2")]
    pub errors: ::prost::alloc::vec::Vec<Error>,
    #[prost(bytes = "vec", tag = "3")]
    pub configuration: ::prost::alloc::vec::Vec<u8>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct ModuleHttpReply {
    #[prost(enumeration = "ModuleReplyType", tag = "1")]
    pub r#type: i32,
    #[prost(message, repeated, tag = "2")]
    pub errors: ::prost::alloc::vec::Vec<Error>,
    #[prost(bytes = "vec", tag = "3")]
    pub configuration: ::prost::alloc::vec::Vec<u8>,
}
#[allow(clippy::derive_partial_eq_without_eq)]
#[derive(Clone, PartialEq, ::prost::Message)]
pub struct UdpMessage {
    #[prost(bytes = "vec", tag = "1")]
    pub device_id: ::prost::alloc::vec::Vec<u8>,
    #[prost(enumeration = "UdpStatus", tag = "2")]
    pub status: i32,
    #[prost(uint32, tag = "3")]
    pub counter: u32,
    #[prost(uint32, tag = "4")]
    pub port: u32,
}
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord, ::prost::Enumeration)]
#[repr(i32)]
pub enum QueryFlags {
    None = 0,
    Logs = 1,
}
impl QueryFlags {
    /// String value of the enum field names used in the ProtoBuf definition.
    ///
    /// The values are not transformed in any way and thus are considered stable
    /// (if the ProtoBuf definition does not change) and safe for programmatic use.
    pub fn as_str_name(&self) -> &'static str {
        match self {
            QueryFlags::None => "QUERY_FLAGS_NONE",
            QueryFlags::Logs => "QUERY_FLAGS_LOGS",
        }
    }
    /// Creates an enum from field names used in the ProtoBuf definition.
    pub fn from_str_name(value: &str) -> ::core::option::Option<Self> {
        match value {
            "QUERY_FLAGS_NONE" => Some(Self::None),
            "QUERY_FLAGS_LOGS" => Some(Self::Logs),
            _ => None,
        }
    }
}
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord, ::prost::Enumeration)]
#[repr(i32)]
pub enum QueryType {
    QueryNone = 0,
    QueryCapabilities = 1,
    QueryConfigureSensor = 2,
    QueryLiveDataPoll = 7,
    QuerySchedules = 8,
    QueryConfigureSchedules = 9,
    QueryFilesSd = 10,
    QueryDownloadFile = 11,
    QueryEraseFile = 12,
    QueryReset = 13,
    QueryNetworkSettings = 14,
    QueryConfigureNetworkSettings = 15,
    QueryScanModules = 16,
    QueryConfigureIdentity = 17,
    QueryStatus = 18,
    QueryModule = 19,
    QueryMetadata = 20,
    QueryFormat = 21,
    QueryGetReadings = 22,
    QueryTakeReadings = 23,
    QueryRecordingControl = 24,
    QueryConfigure = 25,
    QueryScanNetworks = 26,
    QueryFilesSpi = 27,
    QueryFilesQspi = 28,
}
impl QueryType {
    /// String value of the enum field names used in the ProtoBuf definition.
    ///
    /// The values are not transformed in any way and thus are considered stable
    /// (if the ProtoBuf definition does not change) and safe for programmatic use.
    pub fn as_str_name(&self) -> &'static str {
        match self {
            QueryType::QueryNone => "QUERY_NONE",
            QueryType::QueryCapabilities => "QUERY_CAPABILITIES",
            QueryType::QueryConfigureSensor => "QUERY_CONFIGURE_SENSOR",
            QueryType::QueryLiveDataPoll => "QUERY_LIVE_DATA_POLL",
            QueryType::QuerySchedules => "QUERY_SCHEDULES",
            QueryType::QueryConfigureSchedules => "QUERY_CONFIGURE_SCHEDULES",
            QueryType::QueryFilesSd => "QUERY_FILES_SD",
            QueryType::QueryDownloadFile => "QUERY_DOWNLOAD_FILE",
            QueryType::QueryEraseFile => "QUERY_ERASE_FILE",
            QueryType::QueryReset => "QUERY_RESET",
            QueryType::QueryNetworkSettings => "QUERY_NETWORK_SETTINGS",
            QueryType::QueryConfigureNetworkSettings => {
                "QUERY_CONFIGURE_NETWORK_SETTINGS"
            }
            QueryType::QueryScanModules => "QUERY_SCAN_MODULES",
            QueryType::QueryConfigureIdentity => "QUERY_CONFIGURE_IDENTITY",
            QueryType::QueryStatus => "QUERY_STATUS",
            QueryType::QueryModule => "QUERY_MODULE",
            QueryType::QueryMetadata => "QUERY_METADATA",
            QueryType::QueryFormat => "QUERY_FORMAT",
            QueryType::QueryGetReadings => "QUERY_GET_READINGS",
            QueryType::QueryTakeReadings => "QUERY_TAKE_READINGS",
            QueryType::QueryRecordingControl => "QUERY_RECORDING_CONTROL",
            QueryType::QueryConfigure => "QUERY_CONFIGURE",
            QueryType::QueryScanNetworks => "QUERY_SCAN_NETWORKS",
            QueryType::QueryFilesSpi => "QUERY_FILES_SPI",
            QueryType::QueryFilesQspi => "QUERY_FILES_QSPI",
        }
    }
    /// Creates an enum from field names used in the ProtoBuf definition.
    pub fn from_str_name(value: &str) -> ::core::option::Option<Self> {
        match value {
            "QUERY_NONE" => Some(Self::QueryNone),
            "QUERY_CAPABILITIES" => Some(Self::QueryCapabilities),
            "QUERY_CONFIGURE_SENSOR" => Some(Self::QueryConfigureSensor),
            "QUERY_LIVE_DATA_POLL" => Some(Self::QueryLiveDataPoll),
            "QUERY_SCHEDULES" => Some(Self::QuerySchedules),
            "QUERY_CONFIGURE_SCHEDULES" => Some(Self::QueryConfigureSchedules),
            "QUERY_FILES_SD" => Some(Self::QueryFilesSd),
            "QUERY_DOWNLOAD_FILE" => Some(Self::QueryDownloadFile),
            "QUERY_ERASE_FILE" => Some(Self::QueryEraseFile),
            "QUERY_RESET" => Some(Self::QueryReset),
            "QUERY_NETWORK_SETTINGS" => Some(Self::QueryNetworkSettings),
            "QUERY_CONFIGURE_NETWORK_SETTINGS" => {
                Some(Self::QueryConfigureNetworkSettings)
            }
            "QUERY_SCAN_MODULES" => Some(Self::QueryScanModules),
            "QUERY_CONFIGURE_IDENTITY" => Some(Self::QueryConfigureIdentity),
            "QUERY_STATUS" => Some(Self::QueryStatus),
            "QUERY_MODULE" => Some(Self::QueryModule),
            "QUERY_METADATA" => Some(Self::QueryMetadata),
            "QUERY_FORMAT" => Some(Self::QueryFormat),
            "QUERY_GET_READINGS" => Some(Self::QueryGetReadings),
            "QUERY_TAKE_READINGS" => Some(Self::QueryTakeReadings),
            "QUERY_RECORDING_CONTROL" => Some(Self::QueryRecordingControl),
            "QUERY_CONFIGURE" => Some(Self::QueryConfigure),
            "QUERY_SCAN_NETWORKS" => Some(Self::QueryScanNetworks),
            "QUERY_FILES_SPI" => Some(Self::QueryFilesSpi),
            "QUERY_FILES_QSPI" => Some(Self::QueryFilesQspi),
            _ => None,
        }
    }
}
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord, ::prost::Enumeration)]
#[repr(i32)]
pub enum ReplyType {
    ReplyNone = 0,
    ReplySuccess = 1,
    ReplyBusy = 2,
    ReplyError = 3,
    ReplyCapabilities = 4,
    ReplyLiveDataPoll = 8,
    ReplySchedules = 9,
    ReplyFiles = 10,
    ReplyDownloadFile = 11,
    ReplyReset = 12,
    ReplyNetworkSettings = 13,
    ReplyIdentity = 14,
    ReplyStatus = 15,
    ReplyModule = 16,
    ReplyMetadata = 17,
    ReplyReadings = 18,
    ReplyNetworks = 19,
}
impl ReplyType {
    /// String value of the enum field names used in the ProtoBuf definition.
    ///
    /// The values are not transformed in any way and thus are considered stable
    /// (if the ProtoBuf definition does not change) and safe for programmatic use.
    pub fn as_str_name(&self) -> &'static str {
        match self {
            ReplyType::ReplyNone => "REPLY_NONE",
            ReplyType::ReplySuccess => "REPLY_SUCCESS",
            ReplyType::ReplyBusy => "REPLY_BUSY",
            ReplyType::ReplyError => "REPLY_ERROR",
            ReplyType::ReplyCapabilities => "REPLY_CAPABILITIES",
            ReplyType::ReplyLiveDataPoll => "REPLY_LIVE_DATA_POLL",
            ReplyType::ReplySchedules => "REPLY_SCHEDULES",
            ReplyType::ReplyFiles => "REPLY_FILES",
            ReplyType::ReplyDownloadFile => "REPLY_DOWNLOAD_FILE",
            ReplyType::ReplyReset => "REPLY_RESET",
            ReplyType::ReplyNetworkSettings => "REPLY_NETWORK_SETTINGS",
            ReplyType::ReplyIdentity => "REPLY_IDENTITY",
            ReplyType::ReplyStatus => "REPLY_STATUS",
            ReplyType::ReplyModule => "REPLY_MODULE",
            ReplyType::ReplyMetadata => "REPLY_METADATA",
            ReplyType::ReplyReadings => "REPLY_READINGS",
            ReplyType::ReplyNetworks => "REPLY_NETWORKS",
        }
    }
    /// Creates an enum from field names used in the ProtoBuf definition.
    pub fn from_str_name(value: &str) -> ::core::option::Option<Self> {
        match value {
            "REPLY_NONE" => Some(Self::ReplyNone),
            "REPLY_SUCCESS" => Some(Self::ReplySuccess),
            "REPLY_BUSY" => Some(Self::ReplyBusy),
            "REPLY_ERROR" => Some(Self::ReplyError),
            "REPLY_CAPABILITIES" => Some(Self::ReplyCapabilities),
            "REPLY_LIVE_DATA_POLL" => Some(Self::ReplyLiveDataPoll),
            "REPLY_SCHEDULES" => Some(Self::ReplySchedules),
            "REPLY_FILES" => Some(Self::ReplyFiles),
            "REPLY_DOWNLOAD_FILE" => Some(Self::ReplyDownloadFile),
            "REPLY_RESET" => Some(Self::ReplyReset),
            "REPLY_NETWORK_SETTINGS" => Some(Self::ReplyNetworkSettings),
            "REPLY_IDENTITY" => Some(Self::ReplyIdentity),
            "REPLY_STATUS" => Some(Self::ReplyStatus),
            "REPLY_MODULE" => Some(Self::ReplyModule),
            "REPLY_METADATA" => Some(Self::ReplyMetadata),
            "REPLY_READINGS" => Some(Self::ReplyReadings),
            "REPLY_NETWORKS" => Some(Self::ReplyNetworks),
            _ => None,
        }
    }
}
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord, ::prost::Enumeration)]
#[repr(i32)]
pub enum DownloadFlags {
    DownloadFlagNone = 0,
    DownloadFlagMetadataPrepend = 1,
    DownloadFlagMetadataOnly = 2,
}
impl DownloadFlags {
    /// String value of the enum field names used in the ProtoBuf definition.
    ///
    /// The values are not transformed in any way and thus are considered stable
    /// (if the ProtoBuf definition does not change) and safe for programmatic use.
    pub fn as_str_name(&self) -> &'static str {
        match self {
            DownloadFlags::DownloadFlagNone => "DOWNLOAD_FLAG_NONE",
            DownloadFlags::DownloadFlagMetadataPrepend => {
                "DOWNLOAD_FLAG_METADATA_PREPEND"
            }
            DownloadFlags::DownloadFlagMetadataOnly => "DOWNLOAD_FLAG_METADATA_ONLY",
        }
    }
    /// Creates an enum from field names used in the ProtoBuf definition.
    pub fn from_str_name(value: &str) -> ::core::option::Option<Self> {
        match value {
            "DOWNLOAD_FLAG_NONE" => Some(Self::DownloadFlagNone),
            "DOWNLOAD_FLAG_METADATA_PREPEND" => Some(Self::DownloadFlagMetadataPrepend),
            "DOWNLOAD_FLAG_METADATA_ONLY" => Some(Self::DownloadFlagMetadataOnly),
            _ => None,
        }
    }
}
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord, ::prost::Enumeration)]
#[repr(i32)]
pub enum ModuleFlags {
    ModuleFlagNone = 0,
    ModuleFlagInternal = 1,
}
impl ModuleFlags {
    /// String value of the enum field names used in the ProtoBuf definition.
    ///
    /// The values are not transformed in any way and thus are considered stable
    /// (if the ProtoBuf definition does not change) and safe for programmatic use.
    pub fn as_str_name(&self) -> &'static str {
        match self {
            ModuleFlags::ModuleFlagNone => "MODULE_FLAG_NONE",
            ModuleFlags::ModuleFlagInternal => "MODULE_FLAG_INTERNAL",
        }
    }
    /// Creates an enum from field names used in the ProtoBuf definition.
    pub fn from_str_name(value: &str) -> ::core::option::Option<Self> {
        match value {
            "MODULE_FLAG_NONE" => Some(Self::ModuleFlagNone),
            "MODULE_FLAG_INTERNAL" => Some(Self::ModuleFlagInternal),
            _ => None,
        }
    }
}
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord, ::prost::Enumeration)]
#[repr(i32)]
pub enum SensorFlags {
    SensorFlagNone = 0,
}
impl SensorFlags {
    /// String value of the enum field names used in the ProtoBuf definition.
    ///
    /// The values are not transformed in any way and thus are considered stable
    /// (if the ProtoBuf definition does not change) and safe for programmatic use.
    pub fn as_str_name(&self) -> &'static str {
        match self {
            SensorFlags::SensorFlagNone => "SENSOR_FLAG_NONE",
        }
    }
    /// Creates an enum from field names used in the ProtoBuf definition.
    pub fn from_str_name(value: &str) -> ::core::option::Option<Self> {
        match value {
            "SENSOR_FLAG_NONE" => Some(Self::SensorFlagNone),
            _ => None,
        }
    }
}
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord, ::prost::Enumeration)]
#[repr(i32)]
pub enum ModuleQueryType {
    ModuleQueryNone = 0,
    ModuleQueryStatus = 1,
    ModuleQueryConfigure = 2,
    ModuleQueryReset = 3,
}
impl ModuleQueryType {
    /// String value of the enum field names used in the ProtoBuf definition.
    ///
    /// The values are not transformed in any way and thus are considered stable
    /// (if the ProtoBuf definition does not change) and safe for programmatic use.
    pub fn as_str_name(&self) -> &'static str {
        match self {
            ModuleQueryType::ModuleQueryNone => "MODULE_QUERY_NONE",
            ModuleQueryType::ModuleQueryStatus => "MODULE_QUERY_STATUS",
            ModuleQueryType::ModuleQueryConfigure => "MODULE_QUERY_CONFIGURE",
            ModuleQueryType::ModuleQueryReset => "MODULE_QUERY_RESET",
        }
    }
    /// Creates an enum from field names used in the ProtoBuf definition.
    pub fn from_str_name(value: &str) -> ::core::option::Option<Self> {
        match value {
            "MODULE_QUERY_NONE" => Some(Self::ModuleQueryNone),
            "MODULE_QUERY_STATUS" => Some(Self::ModuleQueryStatus),
            "MODULE_QUERY_CONFIGURE" => Some(Self::ModuleQueryConfigure),
            "MODULE_QUERY_RESET" => Some(Self::ModuleQueryReset),
            _ => None,
        }
    }
}
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord, ::prost::Enumeration)]
#[repr(i32)]
pub enum ModuleReplyType {
    ModuleReplyNone = 0,
    ModuleReplySuccess = 1,
    ModuleReplyBusy = 2,
    ModuleReplyError = 3,
}
impl ModuleReplyType {
    /// String value of the enum field names used in the ProtoBuf definition.
    ///
    /// The values are not transformed in any way and thus are considered stable
    /// (if the ProtoBuf definition does not change) and safe for programmatic use.
    pub fn as_str_name(&self) -> &'static str {
        match self {
            ModuleReplyType::ModuleReplyNone => "MODULE_REPLY_NONE",
            ModuleReplyType::ModuleReplySuccess => "MODULE_REPLY_SUCCESS",
            ModuleReplyType::ModuleReplyBusy => "MODULE_REPLY_BUSY",
            ModuleReplyType::ModuleReplyError => "MODULE_REPLY_ERROR",
        }
    }
    /// Creates an enum from field names used in the ProtoBuf definition.
    pub fn from_str_name(value: &str) -> ::core::option::Option<Self> {
        match value {
            "MODULE_REPLY_NONE" => Some(Self::ModuleReplyNone),
            "MODULE_REPLY_SUCCESS" => Some(Self::ModuleReplySuccess),
            "MODULE_REPLY_BUSY" => Some(Self::ModuleReplyBusy),
            "MODULE_REPLY_ERROR" => Some(Self::ModuleReplyError),
            _ => None,
        }
    }
}
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord, ::prost::Enumeration)]
#[repr(i32)]
pub enum UdpStatus {
    Online = 0,
    Bye = 1,
}
impl UdpStatus {
    /// String value of the enum field names used in the ProtoBuf definition.
    ///
    /// The values are not transformed in any way and thus are considered stable
    /// (if the ProtoBuf definition does not change) and safe for programmatic use.
    pub fn as_str_name(&self) -> &'static str {
        match self {
            UdpStatus::Online => "UDP_STATUS_ONLINE",
            UdpStatus::Bye => "UDP_STATUS_BYE",
        }
    }
    /// Creates an enum from field names used in the ProtoBuf definition.
    pub fn from_str_name(value: &str) -> ::core::option::Option<Self> {
        match value {
            "UDP_STATUS_ONLINE" => Some(Self::Online),
            "UDP_STATUS_BYE" => Some(Self::Bye),
            _ => None,
        }
    }
}
