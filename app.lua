--gui=require('gui')
local gui=require('uu')
local comp=require('components')

local mo = peripheral.wrap('right')
if mo~=nil then
    mo.clear()
    mo.setCursorPos(1,1)
end

function test()
    local win=gui.basic_window()
    local listbox1=gui.new_listbox(2,2,15,5,{'hello', 'frankstupid'})
    local btn=gui.new_button(2,8,4,4)
    gui.addwidget(win, listbox1)
    gui.addwidget(win, btn)
    btn.OnClick=function(e,e1,e2,e3)btn.text='Click'end
    btn.OnUp=function(e,e1,e2,e3)btn.text='up'end

    local textpanel=comp.new_TextPanel(20, 3, 25, 1)
    textpanel.hint_text = 'password'
    gui.addwidget(win, textpanel)

    local task_bar = gui.new_widget(1,1,win.w, 2)
    task_bar.text='task_bar'
    task_bar.bc = colors.black
    gui.addwidget(win, task_bar, 'sw')

    local time_label = gui.new_widget(1,1,15,2)
    time_label.update_time_funct = function() time_label.text=os.date('%a %b %d\n%r') 
                                              return true end
    gui.addtimer(win, time_label.update_time_funct, 1)
    time_label.text_align = 'c'
    time_label.bc = colors.gray
    time_label.tc = colors.white
    gui.addwidget(task_bar, time_label, 'se')
    


    local lab1,lab2=gui.new_label('label1'), gui.new_label('label2')
    local dbox1=gui.new_dropdown(win, {lab1,lab2})
    dbox1.x,dbox1.y=20,2
    dbox1.bc=colors.lightGray
    lab1.bc=colors.lightGray
    lab2.bc=colors.lightGray

    --[[local img=paintutils.loadImage('img.img')
    local lmg=gui.new_image(img)
    lmg.x=30
    lmg.y=5
    gui.resize(lmg, 20,20)
    gui.addwidget(win,lmg)]]

    --local textpanel=gui.new_TextPanel(20, 3, 25, 1)


    win.OnMouseClick=function(e,e1,e2,e3) 
        if mo~=nil then
            mo.write('clicked\n')
        end
        if e1==2 then
            dbox1.show(e2,e3)
        end
    end
    gui.mainloop(win)
end
function errhandler(err)
    print("ERROR", err)
    print(debug.traceback())
    fp=fs.open('crash.log','w')
    fp.write(err)
end

local ok,err = pcall(test)
term.setCursorPos(1,1)
term.setBackgroundColor(colors.black)
term.clear()
if not ok then
    fp=fs.open('crash_log.log','w')
    fp.write(err)
    fp.close()
    term.setTextColor(colors.red)
    print(err)
end
term.setTextColor(colors.white)


