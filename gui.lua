
function containpos(widget, x, y)
    if widget.x <= x and x <= widget.x+widget.w then
        if widget.y <= y and y <= widget.y+widget.h then
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

function renderwindow(win)
    
end

function mainloop(win)
    FLAG_EXIT = false
    focused_widget = nil
    clicked_widget = nil
    focusing_widget = win -- default win
    prev_drag_widget = nil

    while not FLAG_EXIT do
        local event, e1, e2, e3 = os.pullEvent()
        if event == 'mouse_click' then
            clicked_widget, clicked_focusable_widget = getwinposwidget(win, e2, e3)
            prev_drag_widget = clicked_widget
            -- update focusing widget
            if clicked_focusable_widget~=nil then
                focusing_widget = clicked_focusable_widget
            else
                focusing_widget = win
            end

            -- signal
            if clicked_widget~=nil then
                nilcall(clicked_widget.OnMouseClick, event, e1, e2, e3)
                clicked_display.text = clicked_widget.name or 'NIL'
            end
            
        
        elseif event == 'mouse_up' then
            clicked_widget, clicked_focusable_widget = getwinposwidget(win, e2, e3)

            -- signal
            if clicked_widget ~= nil then
                nilcall(clicked_widget.OnMouseUp, event,e1,e2,e3)
            end 
            clicked_widget=nil
        
        elseif event == 'mouse_drag' then
            dragged_widget, dragged_focusable_widget = getwinposwidget(win, e2, e3)
            if dragged_widget~=prev_drag_widget then
                if prev_drag_widget ~= nil then
                    -- drag out
                    nilcall(prev_drag_widget.OnDragOut, event,e1,e2,e3)
                end
                if dragged_widget ~= nil then
                    -- drag in
                    nilcall(dragged_widget.OnDragIn, event,e1,e2,e3)
                end
            end
        elseif event == 'key' then
            nilcall(focusing_widget.OnKey, event,e1,e2,e3)
        elseif event == 'key_up' then
            nilcall(focusing_widget.OnKeyUp, event,e1,e2,e3)
        elseif event == 'char' then
            nilcall(focusing_widget.OnChar, event,e1,e2,e3)
        elseif event == 'paste' then
            nilcall(focusing_widget.OnPaste, event,e1,e2,e3)
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

        --parallel.waitForAny(unpack(todo_event))
        for i, ev in pairs(todo_event) do
            ev()
        end

        -- Render --
        term.clear()
        renderwidget(win)

        if event=='key_up' and e1==keys.tab then
            FLAG_EXIT=true
            term.clear()
            term.setCursorPos(1,1)
        end
    end
end

function new_window(x,y,widget,parent,w,h)
    local win={}
    if x==nil then x=1 end
    if y==nil then y=1 end
    if widget==nil then widget={} end
    if parent==nil then parent=term.current() end
    twidth, theight=term.getSize()
    if w==nil then w=twidth end
    if h==nil then h=theight end

    win.x=x
    win.y=y
    win.w=w
    win.h=h
    win.child=widget

    win.window = window.create(parent, win.x, win.y, w, h)
    win.eventDelegate = {} -- a event-function table called by mainloop
    return win
end

function addwidget(parent, widget)
    -- add a widget as others child
    if parent.child==nil then
        parent.child = {widget}
    else
        table.insert(parent.child, widget)
    end
    if widget.window ~= nil then
        widget.window.reposition(widget.x,widget.y,widget.w,widget.h,parent.window)
    else
        widget.window=window.create(parent.window,widget.x,widget.y,widget.w,widget.h)
    end
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
    self.text = event
end

function test()
    lab1 = {x=2,y=2,w=20, h=20,name='label1', text='im label1', bc=colors.white}
    lab1c1 = {x=2,y=2,w=10,h=10,name='child1', text='btn'}
    event_label = {x=10,y=10,w=20,h=1, name='event display', text='Waiting', bc=colors.lightBlue}
    clicked_display = {x=10,y=12,w=20,h=1, name='clicked display', text='Waiting', bc=colors.lightBlue}

    win = new_window(1,1)
    addwidget(win, lab1)
    addwidget(lab1, lab1c1)
    addwidget(win, event_label)
    addwidget(win, clicked_display)
    lab1c1.OnMouseClick = function(e,e1,e2,e3) BtnClick(lab1c1, e,e1,e2,e3) end
    lab1c1.OnMouseUp = function(e,e1,e2,e3) BtnUp(lab1c1, e,e1,e2,e3) end

    bind(win, 'all', event_label, event_label_update)
    mainloop(win)
end
test()
