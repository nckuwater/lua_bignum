
function containpos(widget, x, y)
    if widget.x <= x and x <= widget.x+widget.w-1 then
        if widget.y <= y and y <= widget.y+widget.h-1 then
            return true
        end
    end
    return false
end

function nilcheck(x, val)
    if x==nil then return val else return x end
end

function nilcall(f, ...)
    local args={...}
    if f~=nil then
        f(table.unpack(args))
    end
end

function getposwidget(widget, x, y)
    -- this x, y is base on parent coordinate
    -- first, check if child is valid
    local i,w,res
    if widget.child ~= nil then
        for i,child in pairs(widget.child) do
            res = getposwidget(child, x-widget.x+1, y-widget.y+1)
            if res ~= nil then
                -- child or its child is the target
                return res
            end
        end
    end
    -- second, if no child valid, check self
    if containpos(widget, x, y) then
        return widget
    end
    return nil
end

function getposfocusablewidget(widget, x, y)
    -- this is try to find the lowest clicked focusable widget
    -- this x, y is base on parent coordinate
    -- first, check if child is valid
    local i,w,res
    if widget.child ~= nil then
        for i,child in pairs(widget.child) do
            res = getposwidget(child, x-widget.x+1, y-widget.y+1)
            if res ~= nil and res.focusable==true then
                -- child or its child is the target
                return res
            end
        end
    end
    -- second, if no child valid, check self
    if containpos(widget, x, y) and widget.focusable==true then
        return widget
    end
    return nil
end

function getwinposwidget(win, x, y) 
    local res, focus_res=nil,nil
    x = x-win.x+1
    y = y-win.y+1
    if win.child~=nil then
        for i,w in pairs(win.child) do
            res = getposwidget(w, x, y)
            if res ~= nil then break end
        end
        for i,w in pairs(win.child) do
            focus_res = getposfocusablewidget(w, x, y)
            if focus_res ~= nil then break end
        end
    end
    return res, focus_res
end

function renderwidget(widget)
    --x,y is the parent coordinate
    if widget.window ~= nil then
        if widget.bc == nil then
            widget.window.setBackgroundColor(colors.blue)
        else
            widget.window.setBackgroundColor(widget.bc)
        end
        widget.window.setTextColor(widget.tc or colors.green)
        widget.window.clear()
        widget.window.redraw()
        widget.window.setCursorPos(1,1)
        if widget.text~=nil then widget.window.write(widget.text) end
    end
    if widget.child ~= nil then
        for i,child in pairs(widget.child) do
            renderwidget(child)
        end
    end
end

function handlewindowevent(win, event,e1,e2,e3)
    if win.FLAG_EXIT then
        nilcall(win.OnClose)
        win.window.setVisible(false)
    end

    -- handle the event to a window and its subwindows
    if event == 'mouse_click' then
        win.clicked_widget, win.clicked_focusable_widget = getwinposwidget(win, e2, e3)
        win.prev_drag_widget = win.clicked_widget
        -- update focusing widget
        if win.clicked_focusable_widget~=nil then
            win.focusing_widget = win.clicked_focusable_widget
        else
            win.focusing_widget = win
        end
        -- signal
        if win.clicked_widget ~= nil then
            nilcall(win.clicked_widget.OnMouseClick, event,e1,e2,e3)
        end 
    
    elseif event == 'mouse_up' then
        win.clicked_widget, win.clicked_focusable_widget = getwinposwidget(win, e2, e3)

        -- signal
        if win.clicked_widget ~= nil then
            nilcall(win.clicked_widget.OnMouseUp, event,e1,e2,e3)
        end 
        win.clicked_widget=nil
    
    elseif event == 'mouse_drag' then
        win.dragged_widget, win.dragged_focusable_widget = getwinposwidget(win, e2, e3)
        if win.dragged_widget~=win.prev_drag_widget then
            if win.prev_drag_widget ~= nil then
                -- drag out
                nilcall(win.prev_drag_widget.OnDragOut, event,e1,e2,e3)
            end
            if win.dragged_widget ~= nil then
                -- drag in
                nilcall(win.dragged_widget.OnDragIn, event,e1,e2,e3)
            end
        elseif win.dragged_widget~=nil then
            -- dragging
            nilcall(win.dragged_widget.OnDrag ,event,e1,e2,e3)
        end
    
        win.prev_drag_widget = win.dragged_widget
    elseif event == 'key' then
        nilcall(win.focusing_widget.OnKey, event,e1,e2,e3)
    elseif event == 'key_up' then
        nilcall(win.focusing_widget.OnKeyUp, event,e1,e2,e3)
    elseif event == 'char' then
        nilcall(win.focusing_widget.OnChar, event,e1,e2,e3)
    elseif event == 'paste' then
        nilcall(win.focusing_widget.OnPaste, event,e1,e2,e3)
    elseif event == 'mouse_scroll' then
        nilcall(win.focusing_widget.OnMouseScroll, event,e1,e2,e3)
    end
    -- BroadCast Signal
    local i, func, todo_event
    todo_event={function()return 0 end}
    if win.eventDelegate[event] ~= nil then
        for i, func in pairs(win.eventDelegate[event]) do
            --nilcall(func, event,e1,e2,e3)
            table.insert(todo_event, function() func(event,e1,e2,e3) end)
        end
    end
    if win.eventDelegate['all'] ~= nil then
        for i, func in pairs(win.eventDelegate['all']) do
            --nilcall(func, event,e1,e2,e3)
            table.insert(todo_event, function() func(event,e1,e2,e3) end)
        end
    end

    if event == 'timer' then
        -- e1 is timer_id
        if win.timer[e1] ~= nil then
            local keep_timer = win.timer[e1](event,e1)
            if keep_timer then
                local new_timer_id = os.startTimer(1)
                local tmp_funct = win.timer[e1]
                win.timer[new_timer_id] = tmp_funct
            end
            if e1 ~= new_timer_id then
                win.timer[e1]=nil
            end
        end
    end

    -- Handle win.
    -- {t=period, funct=funct}
    -- get a timer and connect the function
    if win.timer_queue ~= nil then
        for i,tobj in pairs(win.timer_queue) do
            local timer_id = os.startTimer(tobj.t)
            win.timer[timer_id] = tobj.funct
        end
        -- clear queue
        win.timer_queue={}
    end

    --parallel.waitForAny(unpack(todo_event))
    for i, ev in pairs(todo_event) do
        ev()
    end

    -- Recursive Part
    if win.child ~= nil then
        for i,child in pairs(win.child) do
            -- check if child is a window
            if child.is_window then
                handlewindowevent(child, event,e1,e2,e3)
            end
       end
    end


end

function mainloop(win)
    --[[
    win.FLAG_EXIT = false
    win.focused_widget = nil
    win.clicked_widget = nil
    win.focusing_widget = win -- default win
    win.prev_drag_widget = nil
    ]]--

    while not win.FLAG_EXIT do
        local event, e1, e2, e3 = os.pullEvent()

        handlewindowevent(win, event,e1,e2,e3)
        
        -- FOR_DEBUGGING
        if event=='key_up' and e1==keys.tab then
            win.FLAG_EXIT=true
            --term.clear()
            --term.setCursorPos(1,1)
        end

        -- Render --
        --if not win.FLAG_EXIT then
        term.clear()
        renderwidget(win)
        --end
    end
    
    if win.OnClose~=nil then win.OnClose() end
end

function new_window(x,y,w,h,widget,parent)
    local win={}
    win.is_window=true
    if x==nil then x=1 end
    if y==nil then y=1 end
    if widget==nil then widget={} end
    if parent==nil then parent=term.current() end
    local twidth, theight=term.getSize()
    if w==nil then w=twidth end
    if h==nil then h=theight end

    win.x=x
    win.y=y
    win.w=w
    win.h=h
    win.child=widget or {}

    win.window = window.create(parent, win.x, win.y, w, h)
    win.eventDelegate = {} -- a event-function table called by mainloop
    win.timer = {}

    -- event system related
    win.FLAG_EXIT=false
    win.clicked_widget, win.clicked_focusable_widget=nil,nil
    win.focused_widget = nil
    win.clicked_widget = nil
    win.focusing_widget = win -- default win
    win.prev_drag_widget = nil 

    return win
end

function new_widget(x,y,w,h)
    -- parent mainly connect in addwidget function
    -- now just assume it's connected term
    x = nilcheck(x, 1)
    y = nilcheck(y, 1)
    w = nilcheck(w, 1)
    h = nilcheck(h, 1)
    local widget = {
        x=x,y=y,w=w,h=h,
        window=window.create(term.current(),x,y,w,h)
    }
end

function addwidget(parent, widget, align)
    -- add a widget as others child
    widget.parent = parent
    if parent.child==nil then
        parent.child = {widget}
    else
        table.insert(parent.child, widget)
    end
    -- align policy
    if align~=nil then
        local ay, ax=string.sub(align, 1, 1), string.sub(align, 2, 2)
        if ay == 'n' then
            widget.y = widget.y
        elseif ay == 's' then
            widget.y = parent.h-(widget.h-1)-(widget.y-1)
        end
        if ax == 'w' then
            widget.x=widget.x
        elseif ax=='e' then
            widget.x=parent.w-(widget.w-1)-(widget.x-1)
        end
    end

    if widget.window ~= nil then
        widget.window.reposition(widget.x,widget.y,widget.w,widget.h,parent.window)
    else
        widget.window=window.create(parent.window,widget.x,widget.y,widget.w,widget.h)
    end
end

function addwin(win, subwin)
    subwin.parent = win
    if win.child==nil then
        win.child = {subwin}
    else
        table.insert(win.child, subwin)
    end
end

function bind(win, event, widget, func) 
    local func2 = function(e,e1,e2,e3) func(widget,e,e1,e2,e3) end
    if win.eventDelegate[event]==nil then
        win.eventDelegate[event] = {func2}
    else
        table.insert(win.eventDelegate[event], func2)
    end
end

function BtnClick(self, event,e1,e2,e3)
    self.text='clicked'
    self.bc=colors.yellow
end

function BtnUp(self, event,e1,e2,e3)
    self.text='up'
    self.bc=colors.white
end

function event_label_update(self, event,e1,e2,e3)
    self.text = event..' '..(e1 or '')..' '..(e2 or '')..' '..(e3 or '')
end

function ttime(widget, event, e1)
    if widget.timecount == nil then
        widget.timecount = 0
    end
    --widget.text = tostring(widget.timecount)
    widget.text = os.date()
    widget.timecount=widget.timecount+1
    return true
end

function addtimer(win, funct, period)
    -- register a timer from os
    -- store the timer_id:funct in win
    -- deal this in os.pullEvent
    -- the funct should return true to keep the timer running, otherwise it will be cancelled
    --local timer_id = os.startTimer(period)
    --win.timer[timer_id] = funct -- event,e1,e2,e3
    if win.timer_queue==nil then
        win.timer_queue={{t=period, funct=funct}}
    else
        table.insert(win.timer_queue, {t=period, funct=funct})
    end
end



function stopwindow(win)
    for i,t in pairs(win.timer) do
        if t~= nil then
            os.cancelTimer(i)
        end
    end
    win.window.setVisible(false)

end

function new_win1()
    -- original mainloop can only deal with single win event
    -- maybe add recursive to handle multi-win and make os possible.
    local win = new_window(1,1)
    local lab1 = {x=2,y=2,w=20, h=20,name='label1', text='im label1', bc=colors.white}
    local lab1c1 = {x=2,y=2,w=10,h=10,name='child1', text='btn'}
    local event_label = {x=2,y=10,w=20,h=1, name='event display', text='Waiting', bc=colors.lightBlue}
    local clicked_display = {x=2,y=12,w=20,h=1, name='clicked display', text='Waiting', bc=colors.lightBlue}
    local date_label = {x=1,y=1,w=20,h=1, name='date_label', text=os.date(), bc=colors.white, tc=colors.black}

    local exit_btn = {x=1,y=1,w=5,h=1,name='exit btn', text='exit', bc=colors.red, tc=colors.white}
    exit_btn.OnMouseClick = function(e,e1,e2,e3) win.FLAG_EXIT=true exit_btn.bc=colors.pink end

    
    win.bc=colors.lightGray
    addwidget(win, lab1)
    addwidget(lab1, lab1c1)
    addwidget(win, event_label)
    addwidget(win, clicked_display)
    addwidget(win, date_label, 'se')
    addwidget(win, exit_btn, 'ne')
    lab1c1.OnMouseClick = function(e,e1,e2,e3) BtnClick(lab1c1, e,e1,e2,e3) end
    lab1c1.OnDragIn = function(e,e1,e2,e3) BtnClick(lab1c1, e,e1,e2,e3) end
    lab1c1.OnMouseUp = function(e,e1,e2,e3) BtnUp(lab1c1, e,e1,e2,e3) end
    lab1c1.OnDragOut = function(e,e1,e2,e3) BtnUp(lab1c1, e,e1,e2,e3) end

    bind(win, 'all', event_label, event_label_update)
    addtimer(win, function(e,e1) return ttime(date_label, e,e1)end, 1)
    --mainloop(win)
    --stopwindow(win)
    --parallel.waitForAll(function() mainloop(win)end, function() ttime(lab1c1)end)
    win.OnClose=function()stopwindow(win)end
    return win
end

function basic_window(x,y,w,h)
    -- top bar
    local win=new_window(x,y,w,h)
    win.bc=colors.white
    local title_bar={x=1,y=1,w=win.w, h=1, name='title_bar', text='title', bc=colors.gray}
    local exit_btn={x=1,y=1,w=5,h=1, name='exit_btn', text='exit',bc=colors.red, tc=colors.white}
    exit_btn.OnMouseClick=function(e,e1,e2,e3)win.FLAG_EXIT=true exit_btn.bc=colors.yellow end

    addwidget(win, title_bar)
    addwidget(title_bar, exit_btn, 'ne')
    

    win.OnClose=function()stopwindow(win)end
    return win
end

function test()
    local win1 = new_win1()
    local win2 = basic_window(20,5,20,20)


    addwidget(win1, win2)
    mainloop(win1)
    --stopwindow(win1)
end

gui = {
    new_window=new_window,
    new_widget=new_widget,
    addwidget=addwidget,
    bind=bind,
    addtimer,
    mainloop=mainloop,

    basic_window=basic_window

}
