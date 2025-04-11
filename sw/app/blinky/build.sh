cargo build --release
mkdir -p target
cargo objcopy --release --bin blinky -- -O binary target/blinky.bin
../../scripts/neorv32_image_gen -app_bin target/blinky.bin target/neorv32_exe.bin
