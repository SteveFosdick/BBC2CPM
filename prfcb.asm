;;; PRFCB.ASM
;;;
;;; Subroutine to print the filename in an FCB whose address is in HL.

prfcb:  inc     hl              ; move on to the first byte of the filename.
        push    hl
        ld      b,8             ; up to 8 characters for this bit.
        call    prfcb1
        pop     hl
        ld      de,8            ; move on to the type/extensoion.
        add     hl,de
        ld      a,(hl)
        cp      ' '             ; is there one?
        ret     z
        push    hl
        ld      e,'.'           ; print the dot.
        ld      c,CONOUT
        call    BDOS
        pop     hl
        ld      b,3             ; up to three characters in this part.
prfcb1: ld      a,(hl)
        cp      ' '
        ret     z
        inc     hl
        push    bc
        push    hl
        ld      c,CONOUT
        ld      e,a
        call    BDOS
        pop     hl
        pop     bc
        djnz    prfcb1
        ret
        
;;; End.
