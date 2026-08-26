vlib work
vmap work work

# Compile all Control Unit files
vlog -sv control_unit/*.sv

# Compile all Core Module files
vlog -sv core_modules/*.sv

# Compile testbench files
vlog -sv test.sv


echo "Compilation completed successfully!"