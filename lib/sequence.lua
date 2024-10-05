local MusicUtil = require "musicutil"

local Sequence = {}

function Sequence:new(args)
    local m = setmetatable({}, {__index = Sequence})
    local args = args == nil and {} or args
    for k, v in pairs(args) do m[k] = v end
    m:init()
    return m
end

function Sequence:init()
    self.sequence_max = 16 * 4 -- 16 steps, 4 measures
    self.note_max = 7 * 6 -- 4 octaves
    self.scale_full = MusicUtil.generate_scale_of_length(24, 1, self.note_max)
    local matrix = {}
    for i = 1, self.sequence_max do
        matrix[i] = {}
        for j = 1, self.note_max do matrix[i][j] = 0 end
    end
    -- -- add random notes to the matrix
    -- for i = 1, self.sequence_max do
    --     for j = 1, self.note_max do
    --         if math.random() > 0.9 then
    --             matrix[i][j] = 1
    --         end
    --     end
    -- end
    self.matrix = matrix
    self.notes_to_ghost = {}
    self.step = 1
    self.step_last = 1
    self.step_next = 1
    self.movement = 1
    self.note_limit = self.note_max
    self.note_offset = 14
    self.notes_on = {}
    self.step_time_last = clock.get_beats()
    self.step_time_before_last = self.step_time_last
    self.note_to_play = {}
    self.midi_devices = {}
    self.midi_device = midi.connect(1)
    for i = 1, #midi.vports do
        local long_name = midi.vports[i].name
        local short_name = string.len(long_name) > 15 and
                               util.acronym(long_name) or long_name
        table.insert(self.midi_devices, i .. ": " .. short_name)
    end

    -- find all the folders in the mx.samples folder
    local instrument_folders = {}
    local instrument_options = {"toy piano"}
    local files = util.scandir(_path.audio .. "mx.samples")
    for i, folder in ipairs(files) do
        -- remove trailing /
        folder = string.sub(folder, 1, -2)
        table.insert(instrument_folders, folder)
        -- replace underscores with spaces
        local name = string.gsub(folder, "_", " ")
        table.insert(instrument_options, name)
    end
    tab.print(instrument_folders)

    -- setup parameters
    local params_menu = {
        {
            id = "instrument",
            name = "instrument",
            min = 1,
            max = #instrument_options,
            exp = false,
            div = 1,
            default = 1,
            formatter = function(param)
                return instrument_options[param:get()]
            end,
            action = function(v)
                if v == 1 then
                    self.instrument = _path.code .. "eighteen/data"
                else
                    self.instrument = _path.audio .. "mx.samples/" ..
                                          instrument_folders[v - 1]
                end
            end
        }, {
            id = "direction",
            name = "direction",
            min = 1,
            max = 4,
            exp = false,
            div = 1,
            default = 1,
            formatter = function(param)
                local directions = {
                    "forward", "backward", "ping pong", "random"
                }
                return directions[param:get()]
            end
        }, {
            id = "limit",
            name = "limit",
            min = 2,
            max = self.sequence_max,
            exp = false,
            div = 1,
            default = 16,
            formatter = function(param)
                return math.floor(param:get()) .. " steps"
            end
        }, -- midi parameters
        {
            id = "output",
            name = "output",
            min = 1,
            max = 5,
            exp = false,
            div = 1,
            default = 1,
            formatter = function(param)
                local outputs = {
                    "none", "midi", "crow out 1+2", "crow ii JF", "crow ii 301"
                }
                return outputs[param:get()]
            end,
            action = function(value)
                if value == 3 then
                    crow.output[2].action = "{to(5,0),to(0,0.25)}"
                elseif value == 4 or value == 5 then
                    crow.ii.pullup(true)
                    crow.ii.jf.mode(1)
                end
            end
        }, {
            id = "midi_out_device",
            name = "midi out device",
            min = 1,
            max = #self.midi_devices,
            exp = false,
            div = 1,
            default = 1,
            formatter = function(param)
                return self.midi_devices[param:get()]
            end,
            action = function(value)
                local device = midi.connect(value)
                if device then
                    print("midi device connected: " .. device.name)
                    self.midi_out_device = midi.connect(value)
                end
            end
        }, {
            id = "midi_out_channel",
            name = "midi out channel",
            min = 1,
            max = 16,
            exp = false,
            div = 1,
            default = 1,
            formatter = function(param)
                return "ch " .. math.floor(param:get())
            end
        }
    }
    params:add_group("SEQUENCE " .. self.id, #params_menu)
    for _, pram in ipairs(params_menu) do
        pram.id = "sequence" .. self.id .. "_" .. pram.id
        params:add{
            type = "control",
            id = pram.id,
            name = pram.name,
            controlspec = controlspec.new(pram.min, pram.max,
                                          pram.exp and "exp" or "lin", pram.div,
                                          pram.default, pram.unit or "",
                                          pram.div / (pram.max - pram.min)),
            formatter = pram.formatter
        }
        if pram.action then params:set_action(pram.id, pram.action) end
        if pram.hide then params:hide(pram.id) end
    end

    self.instrument = _path.code .. "eighteen/data"

    engine.mx_global("delayBeats", 1)
    engine.mx_global("secondsPerBeat", clock.get_beat_sec())
    engine.mx_global("delayFeedback", 0.05)
    engine.mx_set(self.instrument, "delaysend", 0.2)
    if self.id == 1 then engine.mx_note_on(self.instrument, 60, 0) end
end

function Sequence:marshal()
    local data = {}
    data.matrix = self.matrix
    data.step = self.step
    data.movement = self.movement
    data.notes_to_ghost = self.notes_to_ghost
    data.note_offset = self.note_offset
    return data
end

function Sequence:delta_param(v, d)
    params:delta("sequence" .. self.id .. "_" .. v, d)
end

function Sequence:get_param(v)
    return params:get("sequence" .. self.id .. "_" .. v)
end

function Sequence:get_param_str(v)
    return params:string("sequence" .. self.id .. "_" .. v)
end

function Sequence:step_peek(step, movement)
    if self:get_param("direction") == 1 then
        movement = 1
        step = step + 1
        while step > self:get_param("limit") do
            step = step - self:get_param("limit")
        end
    elseif self:get_param("direction") == 2 then
        movement = -1
        step = step - 1
        while step < 1 do step = step + self:get_param("limit") end
    elseif self:get_param("direction") == 3 then
        step = step + movement
        if step > self:get_param("limit") then
            step = self:get_param("limit") - 1
            movement = -1
        end
        if step < 1 then
            step = 2
            movement = 1
        end
    elseif self:get_param("direction") == 4 then
        step = math.random(1, self:get_param("limit"))
    end
    return step, movement
end

function Sequence:update()
    self.step_time_before_last = self.step_time_last
    self.step_time_last = clock.get_beats()
    self.step_last = self.step
    self.step, self.movement = self:step_peek(self.step, self.movement)
    -- self.step_next, _ = self:step_peek(self.step, self.movement)
    -- check which notes are activated
    local notes = {}
    for i = 1, self.note_limit do
        if self.matrix[self.step_last][i] > 0 then table.insert(notes, i) end
    end

    -- turn off prevoius notes
    for _, note_data in ipairs(self.notes_on) do
        local instrument = note_data[1]
        local note = note_data[2]
        engine.mx_note_off(self.instrument, note)
    end

    -- emit those notes
    self.notes_on = {}
    for i, note in ipairs(notes) do self.note_to_play[note] = true end
    for i, v in pairs(self.note_to_play) do if v then self:note_on(i) end end
    self.note_to_play = {}

    -- check if there are notes to ghost
    if #self.notes_to_ghost > 0 then
        -- randomly choose 1 note to toggle off if it is on
        local note_to_ghost = self.notes_to_ghost[math.random(1,
                                                              #self.notes_to_ghost)]
        if self.matrix[note_to_ghost[1]][note_to_ghost[2]] > 0 then
            self.matrix[note_to_ghost[1]][note_to_ghost[2]] = 0
            -- remove it from the notes_to_ghost table
            for i, v in ipairs(self.notes_to_ghost) do
                if v[1] == note_to_ghost[1] and v[2] == note_to_ghost[2] then
                    table.remove(self.notes_to_ghost, i)
                    break
                end
            end
        end
    end
end

function Sequence:note_on(note_index)
    local note = self.scale_full[note_index]
    table.insert(self.notes_on, {self.instrument, note})
    local velocity = math.random(40, 80)
    engine.mx_note_on(self.instrument, note, velocity)
end

function Sequence:clear()
    for i = 1, self.sequence_max do
        self.matrix[i] = {}
        for j = 1, self.note_max do self.matrix[i][j] = 0 end
    end
end

function Sequence:toggle_from_note(note)
    local closest_index = 1
    local closest_distance = 1000
    for i, v in ipairs(self.scale_full) do
        local distance = math.abs(v - note)
        if distance < closest_distance then
            closest_distance = distance
            closest_index = i
        end
    end
    print(self.step, closest_index)
    self.matrix[self.step][closest_index] = 1 -
                                                self.matrix[self.step][closest_index]
    -- find the note offset that is closest to that index
    self.note_offset = math.floor((closest_index) / 7) * 7
    print(self.note_offset)
end

function Sequence:toggle_pos(step, row)
    local note_index = (row + self.note_offset - 1) % self.note_limit + 1
    self.matrix[step][note_index] = 1 - self.matrix[step][note_index]
end

function Sequence:toggle_note(note_index)
    local step = self.step
    local note_index = self:get_note_index(note_index)
    if self.matrix[step][note_index] == 0 then
        self.matrix[step][note_index] = 1
    else
        self.matrix[step][note_index] = 0
    end
end

function Sequence:get_note_index(note_index)
    return (note_index + self.note_offset - 1) % self.note_limit + 1
end

function Sequence:get_note_from_index(note_index)
    return self.scale_full[self:get_note_index(note_index)]
end

function Sequence:clear_all()
    for i = 1, self:get_param("limit") do
        for j = 1, self.note_limit do self.matrix[i][j] = 0 end
    end
end

function Sequence:ghost_section(step_start, step_end, note_start, note_end)
    for i = step_start, step_end do
        for j = note_start, note_end do
            if self.matrix[i][j] > 0 then
                -- check to see if (i,j) is already in the notes_to_ghost table
                local has_note = false
                for k, v in ipairs(self.notes_to_ghost) do
                    if v[1] == i and v[2] == j then
                        has_note = true
                        break
                    end
                end
                if not has_note then
                    table.insert(self.notes_to_ghost, {i, j})
                end
            end
        end
    end
end

return Sequence
