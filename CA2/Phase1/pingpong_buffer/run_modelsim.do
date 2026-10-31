# Run from the project root: do run_modelsim.do
# Optional selection: set TEST tb_fp16_multiplier; do run_modelsim.do
# No ACTEL_COUNT define here: use scripts/count_modelsim.py for gate counting.
onerror {quit -code 1}
if {![info exists TEST]} {set TEST tb_fp16_adder}
set allowed {tb_fp16_adder tb_fp16_multiplier tb_ping_pong_buffer tb_building_blocks tb_actel_cells}
if {[lsearch -exact $allowed $TEST] < 0} {error "Unknown TEST: $TEST"}
if {![file exists work]} {vlib work}
set stream [open rtl/files.f r]
set sources [split [read $stream] "\n"]
close $stream
foreach source $sources {
    if {[string trim $source] ne ""} {vlog -sv $source}
}
vlog -sv tb/ca1_ping_pong_reference.v
vlog -sv tb/$TEST.sv
vsim -voptargs=+acc work.$TEST
onfinish stop
log -r /*
add wave -r sim:/$TEST/*
run -all
