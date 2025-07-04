-- hope this is somewhat accurate

local little_assembly = {}

--[[
LMC REF:
	HLT	 	Stop (Little Man has a rest).	
 	 1	 	ADD	 	Add the contents of the memory address to the Accumulator	
 	 2	 	SUB	 	Subtract the contents of the memory address from the Accumulator	
 	 3	 	STA or STO	 	Store the value in the Accumulator in the memory address given.	
 	 4	 	 	 	This code is unused and gives an error.	
 	 5	 	LDA	 	Load the Accumulator with the contents of the memory address given	
 	 6	 	BRA	 	Branch - use the address given as the address of the next instruction	
 	 7	 	BRZ	 	Branch to the address given if the Accumulator is zero	
 	 8	 	BRP	 	Branch to the address given if the Accumulator is zero or positive	
 	 9	 	INP or OUT	 	Input or Output. Take from Input if address is 1, copy to Output if address is 2.	
 	 9	 	OTC	 	Output accumulator as a character if address is 22. (Non-standard instruction)	
 	 	 	DAT	 	Used to indicate a location that contains data.	
]]

local instruction_set = {
    HLT = {
        opcode = 0,
        requires_operand = false,
        command_handler = function(machine)
            -- set halt to true
            machine.halt = true
        end
    },
    ADD = {
        opcode = 1,
        requires_operand = true,
        command_handler = function(machine, address)
            machine.accumulator = machine.addresses[address] + machine.accumulator
        end
    },
    SUB = {
        opcode = 2,
        requires_operand = true,
        command_handler = function(machine, address)
            machine.accumulator = machine.accumulator - machine.addresses[address]
        end
    },
    STA = {
        opcode = 3,
        requires_operand = true,
        command_handler = function(machine, address)
            machine.addresses[address] = machine.accumulator
        end
    },
    LDA = {
        opcode = 4,
        requires_operand = true,
        command_handler = function(machine, address)
            machine.accumulator = machine.addresses[address]
        end
    },
    BRA = {
        opcode = 5,
        requires_operand = true,
        command_handler = function(machine, address)
            machine.program_counter = address - 1
        end
    },
    BRZ = {
        opcode = 6,
        requires_operand = true,
        command_handler = function(machine, address)
            if machine.accumulator == 0 then
                machine.program_counter = address - 1
            end
        end
    },
    BRP = {
        opcode = 7,
        requires_operand = true,
        command_handler = function(machine, address)
            if machine.accumulator >= 0 then
                machine.program_counter = address - 1
            end
        end
    },
    INP = {
        opcode = 8,
        requires_operand = false,
        command_handler = function(machine)
            -- i dont think this is standard of the LMC but icba its only minor
            print("INPUT:")
            local input = io.read()

            if not tonumber(input) then
                error("input must be number")
            end

            if tonumber(input) > 999 then
                error("input must be <= 999")
            end

            machine.input = tonumber(input)
            machine.accumulator = machine.input
        end
    },
    OUT = {
        opcode = 9,
        requires_operand = false,
        command_handler = function(machine)
            -- i dont think this is standard of the LMC but icba its only minor
            table.insert(machine.output, machine.accumulator)
            print("OUTPUT: " .. machine.accumulator)
        end
    },
}

local function get_command_from_input(input)
    input = string.upper(input)
    return instruction_set[input]
end

local function split_string(input, separator)
    if separator == nil then
        separator = '%s'
    end

    local separated_string_table = {}

    for str in string.gmatch(input, '([^' .. separator .. ']+)') do
        table.insert(separated_string_table, str)
        --print(str)
    end

    return separated_string_table
end

local function construct_address_value_for_op(opcode, address)
    -- opcode goes x00 and + address will make xYY where YY is address
    return opcode * 100 + address
end

little_assembly._instruction_set = instruction_set

-- parse and assemble
little_assembly.assemble = function(machine, assembly)
    -- assembly is a string (and we should separate everything based off)

    -- first separate by a space
    local separated_assembly = split_string(assembly, "\r\n ")
    local labels = {}


    -- first pass for collecting all labels
    local function first_pass()
        --[[
            a label is basically another way of representing a memory address
            so '<label> instruction' basically says, right, where instruction is, this is technically our memory address.
            and therefore, if we do
            '<label> DAT 2', that basically says where this instruction is (DAT), this is what memory address we're linking to.
            but for DAT, it just evaluates to 2.

            when we reference a label for an operand, it'll probably look something like
            'ADD <label>' or '<instruction> <label>'.
            we want to replace these labels with the actual memory address of the location of the prior labels
        ]]

        local index = 1
        local memory_address = 1

        while index <= #separated_assembly do
            local token = separated_assembly[index]

            -- we want to check if it's a command first
            local command = get_command_from_input(token)

            if command then
                -- where we specifically deal with label REFERENCES
                if command.requires_operand == true then
                    local potential_operand = separated_assembly[index + 1]

                    if potential_operand then
                        -- advance forward by an extra 1 (on top of 1 later on, so 2 in total)
                        index = index + 1
                    end
                end
            else
                -- where we specifically deal with label DECLARATIONS

                -- if the item in front of it is an instruction, it's a label pointing to said instruction
                local potential_command = get_command_from_input(separated_assembly[index + 1])

                if potential_command then
                    -- we basically delete the label here since it's a declaration but it's to point to an instruction
                    labels[token] = memory_address
                    memory_address = memory_address - 1
                else
                    -- this is 100% a DAT declaration
                    if string.upper(separated_assembly[index + 1]) == "DAT" then
                        -- we also want to check if it's explicitly declaring any value at all, and if not we just default to 0
                        local potential_value = separated_assembly[index + 2]

                        if potential_value then
                            -- make sure it's an integer/number
                            if tonumber(potential_value) then
                                labels[token] = memory_address
                                machine.addresses[memory_address] = potential_value

                                index = index + 2
                            else
                                labels[token] = memory_address
                                machine.addresses[memory_address] = 0
                                index = index + 1
                            end
                        else
                            labels[token] = memory_address
                            -- it's already zeroed out anyways..
                            index = index + 1
                        end
                    end
                end
            end

            index = index + 1
            memory_address = memory_address + 1
        end
    end

    -- second pass for assembling the code into the memory addresses
    local function second_pass()
        --[[
            in this pass, we are actually now properly assembling the code and replacing labels when we get to them
        ]]

        local index = 1
        local memory_address = 1

        while index <= #separated_assembly do
            local token = separated_assembly[index]

            -- we want to check if it's a command first
            local command = get_command_from_input(token)

            if command then
                -- if it has a operand, we should check if that operand is just a raw memory address, or a label (a string)
                if command.requires_operand == true then
                    local potential_operand = separated_assembly[index + 1]

                    if potential_operand then
                        if tonumber(potential_operand) then
                            -- we wanna put this in the memory address
                            machine.addresses[memory_address] = construct_address_value_for_op(command.opcode,
                                potential_operand)
                        else
                            -- definitely a label
                            if labels[potential_operand] then
                                -- we wanna put this in the memory address ofc
                                machine.addresses[memory_address] = construct_address_value_for_op(command.opcode,
                                    labels[potential_operand])
                            else
                                error("unidentifiable operand for instruction " ..
                                    token .. "" .. ". got: " .. potential_operand)
                            end
                        end
                        -- also account for the fact we're gonna be consuming the operand
                        index = index + 1
                    end
                else
                    -- and now commands that don't require operands which should be easy
                    machine.addresses[memory_address] = construct_address_value_for_op(command.opcode,
                        00)
                end
            else
                -- this is probably a label or a DAT instruction

                local potential_command = get_command_from_input(separated_assembly[index + 1])

                if potential_command then
                    -- this is simply because we're not bothering recording this label by any means (we've already registered it's existance)
                    memory_address = memory_address - 1
                else
                    -- this is 100% a DAT declaration
                    if string.upper(separated_assembly[index + 1]) == "DAT" then
                        -- we just want to find out how much we should offset index by
                        local potential_value = separated_assembly[index + 2]

                        if potential_value then
                            -- make sure it's an integer/number
                            if tonumber(potential_value) then
                                index = index + 2
                            else
                                index = index + 1
                            end
                        else
                            index = index + 1
                        end

                        -- account for the fact that this will already be registered in memory.
                        -- label for instruction isn't registered in memory, so we shouldn't consider it here
                        -- DAT label is registered in memory (the value of the dat label) already, but again we don't need to consider the label
                        memory_address = memory_address - 1
                    end
                end
            end

            index = index + 1
            memory_address = memory_address + 1
        end
    end

    first_pass()
    second_pass()
end

little_assembly.run_program = function(machine)
    -- we start interpreting at addresses[1]

    while not machine.halt do
        -- we then want to interpret the value given which is in format:
        -- oxx, o = opcode, xx = address

        machine.address_register = machine.program_counter

        -- fetch

        local value = tostring(machine.addresses[machine.address_register])

        -- value may not fulfil oxx pattern, but will always have o at end, so we double check

        if string.len(value) == 1 then
            -- missing xx
            value = value .. "00"
        elseif string.len(value) == 2 then
            -- missing x
            value = value .. "0"
        end

        if not value then
            error("no instruction at address " .. machine.address_register)
        end

        -- decode
        machine.current_instruction_register = machine.addresses[machine.address_register] -- raw

        local opcode = tonumber(string.sub(value, 1, 1)) % 100
        local address = tonumber(string.sub(value, 2, string.len(value))) % 100

        for _, value in pairs(instruction_set) do
            if value.opcode == opcode then
                -- execute
                if value.requires_operand then
                    value.command_handler(machine, address)
                    break
                else
                    value.command_handler(machine)
                    break
                end
            end
        end

        machine.program_counter = machine.program_counter + 1
    end
end

little_assembly._display_memory_addresses = function(machine)
    print("MEMORY ADDRESSES:\n")
    for index, value in ipairs(machine.addresses) do
        print(index, " - ", value)
    end
    print("\n")
end


little_assembly.create_machine = function(address_amount)
    -- also hardcoded default of 999 as max number
    -- max address count 99!
    local addresses = {}
    local accumulator = 0
    local input = 0
    local current_instruction_register = 0
    local program_counter = 1
    local address_register = 0
    local output = {}
    local halt = false

    if address_amount > 99 then
        address_amount = 99
    end

    for i = 1, address_amount, 1 do
        addresses[i] = 000
    end

    return {
        addresses = addresses,
        accumulator = accumulator,
        current_instruction_register = current_instruction_register,
        program_counter = program_counter,
        address_register = address_register,
        input = input,
        output = output,
        halt = halt,
    }
end

return little_assembly
