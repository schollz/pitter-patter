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
    self.note_max = 7 * 4 + 1 -- 4 octaves
    self.scale_full = MusicUtil.generate_scale_of_length(36, 1, self.note_max)
    local matrix = {}
    for i = 1, self.sequence_max do
        matrix[i] = {}
        for j = 1, self.note_max do
            matrix[i][j] = 0
        end
    end
    -- -- add random notes to the matrix
    -- for i = 1, self.sequence_max do
    --     for j = 1, self.note_max do
    --         if math.random() > 0.8 then
    --             matrix[i][j] = 1
    --         end
    --     end
    -- end
    self.matrix = matrix
    self.notes_to_ghost = {}
    self.instrument = "marimba_white"
    self.direction = "pingpong"
    self.step = 1
    self.step_next = 1
    self.movement = 1
    self.sequence_limit = 8
    self.note_limit = self.note_max
    self.note_offset = 0
    self.notes_on = {}
    self.step_time_last = clock.get_beats()
    self.step_time_before_last = self.step_time_last
end

function Sequence:step_peek(step, movement)
    if self.direction == "forward" then
        movement = 1
        step = step + 1
        if step > self.sequence_limit then
            step = 1
        end
    elseif self.direction == "backward" then
        movement = -1
        step = step - 1
        if step < 1 then
            step = self.sequence_limit
        end
    elseif self.direction == "random" then
        step = math.random(1, self.sequence_limit)
    elseif self.direction == "pingpong" then
        step = step + movement
        if step > self.sequence_limit then
            step = self.sequence_limit - 1
            movement = -1
        elseif step < 1 then
            step = 2
            movement = 1
        end
    end
    return step, movement
end

function Sequence:update()
    self.step_time_before_last = self.step_time_last
    self.step_time_last = clock.get_beats()
    self.step, self.movement = self:step_peek(self.step, self.movement)
    self.step_next, _ = self:step_peek(self.step, self.movement)
    -- check which notes are activated
    local notes = {}
    for i = 1, self.note_limit do
        if self.matrix[self.step][i] > 0 then
            table.insert(notes, i)
        end
    end

    -- turn off prevoius notes

    for _, note_data in ipairs(self.notes_on) do
        local instrument = note_data[1]
        local note = note_data[2]
        print("note_off", instrument, note)
        engine.mx_note_off(instrument, note)
    end

    -- emit those notes
    self.notes_on = {}
    for i, note in ipairs(notes) do
        table.insert(self.notes_on, {self.instrument, note})
        print("note_on", self.instrument, note)
        local velocity = 60
        engine.mx_note_on(_path.code .. "eighteen/data/" .. self.instrument, note, velocity)
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

function Sequence:toggle_pos(step, row)
    local note_index = (row + self.note_offset - 1) % self.note_limit + 1
    print("toggle_pos", step, row, note_index)
    self.matrix[step][note_index] = 1 - self.matrix[step][note_index]
end

function Sequence:toggle_note(note_index)
    local step = self.step
    if (self.step_time_last - self.step_time_before_last) < (clock.get_beats() - self.step_time_last) / 2 then
        step = self.step_next
    end
    local note_index = (note_index + self.note_offset - 1) % self.note_limit + 1
    print("note_index", note_index, "step", step)
    if self.matrix[step][note_index] == 0 then
        self.matrix[step][note_index] = 1
    else
        self.matrix[step][note_index] = 0
    end
end

function Sequence:clear_all()
    for i = 1, self.sequence_limit do
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
