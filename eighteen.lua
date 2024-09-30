-- lightsout v0.0.0
--
--
-- llllllll.co/t/lightsout
--
--
--
--    ▼ instructions below ▼
grid__ = include("lightsout/lib/ggrid")
MusicUtil = require "musicutil"
lattice = require("lattice")

engine.name = "PolyPerc"

beat_current = 0

function init()
    grid_ = grid__:new()

    scale_full = MusicUtil.generate_scale_of_length(12, 1, 64)
    for _, note in ipairs(MusicUtil.generate_scale_of_length(12, 1, 128)) do
        table.insert(scale_full, note)
    end
    -- shuffled = {}
    -- for i, v in ipairs(scale_full) do
    --   local pos = math.random(1, #shuffled+1)
    --   table.insert(shuffled, pos, v)
    -- end
    -- scale_full=shuffled
    scales = {}
    k = 1
    for col = 1, 16 do
        for row = 1, 8 do
            if col == 1 then
                scales[row] = {}
            end
            scales[row][col] = scale_full[k]
            k = k + 1
        end
        k = k - 3
    end

    -- start lattice
    local sequencer = lattice:new{
        ppqn = 96
    }
    sequencer:new_pattern({
        action = function(t)
            print("division")
            beat_current = beat_current + 1
            grid_:set_beat(beat_current)
            redraw()
        end,
        division = 1 / 8
    })
    sequencer:hard_restart()

end

function play_note(col, step)
    local row = (step - 1) % 8 + 1
    local light = grid_.lightsout[row][col]
    if light > 0 then
        print(row, col)
        print(scales[row][col])
        local freq = MusicUtil.note_num_to_freq(scales[row][col])
        grid_.visual[row][col] = 15
        engine.hz(freq)
        -- grid_:toggle_key(row,col)
    end
end

function enc(k, d)

end

function key(k, z)

end

function redraw()
    screen.clear()
    -- draw the grid
    local grid_square_size = 7
    local visual = grid_:get_visual()
    print(visual[1][1])
    for i, v in ipairs(visual) do
        for j, u in ipairs(v) do
            -- draw a box 
            screen.level(10)
            screen.line_width(1)
            screen.rect((j * grid_square_size) + 2, i * grid_square_size - grid_square_size / 2, grid_square_size,
                grid_square_size)
            screen.stroke()
            if u > 0 then
                screen.rect((j * grid_square_size) + 2, i * grid_square_size - grid_square_size / 2 + 1,
                    grid_square_size - 1, grid_square_size - 1)
                screen.level(u)
                screen.fill()
            end
        end
    end

    screen.update()
end

function rerun()
    norns.script.load(norns.state.script)
end

function cleanup()

end

function table.reverse(t)
    local len = #t
    for i = len - 1, 1, -1 do
        t[len] = table.remove(t, i)
    end
end
