# 64-bit Single-Cycle RISC-V Processor — Full Explanation

## Overview

This is a **non-pipelined, single-cycle** RISC-V processor. Every instruction completes fully within one clock cycle (with the exception of Data Memory writes, which are committed at the clock edge). The processor supports 8 instructions: `add`, `sub`, `addi`, `and`, `or`, `ld`, `sd`, `beq`.

---

## Module Map

```
seq_tb.v
└── datapath.v
    ├── program_counter.v       PC register
    ├── instruction_memory.v    Reads instructions.txt
    ├── control_unit.v          Opcode → control signals
    ├── register_file.v         32 × 64-bit registers
    ├── immediate_gen.v         Sign-extend immediate
    ├── alu_control.v           ALUOp + funct → ALU opcode
    ├── alu.v                   64-bit arithmetic/logic
    └── data_memory.v           1024-byte byte-addressed store
```

---

## General Datapath Flow (Every Cycle)

```
PC → IMEM → [instruction_word]
               │
               ├─ [6:0]   opcode  → Control Unit → {branch, mem_read, mem_to_reg,
               │                                     alu_op, mem_write, alu_src, reg_write}
               ├─ [11:7]  rd
               ├─ [14:12] funct3  ─┐
               ├─ [19:15] rs1     → Register File → read_data1 ─→ ALU input1
               ├─ [24:20] rs2            │          read_data2 ─→ ALU input2 (or MUX → imm)
               ├─ [30]    funct7  ─┘                           └→ DMEM write_data (for sd)
               └─ [31:0]  full   → Imm Gen → imm_extended
                                                  │
                              ALUSrc=1 ────────── MUX → ALU input2
                              ALUSrc=0 → read_data2 ─┘

ALU Control: {alu_op, funct7[30], funct3} → alu_control_signal → ALU

ALU result → DMEM address (for ld/sd)
           → write-back data (for R/I-type)

DMEM read_data → write-back (for ld)

Write-back: MemtoReg=1 → mem_read_data
            MemtoReg=0 → alu_result     → Register File [rd]

PC update:
  branch & zero_flag=1 → PC + (imm << 1)    (beq taken)
  otherwise            → PC + 4
```

---

## Module-by-Module Detail

### `program_counter.v`
- **Inputs**: `clk`, `reset`, `pc_in [63:0]`
- **Output**: `pc_out [63:0]`
- On every `posedge clk`, loads `pc_in`. On `reset`, goes to 0.
- `pc_in` is chosen by the PC MUX in the datapath: either `PC+4` or the branch target.

---

### `instruction_memory.v`
- **Input**: `addr [63:0]`
- **Output**: `instruction_word [31:0]`
- At simulation start, reads `instructions.txt` into a byte array (one hex byte per line, Big-Endian).
- Output: `{mem[addr], mem[addr+1], mem[addr+2], mem[addr+3]}` — assembles 4 bytes into a 32-bit instruction, MSB first.

---

### `control_unit.v`
- **Input**: `opcode [6:0]` (instruction[6:0])
- **Outputs**: `branch`, `mem_read`, `mem_to_reg`, `alu_op[1:0]`, `mem_write`, `alu_src`, `reg_write`

| Instruction | opcode      | branch | mem_read | mem_to_reg | alu_op | mem_write | alu_src | reg_write |
|-------------|-------------|--------|----------|------------|--------|-----------|---------|-----------|
| add/sub/and/or | `0110011` | 0 | 0 | 0 | `10` | 0 | 0 | 1 |
| addi        | `0010011`   | 0      | 0        | 0          | `00`   | 0         | 1       | 1         |
| ld          | `0000011`   | 0      | 1        | 1          | `00`   | 0         | 1       | 1         |
| sd          | `0100011`   | 0      | 0        | 0          | `00`   | 1         | 1       | 0         |
| beq         | `1100011`   | 1      | 0        | 0          | `01`   | 0         | 0       | 0         |

---

### `register_file.v`
- **Inputs**: `clk`, `reset`, `read_reg1/2 [4:0]`, `write_reg [4:0]`, `write_data [63:0]`, `reg_write_en`
- **Outputs**: `read_data1/2 [63:0]`
- **Read**: Asynchronous (combinatorial) — changes as soon as `rs1`/`rs2` change.
- **Write**: Synchronous on `posedge clk`, gated by `reg_write_en`. `x0` is hardwired to 0 and never written.

---

### `immediate_gen.v`
- **Input**: `instruction_word [31:0]`
- **Output**: `imm_extended [63:0]`

| Type   | Instructions | Bits extracted |
|--------|-------------|----------------|
| I-type | `addi`, `ld` | `inst[31:20]`, sign-extended from bit 31 |
| S-type | `sd`        | `{inst[31:25], inst[11:7]}`, sign-extended |
| B-type | `beq`       | `{inst[31], inst[7], inst[30:25], inst[11:8]}`, sign-extended |

> **Key**: No shift is done here. For `beq`, the binary encoding drops the trailing LSB (always 0). A dedicated `<< 1` in the datapath restores it before the branch adder.

---

### `alu_control.v`
- **Inputs**: `alu_op [1:0]`, `funct7_bit30`, `funct3 [2:0]`
- **Output**: `alu_control_signal [3:0]`

| `alu_op` | Meaning | `alu_control_signal` |
|----------|---------|---------------------|
| `00`     | ld / sd / addi → always ADD | `0010` |
| `01`     | beq → always SUB (result=0 means equal) | `0110` |
| `10`, funct3=`000`, funct7[30]=0 | add | `0010` |
| `10`, funct3=`000`, funct7[30]=1 | sub | `0110` |
| `10`, funct3=`111` | and | `0000` |
| `10`, funct3=`110` | or  | `0001` |

---

### `alu.v`
- **Inputs**: `input1 [63:0]`, `input2 [63:0]`, `alu_control_signal [3:0]`
- **Outputs**: `alu_result [63:0]`, `zero_flag`

| Signal | Operation |
|--------|-----------|
| `0000` | AND |
| `0001` | OR |
| `0010` | ADD |
| `0110` | SUB |

`zero_flag = (alu_result == 0)` — used by `beq` to decide branching.

---

### `data_memory.v`
- **Inputs**: `clk`, `reset`, `address [63:0]`, `write_data [63:0]`, `mem_read`, `mem_write`
- **Output**: `read_data [63:0]`
- 1024 bytes, byte-addressed, **Big-Endian** (MSB at lowest address).
- `ld` reads 8 consecutive bytes starting at `address[9:0]`.
- `sd` stores 8 bytes starting at `address[9:0]`.
- **Write**: non-blocking on `posedge clk` (1-cycle write latency).
- **Read**: combinatorial — reflects the array immediately, so an `ld` issued one cycle after an `sd` sees the freshly stored value.

---

## Per-Instruction Walkthrough

### `add rd, rs1, rs2`
```
Control: alu_src=0, alu_op=10, reg_write=1, mem_write=0, mem_read=0
ALU ctrl: funct3=000, funct7[30]=0 → 0010 (ADD)
Flow: read_data1 + read_data2 → alu_result → registers[rd]
```

### `sub rd, rs1, rs2`
```
Control: alu_src=0, alu_op=10, reg_write=1
ALU ctrl: funct3=000, funct7[30]=1 → 0110 (SUB)
Flow: read_data1 - read_data2 → alu_result → registers[rd]
```

### `addi rd, rs1, imm`
```
Control: alu_src=1, alu_op=00, reg_write=1
Imm gen: sign-extend inst[31:20] → imm_extended
ALU ctrl: 00 → 0010 (ADD, always — avoids funct7 misinterpretation on negative immediates)
Flow: read_data1 + imm_extended → alu_result → registers[rd]
```

### `and rd, rs1, rs2`
```
Control: alu_src=0, alu_op=10, reg_write=1
ALU ctrl: funct3=111 → 0000 (AND)
Flow: read_data1 & read_data2 → alu_result → registers[rd]
```

### `or rd, rs1, rs2`
```
Control: alu_src=0, alu_op=10, reg_write=1
ALU ctrl: funct3=110 → 0001 (OR)
Flow: read_data1 | read_data2 → alu_result → registers[rd]
```

### `ld rd, imm(rs1)`
```
Control: alu_src=1, alu_op=00, mem_read=1, mem_to_reg=1, reg_write=1
Imm gen: sign-extend inst[31:20] → imm_extended
ALU ctrl: 00 → 0010 (ADD)
Flow: read_data1 + imm_extended → effective address
      data_memory[address] (8 bytes, combinatorial) → mem_read_data → registers[rd]
```
> Data memory must have been written by a prior `sd` (committed at a previous posedge) for `ld` to see the value.

### `sd rs2, imm(rs1)`
```
Control: alu_src=1, alu_op=00, mem_write=1, reg_write=0
Imm gen: sign-extend {inst[31:25], inst[11:7]} → imm_extended   (S-type)
ALU ctrl: 00 → 0010 (ADD)
Flow: read_data1 + imm_extended → effective address
      read_data2 → written to data_memory[address] on posedge clk
```
> The 8 bytes are stored Big-Endian: MSB of `rs2` goes to `mem[addr]`, LSB to `mem[addr+7]`.

### `beq rs1, rs2, offset`
```
Control: alu_src=0, alu_op=01, branch=1, reg_write=0
Imm gen: sign-extend B-type fields → imm_extended  (this is offset/2 in binary)
ALU ctrl: 01 → 0110 (SUB)
Flow: read_data1 - read_data2 → alu_result
      zero_flag = (alu_result == 0)

Branch target: PC + (imm_extended << 1)   ← SLL-1 restores the dropped trailing zero

PC next: (branch & zero_flag) ? branch_target : PC+4
```
> Example: `beq x4, x5, 8` — the binary encodes imm=4 (8 dropped the 0). Imm gen outputs 4, SLL-1 gives 8, branch target = PC+8. ✓

---

## Termination & Output

The testbench (`seq_tb.v`) samples `instruction_word` combinatorially before each clock edge. When it sees `32'h00000000` (all-zero instruction, i.e., past the end of the program), it:
1. Counts that cycle in `cycle_count`
2. Waits for the posedge to complete
3. Dumps `registers[0..31]` as 16-digit hex (one per line) to `register_file.txt`
4. Appends `cycle_count` as a decimal on the last line
5. Calls `$finish`

The grader runs `iverilog seq_tb.v && ./a.out` and checks `register_file.txt`.

---

## Endianness

Both Register File and Data Memory are **Big-Endian**:
- The most-significant byte is stored at the lowest address.
- `instructions.txt` is also Big-Endian: the first of the 4 bytes in a file is the MSB of the instruction word.
- Register values are printed MSB-first in `register_file.txt` (standard `%016h` formatting).
