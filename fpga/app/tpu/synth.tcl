set output_dir ./output

create_project tpu $output_dir/project -part xc7a100tcsg324-1 -force

set_property ip_repo_paths {
    ../../../external/neorv32/rtl/system_integration/neorv32_vivado_ip_work/packaged_ip
    ../../../external/xilinx/mii_to_rmii_v2_0
} [current_project]
update_ip_catalog

read_verilog $output_dir/tpu_top.v
read_xdc constraints.xdc

# Import block diagram.
exec rm -rf $output_dir/bd
set ::origin_dir_loc output/bd
source ../../bd/tpu_bd.tcl
close_bd_design [get_bd_designs tpu_bd]
generate_target all [get_files output/bd/tpu_bd/tpu_bd.bd]

set ip_list {
    tpu_bd_neorv32_vivado_ip_0_0
    tpu_bd_clk_wiz_0_0
    tpu_bd_axi_ethernetlite_0_0
    tpu_bd_mii_to_rmii_0_0
    tpu_bd_xbar_0
    tpu_bd_blk_mem_gen_0_0
    tpu_bd_axi_bram_ctrl_0_0
    tpu_bd_auto_pc_0
    tpu_bd_auto_pc_1
    tpu_bd_auto_pc_2
    tpu_bd_auto_pc_3
    tpu_bd_axi_dma_0_0
    tpu_bd_axi_dma_1_0
    tpu_bd_proc_sys_reset_0_0
    tpu_bd_util_vector_logic_0_0
    tpu_bd_util_vector_logic_1_0
}

# Export IP cache for each IP.
foreach ip $ip_list {
    catch { config_ip_cache -export [get_ips -all $ip] }
}

export_ip_user_files -of_objects [get_files output/bd/tpu_bd/tpu_bd.bd] -no_script -sync -force
create_ip_run [get_files -of_objects [get_fileset sources_1] output/bd/tpu_bd/tpu_bd.bd]

# Synth IP.
set synth_runs {}
foreach ip $ip_list {
    lappend synth_runs ${ip}_synth_1
}
launch_runs {*}$synth_runs -jobs 4
wait_on_run {*}$synth_runs

# Top-level synth.
synth_design -top tpu_top
write_checkpoint -force $output_dir/post_synth.dcp
