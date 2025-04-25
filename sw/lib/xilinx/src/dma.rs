use bilge::prelude::*;
use neorv32::println;
use volatile_register::{RO, RW};

#[bitsize(32)]
#[derive(DebugBits, Clone, Copy)]
struct Control {
    run: bool,
    reserved: u1,
    reset: bool,
    reserved: u9,
    completed_irq_en: bool,
    reserved: u1,
    error_irq_en: bool,
    reserved: u17,
}

#[bitsize(32)]
#[derive(DebugBits, Clone, Copy)]
struct Status {
    halted: bool,
    idle: bool,
    reserved: u2,
    internal_error: bool,
    slave_error: bool,
    decode_error: bool,
    reserved: u1,
    reserved: u4,
    completed_irq: bool,
    reserved: u1,
    error_irq: bool,
    reserved: u17,
}

struct DmaChannelRegs {
    control: &'static mut RW<Control>,
    status: &'static mut RO<Status>,
    addr: &'static mut RW<u32>,
    len: &'static mut RW<u32>,
}

impl DmaChannelRegs {
    const CONTROL_OFFSET: usize = 0x00;
    const STATUS_OFFSET: usize = 0x04;
    const ADDR_OFFSET: usize = 0x18;
    const LEN_OFFSET: usize = 0x28;

    fn new(base: usize) -> Self {
        unsafe {
            Self {
                control: &mut *((base + Self::CONTROL_OFFSET) as *mut RW<Control>),
                status: &mut *((base + Self::STATUS_OFFSET) as *mut RO<Status>),
                addr: &mut *((base + Self::ADDR_OFFSET) as *mut RW<u32>),
                len: &mut *((base + Self::LEN_OFFSET) as *mut RW<u32>),
            }
        }
    }
}

pub struct DmaTxChannel {
    regs: DmaChannelRegs,
}

impl DmaTxChannel {
    const MM2S_OFFSET: usize = 0x00;

    pub fn new(base: usize) -> Self {
        Self {
            regs: DmaChannelRegs::new(base + Self::MM2S_OFFSET),
        }
    }

    pub fn init(&mut self) {
        // TODO: Figure out interrupts.

        unsafe {
            self.regs.control.modify(|mut control| {
                // control.set_completed_irq_en(true);
                // control.set_error_irq_en(true);
                control.set_run(true);
                control
            });
        };

        // Halted bit should clear indicating the DMA is running.
        while self.regs.status.read().halted() {}
    }

    pub fn transmit(&mut self, addr: usize, len: usize) {
        assert!(
            addr % size_of::<u32>() == 0,
            "DMA'ed data needs to be aligned to the AXI bus width"
        );

        unsafe {
            self.regs.addr.write(addr as u32);
            self.regs.len.write(len as u32);
        }
    }

    pub fn idle(&mut self) -> bool {
        self.regs.status.read().idle()
    }
}

pub struct DmaRxChannel {
    regs: DmaChannelRegs,
}

impl DmaRxChannel {
    const S2MM_OFFSET: usize = 0x30;

    pub fn new(base: usize) -> Self {
        Self {
            regs: DmaChannelRegs::new(base + Self::S2MM_OFFSET),
        }
    }

    pub fn init(&mut self) {
        // TODO: Figure out interrupts.

        unsafe {
            self.regs.control.modify(|mut control| {
                // control.set_completed_irq_en(true);
                // control.set_error_irq_en(true);
                control.set_run(true);
                control
            });
        };

        // Halted bit should clear indicating the DMA is running.
        while self.regs.status.read().halted() {}
    }

    pub fn receive(&mut self, addr: usize, len: usize) {
        assert!(
            addr as usize % size_of::<u32>() == 0,
            "DMA'ed data needs to be aligned to the AXI bus width"
        );

        unsafe {
            self.regs.addr.write(addr as u32);
            self.regs.len.write(len as u32);
        }
    }

    pub fn idle(&mut self) -> bool {
        self.regs.status.read().idle()
    }

    pub fn print_status(&mut self) {
        println!("status = {:?}", self.regs.status.read());
    }
}
