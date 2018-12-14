;;; BBC2CPM
;;;
;;; This is a program specific to the Acorn Z80 processor for the
;;; BBC Microcomputer System which copies a file from the current
;;; Acorn filing system (e.g. DFS) to the CP/M filing system.
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
        ld      a,(FCB2+$01)    ; Look for a ready-parsed 2nd filename.  A
        cp      ' '             ; space means no 2nd filename given.
        jr      z,usage
spclp:  inc     hl              ; Back to the command line tail, skip any
        ld      a,(hl)          ; initial spaces.
        cp      ' '
        jr      z,isspc
        cp      $09
        jr      nz,notspc
isspc:  djnz    spclp           ; If we get to the end of the command line the
usage:  ld      de,ustr         ; 1st filename must be missing.
msgout: ld      c,PRSTR
        jp      BDOS
notspc: ld      de,fndest       ; Copy filename of the 1st file to immediately
        ld      (ofblk),de      ; after the program code as CP/M will clobber
nsplp:  ld      a,(hl)          ; it if left at 0080h
        cp      ' '
        jp      z,endnam
        cp      $09
        jp      z,endnam
        ld      (de),a
        inc     hl
        inc     de
        djnz    nsplp
endnam: ld      a,$0D           ; Terminate the filename with CR.
        ld      (de),a
        inc     de              ; Save end of filename address as start of
        ld      (dbuff),de      ; data buffer.

        ;; Check if the source (BBC) file fits in the available buffer.

        ld      hl,ofblk        ; Issue an OSFILE call for that filename to
        ld      a,$05           ; find how big the corresponding file is.
        call    OSFILE
        cp      $01             ; Was a file found?
        jr      z,found
        cp      $02             ; Was a directory found?
        jr      z,gotdir
        ld      de,notfnd
        jp      msgout
gotdir: ld      de,dirmsg
        jr      msgout
found:  ld      c,FDELETE       ; Delete any existing file in the way of
        ld      de,FCB2         ; the output file.
        call    BDOS
        ld      c,FCREATE       ; Create a new output file.
        ld      de,FCB2
        call    BDOS
        cp      $FF             ; Check if succesful.
        jp      nz,isopen
        ld      de,ocmsg
        jr      msgout
isopen: xor     a               ; Start writing at record zero.
        ld      (FCB2+$20),a
        ld      hl,ofblk+$0C    ; Back to the Acorn file, if either of the
        ld      a,(hl)          ; most significant two bytes of the length is
        inc     hl              ; set then this is too big to do in one go.
        or      (hl)
        jp      nz,bigfil
        ld      bc,(dbuff)      ; Otherwise find out how much RAM is available
        ld      hl,CCPBASE
        and     a
        sbc     hl,bc
        ld      bc,(ofblk+$0A)  ; and compare with file size to see if the
        sbc     hl,bc           ; file will fit in RAM.
        jp      c,bigfil

        ;; This is the copy strategy when the whole files fits in buffer.

        xor     a               ; Clear everything in the OSFILE control
        ld      b,$10           ; except the filename pointer.
        ld      hl,ofblk+$02
obclp:  ld      (hl),a
        inc     hl
        djnz    obclp
        ld      hl,(dbuff)      ; Set up the load address in the OSFILE block
        ld      (ofblk+$02),hl  ; at the end of this program then issue the
        ld      a,$FF           ; the call to load the file.
        ld      hl,ofblk
        call    OSFILE
        or      a
        jr      z,ofail
        ld      de,(dbuff)      ; Write to CP/M
        ld      hl,(ofblk+$0A)
        call    cpmwrt
clscpm: ld      c,FCLOSE        ; Close the output file
        ld      de,FCB2
        call    BDOS
        cp      $FF
        jp      z,wrerr
        ret
ofail:  ld      de,notfnd
        jp      msgout

        ;; This is the copy strategy when the the file does not fit in buffer.

bigfil: ld      bc,(dbuff)      ; Get the buffer space again and truncate it
        ld      hl,CCPBASE      ; to an integer multiple of the CP/M record
        and     a               ; size so only the last CP/M record is a
        sbc     hl,bc           ; partial one and we don't add random junk
        ld      a,$80           ; in the middle of the file.
        and     l
        ld      l,a
        ld      (bufsiz),hl
        ld      a,$40           ; Open the BBC (1st) file for reading
        ld      hl,fndest
        call    OSFIND
        or      a
        jr      nz,bigfnd
        ld      de,notfnd
        jp      msgout
bigfnd: ld      hl,gbblk        ; Set up the OSGBPB parameter block.
        ld      (hl),a
        xor     a
        ld      b,$0C
clrlp:  inc     hl
        ld      (hl),a
        djnz    clrlp
gblp:   ld      hl,(dbuff)
        ld      (gbblk+$01),hl
        ld      hl,(bufsiz)
        ld      (gbblk+$05),hl
        ld      a,$04           ; Read bytes from the file.
        ld      hl,gbblk
        call    OSGBPB
        ld      hl,gbblk+$05    ; Check if we read a complete buffer full.
        ld      c,(hl)
        ld      a,c
        inc     hl
        ld      b,(hl)
        or      b
        inc     hl
        or      (hl)
        inc     hl
        or      (hl)
        push    af
        and     a
        ld      hl,(bufsiz)     ; Work out how many bytes read.
        sbc     hl,bc
        ld      de,(dbuff)      ; Write to the CP/M file.
        call    cpmwrt
        jr      c,done
        pop     af              ; Last buffer?
        jr      z,gblp
close:  ld      a,(gbblk)       ; Close the BBC file.
        ld      h,a
        xor     a
        call    OSFIND
        jr      clscpm          ; Close the CP/M file.
done:   pop     af
        jr      close

        ;; Subroutine to write the buffer to the CP/M file.

cpmwrt: ld      a,l             ; Round number of CP/M records?
        and     $7F
        jr      z,round
        ld      bc,$80          ; Not a round number so write one extra
        add     hl,bc           ; record for the odd bytes at the end.
round:  xor     a
        add     hl,hl           ; multiply by two
        adc     a,a             ; then capture carry.
        ld      b,h             ; so B contains a number of 128 byte records
        ld      c,a             ; to write and C is one if another 256 should
wrloop: push    bc              ; be written.
        push    de
        ld      c,SETDMA        ; Set the "DMA" address, i.e. where the
        call    BDOS            ; data is to be written from.
        ld      c,FWRITSQ       ; Write the record.
        ld      de,FCB2
        call    BDOS
        or      a               ; Successful
        jr      nz,wrerr
        pop     de              ; Increment DMA address.
        ld      hl,$80
        add     hl,de
        ld      d,h
        ld      e,l
        pop     bc
        djnz    wrloop
        ld      a,c
        ld      c,b
        or      a
        jr      nz,wrloop
        and     a               ; clear carry to indicate success.
        ret
wrerr:  ld      de,wrmsg
        call    msgout
        scf                     ; set carry to indicate failure.
        ret

        ;; Messages

notfnd: db      "Acorn input file not found",$0D,$0A,'$'
wrmsg   db      "Error writing to CP/M output file",$0D,$0A,'$'  
ustr:   db      "Usage: dfs2cpm <dfs-file> <cpm-file>",$0D,$0A,'$'
dirmsg  db      "Unable to copy a directory",$0D,$0A,'$'
ocmsg:  db      "Unable to create CP/M output file",$0D,$0A,'$'
data:

        ;; Unitialised data section, i.e. workspace.

        .segu   "data"
        .org    data
dbuff:  dw      0
bufsiz  dw      0        
ofblk   ds      18
gbblk   equ     ofblk+2        
fndest: 
