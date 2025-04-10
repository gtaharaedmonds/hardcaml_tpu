# .PHONY:  ../../../_build/default/hardcaml_nexys/examples/blinky/blinky.exe

blinky.exe: ../../../_build/default/hardcaml_nexys/examples/blinky/blinky.exe

../../../_build/default/hardcaml_nexys/examples/blinky/blinky.exe:
	dune build blinky.exe

hardcaml_nexys_top.v: ../../../_build/default/hardcaml_nexys/examples/blinky/blinky.exe
	$< >$@

outputs/post_synth.dcp: synth.tcl hardcaml_nexys_top.v
	vivado -nojournal -mode batch -source synth.tcl -tclargs -log outputs/synth.log

outputs/post_place.dcp: place.tcl outputs/post_synth.dcp
	vivado -nojournal -mode batch -source place.tcl -log outputs/place.log

outputs/hardcaml_nexys_top.bit outputs/post_route.dcp: route.tcl outputs/post_place.dcp
	vivado -nojournal -mode batch -source route.tcl -log outputs/route.log
	rm -f usage_statistics_webtalk.html usage_statistics_webtalk.xml

clean:
	rm -f outputs/*
