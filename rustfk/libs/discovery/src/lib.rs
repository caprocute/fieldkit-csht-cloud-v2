use anyhow::{Context, Result};
use std::{
    net::{Ipv4Addr, SocketAddr, SocketAddrV4},
    sync::{atomic::AtomicI32, Arc},
};
use tokio::{net::UdpSocket, sync::mpsc::Sender};
use tracing::*;

const MULTICAST_IP: [u8; 4] = [224, 1, 2, 3];
const MULTICAST_PORT: u16 = 22143;
const READ_BUFFER_SIZE: usize = 4096;
const DEFAULT_UDP_SERVER_PORT: u16 = 22144;

#[derive(Clone, Debug, Eq, PartialEq, Hash)]
pub struct DeviceId(pub String);

impl Into<String> for DeviceId {
    fn into(self) -> String {
        self.0
    }
}

#[derive(Clone, Debug)]
pub struct Discovered {
    pub device_id: DeviceId,
    pub http_addr: Option<SocketAddr>,
    pub udp_addr: Option<SocketAddr>,
}

impl Discovered {
    pub fn http_url(&self) -> Option<String> {
        self.http_addr.map(|addr| format!("http://{}/fk/v1", addr))
    }
}

#[derive(Default)]
struct UdpListener {}

impl UdpListener {
    async fn run(&self, publisher: &Sender<Discovered>, discoveries: &Discoveries) -> Result<()> {
        let addr = SocketAddrV4::new(MULTICAST_IP.into(), MULTICAST_PORT);
        let receiving = Arc::new(self.bind(&addr).context("binding")?);

        let mut buffer = vec![0u8; READ_BUFFER_SIZE];

        loop {
            let (len, addr) = receiving
                .recv_from(&mut buffer[..])
                .await
                .context("receiving")?;
            debug!("{} bytes from {}", len, addr);

            let bytes = &buffer[0..len];
            let announced = Announce::parse(bytes).context("parsing announce")?;
            let discovered = Discovered {
                device_id: announced.device_id().clone(),
                http_addr: announced
                    .port()
                    .map(|port| SocketAddr::new(addr.ip(), port)),
                udp_addr: { Some(SocketAddr::new(addr.ip(), DEFAULT_UDP_SERVER_PORT)) },
            };

            trace!("discovered {:?}", discovered);

            discoveries.found_udp();

            publisher
                .send(discovered)
                .await
                .context("publishing discovery")?;
        }
    }

    fn bind(&self, addr: &SocketAddrV4) -> Result<UdpSocket> {
        use socket2::{Domain, Protocol, Socket, Type};

        assert!(addr.ip().is_multicast(), "must be multcast address");

        let socket = Socket::new(Domain::IPV4, Type::DGRAM, Some(Protocol::UDP))?;

        info!("discovering on {}", addr);

        // This don't seem to be necessary when running a rust program from the
        // command line on Linux. If you omit them, then running a flutter
        // application that uses this library will fail to bind with an error
        // about the address being in use.
        socket.set_reuse_address(true)?;

        // Saving just in case this becomes a factor later, as the above did.
        // socket.set_multicast_loop_v4(true)?;

        // This is very important when using UdpSocket::from_std, otherwise
        // you'll see weird blocking behavior.
        socket.set_nonblocking(true)?;
        socket.bind(&socket2::SockAddr::from(*addr))?;
        socket.join_multicast_v4(addr.ip(), &Ipv4Addr::new(0, 0, 0, 0))?;

        Ok(UdpSocket::from_std(socket.into())?)
    }
}

#[derive(Default)]
struct FindConnected {}

impl FindConnected {
    pub async fn run(
        &self,
        publisher: &Sender<Discovered>,
        discoveries: &Discoveries,
    ) -> Result<()> {
        let query = query::device::Client::new().context("client construction")?;

        loop {
            let delay = if discoveries.any_found_connected() || discoveries.any_found_udp() {
                tokio::time::Duration::from_secs(300)
            } else {
                tokio::time::Duration::from_secs(10)
            };

            tokio::time::sleep(delay).await;

            if discoveries.any_found_udp() {
                continue;
            }

            info!("ap-mode-ip: querying");

            match query.query_status("192.168.2.1").await {
                Ok(status) => {
                    let addr = Ipv4Addr::new(192, 168, 2, 1).into();
                    let device_id = status
                        .decoded
                        .status
                        .and_then(|m| m.identity)
                        .map(|m| DeviceId(hex::encode(m.device_id)));

                    match device_id {
                        Some(device_id) => {
                            match publisher
                                .send(Discovered {
                                    device_id,
                                    http_addr: Some(SocketAddr::new(addr, 80)),
                                    udp_addr: Some(SocketAddr::new(addr, DEFAULT_UDP_SERVER_PORT)),
                                })
                                .await
                            {
                                Ok(_) => {
                                    info!("ap-mode-ip: found");
                                    discoveries.found_connected();
                                }
                                Err(e) => error!("Send failed: {:?}", e),
                            }
                        }
                        None => error!("No device id"),
                    }
                }
                Err(_) => {
                    debug!("ap-mode-ip: none");
                }
            }
        }
    }
}

#[derive(Default)]
pub struct Discovery {}

impl Discovery {
    pub async fn run(&self, publisher: Sender<Discovered>) -> Result<()> {
        let discoveries = Discoveries::default();

        loop {
            info!("discovery:begin");

            let udp_listener = UdpListener::default();
            let find_connected = FindConnected::default();

            tokio::select! {
                r = udp_listener.run(&publisher, &discoveries) => {
                    match r {
                        Err(e) => warn!("discovery:udp: {:?}", e),
                        Ok(_) => {}
                    }
                },
                r = find_connected.run(&publisher, &discoveries) => {
                    match r {
                        Err(e) => warn!("discovery:fc: {:?}", e),
                        Ok(_) => {}
                    }
                }
            }

            info!("discovery:exited");

            tokio::time::sleep(std::time::Duration::from_secs(1)).await;
        }
    }
}

pub enum Announce {
    Hello(DeviceId, u16),
    Bye(DeviceId),
}

impl Announce {
    fn parse(bytes: &[u8]) -> Result<Self> {
        const DEVICE_ID_TAG: u32 = 1;
        const PORT_TAG: u32 = 4;
        use quick_protobuf::BytesReader;

        let mut reader = BytesReader::from_bytes(bytes);
        let _size = reader.read_varint32(bytes)?;
        let tag = reader.next_tag(bytes)?;
        assert_eq!(tag >> 3, DEVICE_ID_TAG);
        let id_bytes = reader.read_bytes(bytes)?;
        let device_id = DeviceId(hex::encode(id_bytes));
        let port = if !reader.is_eof() {
            let tag = reader.next_tag(bytes)?;
            if tag >> 3 == PORT_TAG {
                reader.read_int32(bytes)?
            } else {
                80
            }
        } else {
            80
        };

        if reader.is_eof() {
            Ok(Announce::Hello(device_id, port as u16))
        } else {
            Ok(Announce::Bye(device_id))
        }
    }

    fn device_id(&self) -> &DeviceId {
        match self {
            Announce::Hello(id, _) => id,
            Announce::Bye(id) => id,
        }
    }

    fn port(&self) -> Option<u16> {
        match self {
            Announce::Hello(_, port) => Some(*port),
            Announce::Bye(_) => None,
        }
    }
}

#[derive(Debug, Default)]
struct Discoveries {
    udp: AtomicI32,
    connected: AtomicI32,
}

use std::sync::atomic::Ordering::Relaxed;

impl Discoveries {
    fn found_udp(&self) {
        self.udp.fetch_add(1, Relaxed);
    }

    fn any_found_udp(&self) -> bool {
        self.udp.fetch_add(0, Relaxed) > 0
    }

    fn found_connected(&self) {
        self.connected.fetch_add(1, Relaxed);
    }

    fn any_found_connected(&self) -> bool {
        self.connected.fetch_add(0, Relaxed) > 0
    }
}
