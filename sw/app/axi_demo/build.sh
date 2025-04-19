cargo build --release --target riscv32imac-unknown-none-elf
mkdir -p target
cargo objcopy --release --target riscv32imac-unknown-none-elf --bin axi_demo -- -O binary target/axi_demo.bin
../../scripts/neorv32_image_gen -app_bin target/axi_demo.bin target/neorv32_exe.bin
