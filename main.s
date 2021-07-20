gpio_portf_data_sw1	equ	0x40025040
gpio_portf_data_sw2	equ	0x40025004
timer1_ctl			equ	0x4003100C
	
		area 	main,readonly,code
		thumb
		extern	Nokia_Init
		extern	normal_mode_ui
		extern	adjustment_mode_ui
		extern	braking_mode_ui
		extern	ADC_initialization
		extern	ADC_sampling
		extern	PULSE_INIT
		extern	timer3_config
		extern	ultrasound
		extern 	motor_init
		export  normal_mode
		export 	adjustment_mode
		export  braking_mode
		export 	small_delay
		export	__main

small_delay 
		push{r0-r3,lr}
			
		LDR		R0,=0x0000FFFF
goto1	SUBS	R0,#1
		BNE		goto1
			
		pop{r0-r3,lr}
		bx lr
			

normal_mode
		push{r0-r3,lr}
		
		bl 		normal_mode_ui

		pop{r0-r3,lr}
		bx lr



adjustment_mode
		push{r0-r3,lr}
		
SW1_loop1					
		bl		ADC_sampling
		bl 		adjustment_mode_ui
		
		;continuously check if SW1 is pressed or not. use small delay for debouncing.
		bl		small_delay
		ldr		r1,=gpio_portf_data_sw1
		ldr 	r0,[r1]
		cmp 	r0,#0
		bne		SW1_loop1
		
SW1_loop2
		;continuously check if SW1 is pressed or not. use small delay for debouncing.
		bl		small_delay
		ldr		r1,=gpio_portf_data_sw1
		ldr 	r0,[r1]
		cmp 	r0,#0
		beq		SW1_loop2
		
		pop{r0-r3,lr}
		bx lr
		
		
braking_mode
		push{r0-r3,lr}
		
wait_in_braking_mode
		bl		ultrasound
		bl 		braking_mode_ui
		bl		small_delay

		;check if SW2 is pressed or not. use small delay for debouncing.
		bl		small_delay
		ldr		r1,=gpio_portf_data_sw2
		ldr 	r0,[r1]
		cmp 	r0,#0
		bne		wait_in_braking_mode
		
SW1_loop4
		;continuously check if SW2 is pressed or not. use small delay for debouncing.
		bl		small_delay
		ldr		r1,=gpio_portf_data_sw2
		ldr 	r0,[r1]
		cmp 	r0,#0
		beq		SW1_loop4
		
		pop{r0-r3,lr}
		bx lr



__main
		push{r0-r5,lr}
		
		;Ultrasound Sensor Initialization
		bl 		PULSE_INIT
		bl 		timer3_config
		;Nokia LCD Initialization
		bl		Nokia_Init
		;ADC Initialization
		bl		ADC_initialization
		;Stepper Motor Initialization
		;bl		motor_init
		
		
		mov 	r5,#111
		
		LDR		R0,=0x00200000
delay1	SUBS	R0,#1
		BNE		delay1		
		
goto_beginning
		;take measurement value from ultrasound with R4 register.
		bl		ultrasound
		bl 		normal_mode
		
		;compare distance and threshold values.
		;If distance value is lower than threshold value go to preventative braking mode
		;Look for SW2 flag first.
		cmp		r4,r5
		blo		braking_mode
		
		;check if SW1 is pressed or not. use small delay for debouncing.
		bl		small_delay
		ldr		r1,=gpio_portf_data_sw1
		ldr 	r0,[r1]
		cmp 	r0,#0
		bne		goto_beginning
		
SW1_loop3
		;continuously check if SW1 is pressed or not. use small delay for debouncing.
		bl		small_delay
		ldr		r1,=gpio_portf_data_sw1
		ldr 	r0,[r1]
		cmp 	r0,#0
		beq		SW1_loop3
		
		bl 		adjustment_mode
		b		goto_beginning
		
		pop{r0-r5,lr}
		bx lr
		
		align
		end