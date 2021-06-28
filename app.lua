gui=require('gui')

function test()
    local win=gui.basic_window()
    local listbox1=gui.new_listbox(2,2,15,5,{'hello', 'frankstupid'})

    gui.addwidget(win, listbox1)

    mainloop(win)
end

test()
term.clear()
term.setCursorPos(1,1)