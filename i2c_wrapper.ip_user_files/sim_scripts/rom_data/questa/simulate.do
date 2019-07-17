onbreak {quit -f}
onerror {quit -f}

vsim -t 1ps -lib xil_defaultlib rom_data_opt

do {wave.do}

view wave
view structure
view signals

do {rom_data.udo}

run -all

quit -force
