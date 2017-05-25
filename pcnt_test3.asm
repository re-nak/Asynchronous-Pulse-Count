;******************************************************************************
; 
;    Filename:       pcnt_test3.asm 
;    Date:           2017.05.24
;    File Version:   1.0
;
;    Author:         RE:NAK
;    URL:            http://smartmeship.blogspot.jp/2017/05/13.html
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
		dtemp		; Delay Count Work
		ltemp		; Loop Count Work
		bcount		; Byte Count
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
	BANKSEL	OSCSTAT
osc_wait
	BTFSS	OSCSTAT,HFIOFL	; Oscillator Locked bit Flag Check
	GOTO	osc_wait
	
;---Debug Only----------
	BANKSEL	PORTA
	BSF	PORTA,RA5	; RA5 On 1
	
	MOVLW	0x02		; Set SSP1BUF Address
	MOVWF	FSR0H		; 
	MOVLW	0x11		; 
	MOVWF	FSR0L		; SSP1BUF Address is 0x0211
	MOVLW	0x02
	MOVWF	bcount		; bcount Set 0x02

	BANKSEL	PIR1
if_wait1
	BTFSS	PIR1,SSP1IF	; SSP Interrupt Flag Check
	GOTO	if_wait1
	
	BCF	PIR1,SSP1IF	; SSP Interrupt Flag Clear
	MOVFW	INDF0		; Dummy Read
	
;---Debug Only----------
	BANKSEL	PORTA
	BCF	PORTA,RA5	; RA5 Off 1

	BANKSEL	SSP1STAT
	BTFSS	SSP1STAT,R_NOT_W	; Skip if Read Mode
	GOTO	wr_mode		; Jump if Write Mode
	
	BANKSEL	SSP1STAT
	BTFSC	SSP1STAT,D_NOT_A	; Skip if Address received
	GOTO	if_wait4	; Jump if Data received

;---Debug Only----------
	BANKSEL	PORTA
	BSF	PORTA,RA5	; RA5 On 2
	
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
;---Debug Only----------
	BANKSEL	PORTA
	BCF	PORTA,RA5	; RA5 Off 2

	BANKSEL	SSP1CON2
	BCF	SSP1CON2,ACKDT	; Clear ACKDT (ACK)
	BSF	SSP1CON1,CKP	; Release the clock
	
	BANKSEL	PIR1
if_wait2
	BTFSS	PIR1,SSP1IF	; SSP Interrupt Flag Check
	GOTO	if_wait2
	
	BCF	PIR1,SSP1IF	; SSP Interrupt Flag Clear
	
;---Debug Only----------
	BANKSEL	PORTA
	BSF	PORTA,RA5	; RA5 On 3
	
	MOVFW	p_count_h2	; Read Back Count Value H2
	BANKSEL	SSP1STAT
bf_wait1
	MOVWF	INDF0		; SSP Buffer Write
	BTFSS	SSP1STAT,BF	; Skip if Buffer Full
	GOTO	bf_wait1	; Loop if Buffer Empty

	BSF	SSP1CON1,CKP	; Release the clock
	
;---Debug Only----------
	BANKSEL	PORTA
	BCF	PORTA,RA5	; RA5 Off 3
	
	BANKSEL	PIR1
if_wait3
	BTFSS	PIR1,SSP1IF	; SSP Interrupt Flag Check
	GOTO	if_wait3

	BCF	PIR1,SSP1IF	; SSP Interrupt Flag Clear
	
;---Debug Only----------
	BANKSEL	PORTA
	BSF	PORTA,RA5	; RA5 On 4
	
	MOVLW	0x04
	MOVWF	ltemp
	MOVFW	p_count_l	; Read Back Count Value L
	BANKSEL	SSP1STAT
bf_wait2
	MOVWF	INDF0		; SSP Buffer Write
	BTFSC	SSP1STAT,BF	; Skip if Buffer EmptyFull
	GOTO	bf_exit2	; Loop if Buffer EmptyFull
	
	DECFSZ	ltemp,F
	GOTO	bf_wait2
	
	BANKSEL	SSP1STAT
	BTFSC	SSP1STAT,P	; Skip if Stop bit Not Detect 
	GOTO	xmit_end	; Jump if Stop bit Detect
	
bf_exit2
	BSF	SSP1CON1,CKP	; Release the clock
	
;---Debug Only----------
	BANKSEL	PORTA
	BCF	PORTA,RA5	; RA5 Off 4
	
if_wait4
	BANKSEL	PIR1
	BTFSS	PIR1,SSP1IF	; SSP Interrupt Flag Check
	GOTO	if_wait4

	BCF	PIR1,SSP1IF	; SSP Interrupt Flag Clear
	
;---Debug Only----------
	BANKSEL	PORTA
	BSF	PORTA,RA5	; RA5 On 5
	
	BANKSEL	SSP1CON2
	BTFSC	SSP1CON2,ACKSTAT	; Skip if ACK Returned
	GOTO	xmit_end	; Jump if NACK Returned

	MOVFW	bcount		; Load bcount to W
	BANKSEL	SSP1STAT
bf_wait3
	MOVWF	INDF0		; SSP Buffer Write
	BTFSS	SSP1STAT,BF	; Skip if Buffer Full
	GOTO	bf_wait3	; Loop if Buffer Empty

	BSF	SSP1CON1,CKP	; Release the clock
;---Debug Only----------
	BANKSEL	PORTA
	BCF	PORTA,RA5	; RA5 Off 2
	INCF	bcount,F	; Increment bcount
	GOTO	if_wait4	; Wait for next data
	
wr_mode
;---Debug Only----------
	BANKSEL	PORTA
	BSF	PORTA,RA5	; RA5 On 2
	
	BANKSEL	SSP1STAT
	BTFSC	SSP1STAT,D_NOT_A	; Skip if Address received
	GOTO	rd_next		; Jump if Data received
	
	BANKSEL	SSP1CON2
	BCF	SSP1CON2,ACKDT	; Clear ACKDT (ACK)
	BSF	SSP1CON1,CKP	; Release the clock
	
;---Debug Only----------
	BANKSEL	PORTA
	BCF	PORTA,RA5	; RA5 Off 2
	
if_wait02
	MOVLW	0x11
	MOVWF	ltemp
wloop02
	BANKSEL	PIR1
	BTFSC	PIR1,SSP1IF	; SSP Interrupt Flag Check
	GOTO	exit_wait02
	
	DECFSZ	ltemp,F
	GOTO	wloop02
	GOTO	xmit_end
	
exit_wait02
	BCF	PIR1,SSP1IF	; SSP Interrupt Flag Clear
	MOVFW	INDF0		; Dummy Read
	
;---Debug Only----------
	BANKSEL	PORTA
	BSF	PORTA,RA5	; RA5 On 3
	
rd_next
	BANKSEL	SSP1CON1
	BSF	SSP1CON1,CKP	; Release the clock

;--- Check STOP Condition
	CALL	Delay30		; Wait 30usec
	BANKSEL	SSP1STAT
	BTFSC	SSP1STAT,P	; Skip if Stop bit Not Detect 
	GOTO	xmit_end	; Jump if Stop bit Detect
	
;---Debug Only----------
	BANKSEL	PORTA
	BCF	PORTA,RA5	; RA5 Off 3
	GOTO	if_wait02
	
xmit_end
;---Debug Only----------
	BANKSEL	PORTA
	BCF	PORTA,RA5	; RA5 Off 5
	
stop_det
	BANKSEL	SSP1BUF		; 
	MOVFW	SSP1BUF		; Dummy Read
	BCF	SSP1CON1,WCOL	; Clear WCOL
	BCF	SSP1CON1,SSPOV	; Clear SSPOV
	BANKSEL	PIR1
	CLRF	PIR1		; Clear PIR1
	BANKSEL INTCON		; 
	MOVLW	b'11000000'	; GIE=1 PEIE=1 IOCIE=0
	MOVWF	INTCON		; Interrrupt Enable

	RETFIE

;------------------------------------------------------------------------------
;  Delay SUB
;------------------------------------------------------------------------------	
Delay30
	MOVLW	0x03
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
	MOVLW	b'01100010'	;  2MHz HFosc
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
	MOVLW	b'00001111'	; Set RA<3>,RA<2>,RA<1>,RA<0> as input
;	MOVLW	b'00101111'	; Set RA<5>,RA<3>,RA<2>,RA<1>,RA<0> as input
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
	MOVLW	B'00000000'	; 
	MOVWF	SSP1STAT	; CKE=0
	MOVLW	b'00110110'	; SSP1EN=1
	MOVWF	SSP1CON1	; CKP=1 SSP1M=[0110] I2C Slave 7bit Address
	MOVLW	b'00000001'	; 
	MOVWF	SSP1CON2	; SEN=1
	MOVLW	b'00011010'	; 
	MOVWF	SSP1CON3	; SCIE=0 BOEN=1 SDAHT=1 AHEN=1 DHEN=0
	MOVLW	b'11001100'	; 
	MOVWF	SSP1ADD		; Slave Address 0x66

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
