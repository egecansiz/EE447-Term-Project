sysctl_rcgcgpio		equ	0x400FE608
gpio_porte_dir		equ	0x40024400
gpio_porte_den		equ	0x4002451C
gpio_porte_amsel	equ	0x40024528
gpio_porte_afsel	equ	0x40024420

sysctl_rcgcadc	equ	0x400FE638
adc0_actss		equ	0x40038000
adc0_emux		equ	0x40038014
adc0_ssmux3		equ	0x40038040
adc0_ssctl3		equ	0x400380A4
adc0_pc			equ	0x40038FC4

adc0_pssi		equ	0x40038028
adc0_ris		equ	0x40038004
adc0_ssfifo3	equ	0x400380A8
adc0_isc		equ	0x4003800C

gpio_portf_lock	equ	0x40025520
gpio_portf_cr	equ	0x40025524
gpio_portf_den	equ	0x4002551C
gpio_portf_dir	equ	0x40025400
gpio_portf_pur	equ	0x40025510
			
				area routines,readonly,code
				thumb
				export ADC_initialization
				export ADC_sampling
			
ADC_initialization
				push{r0-r3,lr}
				
				;enable porte clock.
				ldr r1,=sysctl_rcgcgpio
				ldr r0,[r1]
				orr r0,#0x10
				str r0,[r1]
				nop
				nop
				nop
				
				;assume we use ADC0 and SS3 only.
				;enable the clock for ADC0.
				ldr r1,=sysctl_rcgcadc
				ldr r0,[r1]
				orr r0,#0x01		;store 0x01 for ADC0 and store 0x02 for ADC1.
				str r0,[r1]
				nop
				nop
				nop
				
				;configure PE3 as input.
				ldr r1,=gpio_porte_dir
				ldr r0,[r1]
				bic r0,#0x08
				str r0,[r1]
				
				;configure PE3 as alternate function.
				ldr r1,=gpio_porte_afsel
				ldr r0,[r1]
				orr r0,#0x08
				str r0,[r1]
				
				;Configure PE3 as non-digital input.
				ldr r1,=gpio_porte_den
				ldr r0,[r1]
				bic r0,#0x08
				str r0,[r1]
				
				;Configure PE3 as analog input.
				ldr r1,=gpio_porte_amsel
				ldr r0,[r1]
				orr r0,#0x08
				str r0,[r1]
				
				;disable sample sequencer 3 of ADC0.
				ldr r1,=adc0_actss
				ldr r0,[r1]
				bic r0,#0x08
				str r0,[r1]
				
				;disable event mux select to processor trigger for SS3.
				;we will use software trigger for SS3.
				ldr r1,=adc0_emux
				ldr r0,[r1]
				bic r0,#0xF000
				str r0,[r1]
				
				;clear SS3 mux since we are using AIN0 which is PE3.
				ldr r1,=adc0_ssmux3
				ldr r0,[r1]
				bic r0,#0xF
				str r0,[r1]
				
				;configure sample sequencer control 3.
				;enable IE0 and END0. disable TS0 and D0.
				ldr r1,=adc0_ssctl3
				ldr r0,[r1]
				orr r0,#0x6
				str r0,[r1]
				
				;configure for 125k samples/sec.
				;ADC peripheral configuration. Set bit0 for 125ksps.
				ldr r1,=adc0_pc
				ldr r0,[r1]
				orr r0,#0x01
				str r0,[r1]
				
				;enable SS3.
				ldr r1,=adc0_actss
				ldr r0,[r1]
				orr r0,#0x8
				str r0,[r1]			
				
				;Make SW1 and SW2 initializations
				;SW1=PF4 and SW2=PF0
				;enable portf clock
				ldr r1,=sysctl_rcgcgpio
				ldr r0,[r1]
				orr r0,#0x20
				str r0,[r1]
				nop
				nop
				nop
				
				;disable lock register of Port F.
				ldr r1,=gpio_portf_lock
				ldr r0,=0x4C4F434B
				str r0,[r1]
				
				;specify PortF pins (PF0 and PF4) to commit lock.
				ldr r1,=gpio_portf_cr
				mov r0,#0x11
				str r0,[r1]
				
				;set directions of PF0 and PF4 to input.
				ldr r1,=gpio_portf_dir
				ldr r0,[r1]
				bic r0,#0x11
				str r0,[r1]
				
				;set PF0 and PF4 to digital functions.
				ldr r1,=gpio_portf_den
				ldr r0,[r1]
				orr r0,#0x11
				str r0,[r1]
				
				;enable pull-up register for SW1 and SW2.
				ldr r1,=gpio_portf_pur
				mov r0,#0x11
				str r0,[r1]
				
				pop{r0-r3,lr}
				bx	lr
			
			
ADC_sampling	
				push{r0-r3,lr}
							
				;initiate sampling by enabling sequencer 3 in sample sequence initiate adress (PSSI).
				ldr r1,=adc0_pssi
				ldr r0,[r1]
				orr r0,#0x8				;set bit3 for SS3.
				str r0,[r1]
				
				;check for sample complete. check interrupt adress register (RIS).
				ldr r1,=adc0_ris
checkRIS		ldr r0,[r1]
				cmp r0,#0x8			;check bit3 for SS3.
				bne	checkRIS
				
				;store the value in R5.
				ldr r1,=adc0_ssfifo3	;result adress.
				ldr r5,[r1]
				
				MOV R2,#1000 	;this is for boundary value
				MOV R3,#4096 	;max val in decimal
		
				MUL R5,R2
				UDIV R5,R3 		;R5 is the result between 0 and 999 now
				
				;branch fails if the flag is set, so data can be read and flag is cleared.
				ldr r1,=adc0_isc
				ldr r0,[r1]
				orr r0,#0x8
				str r0,[r1]
				
				;finish sampling by disabling sequencer 3 in sample sequence initiate adress (PSSI).
				ldr r1,=adc0_pssi
				ldr r0,[r1]
				bic r0,#0x8				;set bit3 for SS3.
				str r0,[r1]
				
				pop{r0-r3,lr}
				bx	lr
			
				align
				end