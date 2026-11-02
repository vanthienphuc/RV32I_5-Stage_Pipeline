.section .text
.global main

main:
    # ==============================================================
    # TEST 1: JAL AND PIPELINE FLUSH
    # ==============================================================
    # JAL should skip the next two instructions.
    jal x0, test_forwarding

    # Jump trap: reached if JAL or flush fails
    addi x7, x0, -1
    beq  x0, x0, end

test_forwarding:
    # ==============================================================
    # TEST 2: DATA FORWARDING (CONSECUTIVE ALU INSTRUCTIONS)
    # ==============================================================
    addi x2, x0, 5       # x2 = 5
    add  x3, x2, x2      # x3 = 10; forward both operands from EX/MEM
    add  x4, x3, x2      # x4 = 15; forward x3 from EX/MEM and x2 from MEM/WB

    # Check forwarding result
    addi x11, x0, 15
    bne  x4, x11, fail

    # ==============================================================
    # TEST 3: STORE DATA FORWARDING
    # ==============================================================
    addi x1, x0, 64      # Base address = 64
    addi x5, x0, 20      # x5 = 20
    sw   x5, 0(x1)       # Store 20 at memory address 64

    # ==============================================================
    # TEST 4: LOAD-USE HAZARD (STALL AND BUBBLE)
    # ==============================================================
    lw   x6, 0(x1)       # Load 20 from memory address 64
    add  x8, x6, x4      # x8 = 20 + 15 = 35; requires a stall and forwarding

    # Check the result after the stall
    addi x11, x0, 35
    bne  x8, x11, fail

    # ==============================================================
    # TEST 5: LUI AND JALR (CLEAR BIT 0)
    # ==============================================================
    # Build the target address using LUI and ADDI
    lui  x9, %hi(target_jalr)
    addi x9, x9, %lo(target_jalr)

    # Make the address odd to test JALR bit-0 clearing
    addi x9, x9, 1

    jalr x12, x9, 0     # Jump to target_jalr and save the return address in x12

    # JALR trap: reached if the jump or flush fails
    addi x7, x0, -1
    beq  x0, x0, end

target_jalr:
    # Check that JALR saved the return address
    beq  x12, x0, fail

    # ==============================================================
    # TEST 6: CONDITIONAL BRANCH (BEQ) AND FLUSH
    # ==============================================================
    beq  x8, x8, success # Always taken because x8 = x8

    # Branch trap: reached if branch resolution fails
    addi x7, x0, -1
    beq  x0, x0, end

fail:
    addi x7, x0, -1      # Set failure flag (x7 = -1)
    beq  x0, x0, end

success:
    addi x7, x0, 1       # Set success flag (x7 = 1)

end:
    beq  x0, x0, end     # Infinite loop to stop execution


