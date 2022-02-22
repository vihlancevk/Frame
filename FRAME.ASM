.model tiny

.data
VIDEOSEG = 0b800h

CONSOLE_WIDTH = 25d
CONSOLE_LENGTH = 80d

Msg db 'Botay$'
MSG_SIZE = 5d

FRAME_WIDTH  = 3d
FRAME_LENGTH = MSG_SIZE + 2d

Elems db 21h, 03h, 21h, 03h, 20h, 03h, 21h, 03h, 21h	; !   03h  !
							; 03h     03h
							; !   03h  !

; Elems db 20h, 20h, 20h, 20h, 20h, 20h, 20h, 20h, 20h	; _ _ _
							; _ _ _
							; _ _ _
							; '_' - Netflix space

Status db 01h, 01h

;------------------------------------------------
; Calculate a two-digit number (decimal number system)
;
; Entry:	SI - addr of 2-byte array containing number
; Exit:		AH - two-digit number
; Destr:	AX, SI
;------------------------------------------------

CalcTwoDigitNum     proc
			                    
                    mov ah, [si]	; calculation of the highest digit
                    inc si
                    sub ah, 30h
                    mov al, 10d
                    mul ah
                    mov ah, al

                    mov al, [si]	; calculating of the lowest digit
                    inc si
                    sub al, 30h

                    add ah, al	   	; number
                    
                    ret
CalcTwoDigitNum     endp

;------------------------------------------------
; Calculate start point
;
; Entry:	SI - args cmd addr (81h)
; Exit:		DI - start point of frame
; Destr:	AX, DI, SI
;------------------------------------------------

CalcStPt	proc

		mov si, CMD_LINE
        	call CalcTwoDigitNum
        	mov al, CONSOLE_LENGTH * 2d
        	mul ah
        	mov di, ax

		inc si        	
        	call CalcTwoDigitNum
        	mov al, 2d
        	mul ah
        	add di, ax
		
           	ret
CalcStPt	endp

;------------------------------------------------
; Draw a line in a frame
;
; Entry:	AH - color (attr) of line
;		CX - lenght of string
;		SI - addr of 3-byte array containing line elements
;		DI - adress of start of line
; Note:		ES - videoseg addr (0b800h)
; Exit:		None
; Destr:	AX, CX, DI, SI
;------------------------------------------------

DrawLine	proc		; cld (Clear Dest Flag) (++)
				; std (Set Dest Flag) (--)
		mov al, [si]	; lodcb (Load String of )
		inc si

		mov es:[di], ax	; stosw (Store String of Words)
		add di, 2d			

		mov al, [si]	; lodcb
		inc si

		sub cx, 2d
		jbe @@stopLine

@@nextSym:	mov es:[di], ax	; rep stosw
		add di, 2d
		loop @@nextSym

		mov al, [si]	; lodsb

		mov es:[di], ax	; stosw
		add di, 2d

@@stopLine:	ret
DrawLine	endp

;------------------------------------------------
; Draw frame
;
; Entry:	None
; Note:		ES - videoseg addr (0b800h)
; Exit:		None
; Destr:	AX, BX, CX, DX, DI, SI
;------------------------------------------------

DrawFrame 	proc

		mov ax, VIDEOSEG
		mov es, ax
	
		;================================================
		; Draw first line of frame
		;------------------------------------------------
		call CalcStPt

		mov si, offset Elems
		mov ax, 7000h
		mov cx, FRAME_LENGTH
		call DrawLine
		;================================================

		;================================================
		; Draw the main part of frame
		;------------------------------------------------
		mov dh, 1d	

		mov cx, FRAME_WIDTH
		sub cx, 2d

lp1:		call CalcStPt		
		mov ah, dh
		mov al, CONSOLE_LENGTH * 2d
		mul ah
		add di, ax
		
		mov ax, 7000h
		mov bx, cx
		mov cx, FRAME_LENGTH
		mov si, offset Elems
		add si, 3d
		call DrawLine

		inc dh
		mov cx, bx
		loop lp1
		;================================================	
		
		mov si, offset Msg		; displaying text in a frame
		sub di, 2d * FRAME_LENGTH
		add di, 2d
		mov cx, MSG_SIZE

lp:		mov bl, [si]
		mov es:[di], bl
		inc si
		add di, 2d
		loop lp

		;================================================
		; Draw last line of frame
		;------------------------------------------------
		mov si, offset Elems
		add si, 6d
		mov bx, si

		call CalcStPt
		mov ah, dh
		mov al, CONSOLE_LENGTH * 2d
		mul ah
		add di, ax
	
		mov si, bx	
		mov ax, 7000h
		mov cx, FRAME_LENGTH
		call DrawLine
		;================================================

		ret
DrawFrame	endp

;------------------------------------------------
; Function add
;
; Entry:	SI - addr number
; Exit:		increasing the number by one
; Destr:	AX, SI
;------------------------------------------------

FuncAdd		proc

		inc si
       		mov al, [si]
        	cmp al, 09d
        	je TEN_ADD
            		add al, 01h
            		mov [si], al
            		jmp NO_TEN_ADD

TEN_ADD:	mov al, 30h
		mov [si], al
		dec si
		mov al, [si]
		add al, 1h
		mov [si], al

NO_TEN_ADD:
		ret
FuncAdd		endp

;------------------------------------------------
; Function sub
;
; Entry:	SI - addr number
; Exit:		dec the number by one
; Destr:	AX, SI
;------------------------------------------------

FuncSub	    proc
            
            inc si
            mov al, [si]
            cmp al, 00d
            je TEN_SUB
            	sub al, 1h
            	mov [si], al
            	jmp NO_TEN_SUB

TEN_SUB:    mov al, 39h
            mov [si], al
            dec si
            mov al, [si]
            sub al, 1h
            mov [si], al

NO_TEN_SUB:
            
            ret
FuncSub     endp

;-------------------------------------------------
; Change coordinates start point
;
; Entry:	BP - bypass direction ( 01h - down, 00h - up)
;			DS - bypass direction ( 01h - right, 00h - left)
; Note:		ES - videoseg addr (0b800h)
; Exit:		new coordinates
; Destr:	AX, BX, SI, BP
;-------------------------------------------------

ChangeCordStPr      proc
                    
                    mov si, CMD_LINE
                    call CalcTwoDigitNum
                    mov si, offset Status
                    cmp ah, 00d
                    jne skip11
                        mov bl, 01h
                        mov [si], bl

skip11:		    cmp ah, CONSOLE_WIDTH - FRAME_WIDTH
                    jne skip12
                        mov bl, 00h
                        mov [si], bl

skip12:		    mov bl, 01h
                    cmp [si], bl
                    je add1
                        mov si, CMD_LINE
                        call FuncSub    	; function sub
                        jmp sub1

add1:		    mov si, CMD_LINE
                    call FuncAdd    		; function add

sub1:		    mov si, CMD_LINE
                    add si, 3
                    call CalcTwoDigitNum
                    mov si, offset Status
                    inc si
                    cmp ah, 00d
                    jne skip21
                        mov bl, 01h
                        mov [si], bl

skip21:		    cmp ah, CONSOLE_LENGTH - FRAME_LENGTH
                    jne skip22
                        mov bl, 00h
                        mov [si], bl

skip22:		    mov bl, 01h
                    cmp [si], bl
                    je add2
                        mov si, CMD_LINE
                        add si, 3
                        call FuncSub    	; function sub
                        jmp sub2

add2:		    mov si, CMD_LINE
                    add si, 3
                    call FuncAdd    		; function add

sub2:
                    
                    ret
ChangeCordStPr      endp

.code
org 100h

locals @@ ; (lb - global label, @@lb - local label)

.getch	macro
	nop
	xor ah, ah
	int 16h
	nop
	endm

CMD_LINE = 82h

Start:	mov ax, VIDEOSEG
	mov es, ax

lp2:	call DrawFrame
	call ChangeCordStPr
        
	mov ax, 8600h		; pause for 0,4 second
	mov cx, 0006h
	mov dx, 1a80h
	int 15h
        
        mov ax, 0h		; clearing the console
        mov di, 0h
        mov cx, 4000d
        rep stosw
        mov ax, 6B00h
        int 21h
        
	jmp lp2

	mov ax, 4c00h
	int 21h

end 	Start