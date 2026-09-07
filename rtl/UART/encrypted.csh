
echo "Create Encrypted file $1p from $1"
vlib work
vmap work work
vlog $1 +protect=$1p
rm -rf work modelsim.ini
