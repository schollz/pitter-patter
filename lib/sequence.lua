local MusicUtil = require "musicutil"

local Sequence = {}

function Sequence:new(args)
    local m = setmetatable({}, {
        __index = Sequence
    })
    local args = args == nil and {} or args
    for k, v in pairs(args) do
        m[k] = v
    end
    m:init()
    return m
end

function Sequence:init()
    self.sequence_max = 16 * 4 -- 16 steps, 4 measures
    self.note_max = 7 * 6 -- 4 octaves
    local scale_names = {}
    for i = 1, #MusicUtil.SCALES do
        table.insert(scale_names, string.lower(MusicUtil.SCALES[i].name))
    end

    self.scale_full = MusicUtil.generate_scale_of_length(24, 1, self.note_max)
    local matrix = {}
    for i = 1, self.sequence_max do
        matrix[i] = {}
        for j = 1, self.note_max do
            matrix[i][j] = 0
        end
    end

    self.velocity_profiles = {{1, 1, 1, 1, 1, 1, 1, 1}, {1, 1, 0, 1, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0}, {1, 0, 1, 0, 1, 0},
                              {1, 0, 1, 1, 0, 0, 1, 0, 1, 0, 1}, {0, 0, 1, 0, 0, 1, 0, 0}, {1, 1, 0, 1, 1, 0, 1, 0}}
    self.matrix = matrix
    self.notes_to_ghost = {}
    self.step = 1
    self.step_last = 1
    self.step_next = 1
    self.movement = 1
    self.note_limit = self.note_max
    self.note_offset = 21
    self.notes_on = {}
    self.step_time_last = clock.get_beats()
    self.step_time_before_last = self.step_time_last
    self.midi_devices = {}
    self.midi_device = midi.connect(1)
    self.velocity_i = 1
    self.beat = 1
    self.last_beat = 1
    for i = 1, #midi.vports do
        local long_name = midi.vports[i].name
        local short_name = string.len(long_name) > 15 and util.acronym(long_name) or long_name
        table.insert(self.midi_devices, i .. ": " .. short_name)
    end

    -- find all the folders in the mx.samples folder
    local instrument_folders = {}
    local instrument_options = {"pitter patter"}
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
    local params_menu = {{
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
                self.instrument = _path.code .. "pitter-patter/data"
            else
                self.instrument = _path.audio .. "mx.samples/" .. instrument_folders[v - 1]
            end
            engine.mx_set_instrument(self.id, self.instrument)
        end
    }, -- division
    {
        id = "division",
        name = "clock division",
        min = 1,
        max = 8,
        exp = false,
        div = 1,
        default = 7,
        formatter = function(param)
            return self.divisions_strings[param:get()]
        end
    }, {
        id = "mute",
        name = "mute",
        min = 0,
        max = 1,
        exp = false,
        div = 1,
        default = 0,
        formatter = function(param)
            return param:get() == 1 and "muted" or "unmuted"
        end
    }, {
        id = "generate",
        name = "generate",
        min = 0,
        max = 1,
        exp = false,
        div = 1,
        default = 0,
        -- default = self.id==1 and 1 or 0,
        formatter = function(param)
            return param:get() == 0 and "no" or "yes"
        end,
        action = function(v)
            if v == 1 then
                self:clear()
                local density = math.random(90,95)/100
                for i = 1, self.sequence_max do
                    for j = util.round(self.note_max*1/4), util.round(self.note_max*3/4) do
                        if math.random() > density then
                            matrix[i][j] = 1
                        end
                    end
                end
            end
        end
    }, {
        id = "scale",
        name = "scale",
        min = 1,
        max = #scale_names,
        exp = false,
        div = 1,
        default = 1,
        formatter = function(param)
            return scale_names[param:get()]
        end,
        action = function(v)
            print("scale changed to " .. scale_names[v])
            self.scale_full = MusicUtil.generate_scale_of_length(self:get_param("root_note"), self:get_param("scale"),
                self.note_max)
        end
    }, {
        id = "root_note",
        name = "root note",
        min = 12,
        max = 36,
        exp = false,
        div = 1,
        default = 24,
        formatter = function(param)
            return MusicUtil.note_num_to_name(param:get(), true)
        end,
        action = function(v)
            print("root note changed to " .. MusicUtil.note_num_to_name(v, true))
            self.scale_full = MusicUtil.generate_scale_of_length(self:get_param("root_note"), self:get_param("scale"),
                self.note_max)
        end
    }, {
        id = "velocity",
        name = "velocity",
        min = 1,
        max = #self.velocity_profiles,
        exp = false,
        div = 1,
        default = 2,
        formatter = function(param)
            -- concat the table into a string
            local str = ""
            for i, v in ipairs(self.velocity_profiles[param:get()]) do
                str = str .. v
            end
            return str
        end
    }, {
        id = "direction",
        name = "direction",
        min = 1,
        max = 4,
        exp = false,
        div = 1,
        default = 4,
        formatter = function(param)
            local directions = {"backward", "ping pong", "random", "forward"}
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
        id = "probability",
        name = "probability",
        min = 0,
        max = 1,
        exp = false,
        div = 0.01,
        default = 1.0,
        formatter = function(param)
            return param:get() * 100 .. "%"
        end
    }, {
        id = "output",
        name = "output",
        min = 1,
        max = 5,
        exp = false,
        div = 1,
        default = 1,
        formatter = function(param)
            local outputs = {"supercollider", "midi", "crow out 1+2", "crow ii JF", "crow ii 301"}
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
    }, {
        id = "db",
        name = "volume",
        min = -96,
        max = 32,
        exp = false,
        div = 1,
        default = 0,
        formatter = function(param)
            return param:get() .. " dB"
        end,
        action = function(v)
            engine.mx_set(self.id, self.instrument, "amp", util.dbamp(v))
        end
    }, {
        id = "pan",
        name = "pan",
        min = -1,
        max = 1,
        exp = false,
        div = 0.025,
        default = 0,
        formatter = function(param)
            return param:get()
        end,
        action = function(v)
            engine.mx_set(self.id, self.instrument, "pan", v)
        end
    }, {
        id = "attack",
        name = "attack",
        min = 0.01,
        max = 1,
        exp = true,
        div = 0.01,
        default = 0.01,
        formatter = function(param)
            return param:get() .. " s"
        end,
        action = function(v)
            engine.mx_set(self.id, self.instrument, "attack", v)
        end
    }, {
        id = "decay",
        name = "decay",
        min = 0.1,
        max = 5,
        exp = true,
        div = 0.1,
        default = 0.1,
        formatter = function(param)
            return param:get() .. " s"
        end,
        action = function(v)
            engine.mx_set(self.id, self.instrument, "decay", v)
        end
    }, {
        id = "sustain",
        name = "sustain",
        min = 0,
        max = 1,
        exp = false,
        div = 0.01,
        default = 1,
        formatter = function(param)
            return param:get()
        end,
        action = function(v)
            engine.mx_set(self.id, self.instrument, "sustain", v)
        end
    }, {
        id = "release",
        name = "release",
        min = 0.1,
        max = 10,
        exp = false,
        div = 0.1,
        default = 2,
        formatter = function(param)
            return param:get() .. " s"
        end,
        action = function(v)
            engine.mx_set(self.id, self.instrument, "release", v)
        end
    }, {
        id = "fadetime",
        name = "fadetime",
        min = 0.1,
        max = 5,
        exp = true,
        div = 0.1,
        default = 1,
        formatter = function(param)
            return param:get()
        end,
        action = function(v)
            engine.mx_set(self.id, self.instrument, "fadetime", v)
        end
    }, {
        id = "delaysend",
        name = "delay send",
        min = 0,
        max = 1,
        exp = false,
        div = 0.01,
        default = 0,
        formatter = function(param)
            return param:get()
        end,
        action = function(v)
            engine.mx_set(self.id, self.instrument, "delaysend", v)
        end
    }, {
        id = "reverbsend",
        name = "reverb send",
        min = 0,
        max = 1,
        exp = false,
        div = 0.01,
        default = 0,
        formatter = function(param)
            return param:get()
        end,
        action = function(v)
            engine.mx_set(self.id, self.instrument, "reverbsend", v)
        end
    }, {
        id = "lpf",
        name = "low pass filter",
        min = 20,
        max = 18000,
        exp = true,
        div = 100,
        default = 18000,
        formatter = function(param)
            return param:get() .. " Hz"
        end,
        action = function(v)
            engine.mx_set(self.id, self.instrument, "lpf", v)
        end
    }, {
        id = "lpfrq",
        name = "low pass filter resonance",
        min = 0.1,
        max = 1,
        exp = false,
        div = 0.01,
        default = 0.707,
        formatter = function(param)
            return param:get()
        end,
        action = function(v)
            engine.mx_set(self.id, self.instrument, "lpfrq", v)
        end
    }, {
        id = "hpf",
        name = "high pass filter",
        min = 20,
        max = 18000,
        exp = true,
        div = 10,
        default = 20,
        formatter = function(param)
            return param:get() .. " Hz"
        end,
        action = function(v)
            engine.mx_set(self.id, self.instrument, "hpf", v)
        end
    }, {
        id = "hpfrq",
        name = "high pass filter resonance",
        min = 0.1,
        max = 1,
        exp = false,
        div = 0.01,
        default = 1,
        formatter = function(param)
            return param:get()
        end,
        action = function(v)
            engine.mx_set(self.id, self.instrument, "hpfrq", v)
        end
    }}

    params:add_group("SEQUENCE " .. self.id, #params_menu)
    for _, pram in ipairs(params_menu) do
        pram.id = "sequence" .. self.id .. "_" .. pram.id
        params:add{
            type = "control",
            id = pram.id,
            name = pram.name,
            controlspec = controlspec.new(pram.min, pram.max, pram.exp and "exp" or "lin", pram.div, pram.default,
                pram.unit or "", pram.div / (pram.max - pram.min)),
            formatter = pram.formatter
        }
        if pram.action then
            params:set_action(pram.id, pram.action)
        end
        if pram.hide then
            params:hide(pram.id)
        end
    end

    self.instrument = _path.code .. "pitter-patter/data"

    engine.mx_global("delayBeats", 1)
    engine.mx_global("secondsPerBeat", clock.get_beat_sec())
    engine.mx_global("delayFeedback", 0.05)
    engine.mx_set(self.id, self.instrument, "delaysend", 0.2)
    if self.id == 1 then
        engine.mx_note_on(self.id, self.instrument, 60, 0)
    end
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

function Sequence:unmarshal(data)
    self.matrix = data.matrix
    self.step = data.step
    self.movement = data.movement
    self.notes_to_ghost = data.notes_to_ghost
    self.note_offset = data.note_offset
end

function Sequence:get_velocity_profile()
    return self.velocity_profiles[self:get_param("velocity")]
end

function Sequence:delta_param(v, d)
    params:delta("sequence" .. self.id .. "_" .. v, d)
end

function Sequence:get_param(v)
    return params:get("sequence" .. self.id .. "_" .. v)
end

function Sequence:set_param(v, value)
    params:set("sequence" .. self.id .. "_" .. v, value)
end

function Sequence:get_param_str(v)
    return params:string("sequence" .. self.id .. "_" .. v)
end

function Sequence:step_peek(step, movement)
    if self:get_param("direction") == 4 then
        movement = 1
        step = step + 1
        while step > self:get_param("limit") do
            step = step - self:get_param("limit")
        end
    elseif self:get_param("direction") == 1 then
        movement = -1
        step = step - 1
        while step < 1 do
            step = step + self:get_param("limit")
        end
    elseif self:get_param("direction") == 2 then
        step = step + movement
        if step > self:get_param("limit") then
            step = self:get_param("limit") - 1
            movement = -1
        end
        if step < 1 then
            step = 2
            movement = 1
        end
    elseif self:get_param("direction") == 3 then
        step = math.random(1, self:get_param("limit"))
    end
    return step, movement
end

function Sequence:update(division, beat)
    if division ~= self.divisions[self:get_param("division")] then
        do
            return
        end
    end
    -- if generating then remove a random note and replace with a new note
    if self:get_param("generate") == 1 and math.random() > 0.9 then
        -- find all the steps
        local steps = {}
        for i = 1, self.sequence_max do
            for j = 1, self.note_max do
                if self.matrix[i][j] > 0 then
                    table.insert(steps, {i, j})
                end
            end
        end
        if #steps > 0 then
            local random_step = steps[math.random(1, #steps)]
            print("removing note", random_step[1], random_step[2])
            self.matrix[random_step[1]][random_step[2]] = 0
            local random_i = math.random(1, self.sequence_max)
            local random_j = math.random(1, self.note_max)
            self.matrix[random_i][random_j] = 1
            print("adding note", random_i, random_j)
        end
    end
    self.last_beat = self.beat
    self.beat = beat and beat or self.last_beat + 1
    self.step_time_before_last = self.step_time_last
    self.step_time_last = clock.get_beats()
    self.step_last = self.step
    self.step, self.movement = self:step_peek(self.step, self.movement)
    -- self.step_next, _ = self:step_peek(self.step, self.movement)
    -- check which notes are activated
    local notes = {}
    for i = 1, self.note_limit do
        if self.matrix[self.step_last][i] > 0 then
            table.insert(notes, i)
        end
    end

    -- turn off prevoius notes
    for _, note_data in ipairs(self.notes_on) do
        local instrument = note_data[1]
        local note = note_data[2]
        if self:get_param("output") == 1 then
            engine.mx_note_off(self.id, note)
        elseif self:get_param("output") == 2 then
            -- midi output
            if self.midi_out_device then
                self.midi_out_device:note_off(note, 0, self:get_param("midi_out_channel"))
            end
        end
    end

    -- emit those notes
    self.notes_on = {}
    for i, note in pairs(notes) do
        self:note_on(note)
    end

    -- check if there are notes to ghost
    if #self.notes_to_ghost > 0 then
        -- randomly choose 1 note to toggle off if it is on
        local note_to_ghost = self.notes_to_ghost[math.random(1, #self.notes_to_ghost)]
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
    if self:get_param("mute") == 1 then
        do
            return
        end
    end
    if self:get_param("probability") < math.random() then
        do
            return
        end
    end
    local note = self.scale_full[note_index]
    table.insert(self.notes_on, {self.instrument, note})
    self.velocity_i = (self.beat - 1) % #self:get_velocity_profile() + 1
    if self.velocity_i > #self:get_velocity_profile() then
        self.velocity_i = 1
    end
    local velocity
    if self.velocity_profiles[self:get_param("velocity")][self.velocity_i] == 1 then
        velocity = math.random(80, 125)
    else
        velocity = math.random(20, 60)
    end
    -- print("note on", note, velocity)
    if self:get_param("output") == 1 then
        engine.mx_note_on(self.id, self.instrument, note, velocity)
    elseif self:get_param("output") == 2 then
        -- midi output
        if self.midi_out_device then
            self.midi_out_device:note_on(note, velocity, self:get_param("midi_out_channel"))
        end
    elseif self:get_param("output") == 3 then
        crow.output[1].volts = (note - 60) / 12
        crow.output[2].execute()
    elseif self:get_param("output") == 4 then
        crow.ii.jf.play_note((note - 60) / 12, 5)
    elseif self:get_param("output") == 5 then -- er301
        crow.ii.er301.cv(1, (note - 60) / 12)
        crow.ii.er301.tr_pulse(1)
    end
end

function Sequence:clear_visible()
    for i = 1, self.sequence_max do
        for row = 1, 7 do
            local note_index = (row + self.note_offset - 1) % self.note_limit + 1
            self.matrix[i][note_index] = 0
        end
    end
end

function Sequence:clear()
    for i = 1, self.sequence_max do
        self.matrix[i] = {}
        for j = 1, self.note_max do
            self.matrix[i][j] = 0
        end
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
    self.matrix[self.step][closest_index] = 1 - self.matrix[self.step][closest_index]
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
        for j = 1, self.note_limit do
            self.matrix[i][j] = 0
        end
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
