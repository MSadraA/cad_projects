# Deliberately selected signals: no thousands-word SRAM dump in the Wave window.
# Paths are checked by scripts/audit.py against the current RTL hierarchy.
view wave
catch {delete wave *}
add wave -noupdate -group {01 Top} sim:/tb_fcnn/clk sim:/tb_fcnn/rst sim:/tb_fcnn/start sim:/tb_fcnn/busy sim:/tb_fcnn/done
add wave -noupdate -group {01 Top} -radix unsigned sim:/tb_fcnn/predicted_digit
add wave -noupdate -group {01 Top} -radix hexadecimal sim:/tb_fcnn/logits

add wave -noupdate -group {02 Controller} -radix unsigned sim:/tb_fcnn/dut/controller_inst/state sim:/tb_fcnn/dut/controller_inst/next_state
add wave -noupdate -group {02 Controller} sim:/tb_fcnn/dut/run_init sim:/tb_fcnn/dut/fc1_active sim:/tb_fcnn/dut/fc2_active sim:/tb_fcnn/dut/fc1_finished sim:/tb_fcnn/dut/fc2_finished

add wave -noupdate -group {03 SRAM and rows} sim:/tb_fcnn/dut/datapath_inst/request_layer sim:/tb_fcnn/dut/datapath_inst/compute_layer sim:/tb_fcnn/dut/datapath_inst/weight_req sim:/tb_fcnn/dut/datapath_inst/input_req
add wave -noupdate -group {03 SRAM and rows} -radix unsigned sim:/tb_fcnn/dut/datapath_inst/weight_addr sim:/tb_fcnn/dut/datapath_inst/input_addr sim:/tb_fcnn/dut/datapath_inst/compute_row
add wave -noupdate -group {03 SRAM and rows} sim:/tb_fcnn/dut/datapath_inst/weight_sram_valid sim:/tb_fcnn/dut/datapath_inst/input_sram_valid sim:/tb_fcnn/dut/datapath_inst/weight_available sim:/tb_fcnn/dut/datapath_inst/input_available sim:/tb_fcnn/dut/datapath_inst/consume_weight_row sim:/tb_fcnn/dut/datapath_inst/consume_input_row
add wave -noupdate -group {03 SRAM and rows} -radix hexadecimal sim:/tb_fcnn/dut/datapath_inst/weight_stage_data sim:/tb_fcnn/dut/datapath_inst/input_stage_data

add wave -noupdate -group {04 Scheduler} -radix unsigned sim:/tb_fcnn/dut/datapath_inst/scheduler_inst/request_wait sim:/tb_fcnn/dut/datapath_inst/lane_idx
add wave -noupdate -group {04 Scheduler} sim:/tb_fcnn/dut/datapath_inst/scheduler_inst/bias_issue_gap sim:/tb_fcnn/dut/datapath_inst/scheduler_inst/hidden_reads_done

add wave -noupdate -group {05 Multiplier} sim:/tb_fcnn/dut/datapath_inst/mul_issue sim:/tb_fcnn/dut/datapath_inst/term_valid sim:/tb_fcnn/dut/datapath_inst/term_last sim:/tb_fcnn/dut/datapath_inst/group_last
add wave -noupdate -group {05 Multiplier} -radix unsigned sim:/tb_fcnn/dut/datapath_inst/term_dest
add wave -noupdate -group {05 Multiplier} -radix hexadecimal sim:/tb_fcnn/dut/datapath_inst/mul_weight sim:/tb_fcnn/dut/datapath_inst/mul_input sim:/tb_fcnn/dut/datapath_inst/mul_result

add wave -noupdate -group {06 Ping-Pong} sim:/tb_fcnn/dut/datapath_inst/pp_wr_valid sim:/tb_fcnn/dut/datapath_inst/pp_wr_ready sim:/tb_fcnn/dut/datapath_inst/pp_rd_valid sim:/tb_fcnn/dut/datapath_inst/pp_rd_ready sim:/tb_fcnn/dut/datapath_inst/pp_wr_last sim:/tb_fcnn/dut/datapath_inst/pp_rd_last
add wave -noupdate -group {06 Ping-Pong} -radix hexadecimal sim:/tb_fcnn/dut/datapath_inst/pp_wr_data sim:/tb_fcnn/dut/datapath_inst/pp_rd_data
add wave -noupdate -group {06 Ping-Pong} -radix unsigned sim:/tb_fcnn/dut/datapath_inst/pp_wr_dest sim:/tb_fcnn/dut/datapath_inst/pp_rd_dest sim:/tb_fcnn/dut/datapath_inst/ping_pong_inst/count0 sim:/tb_fcnn/dut/datapath_inst/ping_pong_inst/count1
add wave -noupdate -group {06 Ping-Pong} sim:/tb_fcnn/dut/datapath_inst/ping_pong_inst/write_bank sim:/tb_fcnn/dut/datapath_inst/ping_pong_inst/read_bank sim:/tb_fcnn/dut/datapath_inst/ping_pong_inst/sealed0 sim:/tb_fcnn/dut/datapath_inst/ping_pong_inst/sealed1

add wave -noupdate -group {07 Accumulators} sim:/tb_fcnn/dut/datapath_inst/add_commit sim:/tb_fcnn/dut/datapath_inst/accumulator_inst/bias_pending
add wave -noupdate -group {07 Accumulators} -radix unsigned sim:/tb_fcnn/dut/datapath_inst/accumulator_inst/pending_dest
add wave -noupdate -group {07 Accumulators} -radix hexadecimal sim:/tb_fcnn/dut/datapath_inst/add_a sim:/tb_fcnn/dut/datapath_inst/add_b sim:/tb_fcnn/dut/datapath_inst/add_result sim:/tb_fcnn/dut/datapath_inst/accumulator_inst/fc1_acc sim:/tb_fcnn/dut/datapath_inst/accumulator_inst/fc2_acc
add wave -noupdate -group {07 Accumulators} sim:/tb_fcnn/dut/datapath_inst/fc1_final_valid sim:/tb_fcnn/dut/datapath_inst/fc2_all_committed

add wave -noupdate -group {08 ReLU and RF} -radix hexadecimal sim:/tb_fcnn/dut/datapath_inst/fc1_final_value sim:/tb_fcnn/dut/datapath_inst/relu_out sim:/tb_fcnn/dut/datapath_inst/hidden_rd_data sim:/tb_fcnn/dut/datapath_inst/regfile_inst/rf_mem
add wave -noupdate -group {08 ReLU and RF} -radix unsigned sim:/tb_fcnn/dut/datapath_inst/fc1_final_idx sim:/tb_fcnn/dut/datapath_inst/hidden_rd_idx
add wave -noupdate -group {08 ReLU and RF} sim:/tb_fcnn/dut/datapath_inst/hidden_all_valid sim:/tb_fcnn/dut/datapath_inst/rf_final_we sim:/tb_fcnn/dut/datapath_inst/final_ready sim:/tb_fcnn/dut/datapath_inst/argmax_valid

add wave -noupdate -group {09 Testbench} sim:/tb_fcnn/check_outputs sim:/tb_fcnn/simulation_finished
add wave -noupdate -group {09 Testbench} -radix unsigned sim:/tb_fcnn/cycle sim:/tb_fcnn/issued sim:/tb_fcnn/products_read sim:/tb_fcnn/adds sim:/tb_fcnn/weight_requests sim:/tb_fcnn/input_requests sim:/tb_fcnn/completions sim:/tb_fcnn/failures
configure wave -namecolwidth 300
configure wave -valuecolwidth 120
configure wave -timelineunits ns
update
