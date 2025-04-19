#![no_std]
#![no_main]

use riscv_rt::entry;

use neorv32 as _;
use neorv32::{
    clint::{Clint, delay_ms},
    gpio::*,
    println,
    uart::{Uart, init_uart_print},
};
use volatile_register::RW;

const REG_ADDR: *mut RW<u32> = 0xF001_0000 as *mut RW<u32>;

#[entry]
fn main() -> ! {
    let mut gpio = Gpio::new(neorv32::GPIO_BASE);
    let mut uart = Uart::new(neorv32::UART0_BASE);
    let mut clint = Clint::new(neorv32::CLINT_BASE);

    uart.init(19200);
    init_uart_print(uart);
    println!("Initialized UART printing");

    clint.init();
    println!("Initialized CLINT timer");

    let reg = unsafe { &*REG_ADDR };

    let mut count = 0;
    loop {
        gpio.write_output(7, true);
        delay_ms(500);
        gpio.write_output(7, false);
        delay_ms(500);
        println!("Hello, axi! {count}");
        count += 1;

        println!("Read over axi: {}", reg.read());
        unsafe {
            reg.write(count);
        }
    }
}
