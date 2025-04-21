cargo build --release --target riscv32imac-unknown-none-elf
mkdir -p target
cargo objcopy --release --target riscv32imac-unknown-none-elf --bin dma_demo -- -O binary target/dma_demo.bin
../../scripts/neorv32_image_gen -app_bin target/dma_demo.bin target/neorv32_exe.bin
