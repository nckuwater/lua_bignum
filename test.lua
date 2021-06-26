
function table_concat(a, b)
    if b ~= nil then
    for k,v in pairs(b) do
        table.insert(a, v)
    end 
    end
    return a
end

function is_collide(frame, cx, cy, bx, by) 
    local x = frame.x + (bx or 0)
    local y = frame.y + (by or 0)
    --if frame.size ~= nil then
    --if x <= cx and cx <= x+frame.size[1] then
    --    if y <= cy and cy <= y+frame.size[2] then
    --        return frame
    --    end
    --end
    --end
    
    for i, ele in pairs(frame.sub_elements or {}) do
        local tmp = is_collide(ele, cx, cy, x-1, y-1)
        if tmp ~= nil then
            return tmp
        end
    end
    if frame.size ~= nil then
    if x <= cx and cx < x+frame.size[1] then
        if y <= cy and cy < y+frame.size[2] then
            return frame
        end
    end
    end
    return nil
end
        
function render_window(frame, bx, by, invisible)
    -- invisible is to control parent-child visible in recursion, or parent visibility setting. 
    local x = frame.x + (bx or 0)
    local y = frame.y + (by or 0)
    local ele_collect = {}  -- collect all element which is displaying 
    if frame.visible == false then
        invisible = true
    end

    if frame.visible == nil or frame.visible or invisible == false then
        if frame.size ~= nil then
            paintutils.drawFilledBox(x, y,
                                    x+frame.size[1]-1, y+frame.size[2]-1, 
                                    (frame.color or colors.blue))
        end
        if frame.text ~= nil then
            term.setCursorPos(x, y)
            print(frame.text)
        end
    end
    if frame.sub_elements ~= nil then
        for i, ele in pairs(frame.sub_elements or {}) do
            table.insert(ele_collect, 1, ele)
            local sub_ele_collect = render_window(ele, x-1, y-1, invisible)
            ele_collect = table_concat(ele_collect, sub_ele_collect)
        end
    end
    
    return ele_collect    
end

function init_window(win)
    -- initialize a window object
    win.slot = {}  -- key=event, value=delegate
    win.update_handler = {}
    win.slot['mouse_up'] = {}
    win.slot['mouse_drag'] = {}
end

function connect_handler(win, signal, slot)
    -- mouse obj, button, x, y 
    if win.slot == nil then
        win.slot = {}
    end
    if win.slot[signal] == nil then
        win.slot[signal] = {slot}
    else 
        table.insert(win[signal], slot)
    end
end

function button_onclick(btn, e1, e2, e3)
    -- should bind to onclick
    if btn.pressed_color ~= nil then
        btn.color = btn.pressed_color
    end
    if btn.command ~= nil then
        btn.command(e1, e2, e3)
    end
end

function button_onup(btn, e1, e2, e3)
    if btn._color ~= nil then
        btn.color = btn._color
    end
    if btn.command_up ~= nil then
        btn.command_up(e1, e2, e3)
    end
end

function button_ondragin(btn,e1,e2,e3)
    if btn.pressed_color ~= nil then
        btn.color = btn.pressed_color
    end
end

function button_ondragout(btn,e1,e2,e3)
    if btn._color ~= nil then
        btn.color = btn._color
    end
end

function button_ondrag(btn,e1,e2,e3)
    btn.x = e2
    btn.y = e3
end

function add_button(win, btn)
    -- main reason is that button need mouse_up
    -- onclick, onup, onscroll, update
    btn.onclick = function (e, e1, e2, e3) button_onclick(btn, e1, e2, e3) end
    if win.slot['mouse_up'] == nil then
        win.slot['mouse_up'] = {}
    end
    --table.insert(win.slot['mouse_up'], function(e, e1,e2,e3) button_onup(btn,e1,e2,e3) end)
    --table.insert(win.slot['mouse_drag'], function(e, e1,e2,e3) button_ondrag(btn,e1,e2,e3) end)

    btn.onup = function (e, e1, e2, e3) button_onup(btn, e1, e2, e3) end
    btn.ondragin = function (e, e1, e2, e3) button_ondragin(btn, e1, e2, e3) end
    btn.ondragout = function (e, e1, e2, e3) button_ondragout(btn, e1, e2, e3) end
end

function change_color(obj, button, x, y)
    -- delegate
    if obj.color == colors.blue then
        obj.color = colors.yellow
    else
        obj.color = colors.blue
    end
end

function terminate_normal(obj, button, x, y)
    -- click event
    term.setCursorPos(1,1)
    term.setTextColor(colors.red)
    write("Exit Clicked")
    --textutils.slowPrint("...", 1)
    sleep(1)
    FLAG_EXIT = true
end

function test_char(event, chr)

end

exit_btn = {name='exit_btn',x=1,y=1,size={6,2}, text="Exit", color=colors.red, _color=colors.red, pressed_color=colors.white,
            command_up=function(e1, e2, e3) terminate_normal(exit_btn, e1, e2, e3) end}
test_btn = {
    name='test_btn', x=15, y=5, size={4,4}, text="TEST", color=colors.white, _color=colors.white, pressed_color=colors.yellow
}

label = {name='label1', x=1, y=5, size={10,10}, text="how are u"}
subl = {name='sublabel', x=1, y=2, size={8,3}, text="sublabel", color=colors.red}
label.sub_elements = {subl}
label.onclick = function(e1,e2,e3) change_color(label, e1,e2,e3) end
win = {x=1, y=1, sub_elements={label, exit_btn, test_btn}}
init_window(win)

--- BINDING ---
connect_handler(win, 'char', test_char)

add_button(win, test_btn)
add_button(win, exit_btn)



local focus_widget = nil

-- ondragin, ondragout


function mainloop(win)
    local clicked_element = nil
    local prev_drag_element = nil
    while not FLAG_EXIT do 
        local event, e1, e2, e3 = os.pullEvent()  -- for mouse there are 3 args, but 1 for char or key
        --print(event)
        if event == 'mouse_up' then
            local up_element = is_collide(win, e2, e3)
            if up_element ~= nil and up_element.onup ~= nil then
                up_element.onup(event, e1, e2, e3)
            end
        elseif event == 'mouse_drag'then
            -- determine drag in/out
            local drag_element = is_collide(win, e2, e3)
            if prev_drag_element ~= nil and drag_element ~= prev_drag_element then
                -- drag out
                if(prev_drag_element.ondragout ~= nil) then prev_drag_element.ondragout(event, e1, e2, e3) end
            end
            if drag_element ~= nil and drag_element ~= prev_drag_element then
                -- drag in
                if (drag_element.ondragin ~= nil) then drag_element.ondragin(event,e1,e2,e3) end
            end
            if(drag_element ~= nil and drag_element.ondrag ~= nil) then drag_element.ondrag(event,e1,e2,e3) end
            prev_drag_element = drag_element
        end
        
        if event == 'mouse_click' then
            clicked_element = is_collide(win, e2, e3)
            if clicked_element ~= nil then
                if clicked_element.onclick ~= nil then
                    clicked_element.onclick(event, e1, e2, e3)
                end
            end
        end
        if win.slot ~= nil then
            for k,v in pairs(win.slot[event] or {}) do
                v(event, e1, e2, e3)
            end
        end
        term.setBackgroundColor(colors.black)
        term.clear()
        render_window(win)
        --print(textutils.serialise(clicked_element))
    end
end
FLAG_EXIT = false
mainloop(win)

term.setCursorPos(1,1)
term.setBackgroundColor(colors.black)
term.clear()


