use volatile_register::{RO, RW};

#[repr(C)]
pub struct GpioRegs {
    port_in: RO<u32>,
    port_out: RW<u32>,
    reserved: [u32; 2],
    irq_type: RW<u32>,
    irq_polarity: RW<u32>,
    irq_enable: RW<u32>,
    irq_pending: RW<u32>,
}

pub struct InputPin {
    pin: usize,
    regs: &'static GpioRegs,
}

impl InputPin {
    pub fn read(&self) -> bool {
        (self.regs.port_in.read() & (1 << self.pin)) != 0
    }
}

pub struct OutputPin {
    pin: usize,
    regs: &'static GpioRegs,
}

impl OutputPin {
    pub fn write(&self, value: bool) {
        unsafe {
            self.regs.port_out.modify(|mut port_out| {
                if value {
                    port_out |= 1 << self.pin;
                } else {
                    port_out &= !(1 << self.pin);
                }

                port_out
            })
        };
    }
}

pub struct Gpio {
    regs: &'static GpioRegs,
}

impl Gpio {
    pub fn new(regs: *mut GpioRegs) -> Self {
        Self {
            regs: unsafe { &mut *regs },
        }
    }

    pub fn input_pin(&self, pin: usize) -> InputPin {
        InputPin {
            pin: pin,
            regs: self.regs,
        }
    }
    pub fn output_pin(&self, pin: usize) -> OutputPin {
        OutputPin {
            pin: pin,
            regs: self.regs,
        }
    }
}
