pub mod packet_buffer;
pub mod phy;
pub mod regs;

use heapless::Vec;
use packet_buffer::{MAX_DATA_SIZE, PacketBuffer};
use phy::Phy;
use regs::*;

#[repr(transparent)]
#[derive(Clone, Copy)]
pub struct MacAddr([u8; 6]);

impl MacAddr {
    pub fn new(address_raw: [u8; 6]) -> Self {
        Self(address_raw)
    }
}

impl core::fmt::Debug for MacAddr {
    fn fmt(&self, f: &mut core::fmt::Formatter<'_>) -> core::fmt::Result {
        write!(
            f,
            "{:02X}:{:02x}:{:02X}:{:02X}:{:02X}:{:02X}",
            self.0[0], self.0[1], self.0[2], self.0[3], self.0[4], self.0[5]
        )
    }
}

impl From<MacAddr> for u64 {
    fn from(mac: MacAddr) -> Self {
        let mut bytes = [0; 8];
        bytes[..6].copy_from_slice(&mac.0);
        u64::from_le_bytes(bytes)
    }
}

pub struct EthernetLite {
    regs: EthernetLiteRegs,
    mac: MacAddr,
}

impl EthernetLite {
    pub fn new(base: usize, mac: MacAddr) -> Self {
        Self {
            regs: EthernetLiteRegs::new(base),
            mac,
        }
    }

    pub fn init(&mut self) {
        unsafe {
            self.regs
                .tx_control
                .control
                .write(TxControlReg::new(false, false, false, false));
        };

        // Set MAC address.
        self.set_mac_address();

        // Flush RX to start receiving packets.
        self.flush_receive();
    }

    fn set_mac_address(&mut self) {
        // Write MAC address to TX ping buffer.
        self.regs.tx_buffer.write_aligned(&PacketBuffer::new(
            self.mac,
            MacAddr::new([0; 6]),
            Vec::new(),
        ));

        // Set packet length register.
        unsafe {
            self.regs
                .tx_control
                .packet_length
                .write(TxPacketLengthReg::new(self.mac.0.len() as u16));
        };

        // Set program and status bit.
        unsafe {
            self.regs.tx_control.control.modify(|mut control| {
                control.set_program_mac(true);
                control.set_busy(true);
                control
            })
        };

        // Wait until program and status bit cleared.
        while {
            let control = self.regs.tx_control.control.read();
            control.program_mac() || control.busy()
        } {}
    }

    pub fn mac_address(&self) -> &MacAddr {
        &self.mac
    }

    pub fn phy(&mut self, addr: u8) -> Phy {
        Phy::new(self, addr)
    }

    fn tx_busy(&mut self) -> bool {
        self.regs.tx_control.control.read().busy()
    }

    pub fn transmit_frame(&mut self, dest: MacAddr, data: Vec<u8, MAX_DATA_SIZE>) {
        while self.tx_busy() {}

        // Write TX buffer.
        let packet_buffer = PacketBuffer::new(dest, self.mac, data);
        self.regs.tx_buffer.write_aligned(&packet_buffer);

        // Write length of payload and header to TX control register bank.
        unsafe {
            self.regs
                .tx_control
                .packet_length
                .write(TxPacketLengthReg::new(packet_buffer.packet_len() as u16));
        }

        // Dispatch the transaction.
        unsafe {
            self.regs.tx_control.control.modify(|mut control| {
                control.set_busy(true);
                control
            });
        }

        // Spin until complete.
        while self.tx_busy() {}
    }

    fn rx_done(&mut self) -> bool {
        self.regs.rx_control.control.read().done()
    }

    pub fn try_receive_frame(&mut self) -> Result<PacketBuffer, ()> {
        if self.rx_done() {
            let frame = self.regs.rx_buffer.read_aligned();
            self.flush_receive();
            Ok(frame)
        } else {
            Err(())
        }
    }

    pub fn receive_frame(&mut self) -> PacketBuffer {
        loop {
            if let Ok(frame) = self.try_receive_frame() {
                return frame;
            }
        }
    }

    pub fn flush_receive(&mut self) {
        unsafe {
            self.regs.rx_control.control.modify(|mut control| {
                control.set_done(false);
                control
            });
        }
    }
}
