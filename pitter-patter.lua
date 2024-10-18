-- pitter-patter v1.0.1
--
--
-- llllllll.co/t/pitter-patter
--
--
--
--    ▼ instructions below ▼
--
-- E1: change sequence
-- E2: change direction
-- E3: change note pool
-- K1+E1: change instrument
-- K1+E2: change direction
-- K1+E3: change velocity profile
-- K1: shift
-- K2: mute
-- K3: play/stop
-- K1+K2: clear current view
-- K1+K3: clear all
--

GridLib=include("pitter-patter/lib/ggrid")
Sequence=include("pitter-patter/lib/sequence")
lattice=require("lattice")
nb=include("lib/nb/lib/nb")
if not string.find(package.cpath,"/home/we/dust/code/pitter-patter/lib/") then
  package.cpath=package.cpath..";/home/we/dust/code/pitter-patter/lib/?.so"
end
json=require("cjson")
local musicutil=require("musicutil")

engine.name="MxSamplez"

sequencers={}
last_cpu=0

debounce_show_grid_time=30
debounce_show_grid=debounce_show_grid_time
local divisions={4,2,1,1/2,1/4,1/8,1/16,1/32}
local divisions_strings={"4 beats","2 beats","1 beat","1/2","1/4","1/8","1/16","1/32"}

function init()
  nb:init()

  for i=1,4 do sequencers[i]=Sequence:new({id=i,divisions=divisions,divisions_strings=divisions_strings}) end
params_main()
  print("sequencer 3 id: ",sequencers[3].id)
  grid_=GridLib:new()

  -- bang params
  params:bang()

  -- start lattice
  local sequencer=lattice:new{ppqn=96}

  for _,division in ipairs(divisions) do
    local beat=1
    sequencer:new_sprocket({
      action=function(t)
        if params:get("main_play")==1 then
          for i=1,4 do sequencers[i]:update(division,beat) end
beat=beat+1
        end
      end,
      division=division
    })
  end


  -- cpu tracker
  cpu_tracker=poll.set("cpu_avg") -- create a poll to detect pitch of the left input
  cpu_tracker.callback=function(x)
    if x>0 then -- poll returns `-1` without a signal present
      last_cpu=x
    end
  end
  cpu_tracker:start()

  clock.run(function()
    clock.sleep(0.1)
    sequencer:hard_restart()
  end)
  clock.run(function()
    while true do
      clock.sleep(1/15)
      redraw()
    end
  end)
end

local is_shift=false

function enc(k,d)
  if k==1 then
    if is_shift then
      -- change instrument
      sequencers[params:get("main_sequence")]:delta_param("instrument",d)
    else
      -- change sequence
      params:delta("main_sequence",d)
    end
  elseif k==2 then
    if is_shift then
      -- change division
      sequencers[params:get("main_sequence")]:delta_param("division",d)
    elseif d==1 or d==-1 then
      if params:get("main_play")==1 then
        sequencers[params:get("main_sequence")]:delta_param("direction",d)
      else
        sequencers[params:get("main_sequence")]:set_param("direction",d<0 and 1 or 4)
        sequencers[params:get("main_sequence")]:update(divisions[sequencers[params:get("main_sequence")]:get_param(
        "division")])
      end
    end
  elseif k==3 then
    if is_shift then
      -- change velocity profile
      sequencers[params:get("main_sequence")]:delta_param("velocity",d)
    else
      -- change note offset
      sequencers[params:get("main_sequence")].note_offset=sequencers[params:get("main_sequence")].note_offset+d
    end
  end
  debounce_show_grid=debounce_show_grid_time
end

function key(k,z)
  if k==1 then
    is_shift=z==1
  elseif z==1 and k==2 then
    if not is_shift then
      -- toggle mute for current sequence
      sequencers[params:get("main_sequence")]:set_param("mute",sequencers[params:get("main_sequence")]:get_param("mute")==0 and 1 or 0)
    else
      sequencers[params:get("main_sequence")]:clear_visible()
    end
  elseif z==1 and k==3 then
    if is_shift then
      sequencers[params:get("main_sequence")]:clear()
    else
      params:set("main_play",params:get("main_play")==0 and 1 or 0)
    end
  end
end

function redraw()
  screen.clear()
  if is_shift then debounce_show_grid=debounce_show_grid_time end
  if debounce_show_grid>debounce_show_grid_time/10*2 then debounce_show_grid=debounce_show_grid-1 end
  -- draw the grid
  local grid_square_size=5
  local grid_x=22
  local grid_y=6
  local visual=grid_:get_visual()
  for i,v in ipairs(visual) do
    for j,u in ipairs(v) do
      -- draw a box
      screen.level(util.round(4*debounce_show_grid/debounce_show_grid_time))
      screen.line_width(1)
      screen.rect((j*grid_square_size)+grid_x,i*grid_square_size-grid_square_size/2+grid_y,
      grid_square_size,grid_square_size)
      screen.stroke()
      if u>0 then
        screen.rect((j*grid_square_size)+grid_x+1,i*grid_square_size-grid_square_size/2+2+grid_y,
        grid_square_size-3,grid_square_size-3)
        screen.level(util.round(u*debounce_show_grid/debounce_show_grid_time))
        screen.fill()
      end
    end
  end
  screen.level(util.round(util.linlin(0,100,0,15,last_cpu)))
  screen.move(110,5+9)
  screen.text(string.format("%2.0f",last_cpu).."%")
  screen.level(10)
  screen.move(0,5)
  -- show the current sequence
  screen.text("sequence "..params:get("main_sequence"))
  if sequencers[params:get("main_sequence")]:get_param("mute")==1 then
    screen.move(0,5+9)
    screen.level(5)
    screen.text("muted")
  end
  local instrument_string=sequencers[params:get("main_sequence")]:get_param_str("instrument")
  -- get length of string
  screen.move(128,5)
  screen.text_right(instrument_string)
  screen.move(0,64-2)
  screen.text(params:string("main_play")..sequencers[params:get("main_sequence")]:get_param_str("direction").." "..
  sequencers[params:get("main_sequence")]:get_param_str("division"))

  local note_string=
  musicutil.note_num_to_name(sequencers[params:get("main_sequence")]:get_note_from_index(1),true).." to "..
  musicutil.note_num_to_name(sequencers[params:get("main_sequence")]:get_note_from_index(grid_.width-1),true)
  screen.move(128,64-1)
  screen.text_right(note_string)

  -- draw velocity profile
  local velocity_spacing=4
  local velocity_profile=sequencers[params:get("main_sequence")]:get_velocity_profile()
  for i,v in ipairs(velocity_profile) do
    screen.level(v==1 and 10 or 2)
    screen.circle(128-(#velocity_profile+0.5)*1.5*velocity_spacing+i*velocity_spacing*1.5+1,64-11,
    velocity_spacing/2)
    screen.fill()
  end

  screen.update()
end

function rerun()
  norns.script.load(norns.state.script)
end

function cleanup()
end

function table.reverse(t)
  local len=#t
  for i=len-1,1,-1 do t[len]=table.remove(t,i) end
end

function params_main()
  midi_connections={}
  local midi_devices={"any","none"}
  local midi_channels={"all"}
  for i=1,16 do table.insert(midi_channels,i) end
for j,dev in pairs(midi.devices) do
    if dev.port~=nil then
      print("midi device: ",dev.name)
      table.insert(midi_devices,dev.name)
    end
  end

  local params_menu={
    {
      id="sequence",
      name="sequence select",
      min=1,
      max=4,
      exp=false,
      div=1,
      default=1,
      formatter=function(param)
        return string.format("%d",param:get())
      end,
      action=function(v)
        print("sequence",v)
        grid_.sequencer=sequencers[v]
      end
      },{
      id="play",
      name="play",
      min=0,
      max=1,
      exp=false,
      div=1,
      default=1,
      formatter=function(param)
        return param:get()==0 and "" or "play "
      end
      },{
      id="midi_input",
      name="midi input device",
      min=1,
      max=#midi_devices,
      exp=false,
      div=1,
      default=1,
      formatter=function(param)
        return midi_devices[param:get()]
      end
      },{
      id="midi_channel",
      name="midi channel",
      min=1,
      max=17,
      exp=false,
      div=1,
      default=1,
      formatter=function(param)
        return midi_channels[param:get()]
      end
    }}
    for _,pram in ipairs(params_menu) do
      params:add{
        type="control",
        id="main_"..pram.id,
        name=pram.name,
        controlspec=controlspec.new(pram.min,pram.max,pram.exp and "exp" or "lin",pram.div,pram.default,
        pram.unit or "",pram.div/(pram.max-pram.min)),
        formatter=pram.formatter
      }
      if pram.hide then params:hide(pram.id) end
      if pram.action then params:set_action("main_"..pram.id,pram.action) end
      -- params:set_action(pram.id, function(v)
      --     engine.main_set(pram.id, pram.fn ~= nil and pram.fn(v) or v)
      -- end)
    end
    for j,dev in pairs(midi.devices) do
      if dev.port~=nil then
        local conn=midi.connect(dev.port)
        print("connecting to midi device: ",dev.name)
        conn.event=function(data)
          local d=midi.to_msg(data)
          -- check if clock
          if d.type=="clock" then
            -- print("clock")
            return
          end
          -- tab.print(d)
          -- print(dev.name,dev.ch,midi_devices[params:get("main_midi_input")],params:get("main_midi_channel"))
          -- visualize ccs
          -- if d.cc~=nil and d.val~=nil then
          --   if d.cc>0 and d.val>0 then
          --     print("cc",d.cc,d.val)
          --   end
          -- end
          if params:get("main_midi_input")==2 then do return end end
if dev.name~=midi_devices[params:get("main_midi_input")] and params:get("main_midi_input")>2 then
            do return end
          end
          if d.ch~=nil and d.ch~=midi_channels[params:get("main_midi_channel")] and params:get("main_midi_channel")>
            2 then do return end end
if d.type=="note_on" then
              -- print("note_on", dev.name, d.note, d.vel)
              sequencers[params:get("main_sequence")]:toggle_from_note(d.note)
            elseif d.type=="note_off" then
              print("note_off",dev.name,d.note)
            end
          end
        end
      end

      params.action_write=function(filename,name)
        print("[params.action_write]",filename,name)
        local data={}
        for i=1,4 do data["sequence_"..i]=sequencers[i]:marshal() end
filename=filename..".json"
        local file=io.open(filename,"w+")
        io.output(file)
        io.write(json.encode(data))
        io.close(file)
      end

      params.action_read=function(filename,silent)
        print("[params.action_read]",filename,silent)
        -- load all the patterns
        filename=filename..".json"
        if not util.file_exists(filename) then do return end end
local f=io.open(filename,"rb")
        local content=f:read("*all")
        f:close()
        if content==nil then do return end end
local data=json.decode(content)
        if data==nil then do return end end
        for i=1,4 do sequencers[i]:unmarshal(data["sequence_"..i]) end
      end
    end

    
