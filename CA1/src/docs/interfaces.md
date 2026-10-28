# رابط‌های تولیدشده از RTL

این فایل را با `python scripts/design_docs.py` به‌روز کنید؛ مبنا خود RTL است.

## fcnn_accumulator_bank

فایل: `rtl/fcnn_accumulator_bank.v`؛ تعداد نمونه در Top: 1.

| پورت | جهت | عرض اعلام‌شده |
|---|---|---|
| `clk` | input | `1 bit` |
| `rst` | input | `1 bit` |
| `run_init` | input | `1 bit` |
| `layer_sel` | input | `1 bit` |
| `product_valid` | input | `1 bit` |
| `product_ready` | output | `1 bit` |
| `product_data` | input | `[15:0]` |
| `product_dest` | input | `[DEST_W-1:0]` |
| `product_last` | input | `1 bit` |
| `bias_neuron` | output | `[H_W-1:0]` |
| `fc1_bias` | input | `[15:0]` |
| `fc2_biases` | input | `[16*N_OUTPUTS-1:0]` |
| `add_a` | output | `[15:0]` |
| `add_b` | output | `[15:0]` |
| `add_result` | input | `[15:0]` |
| `add_commit` | output | `1 bit` |
| `fc1_final_valid` | output | `1 bit` |
| `fc1_final_value` | output | `[15:0]` |
| `fc1_final_idx` | output | `[H_W-1:0]` |
| `fc2_all_committed` | output | `1 bit` |
| `fc2_results` | output | `[16*N_OUTPUTS-1:0]` |

## fcnn_activation_regfile

فایل: `rtl/fcnn_activation_regfile.v`؛ تعداد نمونه در Top: 1.

| پورت | جهت | عرض اعلام‌شده |
|---|---|---|
| `clk` | input | `1 bit` |
| `rst` | input | `1 bit` |
| `run_init` | input | `1 bit` |
| `hidden_wr_en` | input | `1 bit` |
| `hidden_wr_idx` | input | `[H_W-1:0]` |
| `hidden_wr_data` | input | `[15:0]` |
| `hidden_rd_idx` | input | `[H_W-1:0]` |
| `hidden_rd_data` | output | `[15:0]` |
| `hidden_all_valid` | output | `1 bit` |
| `final_wr_en` | input | `1 bit` |
| `final_wr_data` | input | `[16*N_OUTPUTS-1:0]` |
| `final_ready` | output | `1 bit` |
| `logits` | output | `[16*N_OUTPUTS-1:0]` |

## fcnn_address_generator

فایل: `rtl/fcnn_address_generator.v`؛ تعداد نمونه در Top: 1.

| پورت | جهت | عرض اعلام‌شده |
|---|---|---|
| `clk` | input | `1 bit` |
| `rst` | input | `1 bit` |
| `run_init` | input | `1 bit` |
| `request_layer` | input | `1 bit` |
| `advance_row` | input | `1 bit` |
| `fc1_neuron` | output | `[H_W-1:0]` |
| `fc1_row` | output | `[R1_W-1:0]` |
| `fc2_row` | output | `[R2_W-1:0]` |
| `weight_addr` | output | `[ADDR_W-1:0]` |
| `input_addr` | output | `[R1_W-1:0]` |
| `weight_meta` | output | `[META_W-1:0]` |
| `input_meta` | output | `[META_W-1:0]` |

## fcnn_argmax

فایل: `rtl/fcnn_argmax.v`؛ تعداد نمونه در Top: 1.

| پورت | جهت | عرض اعلام‌شده |
|---|---|---|
| `logits` | input | `[16*N_OUTPUTS-1:0]` |
| `logits_valid` | input | `1 bit` |
| `predicted_digit` | output | `[INDEX_W-1:0]` |
| `argmax_valid` | output | `1 bit` |

## fcnn_bias_rom

فایل: `rtl/fcnn_bias_rom.v`؛ تعداد نمونه در Top: 1.

| پورت | جهت | عرض اعلام‌شده |
|---|---|---|
| `fc1_neuron` | input | `[H_W-1:0]` |
| `fc1_bias` | output | `[15:0]` |
| `fc2_biases` | output | `[16*N_OUTPUTS-1:0]` |

## fcnn_controller

فایل: `rtl/fcnn_controller.v`؛ تعداد نمونه در Top: 1.

| پورت | جهت | عرض اعلام‌شده |
|---|---|---|
| `clk` | input | `1 bit` |
| `rst` | input | `1 bit` |
| `start` | input | `1 bit` |
| `fc1_finished` | input | `1 bit` |
| `fc2_finished` | input | `1 bit` |
| `run_init` | output | `1 bit` |
| `fc1_active` | output | `1 bit` |
| `fc2_active` | output | `1 bit` |
| `busy` | output | `1 bit` |
| `done` | output | `1 bit` |

## fcnn_datapath

فایل: `rtl/fcnn_datapath.v`؛ تعداد نمونه در Top: 1.

| پورت | جهت | عرض اعلام‌شده |
|---|---|---|
| `clk` | input | `1 bit` |
| `rst` | input | `1 bit` |
| `run_init` | input | `1 bit` |
| `fc1_active` | input | `1 bit` |
| `fc2_active` | input | `1 bit` |
| `fc1_finished` | output | `1 bit` |
| `fc2_finished` | output | `1 bit` |
| `logits` | output | `[16*N_OUTPUTS-1:0]` |
| `predicted_digit` | output | `[INDEX_W-1:0]` |

## fcnn_fp16_adder

فایل: `rtl/fcnn_fp16_adder.v`؛ تعداد نمونه در Top: 1.

| پورت | جهت | عرض اعلام‌شده |
|---|---|---|
| `a` | input | `[15:0]` |
| `b` | input | `[15:0]` |
| `result` | output | `[15:0]` |

## fcnn_fp16_multiplier

فایل: `rtl/fcnn_fp16_multiplier.v`؛ تعداد نمونه در Top: 1.

| پورت | جهت | عرض اعلام‌شده |
|---|---|---|
| `a` | input | `[15:0]` |
| `b` | input | `[15:0]` |
| `result` | output | `[15:0]` |

## fcnn_local_scheduler

فایل: `rtl/fcnn_local_scheduler.v`؛ تعداد نمونه در Top: 1.

| پورت | جهت | عرض اعلام‌شده |
|---|---|---|
| `clk` | input | `1 bit` |
| `rst` | input | `1 bit` |
| `run_init` | input | `1 bit` |
| `fc1_active` | input | `1 bit` |
| `fc2_active` | input | `1 bit` |
| `request_neuron` | input | `[H_W-1:0]` |
| `request_fc1_row` | input | `[R1_W-1:0]` |
| `request_fc2_row` | input | `[R2_W-1:0]` |
| `weight_available` | input | `1 bit` |
| `input_available` | input | `1 bit` |
| `compute_layer` | input | `1 bit` |
| `compute_row` | input | `[ROW_W-1:0]` |
| `product_ready` | input | `1 bit` |
| `pp_wr_ready` | input | `1 bit` |
| `term_last` | input | `1 bit` |
| `hidden_all_valid` | input | `1 bit` |
| `activation_last_use` | input | `1 bit` |
| `fc2_all_committed` | input | `1 bit` |
| `final_ready` | input | `1 bit` |
| `argmax_valid` | input | `1 bit` |
| `request_layer` | output | `1 bit` |
| `weight_req` | output | `1 bit` |
| `input_req` | output | `1 bit` |
| `consume_weight_row` | output | `1 bit` |
| `consume_input_row` | output | `1 bit` |
| `lane_idx` | output | `[LANE_W-1:0]` |
| `mul_issue` | output | `1 bit` |
| `group_last` | output | `1 bit` |
| `rf_final_we` | output | `1 bit` |
| `fc1_finished` | output | `1 bit` |
| `fc2_finished` | output | `1 bit` |

## fcnn_operand_router

فایل: `rtl/fcnn_operand_router.v`؛ تعداد نمونه در Top: 1.

| پورت | جهت | عرض اعلام‌شده |
|---|---|---|
| `weight_row` | input | `[16*LANES-1:0]` |
| `input_row` | input | `[16*LANES-1:0]` |
| `weight_meta` | input | `[META_W-1:0]` |
| `input_meta` | input | `[META_W-1:0]` |
| `lane_idx` | input | `[LANE_W-1:0]` |
| `hidden_value` | input | `[15:0]` |
| `hidden_rd_idx` | output | `[H_W-1:0]` |
| `mul_weight` | output | `[15:0]` |
| `mul_input` | output | `[15:0]` |
| `term_valid` | output | `1 bit` |
| `term_dest` | output | `[DEST_W-1:0]` |
| `term_last` | output | `1 bit` |
| `activation_last_term` | output | `1 bit` |

## fcnn_ping_pong_buffer

فایل: `rtl/fcnn_ping_pong_buffer.v`؛ تعداد نمونه در Top: 1.

| پورت | جهت | عرض اعلام‌شده |
|---|---|---|
| `clk` | input | `1 bit` |
| `rst` | input | `1 bit` |
| `wr_valid` | input | `1 bit` |
| `wr_ready` | output | `1 bit` |
| `wr_data` | input | `[15:0]` |
| `wr_dest` | input | `[DEST_W-1:0]` |
| `wr_last` | input | `1 bit` |
| `wr_group_last` | input | `1 bit` |
| `rd_valid` | output | `1 bit` |
| `rd_ready` | input | `1 bit` |
| `rd_data` | output | `[15:0]` |
| `rd_dest` | output | `[DEST_W-1:0]` |
| `rd_last` | output | `1 bit` |
| `bank_full` | output | `[1:0]` |
| `bank_empty` | output | `[1:0]` |
| `bank_select` | output | `1 bit` |

## fcnn_product_register

فایل: `rtl/fcnn_product_register.v`؛ تعداد نمونه در Top: 1.

| پورت | جهت | عرض اعلام‌شده |
|---|---|---|
| `clk` | input | `1 bit` |
| `rst` | input | `1 bit` |
| `in_valid` | input | `1 bit` |
| `in_ready` | output | `1 bit` |
| `in_data` | input | `[15:0]` |
| `in_dest` | input | `[DEST_W-1:0]` |
| `in_last` | input | `1 bit` |
| `in_group_last` | input | `1 bit` |
| `out_valid` | output | `1 bit` |
| `out_ready` | input | `1 bit` |
| `out_data` | output | `[15:0]` |
| `out_dest` | output | `[DEST_W-1:0]` |
| `out_last` | output | `1 bit` |
| `out_group_last` | output | `1 bit` |

## fcnn_relu_fp16

فایل: `rtl/fcnn_relu_fp16.v`؛ تعداد نمونه در Top: 1.

| پورت | جهت | عرض اعلام‌شده |
|---|---|---|
| `x` | input | `[15:0]` |
| `y` | output | `[15:0]` |

## fcnn_row_sram

فایل: `rtl/fcnn_row_sram.v`؛ تعداد نمونه در Top: 2.

| پورت | جهت | عرض اعلام‌شده |
|---|---|---|
| `clk` | input | `1 bit` |
| `rst` | input | `1 bit` |
| `req_valid` | input | `1 bit` |
| `req_addr` | input | `[ADDR_W-1:0]` |
| `req_meta` | input | `[META_W-1:0]` |
| `row_valid` | output | `1 bit` |
| `row_data` | output | `[16*LANES-1:0]` |
| `row_meta` | output | `[META_W-1:0]` |

## fcnn_row_stage

فایل: `rtl/fcnn_row_stage.v`؛ تعداد نمونه در Top: 2.

| پورت | جهت | عرض اعلام‌شده |
|---|---|---|
| `clk` | input | `1 bit` |
| `rst` | input | `1 bit` |
| `in_valid` | input | `1 bit` |
| `in_data` | input | `[16*LANES-1:0]` |
| `in_meta` | input | `[META_W-1:0]` |
| `consume_row` | input | `1 bit` |
| `can_accept` | output | `1 bit` |
| `stored_valid` | output | `1 bit` |
| `stored_data` | output | `[16*LANES-1:0]` |
| `stored_meta` | output | `[META_W-1:0]` |

## fcnn_top

فایل: `rtl/fcnn_top.v`؛ تعداد نمونه در Top: 1.

| پورت | جهت | عرض اعلام‌شده |
|---|---|---|
| `clk` | input | `1 bit` |
| `rst` | input | `1 bit` |
| `start` | input | `1 bit` |
| `busy` | output | `1 bit` |
| `done` | output | `1 bit` |
| `logits` | output | `[16*N_OUTPUTS-1:0]` |
| `predicted_digit` | output | `[((N_OUTPUTS>1)?$clog2(N_OUTPUTS):1)-1:0]` |

