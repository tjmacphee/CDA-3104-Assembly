; 
; Ultrasonic.asm
; 
; Author: P.Allen
; Purpose: Library for an HCSR04 Ultrasonic Ranging Module
;
;changed by Jie Zhou


; 1.) Configure the following GPIO: 
.equ USDIR = DDRD             ; sensor direction register
.equ USOUT = PORTD            ; sensor output register
.equ USIN  = PIND             ; sensor input register
.equ echo  = PD7              ; echo pin
.equ trig  = PD6              ; trigger pin
;
; 2.) call ultrasonicInit to configure the trigger and echo pins
; 3.) call ultrasonicReading to take a reading
;     distance is returned as 2-byte value in centimeters 
;     in R25:R24
; ---------------------------------------------------------


ultrasonicInit:
; configure trigger and echo pins
; ---------------------------------------------------------
     sbi  USDIR,trig          ; trigger pin output
     cbi  USDIR,echo          ; echo pin input

     ret

 
ultrasonicReading:
; takes a reading from the sensor and returns the distance
; in centimeters.
; ---------------------------------------------------------
     ; clear trigger pin condition

     sbi  DDRB, DDB5          ;set to output for LED
     sbi  DDRB, DDB4
     sbi  DDRB, DDB3

     cbi  USOUT,trig
     ldi  r16,2
     call ultrasonicDelay     ; ultrasonicDelay(2)

     ; set trigger pin HIGH(ACTIVE) for 10us
     sbi  USOUT,trig
     ldi  r16,10
     call ultrasonicDelay     ; ultrasonicDelay(10)
     cbi  USOUT,trig

     call pulse_in            ; result comes back in r25:r24
     call get_distance        ; result comes back in r25:r24

     ret


ultrasonicDelay:
; ---------------------------------------------------------
; loop for n microseconds delay
; ---------------------------------------------------------     
     ; multiply 2^4=16 for 16MHZ/cycle
     lsl  r16
     lsl  r16
     lsl  r16
     lsl  r16

delay_us:
     dec  r16
     brne delay_us

     ret


pulse_in:
; ---------------------------------------------------------
; Parameters:
;
; Locals:
.def tmOut3 = r21             ; timeout counter
.def tmOut2 = r20
.def tmOut1 = r19
.def tmOut0 = r18
;
; Returns:
.def pulseH = r25             ; pulse counter
.def pulseL = r24
; ---------------------------------------------------------    
     push tmOut3
     push tmOut2
     push tmOut1
     push tmOut0

     ; reset timout to -1
     clr  tmOut3
     clr  tmOut2
     ldi  tmOut1,$FF
     ldi  tmOut0,$FF

     ; init pulse counter
     clr  pulseH
     clr  pulseL

     ; wait until previous high state clears
pulse_prev:
     sbis USIN,echo           ; if (pin HIGH) check timeout
     rjmp pulse_wait     
     
     ; update timeout
     subi tmOut0,1
     sbci tmOut1,0
     sbci tmOut2,0
     sbci tmOut3,0

     ; check for timeout
     tst  tmOut3
     brne pulse_prev
     tst  tmOut2
     brne pulse_prev
     tst  tmOut1
     brne pulse_prev
     tst  tmOut0
     brne pulse_prev
     rjmp pulse_timeout       ; no timeout

     ; wait for start of pulse
pulse_wait:
     sbic USIN,echo           ; if (pin HIGH) start reading
     rjmp pulse_read
     ; update timeout
     subi tmOut0,1
     sbci tmOut1,0
     sbci tmOut2,0
     sbci tmOut3,0

     ; check for timeout
     tst  tmOut3
     brne pulse_wait
     tst  tmOut2
     brne pulse_wait
     tst  tmOut1
     brne pulse_wait
     tst  tmOut0
     brne pulse_wait
     rjmp pulse_timeout       ; no timeout
     
     ; wait for start of pulse
pulse_read:
     sbis USIN,echo           ; if (pin LOW) read completed
     rjmp pulse_done

     adiw pulseL,1            ; increment pulse counter

     ; check for timeout
     ; update timeout
     subi tmOut0,1
     sbci tmOut1,0
     sbci tmOut2,0
     sbci tmOut3,0

     ; check for timeout
     tst  tmOut3
     brne pulse_read
     tst  tmOut2
     brne pulse_read
     tst  tmOut1
     brne pulse_read
     tst  tmOut0
     brne pulse_read
     rjmp pulse_timeout       ; no timeout

pulse_done:     
     ; convert cycles to microseconds
     ; the read loop takes approx 8 cycles,
     ; so each pulse is 8 * 0.0625 or 0.5us
     ; we can add the pulse counter to itself
     ; to multiply it by 2
     lsl  pulseH
     lsl  pulseL
     brcc pulse_to_clk
     inc  pulseH              ; add carry to high-byte
pulse_to_clk:

     rjmp pulse_ret

pulse_timeout:                ; return 0
     clr  pulseH
     clr  pulseL
     
pulse_ret:
     ; restore local registers
     pop  tmOut0
     pop  tmOut1
     pop  tmOut2
     pop  tmOut3

     ret                      ; return pulse count


get_distance:
; ---------------------------------------------------------
; Parameters:
.def durH = r25               ; duration passed in
.def durL = r24
;
; Locals:
.def tabH = r7                ; table data 
.def tabL = r6                
.def distH = r27              ; distance calculation
.def distL = r26
; ZH:ZL                       ; pointer to durations table
;
; Returns:
; r25:r24                     ; distance
; ---------------------------------------------------------
     push tabH                ; push table data on stack
     push tabL
     push distH               ; distance calculation on stack
     push distL
     push ZH                  ;Z POINTER to durations table on stack
     push ZL

     clr  distH               ;CLEAR HIGH BYTE
     ldi  distL,1             ;DISTANCE 00000001

     tst  durH                ; if (durH > 0)     Test for Zero or Minus
     brne dist_find           ;   start getting distance
     tst  durL                ; else if (durL == 0)
     breq dist_done           ;   return
     
dist_find:
     ldi  ZH,high(DURATIONS<<1)
     ldi  ZL,low(DURATIONS<<1)

dist_next:
     cbi  PORTB, PB4 
     cbi  PORTB, PB5
     cbi  PORTB, PB3

     lpm  tabL,Z+
     lpm  tabH,Z+

     cp   tabH,durH           ; while (durationH >= tableH )
     brlo dist_inc            ;  increment
     cp   tabL,durL           ; else if (durationL >= tableL)
     brlo dist_inc            ;  increment
     rjmp dist_done           ; else return
dist_nextY:
     cbi  PORTB, PB4 
     cbi  PORTB, PB3          ;turn the other two off
 
     sbi  PORTB, PB5          ;turn LED on


     lpm  tabL,Z+
     lpm  tabH,Z+

     cp   tabH,durH           ; while (durationH >= tableH )
     brlo dist_inc            ;  increment
     cp   tabL,durL           ; else if (durationL >= tableL)
     brlo dist_inc            ;  increment
     rjmp dist_done           ; else return
dist_nextG:
     cbi  PORTB, PB5
     cbi  PORTB, PB3     ;turn the other two off

     
     sbi  PORTB, PB4          ;turn LED on
     

     lpm  tabL,Z+
     lpm  tabH,Z+

     cp   tabH,durH           ; while (durationH >= tableH )
     brlo dist_inc            ;  increment
     cp   tabL,durL           ; else if (durationL >= tableL)
     brlo dist_inc            ;  increment
     rjmp dist_done           ; else return

dist_nextW:

     cbi  PORTB, PB4 
     cbi  PORTB, PB5          ;turn the other two off

     sbi  PORTB, PB3          ;turn LED on
     call T1Normal

     lpm  tabL,Z+
     lpm  tabH,Z+

     cp   tabH,durH           ; while (durationH >= tableH )
     brlo dist_inc            ;  increment
     cp   tabL,durL           ; else if (durationL >= tableL)
     brlo dist_inc            ;  increment
     rjmp dist_done           ; else return
       
dist_inc:
                 
     adiw distL,1             ; distance += 1cm

 
     ;difference duration for different LED
     cpi  distH,high(15)
     brlo dist_nextY
     cpi  distL,low(15)
     brlo dist_nextY

     cpi  distH,high(40)
     brlo dist_nextG
     cpi  distL,low(40)
     brlo dist_nextG

     cpi  distH,high(100)
     brlo dist_nextW
     cpi  distL,low(100)
     brlo dist_nextW

     ; check for duration greater than max
     cpi  distH,high(450)
     brlo dist_next
     cpi  distL,low(450)
     brlo dist_next 



     ; return 0 when > max
     clr  distH
     clr  distL

dist_done:
     mov  r25,distH           ; move distance to return 
     mov  r24,distL           ; registers

     pop  ZL
     pop  ZH
     pop  distL
     pop  distH
     pop  tabL
     pop  tabH

     ret                      ; distance - r25:r24



; ---------------------------------------------------------
; table of ultrasonic sensor durations from 1cm-450cm
; Calcuate: Duration = 29us * 2 (round-trip time) per cm
;           distance in cm = index where duration > table - 1
; ---------------------------------------------------------
DURATIONS:                         
.dw 58
.dw 116
.dw 174
.dw 232
.dw 290
.dw 348
.dw 406
.dw 464
.dw 522
.dw 580
.dw 638
.dw 696
.dw 754
.dw 812
.dw 870
.dw 928
.dw 986
.dw 1044
.dw 1102
.dw 1160
.dw 1218
.dw 1276
.dw 1334
.dw 1392
.dw 1450
.dw 1508
.dw 1566
.dw 1624
.dw 1682
.dw 1740
.dw 1798
.dw 1856
.dw 1914
.dw 1972
.dw 2030
.dw 2088
.dw 2146
.dw 2204
.dw 2262
.dw 2320
.dw 2378
.dw 2436
.dw 2494
.dw 2552
.dw 2610
.dw 2668
.dw 2726
.dw 2784
.dw 2842
.dw 2900
.dw 2958
.dw 3016
.dw 3074
.dw 3132
.dw 3190
.dw 3248
.dw 3306
.dw 3364
.dw 3422
.dw 3480
.dw 3538
.dw 3596
.dw 3654
.dw 3712
.dw 3770
.dw 3828
.dw 3886
.dw 3944
.dw 4002
.dw 4060
.dw 4118
.dw 4176
.dw 4234
.dw 4292
.dw 4350
.dw 4408
.dw 4466
.dw 4524
.dw 4582
.dw 4640
.dw 4698
.dw 4756
.dw 4814
.dw 4872
.dw 4930
.dw 4988
.dw 5046
.dw 5104
.dw 5162
.dw 5220
.dw 5278
.dw 5336
.dw 5394
.dw 5452
.dw 5510
.dw 5568
.dw 5626
.dw 5684
.dw 5742
.dw 5800
.dw 5858
.dw 5916
.dw 5974
.dw 6032
.dw 6090
.dw 6148
.dw 6206
.dw 6264
.dw 6322
.dw 6380
.dw 6438
.dw 6496
.dw 6554
.dw 6612
.dw 6670
.dw 6728
.dw 6786
.dw 6844
.dw 6902
.dw 6960
.dw 7018
.dw 7076
.dw 7134
.dw 7192
.dw 7250
.dw 7308
.dw 7366
.dw 7424
.dw 7482
.dw 7540
.dw 7598
.dw 7656
.dw 7714
.dw 7772
.dw 7830
.dw 7888
.dw 7946
.dw 8004
.dw 8062
.dw 8120
.dw 8178
.dw 8236
.dw 8294
.dw 8352
.dw 8410
.dw 8468
.dw 8526
.dw 8584
.dw 8642
.dw 8700
.dw 8758
.dw 8816
.dw 8874
.dw 8932
.dw 8990
.dw 9048
.dw 9106
.dw 9164
.dw 9222
.dw 9280
.dw 9338
.dw 9396
.dw 9454
.dw 9512
.dw 9570
.dw 9628
.dw 9686
.dw 9744
.dw 9802
.dw 9860
.dw 9918
.dw 9976
.dw 10034
.dw 10092
.dw 10150
.dw 10208
.dw 10266
.dw 10324
.dw 10382
.dw 10440
.dw 10498
.dw 10556
.dw 10614
.dw 10672
.dw 10730
.dw 10788
.dw 10846
.dw 10904
.dw 10962
.dw 11020
.dw 11078
.dw 11136
.dw 11194
.dw 11252
.dw 11310
.dw 11368
.dw 11426
.dw 11484
.dw 11542
.dw 11600
.dw 11658
.dw 11716
.dw 11774
.dw 11832
.dw 11890
.dw 11948
.dw 12006
.dw 12064
.dw 12122
.dw 12180
.dw 12238
.dw 12296
.dw 12354
.dw 12412
.dw 12470
.dw 12528
.dw 12586
.dw 12644
.dw 12702
.dw 12760
.dw 12818
.dw 12876
.dw 12934
.dw 12992
.dw 13050
.dw 13108
.dw 13166
.dw 13224
.dw 13282
.dw 13340
.dw 13398
.dw 13456
.dw 13514
.dw 13572
.dw 13630
.dw 13688
.dw 13746
.dw 13804
.dw 13862
.dw 13920
.dw 13978
.dw 14036
.dw 14094
.dw 14152
.dw 14210
.dw 14268
.dw 14326
.dw 14384
.dw 14442
.dw 14500
.dw 14558
.dw 14616
.dw 14674
.dw 14732
.dw 14790
.dw 14848
.dw 14906
.dw 14964
.dw 15022
.dw 15080
.dw 15138
.dw 15196
.dw 15254
.dw 15312
.dw 15370
.dw 15428
.dw 15486
.dw 15544
.dw 15602
.dw 15660
.dw 15718
.dw 15776
.dw 15834
.dw 15892
.dw 15950
.dw 16008
.dw 16066
.dw 16124
.dw 16182
.dw 16240
.dw 16298
.dw 16356
.dw 16414
.dw 16472
.dw 16530
.dw 16588
.dw 16646
.dw 16704
.dw 16762
.dw 16820
.dw 16878
.dw 16936
.dw 16994
.dw 17052
.dw 17110
.dw 17168
.dw 17226
.dw 17284
.dw 17342
.dw 17400
.dw 17458
.dw 17516
.dw 17574
.dw 17632
.dw 17690
.dw 17748
.dw 17806
.dw 17864
.dw 17922
.dw 17980
.dw 18038
.dw 18096
.dw 18154
.dw 18212
.dw 18270
.dw 18328
.dw 18386
.dw 18444
.dw 18502
.dw 18560
.dw 18618
.dw 18676
.dw 18734
.dw 18792
.dw 18850
.dw 18908
.dw 18966
.dw 19024
.dw 19082
.dw 19140
.dw 19198
.dw 19256
.dw 19314
.dw 19372
.dw 19430
.dw 19488
.dw 19546
.dw 19604
.dw 19662
.dw 19720
.dw 19778
.dw 19836
.dw 19894
.dw 19952
.dw 20010
.dw 20068
.dw 20126
.dw 20184
.dw 20242
.dw 20300
.dw 20358
.dw 20416
.dw 20474
.dw 20532
.dw 20590
.dw 20648
.dw 20706
.dw 20764
.dw 20822
.dw 20880
.dw 20938
.dw 20996
.dw 21054
.dw 21112
.dw 21170
.dw 21228
.dw 21286
.dw 21344
.dw 21402
.dw 21460
.dw 21518
.dw 21576
.dw 21634
.dw 21692
.dw 21750
.dw 21808
.dw 21866
.dw 21924
.dw 21982
.dw 22040
.dw 22098
.dw 22156
.dw 22214
.dw 22272
.dw 22330
.dw 22388
.dw 22446
.dw 22504
.dw 22562
.dw 22620
.dw 22678
.dw 22736
.dw 22794
.dw 22852
.dw 22910
.dw 22968
.dw 23026
.dw 23084
.dw 23142
.dw 23200
.dw 23258
.dw 23316
.dw 23374
.dw 23432
.dw 23490
.dw 23548
.dw 23606
.dw 23664
.dw 23722
.dw 23780
.dw 23838
.dw 23896
.dw 23954
.dw 24012
.dw 24070
.dw 24128
.dw 24186
.dw 24244
.dw 24302
.dw 24360
.dw 24418
.dw 24476
.dw 24534
.dw 24592
.dw 24650
.dw 24708
.dw 24766
.dw 24824
.dw 24882
.dw 24940
.dw 24998
.dw 25056
.dw 25114
.dw 25172
.dw 25230
.dw 25288
.dw 25346
.dw 25404
.dw 25462
.dw 25520
.dw 25578
.dw 25636
.dw 25694
.dw 25752
.dw 25810
.dw 25868
.dw 25926
.dw 25984
.dw 26042
.dw 26100


.include "delay.asm"
