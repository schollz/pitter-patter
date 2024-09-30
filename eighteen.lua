-- lightsout v0.0.0
--
--
-- llllllll.co/t/lightsout
--
--
--
--    ▼ instructions below ▼
GridLib = include("eighteen/lib/ggrid")
Sequence = include("eighteen/lib/sequence")
lattice = require("lattice")

engine.name = "PolyPerc"

beat_current = 0
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
    step_time_last = 0
    step_time_before_last = 0
    sequencer:new_pattern({
        action = function(t)
            sequencers[1]:update()
            -- print("step: ", sequencers[1].step)
            step_time_before_last = step_time_last
            step_time_last = clock.get_beats()
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

end

function key(k, z)
    if z == 1 then
        step_time_between = step_time_last - step_time_before_last
        step_time_since = clock.get_beats() - step_time_last
        -- determine if closer to the last step or the next step
        print(step_time_before_last, step_time_last, step_time_since, step_time_between / 2, sequencers[1].step,
            sequencers[1].step_next)
        if step_time_since < step_time_between / 2 then
            print("beat previous: ", sequencers[1].step)
            sequencers[1]:toggle(sequencers[1].step, 3)
        else
            sequencers[1]:toggle(sequencers[1].step_next, 3)
        end
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
