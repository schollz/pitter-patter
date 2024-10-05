-- local pattern_time = require("pattern")
local GGrid = {}

function GGrid:new(args)
  local m = setmetatable({}, {__index=GGrid})
  local args = args == nil and {} or args

  m.grid_on = args.grid_on == nil and true or args.grid_on

  -- initiate the grid
  m.g = grid.connect()
  m.g.key = function(x, y, z)
    if m.grid_on then m:grid_key(x, y, z) end
  end
  print("grid columns: " .. m.g.cols)

  m.width = 16
  m.height = 8
  m.scroll_y = 0

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
    if m.grid_on then m:grid_redraw() end
  end
  m.grid_refresh:start()

  return m
end

function GGrid:grid_key(x, y, z)
  self:key_press(y, x, z == 1)
  self:grid_redraw()
end

function GGrid:key_press(row, col, on)
  local flipped_row = self.height - row
  if on then
    self.pressed_buttons[row .. "," .. col] = true
  else
    self.pressed_buttons[row .. "," .. col] = nil
  end
  if on and row == self.height and col < self.width - 1 then
    -- toggle sequence from keyboard
    self.sequencer:toggle_note(col)
  elseif on and row < self.height then
    -- toggle specific position
    print(flipped_row, col)
    local step_index = (col) + math.floor((self.sequencer.step - 1) / 16) * 16
    self.sequencer:toggle_pos(step_index, flipped_row) -- Use flipped_row
  elseif on and row == self.height and col == self.width then
    self.sequencer.note_offset = math.floor((self.sequencer.note_offset + 7) / 7) * 7
  end
end

function GGrid:get_visual()
  -- clear visual
  for row = 1, 8 do for col = 1, self.grid_width do self.visual[row][col] = 0 end end

  -- illuminate currently pressed button
  for k, _ in pairs(self.pressed_buttons) do
    local row, col = k:match("(%d+),(%d+)")
    self.visual[tonumber(row)][tonumber(col)] = 15
  end

  -- illuminate sequence
  if self.sequencer ~= nil then
    -- figure out which of the 'width' steps to show based on 
    -- self.sequencer.step and self.width 
    local step_offset = math.floor((self.sequencer.step - 1) / self.width) * self.width
    for i = 1, self.width do
      for j = 1, self.height - 1 do
        local note_index = self.sequencer:get_note_index(self.height - j)
        if self.sequencer.matrix[i + step_offset][note_index] > 0 then
          self.visual[j][i] = 12 - (self.sequencer.scale_full[note_index] % 12) + 2
        end
      end
    end

    -- show current step
    for i = 1, self.height - 1 do
      local v = self.visual[i][(self.sequencer.step - 1) % self.width + 1]
      v = v + 4
      if v > 15 then v = 15 end
      self.visual[i][(self.sequencer.step - 1) % self.width + 1] = v
    end

    -- show keyboard
    for col = 1, self.width - 1 do
      local note_index = self.sequencer:get_note_index(col)
      self.visual[self.height][col] = 12 - (self.sequencer.scale_full[note_index] % 12) + 2
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
  for row = 1, 8 do for col = s, e do if gd[row][col] ~= 0 then self.g:led(col + adj, row, gd[row][col]) end end end
  self.g:refresh()
end

return GGrid
