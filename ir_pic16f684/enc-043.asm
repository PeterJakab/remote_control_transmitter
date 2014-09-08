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
;
;**********************************************************************
	list	p=16f684
	__CONFIG   _CP_OFF & _WDT_OFF & _PWRTE_ON & _MCLRE_OFF & _INTRC_OSC_NOCLKOUT & _BOD_OFF & _FCMEN_OFF & _IESO_OFF

; toggle or momentary mode, 8 channels
#define MODE_CH8

; ON/OFF latched mode, 4 channels
;define MODE_CH4

#include <p16F684.inc>
#include <irmtxv4.inc>

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
		movlw 7
		movwf CMCON0 ; set outputs digital
		BANKSEL ANSEL
		clrf ANSEL
		movlw 0x17
		movwf TRISA
		clrf TRISC
		movwf WPUA
		movwf IOCA
		clrf TMR0
		bcf OPTION_REG, PSA
		clrwdt
		movlw (0<<NOT_RAPU)|(0<<T0CS)|(0<<INTEDG)|(0<<PSA)|(0x07)
		movwf OPTION_REG ; portA pullups enabled
		clrwdt

		BANKSEL PORTA
		clrf PORTA
		clrf PORTC
		movlw (1<<RAIE); RA int on change enable
		movwf INTCON

		call mtx_init
		clrf mtx_buffer
		clrf tcnt

loop0		clrf (mtx_buffer+1)
		movlw 0xff
		movwf prevcod ; no button was pressed in the previous scan
		movlw 0x1c ;c0,c1=0,c3=1
		movwf PORTC
		movlw 0x00
		tris PORTC
		movf PORTA, W
		bcf INTCON, RAIF
		sleep

loop		clrf cod
		movlw 0x1d
		tris PORTC ; select colA (RC1)
		clrf PORTC
#ifdef MODE_CH8
		clrw
#endif
#ifdef MODE_CH4
		movlw 0x20
#endif
		call scan
		movlw 0x1e
		tris PORTC ; select colB (RC0)
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

loop2		movlw 0x17
		tris PORTC ; select ID (RC3)
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
		movlw 0x17
		andwf PORTA, W
		movwf rowstate

		incf cod0, F
		btfss rowstate, 2
		goto pressed

		incf cod0, F
		btfss rowstate, 4
		goto pressed

		incf cod0, F
		btfss rowstate, 0
		goto pressed

		incf cod0, F
		btfss rowstate, 1
		goto pressed
		retlw 0

pressed		movf cod0, W
		movwf cod
		return

scanid		clrf cod0
		clrw
scandelay2	addlw 1
		bnz scandelay2
		movlw 0x17
		andwf PORTA, W
		movwf rowstate

		btfss rowstate, 4
		bsf cod0, 3
		btfss rowstate, 0
		bsf cod0, 2
		btfss rowstate, 2
		bsf cod0, 1
		btfss rowstate, 1
		bsf cod0, 0
		return

		end
