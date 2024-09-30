-- local pattern_time = require("pattern")
local Sequence = {}

function Sequence:new(args)
    local m = setmetatable({}, {
        __index = Sequence
    })
    local args = args == nil and {} or args
    m:init()
    return m
end

function Sequence:init()
    local sequence_max = 16 * 4 -- 16 steps, 4 measures
    local note_max = 48 -- 4 octaves
    local matrix = {}
    for i = 1, sequence_max do
        matrix[i] = {}
        for j = 1, note_max do
            matrix[i][j] = 0
        end
    end
    self.matrix = matrix
    self.notes_to_ghost = {}
    self.instrument = "marimba_white"
    self.direction = "forward"
    self.step = 1
    self.movement = 1
    self.sequence_limit = 16
    self.note_limit = 48
end

function Sequence:update()
    local step = self.step
    if self.direction == "forward" then
        self.movement = 1
        step = step + 1
        if step > self.sequence_limit then
            step = 1
        end
    elseif self.direction == "backward" then
        self.movement = -1
        step = step - 1
        if step < 1 then
            step = self.sequence_limit
        end
    elseif self.direction == "random" then
        step = math.random(1, self.sequence_limit)
    elseif self.direction == "pingpong" then
        step = step + self.movement
        if step > self.sequence_limit then
            step = self.sequence_limit - 1
            self.movement = -1
        elseif step < 1 then
            step = 2
            self.movement = 1
        end
    end
    self.step = step
    -- check which notes are activated
    local notes = {}
    for i = 1, self.note_limit do
        if self.matrix[step][i] > 0 then
            table.insert(notes, i)
        end
    end
    -- emit those notes
    for i, note in ipairs(notes) do
        print("note_on", self.instrument, note)
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

function Sequence:toggle(step, note)
    if self.matrix[step][note] == 0 then
        self.matrix[step][note] = 1
    else
        self.matrix[step][note] = 0
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
