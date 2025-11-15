use anyhow::{anyhow, Result};
use backoff::{backoff::Backoff, ExponentialBackoff, ExponentialBackoffBuilder};
use discovery::{DeviceId, Discovered};
use range_set_blaze::prelude::*;
use std::{
    collections::HashMap,
    net::SocketAddr,
    ops::RangeInclusive,
    sync::Arc,
    time::{Duration, SystemTime},
};
use tokio::{
    sync::{
        mpsc::{self, Receiver, Sender},
        Mutex,
    },
    time::{self, Instant},
};
use tracing::*;

use crate::{
    progress::{Progress, RangeProgress},
    proto::{Identity, Message, ReceivedRecords, RecordRange},
    transport::{ReceiveTransport, SendTransport},
    FileMeta, Transport, TransportMessage,
};

const STALLED_EXPECTING_MILLIS: u64 = 5000;
const STALLED_RECEIVING_MILLIS: u64 = 500;
const REQUIRES_MERGE_WIDTH: u64 = 500;

#[derive(Debug)]
pub enum SinkMessage {
    Records(ReceivedRecords),
    Flush(String, Identity),
}

#[derive(Debug)]
pub struct RecordSinkArchive {
    pub device_id: String,
    pub generation_id: String,
    pub path: String,
    pub meta: FileMeta,
}

#[derive(Debug, PartialEq, Eq, Clone)]
pub struct Flushed {
    pub head_record: i64,
    pub total_records: i64,
}

pub trait RecordsSink: Send + Sync {
    fn query_archives(&self) -> Result<Vec<RecordSinkArchive>>;
    fn write(&self, records: &ReceivedRecords) -> Result<()>;
    fn flush(&self, sync_id: String, identity: Identity) -> Result<Flushed>;
    fn uploaded(&self, archive: String) -> Result<()>;
}

#[derive(Default)]
pub struct DevNullSink {}

impl RecordsSink for DevNullSink {
    fn query_archives(&self) -> Result<Vec<RecordSinkArchive>> {
        Ok(Vec::new())
    }

    fn write(&self, _records: &ReceivedRecords) -> Result<()> {
        Ok(())
    }

    fn flush(&self, _sync_id: String, _identity: Identity) -> Result<Flushed> {
        Ok(Flushed {
            head_record: 0,
            total_records: 0,
        })
    }

    fn uploaded(&self, _archive: String) -> Result<()> {
        Ok(())
    }
}

#[derive(Debug)]
pub enum ServerEvent {
    Began(DeviceId),
    Transferring(DeviceId, Option<u64>, SystemTime, Progress),
    Processing(DeviceId),
    Completed(DeviceId),
    Failed(DeviceId),
    Available(Vec<RecordSinkArchive>),
}

#[derive(Debug)]
pub enum ServerCommand {
    Begin(Discovered, Option<u64>),
    Cancel(DeviceId),
    Received(TransportMessage),
    Tick,
    Flushed(Option<Flushed>),
}

#[derive(Clone)]
struct Until(Instant);

impl Until {
    fn before(&self) -> bool {
        Instant::now() < self.0
    }
}

impl std::fmt::Debug for Until {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{:?}", self.0 - Instant::now())
    }
}

#[derive(Clone, Debug)]
enum DeviceState {
    Discovered,
    Learning,
    Required(RecordRange),
    Receiving(RecordRange),
    Stalled(Until),
    Processing,
    Synced,
    Failed,
}

#[derive(Debug)]
#[allow(dead_code)]
enum HasGaps {
    Continuous(RangeInclusive<u64>),
    HasGaps(RangeInclusive<u64>, Vec<RangeInclusive<u64>>),
}

#[derive(Default)]
pub struct Statistics {
    pub messages_received: u32,
}

struct ConnectedDevice {
    batch_size: u64,
    device_id: DeviceId,
    addr: SocketAddr,
    sync_id: String,
    state: DeviceState,
    identity: Option<Identity>,
    syncing_started: Option<SystemTime>,
    progress_published: Option<Instant>,
    received_at: Option<Instant>,
    first: Option<u64>,
    total_records: Option<u64>,
    received: RangeSetBlaze<u64>,
    backoff: ExponentialBackoff,
    statistics: Statistics,
}

impl std::fmt::Debug for ConnectedDevice {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("ConnectedDevice")
            .field("device_id", &self.device_id)
            .field("addr", &self.addr)
            .field("sync_id", &self.sync_id)
            .field("state", &self.state)
            .field("received_at", &self.received_at)
            .field("first", &self.first)
            .field("total_records", &self.total_records)
            // .field("batch_size", &self.batch_size)
            // .field("identity", &self.identity)
            // .field("syncing_started", &self.syncing_started)
            // .field("progress_published", &self.progress_published)
            // .field("received", &self.received)
            // .field("backoff", &self.backoff)
            // .field("statistics", &self.statistics)
            .finish()
    }
}

#[derive(Debug)]
enum Transition {
    None,
    Direct(DeviceState),
    Send(Message, DeviceState),
}

fn new_sync_id() -> String {
    use chrono::offset::Utc;
    use chrono::DateTime;
    let now: DateTime<Utc> = SystemTime::now().into();
    now.format("%Y%m%d_%H%M%S").to_string()
}

impl ConnectedDevice {
    fn new_with_batch_size(device_id: DeviceId, addr: SocketAddr, batch_size: u64) -> Self {
        Self {
            device_id,
            addr,
            batch_size,
            state: DeviceState::Discovered,
            identity: None,
            received_at: None,
            first: None,
            total_records: None,
            received: RangeSetBlaze::new(),
            backoff: Self::stall_backoff(),
            sync_id: new_sync_id(),
            syncing_started: None,
            progress_published: None,
            statistics: Default::default(),
        }
    }

    fn new(device_id: DeviceId, addr: SocketAddr) -> Self {
        Self::new_with_batch_size(device_id, addr, 5000)
    }

    fn try_begin(&mut self, first: Option<u64>) -> Transition {
        match &self.state {
            DeviceState::Discovered | DeviceState::Synced | DeviceState::Failed => {
                self.first = first;
                self.total_records = None;
                self.received.clear();
                self.received_at = None;
                self.sync_id = new_sync_id();
                self.syncing_started = Some(SystemTime::now());
                self.progress_published = None;
                self.statistics = Default::default();
                self.backoff.reset();

                Transition::Send(Message::Query, DeviceState::Learning)
            }
            _ => Transition::None,
        }
    }

    fn tick(&mut self) -> Result<Transition> {
        match &self.state {
            DeviceState::Synced | DeviceState::Failed => Ok(Transition::None),
            DeviceState::Learning => {
                if self.is_stalled()
                    || self.started_more_than(Duration::from_millis(STALLED_EXPECTING_MILLIS))
                {
                    info!("STALL {:?}", self.last_received_at(),);
                    // No need to process any received records if we've failed
                    // in learning, since we never got around to asking for any
                    // records.
                    Ok(Transition::Direct(DeviceState::Failed))
                } else {
                    Ok(Transition::None)
                }
            }
            DeviceState::Discovered => {
                self.received.clear();

                Ok(Transition::Send(Message::Query, DeviceState::Learning))
            }
            DeviceState::Stalled(until) => {
                if until.before() {
                    Ok(Transition::None)
                } else {
                    self.query_requires()
                }
            }
            _ => {
                if self.is_stalled() {
                    if let Some(delay) = self.backoff.next_backoff() {
                        info!("STALL {:?}", self.last_received_at(),);
                        Ok(Transition::Direct(DeviceState::Stalled(Until(
                            Instant::now() + delay,
                        ))))
                    } else {
                        info!("FAILED {:?}", self.last_received_at(),);
                        Ok(Transition::Direct(DeviceState::Processing))
                    }
                } else {
                    Ok(Transition::None)
                }
            }
        }
    }

    fn flushed(&self, flushed: Option<Flushed>) -> Transition {
        match &self.state {
            DeviceState::Processing => {
                if let Some(flushed) = flushed {
                    debug!(
                        "{:?} (flushed={}) first={:?} total={:?}",
                        flushed,
                        flushed.head_record + flushed.total_records,
                        self.first,
                        self.total_records,
                    );
                    let last_flushed = flushed.head_record + flushed.total_records;
                    let got_everything = self
                        .total_records
                        .map(|total| last_flushed >= total as i64)
                        .unwrap_or_default();
                    if self.is_stalled() || !got_everything {
                        Transition::Direct(DeviceState::Failed)
                    } else {
                        Transition::Direct(DeviceState::Synced)
                    }
                } else {
                    Transition::Direct(DeviceState::Failed)
                }
            }
            _ => {
                warn!("Flushed during {:?}", self.state);
                Transition::None
            }
        }
    }

    fn handle(&mut self, message: &Message) -> Result<Transition> {
        self.statistics.messages_received += 1;
        self.received_at = Some(Instant::now());
        self.backoff.reset();

        match message {
            Message::Statistics { nrecords, identity } => {
                self.identity = Some(identity.clone());
                self.total_records = Some(*nrecords);
                if let Some(first) = self.first {
                    self.received(RangeSetBlaze::from_iter([0..=first]));
                }
                self.query_requires()
            }
            Message::Records {
                head,
                flags: _flags,
                sequence: _sequence,
                records,
            } => {
                assert!(!records.is_empty());

                // Include the received records in our received set.
                let just_received: RangeSetBlaze<u64> =
                    (0..records.len()).map(|v| v as u64 + *head).collect();
                self.received(just_received);

                let progress = self.progress();
                let has_gaps = self.received_has_gaps();
                let progress = progress.map_or("".to_owned(), |f| format!("{:?}", f));
                trace!(target: "transfer-progress", "{} {:?}", progress, &has_gaps);

                match &self.state {
                    DeviceState::Required(range) => {
                        Ok(Transition::Direct(DeviceState::Receiving(range.clone())))
                    }
                    _ => Ok(Transition::None),
                }
            }
            Message::Batch {
                flags: _flags,
                errors: _errors,
            } => self.query_requires(),
            _ => Ok(Transition::None),
        }
    }

    fn query_requires(&mut self) -> Result<Transition> {
        if let Some(range) = self.requires() {
            let new_state = DeviceState::Required(range.clone());
            Ok(Transition::Send(Message::Require(range), new_state))
        } else {
            if self.total_records.is_some() {
                let elapsed = SystemTime::now().duration_since(self.syncing_started.unwrap())?;
                info!("Transferring {:?} took {:?}", self.total_records, elapsed);

                Ok(Transition::Direct(DeviceState::Processing))
            } else {
                Ok(Transition::None)
            }
        }
    }

    fn requires(&self) -> Option<RecordRange> {
        fn cap_length(r: RangeInclusive<u64>, len: u64) -> RangeInclusive<u64> {
            assert!(len > 0);
            let end = *r.end();
            let start = *r.start();
            if end - start > len {
                start..=(start + len - 1)
            } else {
                r
            }
        }

        fn try_merge(
            first: Option<RangeInclusive<u64>>,
            second: RangeInclusive<u64>,
            len: u64,
        ) -> Option<RangeInclusive<u64>> {
            match &first {
                Some(first) => {
                    let combined = *first.start()..=*second.end();
                    let width = combined.end() - combined.start();
                    if width > len {
                        Some(first.clone())
                    } else {
                        Some(combined)
                    }
                }
                None => Some(second),
            }
        }

        let total_records = self.total_records?;
        let total_required = RangeSetBlaze::from_iter([0..=total_records - 1]) - &self.received;

        let mut requiring: Option<RangeInclusive<u64>> = None;
        for range in total_required.into_ranges() {
            requiring = try_merge(
                requiring,
                cap_length(range, self.batch_size),
                REQUIRES_MERGE_WIDTH,
            );
        }

        requiring.map(RecordRange)
    }

    fn received(&mut self, records: RangeSetBlaze<u64>) {
        let mut appending = records;
        self.received.append(&mut appending);
    }

    fn last_received_at(&self) -> Option<Duration> {
        self.received_at.map(|r| Instant::now() - r)
    }

    fn started_more_than(&self, d: Duration) -> bool {
        self.syncing_started
            .and_then(|v| v.elapsed().ok())
            .map(|v| v > d)
            .unwrap_or(false)
    }

    fn last_received_more_than(&self, d: Duration) -> bool {
        self.last_received_at().map(|v| v > d).unwrap_or(false)
    }

    fn is_stalled(&self) -> bool {
        match &self.state {
            DeviceState::Learning | DeviceState::Required(_) => {
                self.last_received_more_than(Duration::from_millis(STALLED_EXPECTING_MILLIS))
            }
            DeviceState::Receiving(_) => {
                self.last_received_more_than(Duration::from_millis(STALLED_RECEIVING_MILLIS))
            }
            _ => false,
        }
    }

    fn received_has_gaps(&self) -> HasGaps {
        match self.received.last() {
            Some(last) => {
                let full_range = 0..=last;
                if last as u128 + 1 == self.received.len() {
                    HasGaps::Continuous(full_range)
                } else {
                    let inverted = RangeSetBlaze::from_iter(full_range.clone()) - &self.received;
                    let gaps = inverted
                        .into_ranges()
                        .collect::<Vec<std::ops::RangeInclusive<_>>>();
                    HasGaps::HasGaps(full_range, gaps)
                }
            }
            None => HasGaps::Continuous(0..=0),
        }
    }

    fn stall_backoff() -> ExponentialBackoff {
        ExponentialBackoffBuilder::new()
            .with_initial_interval(Duration::from_millis(5000))
            .with_randomization_factor(0.0)
            .with_multiplier(1.8)
            .with_max_elapsed_time(Some(Duration::from_secs(30)))
            .build()
    }

    fn completed(&self) -> Option<RangeProgress> {
        if let Some(total) = self.total_records {
            Some(RangeProgress::new(0..=(total - 1), &self.received))
        } else {
            None
        }
    }

    fn batch(&self) -> Option<RangeProgress> {
        match &self.state {
            DeviceState::Receiving(range) => {
                Some(RangeProgress::new(range.0.clone(), &self.received))
            }
            _ => None,
        }
    }

    fn progress(&self) -> Option<Progress> {
        match &self.state {
            DeviceState::Receiving(_range) => Some(Progress {
                total: self.completed(),
                batch: self.batch(),
            }),
            _ => None,
        }
    }

    async fn transition(
        &mut self,
        new: DeviceState,
        events: &Sender<ServerEvent>,
        sink: &Sender<SinkMessage>,
    ) -> Result<()> {
        info!(
            "{:?} -> {:?} (publish = {}) (sink = {})",
            &self.state,
            &new,
            events.max_capacity() - events.capacity(),
            sink.max_capacity() - sink.capacity()
        );

        match (&self.state, &new) {
            (DeviceState::Synced, _) => {}
            (DeviceState::Failed, _) => {}
            (_, DeviceState::Learning) => {
                events
                    .send(ServerEvent::Began(self.device_id.clone()))
                    .await?;
            }
            (_, DeviceState::Processing) => {
                events
                    .send(ServerEvent::Processing(self.device_id.clone()))
                    .await?;
                sink.send(SinkMessage::Flush(
                    self.sync_id.clone(),
                    self.identity
                        .clone()
                        .ok_or_else(|| anyhow!("No identity in Flush"))?,
                ))
                .await?;
            }
            (_, DeviceState::Synced) => {
                events
                    .send(ServerEvent::Completed(self.device_id.clone()))
                    .await?;
            }
            (_, DeviceState::Failed) => {
                events
                    .send(ServerEvent::Failed(self.device_id.clone()))
                    .await?;
            }
            (_, _) => {}
        }

        self.state = new;

        Ok(())
    }

    async fn apply<S: SendTransport>(
        &mut self,
        transition: Transition,
        events: &Sender<ServerEvent>,
        sink: &Sender<SinkMessage>,
        sender: &S,
    ) -> Result<()> {
        match transition {
            Transition::None => Ok(()),
            Transition::Direct(state) => {
                self.transition(state, events, sink).await?;

                Ok(())
            }
            Transition::Send(sending, state) => {
                sender
                    .send(TransportMessage((self.addr.clone(), sending)))
                    .await?;

                self.transition(state, events, sink).await?;

                Ok(())
            }
        }
    }
}

pub struct Server<T, R>
where
    T: Transport,
    R: RecordsSink,
{
    transport: T,
    records_sink: Arc<Mutex<R>>,
    sender: Arc<Mutex<Option<Sender<Vec<ServerCommand>>>>>,
    tx: Sender<ServerEvent>,
}

impl<T: Transport, R: RecordsSink + 'static> Server<T, R> {
    pub fn new(transport: T, records_sink: R) -> (Self, Receiver<ServerEvent>) {
        let (tx, rx) = tokio::sync::mpsc::channel::<ServerEvent>(32);
        (
            Self {
                transport,
                records_sink: Arc::new(Mutex::new(records_sink)),
                sender: Arc::new(Mutex::new(None)),
                tx,
            },
            rx,
        )
    }

    #[cfg(test)]
    pub async fn received(&self, addr: SocketAddr, message: Message) -> Result<()> {
        self.send(ServerCommand::Received(TransportMessage((addr, message))))
            .await
    }

    pub async fn sync(&self, discovered: Discovered, first: Option<u64>) -> Result<()> {
        self.send(ServerCommand::Begin(discovered, first)).await
    }

    pub async fn cancel(&self, device_id: DeviceId) -> Result<()> {
        self.send(ServerCommand::Cancel(device_id)).await
    }

    pub async fn check_for_archives(&self) -> Result<()> {
        let sink = self.records_sink.lock().await;
        let archives = sink.query_archives()?;

        self.tx.send(ServerEvent::Available(archives)).await?;

        Ok(())
    }

    pub async fn uploaded(&self, archive: String) -> Result<()> {
        let sink = self.records_sink.lock().await;
        sink.uploaded(archive)
    }

    pub async fn run(&self) -> Result<()> {
        let (tx, mut rx) = mpsc::channel::<Vec<ServerCommand>>(1024);
        let (sink_tx, mut sink_rx) = mpsc::channel::<SinkMessage>(1024);
        let (send, receive) = self.transport.open().await?;

        self.check_for_archives().await?;

        let drain_sink = tokio::spawn({
            let tx = tx.clone();
            let publish = self.tx.clone();
            let records_sink = Arc::clone(&self.records_sink);
            async move {
                while let Some(message) = sink_rx.recv().await {
                    let sink = records_sink.lock().await;
                    match message {
                        SinkMessage::Records(received) => match sink.write(&received) {
                            Err(e) => warn!("Write records error: {:?}", e),
                            Ok(_) => (),
                        },
                        SinkMessage::Flush(sync_id, identity) => {
                            info!("flushing");
                            match sink.flush(sync_id, identity) {
                                Err(e) => {
                                    warn!("Flush error: {:?}", e);
                                    // This send will trigger a transition to Failed
                                    match tx.send(vec![ServerCommand::Flushed(None)]).await {
                                        Ok(_) => {}
                                        Err(_) => warn!("Send Flushed error: {:?}", e),
                                    }
                                }
                                Ok(flushed) => {
                                    match tx.send(vec![ServerCommand::Flushed(Some(flushed))]).await
                                    {
                                        Err(e) => warn!("Send Flushed error: {:?}", e),
                                        Ok(_) => match sink.query_archives() {
                                            Ok(archives) => {
                                                match publish
                                                    .send(ServerEvent::Available(archives))
                                                    .await
                                                {
                                                    Err(e) => warn!("Publish error: {:?}", e),
                                                    Ok(_) => {}
                                                }
                                            }
                                            Err(e) => warn!("Query archives error: {:?}", e),
                                        },
                                    }
                                }
                            }
                        }
                    }
                }
            }
        });

        let receiver = tokio::spawn({
            let tx = tx.clone();
            async move {
                loop {
                    match receive.recv().await {
                        Ok(Some(received)) => {
                            match tx
                                .send(
                                    received
                                        .into_iter()
                                        .map(|m| ServerCommand::Received(m))
                                        .collect(),
                                )
                                .await
                            {
                                Err(e) => warn!("Error forwarding received: {:?}", e),
                                Ok(_) => {}
                            }
                        }
                        Ok(None) => warn!("Received empty messages"),
                        Err(e) => warn!("Error receiving: {:?}", e),
                    }
                }
            }
        });

        let pump = tokio::spawn({
            let publish = self.tx.clone();
            let tx = tx.clone();
            let mut devices = Devices::new();
            let mut locked = self.sender.lock().await;
            *locked = Some(tx.clone());
            async move {
                while let Some(batch) = rx.recv().await {
                    if tx.capacity() < tx.max_capacity() / 8 {
                        trace!(
                            "server-command:capacity = {}/{} ({})",
                            tx.capacity(),
                            tx.max_capacity(),
                            batch.len(),
                        );
                    }
                    for cmd in batch.iter() {
                        match handle_server_command::<R, T::Send>(
                            cmd,
                            &send,
                            &publish,
                            &sink_tx,
                            &mut devices,
                        )
                        .await
                        {
                            Ok(_) => {}
                            Err(e) => warn!("Server command error: {}", e),
                        }
                    }
                }
            }
        });

        let timer = tokio::spawn(async move {
            let mut interval = time::interval(Duration::from_millis(250));

            loop {
                interval.tick().await;

                match tx.send(vec![ServerCommand::Tick]).await {
                    Err(e) => warn!("Tick error: {}", e),
                    Ok(_) => {}
                }
            }
        });

        tokio::select! {
            e = drain_sink => {
                warn!("server-drain-sink: {:?}", e);
            },
            e = receiver => {
                warn!("server-receiver: {:?}", e);
            },
            e = pump => {
                warn!("server-pump: {:?}", e);
            },
            e = timer => {
                warn!("server-timer: {:?}", e);
            },
        };

        Ok(())
    }

    async fn send(&self, cmd: ServerCommand) -> Result<()> {
        let locked = self.sender.lock().await;
        Ok(locked
            .as_ref()
            .ok_or_else(|| anyhow!("Sender required"))?
            .send(vec![cmd])
            .await?)
    }
}

struct Devices {
    devices: HashMap<DeviceId, ConnectedDevice>,
    by_addr: HashMap<SocketAddr, DeviceId>,
}

impl Devices {
    fn new() -> Self {
        Self {
            devices: HashMap::new(),
            by_addr: HashMap::new(),
        }
    }

    fn get_or_add_device(
        &mut self,
        device_id: DeviceId,
        addr: SocketAddr,
    ) -> Option<&mut ConnectedDevice> {
        let entry = self.devices.entry(device_id.clone());
        let entry = entry.or_insert_with(|| ConnectedDevice::new(device_id.clone(), addr));

        self.by_addr.entry(addr).or_insert(device_id.clone());

        Some(entry)
    }

    fn get_device_by_addr(&mut self, addr: &SocketAddr) -> Option<&mut ConnectedDevice> {
        if let Some(device_id) = self.by_addr.get(addr) {
            self.devices.get_mut(device_id)
        } else {
            None
        }
    }

    /*
    fn remove_expired(&mut self) {
        for (device_id, addr) in self
            .devices
            .iter()
            .filter(|(_, connected)| connected.is_expired())
            .map(|(device_id, connected)| (device_id.clone(), connected.addr))
            .collect::<Vec<_>>()
        {
            info!("{:?}@{:?} expired", device_id, addr);
            self.by_addr.remove(&addr);
            self.devices.remove(&device_id);
        }
    }
    */

    fn iter(&mut self) -> impl Iterator<Item = &mut ConnectedDevice> {
        self.devices.iter_mut().map(|(_, c)| c)
    }

    fn remove(&mut self, device_id: &DeviceId) -> Option<ConnectedDevice> {
        if let Some((_, connected)) = self.devices.remove_entry(device_id) {
            info!("{:?} removed", device_id);
            self.by_addr.remove(&connected.addr);
            Some(connected)
        } else {
            None
        }
    }
}

async fn handle_server_command<R: RecordsSink, S: SendTransport>(
    cmd: &ServerCommand,
    sending: &S,
    events: &Sender<ServerEvent>,
    sink: &Sender<SinkMessage>,
    devices: &mut Devices,
) -> Result<()> {
    match cmd {
        ServerCommand::Begin(discovered, first) => {
            let udp_addr = discovered
                .udp_addr
                .ok_or(anyhow::anyhow!("Udp address is required"))?;

            match devices.get_or_add_device(discovered.device_id.clone(), udp_addr) {
                Some(connected) => {
                    let transition = connected.try_begin(first.clone());
                    connected.apply(transition, events, sink, sending).await?
                }
                None => warn!("No connected device on Begin"),
            }
        }
        ServerCommand::Received(TransportMessage((addr, message))) => {
            message.log_received();

            match devices.get_device_by_addr(addr) {
                Some(connected) => {
                    // Queue up the records into the record sink before applying
                    // the message, so that the final Flush is after them.
                    if let Some(records) = message.numbered_records()? {
                        sink.send(SinkMessage::Records(ReceivedRecords {
                            sync_id: connected.sync_id.clone(),
                            device_id: connected.device_id.clone(),
                            records,
                        }))
                        .await?;
                    }

                    let transition = connected.handle(message)?;
                    connected.apply(transition, events, sink, sending).await?;

                    if let Some(progress) = connected.progress() {
                        events
                            .send(ServerEvent::Transferring(
                                connected.device_id.clone(),
                                connected.first,
                                connected.syncing_started.unwrap_or(SystemTime::now()),
                                progress,
                            ))
                            .await?;
                        connected.progress_published = Some(Instant::now());
                    }
                }
                None => warn!("Unsolicited message: {:?}", message),
            }
        }
        ServerCommand::Flushed(flushed) => {
            for connected in devices.iter() {
                let transition = connected.flushed(flushed.clone());
                connected.apply(transition, events, sink, sending).await?;
            }
        }
        ServerCommand::Tick => {
            for connected in devices.iter() {
                let transition = connected.tick()?;
                connected.apply(transition, events, sink, sending).await?;
            }
        }
        ServerCommand::Cancel(device_id) => {
            if let Some(connected) = devices.remove(device_id) {
                info!("{:?} removed", device_id);
                match connected.state {
                    DeviceState::Failed | DeviceState::Synced => {}
                    _ => events.send(ServerEvent::Failed(device_id.clone())).await?,
                }
            }
        }
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use std::net::SocketAddrV4;

    use async_trait::async_trait;
    use tokio::sync::Mutex;

    use super::*;

    #[derive(Default)]
    pub struct VectorTransport {
        open: OpenVectorTransport,
    }

    impl VectorTransport {}

    #[derive(Default, Clone)]
    pub struct OpenVectorTransport {
        outbox: Arc<Mutex<Vec<TransportMessage>>>,
        inbox: Arc<Mutex<Vec<TransportMessage>>>,
    }

    #[async_trait]
    impl SendTransport for OpenVectorTransport {
        async fn send(&self, message: TransportMessage) -> Result<()> {
            let mut outbox = self.outbox.lock().await;
            outbox.push(message);

            Ok(())
        }
    }

    #[async_trait]
    impl ReceiveTransport for OpenVectorTransport {
        async fn recv(&self) -> Result<Option<Vec<TransportMessage>>> {
            let mut inbox = self.inbox.lock().await;
            Ok(inbox.pop().map(|m| vec![m]))
        }
    }

    #[async_trait]
    impl Transport for VectorTransport {
        type Send = OpenVectorTransport;
        type Receive = OpenVectorTransport;

        async fn open(&self) -> Result<(Self::Send, Self::Receive)> {
            Ok((self.open.clone(), self.open.clone()))
        }
    }

    fn test_device() -> ConnectedDevice {
        const IP_ALL: [u8; 4] = [0, 0, 0, 0];
        ConnectedDevice::new_with_batch_size(
            DeviceId("test-device".to_owned()),
            SocketAddrV4::new(IP_ALL.into(), 22144).into(),
            10000,
        )
    }

    #[test]
    pub fn test_server() {
        let transport = VectorTransport::default();
        let _server = Server::new(transport, DevNullSink::default());
    }

    #[test]
    pub fn test_unknown_total_records() {
        let connected = test_device();
        assert_eq!(connected.requires(), None);
    }

    #[test]
    pub fn test_requires_when_none_received() {
        let mut connected = test_device();
        connected.total_records = Some(100_000);
        assert_eq!(connected.requires(), Some(RecordRange(0..=9_999)));
    }

    #[test]
    pub fn test_requires_when_some_received() {
        let mut connected = test_device();
        connected.total_records = Some(100_000);
        connected.received(RangeSetBlaze::from_iter([0..=1000]));
        assert_eq!(connected.requires(), Some(RecordRange(1001..=11_000)));
    }

    #[test]
    pub fn test_requires_with_gap() {
        let mut connected = test_device();
        connected.total_records = Some(100_000);
        connected.received(RangeSetBlaze::from_iter([0..=1000]));
        connected.received(RangeSetBlaze::from_iter([3000..=4000]));
        assert_eq!(connected.requires(), Some(RecordRange(1001..=2999)));
    }

    #[test]
    pub fn test_requires_duplicates_when_gaps_are_clumped() {
        let mut connected = test_device();
        connected.total_records = Some(100_000);
        connected.received(RangeSetBlaze::from_iter([0..=1000]));
        connected.received(RangeSetBlaze::from_iter([1010..=1020]));
        connected.received(RangeSetBlaze::from_iter([1080..=1099]));
        connected.received(RangeSetBlaze::from_iter([1180..=2000]));
        assert_eq!(connected.requires(), Some(RecordRange(1001..=1179)));
    }

    #[test]
    pub fn test_requires_with_gap_wider_than_batch_size() {
        let mut connected = test_device();
        connected.total_records = Some(100_000);
        connected.received(RangeSetBlaze::from_iter([0..=1000]));
        connected.received(RangeSetBlaze::from_iter([30_000..=40_000]));
        assert_eq!(connected.requires(), Some(RecordRange(1001..=11_000)));
    }

    #[test]
    pub fn test_requires_when_have_everything() {
        let mut connected = test_device();
        connected.total_records = Some(100_000);
        connected.received(RangeSetBlaze::from_iter([0..=100_000]));
        assert_eq!(connected.requires(), None);
    }

    #[test]
    pub fn test_backoff_is_sensibly_tuned() {
        let mut backoff = ConnectedDevice::stall_backoff();
        assert_eq!(backoff.next_backoff(), Some(Duration::from_millis(5000)));
        assert_eq!(backoff.next_backoff(), Some(Duration::from_millis(9000)));
    }
}
