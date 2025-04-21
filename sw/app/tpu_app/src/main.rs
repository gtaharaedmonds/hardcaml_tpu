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
use xilinx::dma::{DmaRxChannel, DmaTxChannel};

const WEIGHT_DMA_ADDR: usize = 0xF001_0000;
const ACC_DMA_ADDR: usize = 0xF001_0000;
const DATA_DMA_ADDR: usize = 0xF001_8000;

#[entry]
fn main() -> ! {
    let mut gpio = Gpio::new(neorv32::GPIO_BASE);
    let mut uart = Uart::new(neorv32::UART0_BASE);
    let mut clint = Clint::new(neorv32::CLINT_BASE);
    let mut weight_tx = DmaTxChannel::new(WEIGHT_DMA_ADDR);
    let mut data_tx = DmaTxChannel::new(DATA_DMA_ADDR);
    let mut acc_rx = DmaRxChannel::new(ACC_DMA_ADDR);

    uart.init(19200);
    init_uart_print(uart);
    println!("Initialized UART printing");

    clint.init();
    println!("Initialized CLINT timer");

    weight_tx.init();
    data_tx.init();
    acc_rx.init();
    println!("Initialized DMA channels");

    let weight_reg = unsafe { &*(0xF002_0000 as *mut RW<u32>) };
    let data_reg = unsafe { &*(0xF002_0004 as *mut RW<u32>) };
    let acc_reg = unsafe { &*(0xF002_0010 as *mut RW<u32>) };

    unsafe { weight_reg.write(0x01020304) };
    unsafe { data_reg.write(0x05060708) };
    unsafe { acc_reg.write(0xffffffff) };

    let ready = gpio.read_input(0);
    let finished = gpio.read_input(1);
    println!("Status 1: {ready} {finished} {}", acc_reg.read());

    weight_tx.transmit_blocking(core::ptr::addr_of!(weight_reg) as usize, 4);
    data_tx.transmit_blocking(core::ptr::addr_of!(data_reg) as usize, 4);

    let ready = gpio.read_input(0);
    let finished = gpio.read_input(1);
    println!("Status 2: {ready} {finished} {}", acc_reg.read());

    acc_rx.receive(core::ptr::addr_of!(acc_reg) as usize, 16);
    gpio.write_output(1, true);
    println!("Started");
    gpio.write_output(1, false);
    println!("Undo started");

    println!("Trying to receive...");

    loop {
        let ready = gpio.read_input(0);
        let finished = gpio.read_input(1);
        println!("Status loop: {ready} {finished} {}", acc_reg.read());
        delay_ms(1000);
    }
}
