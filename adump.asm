        .processor z80
        .include   "defs.asm"
        org     $100

        ld      a,(FCB1FN)      ; Look for a ready-parsed filename.  A
        cp      ' '             ; space means no filename given.
        jp      z,usage
        xor     a               ; Start at the beginning of the file.
        ld      (FCB1EX),a
        ld      (FCB1CR),a
        ld      c,FOPEN         ; Open file.
        ld      de,FCB1
        call    BDOS
        inc     a
        jp      z,notfnd
reclp:  ld      c,FREADSQ       ; Read a record from the file.
        ld      de,FCB1
        call    BDOS
        or      a
        ret     nz              ; EOF.
        ld      hl,$0080
        ld      c,8             ; 8 lines per record.
linelp: push    bc
        ld      de,outlin
        ld      a,(offset+3)    ; print the offset in hex.
        call    hexbyt
        ld      a,(offset+2)
        call    hexbyt
        ld      a,(offset+1)
        call    hexbyt
        ld      a,(offset)
        call    hexbyt
        ld      a,':'
        ld      (de),a
        inc     de
        ld      a,' '
        ld      (de),a
        inc     de
        pop     bc
        ld      b,16            ; 16 bytes per line.
        push    bc
hexlp:  ld      a,(hl)
        inc     hl
        call    hexbyt          ; print in hex.
        ld      a,' '
        ld      (de),a
        inc     de
        djnz    hexlp
        ld      a,'$'
        ld      (de),a
        push    hl
        ld      c,PRSTR
        ld      de,outlin
        call    BDOS
        pop     hl
        pop     bc
        ld      de,-16          ; Rewind the memory pointer to the first
        add     hl,de
        ld      b,16
asclp:  ld      a,(hl)
        inc     hl
        push    bc
        push    hl
        cp      ' '
        jr      c,dot           ; control characters to dots.
        cp      $7f
        jr      c,asis
dot:    ld      a,'.'
asis:   ld      e,a             ; Print ASCII character.
        ld      c,CONOUT
        call    BDOS
        pop     hl
        pop     bc
        djnz    asclp           ; go round for next.
        push    bc
        push    hl
        ld      e,$0D
        ld      c,CONOUT
        call    BDOS
        ld      e,$0A
        ld      c,CONOUT
        call    BDOS
        ld      hl,(offset)
        ld      de,16
        add     hl,de
        ld      (offset),hl
        jr      nc,noinc
        ld      hl,(offset+2)
        inc     hl
        ld      (offset+2),hl
noinc:  pop     hl
        pop     bc
        dec     c
        jp      nz,linelp
        jp      reclp
usage:  ld      de,usmsg
        ld      c,PRSTR
        jp      BDOS
usmsg:  db      "Usage: adump <file>",$0D,$0A,'$'

notfnd: ld      de,nfmsg1
        ld      c,PRSTR
        call    BDOS
        ld      hl,FCB1
        call    prfcb
        ld      de,nfmsg2
        ld      c,PRSTR
        jp      BDOS
nfmsg1: db      "File '$"
nfmsg2: db      "' not found",$0D,$0A,'$'

        .include "prfcb.asm"
        
hexbyt: ld      c,a
        rrc     a
        rrc     a
        rrc     a
        rrc     a
        call    hexnyb
        ld      a,c
hexnyb: and     $0F
        cp      $0A
        ccf
        adc     a,'0'
        daa
        ld      (de),a
        inc     de
        ret
offset: dw      0
        dw      0
outlin: 
