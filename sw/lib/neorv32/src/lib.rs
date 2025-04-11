#![no_std]
#![allow(static_mut_refs)]

use core::panic::PanicInfo;

pub mod clint;
pub mod gpio;
pub mod uart;

pub const CLK_HZ: usize = 100_000_000; // 100MHz

pub const CLINT_BASE: *mut clint::ClintRegs = 0xFFF40000 as *mut clint::ClintRegs;
pub const UART0_BASE: *mut uart::UartRegs = 0xFFF50000 as *mut uart::UartRegs;
pub const UART1_BASE: *mut uart::UartRegs = 0xFFF60000 as *mut uart::UartRegs;
pub const GPIO_BASE: *mut gpio::GpioRegs = 0xFFFC0000 as *mut gpio::GpioRegs;

#[inline(never)]
#[panic_handler]
fn panic(info: &PanicInfo) -> ! {
    println!("Panic! {:?}", info);
    loop {}
}
