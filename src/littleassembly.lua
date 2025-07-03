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
            -- add whatever is in address to accumulator
            machine.accumulator = machine.addresses[address] + machine.accumulator
        end
    },
    SUB = {
        opcode = 2,
        requires_operand = true,
        command_handler = function(machine, address)
            -- sub whatever is
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
            machine.program_counter = address
        end
    },
    BRZ = {
        opcode = 6,
        requires_operand = true,
        command_handler = function(machine, address)
            if machine.accumulator == 0 then
                machine.program_counter = address
            end
        end
    },
    BRP = {
        opcode = 7,
        requires_operand = true,
        command_handler = function(machine, address)
            if machine.accumulator >= 0 then
                machine.program_counter = address
            end
        end
    },
    INP = {
        opcode = 8,
        requires_operand = false,
        command_handler = function(machine)
            -- i dont think this is standard of the LMC but icba its only minor
            print("input required:")
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
            print("OUTPUT" .. machine.accumulator)
        end
    },
}

local function get_command_from_input(input)
    return instruction_set[input]
end

local function split_string(input, separator)
    if separator == nil then
        separator = '%s'
    end

    local separated_string_table = {}

    for str in string.gmatch(input, '([^' .. separator .. ']+)') do
        table.insert(separated_string_table, str)
    end

    return separated_string_table
end

local function construct_address_value_for_op(opcode, address)
    return tonumber(tostring(opcode) .. tostring(address))
end

little_assembly._instruction_set = instruction_set

-- parse and interpret
little_assembly.assemble = function(machine, assembly)
    -- assembly is a string (and we should separate everything based off)

    -- first separate by a space
    local separated_assembly = split_string(assembly, "\r\n ")
    local labels = {}


    -- first pass for collecting all DAT labels
    local function first_pass()
        -- variables for the loop
        local current_address = 1
        local index = 1

        -- go through each string and check if it's a DAT
        while index <= #separated_assembly do
            local word = separated_assembly[index]

            local command = get_command_from_input(word)

            if command == nil then
                -- this could potentially be a label, so check for colon ":"
                local label_name = word
                if string.sub(word, #word, #word) == ':' then
                    label_name = word:sub(1, -2) -- remove the trailing ':'
                end

                -- let's check the i + 1 word is DAT, if so then this is a data label as expected,
                if separated_assembly[index + 1] == "DAT" then
                    if separated_assembly[index + 2] then
                        if tonumber(separated_assembly[index + 2]) then
                            labels[label_name] = current_address
                            machine.addresses[current_address] = tonumber(separated_assembly[index + 2])
                        else
                            error("invalid value given for DAT")
                        end
                    else
                        labels[label_name] = current_address
                        machine.addresses[current_address] = 0
                    end

                    index = index + 2
                    current_address = current_address + 1
                else
                    -- it's probably just a regular label, so we can force check by seeing if any instruction exists after it
                    if separated_assembly[index + 1] then
                        if get_command_from_input(separated_assembly[index + 1]) then
                            labels[label_name] = current_address
                        else
                            error("no instruction provided for label " .. label_name)
                        end
                    else
                        error("no instruction provided for label " .. label_name)
                    end
                end
            else
                -- command let's not do anything since it's first pass
            end

            index = index + 1
            -- moved current address increment inside of the other lines so dw still here

            assert(current_address <= #machine.addresses, "program too large for allocated memory")
        end
    end

    -- second pass for assembling the code into the memory addresses
    local function second_pass()
        -- variables for the loop
        local current_address = 1
        local index = 1

        -- go through each string and check it's command + parse + load into memory
        while index <= #separated_assembly do
            local word = separated_assembly[index]

            local command = get_command_from_input(word)

            if command == nil then
                -- this could potentially be a label, but since the label is registered we just ditch it and offset current address by -1
                current_address = current_address - 1
            else
                -- confirmed this is a command!
                -- check if it requires address
                if command.requires_operand then
                    -- we should grab the second word after this
                    if separated_assembly[index + 1] then
                        local memory_address = tonumber(separated_assembly[index + 1])
                        if not memory_address or memory_address == nil then
                            -- this could be potentially a label..?
                            if labels[separated_assembly[index + 1]] then
                                machine.addresses[current_address] =
                                    construct_address_value_for_op(command.opcode, labels[separated_assembly[index + 1]])
                            else
                                error("not a valid memory address")
                            end
                        else
                            if memory_address > #machine.addresses then
                                error("not a valid memory address (> max amount)")
                            end

                            machine.addresses[current_address] = construct_address_value_for_op(command.opcode,
                                memory_address)
                        end
                    else
                        error("no memory address provided for " .. command)
                    end
                else
                    machine.addresses[current_address] = construct_address_value_for_op(command.opcode, 00)
                end
            end

            index = index + 1
            current_address = current_address + 1
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
