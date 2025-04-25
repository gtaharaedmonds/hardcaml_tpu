use core::fmt;

use volatile_register::RW;

use neorv32::gpio::{Gpio, InputPin, OutputPin};
use xilinx::dma::{DmaRxChannel, DmaTxChannel};

#[repr(C)]
#[derive(Clone, Copy, Debug)]
pub struct Matrix<T, const N: usize>(pub [[T; N]; N]);

impl<T, const N: usize> Matrix<T, N> {
    pub const fn new(data: [[T; N]; N]) -> Self {
        Self(data)
    }
}

impl<T: fmt::Display, const N: usize> fmt::Display for Matrix<T, N> {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        // Find the maximum width needed for any element without using std
        let mut max_width = 0;
        for row in self.0.iter() {
            for value in row.iter() {
                // Use a temporary formatter to measure the length
                struct LengthCounter(usize);
                impl fmt::Write for LengthCounter {
                    fn write_str(&mut self, s: &str) -> fmt::Result {
                        self.0 += s.len();
                        Ok(())
                    }
                }

                let mut counter = LengthCounter(0);
                // Ignore the result as we only care about the length
                let _ = fmt::write(&mut counter, format_args!("{}", value));
                if counter.0 > max_width {
                    max_width = counter.0;
                }
            }
        }

        // Use ASCII characters for borders
        const TOP_LEFT: &str = "+";
        const TOP_RIGHT: &str = "+";
        const BOTTOM_LEFT: &str = "+";
        const BOTTOM_RIGHT: &str = "+";
        const HORIZONTAL: &str = "-";
        const VERTICAL: &str = "|";
        const CROSS: &str = "+";
        const T_DOWN: &str = "+";
        const T_UP: &str = "+";
        const T_RIGHT: &str = "+";
        const T_LEFT: &str = "+";

        // Write the top border
        write!(f, "{}", TOP_LEFT)?;
        for _ in 0..(N * (max_width + 3) - 1) {
            write!(f, "{}", HORIZONTAL)?;
        }
        writeln!(f, "{}", TOP_RIGHT)?;

        // Write each row
        for (i, row) in self.0.iter().enumerate() {
            write!(f, "{}", VERTICAL)?;
            for (j, value) in row.iter().enumerate() {
                write!(f, " {:>width$} ", value, width = max_width)?;
                if j < N - 1 {
                    write!(f, "{}", VERTICAL)?;
                }
            }
            writeln!(f, "{}", VERTICAL)?;

            // Write row separator, except after the last row
            if i < N - 1 {
                write!(f, "{}", T_RIGHT)?;
                for j in 0..N {
                    for _ in 0..(max_width + 2) {
                        write!(f, "{}", HORIZONTAL)?;
                    }
                    if j < N - 1 {
                        write!(f, "{}", CROSS)?;
                    }
                }
                writeln!(f, "{}", T_LEFT)?;
            }
        }

        // Write the bottom border
        write!(f, "{}", BOTTOM_LEFT)?;
        for _ in 0..(N * (max_width + 3) - 1) {
            write!(f, "{}", HORIZONTAL)?;
        }
        writeln!(f, "{}", BOTTOM_RIGHT)
    }
}

pub struct Tpu<const N: usize> {
    ready_in: InputPin,
    finished_in: InputPin,
    clear_accs_out: OutputPin,
    start_out: OutputPin,
    weight_dma: DmaTxChannel,
    data_dma: DmaTxChannel,
    acc_dma: DmaRxChannel,
}

#[derive(Debug)]
pub struct TpuStatus {
    ready: bool,
    finished: bool,
}

impl<const N: usize> Tpu<N> {
    pub fn new(
        gpio: Gpio,
        weight_dma: DmaTxChannel,
        data_dma: DmaTxChannel,
        acc_dma: DmaRxChannel,
    ) -> Self {
        Self {
            ready_in: gpio.input_pin(0),
            finished_in: gpio.input_pin(1),
            clear_accs_out: gpio.output_pin(0),
            start_out: gpio.output_pin(1),
            weight_dma,
            data_dma,
            acc_dma,
        }
    }

    pub fn multiply(
        &mut self,
        weight: &RW<Matrix<u8, N>>,
        data: &RW<Matrix<u8, N>>,
        acc_out: &mut RW<Matrix<u32, N>>,
    ) {
        // Stream weights and data to TPU using DMA.
        self.weight_dma.transmit(
            weight as *const RW<Matrix<u8, N>> as usize,
            size_of::<Matrix<u8, N>>(),
        );
        self.data_dma.transmit(
            data as *const RW<Matrix<u8, N>> as usize,
            size_of::<Matrix<u8, N>>(),
        );

        // Spin until DMA completes.
        while !self.weight_dma.idle() {}
        while !self.data_dma.idle() {}

        assert!(
            self.ready_in.read(),
            "Tried to run a multiplication but the TPU wasn't ready"
        );

        // DMA to receive the results.
        self.acc_dma.receive(
            acc_out as *const RW<Matrix<u32, N>> as usize,
            size_of::<Matrix<u32, N>>(),
        );

        // Toggle start pin.
        self.start_out.write(true);
        self.start_out.write(false);

        // Wait until results are received.
        while !self.acc_dma.idle() {}
    }

    pub fn status(&mut self) -> TpuStatus {
        TpuStatus {
            ready: self.ready_in.read(),
            finished: self.finished_in.read(),
        }
    }
}
