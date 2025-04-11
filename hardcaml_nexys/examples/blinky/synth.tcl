set_param board.repoPaths "../../boards/"
set output_dir "./output"

create_project hardcaml_nexys $output_dir -part xc7a100tcsg324-1 -force
set_property board_part digilentinc.com:nexys-a7-100t:part0:1.3 [current_project]

set_property ip_repo_paths ../../../external/neorv32/rtl/system_integration/neorv32_vivado_ip_work/packaged_ip [current_project]
update_ip_catalog

exec rm -rf $output_dir/ip
exec cp -r ip/ $output_dir/ip
read_ip -verbose $output_dir/ip/hardcaml_nexys_neorv32_vivado_ip_0_0/hardcaml_nexys_neorv32_vivado_ip_0_0.xci
read_ip -verbose $output_dir/ip/hardcaml_nexys_clk_wiz_0_0/hardcaml_nexys_clk_wiz_0_0.xci

read_verilog hardcaml_nexys_top.v

upgrade_ip [get_ips]
set_property generate_synth_checkpoint false [get_files $output_dir/ip/hardcaml_nexys_neorv32_vivado_ip_0_0/hardcaml_nexys_neorv32_vivado_ip_0_0.xci]
set_property generate_synth_checkpoint false [get_files $output_dir/ip/hardcaml_nexys_clk_wiz_0_0/hardcaml_nexys_clk_wiz_0_0.xci]
generate_target all [get_ips]
validate_ip [get_ips]

synth_design -top hardcaml_nexys_top
write_checkpoint -force $output_dir/post_synth.dcp
