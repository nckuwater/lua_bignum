mo = peripheral.wrap('right')
print(mo)
aa = table.pack(mo.getPaletteColor(11))

print(textutils.serialise(aa))

print(aa)
print(colors.black)

mo.clear()
print(mo.getTextScale())
mo.setTextScale(1)
mo.setCursorPos(1,1)
mo.write("mop")

img = paintutils.loadImage('the_paint.nfp')
print(textutils.serialiseJSON(img))

