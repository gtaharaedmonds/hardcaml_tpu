
################################################################
# This is a generated script based on design: tpu_bd
#
# Though there are limitations about the generated script,
# the main purpose of this utility is to make learning
# IP Integrator Tcl commands easier.
################################################################

namespace eval _tcl {
   proc get_script_folder {} {
      set script_path [file normalize [info script]]
      set script_folder [file dirname $script_path]
      return $script_folder
   }
}
variable script_folder
set script_folder [_tcl::get_script_folder]

################################################################
# Check if script is running in correct Vivado version.
################################################################
set scripts_vivado_version 2024.1
set current_vivado_version [version -short]

if { [string first $scripts_vivado_version $current_vivado_version] == -1 } {
   puts ""
   if { [string compare $scripts_vivado_version $current_vivado_version] > 0 } {
      catch {common::send_gid_msg -ssname BD::TCL -id 2042 -severity "ERROR" " This script was generated using Vivado <$scripts_vivado_version> and is being run in <$current_vivado_version> of Vivado. Sourcing the script failed since it was created with a future version of Vivado."}

   } else {
      catch {common::send_gid_msg -ssname BD::TCL -id 2041 -severity "ERROR" "This script was generated using Vivado <$scripts_vivado_version> and is being run in <$current_vivado_version> of Vivado. Please run the script in Vivado <$scripts_vivado_version> then open the design in Vivado <$current_vivado_version>. Upgrade the design by running \"Tools => Report => Report IP Status...\", then run write_bd_tcl to create an updated script."}

   }

   return 1
}

################################################################
# START
################################################################

# To test this script, run the following commands from Vivado Tcl console:
# source tpu_bd_script.tcl

# If there is no project opened, this script will create a
# project, but make sure you do not have an existing project
# <./myproj/project_1.xpr> in the current working folder.

set list_projs [get_projects -quiet]
if { $list_projs eq "" } {
   create_project project_1 myproj -part xc7a100tcsg324-1
}


# CHANGE DESIGN NAME HERE
variable design_name
set design_name tpu_bd

# This script was generated for a remote BD. To create a non-remote design,
# change the variable <run_remote_bd_flow> to <0>.

set run_remote_bd_flow 1
if { $run_remote_bd_flow == 1 } {
   # Set the reference directory for source file relative paths (by default
   # the value is script directory path)
   set origin_dir ./src/hardcaml_tpu/fpga/app/demo_system/output/bd

   # Use origin directory path location variable, if specified in the tcl shell
   if { [info exists ::origin_dir_loc] } {
      set origin_dir $::origin_dir_loc
   }

   set str_bd_folder [file normalize ${origin_dir}]
   set str_bd_filepath ${str_bd_folder}/${design_name}/${design_name}.bd

   # Check if remote design exists on disk
   if { [file exists $str_bd_filepath ] == 1 } {
      catch {common::send_gid_msg -ssname BD::TCL -id 2030 -severity "ERROR" "The remote BD file path <$str_bd_filepath> already exists!"}
      common::send_gid_msg -ssname BD::TCL -id 2031 -severity "INFO" "To create a non-remote BD, change the variable <run_remote_bd_flow> to <0>."
      common::send_gid_msg -ssname BD::TCL -id 2032 -severity "INFO" "Also make sure there is no design <$design_name> existing in your current project."

      return 1
   }

   # Check if design exists in memory
   set list_existing_designs [get_bd_designs -quiet $design_name]
   if { $list_existing_designs ne "" } {
      catch {common::send_gid_msg -ssname BD::TCL -id 2033 -severity "ERROR" "The design <$design_name> already exists in this project! Will not create the remote BD <$design_name> at the folder <$str_bd_folder>."}

      common::send_gid_msg -ssname BD::TCL -id 2034 -severity "INFO" "To create a non-remote BD, change the variable <run_remote_bd_flow> to <0> or please set a different value to variable <design_name>."

      return 1
   }

   # Check if design exists on disk within project
   set list_existing_designs [get_files -quiet */${design_name}.bd]
   if { $list_existing_designs ne "" } {
      catch {common::send_gid_msg -ssname BD::TCL -id 2035 -severity "ERROR" "The design <$design_name> already exists in this project at location:
         $list_existing_designs"}
         catch {common::send_gid_msg -ssname BD::TCL -id 2036 -severity "ERROR" "Will not create the remote BD <$design_name> at the folder <$str_bd_folder>."}

         common::send_gid_msg -ssname BD::TCL -id 2037 -severity "INFO" "To create a non-remote BD, change the variable <run_remote_bd_flow> to <0> or please set a different value to variable <design_name>."

         return 1
      }

      # Now can create the remote BD
      # NOTE - usage of <-dir> will create <$str_bd_folder/$design_name/$design_name.bd>
      create_bd_design -dir $str_bd_folder $design_name
   } else {

   # Create regular design
   if { [catch {create_bd_design $design_name} errmsg] } {
      common::send_gid_msg -ssname BD::TCL -id 2038 -severity "INFO" "Please set a different value to variable <design_name>."

      return 1
   }
}

current_bd_design $design_name

set bCheckIPsPassed 1
##################################################################
# CHECK IPs
##################################################################
set bCheckIPs 1
if { $bCheckIPs == 1 } {
   set list_check_ips "\
      NEORV32:user:neorv32_vivado_ip:1.0\
      xilinx.com:ip:clk_wiz:6.0\
      xilinx.com:ip:axi_ethernetlite:3.0\
      xilinx.com:ip:mii_to_rmii:2.0\
      xilinx.com:ip:blk_mem_gen:8.4\
      xilinx.com:ip:axi_bram_ctrl:4.1\
      xilinx.com:ip:axi_dma:7.1\
      xilinx.com:ip:proc_sys_reset:5.0\
      xilinx.com:ip:util_vector_logic:2.0\
      xilinx.com:ip:xlconcat:2.1\
      xilinx.com:ip:xlconstant:1.1\
   "

set list_ips_missing ""
common::send_gid_msg -ssname BD::TCL -id 2011 -severity "INFO" "Checking if the following IPs exist in the project's IP catalog: $list_check_ips ."

foreach ip_vlnv $list_check_ips {
   set ip_obj [get_ipdefs -all $ip_vlnv]
   if { $ip_obj eq "" } {
      lappend list_ips_missing $ip_vlnv
   }
}

if { $list_ips_missing ne "" } {
   catch {common::send_gid_msg -ssname BD::TCL -id 2012 -severity "ERROR" "The following IPs are not found in the IP Catalog:\n  $list_ips_missing\n\nResolution: Please add the repository containing the IP(s) to the project." }
   set bCheckIPsPassed 0
}

}

if { $bCheckIPsPassed != 1 } {
   common::send_gid_msg -ssname BD::TCL -id 2023 -severity "WARNING" "Will not continue with creation of design due to the error(s) above."
   return 3
}

##################################################################
# DESIGN PROCs
##################################################################



# Procedure to create entire design; Provide argument to make
# procedure reusable. If parentCell is "", will use root.
proc create_root_design { parentCell } {

   variable script_folder
   variable design_name

   if { $parentCell eq "" } {
      set parentCell [get_bd_cells /]
   }

   # Get object for parentCell
   set parentObj [get_bd_cells $parentCell]
   if { $parentObj == "" } {
      catch {common::send_gid_msg -ssname BD::TCL -id 2090 -severity "ERROR" "Unable to find parent cell <$parentCell>!"}
      return
   }

   # Make sure parentObj is hier blk
   set parentType [get_property TYPE $parentObj]
   if { $parentType ne "hier" } {
      catch {common::send_gid_msg -ssname BD::TCL -id 2091 -severity "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
      return
   }

   # Save current instance; Restore later
   set oldCurInst [current_bd_instance .]

   # Set parent object as current
   current_bd_instance $parentObj


   # Create interface ports
   set eth_mdio [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:mdio_rtl:1.0 eth_mdio ]

   set eth_rmii [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:rmii_rtl:1.0 eth_rmii ]

   set axi_mm2s_0 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 axi_mm2s_0 ]

   set axi_s2mm [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:axis_rtl:1.0 axi_s2mm ]
   set_property -dict [ list \
      CONFIG.HAS_TKEEP {1} \
      CONFIG.HAS_TLAST {1} \
      CONFIG.HAS_TREADY {1} \
      CONFIG.HAS_TSTRB {0} \
      CONFIG.LAYERED_METADATA {undef} \
      CONFIG.TDATA_NUM_BYTES {4} \
      CONFIG.TDEST_WIDTH {0} \
      CONFIG.TID_WIDTH {0} \
      CONFIG.TUSER_WIDTH {0} \
      ] $axi_s2mm

   set axi_mm2s_1 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:axis_rtl:1.0 axi_mm2s_1 ]


   # Create ports
   set sys_clk [ create_bd_port -dir I -type clk -freq_hz 100000000 sys_clk ]
   set rst_n [ create_bd_port -dir I -type rst rst_n ]
   set gpio_i [ create_bd_port -dir I -from 7 -to 0 gpio_i ]
   set gpio_o [ create_bd_port -dir O -from 7 -to 0 gpio_o ]
   set uart_rx [ create_bd_port -dir I uart_rx ]
   set uart_tx [ create_bd_port -dir O uart_tx ]
   set eth_rst_n [ create_bd_port -dir O -from 0 -to 0 eth_rst_n ]
   set eth_refclk [ create_bd_port -dir O -type clk eth_refclk ]
   set axi_clk [ create_bd_port -dir O -type clk axi_clk ]
   set_property -dict [ list \
      CONFIG.ASSOCIATED_BUSIF {axi_s2mm:axi_mm2s_0:axi_mm2s_1} \
      ] $axi_clk
   set axi_rst_n [ create_bd_port -dir O -from 0 -to 0 axi_rst_n ]

   # Create instance: neorv32_vivado_ip_0, and set properties
   set neorv32_vivado_ip_0 [ create_bd_cell -type ip -vlnv NEORV32:user:neorv32_vivado_ip:1.0 neorv32_vivado_ip_0 ]
   set_property -dict [list \
      CONFIG.IO_CLINT_EN {true} \
      CONFIG.IO_GPIO_EN {true} \
      CONFIG.IO_GPIO_IN_NUM {16} \
      CONFIG.IO_GPIO_OUT_NUM {8} \
      CONFIG.IO_UART0_EN {true} \
      CONFIG.IO_UART0_RX_FIFO {64} \
      CONFIG.IO_UART0_TX_FIFO {64} \
      CONFIG.MEM_INT_DMEM_EN {true} \
      CONFIG.MEM_INT_DMEM_SIZE {65536} \
      CONFIG.MEM_INT_IMEM_EN {true} \
      CONFIG.MEM_INT_IMEM_SIZE {65536} \
      CONFIG.OCD_EN {false} \
      CONFIG.RISCV_ISA_C {true} \
      CONFIG.RISCV_ISA_E {false} \
      CONFIG.RISCV_ISA_M {true} \
      CONFIG.RISCV_ISA_Zaamo {true} \
      CONFIG.RISCV_ISA_Zalrsc {true} \
      CONFIG.RISCV_ISA_Zicntr {true} \
      CONFIG.XBUS_EN {true} \
      CONFIG.XBUS_REGSTAGE_EN {false} \
      ] $neorv32_vivado_ip_0


   # Create instance: clk_wiz_0, and set properties
   set clk_wiz_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_wiz_0 ]
   set_property -dict [list \
      CONFIG.CLKOUT2_JITTER {151.636} \
      CONFIG.CLKOUT2_PHASE_ERROR {98.575} \
      CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {50.000} \
      CONFIG.CLKOUT2_USED {true} \
      CONFIG.CLKOUT3_JITTER {151.636} \
      CONFIG.CLKOUT3_PHASE_ERROR {98.575} \
      CONFIG.CLKOUT3_REQUESTED_OUT_FREQ {50} \
      CONFIG.CLKOUT3_REQUESTED_PHASE {45} \
      CONFIG.CLKOUT3_USED {true} \
      CONFIG.MMCM_CLKOUT1_DIVIDE {20} \
      CONFIG.MMCM_CLKOUT2_DIVIDE {20} \
      CONFIG.MMCM_CLKOUT2_PHASE {45.000} \
      CONFIG.NUM_OUT_CLKS {3} \
      CONFIG.RESET_PORT {reset} \
      CONFIG.RESET_TYPE {ACTIVE_HIGH} \
      CONFIG.USE_DYN_PHASE_SHIFT {false} \
      ] $clk_wiz_0


   # Create instance: axi_ethernetlite_0, and set properties
   set axi_ethernetlite_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_ethernetlite:3.0 axi_ethernetlite_0 ]
   set_property -dict [list \
      CONFIG.C_INCLUDE_GLOBAL_BUFFERS {1} \
      CONFIG.C_INCLUDE_INTERNAL_LOOPBACK {0} \
      CONFIG.C_INCLUDE_MDIO {1} \
      CONFIG.C_RX_PING_PONG {0} \
      CONFIG.C_TX_PING_PONG {0} \
      ] $axi_ethernetlite_0


   # Create instance: mii_to_rmii_0, and set properties
   set mii_to_rmii_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:mii_to_rmii:2.0 mii_to_rmii_0 ]

   # Create instance: axi_interconnect_0, and set properties
   set axi_interconnect_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_interconnect_0 ]
   set_property -dict [list \
      CONFIG.NUM_MI {4} \
      CONFIG.NUM_SI {4} \
      ] $axi_interconnect_0


   # Create instance: blk_mem_gen_0, and set properties
   set blk_mem_gen_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:blk_mem_gen:8.4 blk_mem_gen_0 ]
   set_property CONFIG.Memory_Type {Single_Port_RAM} $blk_mem_gen_0


   # Create instance: axi_bram_ctrl_0, and set properties
   set axi_bram_ctrl_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 axi_bram_ctrl_0 ]
   set_property -dict [list \
      CONFIG.PROTOCOL {AXI4} \
      CONFIG.SINGLE_PORT_BRAM {1} \
      ] $axi_bram_ctrl_0


   # Create instance: axi_dma_0, and set properties
   set axi_dma_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma_0 ]
   set_property -dict [list \
      CONFIG.c_include_s2mm_dre {0} \
      CONFIG.c_include_sg {0} \
      ] $axi_dma_0


   # Create instance: proc_sys_reset_0, and set properties
   set proc_sys_reset_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_0 ]

   # Create instance: util_vector_logic_0, and set properties
   set util_vector_logic_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:util_vector_logic:2.0 util_vector_logic_0 ]
   set_property -dict [list \
      CONFIG.C_OPERATION {not} \
      CONFIG.C_SIZE {1} \
      ] $util_vector_logic_0


   # Create instance: xlconcat_0, and set properties
   set xlconcat_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 xlconcat_0 ]
   set_property -dict [list \
      CONFIG.IN0_WIDTH {8} \
      CONFIG.IN6_WIDTH {3} \
      CONFIG.NUM_PORTS {7} \
      ] $xlconcat_0


   # Create instance: util_vector_logic_1, and set properties
   set util_vector_logic_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:util_vector_logic:2.0 util_vector_logic_1 ]
   set_property -dict [list \
      CONFIG.C_OPERATION {not} \
      CONFIG.C_SIZE {1} \
      ] $util_vector_logic_1


   # Create instance: xlconstant_0, and set properties
   set xlconstant_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_0 ]
   set_property -dict [list \
      CONFIG.CONST_VAL {0} \
      CONFIG.CONST_WIDTH {3} \
      ] $xlconstant_0


   # Create instance: axi_dma_1, and set properties
   set axi_dma_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma_1 ]
   set_property -dict [list \
      CONFIG.c_include_mm2s {1} \
      CONFIG.c_include_s2mm {0} \
      CONFIG.c_include_sg {0} \
      ] $axi_dma_1


   # Create interface connections
   connect_bd_intf_net -intf_net S_AXIS_S2MM_0_1 [get_bd_intf_ports axi_s2mm] [get_bd_intf_pins axi_dma_0/S_AXIS_S2MM]
   connect_bd_intf_net -intf_net axi_bram_ctrl_0_BRAM_PORTA [get_bd_intf_pins axi_bram_ctrl_0/BRAM_PORTA] [get_bd_intf_pins blk_mem_gen_0/BRAM_PORTA]
   connect_bd_intf_net -intf_net axi_dma_0_M_AXIS_MM2S [get_bd_intf_ports axi_mm2s_0] [get_bd_intf_pins axi_dma_0/M_AXIS_MM2S]
   connect_bd_intf_net -intf_net axi_dma_0_M_AXI_MM2S [get_bd_intf_pins axi_dma_0/M_AXI_MM2S] [get_bd_intf_pins axi_interconnect_0/S01_AXI]
   connect_bd_intf_net -intf_net axi_dma_0_M_AXI_S2MM [get_bd_intf_pins axi_dma_0/M_AXI_S2MM] [get_bd_intf_pins axi_interconnect_0/S02_AXI]
   connect_bd_intf_net -intf_net axi_dma_1_M_AXIS_MM2S [get_bd_intf_ports axi_mm2s_1] [get_bd_intf_pins axi_dma_1/M_AXIS_MM2S]
   connect_bd_intf_net -intf_net axi_dma_1_M_AXI_MM2S [get_bd_intf_pins axi_dma_1/M_AXI_MM2S] [get_bd_intf_pins axi_interconnect_0/S03_AXI]
   connect_bd_intf_net -intf_net axi_ethernetlite_0_MDIO [get_bd_intf_ports eth_mdio] [get_bd_intf_pins axi_ethernetlite_0/MDIO]
   connect_bd_intf_net -intf_net axi_ethernetlite_0_MII [get_bd_intf_pins axi_ethernetlite_0/MII] [get_bd_intf_pins mii_to_rmii_0/MII]
   connect_bd_intf_net -intf_net axi_interconnect_0_M00_AXI [get_bd_intf_pins axi_ethernetlite_0/S_AXI] [get_bd_intf_pins axi_interconnect_0/M00_AXI]
   connect_bd_intf_net -intf_net axi_interconnect_0_M01_AXI [get_bd_intf_pins axi_interconnect_0/M01_AXI] [get_bd_intf_pins axi_dma_0/S_AXI_LITE]
   connect_bd_intf_net -intf_net axi_interconnect_0_M02_AXI [get_bd_intf_pins axi_interconnect_0/M02_AXI] [get_bd_intf_pins axi_dma_1/S_AXI_LITE]
   connect_bd_intf_net -intf_net axi_interconnect_0_M03_AXI [get_bd_intf_pins axi_interconnect_0/M03_AXI] [get_bd_intf_pins axi_bram_ctrl_0/S_AXI]
   connect_bd_intf_net -intf_net mii_to_rmii_0_RMII_PHY_M [get_bd_intf_ports eth_rmii] [get_bd_intf_pins mii_to_rmii_0/RMII_PHY_M]
   connect_bd_intf_net -intf_net neorv32_vivado_ip_0_m_axi [get_bd_intf_pins neorv32_vivado_ip_0/m_axi] [get_bd_intf_pins axi_interconnect_0/S00_AXI]

   # Create port connections
   connect_bd_net -net axi_dma_0_mm2s_introut [get_bd_pins axi_dma_0/mm2s_introut] [get_bd_pins xlconcat_0/In2]
   connect_bd_net -net axi_dma_0_mm2s_prmry_reset_out_n [get_bd_pins axi_dma_0/mm2s_prmry_reset_out_n] [get_bd_pins axi_interconnect_0/S01_ARESETN]
   connect_bd_net -net axi_dma_0_s2mm_introut [get_bd_pins axi_dma_0/s2mm_introut] [get_bd_pins xlconcat_0/In3]
   connect_bd_net -net axi_dma_0_s2mm_prmry_reset_out_n [get_bd_pins axi_dma_0/s2mm_prmry_reset_out_n] [get_bd_pins axi_interconnect_0/S02_ARESETN]
   connect_bd_net -net axi_dma_1_mm2s_introut [get_bd_pins axi_dma_1/mm2s_introut] [get_bd_pins xlconcat_0/In4]
   connect_bd_net -net axi_dma_1_mm2s_prmry_reset_out_n [get_bd_pins axi_dma_1/mm2s_prmry_reset_out_n] [get_bd_pins axi_interconnect_0/S03_ARESETN]
   connect_bd_net -net axi_ethernetlite_0_ip2intc_irpt [get_bd_pins axi_ethernetlite_0/ip2intc_irpt] [get_bd_pins xlconcat_0/In1]
   connect_bd_net -net axi_ethernetlite_0_phy_rst_n [get_bd_pins axi_ethernetlite_0/phy_rst_n] [get_bd_ports eth_rst_n]
   connect_bd_net -net clk_wiz_0_clk_out1 [get_bd_pins clk_wiz_0/clk_out1] [get_bd_pins neorv32_vivado_ip_0/clk] [get_bd_pins proc_sys_reset_0/slowest_sync_clk] [get_bd_pins axi_dma_0/m_axi_s2mm_aclk] [get_bd_pins axi_dma_0/m_axi_mm2s_aclk] [get_bd_pins axi_dma_0/s_axi_lite_aclk] [get_bd_pins axi_interconnect_0/ACLK] [get_bd_pins axi_interconnect_0/S00_ACLK] [get_bd_pins axi_interconnect_0/M00_ACLK] [get_bd_pins axi_interconnect_0/M01_ACLK] [get_bd_pins axi_interconnect_0/M02_ACLK] [get_bd_pins axi_interconnect_0/S01_ACLK] [get_bd_pins axi_interconnect_0/S02_ACLK] [get_bd_pins axi_bram_ctrl_0/s_axi_aclk] [get_bd_pins axi_ethernetlite_0/s_axi_aclk] [get_bd_ports axi_clk] [get_bd_pins axi_dma_1/s_axi_lite_aclk] [get_bd_pins axi_dma_1/m_axi_mm2s_aclk] [get_bd_pins axi_interconnect_0/M03_ACLK] [get_bd_pins axi_interconnect_0/S03_ACLK]
   connect_bd_net -net clk_wiz_0_clk_out2 [get_bd_pins clk_wiz_0/clk_out2] [get_bd_pins mii_to_rmii_0/ref_clk]
   connect_bd_net -net clk_wiz_0_clk_out3 [get_bd_pins clk_wiz_0/clk_out3] [get_bd_ports eth_refclk]
   connect_bd_net -net clk_wiz_0_locked [get_bd_pins clk_wiz_0/locked] [get_bd_pins proc_sys_reset_0/dcm_locked]
   connect_bd_net -net gpio_i_1 [get_bd_ports gpio_i] [get_bd_pins xlconcat_0/In0]
   connect_bd_net -net neorv32_vivado_ip_0_uart0_txd_o [get_bd_pins neorv32_vivado_ip_0/uart0_txd_o] [get_bd_ports uart_tx]
   connect_bd_net -net neorv32_vivado_ip_1_gpio_o [get_bd_pins neorv32_vivado_ip_0/gpio_o] [get_bd_ports gpio_o]
   connect_bd_net -net proc_sys_reset_0_interconnect_aresetn [get_bd_pins proc_sys_reset_0/interconnect_aresetn] [get_bd_pins axi_interconnect_0/ARESETN]
   connect_bd_net -net proc_sys_reset_0_mb_reset [get_bd_pins proc_sys_reset_0/mb_reset] [get_bd_pins util_vector_logic_0/Op1]
   connect_bd_net -net proc_sys_reset_0_peripheral_aresetn [get_bd_pins proc_sys_reset_0/peripheral_aresetn] [get_bd_pins axi_ethernetlite_0/s_axi_aresetn] [get_bd_pins axi_dma_0/axi_resetn] [get_bd_pins axi_bram_ctrl_0/s_axi_aresetn] [get_bd_pins axi_interconnect_0/M02_ARESETN] [get_bd_pins axi_interconnect_0/M01_ARESETN] [get_bd_pins axi_interconnect_0/M00_ARESETN] [get_bd_ports axi_rst_n] [get_bd_pins mii_to_rmii_0/rst_n] [get_bd_pins axi_dma_1/axi_resetn] [get_bd_pins axi_interconnect_0/M03_ARESETN]
   connect_bd_net -net rst_n_1 [get_bd_ports rst_n] [get_bd_pins util_vector_logic_1/Op1]
   connect_bd_net -net sys_clk_1 [get_bd_ports sys_clk] [get_bd_pins clk_wiz_0/clk_in1]
   connect_bd_net -net uart_rx_1 [get_bd_ports uart_rx] [get_bd_pins neorv32_vivado_ip_0/uart0_rxd_i]
   connect_bd_net -net util_vector_logic_0_Res [get_bd_pins util_vector_logic_0/Res] [get_bd_pins neorv32_vivado_ip_0/resetn] [get_bd_pins axi_interconnect_0/S00_ARESETN]
   connect_bd_net -net util_vector_logic_1_Res [get_bd_pins util_vector_logic_1/Res] [get_bd_pins proc_sys_reset_0/ext_reset_in] [get_bd_pins clk_wiz_0/reset]
   connect_bd_net -net xlconcat_0_dout [get_bd_pins xlconcat_0/dout] [get_bd_pins neorv32_vivado_ip_0/gpio_i]
   connect_bd_net -net xlconstant_0_dout [get_bd_pins xlconstant_0/dout] [get_bd_pins xlconcat_0/In6]

   # Create address segments
   assign_bd_address -offset 0xF0020000 -range 0x00010000 -target_address_space [get_bd_addr_spaces neorv32_vivado_ip_0/m_axi] [get_bd_addr_segs axi_bram_ctrl_0/S_AXI/Mem0] -force
   assign_bd_address -offset 0xF0010000 -range 0x00008000 -target_address_space [get_bd_addr_spaces neorv32_vivado_ip_0/m_axi] [get_bd_addr_segs axi_dma_0/S_AXI_LITE/Reg] -force
   assign_bd_address -offset 0xF0018000 -range 0x00008000 -target_address_space [get_bd_addr_spaces neorv32_vivado_ip_0/m_axi] [get_bd_addr_segs axi_dma_1/S_AXI_LITE/Reg] -force
   assign_bd_address -offset 0xF0000000 -range 0x00010000 -target_address_space [get_bd_addr_spaces neorv32_vivado_ip_0/m_axi] [get_bd_addr_segs axi_ethernetlite_0/S_AXI/Reg] -force
   assign_bd_address -offset 0xF0020000 -range 0x00010000 -target_address_space [get_bd_addr_spaces axi_dma_0/Data_MM2S] [get_bd_addr_segs axi_bram_ctrl_0/S_AXI/Mem0] -force
   assign_bd_address -offset 0xF0020000 -range 0x00010000 -target_address_space [get_bd_addr_spaces axi_dma_0/Data_S2MM] [get_bd_addr_segs axi_bram_ctrl_0/S_AXI/Mem0] -force
   assign_bd_address -offset 0xF0020000 -range 0x00010000 -target_address_space [get_bd_addr_spaces axi_dma_1/Data_MM2S] [get_bd_addr_segs axi_bram_ctrl_0/S_AXI/Mem0] -force

   # Exclude Address Segments
   exclude_bd_addr_seg -offset 0xF0010000 -range 0x00000400 -target_address_space [get_bd_addr_spaces axi_dma_0/Data_MM2S] [get_bd_addr_segs axi_dma_0/S_AXI_LITE/Reg]
   exclude_bd_addr_seg -offset 0xF0018000 -range 0x00008000 -target_address_space [get_bd_addr_spaces axi_dma_0/Data_MM2S] [get_bd_addr_segs axi_dma_1/S_AXI_LITE/Reg]
   exclude_bd_addr_seg -offset 0xF0000000 -range 0x00004000 -target_address_space [get_bd_addr_spaces axi_dma_0/Data_MM2S] [get_bd_addr_segs axi_ethernetlite_0/S_AXI/Reg]
   exclude_bd_addr_seg -offset 0xF0010000 -range 0x00000400 -target_address_space [get_bd_addr_spaces axi_dma_0/Data_S2MM] [get_bd_addr_segs axi_dma_0/S_AXI_LITE/Reg]
   exclude_bd_addr_seg -offset 0xF0018000 -range 0x00008000 -target_address_space [get_bd_addr_spaces axi_dma_0/Data_S2MM] [get_bd_addr_segs axi_dma_1/S_AXI_LITE/Reg]
   exclude_bd_addr_seg -offset 0xF0000000 -range 0x00004000 -target_address_space [get_bd_addr_spaces axi_dma_0/Data_S2MM] [get_bd_addr_segs axi_ethernetlite_0/S_AXI/Reg]
   exclude_bd_addr_seg -offset 0xF0010000 -range 0x00008000 -target_address_space [get_bd_addr_spaces axi_dma_1/Data_MM2S] [get_bd_addr_segs axi_dma_0/S_AXI_LITE/Reg]
   exclude_bd_addr_seg -offset 0xF0018000 -range 0x00008000 -target_address_space [get_bd_addr_spaces axi_dma_1/Data_MM2S] [get_bd_addr_segs axi_dma_1/S_AXI_LITE/Reg]
   exclude_bd_addr_seg -offset 0xF0000000 -range 0x00010000 -target_address_space [get_bd_addr_spaces axi_dma_1/Data_MM2S] [get_bd_addr_segs axi_ethernetlite_0/S_AXI/Reg]


   # Restore current instance
   current_bd_instance $oldCurInst

   validate_bd_design
   save_bd_design
}
# End of create_root_design()


##################################################################
# MAIN FLOW
##################################################################

create_root_design ""


