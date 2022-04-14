/*
 * delay.asm
 *
 *  Created: 12/9/2021 6:27:47 PM
 *   Author: Jie Zhou
 */ 
T1Normal:

ldi r22,0xB6
ldi r23,0xC2
sts TCNT1H,r22 ;high 48
sts TCNT1L,r23 ;low e5

clr r24
sts TCCR1A,r24 ;set normal


ldi r25,0x05
sts TCCR1B,r25


clr r24
sts TCCR1B,r24 ; clear clock select bits


sbi TIFR1,TOV1 ; clear overflow flag by setting it to 1 (INTERNALLY CLEARS WHEN SET TO 1)


ret ; end T0Normal