-- eighteen v0.0.1
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
playing = true
function init()
    params_main()
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
            if playing then 
            sequencers[1]:update()
        end
        end,
        division = 1 / 16
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
    elseif k==2 and math.abs(d)<2 then 
            params:set("sequence1_direction",d>0 and 1 or 2)
            sequencers[1]:update()
    end
end

function key(k, z)
    if z == 1 and k == 3 then
        playing = not playing
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
    screen.text(sequencers[1]:get_param("direction"))

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

function params_main()
    local params_menu = {{
        id = "sequence",
        name = "sequence",
        min = 1,
        max = 4,
        exp = false,
        div = 1,
        default = 1,
        formatter = function(param)
            return string.format("%d", param:get())
        end
    }, {
        id = "record",
        name = "record",
        min = 0,
        max = 1,
        exp = false,
        div = 1,
        default = 1,
        formatter = function(param)
            return param:get() == 0 and "off" or "recording"
        end
    }, {
        id = "play",
        name = "play",
        min = 0,
        max = 1,
        exp = false,
        div = 1,
        default = 1,
        formatter = function(param)
            return param:get() == 0 and "off" or "playing"
        end
    }}
    for _, pram in ipairs(params_menu) do
        params:add{
            type = "control",
            id = "main" .. pram.id,
            name = pram.name,
            controlspec = controlspec.new(pram.min, pram.max, pram.exp and "exp" or "lin", pram.div, pram.default,
                pram.unit or "", pram.div / (pram.max - pram.min)),
            formatter = pram.formatter
        }
        if pram.hide then
            params:hide(pram.id)
        end
        -- params:set_action(pram.id, function(v)
        --     engine.main_set(pram.id, pram.fn ~= nil and pram.fn(v) or v)
        -- end)
    end
end

function params_action()
    params.action_write = function(filename, name)
        print("[params.action_write]", filename, name)
        local data = {
            -- pattern_current = pattern_current,
        }
        filename = filename .. ".json"
        local file = io.open(filename, "w+")
        io.output(file)
        io.write(json.encode(data))
        io.close(file)
    end

    params.action_read = function(filename, silent)
        print("[params.action_read]", filename, silent)
        -- load all the patterns
        filename = filename .. ".json"
        if not util.file_exists(filename) then
            do
                return
            end
        end
        local f = io.open(filename, "rb")
        local content = f:read("*all")
        f:close()
        if content == nil then
            do
                return
            end
        end
        local data = json.decode(content)
        if data == nil then
            do
                return
            end
        end
        -- pattern_current = data.pattern_current
        -- pattern_store = data.pattern_store
        -- bass_pattern_current = data.bass_pattern_current
        -- bass_pattern_store = data.bass_pattern_store
    end
end
