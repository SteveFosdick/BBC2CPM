all: bbc2cpm.hex cpm2bbc.hex adump.hex

%.hex: %.asm
	tpasm -o intel $@ -l $*.lis $<

bbc2cpm.hex: bbc2cpm.asm defs.asm prfcb.asm ScanFilename.asm

cpm2bbc.hex: cpm2bbc.asm defs.asm prfcb.asm

adump.hex: adump.asm defs.asm prfcb.asm
