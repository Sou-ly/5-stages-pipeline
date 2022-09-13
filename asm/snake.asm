;    set game state memory location
.equ    HEAD_X,         0x1000  ; Snake head's position on x
.equ    HEAD_Y,         0x1004  ; Snake head's position on y
.equ    TAIL_X,         0x1008  ; Snake tail's position on x
.equ    TAIL_Y,         0x100C  ; Snake tail's position on Y
.equ    SCORE,          0x1010  ; Score address
.equ    GSA,            0x1014  ; Game state array address

.equ    CP_VALID,       0x1200  ; Whether the checkpoint is valid.
.equ    CP_HEAD_X,      0x1204  ; Snake head's X coordinate. (Checkpoint)
.equ    CP_HEAD_Y,      0x1208  ; Snake head's Y coordinate. (Checkpoint)
.equ    CP_TAIL_X,      0x120C  ; Snake tail's X coordinate. (Checkpoint)
.equ    CP_TAIL_Y,      0x1210  ; Snake tail's Y coordinate. (Checkpoint)
.equ    CP_SCORE,       0x1214  ; Score. (Checkpoint)
.equ    CP_GSA,         0x1218  ; GSA. (Checkpoint)

.equ    LEDS,           0x2000  ; LED address
.equ    SEVEN_SEGS,     0x1198  ; 7-segment display addresses
.equ    RANDOM_NUM,     0x2010  ; Random number generator address
.equ    BUTTONS,        0x2030  ; Buttons addresses

; button state
.equ    BUTTON_NONE,    0
.equ    BUTTON_LEFT,    1
.equ    BUTTON_UP,      2
.equ    BUTTON_DOWN,    3
.equ    BUTTON_RIGHT,   4
.equ    BUTTON_CHECKPOINT,    5

; array state
.equ    DIR_LEFT,       1       ; leftward direction
.equ    DIR_UP,         2       ; upward direction
.equ    DIR_DOWN,       3       ; downward direction
.equ    DIR_RIGHT,      4       ; rightward direction
.equ    FOOD,           5       ; food

; constants
.equ    NB_ROWS,        8       ; number of rows
.equ    NB_COLS,        12      ; number of columns
.equ    NB_CELLS,       96      ; number of cells in GSA
.equ    RET_ATE_FOOD,   1       ; return value for hit_test when food was eaten
.equ    RET_COLLISION,  2       ; return value for hit_test when a collision was detected
.equ    ARG_HUNGRY,     0       ; a0 argument for move_snake when food wasn't eaten
.equ    ARG_FED,        1       ; a0 argument for move_snake when food was eaten

; initialize stack pointer
addi    sp, zero, LEDS

; main
; arguments
;     none
;
; return values
;     This procedure should never return.
main:
stw zero, CP_VALID(zero)
init:
call init_game
getinput:
call wait
call get_input
addi t0, zero, 5
beq v0, t0, restore
call hit_test
addi t0, zero, 1
beq v0, t0, eatfood
beq v0, zero, move
br init

move:
add a0, zero, zero
call move_snake
br draw

eatfood:
ldw t0, SCORE(zero)
addi t0, t0, 1
stw t0, SCORE(zero)
call display_score
addi a0, zero, 1
call move_snake
call create_food 
call save_checkpoint
beq v0, zero, draw
br blinkscore

restore:
call restore_checkpoint
beq v0, zero, getinput
br blinkscore

blinkscore:
call blink_score
draw:
call clear_leds
call draw_array
br getinput


    ; TODO: Finish this procedure.
	

; BEGIN: clear_leds
clear_leds:
	stw zero, LEDS(zero)
	stw zero, LEDS+4(zero)
	stw zero, LEDS+8(zero)
	ret
; END: clear_leds

; BEGIN: set_pixel
set_pixel:
	; a0 x coordinate
	; a1 y coordinate 
	; t0 is offset
	andi t0, a0, 3
	; t1 is LED index
	srli t1, a0, 2
	slli t1, t1, 2
	; t2 is the position of the pixel in the word
	slli t2, t0, 3 
	add t2, t2, a1  ; 8 * x + y
	; t3 is the new pixel bit
	addi t3, zero, 1
	sll t3, t3, t2
	; load the current LED word
	ldw t4, LEDS(t1)
	; add the bit
	or t4, t4, t3
	stw t4, LEDS(t1)
	ret
; END: set_pixel

; BEGIN: display_score
display_score:
	; display 00 on seven_seg 3 et 4
	ldw t1, digit_map(zero) ;
	stw t1, SEVEN_SEGS (zero) 
	stw t1, SEVEN_SEGS + 4(zero)
	;extraction of two digits
	addi t4, zero, 10 ; constante = 10
	add t3, zero, zero ; will count the number of tens
	ldw t2, SCORE(zero); at the end will be the rest (ie the unit digit)
	blt t2, t4, return_display
	modulo_10:
	sub t2, t2, t4
	addi t3, t3, 1 
	bge t2, t4, modulo_10 ; loop while score >= t4 (=10)
	return_display:
	slli t3, t3, 2
	ldw t5, digit_map(t3)
	stw t5, SEVEN_SEGS + 8(zero) ; load and store the tens digit on seven_seg 1
	slli t2,t2, 2
	ldw t6, digit_map(t2)
	stw t6, SEVEN_SEGS + 12(zero) ; load and store the unit digit on seven_seg 0
ret
; END: display_score

; BEGIN: init_game
init_game:
	addi sp, sp, -4
	stw  ra, 0(sp)
	stw zero, HEAD_X(zero)
	stw zero, HEAD_Y(zero)
	stw zero, TAIL_X(zero)
	stw zero, TAIL_Y(zero)
	add t5, zero, zero
	addi t6, zero, 384
	init_loop:
		bge t5, t6, end_init_loop
		stw zero, GSA(t5)
		addi t5, t5, 4
		br init_loop
	end_init_loop:
	stw zero, SCORE(zero)
	ldw t0, GSA(zero)
	addi t0, zero, 4
	stw t0, GSA(zero)
	call create_food
	call clear_leds
	call draw_array
	call display_score 
	ldw  ra, 0(sp)
	addi sp, sp, 4
ret
; END: init_game



; BEGIN: create_food
create_food:
	addi t1, zero, 96
	get_rand_num:
	ldw  t0, RANDOM_NUM(zero)
	andi t0, t0, 255 ; get lowest byte
	bge  t0, t1, get_rand_num
	slli t0, t0, 2  ; align with GSA words
	; check if that place is already occupied, if not, place food
	ldw  t2, GSA(t0)
	bne  t2, zero, get_rand_num
	addi t3, zero, 5
	stw  t3, GSA(t0)
	ret
; END: create_food


; BEGIN: hit_test
hit_test:
	add v0, zero, zero
	ldw  t0, HEAD_X(zero)
	ldw  t1, HEAD_Y(zero)
	slli t2, t0, 3
	add  t2, t2, t1
	slli t2, t2, 2
	; get direction of the head to get tile it is facing
	ldw  t3, GSA(t2)
	addi t4, zero, 1
	bne  t3, t4, test_up
	beq  t0, zero, collision
	addi t0, t0, -1
	br check_cell
	test_up:
		addi t4, zero, 2
		bne  t3, t4, test_down
		beq  t1, zero, collision
		addi t1, t1, -1
		br check_cell
	test_down:
		addi t4, zero, 3
		bne  t3, t4, test_right
		addi t5, zero, 7
		beq  t1, t5, collision
		addi t1, t1, 1
		br check_cell
	test_right:
		addi t4, zero, 4
		bne  t3, t4, return_hit_test
		addi t5, zero, 11
		beq  t0, t5, collision
		addi t0, t0, 1
	check_cell:
		; retrieve the cell faced
		slli t2, t0, 3
		add  t2, t2, t1
		slli t2, t2, 2
		ldw  t3, GSA(t2)
		beq  t3, zero, return_hit_test
		addi t4, zero, 5
		blt  t3, t4, collision
		addi v0, zero, 1
		br   return_hit_test
	collision:
		addi v0, zero, 2
	return_hit_test:
	ret
; END: hit_test

; BEGIN: get_input
get_input:
	; convert 2^n to n
	ldw t0, BUTTONS+4(zero) ; edgecapture 5 lsb
	addi t1, zero, 0 ; bit index, value to store in v0
	addi t2, zero, 5 ; max index
	get_input_loop:
		bge t1, t2, return_input
		srl t3, t0, t1 ; t3 = (t0 >> t1) 
		andi t3, t3, 1  ; t3 = t3 && 1
		bne t3, zero, get_input_end_loop ; break if edgecapture[$t1] = 1
		addi t1, t1, 1  ; t1++
		br get_input_loop
	get_input_end_loop:
	addi t1, t1, 1
	add  v0, zero, t1 ; button pressed
	; check if checkpoint
	beq  v0, t2, return_input
	; check if opposite to current direction
	add  v0, zero, zero
	ldw  t4, HEAD_X(zero)
	ldw  t5, HEAD_Y(zero)
	slli t4, t4, 3
	add  t4, t4, t5
	slli t4, t4, 2
	ldw  t5, GSA(t4)
	add  t5, t1, t5
	beq  t5, t2, return_input
	add v0, zero, t1
	stw v0, GSA(t4)
	return_input:
	; reset BUTTONS+4 LSB
	srli t0, t0, 5
	slli t0, t0, 5
	stw  t0, BUTTONS+4(zero)
	ret 
; END: get_input

; BEGIN: draw_array
draw_array:
	addi sp, sp, -12
	stw  ra, 0(sp)
	stw  a0, 4(sp)
	stw  a1, 8(sp)
	add  a0, zero, zero ; x
	addi s0, zero, 12  ; max row index
	addi s1, zero, 8   ; max column index
	row_loop:
		bge  a0, s0, return_draw
		add  a1, zero, zero ; y
		col_loop:
			bge  a1, s1, end_row_loop
			slli s2, a0, 3
			add  s2, s2, a1
			slli s2, s2, 2 ; *4 to align with words
			ldw  s3, GSA(s2)
			beq  s3, zero, end_col_loop
			call set_pixel
		end_col_loop:
			addi a1, a1, 1
			br   col_loop
	end_row_loop:
		addi a0, a0, 1
		br   row_loop
	return_draw:
	ldw  ra, 0(sp)
	ldw  a0, 4(sp)
	ldw  a1, 8(sp)
	addi sp, sp, 12
	ret
; END: draw_array



; BEGIN: move_snake
move_snake:
	addi sp, sp, -4
	stw  ra, 0(sp)
	add  s0, zero, a0
	; head update
	ldw  a0, HEAD_X(zero)
	ldw  a1, HEAD_Y(zero)
	slli s1, a0, 3
	add  s1, s1, a1
	slli s1, s1, 2
	ldw  s2, GSA(s1)
	call get_front_cell
	stw  v0, HEAD_X(zero)
	stw  v1, HEAD_Y(zero)
	slli t0, v0, 3
	add  t0, t0, v1
	slli t0, t0, 2
	stw  s2, GSA(t0)
	bne  s0, zero, end_move
	; tail update
	ldw  a0, TAIL_X(zero)
	ldw  a1, TAIL_Y(zero)
	slli s1, a0, 3
	add  s1, s1, a1
	slli s1, s1, 2
	call get_front_cell
	stw  v0, TAIL_X(zero)
	stw  v1, TAIL_Y(zero)
	stw  zero, GSA(s1)
	end_move:
	ldw  ra, 0(sp)
	addi sp, sp, 4
	ret

get_front_cell:
	slli t0, a0, 3
	add  t0, t0, a1
	slli t0, t0, 2
	ldw  t1, GSA(t0)
	beq  t1, zero, return_front_cell
	addi t2, zero, 5
	bge  t1, t2, return_front_cell
	add  v0, zero, a0
	add  v1, zero, a1
	get_left:
		addi t2, zero, 1
		bne  t1, t2, get_up
		addi v0, v0, -1
		br return_front_cell
	get_up:
		addi t2, zero, 2
		bne  t1, t2, get_down
		addi v1, v1, -1
		br return_front_cell
	get_down:
		addi t2, zero, 3
		bne  t1, t2, get_right
		addi v1, v1, 1
		br return_front_cell
	get_right:
		addi v0, v0, 1
	return_front_cell:
	ret 
; END: move_snake

; BEGIN: save_checkpoint
save_checkpoint:
	ldw t0, SCORE(zero);
	addi t1, zero, 10
	blt t0, t1, equal_zero
	mod_10:
	sub t0, t0, t1 
	bge t0, t1, mod_10 
	equal_zero:
	beq t0, zero, compute_checkpoint
	add v0, zero, zero
	br return_save_checkpoint
	compute_checkpoint:
	ldw t3, CP_VALID(zero)
	addi t3, t3,1 
	stw t3, CP_VALID(zero)
	add t5, zero, zero
	addi t6, zero, 384
	save_loop:
		bge t5, t6, end_save_loop
		ldw t4, GSA(t5)
		stw t4, CP_GSA(t5)
		addi t5, t5, 4
		br save_loop
	end_save_loop:
	ldw t4, SCORE(zero)
	stw t4, CP_SCORE(zero)
	ldw t4, HEAD_X(zero)
	stw t4, CP_HEAD_X(zero)
	ldw t4, HEAD_Y(zero)
	stw t4, CP_HEAD_Y(zero)
	ldw t4, TAIL_X(zero)
	stw t4, CP_TAIL_X(zero)
	ldw t4, TAIL_Y(zero)
	stw t4, CP_TAIL_Y(zero)
	addi v0, zero, 1
	return_save_checkpoint:
	ret
; END: save_checkpoint

; BEGIN: restore_checkpoint
restore_checkpoint:
	ldw t0, CP_VALID(zero)
	addi t1, zero, 1
	beq t0, t1, overwrite_game
	add v0, zero, zero
	br return_restore_checkpoint
	overwrite_game:
	add t5, zero, zero
	addi t6, zero, 384
	restore_loop:
		bge t5, t6, end_restore_loop
		ldw t4, CP_GSA(t5)
		stw t4, GSA(t5)
		addi t5, t5, 4
		br restore_loop
	end_restore_loop:
	ldw t4, CP_SCORE(zero)
	stw t4, SCORE(zero)
	ldw t4, CP_HEAD_X(zero)
	stw t4, HEAD_X(zero)
	ldw t4, CP_HEAD_Y(zero)
	stw t4, HEAD_Y(zero)
	ldw t4, CP_TAIL_X(zero)
	stw t4, TAIL_X(zero)
	ldw t4, CP_TAIL_Y(zero)
	stw t4, TAIL_Y(zero)
	addi v0, zero, 1
	return_restore_checkpoint:
	ret
; END: restore_checkpoint

; BEGIN: blink_score
blink_score: 
	addi sp, sp, -4
	stw  ra, 0(sp)
	stw zero, SEVEN_SEGS (zero)
	stw zero, SEVEN_SEGS +4(zero)
	stw zero, SEVEN_SEGS +8(zero)
	stw zero, SEVEN_SEGS +12(zero)
	call wait
	call display_score
	ldw  ra, 0(sp)
	addi sp, sp, 4
	ret
; END: blink_score

wait:
	addi t0, zero, 1
	slli t0, t0, 21
	wait_loop:
		beq t0, zero, stop_wait
		addi t0, t0, -1
		br wait_loop
	stop_wait:
	ret
digit_map:
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