cargo build --release --target riscv32imac-unknown-none-elf
mkdir -p target
cargo objcopy --release --target riscv32imac-unknown-none-elf --bin blinky -- -O binary target/blinky.bin
../../scripts/neorv32_image_gen -app_bin target/blinky.bin target/neorv32_exe.bin
