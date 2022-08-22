        .386P

CODE    SEGMENT BYTE PUBLIC 'CODE'
        ASSUME CS:CODE,CS:CODE,CS:CODE

; Wrapper code to execute the unprotected binary.
START:
        JMP     ENTRY

BUFFER          DB 6000H DUP(0)

BYTES_READ      DW 0
ADDR_OFFSET     DW 0
FILE_HANDLE     DW 0
PATTERN_ADDR    DD 0
ADDR_STR        DB "0",10 DUP(0)
CELL_IN_VRAM    DW 0
MSG_OK          DB "OK",13,10,"$"
MSG_FAILED      DB "FAILED",13,10,"$"
MSG_HEADING     DB 13,10," wINDOWS 95 mEMPHIS  *gENERIC tIME bOMB kILLER* v1.0                27 May 1996"
                DB 13,10," Copyright (c) 1996 tHE riDDLER 1996! [uCF]                 All Rights Reserved"
                DB 13,10,"$"
MSG_OPENING     DB 13,10,"  ",0FEH," Opening file IO.SYS.               $"
MSG_SEARCHING   DB "  ",0FEH," Searching for data to patch.       $"
MSG_FOUND_AT    DB "    > Found at: $"
MSG_MODDING     DB "  ",0FEH," Modifying data.                    $"
MSG_CLOSING     DB "  ",0FEH," Closing file.                      $"
CRLF            DB 13,10,"$"
FILE_IO_SYS     DB "IO.SYS",0 
BYTES_TO_FIND   DB 0B4H,02AH,0CDH,021H,091H,02DH
PATCH_BYTES     DB 033H,0C9H,090H,090H
word_6399       DW 15h
word_639B       DW 0
BACKUP_ATTR     DW 0
                DB 0

ENTRY:
        MOV     AX,DS
        MOV     DS,AX
        MOV     ES,AX
        XOR     CX,CX
        LEA     DX,LARGE FILE_IO_SYS    ; load IO.SYS filename
        MOV     AX,4300H                ; GetFileAttributes
        INT     21H
        MOV     LARGE DS:BACKUP_ATTR,CX ; save the original attributes
        XOR     CX,CX                   ; clear the attributes
        MOV     AX,4301H                ; DOS - SetFileAttributes
        INT     21H
        LEA     DX,LARGE FILE_IO_SYS    ; this line is completely useless
        CALL    OPEN_FILE               ; open the file
        CALL    FIND_PATTERN            ; find the pattern
        CALL    PATCH_FILE              ; patch the file
        JMP     SHORT EXIT              ; restore attributes and quit
        NOP

FAILED:
        LEA     DX,LARGE MSG_FAILED     ; load failure message
        CALL    PRINT                   ; print it
        JMP     SHORT EXIT              ; restore attributes and quit
        NOP

EXIT:
        LEA     DX,LARGE FILE_IO_SYS    ; load IO.SYS filename
        MOV     CX,LARGE DS:BACKUP_ATTR
        MOV     AX,4301H                ; SetFileAttributes
        INT     21H

; Restore the text mode and print empty line
        CALL    PRINT_ASTERISKS
        LEA     DX,LARGE CRLF
        CALL    PRINT

; Quit the program
        MOV     AH,4CH                  ; Exit
        INT     21H

CURS_IN_VIDEO_RAM:
; Set cursor start line
        MOV     CX,2000H
        MOV     AH,1                    ; SetCursorCharacteristics
        INT     10H

; Get cursor position
        MOV     AH,3                    ; ReadCursorPosition
        XOR     BX,BX
        INT     10H
;
; Calculate address of cell in video ram
;
        XCHG    DH,AL                   ; AL = row
        MOV     CL,160
        MUL     CL                      ; AL = row * 80 * 2
        XCHG    AX,BX                   ; BX = AX
        XCHG    DL,AL                   ; AL = column
        MOV     CL,2
        MUL     CL                      ; AL = column * 2
        ADD     BX,AX                   ; row * 80 * 2 + column * 2
        MOV     LARGE DS:CELL_IN_VRAM,BX
        RET

FIND_PATTERN:
; Print searching message
        LEA     DX,LARGE MSG_SEARCHING
        CALL    PRINT
        CALL    CURS_IN_VIDEO_RAM

        MOV     BX,LARGE DS:FILE_HANDLE        ; Seek to beginning
        XOR     CX,CX
        XOR     DX,DX
        MOV     AX,4200H                ; SeekFromBeginning
        INT     21H
        JB      SHORT FAILED

        MOV     CX,6000H                ; read a 0x6000-byte block
        LEA     DX,LARGE BUFFER
        MOV     AH,3FH                  ; Read
        INT     21H
        JB      FAILED

; Save and check the number of bytes read
        MOV     LARGE DS:BYTES_READ,AX
        CMP     AX,CX
        JNZ     SHORT GOT_TO_END
        NOP
        NOP

; Check if pattern is in the current block
        CALL    FIND_IT
        JB      SHORT NEXT_BLOCK        ; onto the next block
        NOP                             ; done
        NOP
        RET

NEXT_BLOCK:
; Get current position
        MOV     BX,LARGE DS:FILE_HANDLE
        XOR     AX,AX
        XOR     CX,CX
        XOR     DX,DX
        MOV     AX,4201H                ; SeekFromCurrentPos
        INT     21H

; Calculate new position (current + 0x6000)
        SHL     EDX,16
        MOV     DX,AX
        SUB     EDX,6
        MOV     CX,DX
        SHR     EDX,16
        XCHG    CX,DX
        MOV     AX,4200H                ; SeekFromBeginning
        INT     21H

; Read next block of 0x6000 bytes
        CLC
        MOV     BX,LARGE DS:FILE_HANDLE
        MOV     CX,6000H
        LEA     DX,LARGE BUFFER
        MOV     AH,3FH                  ; Read
        INT     21H
        JB      FAILED

; Save and check the number of bytes read
        MOV     LARGE DS:BYTES_READ,AX  ; save the n
        CMP     AX,CX                   ; is this the last block
        JNZ     SHORT GOT_TO_END        ; yes it is
        NOP
        NOP                             ; no it isn't
        CALL    FIND_IT
        JB      SHORT NEXT_BLOCK        ; not found, move onto next block
        RET                             ; found the pattern, return

GOT_TO_END:
        CALL    FIND_IT
        JB      FAILED                  ; this is the last block, so pattern not in this file
        RET                             ; found it in the last block

FIND_IT:
        XOR     BX,BX
        LEA     DI,LARGE BUFFER

DO_COMPARE:
        CLC                             ; clear carry flag
        MOV     CX,6                    ; 6 bytes to compare
        CALL    COMPARE_BYTES
        JNZ     SHORT INC_PTR           ; increment and try again
        NOP
        NOP
        CLC                             ; clear carry flag and return
        RET

INC_PTR:
        MOV     AL,6
        XOR     AH,AH
        SUB     AX,CX
        SUB     AX,1
        SUB     DI,AX
        ADD     BX,1                    ; add one to counter
        PUSH    DS                      ; save DS
        PUSH    0B800H                  ; video memory base
        MOV     CX,LARGE DS:CELL_IN_VRAM
        MOV     WORD PTR CS:[$L0000+2],CX
        POP     DS                      ; set DS to 0xB800
$L0000  INC     BYTE PTR DS:[2000]      ; increment B800:CX
        POP     DS                      ; restore DS

; Check if entire block done
        CMP     BX,LARGE DS:BYTES_READ  ; entire block compared?
        JL      SHORT DO_COMPARE        ; nope, compare again
        STC                             ; yes, set carry flag
        RET

COMPARE_BYTES:
        LEA     SI,LARGE BYTES_TO_FIND
        REPE CMPSB
        RET

PATCH_FILE:
        CALL    PRINT_OK                ; show that we've found the pattern
        MOV     AL,6
        XOR     AH,AH
        SUB     DI,AX
        LEA     DX,LARGE BUFFER
        SUB     DI,DX
        ADD     DI,LARGE DS:word_6399
        SUB     DI,LARGE DS:word_639B
        MOV     LARGE DS:ADDR_OFFSET,DI
        MOV     BX,LARGE DS:FILE_HANDLE
        XOR     EAX,EAX
        XOR     CX,CX
        XOR     DX,DX
        MOV     AX,4201H                ; SeekFromCurrentPos
        INT     21H
        SHL     EDX,16
        MOV     DX,AX
        XOR     EAX,EAX
        MOV     AX,LARGE DS:BYTES_READ
        SUB     EDX,EAX
        XOR     EAX,EAX
        MOV     AX,LARGE DS:ADDR_OFFSET
        ADD     EDX,EAX
        MOV     LARGE DS:PATTERN_ADDR,EDX
        MOV     CX,DX
        SHR     EDX,16
        XCHG    CX,DX
        MOV     AX,4200H                ; SeekFromBeginning
        INT     21H
        JB      FAILED
        CALL    PRINT_ADDRESS
        LEA     DX,LARGE MSG_MODDING
        CALL    PRINT
        MOV     BX,LARGE DS:FILE_HANDLE
        MOV     CX,4
        LEA     DX,LARGE PATCH_BYTES
        MOV     AH,40H                  ; Write
        INT     21H
        JB      FAILED
        CALL    PRINT_OK
        LEA     DX,LARGE MSG_CLOSING
        CALL    PRINT
        MOV     BX,LARGE DS:FILE_HANDLE
        MOV     AH,3EH                  ; Close
        INT     21H
        JB      FAILED
        CALL    PRINT_OK
        RET

PRINT:
        MOV     AH,9                    ; Print
        INT     21H
        RET


OPEN_FILE:
        LEA     DX,LARGE CRLF
        CALL    PRINT
        CALL    PRINT_ASTERISKS
        LEA     DX,LARGE MSG_HEADING
        CALL    PRINT
        CALL    PRINT_ASTERISKS
        LEA     DX,LARGE MSG_OPENING
        CALL    PRINT
        LEA     DX,LARGE FILE_IO_SYS
        MOV     AX,3D02H               ; OpenRW
        INT     21H
        JB      FAILED
        MOV     LARGE DS:FILE_HANDLE,AX
        CALL    PRINT_OK
        RET


PRINT_OK:
        LEA     DX,LARGE MSG_OK
        CALL    PRINT
        RET


PRINT_ADDRESS:
        MOV     EAX,LARGE DS:PATTERN_ADDR
        MOV     EBX,16
        XOR     ECX,ECX

GET_DIGITS:
        XOR     EDX,EDX
        DIV     EBX
        PUSH    EDX
        INC     ECX
        OR      EAX,EAX
        JNZ     SHORT GET_DIGITS
        XOR     EDI,EDI
        INC     EDI

LOOP_TO_STR:
        POP     EDX
        CMP     EDX,9
        JG      SHORT DO_BASE_16
        NOP
        NOP
        ADD     DL,30H                  ; to ASCII digit
        MOV     DS:ADDR_STR[DI],DL
        INC     DI
        JMP     SHORT BACK_TO_LOOP_START
        NOP

DO_BASE_16:
        ADD     DL,57H                  ; to ASCII lowercase
        MOV     DS:ADDR_STR[DI],DL
        INC     DI
        JMP     SHORT BACK_TO_LOOP_START
        NOP

BACK_TO_LOOP_START:
        LOOP    LOOP_TO_STR             ; loop if not done yet
        MOV     DL,"H"
        MOV     DS:ADDR_STR[DI],DL      ; append "H" to the string
        MOV     DL,"$"
        MOV     DS:(ADDR_STR+1)[DI],DL  ; mark end of string
        LEA     DX,LARGE MSG_FOUND_AT
        CALL    PRINT                   ; print found at string
        LEA     DX,LARGE ADDR_STR
        CALL    PRINT                   ; print address string
        LEA     DX,LARGE CRLF
        CALL    PRINT                   ; print new line
        RET


PRINT_ASTERISKS:
        MOV     AX,9FAH
        MOV     CX,80
        MOV     BX,1                    ; WriteAttribAndChar
        INT     10H
        RET


CODE            ENDS


                END
