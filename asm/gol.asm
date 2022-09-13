    ;;    game state memory location
    .equ CURR_STATE, 0x1000              ; current game state
    .equ GSA_ID, 0x1004                     ; gsa currently in use for drawing
    .equ PAUSE, 0x1008                     ; is the game paused or running
    .equ SPEED, 0x100C                      ; game speed
    .equ CURR_STEP,  0x1010              ; game current step
    .equ SEED, 0x1014              ; game seed
    .equ GSA0, 0x1018              ; GSA0 starting address
    .equ GSA1, 0x1038              ; GSA1 starting address
    .equ SEVEN_SEGS, 0x1198             ; 7-segment display addresses
    .equ CUSTOM_VAR_START, 0x1200 ; Free range of addresses for custom variable definition
    .equ CUSTOM_VAR_END, 0x1300
    .equ LEDS, 0x2000                       ; LED address
    .equ RANDOM_NUM, 0x2010          ; Random number generator address
    .equ BUTTONS, 0x2030                 ; Buttons addresses

    ;; states
    .equ INIT, 0
    .equ RAND, 1
    .equ RUN, 2

    ;; constants
    .equ N_SEEDS, 4
    .equ N_GSA_LINES, 8
    .equ N_GSA_COLUMNS, 12
    .equ MAX_SPEED, 10
    .equ MIN_SPEED, 1
    .equ PAUSED, 0x00
    .equ RUNNING, 0x01


main:
	;set stack pointer
	addi sp, zero, 0x2000
		
	;infinite loop
	infinite_loop:
		call reset_game
		call get_input
		;store edgecapture
		addi s0, v0, 0
		;set done to 0 (false)
		addi s1, zero, 0
			;;while !done do loop

			loop_done:
			;if done is not equal to false then skip to next iteration of infinite_loop 
			bne s1, zero, infinite_loop 

			;store edgecapture as argument for select_action 
			addi a0, s0, 0
			call select_action

			;store edgecapture as argument for update_state 
			addi a0, s0, 0
			call update_state

			call update_gsa
			call mask
			call draw_gsa
			call wait
			call decrement_step
			;store done
			addi s1, v0, 0

			call get_input
			;store edgecapture
			addi s0, v0, 0
			
			br loop_done
	

	;BEGIN:clear_leds
		clear_leds:
			;initialize upper bound for loop
			addi t0, zero, 0x2009
			;initialise counter for loop
			addi t1, zero, LEDS
			loop_leds:
				;set LEDs[i] to 0  
				stw zero, 0 (t1)
				;add 4 to the counter
				addi t1, t1, 4
				;check if counter reaches upper bound
				blt t1, t0, loop_leds   
		ret
	; END:clear_leds

	; BEGIN:set_pixel
		;a0 := pixel x coordinate
		;a1 := pixel y coordinate
		set_pixel:
			;add x to LEDS 
			addi t0, a0, LEDS
			;find x mod 4
			andi t1, a0, 3 
			;calculate LEDs + x - x mod 4 
			sub t0, t0, t1
			;8 * (x mod 4) 
			slli t1, t1, 3
			;8 * (x mod 4) + y 
			add t1, t1, a1
			;initialize t2 to 1
			addi t2, zero, 1
			;create mask for modifying LED[x, y] to 1
			sll t2, t2, t1
			;load correct LEDs (e.g LEDs[1]) 
			ldw t3, 0 (t0)
			;apply mask
			or t3, t3, t2
			;update the LED that has been modified  
			stw t3, 0 (t0)    
		ret
	; END:set_pixel
	
	; BEGIN:wait
		wait:
			;current_count, initialize to 2^21
			addi t0, zero, 1
			slli t0, t0, 21

			;store speed
			ldw t1, SPEED (zero)

			loop_wait:
				;subtract from current_count SPEED
				sub t0, t0, t1
				;check that current_count is greater than 0, else termination of loop
				bge t0, zero, loop_wait     
		ret
	; END:wait

	; BEGIN:get_gsa
		;a0 := y coordinate of GSA line

		;v0 := line of gsa at y coordinate
		get_gsa:
			;y * 4
			slli t0, a0, 2
			;GSA0 + y * 4
			ldw t1, GSA_ID (zero)
			;check value of GSA_ID and branch accordingly
			beq t1, zero, get_gsa_GSA0

			;if not GSA0 then: GSA1 + y * 4
			addi t0, t0, GSA1
			br get_gsa_end

			get_gsa_GSA0:
				;GSA0 + y * 4
				addi t0, t0, GSA0

			get_gsa_end:
			;load the word at line y in GSA0
			ldw v0, 0 (t0) 
		ret
	; END:get_gsa

	; BEGIN:set_gsa
		;a0 := line to be inserted 
		;a1 := y coordinate of the line
		set_gsa:
			;y * 4
			slli t0, a1, 2
			;GSA0 + y * 4
			ldw t1, GSA_ID (zero)
			;check iF GSA_ID is 1 or 0 and branch accordingly
			beq t1, zero, set_gsa_GSA0

			;if not GSA0, then: GSA1 + y * 4
			addi t0, t0, GSA1 
			br set_gsa_end

			set_gsa_GSA0:
				;GSA0 + y * 4
				addi t0, t0, GSA0
				
			set_gsa_end:
			;store the word at line y in GSA0
			stw a0, 0 (t0) 
		ret
	; END:set_gsa
	
	;BEGIN:draw_gsa
		draw_gsa:
			;store return address on stack
			addi sp, sp, -4
			stw ra, 0 (sp)

			;initialize y counter to 0
			addi a0, zero, 0
			;upperbound for y counter
			addi t0, zero, 8
			;LEDS[0] register
			addi t5, zero, 0
			;LEDS[1] register
			addi t6, zero, 0
			;LEDS[2] register
			addi t7, zero, 0

			draw_gsa_loop:
				;push temporary values on stack
				addi sp, sp, -24
				stw t0, 0 (sp)
				stw t1, 4 (sp)
				stw t5, 8 (sp)
				stw t6, 12 (sp)
				stw t7, 16 (sp)
				stw a0, 20 (sp)

				call get_gsa

				;pop temporary values from stack
				ldw t0, 0 (sp)
				ldw t1, 4 (sp)
				ldw t5, 8 (sp)
				ldw t6, 12 (sp)
				ldw t7, 16 (sp)
				ldw a0, 20 (sp)
				addi sp, sp, 24

				;store gsa
				addi t1, v0, 0

				;put correct byte as input 
				addi a1, t1, 0
				
				
				;push temporary values on stack
				addi sp, sp, -24
				stw t0, 0 (sp)
				stw t1, 4 (sp)
				stw t5, 8 (sp)
				stw t6, 12 (sp)
				stw t7, 16 (sp)
				stw a0, 20 (sp)

				call helper_draw_gsa

				;pop temporary values from stack
				ldw t0, 0 (sp)
				ldw t1, 4 (sp)
				ldw t5, 8 (sp)
				ldw t6, 12 (sp)
				ldw t7, 16 (sp)
				ldw a0, 20 (sp)
				addi sp, sp, 24
				
				;add row to LEDS[0]
				or t5, t5, v0

				;get correct byte as input 
				srli a1, t1, 4 

				;push temporary values on stack
				addi sp, sp, -24
				stw t0, 0 (sp)
				stw t1, 4 (sp)
				stw t5, 8 (sp)
				stw t6, 12 (sp)
				stw t7, 16 (sp)
				stw a0, 20 (sp)

				call helper_draw_gsa

				;pop temporary values from stack
				ldw t0, 0 (sp)
				ldw t1, 4 (sp)
				ldw t5, 8 (sp)
				ldw t6, 12 (sp)
				ldw t7, 16 (sp)
				ldw a0, 20 (sp)
				addi sp, sp, 24
				
				;add row to LEDS[1]
				or t6, t6, v0


				;get correct byte as input 
				srli a1, t1, 8 

				;push temporary values on stack
				addi sp, sp, -24
				stw t0, 0 (sp)
				stw t1, 4 (sp)
				stw t5, 8 (sp)
				stw t6, 12 (sp)
				stw t7, 16 (sp)
				stw a0, 20 (sp)

				call helper_draw_gsa

				;pop temporary values from stack
				ldw t0, 0 (sp)
				ldw t1, 4 (sp)
				ldw t5, 8 (sp)
				ldw t6, 12 (sp)
				ldw t7, 16 (sp)
				ldw a0, 20 (sp)
				addi sp, sp, 24
				
				;add row to LEDS[2]
				or t7, t7, v0
				 
				;increment counter by 1
				addi a0, a0, 1

				;check condition for loop
				bne a0, t0, draw_gsa_loop
			
			;store the LED registers into the LEDS	
			addi t0, zero, LEDS
			stw t5, 0 (t0)
		
			stw t6, 4 (t0)
				
			stw t7, 8 (t0)

			;pop return address from stack 
			ldw ra, 0 (sp)
			addi sp, sp, 4

		ret			
	;END:draw_gsa

	; BEGIN:random_gsa
		random_gsa:
			;store return address on stack
			addi sp, sp, -4
			stw ra, 0 (sp)

			;initialize loop counter to 0
			addi t0, zero, 0
			;initialize loop upperbound
			addi t1, zero, 8

			random_gsa_loop:
				;load a random num into argument for calling set_gsa 
				ldw a0, RANDOM_NUM (zero)
				;mask the random gsa
				andi a0, a0, 0xFFF
				;put y coordinate as argument 
				addi a1, t0, 0

				;push temporary values on stack
				addi sp, sp, -8
				stw t0, 0 (sp)
				stw t1, 4 (sp)

				call set_gsa

				;pop temporary values from stack
				ldw t0, 0 (sp)
				ldw t1, 4 (sp)
				addi sp, sp, 8

				;increment counter
				addi t0, t0, 1
				;if counter hasn't reached upperbound then continue loop
				bne t0, t1, random_gsa_loop
				
				;pop return address from stack
				ldw ra, 0 (sp)
				addi sp, sp, 4	
		ret
	; END:random_gsa

	;BEGIN:change_speed
		;a0 := decrement or increment game speed (0 increment, 1 decrement)
		change_speed:
			;initialize to a constant 1 for incrementing and decrementing and lower bound
			addi t0, zero, MIN_SPEED
			;initialize upperbound 
			addi t1, zero, MAX_SPEED
			;load current speed from its register
			ldw t2, SPEED (zero)
			
			;if a0 is 0, then we will increment, else decrement
			beq a0, zero, change_speed_increment
			br change_speed_decrement

			change_speed_increment:
				;if speed is 10 then we can't increment
				beq t2, t1, change_speed_end
				;else increment speed 
				add t2, t2, t0
				br change_speed_end

			change_speed_decrement:
				;if speed is 1 then we can't decrement
				beq t2, t0, change_speed_end
				;else decrement speed 
				sub t2, t2, t0

			change_speed_end:
			;store our modified speed into its register
			stw t2, SPEED (zero)
		ret		 
	;END:change_speed
	
	;BEGIN:pause_game
		pause_game:
			;load the current state of the game (paused or running)
			ldw t0, PAUSE (zero)
			;invert the current state (only LSB)
			xori t0, t0, 1
			;store the inverted current state
			stw t0, PAUSE (zero)
		ret
	;END:pause_game
	
	;BEGIN:change_steps
		change_steps:
			;load the current step
			ldw t2, CURR_STEP (zero) 
			
			;shift the hexadecimal 10's argument by four positions
			slli t0, a1, 4
			;shift the hexadecimal 100's argument by four positions
			slli t1, a2, 8
			;add all terms together with the current step 
			add t0, t0, a0
			add t0, t0, t1
			add t0, t0, t2
 
			;store the number of steps in CURR_STEP
			stw t0, CURR_STEP (zero) 	
		ret	
	;END:change_steps
	
	;BEGIN:increment_seed
		increment_seed:
			;store return address on stack
			addi sp, sp, -4
			stw ra, 0 (sp)

			;load current state
			ldw t0, CURR_STATE (zero)
			;load current seed
			ldw t1, SEED (zero)
			;constant seed for INIT
			addi t2, zero, INIT
			;constant seed for RAND
			addi t3, zero, RAND
			;constant for RAND seed (4)
			addi t4, zero, 4
			
			;if current state is in init
			beq t0, t2, increment_seed_INIT
			;if current state is in rand
			beq t0, t3, increment_seed_RAND
			br increment_seed_end

			increment_seed_INIT:
				;if seed is 4 then branch to RAND code 
				beq t1, t4, increment_seed_RAND
				;increment the seed 
				addi t1, t1, 1
				;if seed is 4 after incrementation, then branch to increment_seed_RAND
				beq t1, t4, increment_seed_RAND
				
				;multiply seed by 4 to get the address
				slli t2, t1, 2
				;get address of the address of the seed
				addi t2, t2, SEEDS 
				;load the address of the seed
				ldw a0, 0 (t2)

				;call helper function that updates GSA to the current seed
				;store values on stack before calling function
				addi sp, sp, -4
				stw t1, 0 (sp)

				;call function
				call helper_increment_seed

				;retrieve values from stack
				ldw t1, 0 (sp)
				addi sp, sp, 4

				br increment_seed_end

			increment_seed_RAND:
				;if current state is RAND then call the function that fills the GSA randomly

				;store values on stack before calling function
				addi sp, sp, -4
				stw t1, 0 (sp)

				;call function
				call random_gsa

				;retrieve values from stack
				ldw t1, 0 (sp)
				addi sp, sp, 4
				
			increment_seed_end:
			;Store the new updated seed 
			stw t1, SEED (zero)
			
			;pop return address from stack
			ldw ra, 0 (sp)
			addi sp, sp, 4

		ret			 
	;END:increment_seed

	;BEGIN:update_state
		update_state:
			;store return address on stack
			addi sp, sp, -4
			stw ra, 0 (sp)

			;load the current state
			ldw t0, CURR_STATE (zero)
			;RAND state and constant 1
			addi t1, zero, RAND
			addi t2, zero, RUN

			;button0
			andi t3, a0, 1

			;button1
			srli t4, a0, 1
			andi t4, t4, 1

			;button2
			srli t5, a0, 2
			andi t5, t5, 1

			;button3
			srli t6, a0, 3
			andi t6, t6, 1
 
			;button4
			srli t7, a0, 4
			andi t7, t7, 1

			;if state is INIT then go to the INIT code
			beq t0, zero, update_state_INIT
			;if state is RAND then go to the RAND code
			beq t0, t1, update_state_RAND
			;if state is RUN then go to the RUN code
			beq t0, t2, update_state_RUN
			br update_state_end

			update_state_INIT:
				;limit case for transition from INIT to RAND
				addi t7, zero, 4

				;load the current seed value to see if we arrive at limit case
				ldw t2, SEED (zero)
				;check if SEED = 4 to process transition to RAND state
				beq t7, t2, update_state_max_SEED
				;check if button1 is pressed
				beq t4, t1, update_state_INIT_button1
				br update_state_end

				update_state_INIT_button1:
					;update state to RUN
            		addi t0, zero, RUN
					;set game to play
					stw t1, PAUSE (zero)

					br update_state_end
				
				update_state_max_SEED:
					;change state to RAND
					addi t0, zero, RAND

					br update_state_end

			update_state_RAND: 
				;branch if the button 1 is being pressed
        		beq t4, t1, update_state_rand_toRun 
       			br update_state_end

            	update_state_rand_toRun:
					;update state to RUN
            		addi t0, zero, RUN
					;set game to play
					stw t1, PAUSE (zero)

            		br update_state_end

			update_state_RUN:
				;if button3 is pressed then go to code for button3
				beq t6, t1, update_state_RUN_button3
				br update_state_end

				update_state_RUN_button3:
					;set state to INIT 
					addi t0, zero, INIT
					;pause the game
					stw zero, PAUSE (zero)

					;push temporary values onto stack
					addi sp, sp, -4
					stw t0, 0 (sp)

					call reset_game

					;pop the values from the stack
					ldw t0, 0 (sp)
					addi sp, sp, 4  
                                                                       
					br update_state_end

			update_state_end:
			;store updated state into the current state
			stw t0, CURR_STATE (zero)

			;pop return address from stack 
			ldw ra, 0 (sp)
			addi sp, sp, 4

		ret			 
	;END:update_state
	
	;BEGIN:select_action
		select_action:
			;store return address on stack
			addi sp, sp, -4
			stw ra, 0 (sp)

			;load the current state
			ldw t0, CURR_STATE (zero)
			;RAND state and constant 1 
			addi t1, zero, RAND
			;RUN state
			addi t2, zero, RUN

			;button0
			andi t3, a0, 1

			;button1
			srli t4, a0, 1
			andi t4, t4, 1

			;button2
			srli t5, a0, 2
			andi t5, t5, 1

			;button3
			srli t6, a0, 3
			andi t6, t6, 1
 
			;button4
			srli t7, a0, 4
			andi t7, t7, 1

			;if state is INIT then go to the INIT code
			beq t0, zero, select_action_INIT_RAND
			;if state is RAND then go to the RAND code
			beq t0, t1, select_action_INIT_RAND
			;if state is RUN then go to the RUN code
			beq t0, t2, select_action_RUN
			br select_action_end
			
			select_action_INIT_RAND:
				;branch if button0 is pressed
				beq t3, t1, select_action_INIT_RAND_button0

				;add to arguments of change_steps buttons 2, 3, 4
				addi a2, t5, 0
				addi a1, t6, 0
				addi a0, t7, 0

				call change_steps
 
				br select_action_end
				
			select_action_INIT_RAND_button0:
				call increment_seed
				br select_action_end
				
			select_action_RUN:
				;branch if button0 is pressed
				beq t3, t1, select_action_RUN_button0
				;branch if button1 is pressed
				beq t4, t1, select_action_RUN_button1
				;branch if button2 is pressed 
				beq t5, t1, select_action_RUN_button2
				;branch if button4 is pressed
				beq t7, t1, select_action_RUN_button4 
				br select_action_end

				select_action_RUN_button0:
					;pauses or resumes the game
					call pause_game
				
					br select_action_end

				select_action_RUN_button1:
					;increment the speed
					addi a0, zero, 0
					call change_speed
					br select_action_end

				select_action_RUN_button2:
					;decrement the speed
					addi a0, zero, 1
					call change_speed
					br select_action_end

				select_action_RUN_button4:
					;set a random gsa
					;call function
					call random_gsa

					br select_action_end

			select_action_end:
			;pop return address from stack 
			ldw ra, 0 (sp)
			addi sp, sp, 4

		ret				
	;END:select_action

	;BEGIN:cell_fate
		;a0 := sum of neighbours
		;a1 := state of examined cell
		cell_fate:
			;state register (dead or alive) initialised to zero (dead)
			addi t2, zero, 0
			;two neighbours constant
			addi t0, zero, 2
			;three neighbours constant
			addi t1, zero, 3
			;check if cell is alive or dead, and go to appropriate code bloc
			beq a1, zero, cell_fate_dead
			br cell_fate_alive

			cell_fate_dead:
				;if living neighbours is not three than stay dead, go to end
				bne a0, t1, cell_fate_end 
				;set state regitser to alive if living neighbours is 3
				addi t2, zero, 1 
				;go to the end after this
				br cell_fate_end

			cell_fate_alive:
				;change t1 to 4, for the upperbound of bge (since it is greater or equal) 
				addi t1, zero, 4
				;if underpopulation, then go directly to end as state register (t2) is already 0
				blt a0, t0, cell_fate_end
				;if overpopulation, then go directly to end as state register (t2) is already 0
				bge a0, t1, cell_fate_end
				;if neither over or under population, then set state register to alive
				addi t2, zero, 1

			cell_fate_end:
			;return state of the cell
			add v0, zero, t2
		ret
	;END:cell_fate

	; BEGIN:find_neighbours 
		find_neighbours: 
		; a0 = x coordinate of examined cell (column) 
		; a1 = y coordinate of examined cell (row)
		
			;store return address on stack
			addi sp, sp, -4
			stw ra, 0 (sp)

			addi t0, zero, 0 ; state of the cell at location (x,y)
			addi t1, a1, 0 ; y coordinate

			addi t2, zero, 1 ; fixed value = 1
			addi t3, zero, 0 ; sum of living cells


			;--------------------------------------------------------------------------------------------
			addi a1, t1, -1 ; y - 1
			;get modulo of y - 1 mod 8 
			andi a1, a1, 7

			;store values on stack before calling function
			addi sp, sp, -16 
			stw t0, 0 (sp) 
			stw t1, 4 (sp)
			stw t3, 8 (sp)
			stw a0, 12 (sp) 
		
			call helper_find_neighbours

			;retrieve values from stack
        	ldw t0, 0 (sp)
			ldw t1, 4 (sp) 
        	ldw t3, 8 (sp)
			ldw a0, 12 (sp) 
			addi sp, sp, 16

			add t3, t3, v0 ; update the sum of living cells


			;--------------------------------------------------------------------
			addi a1, t1, 0 ; y

			;store values on stack before calling function
			addi sp, sp, -16 
			stw t0, 0 (sp) 
			stw t1, 4 (sp)
			stw t3, 8 (sp)
			stw a0, 12 (sp)
			
			call helper_find_neighbours

			;retrieve values from stack
        	ldw t0, 0 (sp)
			ldw t1, 4 (sp)
	        ldw t3, 8 (sp)
			ldw a0, 12 (sp)
			addi sp, sp, 16

			; -----
			add t3, t3, v0 ; update the sum of living cells
			sub t3, t3, v1 ;subtract the examined cell from the sum
			addi t0, v1, 0 ; store the state of the cell at location (x,y)
	


			;------------------------------------------------------------------------------
			addi a1, t1, 1 ; y + 1
			; y + 1 mod 8
			andi a1, a1, 7

			;store values on stack before calling function
			addi sp, sp, -8 
			stw t0, 0 (sp) 
			stw t3, 4 (sp) 
		
			call helper_find_neighbours

			;retrieve values from stack
        	ldw t0, 0 (sp) 
        	ldw t3, 4 (sp)
			addi sp, sp, 8

			; -----------------------------------------------------
			;return the correct outputs
			add v0, t3, v0
			addi v1, t0, 0
			
			;pop return address from stack 
			ldw ra, 0 (sp)
			addi sp, sp, 4

		ret
	;END:find_neighbours

	;BEGIN:update_gsa
		update_gsa:
			;store return address on stack
			addi sp, sp, -4
			stw ra, 0 (sp)
	
			;load the value of pause of the game, to know if we need to do anything or not
			ldw t0, PAUSE (zero)
			;if game is paused, then do nothing
			beq t0, zero, update_gsa_end 
			

			;gets the current GSA_ID
			ldw t0, GSA_ID (zero)
			;compute the opposite GSA_ID
			xori t0, t0, 1
			;upperbound for y coordinate
			addi t1, zero, 8
			;upperbound for x coordinate
			addi t2, zero, 12
			;counter for y coordinate
			addi t3, zero, 0
			;counter for x coordinate
			addi t4, zero, 0
			;stores current line of the gsa that we are working with in the loop
			addi t5, zero, 0
			;stores shifted value of the cell examined to the right position
			addi t6, zero, 0

			update_gsa_loop_y:
				update_gsa_loop_x:
				
					;x coordinate
					add a0, t4, zero
					;y coordinate
					add a1, t3, zero
					;get the neighbors
					
					;push temporary values onto stack
					addi sp, sp, -20 
					stw t0, 0 (sp)
					stw t1, 4 (sp)
					stw t2, 8 (sp)
					stw t3, 12 (sp)
					stw t4, 16 (sp)

					call find_neighbours

					;pop values from stack
					ldw t0, 0 (sp)
					ldw t1, 4 (sp)
					ldw t2, 8 (sp)
					ldw t3, 12 (sp)
					ldw t4, 16 (sp)
					addi sp, sp, 20

					;neighbors set as argument for cell_fate 
					add a0, v0, zero
					;current cell state set as argument for cell_fate
					add a1, v1, zero

					;push temporary values on stack
					addi sp, sp, -12
					stw t0, 0 (sp)
					stw t1, 4 (sp)
					stw t2, 8 (sp)

					call cell_fate
					
					;pop values from stack	
					ldw t0, 0 (sp)
					ldw t1, 4 (sp)
					ldw t2, 8 (sp)
					addi sp, sp, 12

					;shift the value of the next cell state to the correct position
					sll t6, v0, t4
					;update correct cell in the line of the gsa
					or t5, t5, t6
					;increment x counter
					addi t4, t4, 1
					;check if x counter reaches upperbound
					bne t4, t2, update_gsa_loop_x
				
				;store t5 (one line of the updated gsa) into the stack
				addi sp, sp, -4
				stw t5, 0 (sp)

				;set gsa line to zero for the next iteration
				addi t5, zero, 0
				;set x counter to zero
				addi t4, zero, 0

				;increment y counter
				addi t3, t3, 1
				;check if y counter reaches upperbound
				bne t3, t1, update_gsa_loop_y

			;inverse the GSA_ID
			stw t0, GSA_ID (zero)

			;y counter lower bound
			addi t1, zero, -1
			;y counter intialized to 7 (bottom most index of gsa)
			addi t3, zero, 7

			update_gsa_store_loop:
				;get gsa line from stack
				ldw a0, 0 (sp)
				addi sp, sp, 4

				;put y counter as argument
				addi a1, t3, 0 

				;push temporary values onto stack 
				addi sp, sp, -4 
				stw t1, 0 (sp)

				call set_gsa

				;pop temporary values from stack
				ldw t1, 0 (sp)
				addi sp, sp, 4

				;decrement y counter 
				addi t3, t3, -1 
				;check boundary condition for loop
				bne t3, t1, update_gsa_store_loop

			update_gsa_end:
			;pop return address from stack 
			ldw ra, 0 (sp)
			addi sp, sp, 4
		ret	
	;END:update_gsa


	;BEGIN:mask
		mask:
			;store return address on stack
			addi sp, sp, -4
			stw ra, 0 (sp)

			;load the current seed
			ldw t0, SEED (zero)
			;multiply seed by 4
			slli t0, t0, 2
			addi t0, t0, MASKS
			ldw t0, 0 (t0)
			;loop counter initiliazed to 0
			addi t1, zero, 0
			;upperbound for loop 
			addi t2, zero, 8 

			mask_loop:
				;load line of mask at coordinate y (t1)
				ldw t3, 0 (t0)
				;place y coordinate of gsa as argument
				addi a0, t1, 0

				;push values on stack before calling function
				addi sp, sp, -8
				stw t0, 0 (sp)
				stw t1, 4 (sp)

				call get_gsa

				;pop temporary values from stack
				ldw t0, 0 (sp)
				ldw t1, 4 (sp)
				addi sp, sp, 8

				;apply mask to gsa
				and a0, t3, v0
				;put y coordinate to correct argument before calling set_gsa
				addi a1, t1, 0
				
				;push values on stack before calling function
				addi sp, sp, -8
				stw t0, 0 (sp)
				stw t1, 4 (sp)

				call set_gsa

				;pop temporary values from stack
				ldw t0, 0 (sp)
				ldw t1, 4 (sp)
				addi sp, sp, 8
	
				;increment loop counter
				addi t1, t1, 1
				;increment the y coordinate of the mask to extract
				addi t0, t0, 4
				bne t1, t2, mask_loop 

			;pop return address from stack 
			ldw ra, 0 (sp)
			addi sp, sp, 4
		
		ret		
	;END:mask

	;BEGIN:get_input
		get_input:
			;store BUTTONS address + 4
			addi t0, zero, BUTTONS
			addi t0, t0, 4

			;load edgecapture from BUTTONS + 4
			ldw v0, 0 (t0)

			;reset edgecapture's last five bits to zero
			stw zero, 0 (t0)
		ret
	;END:get_input

	;BEGIN:decrement_step
		decrement_step:
			;load current state 
			ldw t0, CURR_STATE (zero)
			;store RUN state
			addi t1, zero, RUN
			;load current step
			ldw t5, CURR_STEP (zero)
			;check if current state is INIT
			bne t0, t1, decrement_step_INIT_RAND
			;checks if current step is zero
			beq t5, zero, decrement_step_zero
			;check if the game is paused
			ldw t0, PAUSE (zero)
			beq t0, zero, decrement_step_INIT_RAND
			
			addi t5, t5, -1
			stw t5, CURR_STEP (zero)

			decrement_step_INIT_RAND:
                ;loop counter initialized to 0
                addi t1, zero, 0
                ;loop upperbound 
                addi t2, zero, 12
                ;store 7-SEGs[0] address plus 12
                addi t3, zero, SEVEN_SEGS
                addi t3, t3, 12

                decrement_step_loop:
                    ;shift to extract the correct byte
                    srl t4, t5, t1
                    ;mask to only get LSByte of shifted word
                    andi t4, t4, 0xF
                    ;multiply LSByte by 4
                    slli t4, t4, 2
                    ;compute the address of the word for the corresponding digit
                    addi t4, t4, font_data
                    ;load 7-SEG digit
                    ldw t4, 0 (t4)
                    ;store the digit in the correct memory
                    stw t4, 0 (t3)
                    ;decrement 7-SEG address 
                    addi t3, t3, -4
                    ;increment counter by four
                    addi t1, t1, 4
                    ;continue loop if upperbound is not surpassed
                    bne t1, t2, decrement_step_loop
					 
				;return 0 (not done)
				addi v0, zero, 0
				br decrement_step_end

			decrement_step_zero:
				;return 1
				addi v0, zero, 1
			decrement_step_end:
		ret			
	;END:decrement_step

	;BEGIN:reset_game
		reset_game:
			;store return address on stack
			addi sp, sp, -4
			stw ra, 0 (sp)

			;constant 1
			addi t0, zero, 1

			;store 1 for the current_step
			stw t0, CURR_STEP (zero)

			;set current_state to INIT
			stw zero, CURR_STATE (zero)

			;set GSA_ID to zero
			stw zero, GSA_ID (zero)

			;set game speed to 1
			stw t0, SPEED (zero)

			;set current seed to zero
			stw zero, SEED (zero)
			;get address of seed0
			ldw a0, SEEDS (zero)
			;fill current gsa with the seed
			call helper_increment_seed

			;get font_data
			addi t0, zero, font_data
			;address for the font of "1"
			addi t0, t0, 4
			;load font for "1"
			ldw t0, 0 (t0)
			;store "1" (font) at the last 7SEG
			addi t1, zero, 12
			stw t0, SEVEN_SEGS (t1)
			;get the font for "0"
			ldw t0, font_data (zero)
			
			;loop counter starting at address SEVEN_SEGS + 4
			addi t1, zero, SEVEN_SEGS
			addi t1, t1, 0
			;loop upperbound
			addi t2, t1, 12

			;set the other three SEVEN_SEGS to zero
			reset_game_loop:
				;store the font of 0 in 7SEG
				stw t0, 0 (t1)
				;increment address
				addi t1, t1, 4

				bne t1, t2, reset_game_loop

			;set game to paused
			stw zero, PAUSE (zero)

			;draw the reset GSA (seed0) onto the LEDS
			call draw_gsa
			
			;pop return address from stack 
			ldw ra, 0 (sp)
			addi sp, sp, 4
		ret	
	;END:reset_game

	;BEGIN:helper
		;a0 := column of LEDS, a1 := byte to insert in the row of the LEDs,  
		helper_draw_gsa:
			;initialize counter to 0
			addi t0, zero, 0
			;counter upperbound 
			addi t1, zero, 4
			;return value to be modified
			addi v0, zero, 0

			helper_draw_gsa_loop:
				;get the correct bit from the gsa
				srl t2, a1, t0
				;mask to get only LSB
				andi t2, t2, 1
				;multiply counter by 8 to get correct postion in LEDs
				slli t3, t0, 3
				;add to column of the LEDs for which it needs to be inserted
				add t3, t3, a0
				;shift bit to be inserted to the correct insert position
				sll t2, t2, t3
				;place the bit into the return value
				or v0, v0, t2
				;increment loop counter
				addi t0, t0, 1
				;while condition
				bne t0, t1, helper_draw_gsa_loop
			ret		

		;a0 takes as argument address of the seed
		helper_increment_seed:
			;store return address on stack
			addi sp, sp, -4
			stw ra, 0 (sp)

			;initialize loop counter to 0
			addi t0, zero, 0
			;initialize loop upperbound
			addi t1, zero, 8
			;store seed address one to be at the first word
			addi t2, a0, 0
			loop_helper_increment_seed:
				;load the word of the seed that will be copied  
				ldw t3, 0 (t2)
				;argument for set_gsa, the line that will be inserted
				add a0, zero, t3
				;y-coordinate of the GSA word
				add a1, zero, t0 
				
				;push temporary values onto stack 
				addi sp, sp, -8
				stw t0, 0 (sp)
				stw t1, 4 (sp)

				call set_gsa

				;pop temporary values from stack
				ldw t0, 0 (sp)
				ldw t1, 4 (sp)
				addi sp, sp, 8

				;increment counter
				addi t0, t0, 1
				;increment address
				addi t2, t2, 4
				;if counter hasn't reached upperbound then continue loop
				bne t0, t1, loop_helper_increment_seed

			;pop return address from stack 
			ldw ra, 0 (sp)
			addi sp, sp, 4
		ret

	;a0 := x coordinate, a1:= y coordinate
	helper_find_neighbours: 
		;store return address on stack
		addi sp, sp, -4
		stw ra, 0 (sp)

		;IMPORTANT: t0 := x, t1 := x - 1, t2 := x + 1
		;store x coordinate into t0
		addi t0, a0, 0

		;store y coordinate in a0, for following functions calls
		addi a0, a1, 0

		;push temporary value t0 on stack
		addi sp, sp, -4
		stw t0, 0 (sp)
 
		;get the gsa
		call get_gsa

		;pop value from stack
		ldw t0, 0 (sp)
		addi sp, sp, 4

		;max value for x
		addi t1, zero, 11
		
		;check boundary conditions for x coordinate
		beq t0, zero, helper_find_neighbours_zero
		beq t0, t1, helper_find_neighbours_max_x
		br helper_find_neighbours_normal_x

		helper_find_neighbours_zero:
			;set x - 1 to 11
			addi t1, zero, 11
			;set x + 1 to x + 1
			addi t2, t0, 1
			br helper_find_neighbours_common_code
 
		helper_find_neighbours_max_x:
			;set x - 1 to x - 1
			addi t1, t0, -1
			;set x + 1 to 0
			addi t2, zero, 0
			br helper_find_neighbours_common_code

		helper_find_neighbours_normal_x:
			;set x - 1 to x - 1
			addi t1, t0, -1
			;set x + 1 to x + 1
			addi t2, t0, 1

		helper_find_neighbours_common_code:
			;shift gsa to get x - 1 as LSB
			srl t3, v0, t1
			;and to only get LSB
			andi t3, t3, 1 
			;add state of cell to sum	
			addi t4, t3, 0
				
			;shift gsa to get x as LSB
			srl t3, v0, t0
			;and to only get LSB
			andi t3, t3, 1
			;return the state of the middle x 
			addi v1, t3, 0  
			;add state of cell to sum	
			add t4, t4, t3

			;shift gsa to get x + 1 as LSB
			srl t3, v0, t2
			;and to only get LSB
			andi t3, t3, 1 
			;add state of cell to sum	
			add t4, t4, t3

			;return sum of the state of the cells
			addi v0, t4, 0	
			
			;pop return address from stack 
			ldw ra, 0 (sp)
			addi sp, sp, 4
		ret
	; END:helper

font_data:
    .word 0xFC ; 0
    .word 0x60 ; 1
    .word 0xDA ; 2
    .word 0xF2 ; 3
    .word 0x66 ; 4
    .word 0xB6 ; 5
    .word 0xBE ; 6
    .word 0xE0 ; 7
    .word 0xFE ; 8
    .word 0xF6 ; 9
    .word 0xEE ; A
    .word 0x3E ; B
    .word 0x9C ; C
    .word 0x7A ; D
    .word 0x9E ; E
    .word 0x8E ; F

seed0:
    .word 0xC00
    .word 0xC00
    .word 0x000
    .word 0x060
    .word 0x0A0
    .word 0x0C6
    .word 0x006
    .word 0x000

seed1:
    .word 0x000
    .word 0x000
    .word 0x05C
    .word 0x040
    .word 0x240
    .word 0x200
    .word 0x20E
    .word 0x000

seed2:
    .word 0x000
    .word 0x010
    .word 0x020
    .word 0x038
    .word 0x000
    .word 0x000
    .word 0x000
    .word 0x000

seed3:
    .word 0x000
    .word 0x000
    .word 0x090
    .word 0x008
    .word 0x088
    .word 0x078
    .word 0x000
    .word 0x000


    ;; Predefined seeds
SEEDS:
    .word seed0
    .word seed1
    .word seed2
    .word seed3

mask0:
    .word 0xFFF
    .word 0xFFF
    .word 0xFFF
    .word 0xFFF
    .word 0xFFF
    .word 0xFFF
    .word 0xFFF
    .word 0xFFF

mask1:
    .word 0xFFF
    .word 0xFFF
    .word 0xFFF
    .word 0xFFF
    .word 0xFFF
    .word 0x1FF
    .word 0x1FF
    .word 0x1FF

mask2:
    .word 0x7FF
    .word 0x7FF
    .word 0x7FF
    .word 0x7FF
    .word 0x7FF
    .word 0x7FF
    .word 0x7FF
    .word 0x7FF

mask3:
    .word 0xFFF
    .word 0xFFF
    .word 0xFFF
    .word 0xFFF
    .word 0xFFF
    .word 0xFFF
    .word 0xFFF
    .word 0x000

mask4:
    .word 0xFFF
    .word 0xFFF
    .word 0xFFF
    .word 0xFFF
    .word 0xFFF
    .word 0xFFF
    .word 0xFFF
    .word 0x000

MASKS:
    .word mask0
    .word mask1
    .word mask2
    .word mask3
    .word mask4

