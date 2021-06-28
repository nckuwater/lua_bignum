

function ptr_index(ptr, n)
    if ptr.index ~= nil then
        return ptr.d[ptr.index+n]
    else
        return ptr.d[n]
    end
end

function ptr_add(ptr, n)
    ptr.index = ptr.index+n
    return ptr
end

function new_ptr(t)
    local ptr = {d=t, index=0}
    setmetatable(ptr, {__index=ptr_index, __add=ptr_add})
    return ptr
end

function main()
    local tab = {1,2,3}
    local ptr = new_ptr(tab)
    print(getmetatable(t))
    print(ptr[1])
    ptr = ptr+1
    print(ptr[1])
end

local test={}
function test.hello()
    print('hello')
end
hello()