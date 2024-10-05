-- local pattern_time = require("pattern")
local GGrid = {}

local function gcd(a, b)
  while b ~= 0 do a, b = b, a % b end
  return a
end

local function get_line_coordinates(x1, y1, x2, y2)

  local coordinates = {}

  -- Determine if we need to swap points
  if x1 > x2 then
    x1, x2 = x2, x1
    y1, y2 = y2, y1
  end

  if y1 == y2 then
    for x = x1, x2 do table.insert(coordinates, {x, y1}) end
    return coordinates
  end

  -- Calculate slope
  local dx = x2 - x1
  local dy = y2 - y1
  local divisor = gcd(math.abs(dx), math.abs(dy))

  -- Reduce dx and dy
  dx = dx / divisor
  dy = dy / divisor

  -- Generate points for every whole number x
  local x, y = x1, y1
  while x <= x2 do
    table.insert(coordinates, {x, math.floor(y + 0.5)}) -- Round y to nearest integer
    x = x + 1
    y = y + dy / math.abs(dx)
  end

  return coordinates
end

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

  m.width = m.g.cols
  m.height = m.g.rows
  if m.width == nil then m.width = 16 end
  if m.height == nil then m.height = 8 end
  m.scroll_y = 0

  -- setup visual
  m.beat = 0
  m.visual = {}
  m.grid_width = m.width
  for i = 1, m.height do
    m.visual[i] = {}
    for j = 1, m.width do
      m.visual[i][j] = 0
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
    -- check if other buttons are pressed
    local row_other = nil
    local col_other = nil
    for k, _ in pairs(self.pressed_buttons) do
      local r, c = k:match("(%d+),(%d+)")
      r, c = tonumber(r), tonumber(c)
      if not (r == row and c == col) and r < self.height then
        row_other = r
        col_other = c
        break
      end
    end
    if row_other ~= nil and col_other ~= nil then
      local flipped_row_other = self.height - row_other
      -- toggle range 
      -- toggle each position between flipped_row_other,col_other and flipped_row,col
      for i, coord in ipairs(get_line_coordinates(col_other, flipped_row_other, col, flipped_row)) do
        print(i, coord[1], coord[2])
        if i > 1 then
          local x, y = coord[1], coord[2]
          print(x, y)
          local step_index = (x) + math.floor((self.sequencer.step - 1) / 16) * 16
          self.sequencer:toggle_pos(step_index, y) -- Use flipped_row
        end
      end
    else
      -- toggle specific position
      print(flipped_row, col)
      local step_index = (col) + math.floor((self.sequencer.step - 1) / 16) * 16
      self.sequencer:toggle_pos(step_index, flipped_row) -- Use flipped_row
    end
  elseif on and row == self.height and col == self.width then
    self.sequencer.note_offset = math.floor((self.sequencer.note_offset + 7) / 7) * 7
  end
end

function GGrid:get_visual()
  -- clear visual
  for row = 1, self.height do for col = 1, self.width do self.visual[row][col] = 0 end end

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
  for row = 1, self.height do for col = s, e do if gd[row][col] ~= 0 then self.g:led(col + adj, row, gd[row][col]) end end end
  self.g:refresh()
end

return GGrid
