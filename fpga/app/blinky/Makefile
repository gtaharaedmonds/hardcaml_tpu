blinky.exe: ../../../_build/default/fpga/app/blinky/blinky.exe

../../../_build/default/fpga/app/blinky/blinky.exe:
	dune build blinky.exe

output/blinky_top.v: ../../../_build/default/fpga/app/blinky/blinky.exe
	$< >$@

output/post_synth.dcp: synth.tcl output/blinky_top.v
	vivado -nojournal -mode batch -source synth.tcl -tclargs -log output/synth.log

output/post_place.dcp: place.tcl output/post_synth.dcp
	vivado -nojournal -mode batch -source place.tcl -log output/place.log

output/blinky_top.bit output/post_route.dcp: route.tcl output/post_place.dcp
	vivado -nojournal -mode batch -source route.tcl -log output/route.log
	rm -f usage_statistics_webtalk.html usage_statistics_webtalk.xml

clean:
	rm -rf output/*
