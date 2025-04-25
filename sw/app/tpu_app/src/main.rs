#![no_std]
#![no_main]

mod tpu;
use core::panic;

use tpu::*;

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
const BRAM_ADDR: usize = 0xF002_0000;

#[entry]
fn main() -> ! {
    let gpio = Gpio::new(neorv32::GPIO_BASE);
    let mut uart = Uart::new(neorv32::UART0_BASE);
    let mut clint = Clint::new(neorv32::CLINT_BASE);
    let mut weight_dma = DmaTxChannel::new(WEIGHT_DMA_ADDR);
    let mut data_dma = DmaTxChannel::new(DATA_DMA_ADDR);
    let mut acc_dma = DmaRxChannel::new(ACC_DMA_ADDR);

    uart.init(19200);
    init_uart_print(uart);
    println!("Initialized UART printing");

    clint.init();
    println!("Initialized CLINT timer");

    weight_dma.init();
    data_dma.init();
    acc_dma.init();
    println!("Initialized DMA channels");

    let mut tpu = Tpu::new(gpio, weight_dma, data_dma, acc_dma);
    println!("Initial status: {:?}", tpu.status());

    let weight = unsafe { &*(BRAM_ADDR as *mut RW<Matrix<u8, 8>>) };
    let data = unsafe { &*((BRAM_ADDR + size_of::<Matrix<u8, 8>>()) as *mut RW<Matrix<u8, 8>>) };
    unsafe {
        weight.write(Matrix::new({
            let mut data = [[0; 8]; 8];
            for row in 0..8 {
                for col in 0..8 {
                    data[row][col] = (row * 8 + col) as u8;
                }
            }
            data
        }));
        data.write(Matrix::new({
            let mut data = [[0; 8]; 8];
            for row in 0..8 {
                for col in 0..8 {
                    data[row][col] = (64 + row * 8 + col) as u8;
                }
            }
            data
        }));
    }
    println!("Wrote weight and data matrices: {:?}", tpu.status());

    let acc_out =
        unsafe { &mut *((BRAM_ADDR + 2 * size_of::<Matrix<u8, 8>>()) as *mut RW<Matrix<u32, 8>>) };
    tpu.multiply(weight, data, acc_out);
    println!("TPU multiplied: {:?}", tpu.status());

    let acc_out = acc_out.read();
    println!("{}", acc_out);

    let expected = [
        [2912, 2940, 2968, 2996, 3024, 3052, 3080, 3108],
        [8800, 8892, 8984, 9076, 9168, 9260, 9352, 9444],
        [14688, 14844, 15000, 15156, 15312, 15468, 15624, 15780],
        [20576, 20796, 21016, 21236, 21456, 21676, 21896, 22116],
        [26464, 26748, 27032, 27316, 27600, 27884, 28168, 28452],
        [32352, 32700, 33048, 33396, 33744, 34092, 34440, 34788],
        [38240, 38652, 39064, 39476, 39888, 40300, 40712, 41124],
        [44128, 44604, 45080, 45556, 46032, 46508, 46984, 47460],
    ];

    for row in 0..8 {
        for col in 0..8 {
            if acc_out.0[row][col] != expected[row][col] {
                panic!("mismatch at ({}, {})!", row, col);
            }
        }
    }

    println!("Matched expected!");

    loop {
        delay_ms(0xFFFFFFFF);
    }
}
