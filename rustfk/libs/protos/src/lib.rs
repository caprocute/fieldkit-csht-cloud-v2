use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};
use std::{collections::HashMap, fs::OpenOptions, path::Path};
use tokio::{fs::File, io::AsyncReadExt};

pub mod data {
    include!("fk_data.rs");
}

pub mod http {
    include!("fk_app.rs");
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct FileMeta {
    pub sync_id: String,
    pub device_id: String,
    pub generation_id: Option<String>,
    pub head: i64,
    pub tail: i64,
    pub data_name: String,
    pub headers: HashMap<String, String>,
    pub uploaded: Option<i64>,
}

impl FileMeta {
    pub async fn load_from_json(path: &Path) -> Result<Self> {
        let mut file = File::open(path).await?;
        let mut string = String::new();
        file.read_to_string(&mut string).await?;
        Ok(serde_json::from_str(&string)?)
    }

    pub fn load_from_json_sync(path: &Path) -> Result<Self> {
        use std::io::prelude::*;
        let mut file = std::fs::File::open(path)?;
        let mut string = String::new();
        file.read_to_string(&mut string)?;
        Ok(serde_json::from_str(&string)?)
    }

    pub fn save(&self, path: &Path) -> Result<()> {
        let writing = OpenOptions::new()
            .write(true)
            .create(true)
            .truncate(true)
            .open(path)
            .with_context(|| format!("Writing {:?}", &path))?;

        serde_json::to_writer(writing, self)?;

        Ok(())
    }
}

pub const MODULES_FLAG_INTERNAL: u32 = 0x1;

pub struct ModuleFlags(u32);

impl ModuleFlags {
    pub fn new(value: u32) -> Self {
        Self(value)
    }
}

impl From<u32> for ModuleFlags {
    fn from(value: u32) -> Self {
        Self(value)
    }
}

pub trait InternalFlag {
    fn internal(&self) -> bool;
}

impl InternalFlag for ModuleFlags {
    fn internal(&self) -> bool {
        self.0 & MODULES_FLAG_INTERNAL == MODULES_FLAG_INTERNAL
    }
}

impl InternalFlag for data::ModuleInfo {
    fn internal(&self) -> bool {
        ModuleFlags(self.flags).internal()
    }
}
