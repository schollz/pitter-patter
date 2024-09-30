-- eighteen v0.0.0
--
--
-- llllllll.co/t/eighteen
--
--
--
--    ▼ instructions below ▼
-- 
-- 
GridLib = include("eighteen/lib/ggrid")
Sequence = include("eighteen/lib/sequence")
lattice = require("lattice")

engine.name = "MxSamplez"

sequencers = {}

function init()

    for i = 1, 4 do
        sequencers[i] = Sequence:new({
            id = i
        })
    end
    print("sequencer 3 id: ", sequencers[3].id)
    grid_ = GridLib:new()

    -- set default sequencer
    grid_.sequencer = sequencers[1]

    -- start lattice
    local sequencer = lattice:new{
        ppqn = 96
    }

    sequencer:new_pattern({
        action = function(t)
            sequencers[1]:update()
            redraw()
        end,
        division = 1 / 8
    })
    clock.run(function()
        clock.sleep(0.1)
        sequencer:hard_restart()
    end)
    clock.run(function()
        while true do
            clock.sleep(1 / 15)
            redraw()
        end
    end)
    -- sequencers[1]:update()
end

function enc(k, d)
    if k == 3 then
        sequencers[1].note_offset = sequencers[1].note_offset + d
    elseif k == 1 then
        sequencers[1]:set_direction_delta(d)
    end
end

function key(k, z)
    if z == 1 and k == 3 then
        local row = 2
        local col = 3
        local step_index = col + math.floor((sequencers[1].step - 1) / 16) * 16
        sequencers[1]:toggle_pos(step_index, row)
    elseif z == 1 and k == 2 then
        sequencers[1]:update()

    end
end

function redraw()
    screen.clear()
    -- draw the grid
    local grid_square_size = 7
    local visual = grid_:get_visual()
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

    screen.move(5, 5)
    screen.text(sequencers[1].direction)

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
