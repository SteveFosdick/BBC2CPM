;;; Parse a CP/M filename to a File Control Block (FCB)
;;;
;;; On entry: DE => text to scan
;;;           HL => FCB to fill
;;; On exit:  DE => terminating character.
;;;           A  =  terminating character.
;;;           NZ =  bad filename
;;; Filename terminated by CR SPC ',' or '='
;;;
;;; Originally from SJCCP via http://mdfs.net/Docs/Comp/CPM/ScanName

ScanFnFCB1:     LD      HL,FCB1
ScanFilename:   PUSH    HL          ; Save address of FCB.
                XOR     A           ; Drive and current record default to 0.
                LD      (HL),A
                LD      A,' '       ; Clear filename+type to all spaces.
                LD      B,11
ScanFnClearLp1: INC     HL
                LD      (HL),A
                DJNZ    ScanFnClearLp1
                XOR     A           ; Clear extent and next 3 bytes to zero.
                LD      B,4
ScanFnClearLp2: INC     HL
                LD      (HL),A
                DJNZ    ScanFnClearLp2
                POP     HL
                PUSH    DE
                CALL    GetUpperTest
                JR      C,ScanFnEnd ; Error if control char.
                LD      C,A         ; Save in case it is the drive letter.
                CALL    GetUpper
                CP      ':'         ; Drive letter separator?
                JR      Z,ScanFnGotDrv
                POP     DE
                JR      ScanFnComm
ScanFnGotDrv:   LD      A,$3F       ; Convert to drive number.
                AND     C
                LD      (HL),A
                INC     SP          ; Discard line pointer
                INC     SP
ScanFnComm:     INC     HL          ; point to filename part of FCB.
                PUSH    HL
                LD      B,9         ; scan 8 characters (does not include 0).
ScanFnFileLp:   CALL    GetUpperTest
                JR      Z,ScanFnEnd
                JR      C,ScanFnEnd
ScanFnNotEnd:   CP      '.'         ; If '.' the move to file type (extension)
                JR      Z,ScanFnDot
                CP      '*'         ; if '*' expand to '?'s
                CALL    Z,ScanFnWild
                LD      (HL),A
                INC     HL
                DJNZ    ScanFnFileLp
                JR      ScanFnEnd
ScanFnDot:      POP     HL          ; Point to the file type in FCB.
                LD      BC,8
                ADD     HL,BC
                LD      B,4         ; Up to 3 characters.
ScanFnTypeLp:   CALL    GetUpperTest
                RET     Z           ; end of filename.
                RET     C           ; bad character.
                CP      '*'         ; if '*' expand to '?'s
                CALL    Z,ScanFnWild
                LD      (HL),A
                INC     HL
                DJNZ    ScanFnTypeLp
                RET                 ; too many characters.
ScanFnEnd:      POP     HL
                RET
ScanFnWild:     LD      A,'?'
                DEC     B
                JR      Z,ScanFnWildEnd
ScanFnWildLp:   LD      (HL),A
                INC     HL
                DJNZ    ScanFnWildLp
                DEC     HL
                INC     B
ScanFnWildEnd:  INC     B
                RET

GetUpper:       LD      A,(DE)
                CP      $0D
                RET     Z
                AND     $5F         ; convert to lower case.
                CP      'A'
                JR      C,GetUpperNotA
                CP      '['
                JR      C,GetUpperIsA
GetUpperNotA:   LD      A,(DE)      ; wasn't alpha so get original.
GetUpperIsA:    INC     DE
                RET

GetUpperTest:   CALL    GetUpper
                CP      $0D
                RET     Z
                CP      ','
                RET     Z
                CP      '='
                RET     Z
                CP      ' '
                RET     NZ
                PUSH    AF
                CALL    SkipSpace
                POP     AF
                RET

SkipSpace:      LD      A,(DE)
                CP      ' '
                RET     NZ
                INC     DE
                JR      SkipSpace
