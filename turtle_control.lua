local MODEM_SIDE='right'
local PTC='test'
local HostName='controller'

rednet.open(MODEM_SIDE)
if PTC ~= nil then
    rednet.host(PTC, HostName)
end


local turtles=settings.get('turtles') or {}
local turtle_length=settings.get('turtle_length') or 0
local bx, by, bz=0,0,0
local bp={}

print(textutils.serialise(turtles))

function register_turtle(id, pos)
    --top is 0
    print('Register turtle', id, 'at:', pos)
    if pos==nil then return end
    turtles[pos]=id
    settings.set('turtles', turtles)
    --print(type(pos))
    --print(type(turtle_length))
    if pos >= turtle_length then 
        turtle_length=pos 
    end
    settings.set('turtle_length', turtle_length)
    settings.save()
end
function listen_turtle_register()
    local id, mes
    while true do
        id, mes = rednet.receive(PTC)
        print(id, mes)
        --print(textutils.serialise(mes))
        print(textutils.unserialise(mes))
        if mes=='stop' then
            settings.save()
            break
        end
        mes=textutils.unserialise(mes)
        mes=tonumber(mes)
        register_turtle(id, mes)
        
    end    
end

function get_turtles_pos()
    local id, mes
    local command={'gps','locate'}
    local args={}
    local rpc={command=command, args=args}
    local pos_data={}
    for i, tid in pairs(turtles) do    
        rednet.send(tid, rpc, PTC)
        id, mes=recv(tid)
        -- adjust to local position
        mes[1]=mes[1]-bx+1
        mes[2]=mes[2]-by+1
        mes[3]=mes[3]-bz+1
        pos_data[tid]=mes
        print(mes)
        print(textutils.serialise(mes))
    end
    return pos_data
end

function get_turtles_FuelLevel()
    local fuel_data={}
    for i,tid in pairs(turtles) do
        local rpc={
            command={'turtle', 'getFuelLevel'},
            args={}
        }
        local fuel=rpc_call(tid, rpc)
        fuel_data[tid]=fuel
        
    end
    return fuel_data
end

function check_turtles_FuelLevel(low_line)
    -- should make sure that turtle can go back to refuel position
    local fuel_data=get_turtles_FuelLevel()
    local need_refuel=false
    for k,v in pairs(fuel_data) do
        print(k, textutils.serialise(v))
        if v[1]<low_line then
            return true
        end
    end
    return false
end

function refuel_turtles()
    local rpc={command={'refuel'}, args={}}
    for i,tid in pairs(turtles) do
        local res=rpc_call(tid, rpc)
        
    end
end   


function create_arr(len, val)
    local m={}
    val=val or 0
    for i=1, len do
        m[i]=val
    end
    return m
end

function create_matrix(r, c, val)
    val=val or 0
    local m = {}
    for i=1, r do
        m[i]={}
        for j=1, c do
            m[i][j]=val
        end
    end
    return m
end

function rpc_call(tid, rpc, Protocol)
    rednet.send(tid, rpc, Protocol)
    local id,mes=recv(tid)
    return mes
end
function rpc_all(ids, rpc, reverse, protocol)
    local res_list={}
    reverse=reverse or false
    if not reverse then
    for i, tid in pairs(ids) do
        res_list[tid]=rpc_call(tid, rpc, protocol)
    end
    else
    local tid
    for i=#ids, 1, -1 do
        tid=ids[i]
        res_list[tid]=rpc_call(tid, rpc, protocol)
    end
    sleep(0.1)
    return res_list
end

function set_blueprint(bp)
    _G.bp=bp
    _G.bx,_G.by,_G.bz=bp.base_x,bp.base_y,bp.base_z
end

function load_blueprint(path)
    local fp = fs.open(path, 'r')
    local bp = textutils.unserialiseJSON(fp.readAll())
    set_blueprint(bp)
end

function init_blueprint(bp, x,y,z)
    --_G.bp=bp
    
    bp.mat_map=bp['material_data'][1] -- y,x,z -> x,z
    bp.height_map=bp['height_data'][1]
    bp.state='line-done' -- the work currently doing
    bp.tcount=1 -- the turtle count
    -- check-supply
    -- move-forward
    -- move-height
    -- placedown
    -- line-done (calculate new p-xyz, determine zdir...)
    -- back to check-supply...

    -- all-done

    -- the world coordinate
    bp.base_x=x
    bp.base_y=y
    bp.base_z=z
    --initial processing position
    bp.px=1
    bp.py=1
    bp.pz=1
    -- progress is +x +z direction
    -- turtle array should be at z+1
    -- move forward then adjust to the correct height,
    -- then placeblock below

    -- process args
    bp.zdir=true -- true if positive z

    
end

function process_bp(bp)

end

function dump(path, obj)
    local fp=fs.open(path,'w')
    fp.write(textutils.serialiseJSON(obj))
    fp.close()
    return true
end

function build_line(bp)
    if bp==nil then
        bp=_G.bp
    end
    -- check fuel to height
    -- check fuel to forward
    -- check material supply
    -- all good then
    -- move to height
    -- move forward
    -- place block below

end
function buildline_check(bp)
    if bp==nil then bp=_G.bp end

end

function move_all(ids,x,y,z)
    -- move all together
    -- use this instead of [for-loop move] to prevent blocking
    -- x,y,z are diff.
    -- return true if success
    -- this assume fuel is enough
    x=x or 0
    y=y or 0
    z=z or 0
    local nx,ny,nz=(x<0),(y<0),(z<0)
    local rpc={
        command={'turtle', ''}
    }    
    for i=1, x do
        if nx then -- go north(facing)
            rpc.command[2]='forward'
        else
            rpc.command[2]='back'
        end
        rpc_all(ids, rpc, true)--reverse call
        sleep(1)
    end
    for i=1, y do
        if ny then -- go down
            rpc.command[2]='down'
        else
            rpc.command[2]='up'
        end
        rpc_all(ids, rpc, true)
        sleep(1)
    end
    for i=1, z do
        if nz then -- go west
            rpc.command[2]='left'
        else
            rpc.command[2]='right'
        end
        rpc_all(ids, rpc, true)
        sleep(1)
    end
end

function move(id, x,y,z)do
    x=x or 0
    y=y or 0
    z=z or 0
    local nx,ny,nz=(x<0),(y<0),(z<0)
    local rpc={
        command={'turtle', ''}
    }    
    for i=1, x do
        if nx then -- go north(facing)
            rpc.command[2]='forward'
        else
            rpc.command[2]='back'
        end
        rpc_call(id, rpc)
        sleep(1)
    end
    for i=1, y do
        if ny then -- go down
            rpc.command[2]='down'
        else
            rpc.command[2]='up'
        end
        rpc_call(id, rpc)
        sleep(1)
    end
    for i=1, z do
        if nz then -- go west
            rpc.command[2]='left'
        else
            rpc.command[2]='right'
        end
        rpc_call(id, rpc)
        sleep(1)
    end
end

function move_all_to_xz(ids,x,z)
    -- this take absoulte position
    -- move y then z then x 
    -- move large to small id to prevent collision
    local pos_data=get_turtles_pos()
    local dx=x-pos_data[1][1]
    local dz=z-pos_data[1][3]
    return move_all(ids,dx, 0, dz)
end

function move_to_y(id, y)
    -- in progress, height will be different
    -- but use move_all_to_y will be more efficient
    local pos_data=get_turtles_pos()
    local dy=y-pos_data[1][2]
    return move(id, 0,y,0)
end

function move_all_to_y(ids, y)
    local dy
    local pos_data=get_turtles_pos()
    local res={}
    for i, tid in pairs(ids) do
        dy=y-pos_data[tid]
        res[tid]=move(tid, 0,dy,0)
    end
    return res
end

function recv(tid)
    local id, mes
    while id==nil or id~=tid do
        id, mes=rednet.receive()
    end
    return id, mes
end

function refuel_all(ids)
    --move all to the max_height+1
    --go back to 0,0,length+1
    move_all_to_y(ids, bp)
end

--listen_turtle_register()
local res = get_turtles_pos()
print(textutils.serialise(res))
--print(textutils.unserialise(res))
res = get_turtles_FuelLevel()
print(textutils.serialise(res))
refuel_turtles()
rednet.unhost(PTC)
local need_refuel=check_turtles_FuelLevel(200)
print(need_refuel)