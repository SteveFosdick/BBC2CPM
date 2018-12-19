all: bbc2cpm.hex cpm2bbc.hex adump.hex

bbc2cpm.hex: bbc2cpm.asm defs.asm prfcb.asm
	tpasm -o intel bbc2cpm.hex -l bbc2cpm.lis bbc2cpm.asm

cpm2bbc.hex: cpm2bbc.asm defs.asm prfcb.asm
	tpasm -o intel cpm2bbc.hex -l cpm2bbc.lis cpm2bbc.asm

adump.hex: adump.asm defs.asm prfcb.asm
	tpasm -o intel adump.hex -l adump.lis adump.asm
