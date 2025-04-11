use bilge::prelude::*;
use volatile_register::{RO, RW};

use super::packet_buffer::PacketBuffer;

#[bitsize(32)]
#[derive(DebugBits, Clone, Copy)]
pub struct TxPacketLengthReg {
    pub packet_length: u16,
    reserved: u16,
}

#[bitsize(32)]
#[derive(DebugBits, Clone, Copy)]
pub struct TxGlobalInterruptEnableReg {
    pub reserved: u31,
    enable: bool,
}

#[bitsize(32)]
#[derive(DebugBits, Clone, Copy)]
pub struct TxControlReg {
    pub busy: bool,
    pub program_mac: bool,
    reserved: bool,
    pub interrupt_enable: bool,
    pub loopback: bool,
    reserved: u27,
}

#[repr(C)]
pub struct TxControlRegs {
    pub packet_length: RW<TxPacketLengthReg>,
    pub global_interrupt_enable: RW<TxGlobalInterruptEnableReg>,
    pub control: RW<TxControlReg>,
}

#[bitsize(32)]
#[derive(DebugBits, Clone, Copy)]
pub struct RxControlReg {
    pub done: bool,
    reserved: u2,
    pub interrupt_enable: bool,
    reserved: u28,
}

#[repr(C)]
pub struct RxControlRegs {
    pub control: RW<RxControlReg>,
}

#[bitsize(32)]
#[derive(DebugBits, Clone, Copy)]
pub struct MdioAddrReg {
    pub reg_addr: u5,
    pub phy_addr: u5,
    pub operation_rw: bool,
    reserved: u21,
}

#[bitsize(32)]
#[derive(DebugBits, Clone, Copy)]
pub struct MdioDataReg {
    pub data: u16,
    reserved: u16,
}

#[bitsize(32)]
#[derive(DebugBits, Clone, Copy)]
pub struct MdioControlReg {
    pub busy: bool,
    pub reserved: u2,
    pub enable: bool,
    reserved: u28,
}

#[repr(C)]
pub struct MdioRegs {
    pub addr: RW<MdioAddrReg>,
    pub write_data: RW<MdioDataReg>,
    pub read_data: RO<MdioDataReg>,
    pub control: RW<MdioControlReg>,
}

pub struct EthernetLiteRegs {
    pub tx_buffer: &'static mut PacketBuffer,
    pub mdio: &'static mut MdioRegs,
    pub tx_control: &'static mut TxControlRegs,
    pub rx_buffer: &'static mut PacketBuffer,
    pub rx_control: &'static mut RxControlRegs,
}

impl EthernetLiteRegs {
    const TX_BUF_REGS_OFFSET: usize = 0x000;
    const MDIO_REGS_OFFSET: usize = 0x7E4;
    const TX_CONTROL_REGS_OFFSET: usize = 0x7F4;
    const RX_BUF_REGS_OFFSET: usize = 0x1000;
    const RX_CONTROL_REG_OFFSET: usize = 0x17FC;

    pub fn new(base: usize) -> Self {
        unsafe {
            Self {
                tx_buffer: &mut *((base + Self::TX_BUF_REGS_OFFSET) as *mut PacketBuffer),
                mdio: &mut *((base + Self::MDIO_REGS_OFFSET) as *mut MdioRegs),
                tx_control: &mut *((base + Self::TX_CONTROL_REGS_OFFSET) as *mut TxControlRegs),
                rx_buffer: &mut *((base + Self::RX_BUF_REGS_OFFSET) as *mut PacketBuffer),
                rx_control: &mut *((base + Self::RX_CONTROL_REG_OFFSET) as *mut RxControlRegs),
            }
        }
    }
}
