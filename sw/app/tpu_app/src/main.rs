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

// const N: usize = 8;
const N: usize = 16;

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

    // let weight_mat = Matrix::new({
    //     let mut data = [[0; N]; N];
    //     for row in 0..N {
    //         for col in 0..N {
    //             data[row][col] = (row * N + col) as u8;
    //         }
    //     }
    //     data
    // });
    // let data_mat = Matrix::new({
    //     let mut data = [[0; N]; N];
    //     for row in 0..N {
    //         for col in 0..N {
    //             data[row][col] = (64 + row * N + col) as u8;
    //         }
    //     }
    //     data
    // });
    // let expected_mat = Matrix::new([
    //     [2912, 2940, 2968, 2996, 3024, 3052, 3080, 3108],
    //     [8800, 8892, 8984, 9076, 9168, 9260, 9352, 9444],
    //     [14688, 14844, 15000, 15156, 15312, 15468, 15624, 15780],
    //     [20576, 20796, 21016, 21236, 21456, 21676, 21896, 22116],
    //     [26464, 26748, 27032, 27316, 27600, 27884, 28168, 28452],
    //     [32352, 32700, 33048, 33396, 33744, 34092, 34440, 34788],
    //     [38240, 38652, 39064, 39476, 39888, 40300, 40712, 41124],
    //     [44128, 44604, 45080, 45556, 46032, 46508, 46984, 47460],
    // ]);

    let weight_mat = Matrix::new({
        let mut data = [[0; N]; N];
        for row in 0..N {
            for col in 0..N {
                data[row][col] = ((row + col) * 4) as u8;
            }
        }
        data
    });
    let data_mat = Matrix::new({
        let mut data = [[0; N]; N];
        for row in 0..N {
            for col in 0..N {
                data[row][col] = ((row + col) * 8) as u8;
            }
        }
        data
    });
    #[rustfmt::skip]
    let expected_mat = Matrix::new([
        [39680, 43520, 47360, 51200, 55040, 58880, 62720, 66560, 70400, 74240, 78080, 81920, 85760, 89600, 93440, 97280],
        [43520, 47872, 52224, 56576, 60928, 65280, 69632, 73984, 78336, 82688, 87040, 91392, 95744, 100096, 104448, 108800],
        [47360, 52224, 57088, 61952, 66816, 71680, 76544, 81408, 86272, 91136, 96000, 100864, 105728, 110592, 115456, 120320],
        [51200, 56576, 61952, 67328, 72704, 78080, 83456, 88832, 94208, 99584, 104960, 110336, 115712, 121088, 126464, 131840],
        [55040, 60928, 66816, 72704, 78592, 84480, 90368, 96256, 102144, 108032, 113920, 119808, 125696, 131584, 137472, 143360],
        [58880, 65280, 71680, 78080, 84480, 90880, 97280, 103680, 110080, 116480, 122880, 129280, 135680, 142080, 148480, 154880],
        [62720, 69632, 76544, 83456, 90368, 97280, 104192, 111104, 118016, 124928, 131840, 138752, 145664, 152576, 159488, 166400],
        [66560, 73984, 81408, 88832, 96256, 103680, 111104, 118528, 125952, 133376, 140800, 148224, 155648, 163072, 170496, 177920],
        [70400, 78336, 86272, 94208, 102144, 110080, 118016, 125952, 133888, 141824, 149760, 157696, 165632, 173568, 181504, 189440],
        [74240, 82688, 91136, 99584, 108032, 116480, 124928, 133376, 141824, 150272, 158720, 167168, 175616, 184064, 192512, 200960],
        [78080, 87040, 96000, 104960, 113920, 122880, 131840, 140800, 149760, 158720, 167680, 176640, 185600, 194560, 203520, 212480],
        [81920, 91392, 100864, 110336, 119808, 129280, 138752, 148224, 157696, 167168, 176640, 186112, 195584, 205056, 214528, 224000],
        [85760, 95744, 105728, 115712, 125696, 135680, 145664, 155648, 165632, 175616, 185600, 195584, 205568, 215552, 225536, 235520],
        [89600, 100096, 110592, 121088, 131584, 142080, 152576, 163072, 173568, 184064, 194560, 205056, 215552, 226048, 236544, 247040],
        [93440, 104448, 115456, 126464, 137472, 148480, 159488, 170496, 181504, 192512, 203520, 214528, 225536, 236544, 247552, 258560],
        [97280, 108800, 120320, 131840, 143360, 154880, 166400, 177920, 189440, 200960, 212480, 224000, 235520, 247040, 258560, 270080],
    ]);

    let weight = unsafe { &*(BRAM_ADDR as *mut RW<Matrix<u8, N>>) };
    let data = unsafe { &*((BRAM_ADDR + size_of::<Matrix<u8, N>>()) as *mut RW<Matrix<u8, N>>) };
    let acc_out =
        unsafe { &mut *((BRAM_ADDR + 2 * size_of::<Matrix<u8, N>>()) as *mut RW<Matrix<u32, N>>) };

    unsafe {
        weight.write(weight_mat);
        data.write(data_mat);
    }
    println!("Wrote weight and data matrices: {:?}", tpu.status());

    tpu.multiply(weight, data, acc_out);
    println!("TPU multiplied: {:?}", tpu.status());

    let acc_out = acc_out.read();
    println!("{}", acc_out);

    for row in 0..N {
        for col in 0..N {
            if acc_out.0[row][col] != expected_mat.0[row][col] {
                panic!("mismatch at ({}, {})!", row, col);
            }
        }
    }

    println!("Matched expected!");

    loop {
        delay_ms(0xFFFFFFFF);
    }
}
