for i = 0x00, 0xff do
    print(i, " = ", string.char(i))
end 

function tt(obj)
    print(obj)
end

l = function() return tt("hello") end

--l()

function ff(a,b)
    print('ff')
end

ff(1,2,3)

while false do
    local event, e1, e2, e3 = os.pullEvent()  
    print(event)
    print(textutils.serialise(e1))
    print(textutils.serialise(e2))
    print(textutils.serialise(e3))
end

print(false == nil)
term.clear()
w = window.create(term.current(), 5,5, 10, 10)

w.setBackgroundColor(colors.red)
w.clear()
w.setCursorPos(1,1)
w.write("hey")

sub = window.create(w, 3,3,5,5)
sub.setBackgroundColor(colors.blue)
sub.clear()
sub.write("sub")
while true do
    event,e1,e2,e3 = os.pullEvent()
    term.clear()
    if e2 ~= nil then
        
        w.reposition(e2, e3)
        --w.redraw()
        --w.restoreCursor()
        --x,y=sub.getPosition()
        --sub.clear()
        --sub.write(e2.."-"..e3)
        --sub.redraw()
        --[[
        w.clear()
        w.setCursorPos(1,1)
        w.write("move")
        w.reposition(e2, e3)
        w.redraw()

        sub.clear()
        sub.setCursorPos(1,1)
        x,y = sub.getPosition()
        sub.write(e2 .. "-" .. e3)
        sub.redraw()
        --]]
        
    end
    --term.clear()
    term.setCursorPos(1,1)
    term.write((e2 or "-").." "..(e3 or "-"))
    --term.current().redraw()

end