;**********************************************************************
;                                                                     *
;    Filename:	    encoder.asm                                       *
;    Date:                                                            *
;    File Version:                                                    *
;                                                                     *
;    Author:        Peter Jakab <el@jap.hu>                           *
;                   http://jap.hu/electronic/                         *
;**********************************************************************
;NOTES
;encoder v4.2
;
;**********************************************************************
;HISTORY
;
; 040-20050131 4/8-channel encoder for 16F630
; 041-20050213
; 042-20050217 modify transmission repetition algorithm
; 043-20050227 use IR medium with irmtxv4 library
; 044-20090531 adapt 042-20050227 to the pic16f628
;
;**********************************************************************
	list	p=16f628
	__CONFIG   _CP_OFF & _WDT_OFF & _PWRTE_ON & _INTRC_OSC_NOCLKOUT & _LVP_OFF & _MCLRE_OFF & _BODEN_OFF


; toggle or momentary mode, 8 channels
; #define MODE_CH8

; ON/OFF latched mode, 4 channels
#define MODE_CH4

#include <p16F628.inc>
#include <mtxv4.inc>

variables	UDATA
; RAM registers
tcnt		RES 1
rcnt		RES 1
cod		RES 1
prevcod		RES 1
cod0		RES 1
rowstate	RES 1

startup		CODE 0
  		goto main
		nop
		nop
		nop
		retfie

prog		CODE

main		; program starts here
		clrf PORTA
		clrf PORTB
		clrf TMR0

		BANKSEL TRISA
		movlw 0
		movwf TRISA
		movlw 0xf0
		movwf TRISB

		bcf OPTION_REG, PSA
		clrwdt
		clrf OPTION_REG
		clrwdt

		BANKSEL PORTA
		movlw 7
		movwf CMCON
		movlw (1<<RBIE); RB4-7 int on change enable
		movwf INTCON

		call mtx_init
		clrf mtx_buffer
		clrf tcnt

loop0		clrf (mtx_buffer+1)
		movlw 0xff
		movwf prevcod ; no button was pressed in the previous scan
		movlw 0xfc ;ca,cb=0,cj=1
		movwf PORTB
		movlw 0xf0
		tris PORTB
		movf PORTB, W
		bcf INTCON, RBIF
		sleep

loop		clrf cod
		movlw 0xfe
		tris PORTB ; select colA (RB0)
		clrf PORTB
#ifdef MODE_CH8
		clrw
#endif
#ifdef MODE_CH4
		movlw 0x20
#endif
		call scan
		movlw 0xfd
		tris PORTB ; select colB (RB1)
#ifdef MODE_CH8
		movlw 0x04
#endif
#ifdef MODE_CH4
		movlw 0x30
#endif
		call scan
		movf cod, W
		bz loop2 ; if no buton is pressed, skip

		subwf prevcod, W ; if the same button is pressed, skip
		bz loop2

		movf cod, W
		movwf prevcod ; a new button is pressed - rcnt=3
		movwf (mtx_buffer+1)
		movlw 3
		movwf rcnt

		movlw 0x40 ; new button - new transmission
		addwf tcnt, F

loop2		movlw 0xf7
		tris PORTB ; select ID (RB3)
		call scanid
		movf cod0, W
		movwf (mtx_buffer)

loop3		movf (mtx_buffer+1), W
		andlw 0x3f
		iorwf tcnt, W
		movwf (mtx_buffer+1)

		call mtx_send

		movf rcnt, W
		bz loop_done
		decfsz rcnt, F
		goto loop

loop_done	movf cod, W
		btfsc STATUS, Z
		goto loop0 ; no button was pressed, go sleep
		; if the same button is being hold, repeat the transmission
		goto loop

scan		movwf cod0
		;movlw 0xc0
scandelay	;addlw 1
		;bnz scandelay
		movlw 0xf0
		andwf PORTB, W
		movwf rowstate

		incf cod0, F
		btfss rowstate, 4
		goto pressed

		incf cod0, F
		btfss rowstate, 5
		goto pressed

		incf cod0, F
		btfss rowstate, 6
		goto pressed

		incf cod0, F
		btfss rowstate, 7
		goto pressed
		retlw 0

pressed		movf cod0, W
		movwf cod
		return

scanid		clrf cod0
		clrw
scandelay2	addlw 1
		bnz scandelay2
		movlw 0xf0
		andwf PORTB, W
		movwf rowstate

		btfss rowstate, 7
		bsf cod0, 3
		btfss rowstate, 6
		bsf cod0, 2
		btfss rowstate, 5
		bsf cod0, 1
		btfss rowstate, 4
		bsf cod0, 0
		return

		end
