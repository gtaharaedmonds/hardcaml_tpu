demo_system.exe: ../../../_build/default/fpga/app/demo_system/demo_system.exe

../../../_build/default/fpga/app/demo_system/demo_system.exe:
	dune build demo_system.exe

output/demo_system_top.v: ../../../_build/default/fpga/app/demo_system/demo_system.exe
	mkdir -p output
	$< >$@

output/post_synth.dcp: synth.tcl output/demo_system_top.v
	vivado -nojournal -mode batch -source synth.tcl -tclargs -log output/synth.log

output/post_place.dcp: place.tcl output/post_synth.dcp
	vivado -nojournal -mode batch -source place.tcl -log output/place.log

output/demo_system_top.bit output/post_route.dcp: route.tcl output/post_place.dcp
	vivado -nojournal -mode batch -source route.tcl -log output/route.log
	rm -f usage_statistics_webtalk.html usage_statistics_webtalk.xml

clean:
	rm -rf output/*
