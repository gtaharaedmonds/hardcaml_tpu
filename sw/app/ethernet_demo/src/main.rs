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
use xilinx::ethernetlite::phy::PhyDuplex;
use xilinx::ethernetlite::{EthernetLite, MacAddr, phy::PhySpeed};

const PHY_ADDR: u8 = 1;

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

    let server_addr = MacAddr::new([0x00, 0x0A, 0x35, 0x01, 0x02, 0x03]);
    let mut ethernet = EthernetLite::new(0xF000_0000, server_addr);

    ethernet.init();
    println!("Done initializing ethernet");

    let mut phy = ethernet.phy(PHY_ADDR);
    phy.configure(PhySpeed::Speed100M, PhyDuplex::Full);
    println!("Done configuring PHY");

    loop {
        gpio.write_output(7, true);
        delay_ms(500);
        gpio.write_output(7, false);
        delay_ms(500);

        let frame = ethernet.receive_frame();
        let mut data = frame.data();
        data.extend_from_slice(" (echo echo echo)".as_bytes())
            .unwrap();
        ethernet.transmit_frame(frame.src_addr, data);
        println!("Echoed frame: {:?}", frame);
    }
}
