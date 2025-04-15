set output_dir "output/"

open_checkpoint $output_dir/post_synth.dcp

opt_design
place_design
phys_opt_design

write_checkpoint -force $output_dir/post_place
report_timing_summary -file $output_dir/post_place_timing_summary.rpt
