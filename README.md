# Little Assembly Machine (LAM)

Based off of [Little Man's Computer](https://peterhigginson.co.uk/lmc/)

wrote this out of pure interest of how an assembler might work, obviously it doesn't work *exactly* like this, but it helped me further understand the fetch-decode-execute cycle for a level computer science

## Running the machine

To run the Little Assembly Machine, preferrably have a lua version of around `> 5.4`, although probably works on prior versions, and simply run the src/main.lua file, where you will be prompted appropriately

It'll expect either a string of the assembly program, or a file location to the assembly program (which can be specified in the following format `!FILE <file location>`, e.g `!FILE myassembly.txt`)


## Instruction Set

| Command | Opcode | Operand? | Description |
| ------- | ------ | -------- | ----------- |
| `HLT`   | 0      | No       | Halts the program. |
| `ADD`   | 1      | Yes      | Adds the value at the given address to the accumulator. |
| `SUB`   | 2      | Yes      | Subtracts the value at the given address from the accumulator. |
| `STA`   | 3      | Yes      | Stores the value in the accumulator at the given address. |
| `LDA`   | 4      | Yes      | Loads the value at the given address into the accumulator. |
| `BRA`   | 5      | Yes      | Branches to the given address. |
| `BRZ`   | 6      | Yes      | Branches to the given address if the accumulator is zero. |
| `BRP`   | 7      | Yes      | Branches to the given address if the accumulator is zero or positive. |
| `INP`   | 8      | No       | Takes input and stores it in the accumulator. |
| `OUT`   | 9      | No       | Outputs the value in the accumulator. |
