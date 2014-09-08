;**********************************************************************
;                                                                     *
;    Filename:	    mtxv4.asm                                         *
;    Date:                                                            *
;    File Version:                                                    *
;                                                                     *
;    Author:        el@jap.hu                                         *
;    Www page:      http://jap.hu/electronic/                         *
;                                                                     * 
;                                                                     *
;**********************************************************************
;    Notes:
;
; RF transmitter prot.v4.2 (Manchester)
;**********************************************************************
;
; header : 20xbit1, 1xbit0
; bytes : 8xbitX, 1xbit1, 1xbit0
;
; packet structure: <data0> <data1> <data2> <checksum>
;
; 020 - library version
; untested!
;
; 021 - add half frame variable
;       remove buffer initialization
;
; 030-20050102 codec-v4.2: 
;              checksum with CRC-8
;              T=350 usec
;              3-byte buffer length
;
;**********************************************************************

;define TXINV
;invert TX output so inactive is HIGH?

	list      p=16F628
	#include <p16F628.inc>

txbit	EQU 0x01
txport	EQU PORTA

#ifndef TXINV
#define TXLOW 0
#define TXHIGH txbit
#else
#define TXLOW txbit
#define TXHIGH 0
#endif

	GLOBAL mtx_buffer, mtx_init, mtx_send, mtx_delay

packet_len	EQU 2

;***** VARIABLE DEFINITIONS
mtxdata		UDATA

count1		res 1
count2		res 1
ncnt		res 1
bt		res 1
sum		res 1
mtx_buffer	res 2

mtx_delay	res 1 ; half_frame delay

;**********************************************************************

mtx		CODE

mtx_init	movlw .117 ; 350 usec
		movwf mtx_delay
		return
		;

mtx_send
		; send out buffer
outbuf		movlw 0x14 ; 20xbit1, 1xbit0

header		movwf count2
head0		call bit1
		decfsz count2,F
		goto head0
		call bit0

		movlw mtx_buffer
		movwf FSR
		movlw packet_len
		movwf count1
		movlw 0xff
		movwf sum
		;
outbu0		movf INDF,W
		call update_sum
		movf INDF,W
		call outbyte
		incf FSR,F
		decfsz count1,F
		goto outbu0
		movf sum,W
		call outbyte
		; buffer is sent

		return

update_sum	; fast CRC-8 algorithm with poly x^8+x^5+x^4+1
		; executes in 23 cycles per update

		xorwf	sum,f
		clrw
		btfsc	sum,7
		xorlw	0x7a
		btfsc	sum,6
		xorlw	0x3d
		btfsc	sum,5
		xorlw	0x86
		btfsc	sum,4
		xorlw	0x43
		btfsc	sum,3
		xorlw	0xb9
		btfsc	sum,2
		xorlw	0xc4
		btfsc	sum,1
		xorlw	0x62
		btfsc	sum,0
		xorlw	0x31
		movwf	sum
		return
		;
outbyte		movwf bt
		movlw 8
		movwf count2
outby0		rlf bt,F
		btfsc STATUS,C
		goto outby1
		call bit0
		goto outby2
outby1		call bit1
outby2		decfsz count2,F
		goto outby0
		;
		call bit1
		; and bit0

bit0		movlw TXHIGH ; HIGH
		movwf txport

ndelaya0	movf mtx_delay, W
		movwf ncnt
ndelaya1	decfsz ncnt, F
		goto ndelaya1

		movlw TXLOW ; to LOW transition
		movwf txport

ndelayb0	movf mtx_delay, W
		movwf ncnt
ndelayb1	decfsz ncnt, F
		goto ndelayb1

		return

bit1		movlw TXLOW ; LOW
		movwf txport

ndelayc0	movf mtx_delay, W
		movwf ncnt
ndelayc1	decfsz ncnt, F
		goto ndelayc1

		movlw TXHIGH ; to HIGH transition
		movwf txport

ndelaye0	movf mtx_delay, W
		movwf ncnt
ndelaye1	decfsz ncnt, F
		goto ndelaye1

		return

		end

