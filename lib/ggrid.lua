-- local pattern_time = require("pattern")
local GGrid = {}

function GGrid:new(args)
    local m = setmetatable({}, {
        __index = GGrid
    })
    local args = args == nil and {} or args

    m.grid_on = args.grid_on == nil and true or args.grid_on

    -- initiate the grid
    m.g = grid.connect()
    m.g.key = function(x, y, z)
        if m.grid_on then
            m:grid_key(x, y, z)
        end
    end
    print("grid columns: " .. m.g.cols)

    -- setup visual
    m.beat = 0
    m.visual = {}
    m.lightsout = {}
    m.playing = {}
    m.grid_width = 16
    for i = 1, 8 do
        m.lightsout[i] = {}
        m.playing[i] = {}
        m.visual[i] = {}
        for j = 1, m.grid_width do
            m.visual[i][j] = 0
            m.lightsout[i][j] = 0
            m.playing[i][j] = 0
        end
    end

    -- keep track of pressed buttons
    m.pressed_buttons = {}

    -- grid refreshing
    m.grid_refresh = metro.init()
    m.grid_refresh.time = 0.03
    m.grid_refresh.event = function()
        if m.grid_on then
            m:grid_redraw()
        end
    end
    m.grid_refresh:start()

    return m
end

function GGrid:grid_key(x, y, z)
    self:key_press(y, x, z == 1)
    self:grid_redraw()
end

function GGrid:key_press(row, col, on)
    if on then
        self.pressed_buttons[row .. "," .. col] = true
    else
        self.pressed_buttons[row .. "," .. col] = nil
    end
    if on then
        self:toggle_key(row, col)
    end
end

function GGrid:set_beat(beat)
    self.beat = beat
end

function GGrid:toggle_key(row, col)
    for i = row - 1, row + 1 do
        for j = col - 1, col + 1 do
            if i >= 1 and i <= 8 and j >= 1 and j <= self.grid_width then
                self.lightsout[i][j] = 1 - self.lightsout[i][j]
            end
        end
    end
end

function GGrid:get_visual()
    -- clear visual
    for row = 1, 8 do
        for col = 1, self.grid_width do
            self.visual[row][col] = 0
        end
    end

    -- illuminate lights out
    for row in ipairs(self.lightsout) do
        for col in ipairs(self.lightsout[row]) do
            if self.visual[row][col] < 7 then
                self.visual[row][col] = 7 * self.lightsout[row][col]
            end
        end
    end

    -- illuminate currently pressed button
    for k, _ in pairs(self.pressed_buttons) do
        local row, col = k:match("(%d+),(%d+)")
        self.visual[tonumber(row)][tonumber(col)] = 15
    end

    if self.beat > 0 then
        local col = self.beat % 16 + 1
        for row = 1, 8 do
            self.visual[row][col] = 5
        end
    end

    return self.visual
end

function GGrid:grid_redraw()
    self.g:all(0)
    local gd = self:get_visual()
    local s = 1
    local e = self.grid_width
    local adj = 0
    for row = 1, 8 do
        for col = s, e do
            if gd[row][col] ~= 0 then
                self.g:led(col + adj, row, gd[row][col])
            end
        end
    end
    self.g:refresh()
end

return GGrid
