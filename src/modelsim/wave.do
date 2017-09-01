onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /iac_testbench/clock
add wave -noupdate /iac_testbench/reset_n
add wave -noupdate -expand -group Inputs -radix binary /iac_testbench/switch
add wave -noupdate -expand -group Inputs -radix binary /iac_testbench/key
add wave -noupdate -expand -group LED -radix decimal /iac_testbench/led_red
add wave -noupdate -expand -group LCD /iac_testbench/lcd_rs
add wave -noupdate -expand -group LCD /iac_testbench/lcd_en
add wave -noupdate -expand -group LCD /iac_testbench/lcd_rw
add wave -noupdate -expand -group LCD -radix ascii /iac_testbench/lcd_dat
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ps} 0}
quietly wave cursor active 0
configure wave -namecolwidth 150
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ps
update
WaveRestoreZoom {0 ps} {1 ns}
