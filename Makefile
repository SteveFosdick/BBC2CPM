all: bbc2cpm.hex cpm2bbc.hex

bbc2cpm.hex: bbc2cpm.asm
	tpasm -o intel bbc2cpm.hex -l bbc2cpm.lis bbc2cpm.asm

cpm2bbc.hex: cpm2bbc.asm
	tpasm -o intel cpm2bbc.hex -l cpm2bbc.lis cpm2bbc.asm
