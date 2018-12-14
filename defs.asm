;;; Defintions for CP/M programs on the Z80 Second Processor.

        ;; CP/M Addresses

BOOT    equ     $0000
BDOS    equ     $0005
FCB1    equ     $005C
FCB2    equ     $006C
CMDTAIL equ     $0080        
CCPBASE equ     $D400        

        ;; BDOS Function Codes

PRSTR   equ     09h
FOPEN   equ     0fh        
FCLOSE  equ     10h        
FDELETE equ     13h
FREADSQ equ     14h        
FWRITSQ equ     15h
FCREATE equ     16h
SETDMA  equ     1ah

        ;; Acorn MOS Entry Points

OSFIND  equ     $FFCE
OSGBPB  equ     $FFD1
OSBPUT  equ     $FFD4
OSBGET  equ     $FFD7
OSARGS  equ     $FFDA
OSFILE  equ     $FFDD
OSRDCH  equ     $FFE0
OSASCI  equ     $FFE3        
OSNEWL  equ     $FFE7
OSWRCH  equ     $FFEE        
OSWORD  equ     $FFF1
OSBYTE  equ     $FFF4        
OSCLI   equ     $FFF7

;;; End.
