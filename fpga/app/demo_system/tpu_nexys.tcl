
################################################################
# This is a generated script based on design: tpu_nexys
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
# source tpu_nexys_script.tcl

# If there is no project opened, this script will create a
# project, but make sure you do not have an existing project
# <./myproj/project_1.xpr> in the current working folder.

set list_projs [get_projects -quiet]
if { $list_projs eq "" } {
   create_project project_1 myproj -part xc7a100tcsg324-1
}


# CHANGE DESIGN NAME HERE
variable design_name
set design_name tpu_nexys

# This script was generated for a remote BD. To create a non-remote design,
# change the variable <run_remote_bd_flow> to <0>.

set run_remote_bd_flow 1
if { $run_remote_bd_flow == 1 } {
   # Set the reference directory for source file relative paths (by default
   # the value is script directory path)
   set origin_dir output/bd

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

   set s_axi [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 s_axi ]
   set_property -dict [ list \
      CONFIG.ADDR_WIDTH {32} \
      CONFIG.DATA_WIDTH {32} \
      CONFIG.HAS_BURST {0} \
      CONFIG.HAS_CACHE {0} \
      CONFIG.HAS_LOCK {0} \
      CONFIG.HAS_QOS {0} \
      CONFIG.HAS_REGION {0} \
      CONFIG.PROTOCOL {AXI4LITE} \
      ] $s_axi


   # Create ports
   set sys_clk [ create_bd_port -dir I -type clk -freq_hz 100000000 sys_clk ]
   set rst_n [ create_bd_port -dir I -type rst rst_n ]
   set gpio_i [ create_bd_port -dir I -from 7 -to 0 gpio_i ]
   set gpio_o [ create_bd_port -dir O -from 7 -to 0 gpio_o ]
   set uart_rx [ create_bd_port -dir I uart_rx ]
   set uart_tx [ create_bd_port -dir O uart_tx ]
   set eth_rst_n [ create_bd_port -dir O -from 0 -to 0 eth_rst_n ]
   set eth_refclk [ create_bd_port -dir O -type clk eth_refclk ]
   set s_axi_aresetn [ create_bd_port -dir O s_axi_aresetn ]
   set s_axi_aclk [ create_bd_port -dir O -type clk s_axi_aclk ]
   set_property -dict [ list \
      CONFIG.ASSOCIATED_BUSIF {s_axi} \
      ] $s_axi_aclk

   # Create instance: neorv32_vivado_ip_0, and set properties
   set neorv32_vivado_ip_0 [ create_bd_cell -type ip -vlnv NEORV32:user:neorv32_vivado_ip:1.0 neorv32_vivado_ip_0 ]
   set_property -dict [list \
      CONFIG.IO_CLINT_EN {true} \
      CONFIG.IO_GPIO_EN {true} \
      CONFIG.IO_GPIO_IN_NUM {8} \
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
      CONFIG.RESET_PORT {resetn} \
      CONFIG.RESET_TYPE {ACTIVE_LOW} \
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

   # Create interface connections
   connect_bd_intf_net -intf_net axi_ethernetlite_0_MDIO [get_bd_intf_ports eth_mdio] [get_bd_intf_pins axi_ethernetlite_0/MDIO]
   connect_bd_intf_net -intf_net axi_ethernetlite_0_MII [get_bd_intf_pins axi_ethernetlite_0/MII] [get_bd_intf_pins mii_to_rmii_0/MII]
   connect_bd_intf_net -intf_net axi_interconnect_0_M00_AXI [get_bd_intf_pins axi_ethernetlite_0/S_AXI] [get_bd_intf_pins axi_interconnect_0/M00_AXI]
   connect_bd_intf_net -intf_net axi_interconnect_0_M01_AXI [get_bd_intf_ports s_axi] [get_bd_intf_pins axi_interconnect_0/M01_AXI]
   connect_bd_intf_net -intf_net mii_to_rmii_0_RMII_PHY_M [get_bd_intf_ports eth_rmii] [get_bd_intf_pins mii_to_rmii_0/RMII_PHY_M]
   connect_bd_intf_net -intf_net neorv32_vivado_ip_0_m_axi [get_bd_intf_pins neorv32_vivado_ip_0/m_axi] [get_bd_intf_pins axi_interconnect_0/S00_AXI]

   # Create port connections
   connect_bd_net -net axi_ethernetlite_0_ip2intc_irpt [get_bd_pins axi_ethernetlite_0/ip2intc_irpt] [get_bd_pins neorv32_vivado_ip_0/mext_irq_i]
   connect_bd_net -net axi_ethernetlite_0_phy_rst_n [get_bd_pins axi_ethernetlite_0/phy_rst_n] [get_bd_ports eth_rst_n]
   connect_bd_net -net clk_wiz_0_clk_out1 [get_bd_pins clk_wiz_0/clk_out1] [get_bd_pins axi_ethernetlite_0/s_axi_aclk] [get_bd_pins neorv32_vivado_ip_0/clk] [get_bd_pins axi_interconnect_0/ACLK] [get_bd_pins axi_interconnect_0/M00_ACLK] [get_bd_pins axi_interconnect_0/M01_ACLK] [get_bd_pins axi_interconnect_0/S00_ACLK] [get_bd_ports s_axi_aclk]
   connect_bd_net -net clk_wiz_0_clk_out2 [get_bd_pins clk_wiz_0/clk_out2] [get_bd_pins mii_to_rmii_0/ref_clk]
   connect_bd_net -net clk_wiz_0_clk_out3 [get_bd_pins clk_wiz_0/clk_out3] [get_bd_ports eth_refclk]
   connect_bd_net -net clk_wiz_0_locked [get_bd_pins clk_wiz_0/locked] [get_bd_pins axi_ethernetlite_0/s_axi_aresetn] [get_bd_pins neorv32_vivado_ip_0/resetn] [get_bd_pins axi_interconnect_0/M01_ARESETN] [get_bd_pins axi_interconnect_0/M00_ARESETN] [get_bd_pins axi_interconnect_0/S00_ARESETN] [get_bd_pins axi_interconnect_0/ARESETN] [get_bd_pins mii_to_rmii_0/rst_n] [get_bd_ports s_axi_aresetn]
   connect_bd_net -net gpio_i_1 [get_bd_ports gpio_i] [get_bd_pins neorv32_vivado_ip_0/gpio_i]
   connect_bd_net -net neorv32_vivado_ip_0_uart0_txd_o [get_bd_pins neorv32_vivado_ip_0/uart0_txd_o] [get_bd_ports uart_tx]
   connect_bd_net -net neorv32_vivado_ip_1_gpio_o [get_bd_pins neorv32_vivado_ip_0/gpio_o] [get_bd_ports gpio_o]
   connect_bd_net -net rst_n_1 [get_bd_ports rst_n] [get_bd_pins clk_wiz_0/resetn]
   connect_bd_net -net sys_clk_1 [get_bd_ports sys_clk] [get_bd_pins clk_wiz_0/clk_in1]
   connect_bd_net -net uart_rx_1 [get_bd_ports uart_rx] [get_bd_pins neorv32_vivado_ip_0/uart0_rxd_i]

   # Create address segments
   assign_bd_address -offset 0xF0000000 -range 0x00010000 -target_address_space [get_bd_addr_spaces neorv32_vivado_ip_0/m_axi] [get_bd_addr_segs axi_ethernetlite_0/S_AXI/Reg] -force
   assign_bd_address -offset 0xF0010000 -range 0x00010000 -target_address_space [get_bd_addr_spaces neorv32_vivado_ip_0/m_axi] [get_bd_addr_segs s_axi/Reg] -force


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


