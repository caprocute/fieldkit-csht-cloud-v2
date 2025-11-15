use std::{collections::HashMap, path::Path};

use anyhow::{anyhow, Result};
use chrono::{DateTime, Utc};
use itertools::Itertools;
use rusqlite::{params, Connection, Row};
use thiserror::Error;
use tracing::*;

mod merge;
mod migrations;
mod model;
mod parse_reply;

pub use model::*;
pub use parse_reply::*;

pub struct Db {
    conn: Option<Connection>,
}

#[derive(Error, Debug)]
pub enum DbError {
    #[error("Completely unexpected")]
    SeriousBug,
}

impl Db {
    pub fn new() -> Self {
        Self { conn: None }
    }

    fn open_connection(&mut self, mut conn: Connection) -> Result<()> {
        conn.pragma_update(None, "journal_mode", &"WAL")?;

        let migrations = migrations::get_migrations();

        migrations.to_latest(&mut conn)?;

        self.conn = Some(conn);

        Ok(())
    }

    pub fn open_in_memory(&mut self) -> Result<()> {
        self.open_connection(Connection::open_in_memory()?)
    }

    pub fn open<P: AsRef<Path>>(&mut self, path: P) -> Result<()> {
        self.open_connection(Connection::open(path)?)
    }

    pub fn synchronize(&self, incoming: Station) -> Result<Station> {
        let existing = self.hydrate_station(&incoming.device_id)?;
        let saving = merge::merge(existing, incoming)?;
        let saved = self.persist_station(&saving)?;

        info!("{:?} saved {:?}", &saved.device_id, &saved.id);

        Ok(saved)
    }

    pub fn merge_reply(
        &self,
        device_id: DeviceId,
        reply: query::device::HttpReply,
    ) -> Result<Station> {
        let incoming = http_reply_to_station(reply)?;
        assert_eq!(device_id, incoming.device_id);
        Ok(self.synchronize(incoming)?)
    }

    pub fn hydrate_station(&self, device_id: &DeviceId) -> Result<Option<Station>> {
        match self.get_station_by_device_id(device_id)? {
            Some(station) => Ok(Some(Station {
                modules: self
                    .get_modules(station.id.ok_or(DbError::SeriousBug)?)?
                    .into_iter()
                    .map(|module| {
                        Ok(Module {
                            sensors: self.get_sensors(module.id.ok_or(DbError::SeriousBug)?)?,
                            ..module
                        })
                    })
                    .collect::<Result<Vec<_>>>()?,
                ..station
            })),
            None => Ok(None),
        }
    }

    pub fn persist_station(&self, station: &Station) -> Result<Station> {
        let station = match station.id {
            Some(_id) => self.update_station(station)?,
            None => self.add_station(station)?,
        };

        Ok(Station {
            modules: station
                .modules
                .into_iter()
                .map(|module| Module {
                    station_id: station.id,
                    ..module
                })
                .map(|module| match module.id {
                    Some(_id) => Ok(self.update_module(&module)?),
                    None => Ok(self.add_module(&module)?),
                })
                .collect::<Result<Vec<_>>>()?
                .into_iter()
                .map(|module| {
                    Ok(Module {
                        sensors: module
                            .sensors
                            .into_iter()
                            .map(|sensor| Sensor {
                                module_id: module.id,
                                ..sensor
                            })
                            .map(|sensor| {
                                Ok(match sensor.id {
                                    Some(_id) => self.update_sensor(&sensor)?,
                                    None => self.add_sensor(&sensor)?,
                                })
                            })
                            .collect::<Result<Vec<_>>>()?,
                        ..module
                    })
                })
                .collect::<Result<Vec<_>>>()?,
            ..station
        })
    }

    pub fn add_station(&self, station: &Station) -> Result<Station> {
        let conn = self.require_opened()?;
        let mut stmt = conn.prepare(
            r#"
            INSERT INTO station
            (device_id, generation_id, name, firmware_label, firmware_time, last_seen,
             meta_size, meta_records, data_size, data_records, battery_percentage, battery_voltage, solar_voltage, status,
             last_seen_latitude, last_seen_longitude)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, COALESCE(?, NULL), COALESCE(?, NULL))
            "#,
        )?;

        let affected = stmt.execute(params![
            station.device_id.0,
            station.generation_id,
            station.name,
            station.firmware.label,
            station.firmware.time,
            station.last_seen.to_rfc3339(),
            station.meta.size,
            station.meta.records,
            station.data.size,
            station.data.records,
            station.battery.percentage,
            station.battery.voltage,
            station.solar.voltage,
            station.status,
            station.last_seen_location.as_ref().map(|l| l.latitude),
            station.last_seen_location.as_ref().map(|l| l.longitude),
        ])?;

        assert_eq!(affected, 1);

        let id = Some(conn.last_insert_rowid());

        Ok(Station {
            id,
            device_id: station.device_id.clone(),
            generation_id: station.generation_id.clone(),
            name: station.name.clone(),
            firmware: station.firmware.clone(),
            last_seen: station.last_seen,
            modules: station.modules.clone(),
            meta: station.meta.clone(),
            data: station.data.clone(),
            battery: station.battery.clone(),
            solar: station.solar.clone(),
            status: station.status.clone(),
            last_seen_location: station.last_seen_location.clone(),
        })
    }

    pub fn update_station(&self, station: &Station) -> Result<Station> {
        let conn = self.require_opened()?;
        let mut stmt = conn.prepare(
            r#"
            UPDATE station SET
                generation_id = ?, name = ?, firmware_label = ?, firmware_time = ?, last_seen = ?, meta_size = ?, meta_records = ?, data_size = ?, data_records = ?,
                battery_percentage = ?, battery_voltage = ?, solar_voltage = ?, status = ?, last_seen_latitude = COALESCE(?, last_seen_latitude), 
                last_seen_longitude = COALESCE(?, last_seen_longitude)
            WHERE id = ?"#,
        )?;

        let affected = stmt.execute(params![
            station.generation_id,
            station.name,
            station.firmware.label,
            station.firmware.time,
            station.last_seen.to_rfc3339(),
            station.meta.size,
            station.meta.records,
            station.data.size,
            station.data.records,
            station.battery.percentage,
            station.battery.voltage,
            station.solar.voltage,
            station.status,
            station.last_seen_location.as_ref().map(|l| l.latitude),
            station.last_seen_location.as_ref().map(|l| l.longitude),
            station.id,
        ])?;

        assert_eq!(affected, 1);

        Ok(station.clone())
    }

    pub fn delete_station_by_device_id(&self, device_id: &DeviceId) -> Result<()> {
        let conn = self.require_opened()?;
        let mut stmt = conn.prepare(r#"SELECT id FROM station WHERE device_id = ?"#)?;
        let id = stmt.query_row(params![device_id.0], |row| Ok(row.get::<_, i64>(0)?))?;

        self.delete_station(id)
    }

    pub fn delete_station(&self, id: i64) -> Result<()> {
        let conn = self.require_opened()?;
        let mut stmt = conn.prepare(
            r#"DELETE FROM sensor WHERE module_id IN (SELECT id FROM module WHERE station_id = ?)"#,
        )?;
        let affected = stmt.execute(params![id])?;
        info!(sensors = affected, "deleted");

        let mut stmt = conn.prepare(r#"DELETE FROM module WHERE station_id = ?"#)?;
        let affected = stmt.execute(params![id])?;
        info!(modules = affected, "deleted");

        let mut stmt = conn.prepare(r#"DELETE FROM station_download WHERE station_id = ?"#)?;
        let affected = stmt.execute(params![id])?;
        info!(downloads = affected, "deleted");

        let mut stmt = conn.prepare(r#"DELETE FROM station WHERE id = ?"#)?;
        let affected = stmt.execute(params![id])?;
        info!(stations = affected, "deleted");

        Ok(())
    }

    pub fn update_station_location(&self, device_id: &DeviceId, lat: f64, lng: f64) -> Result<()> {
        let conn = self.require_opened()?;
        let mut stmt = conn.prepare(
            r#"
            UPDATE station SET
                last_seen_latitude = ?, last_seen_longitude = ?
            WHERE device_id = ?"#,
        )?;

        let affected = stmt.execute(params![lat, lng, device_id.0])?;

        assert_eq!(affected, 1);

        Ok(())
    }

    fn row_to_station(&self, row: &rusqlite::Row) -> Result<Station, rusqlite::Error> {
        let last_seen: String = row.get(6)?;
        let last_seen = DateTime::parse_from_rfc3339(&last_seen)
            .expect("Parsing last_seen")
            .with_timezone(&Utc);

        let last_seen_lat: Option<f64> = row.get(15)?;
        let last_seen_lng: Option<f64> = row.get(16)?;

        Ok(Station {
            id: row.get(0)?,
            device_id: DeviceId(row.get(1)?),
            generation_id: row.get(2)?,
            name: row.get(3)?,
            firmware: Firmware {
                label: row.get(4)?,
                time: row.get(5)?,
            },
            last_seen,
            meta: Stream {
                size: row.get(7)?,
                records: row.get(8)?,
            },
            data: Stream {
                size: row.get(9)?,
                records: row.get(10)?,
            },
            battery: Battery {
                percentage: row.get(11)?,
                voltage: row.get(12)?,
            },
            solar: Solar {
                voltage: row.get(13)?,
            },
            status: row.get(14)?,
            last_seen_location: if last_seen_lat.is_none() || last_seen_lng.is_none() {
                None
            } else {
                Some(Coordinates {
                    latitude: last_seen_lat.unwrap(),
                    longitude: last_seen_lng.unwrap(),
                })
            },
            modules: Vec::new(),
        })
    }

    pub fn get_all_stations(&self) -> Result<Vec<Station>> {
        let mut stmt = self.require_opened()?.prepare(
            r#"SELECT id, device_id, generation_id, name, firmware_label, firmware_time, last_seen,
               meta_size, meta_records, data_size, data_records,
               battery_percentage, battery_voltage, solar_voltage, status,
               last_seen_latitude, last_seen_longitude
               FROM station"#,
        ).map_err(|e| {
            eprintln!("SQL error during get_all_stations: {}", e);
            e
        })?;
        let stations = stmt.query_map(params![], |row| Ok(self.row_to_station(row)?))?;

        Ok(stations.map(|r| Ok(r?)).collect::<Result<Vec<_>>>()?)
    }

    pub fn get_stations(&self) -> Result<Vec<Station>> {
        let stations = self.get_all_stations()?;
        let mut modules = self.get_all_modules()?;
        let mut sensors = self.get_all_sensors()?;

        Ok(stations
            .into_iter()
            .map(|mut station| {
                station.modules = modules
                    .remove(&station.id.expect("station row missing id"))
                    .unwrap_or_default()
                    .into_iter()
                    .filter(|m| !m.removed)
                    .map(|mut module| {
                        module.sensors = sensors
                            .remove(&module.id.expect("module row missing id"))
                            .unwrap_or_default();

                        module
                    })
                    .collect_vec();

                station
            })
            .collect_vec())
    }

    pub fn get_station_by_device_id(&self, device_id: &DeviceId) -> Result<Option<Station>> {
        let mut stmt = self.require_opened()?.prepare(
            r#"SELECT id, device_id, generation_id, name, firmware_label, firmware_time, last_seen,
               meta_size, meta_records, data_size, data_records,
               battery_percentage, battery_voltage, solar_voltage, status,
               last_seen_latitude, last_seen_longitude
               FROM station WHERE device_id = ?"#,
        )?;

        let stations = stmt.query_map(params![device_id.0], |row| Ok(self.row_to_station(row)?))?;
        let stations = stations.map(|r| Ok(r?)).collect::<Result<Vec<_>>>()?;
        Ok(stations.first().cloned())
    }

    pub fn add_module(&self, module: &Module) -> Result<Module> {
        assert!(module.id.is_none());
        assert!(module.station_id.is_some());

        let conn = self.require_opened()?;
        let mut stmt = conn.prepare(
            r#"
            INSERT INTO module
            (station_id, hardware_id, manufacturer, kind, version, flags, position, key, path, configuration, removed) VALUES
            (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            "#,
        )?;

        let affected = stmt.execute(params![
            module.station_id,
            module.hardware_id,
            module.header.manufacturer,
            module.header.kind,
            module.header.version,
            module.flags,
            module.position,
            module.key,
            module.path,
            module.configuration,
            module.removed,
        ])?;

        assert_eq!(affected, 1);

        let id = Some(conn.last_insert_rowid());

        Ok(Module {
            id,
            station_id: module.station_id,
            hardware_id: module.hardware_id.clone(),
            header: module.header.clone(),
            flags: module.flags,
            position: module.position,
            key: module.key.clone(),
            path: module.path.clone(),
            sensors: module.sensors.clone(),
            removed: module.removed,
            configuration: module.configuration.clone(),
        })
    }

    pub fn update_module(&self, module: &Module) -> Result<Module> {
        assert!(module.id.is_some());
        assert!(module.station_id.is_some());

        let conn = self.require_opened()?;
        let mut stmt = conn.prepare(
            r#"
            UPDATE module SET station_id = ?, manufacturer = ?, kind = ?, version = ?, flags = ?, position = ?, key = ?, path = ?, configuration = ?, removed = ? WHERE id = ?
            "#,
        )?;

        let affected = stmt.execute(params![
            module.station_id,
            module.header.manufacturer,
            module.header.kind,
            module.header.version,
            module.flags,
            module.position,
            module.key,
            module.path,
            module.configuration,
            module.removed,
            module.id,
        ])?;

        assert_eq!(affected, 1);

        Ok(module.clone())
    }

    fn row_to_module<'a>(row: &Row<'a>) -> Result<Module, rusqlite::Error> {
        Ok(Module {
            id: row.get(0)?,
            station_id: row.get(1)?,
            hardware_id: row.get(2)?,
            header: ModuleHeader {
                manufacturer: row.get(3)?,
                kind: row.get(4)?,
                version: row.get(5)?,
            },
            flags: row.get(6)?,
            position: row.get(7)?,
            key: row.get(8)?,
            path: row.get(9)?,
            configuration: row.get(10)?,
            removed: row.get(11)?,
            sensors: Vec::new(),
        })
    }

    pub fn get_all_modules(&self) -> Result<HashMap<i64, Vec<Module>>> {
        let mut stmt = self.require_opened()?.prepare(
            r#"SELECT id, station_id, hardware_id, manufacturer, kind, version, flags, position, key, path, configuration, removed
               FROM module
               ORDER BY station_id"#,
        )?;

        let modules = stmt.query_map([], Db::row_to_module)?;

        Ok(modules
            .map(|r| Ok(r?))
            .collect::<Result<Vec<_>>>()?
            .into_iter()
            .into_group_map_by(|v| v.station_id.expect("module row missing station_id"))
            .into_iter()
            .collect())
    }

    pub fn get_modules(&self, station_id: i64) -> Result<Vec<Module>> {
        let mut stmt = self.require_opened()?.prepare(
            r#"SELECT id, station_id, hardware_id, manufacturer, kind, version, flags, position, key, path, configuration, removed
               FROM module
               WHERE station_id = ?"#,
        )?;

        let modules = stmt.query_map(params![station_id], Db::row_to_module)?;

        Ok(modules.map(|r| Ok(r?)).collect::<Result<Vec<_>>>()?)
    }

    pub fn add_sensor(&self, sensor: &Sensor) -> Result<Sensor> {
        assert!(sensor.id.is_none());
        assert!(sensor.module_id.is_some());

        let conn = self.require_opened()?;
        let mut stmt = conn.prepare(
            r#"
            INSERT INTO sensor
            (module_id, number, flags, key, calibrated_uom, uncalibrated_uom, reading_time, calibrated_value, uncalibrated_value, removed) VALUES
            (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            "#,
        )?;

        let affected = stmt.execute(params![
            sensor.module_id,
            sensor.number,
            sensor.flags,
            sensor.key,
            sensor.calibrated_uom,
            sensor.uncalibrated_uom,
            sensor.value.as_ref().map(|v| v.time.to_rfc3339()),
            sensor.value.as_ref().map(|v| v.value),
            sensor.value.as_ref().map(|v| v.uncalibrated),
            sensor.removed
        ])?;

        assert_eq!(affected, 1);

        let id = Some(conn.last_insert_rowid());

        Ok(Sensor {
            id,
            module_id: sensor.module_id,
            number: sensor.number,
            flags: sensor.flags,
            key: sensor.key.clone(),
            calibrated_uom: sensor.calibrated_uom.clone(),
            uncalibrated_uom: sensor.uncalibrated_uom.clone(),
            value: sensor.value.clone(),
            previous_value: None,
            removed: sensor.removed,
        })
    }

    pub fn update_sensor(&self, sensor: &Sensor) -> Result<Sensor> {
        assert!(sensor.id.is_some());
        assert!(sensor.module_id.is_some());

        let conn = self.require_opened()?;
        let mut stmt = conn.prepare(
            r#"
            UPDATE sensor SET
                number = ?, flags = ?, key = ?, calibrated_uom = ?, uncalibrated_uom = ?,
                previous_reading_time = reading_time, previous_calibrated_value = calibrated_value, previous_uncalibrated_value = uncalibrated_value,
                reading_time = ?, calibrated_value = ?, uncalibrated_value = ?, removed = ?
            WHERE id = ?
            "#,
        )?;

        let affected = stmt.execute(params![
            sensor.number,
            sensor.flags,
            sensor.key,
            sensor.calibrated_uom,
            sensor.uncalibrated_uom,
            sensor.value.as_ref().map(|v| v.time.to_rfc3339()),
            sensor.value.as_ref().map(|v| v.value),
            sensor.value.as_ref().map(|v| v.uncalibrated),
            sensor.removed,
            sensor.id,
        ])?;

        assert_eq!(affected, 1);

        // If it weren't for the previous reading values we could just return
        // `sensor` here. Alas...
        let after_update = self.get_sensor(sensor.id.unwrap())?;
        assert_eq!(after_update.len(), 1);
        Ok(after_update.into_iter().next().unwrap())
    }

    fn row_to_sensor<'a>(row: &Row<'a>) -> Result<Sensor, rusqlite::Error> {
        let value = DatabaseReading {
            time: row.get(7)?,
            calibrated: row.get(8)?,
            uncalibrated: row.get(9)?,
        };

        let previous_value = DatabaseReading {
            time: row.get(10)?,
            calibrated: row.get(11)?,
            uncalibrated: row.get(12)?,
        };

        Ok(Sensor {
            id: row.get(0)?,
            module_id: row.get(1)?,
            number: row.get(2)?,
            flags: row.get(3)?,
            key: row.get(4)?,
            calibrated_uom: row.get(5)?,
            uncalibrated_uom: row.get(6)?,
            removed: row.get(13)?,
            value: value.to_value(),
            previous_value: previous_value.to_value(),
        })
    }

    pub fn get_sensor(&self, sensor_id: i64) -> Result<Vec<Sensor>> {
        let mut stmt = self.require_opened()?.prepare(
            r#"SELECT
                    id, module_id, number, flags, key, calibrated_uom, uncalibrated_uom,
                    reading_time, calibrated_value, uncalibrated_value,
                    previous_reading_time, previous_calibrated_value, previous_uncalibrated_value,
                    removed
               FROM sensor WHERE id = ?"#,
        )?;

        let sensors = stmt.query_map(params![sensor_id], Db::row_to_sensor)?;

        Ok(sensors.map(|r| Ok(r?)).collect::<Result<Vec<_>>>()?)
    }

    pub fn get_all_sensors(&self) -> Result<HashMap<i64, Vec<Sensor>>> {
        let mut stmt = self.require_opened()?.prepare(
            r#"SELECT
                    id, module_id, number, flags, key, calibrated_uom, uncalibrated_uom,
                    reading_time, calibrated_value, uncalibrated_value,
                    previous_reading_time, previous_calibrated_value, previous_uncalibrated_value,
                    removed
               FROM sensor ORDER BY module_id"#,
        )?;

        let sensors = stmt.query_map([], Db::row_to_sensor)?;

        Ok(sensors
            .map(|r| Ok(r?))
            .collect::<Result<Vec<_>>>()?
            .into_iter()
            .into_group_map_by(|v| v.module_id.expect("sensor row missing module_id"))
            .into_iter()
            .collect())
    }

    pub fn get_sensors(&self, module_id: i64) -> Result<Vec<Sensor>> {
        let mut stmt = self.require_opened()?.prepare(
            r#"SELECT
                    id, module_id, number, flags, key, calibrated_uom, uncalibrated_uom,
                    reading_time, calibrated_value, uncalibrated_value,
                    previous_reading_time, previous_calibrated_value, previous_uncalibrated_value,
                    removed
               FROM sensor WHERE module_id = ?"#,
        )?;

        let sensors = stmt.query_map(params![module_id], Db::row_to_sensor)?;

        Ok(sensors.map(|r| Ok(r?)).collect::<Result<Vec<_>>>()?)
    }

    /// Right now syncing state is in the file system and that seems to work
    /// really well. Strongly considering removing this and dropping the table.
    #[allow(dead_code)]
    fn add_station_download(&self, download: &StationDownload) -> Result<StationDownload> {
        let conn = self.require_opened()?;
        let mut stmt = conn.prepare(
            r#"
            INSERT INTO station_download
            (station_id, generation_id, started, begin, end, path, uploaded, finished, size, error) VALUES
            (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            "#,
        )?;

        let affected = stmt.execute(params![
            download.station_id,
            download.generation_id,
            download.started.to_rfc3339(),
            download.begin,
            download.end,
            download.path,
            download.uploaded,
            download.finished.map(|f| f.to_rfc3339()),
            download.size,
            download.error
        ])?;

        assert_eq!(affected, 1);

        let id = Some(conn.last_insert_rowid());

        Ok(StationDownload {
            id,
            station_id: download.station_id,
            generation_id: download.generation_id.clone(),
            started: download.started,
            begin: download.begin,
            end: download.end,
            path: download.path.clone(),
            uploaded: download.uploaded,
            finished: download.finished,
            size: download.size,
            error: download.error.clone(),
        })
    }

    /// Right now syncing state is in the file system and that seems to work
    /// really well. Strongly considering removing this and dropping the table.
    #[allow(dead_code)]
    fn update_station_download(&self, download: &StationDownload) -> Result<StationDownload> {
        let conn = self.require_opened()?;
        let mut stmt = conn.prepare(
            r#"
            UPDATE station_download SET
                station_id = ?, generation_id = ?, started = ?, begin = ?, end = ?,
                path = ?, uploaded = ?, finished = ?, size = ?, error = ?
            WHERE id = ?"#,
        )?;

        let affected = stmt.execute(params![
            download.station_id,
            download.generation_id,
            download.started.to_rfc3339(),
            download.begin,
            download.end,
            download.path,
            download.uploaded,
            download.finished.map(|f| f.to_rfc3339()),
            download.size,
            download.error,
            download.id
        ])?;

        assert_eq!(affected, 1);

        Ok(download.clone())
    }

    /// Right now syncing state is in the file system and that seems to work
    /// really well. Strongly considering removing this and dropping the table.
    #[allow(dead_code)]
    fn get_station_downloads(&self, station_id: i64) -> Result<Vec<StationDownload>> {
        let mut stmt = self.require_opened()?.prepare(
            r#"SELECT id, station_id, generation_id, started, begin, end, path, uploaded, finished, size, error, id
               FROM station_download WHERE station_id = ?"#,
        )?;

        let downloads = stmt.query_map(params![station_id], |row| {
            let started: String = row.get(3)?;
            let started = DateTime::parse_from_rfc3339(&started)
                .expect("Parsing started")
                .with_timezone(&Utc);
            let finished: Option<String> = row.get(8)?;
            let finished = finished.map(|f| {
                DateTime::parse_from_rfc3339(&f)
                    .expect("Parsing finished")
                    .with_timezone(&Utc)
            });

            Ok(StationDownload {
                id: row.get(0)?,
                station_id: row.get(1)?,
                generation_id: row.get(2)?,
                started,
                begin: row.get(4)?,
                end: row.get(5)?,
                path: row.get(6)?,
                uploaded: row.get(7)?,
                finished,
                size: row.get(9)?,
                error: row.get(10)?,
            })
        })?;

        Ok(downloads.map(|r| Ok(r?)).collect::<Result<Vec<_>>>()?)
    }

    pub fn require_opened(&self) -> Result<&Connection> {
        match &self.conn {
            Some(conn) => Ok(conn),
            None => Err(anyhow!("Expected open database")),
        }
    }
}

struct DatabaseReading {
    time: Option<String>,
    calibrated: Option<f32>,
    uncalibrated: Option<f32>,
}

impl DatabaseReading {
    fn to_value(self) -> Option<LiveValue> {
        let time = self.time.map(|r| {
            DateTime::parse_from_rfc3339(&r)
                .expect("Parsing reading_time")
                .with_timezone(&Utc)
        });

        match (time, self.calibrated, self.uncalibrated) {
            (Some(reading_time), Some(calibrated), Some(uncalibrated)) => Some(LiveValue {
                time: reading_time,
                value: calibrated,
                uncalibrated,
            }),
            _ => None,
        }
    }
}

#[cfg(test)]
mod tests {
    use crate::test::*;

    use super::*;

    #[test]
    fn test_opening_in_memory_db() -> Result<()> {
        let mut db = Db::new();
        db.open_in_memory()?;

        Ok(())
    }

    #[test]
    fn test_adding_new_station() -> Result<()> {
        let mut db = Db::new();
        db.open_in_memory()?;

        let added = db.add_station(&BuildStation::default().build())?;
        assert_ne!(added.id, None);

        Ok(())
    }

    #[test]
    fn test_querying_all_stations() -> Result<()> {
        let mut db = Db::new();
        db.open_in_memory()?;

        db.persist_station(&BuildStation::default().with_basic_module("basic-0").build())?;

        let stations = db.get_stations()?;
        assert_eq!(stations.len(), 1);
        assert_eq!(stations[0].modules.len(), 1);
        assert_eq!(stations[0].modules[0].sensors.len(), 2);

        Ok(())
    }

    #[test]
    fn test_updating_station() -> Result<()> {
        let mut db = Db::new();
        db.open_in_memory()?;

        let mut added = db.add_station(&BuildStation::default().build())?;

        let stations = db.get_stations()?;
        assert_eq!(stations.len(), 1);
        assert_eq!(stations.get(0).unwrap().name, "Hoppy Kangaroo");

        added.name = "Tired Kangaroo".to_owned();
        db.update_station(&added)?;

        let stations = db.get_stations()?;
        assert_eq!(stations.len(), 1);
        assert_eq!(stations.get(0).unwrap().name, "Tired Kangaroo");

        Ok(())
    }

    #[test]
    fn test_updating_station_location() -> Result<()> {
        let mut db = Db::new();
        db.open_in_memory()?;

        let added = db.add_station(&BuildStation::default().build())?;

        assert_eq!(added.last_seen_location.is_none(), true);

        db.update_station_location(&added.device_id, 1.0, 2.0)?;

        let station = db.get_station_by_device_id(&added.device_id)?.unwrap();

        assert_eq!(station.last_seen_location.as_ref().unwrap().latitude, 1.0);
        assert_eq!(station.last_seen_location.as_ref().unwrap().longitude, 2.0);

        Ok(())
    }

    #[test]
    fn test_adding_module() -> Result<()> {
        let mut db = Db::new();
        db.open_in_memory()?;

        let station = db.add_station(&BuildStation::default().build())?;
        assert_ne!(station.id, None);

        let module = db.add_module(&BuildModule::default().station_id(station.id).build())?;
        assert_ne!(module.id, None);

        let modules = db.get_modules(station.id.expect("No station id"))?;
        assert_eq!(modules.len(), 1);

        Ok(())
    }

    #[test]
    fn test_updating_module() -> Result<()> {
        let mut db = Db::new();
        db.open_in_memory()?;

        let station = db.add_station(&BuildStation::default().build())?;
        assert_ne!(station.id, None);

        let mut added = db.add_module(
            &BuildModule::default()
                .hardware_id("module-0")
                .named("module-0")
                .station_id(station.id)
                .build(),
        )?;

        let modules = db.get_modules(station.id.expect("No station id"))?;
        assert_eq!(modules.len(), 1);
        assert_eq!(modules.get(0).unwrap().key, "module-0");

        added.key = "renamed-module-0".to_owned();
        db.update_module(&added)?;

        let modules = db.get_modules(station.id.expect("No station id"))?;
        assert_eq!(modules.len(), 1);
        assert_eq!(modules.get(0).unwrap().key, "renamed-module-0");

        Ok(())
    }

    #[test]
    fn test_adding_sensor() -> Result<()> {
        let mut db = Db::new();
        db.open_in_memory()?;

        let station = db.add_station(&BuildStation::default().build())?;
        assert_ne!(station.id, None);

        let module = db.add_module(&BuildModule::default().station_id(station.id).build())?;
        assert_ne!(module.id, None);

        let sensor = db.add_sensor(&BuildSensor::default().module_id(module.id).build())?;
        assert_ne!(sensor.id, None);

        let sensors = db.get_sensors(module.id.expect("No module id"))?;
        assert_eq!(sensors.len(), 1);

        Ok(())
    }

    #[test]
    fn test_updating_sensor() -> Result<()> {
        let mut db = Db::new();
        db.open_in_memory()?;

        let station = db.add_station(&build().station().build())?;
        assert_ne!(station.id, None);

        let module = db.add_module(&build().module().station_id(station.id).build())?;
        assert_ne!(module.id, None);

        let mut sensor = db.add_sensor(&BuildSensor::default().module_id(module.id).build())?;
        assert_ne!(sensor.id, None);

        let sensors = db.get_sensors(module.id.expect("No module id"))?;
        assert_eq!(sensors.len(), 1);
        assert_eq!(sensors.get(0).unwrap().key, "sensor-0");

        sensor.key = "renamed-sensor-0".to_owned();
        db.update_sensor(&sensor)?;

        let sensors = db.get_sensors(module.id.expect("No module id"))?;
        assert_eq!(sensors.len(), 1);
        assert_eq!(sensors.get(0).unwrap().key, "renamed-sensor-0");

        Ok(())
    }

    #[test]
    fn test_sync_new_station() -> Result<()> {
        let mut db = Db::new();
        db.open_in_memory()?;

        let incoming = BuildStation::default().with_basic_module("basic-0").build();
        let station = db.synchronize(incoming)?;

        assert!(station.id.is_some());

        for module in station.modules {
            assert!(module.id.is_some());
            for sensor in module.sensors {
                assert!(sensor.id.is_some());
            }
        }

        Ok(())
    }

    #[test]
    fn test_sync_station_with_only_field_changes() -> Result<()> {
        let mut db = Db::new();
        db.open_in_memory()?;

        let incoming = BuildStation::default().with_basic_module("basic-0").build();
        let first = db.synchronize(incoming)?;

        assert!(first.id.is_some());

        let mut incoming = BuildStation::default().with_basic_module("basic-0").build();
        incoming.name = "Renamed".to_owned();
        let second = db.synchronize(incoming)?;

        assert_eq!(first.id, second.id);
        assert_eq!(second.name, "Renamed");

        Ok(())
    }

    #[test]
    fn test_sync_station_with_module_removed() -> Result<()> {
        let mut db = Db::new();
        db.open_in_memory()?;

        let incoming = BuildStation::default().with_basic_module("basic-0").build();
        let first = db.synchronize(incoming)?;

        assert!(first.id.is_some());

        let incoming = BuildStation::default().build();
        let second = db.synchronize(incoming)?;

        assert_eq!(first.id, second.id);
        assert_eq!(second.modules.len(), 1);
        assert_eq!(second.modules.get(0).map(|m| m.removed), Some(true));

        let queried = db.get_stations()?;
        assert_eq!(queried[0].modules.len(), 0);

        Ok(())
    }

    #[test]
    fn test_sync_station_with_module_removed_and_brought_back_uses_same_row() -> Result<()> {
        let mut db = Db::new();
        db.open_in_memory()?;

        let incoming = BuildStation::default().with_basic_module("basic-0").build();
        let first = db.synchronize(incoming)?;

        assert!(first.id.is_some());

        let incoming = BuildStation::default().build();
        let second = db.synchronize(incoming)?;

        assert_eq!(first.id, second.id);
        assert_eq!(second.modules.len(), 1);
        assert_eq!(second.modules.get(0).map(|m| m.removed), Some(true));

        let queried = db.get_stations()?;
        assert_eq!(queried[0].modules.len(), 0);

        let incoming = BuildStation::default().with_basic_module("basic-0").build();
        let second = db.synchronize(incoming)?;
        assert_eq!(second.modules.len(), 1);
        assert_eq!(second.modules.get(0).map(|m| m.removed), Some(false));

        let queried = db.get_stations()?;
        assert_eq!(queried[0].modules.len(), 1);

        Ok(())
    }

    #[test]
    fn test_sync_station_with_module_added() -> Result<()> {
        let mut db = Db::new();
        db.open_in_memory()?;

        let incoming = BuildStation::default().with_basic_module("basic-0").build();
        let first = db.synchronize(incoming)?;

        assert!(first.id.is_some());

        let incoming = BuildStation::default()
            .with_basic_module("basic-0")
            .with_basic_module("basic-1")
            .build();
        let second = db.synchronize(incoming)?;

        assert_eq!(first.id, second.id);
        assert_eq!(second.modules.len(), 2);

        Ok(())
    }

    #[test]
    fn test_adding_new_station_download() -> Result<()> {
        let mut db = Db::new();
        db.open_in_memory()?;

        let station = db.add_station(&build().station().build())?;
        let adding = build().download().station_id(station.id).build();
        let added = db.add_station_download(&adding)?;
        assert_ne!(added.id, None);

        Ok(())
    }

    #[test]
    fn test_querying_station_downloads() -> Result<()> {
        let mut db = Db::new();
        db.open_in_memory()?;

        let station = db.add_station(&build().station().build())?;
        let adding = build().download().station_id(station.id).build();
        db.add_station_download(&adding)?;

        let stations = db.get_station_downloads(station.id.unwrap())?;
        assert_eq!(stations.len(), 1);

        Ok(())
    }

    #[test]
    fn test_updating_station_download() -> Result<()> {
        let mut db = Db::new();
        db.open_in_memory()?;

        let station = db.add_station(&build().station().build())?;
        let adding = build().download().station_id(station.id).build();
        let mut added = db.add_station_download(&adding)?;

        let stations = db.get_station_downloads(station.id.unwrap())?;
        assert_eq!(stations.len(), 1);
        assert!(stations.get(0).unwrap().finished.is_none());

        added.finished = Some(Utc::now());
        db.update_station_download(&added)?;

        let stations = db.get_station_downloads(station.id.unwrap())?;
        assert_eq!(stations.len(), 1);
        assert!(stations.get(0).unwrap().finished.is_some());

        Ok(())
    }

    #[test]
    fn test_delete_station() -> Result<()> {
        let mut db = Db::new();
        db.open_in_memory()?;

        let station = db.add_station(&build().station().build())?;
        let adding = build().download().station_id(station.id).build();
        db.add_station_download(&adding)?;

        let stations = db.get_station_downloads(station.id.unwrap())?;
        assert_eq!(stations.len(), 1);
        assert!(stations.get(0).unwrap().finished.is_none());

        db.delete_station(station.id.unwrap())?;

        assert!(db.get_all_stations()?.is_empty());

        Ok(())
    }

    #[test]
    fn test_delete_station_by_devicec_id() -> Result<()> {
        let mut db = Db::new();
        db.open_in_memory()?;

        let station = db.add_station(&build().station().build())?;
        let adding = build().download().station_id(station.id).build();
        db.add_station_download(&adding)?;

        let stations = db.get_station_downloads(station.id.unwrap())?;
        assert_eq!(stations.len(), 1);
        assert!(stations.get(0).unwrap().finished.is_none());

        db.delete_station_by_device_id(&station.device_id)?;

        assert!(db.get_all_stations()?.is_empty());

        Ok(())
    }
}
