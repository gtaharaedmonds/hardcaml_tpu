# .PHONY:  ../../../_build/default/hardcaml_nexys/examples/blinky/blinky.exe

blinky.exe: ../../../_build/default/hardcaml_nexys/examples/blinky/blinky.exe

../../../_build/default/hardcaml_nexys/examples/blinky/blinky.exe:
	dune build blinky.exe

hardcaml_nexys_top.v: ../../../_build/default/hardcaml_nexys/examples/blinky/blinky.exe
	$< >$@

output/post_synth.dcp: synth.tcl hardcaml_nexys_top.v
	vivado -nojournal -mode batch -source synth.tcl -tclargs -log output/synth.log

output/post_place.dcp: place.tcl output/post_synth.dcp
	vivado -nojournal -mode batch -source place.tcl -log output/place.log

output/hardcaml_nexys_top.bit output/post_route.dcp: route.tcl output/post_place.dcp
	vivado -nojournal -mode batch -source route.tcl -log output/route.log
	rm -f usage_statistics_webtalk.html usage_statistics_webtalk.xml

clean:
	rm -f output/*
