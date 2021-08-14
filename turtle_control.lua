local MODEM_SIDE='right'
local PTC='test'
local HostName='controller'


function get_turtles_pos(ids, bx,by,bz)
    bx=bx or 1
    by=by or 1
    bz=bz or 1
    local id, mes
    local command={'gps','locate'}
    local args={}
    local rpc={command=command, args=args}
    local pos_data={}
    for i, tid in pairs(ids) do    
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

function get_turtles_FuelLevel(ids)
    local fuel_data={}
    for i,tid in pairs(ids) do
        local rpc={
            command={'turtle', 'getFuelLevel'},
            args={}
        }
        local fuel=rpc_call(tid, rpc)
        fuel_data[tid]=fuel
    end
    return fuel_data
end

function check_turtles_FuelLevel(ids, low_line)
    -- should make sure that turtle can go back to refuel position
    local fuel_data=get_turtles_FuelLevel(ids)
    local need_refuel=false
    for k,v in pairs(fuel_data) do
        print(k, textutils.serialise(v))
        if v[1]<low_line then
            return false
        end
    end
    return true
end
function check_turtles_each_FuelLevel(ids, low_lines)
    local fuel_data=get_turtles_FuelLevel(ids)
    local need_refuel=false
    for k,v in pairs(fuel_data) do
        print(k, textutils.serialise(v))
        if v[1]<low_lines[k] then
            return false
        end
    end
    return true
end


function get_turtle_inventory(id,detail)
    detail=detail or false
    local rpc={
        command={'get_inventory_list'},
        args={detail}
    }
    local id,res=rpc_call(id, rpc)
    if res~=nil then res=res[1] end
    return res
end
function count_turtle_item(id, item)
    local items=get_turtle_inventory(id)
    local count=0
    for k,v in pairs(items) do
        if v~=nil then
            if v.name==item then
                count=count+v.count
            end
        end
    end
    return count
end
function check_turtles_item(ids, items, count)
    count=count or 1
    local res, ic
    res=true
    fail_ids={}
    for i,id in pairs(ids) do
        ic=count_turtle_item(id, items[i])
        if ic<count then
            res=false
            table.insert(fail_ids, id)
        end
    end
    return res, fail_ids
end

function get_turtles_y(ids,by)
    local pos=get_turtles_pos(ids, nil,by,nil)
    local ys={}
    for k,v in pairs(by) do
        ys[k]=pos[k][2]
    end
    return ys
end

function get_turtles_y_diff(ids, heights)
    local res=get_turtles_y(ids)
    for k,v in pairs(res) do
        res[k]=heights[k]-res[k]
    end
    return res
end

function get_mat_list(bp)
    local res={}
    for i=1, bp.tcount do
        res[i]=bp.mat_map[bp.px+i-1][bp.pz]
    end
    for i=1, bp.tcount do 
        res[i]=bp.mat_dict[res[i]]
    end
    return res
end


function refuel_turtles()
    -- hard shit
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

function rpc_call(tid, rpc, protocol)
    protocol=protocol or PTC
    rednet.send(tid, rpc, protocol)
    local id,mes=recv(tid)
    return id,mes
end
function rpc_all(ids, rpc, protocol, reverse)
    local res_list={}
    local res_ids={}
    reverse=reverse or false
    if not reverse then
        for i, tid in pairs(ids) do
            res_ids[tid],res_list[tid]=rpc_call(tid, rpc, protocol)
        end
    else
        local tid
        for i=#ids, 1, -1 do
            tid=ids[i]
            res_ids[tid],res_list[tid]=rpc_call(tid, rpc, protocol)
        end
    return res_ids,res_list
end

function set_blueprint(bp)
    _G.bp=bp
    _G.bx,_G.by,_G.bz=bp.base_x,bp.base_y,bp.base_z
end

function load_json(path)
    local fp = fs.open(path, 'r')
    local bp = textutils.unserialiseJSON(fp.readAll())
    return bp
end

function init_blueprint(bp, x,y,z)
    --_G.bp=bp
    
    bp.mat_map=bp['material_data'][1] -- y,x,z -> x,z
    bp.mat_dict=bp['material_dict']
    -- real block_id = bp.material_dict[mat_map[y][x][z]]
    bp.y_map=bp['height_data'][1]
    bp.state='initiated' -- the work currently doing
    bp.tids={} -- turtle ids
    bp.tcount=1 -- the turtle count
    bp.tys={}

    -- the world coordinate
    bp.bx=x
    bp.by=y
    bp.bz=z
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
    local res
    if bp.state=='initiated' then
        bp.state='move-forward-check'

    -- forward
    elseif bp.state=='move-forward-check' then
        while not check_turtles_FuelLevel(bp.tids, 1) do
            print('move-forward-check failed')
            print('turtle need refuel')
            sleep(20)
        end
        bp.state='move-forward'
    elseif bp.state=='move-forward' then
        res=move_all(bp.tids, 'forward')
        if res==false then return false end

        bp.state='move-height-check'

    -- z
    elseif bp.state=='move-z-check' then
        while not check_turtles_FuelLevel(bp.tids, bp.tcount) do
            print('move-z-check failed')
            print('turtle need refuel')
            sleep(20)
        end
        bp.state='move-z'
    elseif bp.state=='move-z' then
        local turn_dir
        if bp.zdir then
            turn_dir='turnRight'
        else
            turn_dir='turnLeft'
        end
        res=move_all(bp.tids, turn_dir)
        if not res then return false end
        res=move_all(bp.tids, 'forward', bp.tcount)
        if not res then return false end
        res=move_all(bp.tids, turn_dir)
        if not res then return false end

        if bp.zdir then bp.zdir=false else bp.zdir=true end
        bp.state='move-height-check'

    -- y
    elseif bp.state=='move-y-check' then
        bp.y_diff=get_turtles_y_diff(bp.tids, bp.y_map)
        while not check_turtles_each_FuelLevel(bp.tids, bp.y_diff) do
            print('move-z-check failed')
            print('turtle need refuel')
            sleep(20)
        end
        bp.state='move-y'

    elseif bp.state=='move-y' then
        local res=move_y(bp.tids, bp.y_map)
        if res==false then return false end
        bp.state='place-check'

    elseif bp.state=='place-check'
        local mat_list=get_mat_list(bp)
        while not check_turtles_item(bp.tids, mat_list, 1) do
            print('place-check failed')
            print('turtle need mat')
            sleep(20)
        end
        bp.state='place'

    elseif bp.state=='place' then

        bp.state='line-done'
    elseif bp.state=='line-done' then
        -- determine move-forward or move-z

        

    else
        error('unexpected bp state')
    end
    return true
end

function dump_json(path, obj)
    local fp=fs.open(path,'w')
    fp.write(textutils.serialiseJSON(obj))
    fp.close()
    return true
end

function build_line(bp)
    if bp==nil then
        bp=_G.bp
    end


end
function buildline_check(bp)
    if bp==nil then bp=_G.bp end

end

function move_all(ids, direction, dist)
    direction=direction or 'forward'
    dist=dist or 1
    local rpc={
        command={'turtle', direction}
    }

    for i=1, dist do
       rpc_all(ids, rpc) 
    end

end

function move(id, direction, dist)do
    direction=direction or 'forward'
    dist=dist or 1
    local rpc={
        command={'turtle', direction}
    }
    local rid, mes
    for i=1, dist do
        rid,mes=rpc_call(id,rpc)
        if rid==nil then
            return false
        end
    end
    return true
end

function move_y(ids, ys)
    -- ys is each dist
    for i, id in pairs(ids) do
        if ys[i]>0 then
            move(id, 'Up', ys[i])
        elseif y[i]<0 then
            move(id, 'Down', math.abs(ys[i]))
        end
    end
    return true
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