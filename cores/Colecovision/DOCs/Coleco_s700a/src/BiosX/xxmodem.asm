
#DEFINE ORG	.ORG
#DEFINE EQU	.EQU
#DEFINE DW	.DW
#DEFINE DB	.DB
#DEFINE DS	.DS
#DEFINE END	.END

; SERIAL I/O
TTI	EQU	$20
TTO	EQU	$20
TTS	EQU	$25
TTYDA	EQU	$01
TTYTR	EQU	$20


  

;CONSTANTS

CTRX	EQU	$24	; CONTROLX
CR	EQU	$0D
SOH	EQU	1	; Start of Header
ACK     EQU     06H     ; Acknowledge
NAK     EQU     15H     ; Negative acknowledge
EOF     EQU     1AH     ; End of file - ^Z
EOT     EQU     04H     ; End of transmission
ERRLIM	EQU	10	; Max allowable errors


;**********************************************************
L006E		EQU	$006E
REST		EQU	$0
READ_CTL	EQU	$1F79
FILL_VRAM	EQU	$1F82
VIDEO_INIT	EQU	$18E9
FONT_INIT	EQU	$1F7F
WRTRGV		EQU	$1FD9
RCOPYV		EQU	$1FBE
COLOR_TAB	EQU	$143B

CARTADD		EQU	$8000
DMABUF		EQU	$7480

;===================================================================LAK		
	ORG	$7000
	NOP
	DS	$5FF
	
	;ORG	$7600
XMODEM: CALL	VIDEO_INIT
	CALL	$1F85	;CVBIOS:MODE 1
	CALL	$1FD6	;CVBIOS:TURN  OFF SOUND
	CALL	CLR_SCR
      
	;SET COLOR
	LD	HL,2000H	
	LD	A,0F4H	;WHITE/BLUE
	LD	DE,32
	CALL	FILL_VRAM  
	CALL    FONT_INIT	;CVBIOS:LOAD ASCII

	LD	DE,$1863
	LD	HL,MSG_XMODEM
	LD	BC,28
	CALL	$1FDF	;WRITE VRAM
	
	LD	DE,$18E3
	LD	HL,MSG_DOWN
	LD	BC,28
	CALL	$1FDF

	;SCREEN ON
	LD	BC,01C2H	
	CALL	WRTRGV	;WRITE REG

KP1	LD	HL,0001
	CALL	READ_CTL
	LD	A,L
	CP	0FH
	JR	Z,KP1
	CP	0AH
	JP	Z,UART_INIT
	CP	0BH
	JP	NZ,L006E

UART_INIT
	LD	DE,$18E3
	LD	HL,MSG_DWNING
	LD	BC,28
	CALL	$1FDF
	
	LD	A,0     ;* INT OFF
        OUT 	($21),A
        LD 	A,$80
        OUT 	($23),A       ;* DLAB
        LD 	A,$23 ;*38400  ;*19200 = $46 *$8b* div hi 21400000/(139*16)=9600 *6500000/(42 * 16)=9600 -use 42
        OUT 	($20),A       
        LD 	A,0      ;* div lo
        OUT 	($21),A
        LD 	A,3      ;* 8,n,1
        OUT 	($23),A
        LD 	A,$0B    ;*TURN ON DTR,RTS,OUT2
        OUT 	($24),A
	JP	XMODEMR


;---------------------
; XMODEM receive routine
;---------------------
; Implements basic XMODEM checksum receive function to allow loading larger
; files from PC with fewer errors.  Code modified from XMODEM v3.2 source
; by Keith Petersen
XMODEMR:
        LD	HL,CARTADD
	LD	(DEST),HL;save destination address
	LD	A,0	; Initialize sector number to zero
	LD	(SECTNO),A	;
	
RCVLP:	
	CALL	RCVSECT	;GET A SECTOR
	JP	C,RCVEOT	;GOT EOT?
	CALL	WRSECT	;WRITE THE SECTOR
	CALL	INCRSNO	;BUMP SECTOR #
	CALL	SENDACK	;ACK THE SECTOR
	JP	RCVLP	;LOOP UNTIL EOF
;
;GOT EOT ON SECTOR - FLUSH BUFFERS, END
;
RCVEOT:	
		
	CALL	SENDACK	;ACK THE SECTOR
	LD	A,'G'
	CALL	SEND		
	JP	L006E

;**** XMODEM SUBROUTINES		
;
;---->	RCVSECT: RECEIVE A SECTOR
;
;RETURNS WITH CARRY SET IF EOT RECEIVED.
;
RCVSECT:
	XOR	A	 ;GET 0
	LD	(ERRCT),A;INIT ERROR COUNT
;
RCVRPT:	
	LD	B,10	;10 SEC TIMEOUT
	CALL	RECV	;GET SOH/EOT
	JP	C,RCVSTOT	;TIMEOUT
	CP	SOH	;GET SOH?
	JP	Z,RCVSOH	;..YES
;
;EARLIER VERS. OF MODEM PROG SENT SOME NULLS -
;IGNORE THEM
;
	OR	A	;00 FROM SPEED CHECK?
	JP	Z,RCVRPT;YES, IGNORE IT
	CP	EOT	;END OF TRANSFER?
	SCF		;RETURN WITH CARRY..
	RET	Z	;..SET IF EOT
;
;DIDN'T GET SOH  OR EOT - 
;
;DIDN'T GET VALID HEADER - PURGE THE LINE,
;THEN SEND NAK.
;
RCVSERR:
	LD	B,1	;WAIT FOR 1 SEC..
	CALL	RECV	;..WITH NO CHARS
	JP	NC,RCVSERR	;LOOP UNTIL SENDER DONE
	LD	A,NAK	;SEND..
	CALL	SEND	;..THE NAK
	LD	A,(ERRCT)	;ABORT IF..
	INC	A	;..WE HAVE REACHED..
	LD	(ERRCT),A	;..THE ERROR..
	CP	ERRLIM	;..LIMIT?
	JP	C,RCVRPT	;..NO, TRY AGAIN
;
;10 ERRORS IN A ROW - 
;
RCVSABT:
	LD	A,'E'
	CALL	SEND
	JP	REST    ;JUMP TO RESET

;
;TIMEDOUT ON RECEIVE
;
RCVSTOT:
	JP	RCVSERR	;BUMP ERR CT, ETC.
;
;GOT SOH - GET BLOCK #, BLOCK # COMPLEMENTED
;
RCVSOH:
	LD	B,1	;TIMEOUT = 1 SEC
	CALL	RECV	;GET SECTOR
	JP	C,RCVSTOT	;GOT TIMEOUT
	LD	D,A	;D=BLK #
	LD	B,1	;TIMEOUT = 1 SEC
	CALL	RECV	;GET CMA'D SECT #
	JP	C,RCVSTOT	;TIMEOUT
	CPL		;CALC COMPLEMENT
	CP	D	;GOOD SECTOR #?
	JP	Z,RCVDATA	;YES, GET DATA
;
;GOT BAD SECTOR #
;
	JP	RCVSERR	;BUMP ERROR CT.
;
RCVDATA:
	LD	A,D	;GET SECTOR #
	LD	(RCVSNO),A;SAVE IT
	LD	C,0	;INIT CKSUM
	LD	HL,DMABUF ;POINT TO BUFFER  
;
RCVCHR:
	LD	B,1	;1 SEC TIMEOUT
	CALL	RECV	;GET CHAR
	JP	C,RCVSTOT	;TIMEOUT
	LD	(HL),A	;STORE CHAR
	INC	L	;DONE?
	JP	NZ,RCVCHR	;NO, LOOP
;
;VERIFY CHECKSUM
;
	LD	D,C	;SAVE CHECKSUM
	LD	B,1	;TIMEOUT LEN.
	CALL	RECV	;GET CHECKSUM
	JP	C,RCVSTOT	;TIMEOUT
	CP	D	;CHECKSUM OK?
	JP	NZ,RCVSERR	;NO, ERROR
;
;GOT A SECTOR, IT'S A DUP IF = PREV,
;	OR OK IF = 1 + PREV SECTOR
;
	LD	A,(RCVSNO);GET RECEIVED
	LD	B,A	;SAVE IT
	LD	A,(SECTNO);GET PREV
	CP	B	;PREV REPEATED?
	JP	Z,RECVACK	;ACK TO CATCH UP
	INC	A	;CALC NEXT SECTOR #
	CP	B	;MATCH?
	JP	NZ,ABORT	;NO MATCH - STOP SENDER, EXIT
	RET		;CARRY OFF - NO ERRORS
;
;PREV SECT REPEATED, DUE TO THE LAST ACK
;BEING GARBAGED.  ACK IT SO SENDER WILL CATCH UP 
;
RECVACK:
	CALL	SENDACK	;SEND THE ACK,
	JP	RCVSECT	;GET NEXT BLOCK
;
;SEND AN ACK FOR THE SECTOR
;
SENDACK:
	LD	A,ACK	;GET ACK
	CALL	SEND	;..AND SEND IT
	RET
;	

ABORT:
	;LXI	SP,STACK
;
ABORTL:
	LD	B,1	;1 SEC. W/O CHARS.
	CALL	RECV
	JP	NC,ABORTL	;LOOP UNTIL SENDER DONE
	LD	A,CTRX	;CONTROL X
	CALL	SEND	;STOP SENDING END
;
ABORTW:
	LD	B,1	;1 SEC W/O CHARS.
	CALL	RECV
	JP	NC,ABORTW	;LOOP UNTIL SENDER DONE
	LD	A,' '	;GET A SPACE...
	CALL	SEND	;TO CLEAR OUT CONTROL X
	JP	REST

;
;---->	INCRSNO: INCREMENT SECTOR #
;
INCRSNO:
	LD	A,(SECTNO);INCR..
	INC	A	;..SECT..
	LD	(SECTNO),A;..NUMBER
	RET

;
;---->	WRSECT: WRITE A SECTOR
;
WRSECT:
	LD	HL,(DEST)	;load destination address to HL
	EX	DE,HL		;put destination address in DE
	LD	HL,DMABUF	;load CPM dma buffer address to HL
	LD	BC,$0080
	LDIR
	EX	DE,HL
	LD	(DEST),HL
	RET
   

;
;---->	RECV: RECEIVE A CHARACTER
;
;TIMEOUT TIME IS IN B, IN SECONDS.  
;
RECV:
	PUSH	DE	;SAVE

MSEC:
	LD	DE,7150  ;50000	;1 SEC DCR COUNT
;
MWTI:
    	IN      A,(TTS)		; IMSAI specific, check input status
    	AND     TTYDA	; ""
    	JP	NZ,MCHAR	;got a char
    
	DEC	E	;COUNT..
	JP	NZ,MWTI	;..DOWN..
	DEC	D	;..FOR..
	JP	NZ,MWTI	;..TIMEOUT
	DEC	B	;MORE SECONDS?
	JP	NZ,MSEC	;YES, WAIT
;
;MODEM TIMED OUT RECEIVING
;
	POP	DE	;RESTORE D,E
	SCF		;CARRY SHOWS TIMEOUT
	RET
;
;GOT CHAR FROM MODEM
;
MCHAR:
    	IN      A,(TTI)	; IMSAI specific, get input byte
	POP	DE	;RESTORE DE
;
;CALC CHECKSUM
;
	PUSH	AF	;SAVE THE CHAR
	ADD	A,C	;ADD TO CHECKSUM
	LD	C,A	;SAVE CHECKSUM
	POP	AF	;RESTORE CHAR
	OR	A	;CARRY OFF: NO ERROR
	RET		;FROM "RECV"
;
;
;---->	SEND: SEND A CHARACTER TO THE MODEM
;
SEND:
	PUSH	AF	;SAVE THE CHAR
;	ADD	A,C	;CALC CKSUM    
;	LD	C,A	;SAVE CKSUM    

SENDW:
	IN	A,(TTS)	; IMSAI specific, Check Console Output Status
    	AND	TTYTR 
	JP	Z,SENDW	;..NO, WAIT
	POP	AF	;GET CHAR
    	OUT	(TTO),A     ; IMSAI specific, Send Data
	RET		;FROM "SEND"

CLR_SCR	XOR	A		; Fill VRAM from address 0000H
	LD	H,A		;   with 00H
	LD	L,A		;
	LD	DE,4000H	;   length 4000H
	CALL	FILL_VRAM	; Do the fill
	RET

RCVSNO	DB	0	; SECT # RECEIVED (XMODEM)
SECTNO	DB	0	; CURRENT SECTOR NUMBER (XMODEM)
ERRCT	DB	0	; ERROR COUNT(XMODEM)
DEST	DW	0	; destination address pointer 2BYTES (XMODEM)  


MSG_XMODEM	DB "XMODEM(CHECKSUM):38400,8,N,1"

MSG_DOWN	DB "PRESS '*' OR '#' TO DOWNLOAD"
MSG_DWNING	DB "    DOWNLOADING...          "	

	DS	$7800-$-1
	DB	$FF
	END
		