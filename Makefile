all: bbc2cpm.com cpm2bbc.com adump.com

%.hex: %.asm
	tpasm -o intel $@ -l $*.lis $<

%.com: %.hex
	objcopy -I ihex -O binary $< $@

bbc2cpm.hex: bbc2cpm.asm defs.asm prfcb.asm ScanFilename.asm

cpm2bbc.hex: cpm2bbc.asm defs.asm prfcb.asm

adump.hex: adump.asm defs.asm prfcb.asm
