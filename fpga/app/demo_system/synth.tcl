set output_dir ./output

proc read_bd {bd} {
    # add_files $bd
    # open_bd_design $bd

    current_bd_design [get_bd_designs tpu_nexys]
    validate_bd_design -force
    report_ip_status
    upgrade_ip [get_ips]

    # reset_target all [get_ips]
    generate_target all [get_files $bd] -force
}

create_project demo_system $output_dir/project -part xc7a100tcsg324-1 -force

set_property ip_repo_paths {
    ../../../external/neorv32/rtl/system_integration/neorv32_vivado_ip_work/packaged_ip
    ../../../external/xilinx/mii_to_rmii_v2_0
} [current_project]
update_ip_catalog

exec rm -rf $output_dir/bd
# exec cp -r ../../bd/ $output_dir/bd

read_verilog $output_dir/demo_system_top.v
read_xdc constraints.xdc
# read_bd $output_dir/bd/tpu_nexys/tpu_nexys.bd

source tpu_nexys.tcl
current_bd_design [get_bd_designs tpu_nexys]
validate_bd_design
generate_target all [get_files output/bd/tpu_nexys/tpu_nexys.bd]


synth_design -top demo_system_top
write_checkpoint -force $output_dir/post_synth.dcp
