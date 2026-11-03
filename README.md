# RISC-V 5-Stage Pipelined (RV32I)

## Project Overview
This repository contains the RTL design and verification environment for a custom **32-bit RISC-V 5-Stage Pipelined Processor (RV32I)**. Evolved from a baseline Single-Cycle architecture, this core divides instruction execution into five distinct stages (`IF` $\rightarrow$ `ID` $\rightarrow$ `EX` $\rightarrow$ `MEM` $\rightarrow$ `WB`) separated by four pipeline registers. 

This project was developed to demonstrate practical experience in advanced computer architecture. It successfully handles read-after-write (RAW) data hazards dynamically via data forwarding (bypassing), resolves load-use hazards via pipeline stalling, optimizes control flow resolution in the Execute stage, and utilizes Cadence EDA tools for hardware verification.

## Key Features
- **RV32I Base Integer Instruction Set**: Supports R-Type, I-Type, Load/Store, Branch, and Jump instructions.
- **5-Stage Pipeline Execution**: Instruction Fetch (IF), Instruction Decode (ID), Execute (EX), Memory Access (MEM), and Write Back (WB). 
- **4 Inter-Stage Pipeline Registers**: Explicit synchronization registers (`IF/ID`, `ID/EX`, `EX/MEM`, `MEM/WB`) to isolate stage logic and prevent instruction data from being overwritten. *(Note: The WB stage is the final step and writes directly to architectural state, thus requiring no trailing register).*
- **Data Forwarding Unit**: Solves data hazards by bypassing stale Register File values with the most recent results from the `EX/MEM` or `MEM/WB` stages to the ALU, Branch Comparator, and Store Data path. The `EX/MEM` forwarding source is `ForwardData_M`, while the `MEM/WB` forwarding source is `DataD_W`.Comparator, and store-data path.
- **Hazard Detection & Stalling**: Intelligently monitors for Load-Use dependencies, stalling the PC and IF/ID stages while injecting a transparent bubble into the ID/EX stage—ensuring correctness without relying on software compiler-inserted `NOP`s.
- **Early Branch Resolution**: Branch and jump targets are calculated and resolved in the Execute (EX) stage, properly flushing younger, wrong-path instructions fetched into the IF and ID stages.

## Hardware Architecture

The system is partitioned into the 5-stage RISC-V datapath blocks and control units. Below is the block diagram of the pipelined processor core.

```mermaid
flowchart TB

    %% Define Styles
    classDef mem fill:#f9f2f4,stroke:#d9534f,stroke-width:2px;
    classDef core fill:#e8f4f8,stroke:#31708f,stroke-width:2px;
    classDef ctrl fill:#fff3cd,stroke:#856404,stroke-width:2px;
    classDef tb fill:#dff0d8,stroke:#3c763d,stroke-width:2px;
    classDef pipe_reg fill:#e1d5e7,stroke:#9673a6,stroke-width:2px;

    %% Testbench
    TB[tb_RISCV_Pipeline.v]:::tb

    %% Stage 1: Instruction Fetch
    subgraph Stage_IF [1. IF: Instruction Fetch]
        direction LR
        PC[Program_Counter]:::core
        IMEM[(Instruction Memory)]:::mem
        PCPLUS[PC + 4]:::core
        PCMUX{PC Select Mux}:::core

        PC -->|PC_F| IMEM
        PC -->|PC_F| PCPLUS
        PCPLUS -->|Sequential PC| PCMUX
        PCMUX -->|PC_in_F| PC
    end

    %% IF/ID Pipeline Register
    IFID([IF/ID Register]):::pipe_reg

    %% Stage 2: Instruction Decode
    subgraph Stage_ID [2. ID: Instruction Decode]
        direction LR
        CU[Control Unit & Decoders]:::ctrl
        REG[(Register File)]:::core
        WBID[WB-to-ID Bypass]:::ctrl
        IMM[Imm_Gen]:::core
        HAZ[Hazard Detect]:::ctrl
    end

    %% ID/EX Pipeline Register
    IDEX([ID/EX Register]):::pipe_reg

    %% Stage 3: Execute
    subgraph Stage_EX [3. EX: Execute]
        direction LR
        FWD[Forwarding Control Unit]:::ctrl
        FWDA{Forwarding Mux A}:::core
        FWDB{Forwarding Mux B}:::core
        MUXA{ALU Operand A Mux}:::core
        MUXB{ALU Operand B Mux}:::core
        ALU((ALU)):::core
        BCMP[Branch_Comp]:::core
        BRES[Branch_Resolve]:::ctrl
        JALRMUX{JALR Target Mask}:::core
    end

    %% EX/MEM Pipeline Register
    EXMEM([EX/MEM Register]):::pipe_reg

    %% Stage 4: Memory Access
    subgraph Stage_MEM [4. MEM: Memory Access]
        direction LR
        DMEM[(Data Memory)]:::mem
    end

    %% MEM/WB Pipeline Register
    MEMWB([MEM/WB Register]):::pipe_reg

    %% Stage 5: Write Back
    subgraph Stage_WB [5. WB: Write Back]
        direction LR
        WBMUX{WB Mux}:::core
    end

    %% Main Vertical Pipeline Flow
    TB -->|clk, rst_n| PC
    TB -.->|Initialize .hex| IMEM
    TB -.->|Initialize .hex| DMEM

    IMEM -->|Instr_F| IFID
    PCPLUS -->|PC_Plus4_F| IFID

    IFID -->|Instr_D| CU
    IFID -->|rs1, rs2| REG
    IFID -->|Instr_D| IMM
    IFID -->|Instruction fields| HAZ

    REG -->|Register read data| WBID
    WBMUX -->|DataD_W, RegWEn_W| WBID
    WBID -->|DataA_D, DataB_D| IDEX
    CU -->|Control signals| IDEX
    IMM -->|Imm_D| IDEX

    IDEX -->|DataA_E, DataB_E| FWDA
    IDEX -->|DataA_E, DataB_E| FWDB

    %% Forwarding Sources
    EXMEM -.->|ForwardData_M| FWDA
    EXMEM -.->|ForwardData_M| FWDB
    MEMWB -.->|DataD_W| FWDA
    MEMWB -.->|DataD_W| FWDB

    FWD -.->|Forward select signals| FWDA
    FWD -.->|Forward select signals| FWDB

    %% Execute Datapath
    FWDA -->|fwd_DataA_E| MUXA
    FWDB -->|fwd_DataB_E| MUXB

    IDEX -->|PC_E, ASel_E| MUXA
    IDEX -->|Imm_E, BSel_E| MUXB

    MUXA -->|ALU operand A| ALU
    MUXB -->|ALU operand B| ALU

    FWDA -->|Forwarded operand A| BCMP
    FWDB -->|Forwarded operand B| BCMP

    IDEX -->|Branch and Jump control, funct3_E| BRES
    BCMP -->|BrEq_E, BrLT_E| BRES

    %% Branch and Jump Target
    ALU -->|Target / ALU_out_E| JALRMUX
    IDEX -->|Is_JALR_E| JALRMUX
    JALRMUX -->|Target address| PCMUX
    BRES -->|PCSel_E| PCMUX

    %% EX/MEM Register Inputs
    ALU -->|ALU_out_E| EXMEM
    FWDB -->|fwd_DataB_E: Store Data| EXMEM
    IDEX -->|PC_Plus4_E, funct3_E, control| EXMEM

    %% Memory Access
    EXMEM -->|ALU_out_M: Address| DMEM
    EXMEM -->|DataB_M: Store Data| DMEM
    EXMEM -->|funct3_M, MemRW_M| DMEM

    DMEM -->|DataR_M| MEMWB
    EXMEM -->|ALU_out_M, PC_Plus4_M| MEMWB
    EXMEM -->|Write-back control| MEMWB

    %% Write Back
    MEMWB -->|DataR_W, ALU_out_W, PC_Plus4_W| WBMUX
    WBMUX -->|DataD_W, RegWEn_W| REG

    %% Hazard and Flush Control
    HAZ -.->|Load-use stall: Hold PC| PC
    HAZ -.->|Load-use stall: Hold IF/ID| IFID
    HAZ -.->|Load-use bubble| IDEX

    BRES -.->|Flush younger instruction| IFID
    BRES -.->|Redirect bubble control| IDEX

    %% Store Data Forwarding
    FWDB -.->|Forwarded Store Data| EXMEM
```

### Module Descriptions by Pipeline Stage:

1. **Stage 1: IF (Instruction Fetch)**
   - **`Program_Counter.v`**: Synchronous register holding the instruction address. Stalls during load-use hazards and redirects upon taken branches/jumps.
   - **`IMEM.v`**: Instruction Memory model.
   - **`IF_ID_reg.v`**: Pipeline register holding the fetched instruction and PC for the ID stage.

2. **Stage 2: ID (Instruction Decode)**
   - **`control_unit.v` (with `main_decoder` & `ALU_decoder`)**: Decodes the instruction to generate all datapath routing and memory signals.
   - **`RegisterFile.v`**: 32x32-bit memory array. Features an explicit **WB-to-ID write-through bypass** to resolve hazards when reading and writing the same register in the same clock cycle.
   - **`Imm_Gen.v`**: Generates sign-extended immediate values.
   - **`hazard_detect.v`**: Monitors dependencies between a Load in EX and operands in ID. Triggers a 1-cycle PC/IF_ID stall and an ID/EX bubble when a true load-use hazard is detected.
   - **`ID_EX_reg.v`**: Pipeline register passing data, immediates, and control signals to EX.

3. **Stage 3: EX (Execute)**
   - **`forward_unit.v`**: Dynamically detects data dependencies and selects the forwarding source for the EX-stage operands. It supports three data sources:
     - `DataA_E` / `DataB_E`: Original operand values from the ID/EX register.
     - `ForwardData_M`: Forwarding source from the EX/MEM stage, selecting `PC_Plus4_M` for JAL/JALR or `ALU_out_M` for other instructions.
     - `DataD_W`: Forwarding source from the MEM/WB stage, providing the final write-back value.

     The forwarded operands (`fwd_DataA_E` and `fwd_DataB_E`) are supplied to the ALU, Branch Comparator, and Store Data path. When both EX/MEM and MEM/WB contain a matching destination register, EX/MEM forwarding has priority because it contains the more recent result.
   - **`ALU.v`**: Performs arithmetic, logic, and address calculations.
   - **`Branch_Comp.v` & `Branch_Resolve.v`**: Evaluates condition flags and resolves branches/jumps. If taken, it issues a flush signal to younger instructions in the IF and ID stages.
   - **`EX_MEM_reg.v`**: Pipeline register carrying ALU results, store data, and control signals to MEM.

4. **Stage 4: MEM (Memory Access)**
   - **DMEM.v**: Data Memory model supporting load and store operations. The `funct3_M` signal is carried into the MEM stage to preserve the Single cycle memory access behavior.
   - **`MEM_WB_reg.v`**: The final pipeline register, holding memory read data and ALU results for the WB stage.

5. **Stage 5: WB (Write Back)**
   - **Write Back Logic**: A multiplexer selects between Data Memory output, ALU result, or PC+4 (for link instructions) to write back into the Register File. 

## Instruction Set Architecture (ISA) Support

| Type       | Instructions Supported | Description |
|------------|------------------------|-------------|
| **R-Type** | `add`, `sub`, `and`, `or`, `xor`, `sll`, `srl`, `sra`, `slt`, `sltu` | Register-to-register arithmetic and logic operations. |
| **I-Type** | `addi`, `slti`, `sltiu`, `xori`, `ori`,
`andi`, `slli`, `srli`, `srai`, `jalr` |
Register-immediate operations and indirect jump. |
| **S-Type** | `sb`, `sh`, `sw` | Store Byte, Halfword, and Word to Data Memory. |
| **B-Type** | `beq`, `bne`, `blt`, `bge`, `bltu`, `bgeu` | Conditional branches evaluating equality and magnitude. |
| **U-Type** | `lui`, `auipc` | Upper immediate instructions. |
| **J-Type** | `jal` | Jump and Link (unconditional jump with return address). |

## Verification Environment
The design is verified using a pure Verilog testbench (`tb_RISCV_Pipeline.v`). 
* **Self-Checking Assembly Program**: The core executes `test.S`, a custom assembly program rigorously designed to test data forwarding, load-use hazard stalls, branch flushing, and JALR mask behaviors without manually inserted NOPs.
* **Automated Checking**: The testbench continuously monitors the value of register `x7`. If all software tests pass, it writes `1` to `x7`; if it fails, it writes `-1` (`0xFFFFFFFF`). The testbench automatically halts, reports the status, and logs total execution cycles alongside stall cycles.

## Simulation & Synthesis (Cadence EDA Flow)

This project is built and verified using industry-standard Cadence EDA tools. A configured `Makefile` is provided to automate RTL simulation (Xcelium), logic synthesis (Genus).

### RTL Simulation (Cadence Xcelium)

**Compile RTL files:**
```bash
make compile
```

**Elaborate the testbench:**
```bash
make build
```

**Run RTL simulation:**
```bash
make run
```

**Run simulation and launch the waveform viewer (Cadence SimVision):**
```bash
make wave
```

### Logic Synthesis (Cadence Genus)

```bash
make syn
```

*Expected Simulation Output (from `make run`):*
```text
========================================
 [PASSED] ALL PIPELINE TESTS PASSED!
 - Data forwarding (ALU and Store)
 - Load-use hazard (Stall and Bubble)
 - JAL/JALR and Pipeline Flush
----------------------------------------
 REGRESSION REPORT:
 - Total Cycles: 19
 - Load-use Stall Cycles: 1
========================================
```