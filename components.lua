gui = require('uu')

comp = {}


function TextPanel_KeyEventHandler(widget,e,e1,e2,e3)
    if e1==keys.right then
        -- move cursor right by 1
        local cx,cy=widget.cursorPos.x, widget.cursorPos.y
        if widget.cursorPos.x <= #widget.input_text then
            widget.cursorPos.x=widget.cursorPos.x+1
        end
    elseif e1==keys.left then
        local cx,cy=widget.cursorPos.x, widget.cursorPos.y
        if cx>1 then
            widget.cursorPos.x=widget.cursorPos.x-1
        end
    elseif e1==keys.backspace then
        local cx,cy=widget.cursorPos.x, widget.cursorPos.y
        local tlen=#widget.input_text
        if tlen>0 and cx>1 then
            -- remove cx-1
            widget.input_text=
            string.sub(widget.input_text,1 ,cx-2)..
            string.sub(widget.input_text,cx,#widget.input_text)
            widget.cursorPos.x=widget.cursorPos.x-1

            if widget.password_replace == nil then
                widget.text=widget.input_text
            else
                widget.text=string.rep(widget.password_replace, #widget.input_text)
            end
        end
        
    elseif e1==keys.enter then
        fp=fs.open('tmp.log','w')
        fp.write(widget.input_text)
        fp.close()
    end
end

function TextPanel_CharEventHandler(widget,e,e1,e2,e3)
    if e1~=nil then
        local cx,cy=widget.cursorPos.x, widget.cursorPos.y
        widget.input_text=
        string.sub(widget.input_text,1, cx-1)..e1..
        string.sub(widget.input_text,cx, #widget.input_text)
        widget.cursorPos.x=widget.cursorPos.x+1

        if widget.password_replace == nil then
            widget.text=widget.input_text
        else
            widget.text=string.rep(widget.password_replace, #widget.input_text)
        end
        
    end
end

function TextPanel_OnFocus(widget,e,e1,e2,e3)
    -- this can be better like adjust by mouse_click position

    widget.cursorPos.x=#widget.input_text+1

    widget.window.setCursorBlink(true)
end

function TextPanel_OnBlur(widget,e,e1,e2,e3)
    widget.window.setCursorBlink(false)

end

function TextPanel_Render(widget)
    -- Override the way gui lib render
    -- because we need to deal with cursors.
    if widget.window ~= nil then
        if widget.bc == nil then
            widget.window.setBackgroundColor(colors.blue)
        else
            widget.window.setBackgroundColor(widget.bc)
        end
        if #widget.text==0 and widget.hint_tc then
            widget.window.setTextColor(widget.hint_tc)
        else
            widget.window.setTextColor(widget.tc or colors.black)
        end
        widget.window.clear()
        widget.window.redraw()
        widget.window.setCursorPos(1,1)
        if widget.text~=nil then 
            if #widget.text==0 and widget.hint_text~=nil then
                widget.window.write(widget.hint_text)
            else
                widget.window.write(widget.text) 
            end
        end
        widget.window.setCursorPos(widget.cursorPos.x, widget.cursorPos.y)
    end
    -- Render children
    if widget.child ~= nil then
        for i,child in pairs(widget.child) do
            gui.renderwidget(child)
        end
    end
end

function new_TextPanel(x,y,w,h)
    local widget=gui.new_widget(x,y,w,h)
    widget.cursorPos={x=1,y=1}
    widget.input_text='testi'
    widget.text=widget.input_text
    widget.IsFocusable=true -- make this widget can be focus and get key events
    widget.OnKey=function(e,e1,e2,e3)TextPanel_KeyEventHandler(widget,e,e1,e2,e3)end
    widget.OnFocus=function(e,e1,e2,e3)TextPanel_OnFocus(widget,e,e1,e2,e3)end
    widget.OnChar=function(e,e1,e2,e3)TextPanel_CharEventHandler(widget,e,e1,e2,e3)end
    widget.OnBlur=function(e,e1,e2,e3)TextPanel_OnBlur(widget,e,e1,e2,e3)end
    widget.render=function()TextPanel_Render(widget)end

    widget.bc=colors.lightBlue
    widget.password_replace='#'
    widget.hint_text=nil
    widget.hint_tc=colors.gray
    
    return widget
end

comp = {
    new_TextPanel=new_TextPanel
}

return comp