;
; LEDSonicSensor.asm
;
; Created: 12/9/2021 2:52:16 PM
; Author : JieZhou
;

; Interrupt vector table
; ---------------------------------------------------------
.org 0x00                     ; reset
     jmp  main

.org INT_VECTORS_SIZE


main:
     ldi  r16,low(RAMEND)
     out  SPL,r16
     ldi  r16,high(RAMEND)
     out  SPH,r16




     call ultrasonicInit      ; initialize ultrasonic sensor pins

take_reading:                 ; keep taking readings.
     call ultrasonicReading
     
     jmp  main
end_main:
    rjmp end_main



.include "Ultrasonic.asm"
