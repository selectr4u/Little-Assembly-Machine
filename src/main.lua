local little_assembly = require("src.littleassembly")

local function main()
    local address_amount = 99
    local program = ""

    print("what address amount should the machine have (max 99)")
    address_amount = io.read()

    local machine = little_assembly.create_machine(tonumber(address_amount))

    print("please provide your assembly code")
    print("note: for a file, follow format: !FILE <file location> , e.g !FILE myassembly.txt")

    local input = io.read()

    if string.sub(input, 1, 5) == "!FILE" then
        -- we load dedicated file, which is gonna be 7 -> end
        local file_path = string.sub(input, 7, string.len(input))

        local file = io.open(file_path, "r")
        program = file:read("a")
    else
        -- just load in input as program
        program = input
    end

    print("-- PROGRAM START --\n")

    xpcall(function(...)
        little_assembly.assemble(machine, program)
        little_assembly.run_program(machine)
    end, function(res)
        print("encountered an error: " .. res)
    end)

    print("\n-- PROGRAM END --")
end

main()
