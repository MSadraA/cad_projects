set output_dir "../test_results/test_batch19_lw_jalr"

file mkdir $output_dir

mem save -outfile "$output_dir/register_file.txt" -format mti -dataradix hex /TopPipeline_tb/shadow_registerFile

mem save -outfile "$output_dir/data_memory.txt" -format mti -dataradix hex /TopPipeline_tb/shadow_dmem

mem save -outfile "$output_dir/instruction_memory.txt" -format mti -dataradix hex /TopPipeline_tb/shadow_imem

puts "Memory dump completed."