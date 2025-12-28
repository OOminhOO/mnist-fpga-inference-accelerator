## ====================================================================
## 1. Clock Signal (125 MHz)
## ====================================================================
## Zybo Z7의 메인 클럭(K17)을 사용합니다.
set_property -dict { PACKAGE_PIN K17   IOSTANDARD LVCMOS33 } [get_ports { clk }];
create_clock -add -name sys_clk_pin -period 8.00 -waveform {0 4} [get_ports { clk }];

## ====================================================================
## 2. Reset & Control (Switches)
## ====================================================================
## SW0 (G15) -> rst_n
## 스위치를 내리면(0) 리셋, 올리면(1) 동작합니다.
set_property -dict { PACKAGE_PIN G15   IOSTANDARD LVCMOS33 } [get_ports { rst_n }];

## SW1 (P15) -> data_valid
## 스위치를 올리면 데이터 입력이 유효한 것으로 처리됩니다.
set_property -dict { PACKAGE_PIN P15   IOSTANDARD LVCMOS33 } [get_ports { data_valid }];

## ====================================================================
## 3. Data Inputs (8-bit) -> PMOD JB Header
## ====================================================================
## Zybo에는 스위치가 부족하므로, 8비트 입력은 PMOD 포트(JB)에 할당합니다.
## (비트스트림 생성을 위한 핀 할당이며, 실제로는 점퍼선으로 연결해야 입력 가능)
set_property -dict { PACKAGE_PIN T20   IOSTANDARD LVCMOS33 } [get_ports { data_in[0] }]; # JB1
set_property -dict { PACKAGE_PIN U20   IOSTANDARD LVCMOS33 } [get_ports { data_in[1] }]; # JB2
set_property -dict { PACKAGE_PIN V20   IOSTANDARD LVCMOS33 } [get_ports { data_in[2] }]; # JB3
set_property -dict { PACKAGE_PIN W20   IOSTANDARD LVCMOS33 } [get_ports { data_in[3] }]; # JB4
set_property -dict { PACKAGE_PIN Y18   IOSTANDARD LVCMOS33 } [get_ports { data_in[4] }]; # JB7
set_property -dict { PACKAGE_PIN Y19   IOSTANDARD LVCMOS33 } [get_ports { data_in[5] }]; # JB8
set_property -dict { PACKAGE_PIN W18   IOSTANDARD LVCMOS33 } [get_ports { data_in[6] }]; # JB9
set_property -dict { PACKAGE_PIN W19   IOSTANDARD LVCMOS33 } [get_ports { data_in[7] }]; # JB10

## ====================================================================
## 4. Outputs (LEDs)
## ====================================================================
## LED 0~3 -> Decision (결과 숫자 0~9를 2진수로 표시)
set_property -dict { PACKAGE_PIN M14   IOSTANDARD LVCMOS33 } [get_ports { decision[0] }];
set_property -dict { PACKAGE_PIN M15   IOSTANDARD LVCMOS33 } [get_ports { decision[1] }];
set_property -dict { PACKAGE_PIN G14   IOSTANDARD LVCMOS33 } [get_ports { decision[2] }];
set_property -dict { PACKAGE_PIN D18   IOSTANDARD LVCMOS33 } [get_ports { decision[3] }];

## RGB LED 5 (Red) -> Out Valid (추론 완료 시 켜짐)
set_property -dict { PACKAGE_PIN V16   IOSTANDARD LVCMOS33 } [get_ports { out_valid }];

## ====================================================================
## 5. Configuration (Zybo Z7 필수 설정)
## ====================================================================
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]