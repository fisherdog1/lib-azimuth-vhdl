# lib-azimuth-vhdl
[azimuth.tech](https://azimuth.tech/) RTL components.

Licensed under CERN-OHL-P-2.0, See License.txt

# Purpose
Because of the much higher labor qunatities involed, trust is at a premium in hardware sources. The goal of this library is to create components that require less effort to transfer that trust to a new user. The components in this repo are designed more around useful interfaces rather than functional features. Components should act as if they are the fundamental elements of a hypothetical more expressive hardware language. That is, they are simple enough to be easily reasoned about as individual parts of a larger design idea.

There is no particular application area in mind, these are just components that I would like to "write once, cry once". Like every Github repo it is an ongoing exercise in discovering better DevOps ideas.

# Usage
The sources in this repo are designed to be simulated with GHDL. I use Vivado to check that components are possible to synthesize. I have limited syntax to things that are recognized by both GHDL and Vivado, which is a non-trivial intersection.

Provided you have GHDL installed in your PATH, you can use the Make recipe all_libs to build a VHDL 2008 and 1993 library in the lib subdirectory. To use this library when invoking GHDL later, pass the lib directory via GHDL's -P option.
```
cd lib-azimuth-vhdl
make all_libs

cd ../my_project
ghdl compile -P ../lib-azimuth-vhdl/lib/ my_unit.vhd -e my_unit
```

To use my crappy unit test generator, you need Go on your PATH as well. Make sure you pulled submodules to obtain vhdl-dumb-preprocessor. Then use the build_vdp recipe to build it:
```
cd lib-azimuth-vhdl
make build_vdp
```

Run the all_unit_tests recipe to preprocess the testbenches and run them.
```
cd lib-azimuth-vhdl
make all_unit_tests
```

# Caveats
I do not generally check whether the synthesis results on any particular synthesis tool are correct.
None of the things listed in the following section are a strong promise of a future feature. Like virtually every source you find online, there is no warranty.

# Todo
* I would like to formally verify the more depended-upon components
* I would like to generate waveforms for documentation purposes automatically

# Other
I would greatly enjoy hearing any thoughts on this project as a whole.
