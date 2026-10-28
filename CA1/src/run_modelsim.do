# Run inside the ModelSim/Questa GUI: do run_modelsim.do
# Edit ONLY verification/tb_fcnn.v's parameter block for DUT/input/scenario settings.
# Optional: set FCNN_AUTORUN 0 before this command to stop after loading at t=0.
# This script uses Tcl/ModelSim commands only; Python is not invoked.
onerror {abort}

# ModelSim DO macros may return an empty [info script], unlike Tcl source.
# The supported DO entry point is therefore the project root. Tcl source with
# an absolute filename also works and can resolve the root from that filename.
set fcnn_root [pwd]
set fcnn_script [info script]
if {$fcnn_script ne "" && [file tail $fcnn_script] eq "run_modelsim.do"} {
    set fcnn_root [file dirname [file normalize $fcnn_script]]
}
if {![file isfile [file join $fcnn_root rtl files.f]]} {
    error "Change directory to FCNN_Clean (the folder containing rtl and run_modelsim.do), then do run_modelsim.do."
}
if {![info exists FCNN_AUTORUN]} {set FCNN_AUTORUN 1}
if {$FCNN_AUTORUN ni {0 1}} {error "FCNN_AUTORUN must be 0 or 1"}

# Unload the previous simulation so edited TB parameters and memories reload.
catch {quit -sim -f}
cd $fcnn_root
set fcnn_build [file join $fcnn_root build modelsim_gui]
file mkdir $fcnn_build
transcript file [file join $fcnn_build transcript.log]
set fcnn_ini [file join $fcnn_build modelsim.ini]
if {![file isfile $fcnn_ini]} {
    # Copy the tool's default INI into this build directory. All mapping and
    # compile/load commands explicitly use it; other projects' mappings stay intact.
    cd $fcnn_build
    set fcnn_ini_error [catch {vmap -c} fcnn_ini_message]
    cd $fcnn_root
    if {$fcnn_ini_error} {error $fcnn_ini_message}
}
set fcnn_library [file join $fcnn_build work]
if {![file isdirectory $fcnn_library]} {vlib $fcnn_library}
vmap -modelsimini $fcnn_ini fcnn_gui_work $fcnn_library
vlog -modelsimini $fcnn_ini -work fcnn_gui_work -f rtl/files.f verification/tb_fcnn.v

# +acc retains internal state for datapath/controller inspection.
# The TB stops its clock after reporting, so run -all completes without unloading.
vsim -modelsimini $fcnn_ini -onfinish stop -voptargs=+acc -wlf [file join $fcnn_build fcnn.wlf] fcnn_gui_work.tb_fcnn
log -r sim:/tb_fcnn/*
do [file join $fcnn_root modelsim wave.do]
puts "FCNN: configuration comes from verification/tb_fcnn.v."
if {$FCNN_AUTORUN} {
    run -all
    wave zoom full
} else {
    puts "FCNN: loaded at time zero. Use run 200 ns, run -all, or the GUI Run controls."
}
puts "FCNN: after editing the TB or any .mem file, run do run_modelsim.do again."
