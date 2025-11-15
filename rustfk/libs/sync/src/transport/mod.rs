use anyhow::{Context, Result};
use async_trait::async_trait;
use std::{
    net::{SocketAddr, SocketAddrV4},
    sync::Arc,
    time::Duration,
};
use tokio::{net::UdpSocket, sync::Mutex};
use tracing::*;

use crate::proto::{Message, MessageCodec};

const DEFAULT_PORT: u16 = 22144;
const IP_ALL: [u8; 4] = [0, 0, 0, 0];

#[derive(Debug)]
pub struct TransportMessage(pub (SocketAddr, Message));

#[async_trait]
pub trait SendTransport: Send + Sync + 'static {
    async fn send(&self, message: TransportMessage) -> Result<()>;
}

#[async_trait]
pub trait ReceiveTransport: Send + Sync + 'static {
    async fn recv(&self) -> Result<Option<Vec<TransportMessage>>>;
}

#[async_trait]
pub trait Transport {
    type Send: SendTransport;
    type Receive: ReceiveTransport;

    async fn open(&self) -> Result<(Self::Send, Self::Receive)>;
}

#[derive(Clone)]
pub struct OpenUdp {
    port: u16,
    socket: Arc<Mutex<Option<UdpSocket>>>,
}

impl OpenUdp {
    async fn release(&self) {
        let mut socket = self.socket.lock().await;
        let _dropping = socket.take();
    }

    async fn readable(&self) -> Result<bool> {
        let mut socket = self.socket.lock().await;

        if socket.is_none() {
            let listening_addr = SocketAddrV4::new(IP_ALL.into(), self.port);
            info!("listening on {}", listening_addr);
            *socket = Some(bind(&listening_addr).context("binding")?);
        }

        match tokio::time::timeout(
            Duration::from_millis(100),
            socket.as_ref().unwrap().readable(),
        )
        .await
        {
            Ok(_) => Ok(true),
            Err(_) => Ok(false),
        }
    }

    async fn send_to(&self, buf: &[u8], target: SocketAddr) -> Result<()> {
        let socket = self.socket.lock().await;

        if let Some(socket) = socket.as_ref() {
            socket.send_to(buf, target).await?;
        }

        Ok(())
    }

    async fn try_recv_from(
        &self,
        buffer: &mut [u8],
    ) -> std::io::Result<Option<(usize, SocketAddr)>> {
        let socket = self.socket.lock().await;

        if let Some(socket) = socket.as_ref() {
            socket.try_recv_from(buffer).map(Some)
        } else {
            Ok(None)
        }
    }
}

#[async_trait]
impl SendTransport for OpenUdp {
    async fn send(&self, message: TransportMessage) -> Result<()> {
        let TransportMessage((addr, message)) = message;
        let mut buffer = Vec::new();
        message.write(&mut buffer)?;

        debug!("{:?} Sending {:?}", addr, buffer.len());
        self.send_to(&buffer, addr).await.context("send")?;

        Ok(())
    }
}

#[async_trait]
impl ReceiveTransport for OpenUdp {
    async fn recv(&self) -> Result<Option<Vec<TransportMessage>>> {
        let mut codec = MessageCodec::default();
        let mut batch: Vec<TransportMessage> = Vec::new();

        if !self.readable().await.context("readable")? {
            return Ok(Some(batch));
        }

        loop {
            let mut buffer = vec![0u8; 4096];

            match self.try_recv_from(&mut buffer[..]).await {
                Ok(Some((len, addr))) => {
                    trace!("{:?} Received {:?}", addr, len);

                    match codec.try_read(&buffer[..len]).context("try read")? {
                        Some(message) => {
                            if let Message::Batch {
                                flags: _flags,
                                errors,
                            } = message
                            {
                                if errors > 0 {
                                    warn!("{:?} Batch ({:?} Errors)", addr, errors)
                                } else {
                                    info!("{:?} Batch", addr)
                                }
                            }

                            batch.push(TransportMessage((addr, message)));
                        }
                        None => {}
                    }
                }
                Ok(None) => {
                    warn!("Disconnected");
                    return Ok(Some(batch));
                }
                Err(ref e) if e.kind() == std::io::ErrorKind::WouldBlock => {
                    return Ok(Some(batch));
                }
                Err(e) => {
                    // Is this ok? It's not clear to me if on a UDP socket an
                    // error indicates we should close/re-open the socket.
                    warn!("Error: {:?}", e);
                    self.release().await;
                    return Ok(Some(batch));
                }
            }
        }
    }
}

pub struct UdpTransport {
    port: u16,
}

impl UdpTransport {
    pub fn new() -> Self {
        Self { port: DEFAULT_PORT }
    }
}

#[async_trait]
impl Transport for UdpTransport {
    type Send = OpenUdp;
    type Receive = OpenUdp;

    async fn open(&self) -> Result<(OpenUdp, OpenUdp)> {
        let socket = Arc::new(Mutex::new(None));

        let sender = OpenUdp {
            port: self.port,
            socket,
        };

        let receiver = sender.clone();

        Ok((sender, receiver))
    }
}

fn bind(addr: &SocketAddrV4) -> Result<UdpSocket> {
    use socket2::{Domain, Protocol, Socket, Type};

    let socket = Socket::new(Domain::IPV4, Type::DGRAM, Some(Protocol::UDP))?;

    socket.set_reuse_address(true)?;
    socket.set_nonblocking(true)?;
    socket.bind(&socket2::SockAddr::from(*addr))?;

    Ok(UdpSocket::from_std(socket.into())?)
}
