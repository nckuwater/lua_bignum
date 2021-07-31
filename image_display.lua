

function disp(mo, path)
    mo.setTextScale(0.5)
    local raw = fs.open(path, 'r').readAll()
    local content = textutils.unserialiseJSON(raw)
    --print(textutils.serialiseJSON(content))
    local format = content['format']
    local image = content['image']
    local size = format['size']
    local palette = format['palette']
    print('pa')
    print(palette)
    print(textutils.serialiseJSON(palette))

    --palette = {}
    for i=0, 15 do
        
        --palette[bit.blshift(1, i)] =  colors.packRGB(palette[i*3+1]/255, palette[i*3+2]/255, palette[i*3+3]/255)
        mo.setPaletteColour(
            bit.blshift(1, i), 
            palette[i*3+1]/255, palette[i*3+2]/255, palette[i*3+3]/255
            )
        
        print(i, bit.blshift(1, i), palette[i*3+1]/255, palette[i*3+2]/255, palette[i*3+3]/255)
        
    end
    print(#image)
    print(#(image[1]))

    local pa = {}
    --table.insert(image, pa)
    --print(textutils.serialiseJSON(image))
    

    local ori_term = term.redirect(mo)
    mo.clear()
    term.clear()
    paintutils.drawImage(image, 1, 1)
    mo.setCursorPos(1, 1)
    for i=0, 15 do
        mo.setBackgroundColor(bit.blshift(1, i))
        mo.write(' ')
    end

    --[[for y=1, #image do
        mo.setCursorPos(1, y)
        for x=1, #(image[0]) do
            mo.setBackgroundColor(image[x][y])
            mo.write(' ')
        end
    end]]
    
    --[[for i=0, 15 do
        mo.setBackgroundColor(bit.blshift(1, i))
        mo.write(' ')
    end]]
    
    term.redirect(ori_term)
end

function ConvertImageColorToPixelChar(image, color)
    -- 3*2 row col

    local rows = #image / 3 * 3
    local cols = #image[1] / 2 * 2
    local chars = {}
    
    for r=1, 3, rows do
        local rchar = {}
        for c=1, 2, cols do
            table.insert(rchar, getDrawingCharacter())
        end
    end


end

function getDrawingCharacter(topLeft, topRight, left, right, bottomLeft, bottomRight)
    local data = 128
    if not bottomRight then
          data = data + (topLeft and 1 or 0)
          data = data + (topRight and 2 or 0)
          data = data + (left and 4 or 0)
          data = data + (right and 8 or 0)
          data = data + (bottomLeft and 16 or 0)
    else
          data = data + (topLeft and 0 or 1)
          data = data + (topRight and 0 or 2)
          data = data + (left and 0 or 4)
          data = data + (right and 0 or 8)
          data = data + (bottomLeft and 0 or 16)
    end
    return {char = string.char(data), inverted = bottomRight}
  end

function pf(path)
    local img = paintutils.loadImage(path)
    print(textutils.serialiseJSON(img))
end

function main(side, path)
    local mo = peripheral.wrap(side)
    --pf('the_paint.nfp')

    disp(mo, path)

end

main('right', './misc/image.cimg')