;******************************************************************************
; 
;    Filename:       pcnt_test2.asm 
;    Date:           2017.05.22
;    File Version:   1.0
;
;    Author:         RE:NAK
;    URL:            http://smartmeship.blogspot.jp/2017/05/12.html
;
;******************************************************************************

	list		p=12f1822      ; list directive to define processor
	#include	<p12f1822.inc> ; processor specific variable definitions

;------------------------------------------------------------------------------
;
; CONFIGURATION WORD SETUP
;
; The 'CONFIG' directive is used to embed the configuration word within the 
; .asm file. The lables following the directive are located in the respective 
; .inc file.  See the data sheet for additional information on configuration 
; word settings.
;
;------------------------------------------------------------------------------    

    __CONFIG _CONFIG1, _FOSC_INTOSC & _WDTE_OFF & _PWRTE_ON & _MCLRE_OFF & _CP_OFF & _CPD_OFF & _BOREN_OFF & _CLKOUTEN_OFF & _IESO_OFF & _FCMEN_OFF
    __CONFIG _CONFIG2, _WRT_OFF & _PLLEN_OFF & _STVREN_ON & _BORV_LO & _LVP_ON

;------------------------------------------------------------------------------
; VARIABLE DEFINITIONS
;
; Available Data Memory divided into Bank 0-15.  Each Bank may contain 
; Special Function Registers, General Purpose Registers, and Access RAM 
;
;------------------------------------------------------------------------------

	CBLOCK	0x70		; Common RAM
		p_count_h1	; Count Value High Byte 1
		p_count_h2	; Count Value High Byte 2
		p_count_l	; Count Value Low Byte
		cmd_code	; SPI Command Code
		dtemp		; Delay Count Work
	ENDC

;------------------------------------------------------------------------------
; EEPROM INITIALIZATION
;
; The 12F1822 has 256 bytes of non-volatile EEPROM, starting at address 0xF000
; 
;------------------------------------------------------------------------------
;
;DATAEE    ORG  0xF000
;    DE    "MCHP"  ; Place 'M' 'C' 'H' 'P' at address 0,1,2,3
;
;------------------------------------------------------------------------------
; RESET VECTOR
;------------------------------------------------------------------------------

	ORG		0x0000	; processor reset vector
	GOTO	init		; When using debug header, first inst.
						; may be passed over by ICD2.  

;------------------------------------------------------------------------------
; INTERRUPT SERVICE ROUTINE
;------------------------------------------------------------------------------

	ORG		0x0004
;------------------------------------------------------------------------------
; USER INTERRUPT SERVICE ROUTINE GOES HERE
;------------------------------------------------------------------------------

; Note the 12F1822 family automatically handles context restoration for 
; W, STATUS, BSR, FSR, and PCLATH where previous templates for 16F families
; required manual restoration

	BANKSEL INTCON		; 
	CLRF	INTCON		; Interrrupt Disable

	BANKSEL	PIR1
	BTFSC	PIR1,SSP1IF	; SSP Interrupt Flag Check
	GOTO	ssp1_isr
	
	BANKSEL	PIR1		; 
	BCF	PIR1,SSP1IF	; SSP Interrupt Flag Clear
	BANKSEL INTCON		; 
	MOVLW	b'11000000'	; GIE=1 PEIE=1 IOCIE=0
	MOVWF	INTCON		; Interrrupt Enable

	RETFIE			; return from interrupt	

;------------------------------------------------------------------------------
;  SSP1 Interupt Service Routine
;------------------------------------------------------------------------------
ssp1_isr
	MOVLW	0x02		; Set SSP1BUF Address
	MOVWF	FSR0H		; 
	MOVLW	0x11		; 
	MOVWF	FSR0L		; SSP1BUF Address is 0x0211
	
;--- Wait for 1st SS Disable ---
ssh_wait1
	BANKSEL	PORTA
	BTFSS	PORTA,RA0	; Skip if SS is High
	GOTO	ssh_wait1	; Loop if SS is Low
	
;--- Wait for End of Command's 1st Byte
	MOVFW	INDF0		; Dummy Read
	BANKSEL	PIR1
	BCF	PIR1,SSP1IF	; SSP Interrupt Flag Clear
rbuf_loop2
	BTFSS	PIR1,SSP1IF	; Skip if Buffer Full
	GOTO	rbuf_loop2	; Loop if Buffer Empty
	
;--- Command Check ---------
	MOVFW	INDF0		; SSP Buffer Read
	XORLW	0x66		; Command = 0x66?
	BTFSC	STATUS,Z	; Skip if Command <> 0x66
	GOTO	ssh_wait2	; Jump if Command = 0x66
	
;--- Wait for 2nd SS Disable ---
ssh_wait_ng1
	BANKSEL	PORTA
	BTFSS	PORTA,RA0	; Skip if SS is High
	GOTO	ssh_wait_ng1	; Loop if SS is Low

	MOVFW	INDF0		; Dummy Read
	BANKSEL	PIR1
	BCF	PIR1,SSP1IF	; SSP Interrupt Flag Clear
rbuf_loop_ng
	BTFSS	PIR1,SSP1IF	; Skip if Buffer Full
	GOTO	rbuf_loop_ng	; Loop if Buffer Empty
	GOTO	ssh_wait4	; Jump to Ending
	
;--- Wait for 2nd SS Disable ---
ssh_wait2
	BANKSEL	PORTA
	BTFSS	PORTA,RA0	; Skip if SS is High
	GOTO	ssh_wait2	; Loop if SS is Low

	CALL	Delay10		; 10usec Wait

;--- Timer Count Read ---
	BANKSEL	TMR1H		; TIMER1 Higt Byte 1
	MOVFW	TMR1H		; TMR1H -> W
	MOVWF	p_count_h1	; Save Count Value H1
	MOVFW	TMR1L		; TMR1L -> W
	MOVWF	p_count_l	; Save Count Value L
	MOVFW	TMR1H		; TMR1H -> W (check carry)
	MOVWF	p_count_h2	; Save Count Value H2

	XORWF	p_count_h1,W	; Compare TMR1H
	BTFSC	STATUS,Z	; Skip if <>
	GOTO	no_carry

	MOVFW	TMR1L		; TMR1L -> W
	MOVWF	p_count_l	; Save Count Value L(changed)

no_carry
	MOVFW	INDF0		; Dummy Read
	MOVFW	p_count_h2	; Read Back Count Value H2
	MOVWF	INDF0		; SSP Buffer Write
	
	BANKSEL	PIR1
	BCF	PIR1,SSP1IF	; SSP Interrupt Flag Clear
rbuf_loop3
	BTFSS	PIR1,SSP1IF	; Skip if Buffer Full
	GOTO	rbuf_loop3	; Loop if Buffer Empty

;--- Wait for 3rd SS Disable ---
ssh_wait3
	BANKSEL	PORTA
	BTFSS	PORTA,RA0	; Skip if SS is High
	GOTO	ssh_wait3	; Loop if SS is Low

	CALL	Delay10		; 10usec Wait

	MOVFW	INDF0		; Dummy Read
	MOVFW	p_count_l	; Read Back Count Value L
	MOVWF	INDF0		; SSP Buffer Write

	BANKSEL	PIR1
	BCF	PIR1,SSP1IF	; SSP Interrupt Flag Clear
rbuf_loop4
	BTFSS	PIR1,SSP1IF	; Skip if Buffer Full
	GOTO	rbuf_loop4	; Loop if Buffer Empty

;--- Wait for 4th SS Disable ---
ssh_wait4
	BANKSEL	PORTA
	BTFSS	PORTA,RA0	; Skip if SS is High
	GOTO	ssh_wait4	; Loop if SS is Low

	MOVFW	INDF0		; Dummy Read
	BANKSEL	PIR1
	CLRF	PIR1		; Clear PIR1
	BANKSEL INTCON		; 
	MOVLW	b'11000000'	; GIE=1 PEIE=1 IOCIE=0
	MOVWF	INTCON		; Interrrupt Enable

	RETFIE

;------------------------------------------------------------------------------
;  Delay SUB
;------------------------------------------------------------------------------	
Delay10
	MOVLW	0x05
	MOVWF	dtemp
dloop
	DECFSZ	dtemp,F
	GOTO	dloop
	RETURN

;------------------------------------------------------------------------------
;  MAIN PROGRAM
;------------------------------------------------------------------------------
init
	banksel	OSCCON
	movlw	b'01110010'	;  8MHz HFosc
	MOVWF	OSCCON
	MOVLW	b'00000000'	;
	MOVWF	OSCTUNE
	
	BANKSEL	PORTA		; set up port A
	CLRF	PORTA		; Init PORTA
	BANKSEL	LATA		; Data Latch
	CLRF	LATA		;
	BANKSEL	ANSELA		;
	CLRF	ANSELA		; digital I/O
	BANKSEL	TRISA		;
	MOVLW	b'00101111'	; Set RA<5>,RA<3>,RA<2>,RA<1>,RA<0> as input
	MOVWF	TRISA 		; and set RA<4> as outputs

	BANKSEL	APFCON		; ALTERNATE PIN FUNCTION CONTROL REGISTER
	MOVLW	b'01100100'	; 
	MOVWF	APFCON		; RX:RA1 TX:RA0

	BANKSEL	T1CON		; TIMER1 CONTROL REGISTER
	MOVLW	b'10000101'	; TMR1CS=[10],Prescale[1:1],T1OSCEN=0,T1SYNC=1
	CLRF	TMR1H		; Clear TMR1H
	CLRF	TMR1L		; Clear TMR1L
	MOVWF	T1CON		; TIMER1 ON

	BANKSEL	SSP1STAT	; SSP1 STATUS REGISTER
	MOVLW	B'01000000'	; 
	MOVWF	SSP1STAT	; CKE=1
	MOVLW	b'00000000'	; 
	MOVWF	SSP1CON3	; BOEN=0
	MOVLW	b'00100100'	; SSP1EN=1
	MOVWF	SSP1CON1	; SSP1M=[0100]

	BANKSEL	SSP1BUF		; 
	MOVFW	SSP1BUF		; Dummy Read
	BCF	SSP1CON1,WCOL	; Clear WCOL
	BCF	SSP1CON1,SSPOV	; Clear SSPOV
	
	BANKSEL	PIR1		; 
	CLRF	PIR1		; Flag Clear
	BANKSEL	PIE1		; 
	BSF	PIE1,SSP1IE	; Enable the MSSP interrrupt
	BANKSEL INTCON		; 
	MOVLW	b'11000000'	; GIE=1 PEIE=1 IOCIE=0
	MOVWF	INTCON		; Interrrupt Enable

start
	NOP
	SLEEP			; Goto Power Down Mode
	NOP
	GOTO	start

	END
