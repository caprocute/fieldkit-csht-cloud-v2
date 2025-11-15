use chrono::{DateTime, Utc};

// NOTE This is also declared in the `discovery` crate.
#[derive(Clone, Debug, Eq, PartialEq, Hash)]
pub struct DeviceId(pub String);

#[derive(Clone, Default, Debug)]
pub struct Stream {
    pub size: u64,
    pub records: u64,
}

#[derive(Clone, Default, Debug)]
pub struct Battery {
    pub percentage: f32,
    pub voltage: f32,
}

#[derive(Clone, Default, Debug)]
pub struct Solar {
    pub voltage: f32,
}

#[derive(Clone, Debug)]
pub struct Station {
    pub id: Option<i64>,
    pub device_id: DeviceId,
    pub generation_id: String,
    pub name: String,
    pub firmware: Firmware,
    pub last_seen: DateTime<Utc>,
    pub status: Option<Vec<u8>>,
    pub meta: Stream,
    pub data: Stream,
    pub battery: Battery,
    pub solar: Solar,
    pub modules: Vec<Module>,
    pub last_seen_location: Option<Coordinates>,
}

#[derive(Clone, Debug)]

pub struct Coordinates {
    pub latitude: f64,
    pub longitude: f64,
}

#[derive(Clone, Debug)]
pub struct Firmware {
    pub label: String,
    pub time: i64,
}

#[derive(Clone, Debug)]
pub struct ModuleHeader {
    pub manufacturer: u32,
    pub kind: u32,
    pub version: u32,
}

#[derive(Clone, Debug)]
pub struct Module {
    pub id: Option<i64>,
    pub station_id: Option<i64>,
    pub hardware_id: String,
    pub header: ModuleHeader,
    pub flags: u32,
    pub position: u32,
    pub key: String,
    pub path: String,
    pub configuration: Option<Vec<u8>>,
    pub removed: bool,
    pub sensors: Vec<Sensor>,
}

impl Module {
    pub fn internal(&self) -> bool {
        todo!()
    }
}

#[derive(Clone, Debug)]
pub struct Sensor {
    pub id: Option<i64>,
    pub module_id: Option<i64>,
    pub number: u32,
    pub flags: u32,
    pub key: String,
    pub calibrated_uom: String,
    pub uncalibrated_uom: String,
    pub value: Option<LiveValue>,
    pub previous_value: Option<LiveValue>,
    pub removed: bool,
}

#[derive(Clone, Debug)]
pub struct LiveValue {
    pub time: DateTime<Utc>,
    pub value: f32,
    pub uncalibrated: f32,
}

#[derive(Clone, Debug)]
pub struct StationDownload {
    pub id: Option<i64>,
    pub station_id: Option<i64>,
    pub generation_id: String,
    pub started: DateTime<Utc>,
    pub begin: u64,
    pub end: u64,
    pub path: String,
    pub uploaded: bool,
    pub finished: Option<DateTime<Utc>>,
    pub size: Option<i64>,
    pub error: Option<String>,
}

#[cfg(test)]
pub(crate) mod test {
    use super::*;

    pub fn build() -> Build {
        Build::default()
    }

    #[derive(Default)]
    pub struct Build {}

    impl Build {
        pub fn station(&self) -> BuildStation {
            BuildStation::default()
        }

        pub fn module(&self) -> BuildModule {
            BuildModule::default()
        }

        #[allow(dead_code)]
        pub fn sensor(&self) -> BuildSensor {
            BuildSensor::default()
        }

        pub fn download(&self) -> BuildDownload {
            BuildDownload::default()
        }
    }

    #[derive(Default)]
    pub struct BuildStation {
        modules: Vec<Module>,
    }

    impl BuildStation {
        pub fn module(mut self, module: Module) -> Self {
            self.modules.push(module);
            self
        }

        pub fn with_basic_module(self, name: &str) -> Self {
            self.module(BuildModule::default().basic(name).build())
        }

        pub fn build(self) -> Station {
            Station {
                id: None,
                device_id: DeviceId("device-id".to_owned()),
                generation_id: "generation-id".to_owned(),
                name: "Hoppy Kangaroo".to_owned(),
                firmware: Firmware {
                    label: "00aabbccddeeffgg".to_owned(),
                    time: 1688659549,
                },
                last_seen: Utc::now(),
                status: None,
                meta: Stream::default(),
                data: Stream::default(),
                battery: Battery::default(),
                solar: Solar::default(),
                modules: self.modules,
                last_seen_location: None,
            }
        }
    }

    pub struct BuildModule {
        station_id: Option<i64>,
        hardware_id: Option<String>,
        name: String,
        position: u32,
        sensors: Vec<Sensor>,
    }

    impl Default for BuildModule {
        fn default() -> Self {
            Self {
                station_id: None,
                hardware_id: None,
                name: "fk.modules.test".to_owned(),
                position: 0,
                sensors: Vec::new(),
            }
        }
    }

    impl BuildModule {
        pub fn station_id(mut self, station_id: Option<i64>) -> Self {
            self.station_id = station_id;
            self
        }

        pub fn basic(self, name: &str) -> Self {
            self.hardware_id(name).named(name).sensor().sensor()
        }

        #[allow(dead_code)]
        pub fn position(mut self, position: u32) -> Self {
            self.position = position;
            self
        }

        pub fn hardware_id(mut self, hardware_id: &str) -> Self {
            self.hardware_id = Some(hardware_id.to_owned());
            self
        }

        pub fn named(mut self, name: &str) -> Self {
            self.name = name.to_owned();
            self
        }

        pub fn with_sensor(mut self, sensor: Sensor) -> Self {
            self.sensors.push(sensor);
            self
        }

        pub fn sensor(self) -> Self {
            let i = self.sensors.len();
            self.with_sensor(Sensor {
                id: None,
                module_id: None,
                number: i as u32,
                flags: 0,
                key: format!("sensor-{}", i),
                calibrated_uom: "m".to_owned(),
                uncalibrated_uom: "mV".to_owned(),
                value: Some(LiveValue {
                    time: Utc::now(),
                    value: 3.14159,
                    uncalibrated: 1200.0,
                }),
                previous_value: None,
                removed: false,
            })
        }

        pub fn build(self) -> Module {
            Module {
                id: None,
                station_id: self.station_id,
                hardware_id: self.hardware_id.unwrap_or(self.name.clone()),
                header: ModuleHeader {
                    manufacturer: 1,
                    kind: 2,
                    version: 3,
                },
                flags: 0,
                position: self.position,
                key: self.name,
                path: format!("/fk/v1/modules/{}", self.position),
                configuration: None,
                removed: false,
                sensors: self.sensors,
            }
        }
    }

    #[derive(Default)]
    pub struct BuildSensor {
        module_id: Option<i64>,
        number: u32,
    }

    impl BuildSensor {
        pub fn module_id(mut self, module_id: Option<i64>) -> Self {
            self.module_id = module_id;
            self
        }

        #[allow(dead_code)]
        pub fn number(mut self, number: u32) -> Self {
            self.number = number;
            self
        }

        pub fn build(self) -> Sensor {
            Sensor {
                id: None,
                module_id: self.module_id,
                number: self.number as u32,
                flags: 0,
                key: format!("sensor-{}", self.number),
                calibrated_uom: "m".to_owned(),
                uncalibrated_uom: "mV".to_owned(),
                value: Some(LiveValue {
                    time: Utc::now(),
                    value: 3.14159,
                    uncalibrated: 1200.0,
                }),
                previous_value: None,
                removed: false,
            }
        }
    }

    #[derive(Default)]
    pub struct BuildDownload {
        station_id: Option<i64>,
    }

    impl BuildDownload {
        pub fn station_id(mut self, station_id: Option<i64>) -> Self {
            self.station_id = station_id;
            self
        }

        pub fn build(self) -> StationDownload {
            StationDownload {
                id: None,
                station_id: self.station_id,
                generation_id: "generation-id".to_owned(),
                started: Utc::now(),
                begin: 0,
                end: 1000,
                path: "downloaded-data-0.fkpb".to_owned(),
                uploaded: false,
                finished: None,
                size: None,
                error: None,
            }
        }
    }
}
