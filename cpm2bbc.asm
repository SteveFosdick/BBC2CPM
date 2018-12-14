;;; CPM2BBC
;;;
;;; This is a program specific to the Acorn Z80 processor for the
;;; BBC Microcomputer System which copies a file from the CP/M filing
;;; system to the current Acorn filing system (e.g. DFS).
;;;
;;; Copyright 2018 Steve Fosdick.
;;; This is free software distributable under the GNU General Public
;;; License version 3 or, at your option, a later version.

        .processor z80
        .include   "defs.asm"
        org     $100

        ;; Parse the command line.

        ld      hl,CMDTAIL      ; Get the length of the command line tail.
        ld      a,(hl)
        or      a               ; Is the command line empy?
        jr      z,usage
        ld      b,a             ; Save the lenth for later.
        ld      a,(FCB2+$01)    ; Look for a ready-parsed 1st filename.  A
        cp      ' '             ; space means no 1st filename given.
        jr      z,usage
        call    skpspc          ; Skip initial spaces.
fnlp1:  ld      a,(hl)          ; Skip over the 1st filename.
        cp      ' '
        jr      z,endnm1
        cp      $09
        jr      z,endnm1
        inc     hl
        djnz    fnlp1           ; If B=0, 2nd filename is missing.
usage:  ld      de,ustr
msgout: ld      c,PRSTR
        jp      BDOS
endnm1: call    skpspc          ; Skip spaces between filenames.
notspc: ld      de,fndest       ; Copy filename of the 2nd file to immediately
        ld      (ofblk),de      ; after the program code as CP/M will clobber
fnlp2:  ld      a,(hl)          ; it if left at 0080h
        cp      ' '
        jr      z,endnm2
        cp      $09
        jr      z,endnm2
        ld      (de),a
        inc     hl
        inc     de
        djnz    fnlp2
endnm2: ld      a,$0D           ; Terminate the filename with CR.
        ld      (de),a
        inc     de              ; Save end of filename address as start of
        ld      (dbuff),de      ; data buffer.

        ;; Read the first buffer full from the source file.

        xor     a               ; Open the CP/M (1st) file with the current
        ld      (FCB1+$20),a    ; record number set to zero.
        ld      c,FOPEN
        ld      de,FCB1
        call    BDOS
        cp      $FF
        jr      nz,cpmfnd
        ld      de,cpmnf
        jr      msgout
cpmfnd: ld      bc,(dbuff)      ; Find out how much RAM is available to
        ld      hl,CCPBASE      ; use as a buffer.
        and     a               ; Clear carry flag.
        sbc     hl,bc
        xor     a
        add     hl,hl           ; Multiply by 2
        adc     a,a             ; then capture carry.
        ld      b,h             ; so B contains a number of 128 byte CP/M
        ld      c,a             ; records that can be read and C is one if
        xor     a               ; 256 extra records could be read.
        ld      (maxrec),bc
        call    rdcpm           ; Read CP/M records into buffer.
        jr      z,bigfil        ; No EOF during the read so big file way.

        ;; Copy strategy for a file which fit completely in the buffer.

        push    de
        xor     a               ; Clear the OSFILE control block
        ld      b,16
        ld      hl,ofblk+$02
clrlp1: ld      (hl),a
        inc     hl
        djnz    clrlp1
        ld      hl,(dbuff)      ; Set up the addresses in the control
        ld      (ofblk+$0A),hl  ; block.
        pop     de
        ld      (ofblk+$0E),de
        xor     a               ; Use OSFILE to write the BBC file.
        ld      hl,ofblk
        jp      OSFILE

        ;; Copy strategy when the file needs multiple buffer fills.

bigfil: push    af
        push    de
        ld      a,$80           ; Open the BBC (2nd) file for writing.
        ld      hl,fndest
        call    OSFIND
        or      a
        jr      nz,bbcfnd
        pop     de
        ld      de,bbcnf
        jp      msgout
bbcfnd: ld      hl,pbblk        ; Set up the OSGBPB parameter block.
        ld      (hl),a
        xor     a
        ld      b,$0C
clrlp2: inc     hl
        ld      (hl),a
        djnz    clrlp2
        pop     hl              ; Get back last address written.
        ld      bc,(dbuff)
        and     a
        sbc     hl,bc           ; Calculate the length.
        ld      (pbblk+$01),bc
        ld      (pbblk+$05),hl
        ld      a,$02
        call    OSGBPB
        jr      c,bbcwre        ; Write error.
        pop     af
        jr      nz,done
        ld      bc,(maxrec)
        call    rdcpm
        jr      bigfil
done:   ld      a,(pbblk)       ; Close the BBC file.
        ld      h,a
        xor     a
        jp      OSFIND
bbcwre: ld      de,bbcwe
        jp      msgout

        ;; Subroutine to skip over spaces and TABs in the CP/M command
        ;; line where the number of characters remaining is in B.  If
        ;; no non-space characters were found before the end of the line
        ;; the Z flag is set, otherwise clear.

skpspc: inc     hl
        ld      a,(hl)
        cp      ' '
        jp      z,isspc
        cp      $09
        ret     nz
isspc:  djnz    skpspc
        ret

        ;; Subroutine to read records from the CP/M file into the memory
        ;; buffer.  On entry, BC contains the maximum number of records to
        ;; read but with the two halves the opposite way round to normal,
        ;; i.e. B is LSB and C is MSB (but C may only be 0 or 1)

rdcpm:  ld      de,(dbuff)
rdloop: push    bc
        push    de
        ld      c,SETDMA        ; Set the "DMA" address, i.e. where the
        call    BDOS            ; data is to be read to.
        ld      c,FREADSQ       ; Read sequential record.
        call    BDOS
        or      a
        ret     nz              ; End of file (probably).
        pop     de
        ld      hl,$80          ; Move memory destination up by one
        add     hl,de           ; CP/M record.
        ld      d,h
        ld      e,l
        pop     bc
        djnz    rdloop          ; Loop for next record.
        ld      a,c             ; Another 256 records?
        ld      c,b
        or      a
        jr      nz,rdloop
        ret

        ;; Messages.

ustr:   db      "Usage: cpm2bbc <cpm-file> <bbc-file>",$0D,$0A,'$'
cpmnf   db      "CP/M file not found",$0D,$0A,'$'
bbcnf   db      "Error creating BBC file",$0D,$0A,'$'
bbcwe   db      "Write error on BBC file",$0D,$0A,'$'
data:

        ;; Unitialised data section, i.e. workspace.

.segu   "data"
        .org    data
dbuff:  dw      0
maxrec  dw      0        
ofblk   ds      18
pbblk   equ     ofblk+2
fndest: 
