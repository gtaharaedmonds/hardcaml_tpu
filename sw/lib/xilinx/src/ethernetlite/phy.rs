use bilge::prelude::*;
use neorv32::clint::delay_ms;

use super::EthernetLite;
use super::regs::*;

#[bitsize(1)]
#[derive(FromBits, Debug, Clone, Copy)]
pub enum PhyDuplex {
    Half = 0,
    Full = 1,
}

#[bitsize(1)]
#[derive(FromBits, Debug, Clone, Copy)]
pub enum PhySpeed {
    Speed10M = 0,
    Speed100M = 1,
}

#[bitsize(16)]
#[derive(DebugBits, Clone, Copy, FromBits)]
pub struct PhyControlReg {
    reserved: u8,
    duplex: PhyDuplex,
    reserved: u4,
    speed: PhySpeed,
    loopback: bool,
    reset: bool,
}

impl PhyControlReg {
    const ADDR: u8 = 0;
}

#[bitsize(16)]
#[derive(DebugBits, Clone, Copy, FromBits)]
pub struct PhyStatusReg {
    reserved: u3,
    auto_negotation: bool,
    reserved: u7,
    half_duplex_10m: bool,
    full_duplex_10m: bool,
    reserved: u3,
}

impl PhyStatusReg {
    const ADDR: u8 = 1;
}

pub struct Phy<'a> {
    ethernet: &'a mut EthernetLite,
    addr: u8,
}

impl<'a> Phy<'a> {
    pub fn new(ethernet: &'a mut EthernetLite, addr: u8) -> Self {
        Self { ethernet, addr }
    }

    fn busy(&self) -> bool {
        self.ethernet.regs.mdio.control.read().busy()
    }

    fn write(&mut self, reg_addr: u8, data: u16) {
        while self.busy() {}

        // Write MDIO address register.
        unsafe {
            self.ethernet.regs.mdio.addr.write(MdioAddrReg::new(
                u5::new(reg_addr),
                u5::new(self.addr),
                false,
            ))
        }

        // Write to data register.
        unsafe {
            self.ethernet
                .regs
                .mdio
                .write_data
                .write(MdioDataReg::new(data))
        }

        // Set MDIO enable and status bits.
        unsafe {
            self.ethernet.regs.mdio.control.modify(|mut control| {
                control.set_busy(true);
                control.set_enable(true);
                control
            })
        };

        // Block until transaction complete.
        while self.busy() {}

        // Disable MDIO.
        unsafe {
            self.ethernet.regs.mdio.control.modify(|mut control| {
                control.set_enable(false);
                control
            })
        }
    }

    pub fn read(&mut self, reg_addr: u8) -> u16 {
        while self.busy() {}

        // Write MDIO address register.
        unsafe {
            self.ethernet.regs.mdio.addr.write(MdioAddrReg::new(
                u5::new(reg_addr),
                u5::new(self.addr),
                true,
            ))
        }

        // Set MDIO enable and status bits.
        unsafe {
            self.ethernet.regs.mdio.control.modify(|mut control| {
                control.set_busy(true);
                control.set_enable(true);
                control
            })
        };

        // Block until transaction complete.
        while self.busy() {}

        // Data is now available on the read register.
        let data = self.ethernet.regs.mdio.read_data.read().data();

        // Disable MDIO.
        unsafe {
            self.ethernet.regs.mdio.control.modify(|mut control| {
                control.set_enable(false);
                control
            })
        }

        data
    }

    pub fn write_control(&mut self, value: PhyControlReg) {
        self.write(PhyControlReg::ADDR, value.value);
    }

    pub fn write_status(&mut self, value: PhyStatusReg) {
        self.write(PhyStatusReg::ADDR, value.value);
    }

    pub fn read_control(&mut self) -> PhyControlReg {
        PhyControlReg::from(self.read(PhyControlReg::ADDR))
    }

    pub fn read_status(&mut self) -> PhyStatusReg {
        PhyStatusReg::from(self.read(PhyStatusReg::ADDR))
    }

    pub fn configure(&mut self, speed: PhySpeed, duplex: PhyDuplex) {
        // Set speed and put phy in reset.
        self.write_control(PhyControlReg::new(duplex, speed, false, true));

        // Delay for phy to reset.
        delay_ms(4000);
    }

    pub fn configure_loopback(&mut self, speed: PhySpeed, duplex: PhyDuplex) {
        // Set speed and put phy in reset.
        self.write_control(PhyControlReg::new(duplex, speed, false, true));

        // Delay for phy to reset.
        delay_ms(4000);

        // Enable loopback.
        self.write_control(PhyControlReg::new(duplex, speed, true, false));

        // Delay for loopback to enable.
        delay_ms(1000);
    }
}
