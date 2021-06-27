
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
            res = getposwidget(child, widget.x-x+1, widget.y-y+1)
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
            res = getposwidget(child, widget.x-x+1, widget.y-y+1)
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
    x = x+win.x
    y = y+win.y
    if win.widget~=nil then
        for i,w in pairs(win.widget) do
            res = getposwidget(w, x, y)
            if res ~= nil then break end
        end
        for i,w in pairs(win.widget) do
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
    focusing_widget = nil
    prev_drag_widget = nil

    while not FLAG_EXIT do
        local event, e1, e2, e3 = os.pullEvent()
        local clicked_widget
        if event == 'mouse_click' then
            clicked_widget, clicked_focusable_widget = getwinposwidget(win, e2, e3)
            prev_drag_widget = clicked_widget
            -- update focusing widget
            if clicked_focusable_widget~=nil then
                focusing_widget = clicked_focusable_widget
            end
            -- just test
            win.window.reposition(e2,e3)
            --/just test

            -- signal
            if clicked_widget~=nil then
                nilcall(clicked_widget.OnMouseClick, event, e1, e2, e3)
            end
        end
        if event == 'mouse_up' then
            clicked_widget, clicked_focusable_widget = getwinposwidget(win, e2, e3)

            -- signal
            if clicked_widget ~= nil then
                nilcall(clicked_widget.OnMouseUp, event,e1,e2,e3)
            end 
        end
        if event == 'mouse_drag' then
            dragged_widget, dragged_focusable_widget = getwinposwidget(win, e2, e3)
            if dragged_widget~=prev_drag_widget then
                if prev_drag_widget ~= nil then
                    -- drag out
                    nilcall(prev_drag_widget.OnDragOut, event,e1,e2,e3)
                end
                if dragged_widget ~= nil then
                    -- drag in
                    nilcall(dragged_widget.OnDragOut, event,e1,e2,e3)
                end
            end
        end

        -- Render --
        term.clear()
        renderwidget(win)
        --win.window.write(' '..event..' '..e1)
        if event=='key_up' and e1==15 then
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

function test()

    lab1 = {x=2,y=2,w=20, h=20,name='label1', text='im label1', bc=colors.white}
    lab1c1 = {x=2,y=2,w=10,h=10,name='child1', text='pppp'}

    win = new_window(1,1)
    addwidget(win, lab1)
    addwidget(lab1, lab1c1)
    mainloop(win)
end
test()
