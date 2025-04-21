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
use xilinx::dma::Dma;

const DMA_ADDR: usize = 0xF001_0000;
const REG_ADDR: *mut RW<u32> = 0xF002_0000 as *mut RW<u32>;

#[entry]
fn main() -> ! {
    let mut gpio = Gpio::new(neorv32::GPIO_BASE);
    let mut uart = Uart::new(neorv32::UART0_BASE);
    let mut clint = Clint::new(neorv32::CLINT_BASE);
    let mut dma = Dma::new(DMA_ADDR);
    let mut dma2 = Dma::new(DMA_ADDR + 0x8000);

    uart.init(19200);
    init_uart_print(uart);
    println!("Initialized UART printing");

    clint.init();
    println!("Initialized CLINT timer");

    dma.init();
    dma2.init();
    println!("Initialized DMA");

    let reg = unsafe { &*REG_ADDR };
    let dma_source = unsafe { &*(0xF002_0010 as *mut RW<u32>) };
    let dma_dest = unsafe { &*(0xF002_0020 as *mut RW<u32>) };

    unsafe { dma_source.write(17) };

    let dma2_source = unsafe { &*(0xF002_1010 as *mut RW<u32>) };
    let dma2_dest = unsafe { &*(0xF002_1020 as *mut RW<u32>) };

    unsafe { dma2_source.write(27) };

    dma.send(0xF002_0010, 4);
    dma.receive(0xF002_0020, 4);

    dma2.send(0xF002_1010, 4);
    dma2.receive(0xF002_1020, 4);

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

        println!(
            "DMA source: {}, dest: {}",
            dma_source.read(),
            dma_dest.read()
        );

        println!(
            "DMA2 source: {}, dest: {}",
            dma2_source.read(),
            dma2_dest.read()
        );
    }
}
