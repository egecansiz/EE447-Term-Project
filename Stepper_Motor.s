;GPIO Registers for Port C(4-7).
gpio_portd_data		equ		0x4000703c		;enable pc4-7
gpio_portd_dir		equ		0x40007400		
gpio_portd_afsel	equ		0x40007420
gpio_portd_den		equ		0x4000751c
;***********************************************************
;System Clock Registers.
sysctrl_rcgcgpio	equ		0x400fe608
sysctl_rcgctimer	equ		0x400fe604
;***********************************************************
;Timer registers for Timer2A.
timer1_cfg			equ		0x40031000
timer1_tamr			equ		0x40031004
timer1_tapr			equ		0x40031038
timer1_ctl			equ		0x4003100C
timer1_tailr		equ		0x40031028
timer1_tamatchr		equ		0x40031030
timer1_imr			equ		0x40031018
timer1_icr			equ		0x40031024
;***********************************************************
NVIC_PRI5			equ		0xe000e414
NVIC_EN0			equ		0xe000e100
;***********************************************************

			area	gpio_initialize,readonly,code
			thumb
			export	motor_init
			export	My_Timer1A_Handler
			
			
My_Timer1A_Handler
			push {r0-r3,lr}			
			
			LDR R11,=timer1_icr;	CLEAR INTERRUPT 
			LDR R10, [R11];
			ORR R10, #0x01 ; clear bit of timer 1
			STR R10, [R11]
			

			;load gpio portc data register
			ldr r1,=gpio_portd_data		
			ldr r0,[r1]

			;if input1 is set, clear input1 and set input2
			cmp 	r0,#0x01
			eoreq	r0,r0,#0x03
			beq		exit
			
			;if input2 is set, clear input2 and set input3
			cmp 	r0,#0x02
			eoreq	r0,r0,#0x06
			beq		exit
			
			;if input3 is set, clear input3 and set input4
			cmp 	r0,#0x04
			eoreq	r0,r0,#0x0c
			beq		exit
			
			;if input4 is set, clear input4 and set input1
			cmp 	r0,#0x08
			eoreq	r0,r0,#0x09
exit		
			str		r0,[r1]

			pop {r0-r3,lr}
			bx lr
			
			
motor_init
			push {r0-r3,lr}
			
			;activate clock
			ldr r1,=sysctrl_rcgcgpio
			ldr r0,[r1]
			orr r0,r0,#0x08	;turn on PortD clocks.
			str r0,[r1]
			nop
			nop
			nop

			;set direction register
			ldr r1,=gpio_portd_dir
			ldr r0,[r1]
			orr	r0,#0x0f		;make PortD pin0-3 output.
			str r0,[r1]
			
			;clear afsel register
			ldr r1,=gpio_portd_afsel
			ldr r0,[r1]
			bic r0,#0x0f
			str r0,[r1]
			
			;enable digital function
			ldr r1,=gpio_portd_den
			ldr r0,[r1]
			orr r0,#0x0f
			str r0,[r1]
			
			ldr r1,=gpio_portd_data
			mov r0,#0x08		;initialize data.
			str r0,[r1]
			
			;Enable Timer1 clock
			ldr r1,=sysctl_rcgctimer
			ldr r0,[r1]
			orr r0,#0x01
			str r0,[r1]
			nop
			nop
			nop
			
			;Disable timer during initialization
			ldr r1,=timer1_ctl
			ldr r0,[r1]
			bic	r0,#0x01
			str r0,[r1]
			
			;Set 16 bit mode
			ldr r1,=timer1_cfg
			ldr r0,[r1]
			orr	r0,#0x04
			str r0,[r1]
			
			;Set to periodic, count up. Enable match register.
			ldr r1,=timer1_tamr
			ldr r0,[r1]
			orr	r0,#0x32
			str r0,[r1]
			
			LDR R1,=timer1_tailr ; initialize match clocks
			MOV R0,#6000
			STR R0,[R1]
			
			;Initialize match value.
			;ldr r1,=timer1_tamatchr
			;ldr r0,[r1]
			;orr r0,#0xff
			;mov32 r0,#1000
			;str r0,[r1]
			
			;Divide clock.
			ldr r1,=timer1_tapr
			mov	r0,#15
			str r0,[r1]
			
			;Enable timeout interrupt.
			ldr r1,=timer1_imr
			ldr r0,[r1]
			orr	r0,#0x01
			str r0,[r1]
			
; Configure interrupt priorities
; Timer1A is interrupt #23.
; Interrupts 20-23 are handled by NVIC register PRI5.
; Interrupt 21 is controlled by bits 31:29 of PRI5.
; set NVIC interrupt 21 to priority 3
			LDR R1, =NVIC_PRI5
			LDR R2, [R1]
			AND R2, R2, #0xFFFF00FF ; clear interrupt 19 priority
			ORR R2, R2, #0x00008000 ; set interrupt 19 priority to 2
			STR R2, [R1]
; NVIC has to be enabled
; Interrupts 0-31 are handled by NVIC register EN0
; Interrupt 21 is controlled by bit 21
; enable interrupt 21 in NVIC
			LDR R1, =NVIC_EN0
			LDR R2,[R1]
			ORR R2,#0x00200000
			STR R2, [R1]
			
			;Enable Timer and stall on debug.
			ldr r1,=timer1_ctl
			ldr r0,[r1]
			orr r0,#0x03
			str r0,[r1]
			
			pop {r0-r3,lr}
			bx lr
			
			align
			end