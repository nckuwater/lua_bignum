gui=require('gui')

function test()
    local win=gui.basic_window()
    local listbox1=gui.new_listbox(2,2,15,5,{'hello', 'frankstupid'})
    local btn=gui.new_button(2,8,4,4)
    gui.addwidget(win, listbox1)
    gui.addwidget(win, btn)
    btn.OnClick=function(e,e1,e2,e3)btn.text='Click'end
    btn.OnUp=function(e,e1,e2,e3)btn.text='up'end
    mainloop(win)
end

test()
term.clear()
term.setCursorPos(1,1)
