use anyhow::Result;
use chrono::Utc;
use std::collections::{HashMap, HashSet};

use crate::{Module, Sensor, Station};

pub fn merge(existing: Option<Station>, incoming: Station) -> Result<Station> {
    match existing {
        Some(existing) => Ok(Station {
            id: existing.id,
            device_id: existing.device_id,
            name: incoming.name,
            generation_id: incoming.generation_id,
            firmware: incoming.firmware,
            meta: incoming.meta,
            data: incoming.data,
            battery: incoming.battery,
            solar: incoming.solar,
            last_seen: Utc::now(),
            modules: merge_modules(existing.modules, incoming.modules)?,
            status: incoming.status,
            last_seen_location: incoming.last_seen_location.or(existing.last_seen_location),
        }),
        None => Ok(incoming),
    }
}

fn merge_modules(existing: Vec<Module>, incoming: Vec<Module>) -> Result<Vec<Module>> {
    let existing: HashMap<_, _> = existing
        .into_iter()
        .map(|m| (m.hardware_id.clone(), m))
        .collect();
    let incoming: HashMap<_, _> = incoming
        .into_iter()
        .map(|m| (m.hardware_id.clone(), m))
        .collect();

    let keys: HashSet<_> = existing
        .keys()
        .clone()
        .chain(incoming.keys().clone())
        .collect();

    let mut modules = keys
        .into_iter()
        .map(|key| (existing.get(key), incoming.get(key)))
        .map(|pair| match pair {
            (Some(existing), Some(incoming)) => Ok(Module {
                position: incoming.position,
                flags: incoming.flags,
                configuration: incoming.configuration.clone(),
                key: incoming.key.clone(),
                path: incoming.path.clone(),
                sensors: merge_sensors(existing.sensors.clone(), incoming.sensors.clone())?,
                removed: false,
                ..existing.clone()
            }),
            (None, Some(added)) => Ok(added.clone()),
            (Some(removed), None) => Ok(Module {
                removed: true,
                ..removed.clone()
            }),
            (None, None) => panic!("Surprise module key?"),
        })
        .collect::<Result<Vec<_>>>()?;

    modules.sort_by(|a, b| {
        if a.position == b.position {
            a.key.cmp(&b.key)
        } else {
            a.position.cmp(&b.position)
        }
    });

    Ok(modules)
}

fn merge_sensors(existing: Vec<Sensor>, incoming: Vec<Sensor>) -> Result<Vec<Sensor>> {
    let existing: HashMap<_, _> = existing.into_iter().map(|m| (m.number, m)).collect();
    let incoming: HashMap<_, _> = incoming.into_iter().map(|m| (m.number, m)).collect();

    let keys: HashSet<_> = existing
        .keys()
        .clone()
        .chain(incoming.keys().clone())
        .collect();

    Ok(keys
        .into_iter()
        .map(|key| (existing.get(key), incoming.get(key)))
        .map(|pair| match pair {
            (Some(existing), Some(incoming)) => Ok(Sensor {
                key: incoming.key.clone(),
                flags: incoming.flags,
                calibrated_uom: incoming.calibrated_uom.clone(),
                uncalibrated_uom: incoming.uncalibrated_uom.clone(),
                value: incoming.value.clone(),
                ..existing.clone()
            }),
            (None, Some(added)) => Ok(added.clone()),
            (Some(removed), None) => Ok(Sensor {
                removed: true,
                ..removed.clone()
            }),
            (None, None) => panic!("Surprise sensor key?"),
        })
        .collect::<Result<Vec<_>>>()?)
}
