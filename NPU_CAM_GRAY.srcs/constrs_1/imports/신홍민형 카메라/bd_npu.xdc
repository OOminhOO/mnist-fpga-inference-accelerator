## This file is designed for Zybo Z7-20 with OV7670 Camera
## System Clock: 125MHz

## 1. Clock Signal
set_property -dict { PACKAGE_PIN K17   IOSTANDARD LVCMOS33 } [get_ports { clk }]; 
create_clock -add -name sys_clk_pin -period 8.00 -waveform {0 4} [get_ports { clk }];


## 2. Switches (Only 4 on Zybo)
## sw[0]: Bounding Box, sw[1]: Show Process, sw[2]: LeNet Enable, sw[3]: Capture
#set_property -dict { PACKAGE_PIN G15   IOSTANDARD LVCMOS33 } [get_ports { sw[0] }]; 
#set_property -dict { PACKAGE_PIN P15   IOSTANDARD LVCMOS33 } [get_ports { sw[1] }]; 
#set_property -dict { PACKAGE_PIN W13   IOSTANDARD LVCMOS33 } [get_ports { sw[2] }]; 
#set_property -dict { PACKAGE_PIN T16   IOSTANDARD LVCMOS33 } [get_ports { sw[3] }]; 


## 3. Buttons
## btn[0] is used for RESET
set_property -dict { PACKAGE_PIN K18   IOSTANDARD LVCMOS33 } [get_ports { btn }]; 
#set_property -dict { PACKAGE_PIN P16   IOSTANDARD LVCMOS33 } [get_ports { btn[1] }]; 
#set_property -dict { PACKAGE_PIN K19   IOSTANDARD LVCMOS33 } [get_ports { btn[2] }]; 
#set_property -dict { PACKAGE_PIN Y16   IOSTANDARD LVCMOS33 } [get_ports { btn[3] }]; 


## 4. LEDs (Only 4 on Zybo)
set_property -dict { PACKAGE_PIN M14   IOSTANDARD LVCMOS33 } [get_ports { led[0] }]; 
set_property -dict { PACKAGE_PIN M15   IOSTANDARD LVCMOS33 } [get_ports { led[1] }]; 
set_property -dict { PACKAGE_PIN G14   IOSTANDARD LVCMOS33 } [get_ports { led[2] }]; 
set_property -dict { PACKAGE_PIN D18   IOSTANDARD LVCMOS33 } [get_ports { led[3] }]; 


## 5. HDMI TX (Replaces VGA)
## Signals: hdmi_tx_clk_p/n, hdmi_tx_data_p/n[2:0]
set_property -dict { PACKAGE_PIN H16   IOSTANDARD TMDS_33 } [get_ports { hdmi_tx_clk_p }]; 
set_property -dict { PACKAGE_PIN H17   IOSTANDARD TMDS_33 } [get_ports { hdmi_tx_clk_n }]; 
set_property -dict { PACKAGE_PIN D19   IOSTANDARD TMDS_33 } [get_ports { hdmi_tx_data_p[0] }]; 
set_property -dict { PACKAGE_PIN D20   IOSTANDARD TMDS_33 } [get_ports { hdmi_tx_data_n[0] }]; 
set_property -dict { PACKAGE_PIN C20   IOSTANDARD TMDS_33 } [get_ports { hdmi_tx_data_p[1] }]; 
set_property -dict { PACKAGE_PIN B20   IOSTANDARD TMDS_33 } [get_ports { hdmi_tx_data_n[1] }]; 
set_property -dict { PACKAGE_PIN B19   IOSTANDARD TMDS_33 } [get_ports { hdmi_tx_data_p[2] }]; 
set_property -dict { PACKAGE_PIN A20   IOSTANDARD TMDS_33 } [get_ports { hdmi_tx_data_n[2] }]; 


## 6. OV7670 Camera Interface (Mapped to Pmod JB & JC)


## Pmod JB (Top Row)
set_property -dict { PACKAGE_PIN V8    IOSTANDARD LVCMOS33 } [get_ports { OV7670_RESET_N }]; # JB1     ret
set_property -dict { PACKAGE_PIN W8    IOSTANDARD LVCMOS33 } [get_ports { OV7670_D[1] }    ]; # JB2     D1
set_property -dict { PACKAGE_PIN U7    IOSTANDARD LVCMOS33 } [get_ports { OV7670_D[3] }    ]; # JB3     D3
set_property -dict { PACKAGE_PIN V7    IOSTANDARD LVCMOS33 } [get_ports { OV7670_D[5] }    ]; # JB4     D5



## Pmod JB (Bottom Row)
set_property -dict { PACKAGE_PIN Y7    IOSTANDARD LVCMOS33 } [get_ports { OV7670_XCLK } ];# JB7     XLK      #IO_L13P_T2_MRCC_13 Sch=jb_p[3]
set_property -dict { PACKAGE_PIN Y6    IOSTANDARD LVCMOS33 } [get_ports { OV7670_PCLK } ]; # JB8    PLK     #IO_L13N_T2_MRCC_13 Sch=jb_n[3] 
set_property -dict { PACKAGE_PIN V6    IOSTANDARD LVCMOS33 } [get_ports { OV7670_VSYNC }]; # JB9    VS
set_property -dict { PACKAGE_PIN W6    IOSTANDARD LVCMOS33 } [get_ports { OV7670_SIOC } ]; # JB10   SCL




## Pmod JC (Top Row)
set_property -dict { PACKAGE_PIN V15   IOSTANDARD LVCMOS33 } [get_ports { OV7670_PWDN }]; # JC1     PWDM
set_property -dict { PACKAGE_PIN W15   IOSTANDARD LVCMOS33 } [get_ports { OV7670_D[0] }]; # JC2     D0
set_property -dict { PACKAGE_PIN T11   IOSTANDARD LVCMOS33 } [get_ports { OV7670_D[2] }]; # JC3     D2
set_property -dict { PACKAGE_PIN T10   IOSTANDARD LVCMOS33 } [get_ports { OV7670_D[4] }]; # JC4     D4




## Pmod JC (Bottom Row)
set_property -dict { PACKAGE_PIN W14   IOSTANDARD LVCMOS33 } [get_ports { OV7670_D[6] }]; # JC7     D6
set_property -dict { PACKAGE_PIN Y14   IOSTANDARD LVCMOS33 } [get_ports { OV7670_D[7] }];# JC8      D7
set_property -dict { PACKAGE_PIN T12   IOSTANDARD LVCMOS33 } [get_ports { OV7670_HREF }]; # JC9     HS 
set_property -dict { PACKAGE_PIN U12   IOSTANDARD LVCMOS33 } [get_ports { OV7670_SIOD }]; # JC10    SDA


## Pullups for I2C
set_property PULLUP true [get_ports OV7670_SIOD]
set_property PULLUP true [get_ports OV7670_SIOC]

## Clock Dedicated Route (Essential for PCLK on non-clock pin)
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets -of_objects [get_ports OV7670_PCLK]]
