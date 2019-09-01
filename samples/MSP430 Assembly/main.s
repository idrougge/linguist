; main.s Firmware for mspbinclk
; Copyright 2012 Austin S. Hemmelgarn
;
; Licensed under the Apache License, Version 2.0 (the "License");
; you may not use this file except in compliance with the License.
; You may obtain a copy of the License at
;
;     http://www.apache.org/licenses/LICENSE-2.0
;
; Unless required by applicable law or agreed to in writing, software
; distributed under the License is distributed on an "AS IS" BASIS,
; WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
; See the License for the specific language governing permissions and
; limitations under the License.

.text
.org    0xfc00 ; Start of system FLASH
        DINT

; Initialize SP
        MOV     #0x02fe, r1

; Disable WDT+
        MOV     #0x5a9a,&0x0120

; Setup the I/O pins
; Set P2 as all outputs
        CLR.B   &0x0029
        MOV.B   #0xff,  &0x002a
        CLR.B   &0x002b
; Set P1.0 and P1.4 as an input, and P1.1 - P1.3 as outputs
        CLR.B   &0x0021
        BIC.B   #0x00,  &0x0022
        BIS.B   #0x0e,  &0x0022
; Set P1.5 - P1.7 For SPI usage
        CLR.B   &0x0026
        CLR.B   &0x0041
        BIS.B   #0xe0,  &0x0026
; Set up P1.0 as an interrupt triggered on the rising edge
; This is used to emulate an SPI chip enable
        CLR.B   &0x0024
        BIS.B   #0x01,  &0x0025

; Configure the clocks
; This sets the system clock as low as possible to conserve power
        MOV.B   #0x03,  &0x0057
        CLR.B   &0x0058
        BIS.B   #0x20,  &0x0053

; Setup USI as SPI Slave
        BIS.B   #0x01,  &0x0078
        BIS.B   #0xf2,  &0x0078
        CLR.B   &0x0079
        BIS.B   #0x10,  &0x0079
        CLR     &0x007a
        BIS.B   #0xc0,  &0x007b
        CLR     &0x007c

; Timer_A inicialization
        MOV     #0x0210,&0x0160
        MOV     #0xea60,&0x0172
        MOV     #0x0010,&0x0162

; These aren't really needed, but they are good practice
; r4 is used as a subsecond counter
        CLR      r4
; r4 is used as the minute counter for the clock
        CLR      r5
; r5 is used as the hour counter for the clock
        CLR      r6
; r6 is used as a scratch register during updates
        CLR      r7

; Finally, enable interrupts, and then sleep till we get one.
        EINT
        BIS.B   #0x10,   r2

; This branch should never get executed, but it's here just in case.
        BR      &0xffdc

; USI Interrupt handler (Used for SPI communication)
.org    0xff00
        BIS.B   #0x01,  &0x0078
        MOV.B   &0x007c, r5
        MOV.B   &0x007d, r6
        CLR      r4
        CLR     &0x0170
        CLR     &0x007c
        BIC.B   #0x01,  &0x0078
        RETI

; Timer_A main interrupt handler (Used to update the counters)
.org    0xff40
        INC      r4
        CLRZ
        CMP     #0x0064, r4
        JNE      0x1c
; It's been ~1 min
        CLR      r4
        INC      r5
        CLRZ
        CMP     #0x003c, r5
        JNE      0x14
; It's been ~1 hr
        CLR      r5
        INC      r6
        CLRZ
        CMP     #0x0018, r6
        JNE      0x02
        CLR      r6
; Copy the two low bits of the hour count to the two high bits of r5
        MOV.B    r6,     r7
        AND.B   #0x03,   r7
        CLRC
        RRC.B    r7
        RRC.B    r7
        RRC.B    r7
; Grab the minute count
        BIS.B    r5,     r7
; And finally, update P2
        MOV.B    r7,    &0x0029
; Move the other bits of the hour count to the right place in r5
        MOV.B    r6,     r7
        AND.B   #0x3c,   r7
        CLRC
        RLC.B    r7
        RLC.B    r7
; Update P1
        BIC.B    r7,    &0x0021
        BIS.B    r7,    &0x0021
        RETI

; P1 Interrupt handler (Used to emulate chip enable)
.org    0xffb8
        CLRZ
        BIT.B   #0x01,  &0x0024
        JNE      0x0a
; Switch to enabled mode
        BIC.B   #0x01,  &0x0024
        BIC.B   #0x01,  &0x0078
        JMP      0x04
; Switch to disabled mode
        BIS.B   #0x01,  &0x0024
        BIS.B   #0x01,  &0x0078
        CLR     &0x007c
        RETI


; Dummy handler for spurrious interrupts
.org    0xffd8
        NOP
        RETI

; Simple software reset routine
.org    0xffdc
        BR      &0x0000

; Start of interrupt vector table
.org    0xffe0
.word   0xffd8 ; Unused
.word   0xffd8 ; Unused
.word   0xffb8 ; Port 1
.word   0xffd8 ; Port 2
.word   0xff00 ; USI
.word   0xffd8 ; ADC10
.word   0xffd8 ; Unused
.word   0xffd8 ; Unused
.word   0xffd8 ; Timer0_A3 secondary
.word   0xff60 ; Timer0_A3 primary
.word   0xffd8 ; WDT+
.word   0xffd8 ; Comparator_A+
.word   0xffd8 ; Unused
.word   0xffd8 ; Unused
.word   0xffd8 ; NMI
.word   0xfc00 ; Reset
