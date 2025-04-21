tpu_app.exe: ../../../_build/default/fpga/app/tpu/tpu_app.exe

../../../_build/default/fpga/app/tpu/tpu_app.exe:
	dune build tpu_app.exe

output/tpu_top.v: ../../../_build/default/fpga/app/tpu/tpu_app.exe
	mkdir -p output
	$< >$@

output/post_synth.dcp: synth.tcl output/tpu_top.v
	vivado -nojournal -mode batch -source synth.tcl -tclargs -log output/synth.log

output/post_place.dcp: place.tcl output/post_synth.dcp
	vivado -nojournal -mode batch -source place.tcl -log output/place.log

output/tpu_top.bit output/post_route.dcp: route.tcl output/post_place.dcp
	vivado -nojournal -mode batch -source route.tcl -log output/route.log
	rm -f usage_statistics_webtalk.html usage_statistics_webtalk.xml

clean:
	rm -rf output/*
