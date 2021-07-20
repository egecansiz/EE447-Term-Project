;initialize timer 3 to edge time,count up (PB2)
;TRIG of HC-SR04 Ultrasonic sensor -> connected to PF2
;ECHO of HC-SR04 Ultrasonic sensor -> connected to PB2

;***************************************************************
;System Clock Registers.
sysctl_rcgcgpio		equ			0x400fe608
sysctl_rcgctimer	equ			0x400fe604
;***************************************************************
;GPIO Registers for PB2.
gpio_portb_data		equ			0x40005010
gpio_portb_dir		equ			0x40005400
gpio_portb_afsel	equ			0x40005420
gpio_portb_den		equ			0x4000551c
gpio_portb_amsel	equ			0x40005528
gpio_portb_pctl		equ			0x4000552c
gpio_portb_pur		equ			0x40005510
gpio_portb_pdr		equ			0x40005514
;***************************************************************
;Timer registers for PB2 Timer3A.
timer3_cfg			equ			0x40033000
timer3_tamr			equ			0x40033004
timer3_tapr			equ			0x40033038
timer3_ctl			equ			0x4003300C
timer3_tailr		equ			0x40033028

timer3_imr			equ			0x40033018		;Timer3 Interrupt Mask
timer3_ris			equ			0x4003301C		;Timer3 Raw Interrupt Status
timer3_icr			equ			0x40033024		;Timer3 Interrupt Clear
timer3_tar			equ			0x40033048
;***************************************************************
;Nested Vector Interrupt Controller registers
nvic_en1			equ			0xe000e104	;IRQ 32 to 63 Set Enable Register
nvic_pri8			equ			0xe000e420	;IRQ 32 to 35 Priority Register
;***************************************************************

            AREA 		main, READONLY, CODE, ALIGN=3
            THUMB
			export		timer3_config
			export		ultrasound
			
timer3_config
			push{r0-r3,lr}
			
			;Configure GPIO for PortB Pin2.
			;Enable clock for portB.
			ldr	r1,=sysctl_rcgcgpio
			ldr r0,[r1]
			orr r0,#0x02
			str r0,[r1]
			nop
			nop
			nop
			
			;Set direction for PB2 to input.
			ldr r1,=gpio_portb_dir
			ldr r0,[r1]
			bic r0,#0x04
			str r0,[r1]
			
			;Set alternate function for PB2.
			ldr r1,=gpio_portb_afsel
			ldr r0,[r1]
			orr r0,#0x04
			str r0,[r1]
			
			;Set Timer3 function for PB2.
			ldr r1,=gpio_portb_pctl
			mov32 r0,#0x00000700
			str r0,[r1]
			
			;Reset analog function
			ldr r1,=gpio_portb_amsel
			mov	r0,#0
			str r0,[r1]
			
			;Set digital function
			ldr r1,=gpio_portb_den
			ldr r0,[r1]
			orr r0,#0x04
			str r0,[r1]
			
			
			;Configure Timer for PortB Pin2.
			;Enable clock for Timer3.
			ldr	r1,=sysctl_rcgctimer
			ldr r0,[r1]
			orr r0,#0x08
			str r0,[r1]
			nop
			nop
			nop
			
			;Disable at initializing.
			ldr r1,=timer3_ctl
			ldr r0,[r1]
			bic r0,#0x01
			str r0,[r1]
			
			;Configure Timer3: Set 16-bit mode.
			ldr r1,=timer3_cfg
			ldr r0,[r1]
			orr r0,#0x04
			str r0,[r1]
			
			;Set modes for Timer3A: Set edge time, capture, count-up mode.
			ldr r1,=timer3_tamr
			ldr r0,[r1]
			orr r0,#0x03	;capture mode
			orr r0,#0x04	;edge time mode
			orr r0,#0x10	;count-up mode
			str r0,[r1]
			
			;Set prescaler to 15 for dividing the clock by 16.
			;We get 1us clocks after division.
			ldr r1,=timer3_tapr
			mov r0,#15
			str r0,[r1]
			
			;Set Both edge detection mode.
			ldr r1,=timer3_ctl
			ldr r0,[r1]
			orr r0,#0x0c	;both edge detection
			str r0,[r1]
			
			;Load interval load register with count up value.
			ldr r1,=timer3_tailr
			mov32 r0,#0xffffffff
			str r0,[r1]
			
; Configure interrupt priorities
; Timer3A is interrupt #35.
; Interrupts 32-35 are handled by NVIC register PRI8.
; Interrupt 35 is controlled by bits 31:29 of PRI8.
; set NVIC interrupt 35 to priority 2
			LDR R1, =nvic_pri8
			LDR R2, [R1]
			AND R2, R2, #0x00FFFFFF ; clear interrupt 35 priority
			ORR R2, R2, #0x20000000 ; set interrupt 35 priority to 2
			STR R2, [R1]
; NVIC has to be enabled
; Interrupts 32-63 are handled by NVIC register EN1
; Interrupt 35 is controlled by bit 3.
; enable interrupt 35 in NVIC
			LDR R1, =nvic_en1
			MOV R2, #0x08 ; set bit 3 to enable interrupt 35.
			STR R2, [R1]
			
			;Enable timer3a and set Stall on debug.
			ldr r1,=timer3_ctl
			ldr r0,[r1]
			orr r0,#0x01	;enable timer3a
			orr r0,#0x02	;stall on debug
			str r0,[r1]
			
			pop{r0-r3,lr}
			bx lr
;***************************************************************
;***************************************************************

ultrasound	
			push{r0-r3,lr}
			push{r5}
			
			mov r10,#10
loop_10times
			;check [2] "CAERIS" ,it is set when edge detected
			ldr r1,=timer3_ris
wait_interrupt			
			ldr r0,[r1]
			ands r0,#0x04
			beq	wait_interrupt
			
			;clear the flag when an edge is caught
			ldr r1,=timer3_icr
			ldr r0,[r1]
			orr	r0,#0x04
			str r0,[r1]
			
			;get the time captured
			ldr r1,=timer3_tar
			ldr r0,[r1]
			mov r8,r0
			
			;check if port is high or low
			ldr r1,=gpio_portb_data
			ldr r0,[r1]
			and r0,#0x04
			cmp r0,#0x04
			beq is_high
			bne is_low

is_high		sub	r9,r8,r7	;(r8-r7)=period				
			mov r7,r8		;save the time
			b 	jump_to		;our period is 16*period since prescaler worked as a timer extension


is_low		sub	r11,r8,r7	;pulse width=(R8-R6)
			mov	r6,r8		;save the time we've been low to R6 for further calculations
									;it is again pulsewidth*16 (timer extension mode on edge count)
jump_to		subs r10,#1
			bne	loop_10times
			
			;get period and pulse width
			mov	r0,#16					
			udiv r9,r0			;overall period
			udiv r11,r0			;overall pulsewidth

			mov	r0,#100
			mul	r11,r0			;(pulsewidth*100)/period == duty cycle
			udiv r12,r11,r9		;r12 == duty cycle (percent)
			udiv r11,r0			;r11 == width of pulse
			
			mov r0,#17
			mul	r11,r0 		;pulsewidth*17
			mov r5,#100
			udiv r4,r11,r5
			
			
			pop{r5}
			pop{r0-r3,lr}
			bx lr
			
			align
			end