#!/usr/bin/env python3
"""
Assembles a small subset of RV64I into byte-addressed hex (Big-Endian, one byte/line).
Supports: add, sub, and, or, addi, ld, sd, beq
Outputs instructions_edge.txt and expected_edge.txt
"""

REGS = {f"x{i}": i for i in range(32)}

def r_type(funct7, rs2, rs1, funct3, rd):
    return (funct7 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | 0b0110011

def i_type(imm, rs1, funct3, rd, opcode):
    imm = imm & 0xFFF
    return (imm << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode

def s_type(imm, rs2, rs1):
    imm = imm & 0xFFF
    hi = (imm >> 5) & 0x7F
    lo = imm & 0x1F
    return (hi << 25) | (rs2 << 20) | (rs1 << 15) | (0b011 << 12) | (lo << 7) | 0b0100011

def b_type(offset, rs2, rs1):
    # offset is the actual byte offset; encoding drops bit 0
    imm = (offset >> 1) & 0xFFF
    b12 = (imm >> 11) & 1
    b11 = (imm >> 10) & 1  # this is actually imm[11] in the offset, but encoded differently
    # Let me redo this properly from the offset
    # offset bits: [12:1] are encoded (bit 0 dropped)
    b12  = (offset >> 12) & 1
    b11  = (offset >> 11) & 1
    b10_5 = (offset >> 5) & 0x3F
    b4_1  = (offset >> 1) & 0xF
    return (b12 << 31) | (b10_5 << 25) | (rs2 << 20) | (rs1 << 15) | (0b000 << 12) | (b4_1 << 8) | (b11 << 7) | 0b1100011

def encode(asm):
    parts = asm.replace(",", " ").split()
    op = parts[0]
    if op == "add":
        return r_type(0b0000000, REGS[parts[3]], REGS[parts[2]], 0b000, REGS[parts[1]])
    elif op == "sub":
        return r_type(0b0100000, REGS[parts[3]], REGS[parts[2]], 0b000, REGS[parts[1]])
    elif op == "and":
        return r_type(0b0000000, REGS[parts[3]], REGS[parts[2]], 0b111, REGS[parts[1]])
    elif op == "or":
        return r_type(0b0000000, REGS[parts[3]], REGS[parts[2]], 0b110, REGS[parts[1]])
    elif op == "addi":
        return i_type(int(parts[3]), REGS[parts[2]], 0b000, REGS[parts[1]], 0b0010011)
    elif op == "ld":
        # ld rd, imm(rs1)
        imm_rs = parts[2]  # e.g. "0(x20)"
        imm_str, rs = imm_rs.split("(")
        return i_type(int(imm_str), REGS[rs.rstrip(")")], 0b011, REGS[parts[1]], 0b0000011)
    elif op == "sd":
        # sd rs2, imm(rs1)
        imm_rs = parts[2]
        imm_str, rs = imm_rs.split("(")
        return s_type(int(imm_str), REGS[parts[1]], REGS[rs.rstrip(")")])
    elif op == "beq":
        return b_type(int(parts[3]), REGS[parts[2]], REGS[parts[1]])

def to_bytes(word):
    return [(word >> 24) & 0xFF, (word >> 16) & 0xFF, (word >> 8) & 0xFF, word & 0xFF]

# ============================================================
# Edge case test program
# ============================================================
program = [
    # -- x0 hardwired to 0 --
    "addi x0, x0, 100",       # x0 should stay 0

    # -- Negative immediates --
    "addi x1, x0, -1",        # x1 = -1  (0xFFFF...FFFF)
    "addi x2, x0, -2048",     # x2 = -2048  (min I-type imm)
    "addi x3, x0, 2047",      # x3 = 2047   (max I-type imm)

    # -- Arithmetic with mixed signs --
    "add x4, x1, x3",         # x4 = -1 + 2047 = 2046
    "sub x5, x3, x4",         # x5 = 2047 - 2046 = 1
    "sub x6, x3, x3",         # x6 = 0  (sub producing zero)

    # -- Bitwise edge cases --
    "and x7, x1, x3",         # x7 = all_1s & 0x7FF = 0x7FF = 2047
    "and x8, x1, x6",         # x8 = all_1s & 0 = 0
    "or  x9, x3, x6",         # x9 = 2047 | 0 = 2047
    "or  x10, x2, x3",        # x10 = -2048 | 2047 = -1 (all 1s)

    # -- beq NOT taken --
    "beq x5, x6, 8",          # x5=1 != x6=0 → not taken

    # -- This MUST execute (not skipped) --
    "addi x11, x0, 42",       # x11 = 42

    # -- Memory: base address setup --
    "addi x20, x0, 0",        # x20 = 0

    # -- sd/ld basic --
    "sd x1, 0(x20)",          # mem[0..7] = -1
    "ld x12, 0(x20)",         # x12 = -1

    # -- sd/ld with offset --
    "sd x3, 8(x20)",          # mem[8..15] = 2047
    "ld x13, 8(x20)",         # x13 = 2047

    # -- Back-to-back sd then ld --
    "sd x4, 16(x20)",         # mem[16..23] = 2046
    "ld x14, 16(x20)",        # x14 = 2046

    # -- beq TAKEN (equal values) --
    "beq x6, x0, 8",          # x6=0 == x0=0 → branch to PC+8, skip next

    # -- This must be SKIPPED --
    "addi x15, x0, 999",      # x15 should stay 0

    # -- After branch target: use ld results --
    "add x16, x11, x12",      # x16 = 42 + (-1) = 41

    # -- More arithmetic --
    "addi x17, x0, 1",        # x17 = 1
    "sub x18, x0, x1",        # x18 = 0 - (-1) = 1

    # -- Second write-to-x0 attempt --
    "addi x0, x3, 500",       # x0 stays 0

    # -- Self-OR / self-AND --
    "or  x19, x10, x10",      # x19 = -1 | -1 = -1
    "and x21, x4, x4",        # x21 = 2046

    # -- beq TAKEN on equal non-zero regs --
    "beq x7, x3, 8",          # x7=2047 == x3=2047 → branch, skip next

    # -- This must be SKIPPED --
    "addi x22, x0, 111",      # x22 should stay 0

    # -- Final computation proving everything works --
    "add x23, x16, x17",      # x23 = 41 + 1 = 42
]

# Encode
machine_code = [encode(line) for line in program]

# Write instructions_edge.txt
with open("tests/instructions_edge.txt", "w") as f:
    for word in machine_code:
        for b in to_bytes(word):
            f.write(f"{b:02X}\n")

# Simulate to get expected register values
regs = [0] * 32
mem = bytearray(1024)
pc = 0

def sign_extend(val, bits):
    if val & (1 << (bits - 1)):
        val -= (1 << bits)
    return val

def to_64(val):
    return val & 0xFFFFFFFFFFFFFFFF

cycle = 0
instr_bytes = []
for word in machine_code:
    instr_bytes.extend(to_bytes(word))
# Pad to at least 4 more bytes (termination)
instr_bytes.extend([0, 0, 0, 0])

while True:
    word = (instr_bytes[pc] << 24) | (instr_bytes[pc+1] << 16) | (instr_bytes[pc+2] << 8) | instr_bytes[pc+3]
    cycle += 1
    if word == 0:
        break

    opcode = word & 0x7F
    rd = (word >> 7) & 0x1F
    funct3 = (word >> 12) & 0x7
    rs1 = (word >> 15) & 0x1F
    rs2 = (word >> 20) & 0x1F
    funct7 = (word >> 25) & 0x7F

    if opcode == 0b0110011:  # R-type
        a, b_ = to_64(regs[rs1]), to_64(regs[rs2])
        if funct7 == 0b0100000:  # sub
            result = to_64(a - b_)
        elif funct3 == 0b111:    # and
            result = a & b_
        elif funct3 == 0b110:    # or
            result = a | b_
        else:                    # add
            result = to_64(a + b_)
        if rd != 0:
            regs[rd] = result
        pc += 4

    elif opcode == 0b0010011:  # addi
        imm = sign_extend((word >> 20) & 0xFFF, 12)
        result = to_64(regs[rs1] + imm)
        if rd != 0:
            regs[rd] = result
        pc += 4

    elif opcode == 0b0000011:  # ld
        imm = sign_extend((word >> 20) & 0xFFF, 12)
        addr = (regs[rs1] + imm) & 0xFFFFFFFFFFFFFFFF
        addr10 = int(addr) & 0x3FF
        val = 0
        for i in range(8):
            val = (val << 8) | mem[addr10 + i]
        if rd != 0:
            regs[rd] = val
        pc += 4

    elif opcode == 0b0100011:  # sd
        imm_hi = (word >> 25) & 0x7F
        imm_lo = (word >> 7) & 0x1F
        imm = sign_extend((imm_hi << 5) | imm_lo, 12)
        addr = (regs[rs1] + imm) & 0xFFFFFFFFFFFFFFFF
        addr10 = int(addr) & 0x3FF
        val = regs[rs2]
        for i in range(8):
            mem[addr10 + 7 - i] = val & 0xFF
            val >>= 8
        pc += 4

    elif opcode == 0b1100011:  # beq
        imm12 = (word >> 31) & 1
        imm11 = (word >> 7) & 1
        imm10_5 = (word >> 25) & 0x3F
        imm4_1 = (word >> 8) & 0xF
        imm = (imm12 << 12) | (imm11 << 11) | (imm10_5 << 5) | (imm4_1 << 1)
        offset = sign_extend(imm, 13)
        if regs[rs1] == regs[rs2]:
            pc += offset
        else:
            pc += 4

# Write expected output
with open("tests/expected_edge.txt", "w") as f:
    for i in range(32):
        f.write(f"{regs[i]:016x}\n")
    f.write(f"{cycle}\n")

print(f"Generated {len(machine_code)} instructions + termination")
print(f"Expected cycle count: {cycle}")
print("\nExpected non-zero registers:")
for i in range(32):
    if regs[i] != 0:
        print(f"  x{i} = 0x{regs[i]:016x} ({regs[i] if regs[i] < (1<<63) else regs[i]-(1<<64)})")
