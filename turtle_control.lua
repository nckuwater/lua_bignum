local MODEM_SIDE='back'
local PTC='test'
local RECV_TIMEOUT=2
--local HostName='controller'
rednet.open(MODEM_SIDE)

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
    local id,mes=recv(tid, protocol, RECV_TIMEOUT)
    return id,mes
end
function rpc_all(ids, rpc, protocol, reverse)
    local res_list={}
    local res_ids={}
    reverse=reverse or false
    local wraps={}
    if not reverse then
        for i, tid in pairs(ids) do
            res_ids[tid],res_list[tid]=rpc_call(tid, rpc, protocol)
        end
    else
        local tid
        for i=#ids, 1, -1 do
            tid=ids[i]
            wraps.insert(function()
                sleep(i)
                res_ids[tid],res_list[tid]=rpc_call(tid, rpc, protocol)
            end
            )
        end
    end
    parallel.waitForAll(unpack(wraps))
    return res_ids,res_list
end

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
        id, mes=rpc_call(tid,rpc)
        -- adjust to local position
        mes[1]=mes[1]-bx+1
        mes[2]=mes[2]-by+1
        mes[3]=mes[3]-bz+1
        pos_data[i]=mes
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
        local id,fuel=rpc_call(tid, rpc)
        fuel_data[i]=fuel
    end
    print(textutils.serialise(fuel_data))
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

function check_forward_collide(ids)
    local rpc={
        command={'turtle', 'inspect'}
    }
    local ids, mes=rpc_all(ids, rpc)
    for i,insp in pairs(mes) do
        local has_block=insp[1]
        local data=insp[2]
        if has_block then
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
function get_turtles_inventory(ids, detail)
    local res = {}
    for i, id in pairs(ids) do
        res[i] = get_turtle_inventory(id, detail)
    end
    return res
end
function get_turtle_inventory_counts(id,detail)
    -- convert to items format [mat:count]
    detail=detail or false
    local rpc={
        command={'get_inventory_list'},
        args={detail}
    }
    local id,res=rpc_call(id, rpc)
    local items={}
    if res~=nil then 
        res=res[1] 
        for i, item in pairs(res) do
            if items[item.name]==nil then
                items[item.name] = item.count
            else
                items[item.name] = items[item.name] + item.count
            end
        end
    end
    --return res
    return items
end

function get_turtles_inventory_counts(ids, detail)
    -- convert to items format [mat:count]
    local res = {}
    for i, id in pairs(ids) do
        res[i] = get_turtle_inventory_counts(id, detail)
    end
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
    fails={}
    for i,id in pairs(ids) do
        ic=count_turtle_item(id, items[i])
        if ic<count then
            res=false
            table.insert(fails, {id, items[i]})
        end
    end
    return res, fails
end
function send_place_check_info(fails)
    local rpc={
        command={'print'},
        args={}
    }
    for i, fail in pairs(fails) do
        rpc.args[1]=fail[2]
        rpc_call(fail[1], rpc)
    end
end
function print_to(id, text)
    local rpc={
        command={'print'},
        args={text}
    }
    local id,mes=rpc_call(id, rpc)
    return id,mes
end

function get_turtles_y(ids,by)
    local pos=get_turtles_pos(ids, nil,by,nil)
    local ys={}
    print('pos')
    print(textutils.serialise(pos))
    for k,v in pairs(pos) do
        ys[k]=pos[k][2]
    end
    return ys
end

function get_turtles_y_diff(ids, by, heights)
    local res=get_turtles_y(ids, by)
    print('tury')
    print(textutils.serialise(res))
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
function get_y_list(bp)
    local res={}
    for i=1, bp.tcount do
        res[i]=bp.y_map[bp.px+i-1][bp.pz]
    end
    return res
end
function send_total_mat_need(bp)
    local tn = bp['turtle_mat_need']
    local rpc = {
        command={'print'},
        args={}
    }
    local text
    for i, tid in pairs(bp['tids']) do
        text=''
        for item,count in pairs(tn[i]) do
            text = text..item..' '..tostring(count)..'\n'
        end
        rpc.args[1] = text
        rpc_call(tid, rpc)
    end
    return true
end

function check_material_list(rec, items)
    -- rec is recipe(required materials)
    -- items is current obtained
    local rec_remain = {}
    for k,v in pairs(rec) do
        if items[k] ~= nil then
            if rec[k] > items[k] then
                rec_remain[k] = rec[k]-items[k]
            end
        else
            rec_remain[k] = rec[k]
        end
    end
    return rec_remain
end

function get_turtle_chunk_mat(bp, chunk)
    local sup_index = bp['supply_index']
    local sup_plan = bp['supply_plan']
    if chunk==nil then
        -- calc if not specified
        chunk = math.ceil(bp.px / bp.tcount)
    end
    -- find the next supply chunk
    local sup_chunk_index = nil
    local sup_chunk = 1
    for k,v in pairs(sup_index) do
        if v<=chunk and v>=sup_chunk then
            sup_chunk = v
            sup_chunk_index = k
        end
    end
    print('sup ind', bp.px, chunk)
    print(textutils.serialise(sup_index))
    if sup_chunk_index==nil then return nil end -- no need sup
    return sup_plan[sup_chunk_index]
end
function get_turtle_chunk_missing(bp, chunk)
    local chunk_sup = get_turtle_chunk_mat(bp, chunk)
    local turtle_sup = get_turtles_inventory_counts(bp.tids)
    local missing_sup = {}
    print(textutils.serialise(chunk_sup))
    for i, tid in pairs(bp.tids) do
        missing_sup[i] = check_material_list(chunk_sup[i], turtle_sup[i])
    end
    return missing_sup
end
function send_chunk_mat_missing(bp, chunk)
    -- send info about item required for each turtle
    local missing_sup = get_turtle_chunk_missing(bp, chunk)
    local tid
    for i, ms in pairs(missing_sup) do
        if ms~=nil then
            tid = bp.tids[i]
            print_to(tid, textutils.serialise(ms))
        end
    end
end


function refuel_turtles()
    -- hard shit
    local rpc={command={'refuel'}, args={}}
    for i,tid in pairs(turtles) do
        local res=rpc_call(tid, rpc)
        
    end
end


function load_json(path)
    local fp = fs.open(path, 'r')
    local bp = textutils.unserialiseJSON(fp.readAll())
    return bp
end

function load_blueprint(bp)
    -- rename some member

    bp.mat_map=bp['material_data'] -- y,x,z -> x,z
    bp.mat_dict=bp['palette']

    -- real block_id = bp.material_dict[mat_map[y][x][z]]

    bp.y_map=bp['height_data']
    return bp
end
function unload_blueprint(bp)
    bp.mat_map=nil
    bp.mat_dict=nil
    bp.y_map=nil
    return bp
end

function init_blueprint(bp, x,y,z)
    bp.state='initiated' -- the work currently doing
    bp.tids={} -- turtle ids
    bp.tcount=1 -- the turtle count

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

    return bp
end

function process_bp(bp)
    local res
    if bp.state=='initiated' then
        bp.state='move-y-check'

    elseif bp.state=='forward-collide-check' then
        if check_forward_collide(bp.tids) then
            bp.state='move-forward-check'
        else
            bp.state='forward-collide-adjust'
        end

    elseif bp.state=='forward-collide-adjust' then
        move_all(bp.tids, 'up')
        --sleep(1)
        bp.state='forward-collide-check'
        save(bp)
    -- forward
    elseif bp.state=='move-forward-check' then
        while not check_turtles_FuelLevel(bp.tids, 1) do
            print('move-forward-check failed')
            print('turtle need refuel')
            sleep(3)
        end
        bp.state='move-forward'
    elseif bp.state=='move-forward' then
        res=move_all(bp.tids, 'forward')
        if res==false then return false end

        
        bp.state='move-y-check'
        save(bp)
    -- z
    elseif bp.state=='move-x-check' then
        while not check_turtles_FuelLevel(bp.tids, bp.tcount) do
            print('move-x-check failed')
            print('turtle need refuel')
            sleep(3)
        end
        bp.state='move-x'
    elseif bp.state=='move-x' then
        local turn_dir
        if bp.zdir then
            turn_dir='turnLeft'
        else
            turn_dir='turnRight'
        end
        res=move_all(bp.tids, 'forward')
        res=move_all_safe(bp.tids, turn_dir)
        if not res then return false end
        res=move_all_safe(bp.tids, 'forward', bp.tcount)
        if not res then return false end
        res=move_all_safe(bp.tids, turn_dir)
        if not res then return false end

        -- reverse bp.zdir
        if bp.zdir then bp.zdir=false else bp.zdir=true end

        bp.px=bp.px+bp.tcount
        
        bp.state='forward-collide-check'
        save(bp)
    -- y
    elseif bp.state=='move-y-check' then
        bp.y_list=get_y_list(bp)
        bp.y_diff=get_turtles_y_diff(bp.tids, bp.by, bp.y_list)
        for k,v in pairs(bp.y_diff) do
            bp.y_diff[k]=v+2
        end
        while not check_turtles_each_FuelLevel(bp.tids, bp.y_diff) do
            print('move-y-check failed')
            print('turtle need refuel')
            sleep(10)
        end

        bp.state='move-y'

    elseif bp.state=='move-y' then
        print(textutils.serialise(bp.y_diff))
        local res=move_y(bp.tids, bp.y_diff)
        if res==false then return false end

        
        bp.state='move-y-finish-check'
        save(bp)

    elseif bp.state=='move-y-finish-check' then
        -- check if y pos is correct
        bp.y_list=get_y_list(bp)
        bp.y_diff=get_turtles_y_diff(bp.tids, bp.by, bp.y_list)
        local is_pass = true
        for k,v in pairs(bp.y_diff) do
            bp.y_diff[k]=v+2
            if bp.y_diff[k]~=0 then
                bp.state='move-y-check'
                save(bp)
                is_pass=false
                break
            end
        end
        if is_pass then
            bp.state='place-check'
            save(bp)
        end
    elseif bp.state=='place-check' then
        local mat_list=get_mat_list(bp)
        bp.mat_list=mat_list
        local res, fails=check_turtles_item(bp.tids, mat_list, 1)
        if not res then
            send_place_check_info(fails)
        end
        while not res do
            res,fails=check_turtles_item(bp.tids, mat_list, 1)
            print('place-check failed')
            print(textutils.serialise(fails))
            if not res then
                send_place_check_info(fails)
            end
            sleep(10)
        end
        bp.state='place'

    elseif bp.state=='place' then
        place_down_all(bp.tids, bp.mat_list)

        
        bp.state='line-done'
        save(bp)

    elseif bp.state=='line-done' then
        -- determine move-forward or move-x
        if (bp.zdir and bp.pz>=bp.size.z) or ((not bp.zdir) and bp.pz<=1) then
            -- z done
            if (bp.px+bp.tcount-1)>=bp.size.x then
                -- xz done
                if bp.py==bp.size.y then
                    -- all-done
                    bp.state='all-done'
                else
                    -- move to next y
                    -- current no need
                    -- need to add function that move all turtles back to 1,py,1
                    -- need to change mat_map, height_map
                    bp.py=bp.py+1
                    bp.px=1
                    bp.pz=1
                    bp.state='forward-collide-check'
                end
            else
                -- z done x not
                -- move to next x
                --bp.px=bp.px+bp.tcount
                bp.state='move-x-check'
            end
        else
            -- z not done
            if bp.zdir then
                bp.pz=bp.pz+1
            else 
                bp.pz=bp.pz-1
            end
            bp.state='forward-collide-check'
        end
        
    else
        error('unexpected bp state')
    end
    return true
end
function save(bp)
    unload_blueprint(bp)
    dump_json(bp.path, bp)
    load_blueprint(bp)
end
function dump_json(path, obj)
    local fp=fs.open(path,'w')
    fp.write(textutils.serialiseJSON(obj))
    fp.close()
    return true
end


function move_all(ids, direction, dist)
    direction=direction or 'forward'
    dist=dist or 1
    local rpc={
        command={'turtle', direction}
    }

    --for i=1, dist do
    --   rpc_all(ids, rpc) 
    --end
    wraps = {}
    for i, id in pairs(ids) do
        wraps[i]=(
            function()
                return move(id, direction, dist)
            end
        )
    end
    parallel.waitForAll(unpack(wraps))
    return true
end

function move_all_safe(ids, direction, dist)
    direction=direction or 'forward'
    dist=dist or 1
    local rpc={
        command={'turtle', direction}
    }
    for i=#ids, 1, -1 do
        for k=1, dist do
            --rpc_all(ids, rpc) 
            rpc_call(ids[i], rpc)
        end
    end
    return true
end

function move(id, direction, dist)
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
    local wraps={}
    for i, id in pairs(ids) do
        if ys[i]>0 then
            wraps[i]=function()move(id, 'up', ys[i])end
        elseif ys[i]<0 then
            wraps[i]=function()move(id, 'down', math.abs(ys[i]))end
        else
            wraps[i]=function() end
        end
    end
    parallel.waitForAll(unpack(wraps))
    return true
end

function place_down_all(tids, mat_list)
    local rpc={
        command={'place_down'},
        args={}
    }
    local id,mes
    local wraps={}
    local wi=1
    for k,v in pairs(mat_list) do
        rpc.args[1]=v
        --id,mes=rpc_call(tids[k], rpc)
        --if id==nil then return false end
        wraps[wi]=function()rpc_call(tids[k], {
            command={'place_down'},
            args={v}
        })end
        wi=wi+1
    end
    parallel.waitForAll(unpack(wraps))
    return true
end


function recv(tid)
    local id, mes
    while id==nil or id~=tid do
        id, mes=rednet.receive()
    end
    return id, mes
end
function send(tid, mes, protocol)
    rednet.send(tid, mes, protocol or PTC)
end

function refuel_all(ids)
    --move all to the max_height+1
    --go back to 0,0,length+1
    move_all_to_y(ids, bp)
end
function return_pos(bp)
    local pos=get_turtles_pos(bp.tids, bp.bx,bp.by,bp.bz)
    pos=pos[1]
    move_all(bp.tids, 'back', pos[3])
end
function reset_pos(bp)
    local pos=get_turtles_pos(bp.tids, bp.bx,bp.by,bp.bz)
    pos=pos[1]
    bp.px=pos[1]
    bp.py=pos[2]
    bp.pz=pos[3]
    print('reset to', bp.px,bp.py,bp.pz)
    if math.floor((bp.px-1)/bp.tcount)%2==0 then
        bp.zdir=true
    else
        bp.zdir=false
    end
    bp.state='move-y-check'
    save(bp)
end

function main()
    local path='bp2'
    local bp=load_json(path)
    
    if arg[1]=='init' then
        init_blueprint(bp,64,4,-192)
        bp.tids={13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28}
        bp.tcount=16
        bp.path=path
        dump_json(path, bp)
        print('init success')
    elseif arg[1]=='allreq' then
        bp=load_blueprint(bp)
        send_total_mat_need(bp)
    elseif arg[1]=='back' then
        bp=load_blueprint(bp)
        return_pos(bp)
    elseif arg[1]=='reset' then
        bp=load_blueprint(bp)
        reset_pos(bp)
    elseif arg[1]=='mat' then
        bp=load_blueprint(bp)
        send_chunk_mat_missing(bp, tonumber(arg[2]))
    elseif arg[1]=='matloop' then
        bp=load_blueprint(bp)
        while true do
            send_chunk_mat_missing(bp, tonumber(arg[2]))
            sleep(3)
        end
    elseif arg[1]==nil then
        bp=load_blueprint(bp)
        while bp.state~='all-done' do
            print('process')
            print('current state:', bp.state)
            process_bp(bp)
            save(bp)
            --read()
        end
    else
        print('no command')
    end
end
main()
