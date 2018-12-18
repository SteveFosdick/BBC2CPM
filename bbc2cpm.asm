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

        ld      a,(FCB1FN)      ; Check if first filename present.
        ld      b,' '
        cp      b
        jr      z,usage
        ld      a,(FCB2+$01)    ; Check if second filename present.
        cp      b
        jr      z,usage
        ld      bc,16           ; Move the 2nd FCB down over the 1st.  We
        ld      de,FCB1         ; cannot use the ready-parsed FCB1 anyway as
        ld      hl,FCB2         ; Acorn filenames do not use CP/M conventions.
        ldir
        ld      hl,CMDTAIL      ; Go back to the command line and get the
        ld      b,(hl)          ; length.
spclp:  inc     hl              ; Skip any initial spaces.
        ld      a,(hl)
        cp      ' '
        jr      z,isspc
        cp      $09
        jr      nz,notspc
isspc:  djnz    spclp           ; If we get to the end of the command line the
usage:  ld      de,ustr         ; 1st filename must be missing.
msgout: ld      c,PRSTR
        jp      BDOS
notspc: ld      (ofblk),hl      ; Save start address of filename in OSFILE
nsplp:  ld      a,(hl)          ; control block then find the end of the
        cp      ' '             ; filename, i.e. the next space or tab.
        jr      z,endnam
        cp      $09
        jr      z,endnam
        inc     hl
        djnz    nsplp
endnam: ld      a,$0D           ; Terminate the filename with CR.
        ld      (hl),a

        ;; Check if the source (BBC) file fits in the available buffer.

        ld      hl,ofblk        ; Issue an OSFILE call for that filename to
        ld      a,$05           ; find how big the corresponding file is.
        call    OSFILE
        cp      $01             ; Was a file found?
        jr      z,found
        cp      $02             ; Was a directory found?
        jr      z,gotdir
        ld      de,notfnd
        jr      msgout
gotdir: ld      de,dirmsg
        jr      msgout
found:  ld      c,FDELETE       ; Delete any existing file in the way of
        ld      de,FCB1         ; the output file.
        call    BDOS
        ld      c,FCREATE       ; Create a new output file.
        ld      de,FCB1
        call    BDOS
        inc     a               ; Check if succesful.
        jr      nz,isopen
        ld      de,ocmsg
        jr      msgout
isopen: xor     a               ; Start writing at record zero.
        ld      (FCB1EX),a
        ld      (FCB1CR),a
        ld      l,a             ; Set LSB of top of memory to zero.
        ld      a,(BDOS+2)      ; Get MSB of BDOS start.
        sub     8               ; Drop to below start of CCP.
        ld      h,a             ; Now HL is top of usable memory.
        ld      bc,-dbuff       ; Subtract start of buffer to give the
        add     hl,bc           ; size of the available buffer.
        ld      (bufsiz),hl
        ld      hl,ofblk+$0C    ; Back to the Acorn file, if either of the
        ld      a,(hl)          ; most significant two bytes of the length is
        inc     hl              ; set then this is too big to do in one go.
        or      (hl)
        jr      nz,bigfil
        ld      bc,(ofblk+$0A)  ; Otherwise compare the file size to the
        ld      hl,(bufsiz)     ; available memory size to see if the
        and     a               ; file will fit in RAM.
        sbc     hl,bc
        jr      c,bigfil

        ;; This is the copy strategy when the whole file fits in buffer.

        xor     a               ; Clear everything in the OSFILE control
        ld      b,$10           ; except the filename pointer.
        ld      hl,ofblk+$02
obclp:  ld      (hl),a
        inc     hl
        djnz    obclp
        ld      hl,dbuff        ; Set up the load address in the OSFILE block
        ld      (ofblk+$02),hl  ; at the end of this program then issue the
        ld      a,$FF           ; the call to load the file.
        ld      hl,ofblk
        call    OSFILE
        or      a
        jr      z,ofail
        ld      hl,(ofblk+$0A)  ; Round number of records?
        call    padlst
round1: call    cpmwrt          ; Write to CP/M.
clscpm: ld      c,FCLOSE        ; Close the output file
        ld      de,FCB1
        call    BDOS
        inc     a
        ret     nz
        ld      de,wrmsg
        jp      msgout
ofail:  ld      de,notfnd
        jp      msgout

        ;; This is the copy strategy when the the file does not fit in buffer.

bigfil: ld      hl,(bufsiz)     ; Get the buffer size again and truncate it
        ld      a,$80           ; to an integer multiple of the CP/M record
        and     l               ; size so only the last CP/M record is a
        ld      l,a             ; partial one and we don't add random junk
        ld      (bufsiz),hl     ;  in the middle of the file. 
        ld      a,$40
        ld      hl,(ofblk)      ; Open the BBC (1st) file for reading
        call    OSFIND 
        or      a
        jr      nz,bigfnd
        call    clscpm          ; Close the CP/M file.
        ld      de,notfnd       ; Report the not found error.
        jp      msgout
bigfnd: ld      hl,gbblk        ; Store the handle in the OSGBPB block.
        ld      (hl),a
        xor     a               ; Clear the rest of the  OSGBPB block.
        ld      b,$0C
clrlp:  inc     hl
        ld      (hl),a
        djnz    clrlp
gblp:   ld      hl,dbuff        ; Set destination address.
        ld      (gbblk+$01),hl
        ld      hl,(bufsiz)     ; Set size to read.
        ld      (gbblk+$05),hl
        ld      a,$04           ; Read bytes from the file.
        ld      hl,gbblk
        call    OSGBPB
        ld      hl,gbblk+$05    ; Check if we read a complete buffer full
        ld      c,(hl)          ; and also set BC to the number of bytes
        ld      a,c             ; not written.
        inc     hl
        ld      b,(hl)
        or      b
        inc     hl
        or      (hl)
        inc     hl
        or      (hl)
        ld      hl,(bufsiz)
        jr      nz,last
        call    cpmwrt          ; Write to the CP/M file.
        jr      nc,gblp
        jr      close
last:   sbc     hl,bc           ; Work out the number of bytes written.
        call    padlst
        call    cpmwrt          ; Write to the CP/M file.
close:  ld      a,(gbblk)       ; Close the BBC file.
        ld      h,a
        xor     a
        call    OSFIND
        jp      clscpm          ; Close the CP/M file.

        ;; Subroutine to pad out the last record of the CP/M file with CP/M
        ;; EOF characters (^Z).  This also has the effect of ensuring we have
        ;; an integer number of records to write.  Entered with HL containing
        ;; the number of bytes in the buffer ready to be written and returns
        ;; with HL adjusted to a integer multiple of the record size.

padlst: ld      a,$7F           ; Test for integer multiple.
        and     l
        ret     z
        neg
        add     a,$80
        ld      b,a
        ld      a,$1A
        ld      de,dbuff        ; Find end of data read.
        add     hl,de
padlp:  ld      (hl),a
        inc     hl
        djnz    padlp
        and     a               ; Adjust HL.
        sbc     hl,de
        ret

        ;; Subroutine to write the buffer to the CP/M file.

cpmwrt: xor     a
        add     hl,hl           ; multiply by two
        adc     a,a             ; then capture carry.
        ld      b,h             ; so B contains a number of 128 byte records
        ld      c,a             ; to write and C is one if another 256 should
        ld      de,dbuff        ; be written.
wrloop: push    bc
        push    de
        ld      c,SETDMA        ; Set the "DMA" address, i.e. where the
        call    BDOS            ; data is to be written from.
        ld      c,FWRITSQ       ; Write the record.
        ld      de,FCB1
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
bufsiz  dw      0        
ofblk   ds      18
gbblk   equ     ofblk+2        
dbuff:
