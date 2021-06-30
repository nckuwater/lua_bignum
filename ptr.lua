

function ptr_index(ptr, n)
    return ptr.d[ptr.index+n]
end

function ptr_newindex(tab, key, value)
    if tab.d==nil then return nil end
    tab.d[key+tab.index] = value
end

function ptr_add(ptr, n)
    local nptr=new_ptr(ptr.d)
    nptr.index = ptr.index+n
    return nptr
end

function ptr_sub(ptr, n)
    local nptr=new_ptr(ptr.d)
    nptr.index=ptr.index-n
    return nptr 
end

function ptr_eq(t1,t2)
    if t1.d==t2.d and t1.index==t2.index then
        return true
    end
    return false
end

function new_ptr(tab, offset)
    local ptr
    if offset==nil then offset=0 end
    
    if tab==nil then
        ptr={d={}, index=1+offset}
    elseif tab.index~=nil then
        ptr={d=tab.d, index=tab.index+offset}
    else
        ptr={d=tab, index=1+offset}
    end
    setmetatable(ptr, {
        __index=ptr_index, 
        __newindex=ptr_newindex,
        __add=ptr_add,
        __sub=ptr_sub,
        __eq=ptr_eq})
    return ptr
end

function test()
    local tab = {1,2,3}
    local ptr = new_ptr(tab)
    
    local ptr2= new_ptr(ptr)
    ptr = ptr+1
    ptr[0]=100
    print(ptr2[1])
    
end



return {new_ptr=new_ptr}