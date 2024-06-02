local server_fd = socket:tcp()
local ip_address = "127.0.0.1"
local port = 2000
local MSG_LENGTH = 3
local socket_initialized = 0

-- Define the addresses and their names
local addresses = {
    {name = "ADDR_0200F832", address = 0x0200F832},
    {name = "ADDR_0200F904", address = 0x0200F904},
    {name = "ADDR_0200F900", address = 0x0200F900},
    {name = "ADDR_0200F902", address = 0x0200F902},
    {name = "SIOMULTI0", address = 0x4000120},
    {name = "SIOMULTI1", address = 0x4000122},
    {name = "SIOMULTI2", address = 0x4000124},
    {name = "SIOMULTI3", address = 0x4000126},
    {name = "SIODATA8", address = 0x400012A},
    {name = "SIOCNT", address = 0x4000128},
    {name = "RCNT", address = 0x4000134}
}

-- Initialize previous values to nil
local previous_values = {}
local frame_number = 0
local lock_value = 0x0000
local last_received_frame = 0
local ignore_data_until_frame = 0
local start_frame = 0
local current_step = 1
local frames_since_last_data = 0
local no_data_reset_logged = false

-- Function to establish server connection
local function establish_server_connection()
    server_fd:bind(ip_address, port)
    server_fd:listen()
    socket_initialized = 1
    console:log("[+] Listening on: " .. ip_address .. ":" .. port)
end

-- Function to handle incoming data
local function handle_incoming_data()
    local client_fd = server_fd:accept()
    if client_fd then
        local data, err = client_fd:receive(MSG_LENGTH)
        if data then
            local byte1, byte2, byte3 = string.byte(data, 1, 3)
            if byte1 == 0x80 then
                local chip_id_high = byte2
                local chip_id_low = byte3
                lock_value = (chip_id_high << 8) | chip_id_low
                last_received_frame = frame_number
                ignore_data_until_frame = frame_number + 12
                start_frame = frame_number
                current_step = 1
                frames_since_last_data = 0
                no_data_reset_logged = false
                console:log(string.format("Received chip ID: 0x%04X", lock_value))
            end
        end
        client_fd:close()
    end
end

-- Function to write and lock specific addresses based on the frame number
local function write_and_lock_addresses()
    if frame_number == start_frame + 1 then
        emu:write16(0x0200F832, lock_value)
    elseif frame_number == start_frame + 2 then
        emu:write16(0x0200F904, lock_value)
    elseif frame_number == start_frame + 10 then
        emu:write16(0x0200F900, lock_value)
    elseif frame_number == start_frame + 11 then
        emu:write16(0x0200F902, lock_value)
    end

    -- Lock the values at these specific addresses until the 15th frame after starting
    if frame_number >= start_frame + 1 then
        emu:write16(0x0200F832, lock_value)
    end
    if frame_number >= start_frame + 2 then
        emu:write16(0x0200F904, lock_value)
    end
    if frame_number >= start_frame + 10 then
        emu:write16(0x0200F900, lock_value)
    end
    if frame_number >= start_frame + 11 then
        emu:write16(0x0200F902, lock_value)
    end
end

-- Function to log transfers
local function log_transfers()
    frame_number = frame_number + 1
    local changes = false
    local table_rows = {}

    -- Write and lock specific addresses based on the frame number
    write_and_lock_addresses()

    -- Iterate through each address and check for changes
    for _, entry in ipairs(addresses) do
        local current_value = emu:read16(entry.address)
        local previous_value = previous_values[entry.address]
        
        -- Check if the value has changed
        if current_value ~= previous_value then
            changes = true
            previous_values[entry.address] = current_value
        end
        
        -- Prepare the table row
        local change_marker = current_value ~= previous_value and "*" or " "
        local table_row = string.format(
            "| %-13s%s | 0x%08X | 0x%04X  | 0x%04X  |",
            entry.name, change_marker, entry.address, current_value, previous_value or 0
        )
        table.insert(table_rows, table_row)
    end
    
    -- If any value has changed, print the table
    if changes then
        -- Print the frame number
        console:log("+--------------+------------+")
        console:log(string.format("| Frame        | %10d |", frame_number))
        console:log("+--------------+------------+---------+----------+")
        console:log("| Name         | Address    | Current | Previous |")
        console:log("+--------------+------------+---------+----------+")
        
        -- Print the table rows
        for _, row in ipairs(table_rows) do
            console:log(row)
        end
        
        -- Print the table footer
        console:log("+--------------+------------+---------+----------+")
    end
end

-- Function to update the state based on frame number
local function update_state()
    if frame_number >= start_frame + 15 then
        if frames_since_last_data >= 5 and not no_data_reset_logged then
            lock_value = 0x0000
            console:log("No data received for 5 frames, resetting lock value.")
            no_data_reset_logged = true
        end
        frames_since_last_data = frames_since_last_data + 1
    else
        frames_since_last_data = 0
    end
end

-- Main function to be called before each frame
local function main()
    if socket_initialized == 0 then
        establish_server_connection()
    end

    handle_incoming_data()

    if frame_number > ignore_data_until_frame then
        update_state()
    end

    log_transfers()
end

-- Register the function to be called before each frame
callbacks:add("frame", main)
