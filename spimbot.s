# syscall constants
PRINT_STRING            = 4
PRINT_CHAR              = 11
PRINT_INT               = 1

# memory-mapped I/O
VELOCITY                = 0xffff0010
ANGLE                   = 0xffff0014
ANGLE_CONTROL           = 0xffff0018

BOT_X                   = 0xffff0020
BOT_Y                   = 0xffff0024

TIMER                   = 0xffff001c
GET_MAP                 = 0xffff2008

REQUEST_PUZZLE          = 0xffff00d0  ## Puzzle
SUBMIT_SOLUTION         = 0xffff00d4  ## Puzzle

BONK_INT_MASK           = 0x1000
BONK_ACK                = 0xffff0060

TIMER_INT_MASK          = 0x8000
TIMER_ACK               = 0xffff006c

REQUEST_PUZZLE_INT_MASK = 0x800       ## Puzzle
REQUEST_PUZZLE_ACK      = 0xffff00d8  ## Puzzle

RESPAWN_INT_MASK        = 0x2000      ## Respawn
RESPAWN_ACK             = 0xffff00f0  ## Respawn

SHOOT                   = 0xffff2000
CHARGE_SHOT             = 0xffff2004

GET_OP_BULLETS          = 0xffff200c
GET_MY_BULLETS          = 0xffff2010
GET_AVAILABLE_BULLETS   = 0xffff2014

MMIO_STATUS             = 0xffff204c

.data
puzzle_received: .word 0
### Puzzle
board:     .space 512
#### Puzzle

# If you want, you can use the following to detect if a bonk has happened.
has_bonked: .byte 0

.text
main:
    sub $sp, $sp, 4
    sw  $ra, 0($sp)

    # Construct interrupt mask
    li      $t4, 0
    or      $t4, $t4, TIMER_INT_MASK            # enable timer interrupt
    or      $t4, $t4, BONK_INT_MASK             # enable bonk interrupt
    or      $t4, $t4, REQUEST_PUZZLE_INT_MASK   # enable puzzle interrupt
    or      $t4, $t4, 1 # global enable
    mtc0    $t4, $12
    
    li $t1, 0
    sw $t1, ANGLE
    li $t1, 1
    sw $t1, ANGLE_CONTROL
    li $t2, 0
    sw $t2, VELOCITY
        
    # YOUR CODE GOES HERE!!!!!!
    jal puzzle_part
    jal part_one
    
loop: # Once done, enter an infinite loop so that your bot can be graded by QtSpimbot once 10,000,000 cycles have elapsed
    j loop


puzzle_part:
    li $t1, 0
    la $t2, puzzle_received
    sw $t1, 0($t2)
    li $t1, 0 # iterations
    la $t2, board
    sw $t2, REQUEST_PUZZLE
while:
    la $t2, puzzle_received
    lw $t2, 0($t2)
    bne $t2, $0, skip
    j while
skip:
    la $a0, board
    sub $sp, $sp, 4
    sw $ra, 0($sp)
    jal quant_solve
    la $t2, board
    sw $t2, SUBMIT_SOLUTION
    lw $ra, 0($sp)
    add $sp, $sp, 4
    jr $ra


part_one:
    li $t1, 1
    sw $t1, CHARGE_SHOT
    lw $t2, TIMER
    add $t2, $t2, 10000 
c_loop:
    lw $t3, TIMER
    bge $t3, $t2, skip_loop
    j c_loop
skip_loop:
    li $t2, 0
    sw $t2, SHOOT

    # shoot down
    li $t1, 2
    sw $t1, CHARGE_SHOT
    lw $t2, TIMER
    add $t2, $t2, 10000 
c_loop2:
    lw $t3, TIMER
    bge $t3, $t2, skip_loop2
    j c_loop2
skip_loop2:
    li $t2, 0
    sw $t2, SHOOT

    # test new thing 
    # set direction
    #li $t2, 0
    #sw $t2, ANGLE
    #li $t2, 1
    #sw $t2, ANGLE_CONTROL

    li $t1, 0 # i 
large_loop:
    bge $t1, 4, skip_large_loop
    li $t2, 8
    sw $t2, VELOCITY
    lw $t2, TIMER
    add $t2, $t2, 24000
move_loop:
    lw $t3, TIMER
    bge $t3, $t2, skip_m_loop
    j move_loop
skip_m_loop:
    #stop
    li $t2, 0
    sw $t2, VELOCITY
    # shoot down
    li $t2, 2
    sw $t2, CHARGE_SHOT
    lw $t2, TIMER
    add $t2, $t2, 10000 
s_loop:
    lw $t3, TIMER
    bge $t3, $t2, skip_s_loop
    j s_loop
skip_s_loop:
    li $t2, 0
    sw $t2, SHOOT
    add $t1, $t1, 1
    j large_loop
skip_large_loop:
    jr $ra
    

.kdata
chunkIH:    .space 40
non_intrpt_str:    .asciiz "Non-interrupt exception\n"
unhandled_str:    .asciiz "Unhandled interrupt type\n"
.ktext 0x80000180
interrupt_handler:
.set noat
    move    $k1, $at        # Save $at
                            # NOTE: Don't touch $k1 or else you destroy $at!
.set at
    la      $k0, chunkIH
    sw      $a0, 0($k0)        # Get some free registers
    sw      $v0, 4($k0)        # by storing them to a global variable
    sw      $t0, 8($k0)
    sw      $t1, 12($k0)
    sw      $t2, 16($k0)
    sw      $t3, 20($k0)
    sw      $t4, 24($k0)
    sw      $t5, 28($k0)

    # Save coprocessor1 registers!
    # If you don't do this and you decide to use division or multiplication
    #   in your main code, and interrupt handler code, you get WEIRD bugs.
    mfhi    $t0
    sw      $t0, 32($k0)
    mflo    $t0
    sw      $t0, 36($k0)

    mfc0    $k0, $13                # Get Cause register
    srl     $a0, $k0, 2
    and     $a0, $a0, 0xf           # ExcCode field
    bne     $a0, 0, non_intrpt



interrupt_dispatch:                 # Interrupt:
    mfc0    $k0, $13                # Get Cause register, again
    beq     $k0, 0, done            # handled all outstanding interrupts

    and     $a0, $k0, BONK_INT_MASK     # is there a bonk interrupt?
    bne     $a0, 0, bonk_interrupt

    and     $a0, $k0, TIMER_INT_MASK    # is there a timer interrupt?
    bne     $a0, 0, timer_interrupt

    and     $a0, $k0, REQUEST_PUZZLE_INT_MASK
    bne     $a0, 0, request_puzzle_interrupt

    and     $a0, $k0, RESPAWN_INT_MASK
    bne     $a0, 0, respawn_interrupt

    li      $v0, PRINT_STRING       # Unhandled interrupt types
    la      $a0, unhandled_str
    syscall
    j       done

bonk_interrupt:
    sw      $0, BONK_ACK
    la      $t0, has_bonked
    li      $t1, 1
    sb      $t1, 0($t0)
    #Fill in your bonk handler code here
    j       interrupt_dispatch      # see if other interrupts are waiting

timer_interrupt:
    sw      $0, TIMER_ACK
    #Fill in your timer interrupt code here
    j        interrupt_dispatch     # see if other interrupts are waiting

request_puzzle_interrupt:
    sw      $0, REQUEST_PUZZLE_ACK
    #Fill in your puzzle interrupt code here
    li $t0, 1
    sw $t0, puzzle_received
    j       interrupt_dispatch

respawn_interrupt:
    sw      $0, RESPAWN_ACK
    #Fill in your respawn handler code here
    j       interrupt_dispatch

non_intrpt:                         # was some non-interrupt
    li      $v0, PRINT_STRING
    la      $a0, non_intrpt_str
    syscall                         # print out an error message
    # fall through to done

done:
    la      $k0, chunkIH

    # Restore coprocessor1 registers!
    # If you don't do this and you decide to use division or multiplication
    #   in your main code, and interrupt handler code, you get WEIRD bugs.
    lw      $t0, 32($k0)
    mthi    $t0
    lw      $t0, 36($k0)
    mtlo    $t0

    lw      $a0, 0($k0)             # Restore saved registers
    lw      $v0, 4($k0)
    lw      $t0, 8($k0)
    lw      $t1, 12($k0)
    lw      $t2, 16($k0)
    lw      $t3, 20($k0)
    lw      $t4, 24($k0)
    lw      $t5, 28($k0)

.set noat
    move    $at, $k1        # Restore $at
.set at
    eret