cargo build --release --target riscv32imac-unknown-none-elf
mkdir -p target
cargo objcopy --release --target riscv32imac-unknown-none-elf --bin tpu_app -- -O binary target/tpu_app.bin
../../scripts/neorv32_image_gen -app_bin target/tpu_app.bin target/neorv32_exe.bin
