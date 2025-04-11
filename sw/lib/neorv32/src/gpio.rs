#[repr(C)]
pub struct GpioRegs {
    port_in: u32,
    port_out: u32,
    reserved: [u32; 2],
    irq_type: u32,
    irq_polarity: u32,
    irq_enable: u32,
    irq_pending: u32,
}

pub struct Gpio {
    regs: &'static mut GpioRegs,
}

impl Gpio {
    pub fn new(regs: *mut GpioRegs) -> Self {
        Self {
            regs: unsafe { &mut *regs },
        }
    }

    pub fn read_input(&self, pin: usize) -> bool {
        let port_in = unsafe { core::ptr::read_volatile(core::ptr::addr_of!(self.regs.port_in)) };
        (port_in & (1 << pin)) != 0
    }

    pub fn write_output(&mut self, pin: usize, value: bool) {
        let mut port_out =
            unsafe { core::ptr::read_volatile(core::ptr::addr_of!(self.regs.port_out)) };

        if value {
            port_out |= 1 << pin;
        } else {
            port_out &= !(1 << pin);
        }

        unsafe { core::ptr::write_volatile(core::ptr::addr_of_mut!(self.regs.port_out), port_out) }
    }
}
