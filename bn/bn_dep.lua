BN_MASK2 = 0xffff
BN_BITS2 = 16

function new_bn()
    local bn = {
        d = {},
        top = 0,
        dmax = 0,
        neg = 0
    }
    return bn
end

function bn_copy(a, b)
    bn_expand(a, b)
    for i=1, b.top do
        a.d[i] = b.d[i]
    end
    a.neg = b.neg
    return a
end

function hex2bn(hex)
    local bn = new_bn()
    local len = string.len(hex)
    local ih = 0  -- the index of left-most hex
    if string.sub(hex,1,1) == '-' then
        ih = ih+1
        bn.neg = 1
    end
    
    local blocks = math.floor(len*4 / BN_BITS2)
    local head = (len*4 % BN_BITS2) / 4
    local k,ir = 0,1
    local bsize = BN_BITS2 / 4 -- 1 hex = 4bit, # of hex in a block
    local bstr
    --print('bsize'..bsize..' len'..len)
    bn_expand(bn, blocks+1)
    local i=len
    while(i ~= ih) do
        k = k+1

        if k >= bsize then
            bstr = string.sub(hex, i, i+bsize-1)
            --print('bstr'..bstr)
            bn.d[ir] = tonumber(bstr, 16)
            ir=ir+1
            k = 0
        end
        i = i-1
    end
    if k ~= 0 then
        bstr = string.sub(hex, i+1, i+k)
        --print('bstr'..bstr)
        bn.d[ir] = tonumber(bstr, 16)
    end
    return bn
end

function bn2hex(bn)
    local hex = ''
    if bn.neg == 1 then
        hex = hex .. '-'
    end
    local i = bn.top
    while i>0 do
        --hex = hex..string.format("%x", bn.d[i])
        hex = hex..string.format('%04x',bn.d[i])
        i = i-1
        if i>0 then
            hex=hex.." "
        end
    end
    return hex
end

function bn_expand(bn, w)
    if(bn.dmax >= w) then
        return bn
    end
    for i = (bn.top+1), w do
        -- append at higher index
        table.insert(bn.d, 0)
    end
    bn.dmax = w
    bn.top = w
    return bn
end

function bn_check_top(bn)
    local i=bn.top
    while bn.d[i] == 0 do
        bn.top = bn.top-1
        i=i-1
    end
    return bn
end

function bn_add_words(r, ir, a, ia, b, ib, n)
    -- r is pre allocated table
    --local ll,ia,ib,ir = 0, 1, 1, 1
    local ll=0
    while n ~= 0 do
        ll = ll + (a[ia] + b[ib])
        r[ir] = bit.band(ll, BN_MASK2)
        ll = bit.blogic_rshift(ll, BN_BITS2)
        ia = ia + 1
        ib = ib + 1
        ir = ir + 1
        n = n - 1
    end
    return ll
end

function bn_sub_words(r, ir, a, ia, b, ib, n)
    -- r is pre allocated table
    --local ia,ib,ir = 1, 1, 1
    local t1, t2
    local c = 0
    while n ~= 0 do
        t1 = a[ia]
        t2 = b[ib]
        r[ir] = bit.band(t1 - t2 - c, BN_MASK2)
        if t1 ~= t2 then
            if t1 < t2 then
                c = 1
            else
                c = 0
            end
        end
        ia = ia + 1
        ib = ib + 1
        ir = ir + 1
        n = n - 1
    end
    return c
end

function bn_uadd(r, a, b)
    local max, min, dif
    local ap, bp
    local rp, carry, t1, t2
    local ia, ib, ir
    if(a.top < b.top)then
        local tmp = a
        a = b
        b = tmp
    end
    max = a.top
    min = b.top
    dif = max - min
    bn_expand(r, max+1)

    r.top = max
    ap = a.d
    bp = b.d
    rp = r.d

    carry = bn_add_words(rp, 1, ap, 1, bp, 1, min)
    ir = min + 1
    ia = min + 1

    while(dif ~= 0)do
        dif = dif-1
        t1 = ap[ia]
        ia = ia + 1
        t2 = bit.band(t1+carry, BN_MASK2)
        rp[ir] = t2
        if t2 == 0 then carry = bit.band(carry, 1) else carry = bit.band(carry, 0) end
    end
    rp[ir] = carry
    r.top = r.top + carry
    r.neg = 0

    return 1
end

function bn_usub(r, a, b)
    local max, min, dif
    local t1, t2, borrow, rp
    local ap, bp
    local ia,ib,ir=1,1,1

    max = a.top
    min = b.top
    dif = max - min

    if (dif < 0) then              --/* hmm... should not be happening */
        printf("dif error\n")
        return 0
    end

    if (bn_expand(r, max) == 0)then
        printf("sub expand failed\n")
        return 0
    end

    ap = a.d
    bp = b.d
    rp = r.d

    borrow = bn_sub_words(rp, 1, ap, 1, bp, 1, min);
    ia = ia+min;
    ib = ib+min;

    -- borrow process (borrow 1 from left number)
    while (dif ~= 0) do
        dif = dif - 1
        --t1 = *(ap++)
        t1 = ap[ia]
        ia = ia+1
        --t2 = (t1 - borrow) & BN_MASK2
        t2 = bit.band((t1 - borrow), BN_MASK2)
        --*(rp++) = t2;
        rp[ir] = t2
        ir = ir+1
        --borrow &= (t1 == 0) -- borrow from the next number, if the number != 0 it can handle it, then borrow stop.
        if t1 == 0 then borrow = bit.band(borrow, 1) else borrow = bit.band(borrow, 0) end
    end

    ir = ir-1
    while (max and (rp[ir] == 0)) do--// correct the new top
        ir = ir-1
        max = max-1
    end
    r.top = max;
    r.neg = 0;

    return 1;
end

function bn_ucmp(a, b)
    local i = a.top - b.top
    if i~=0 then
        return i
    end
    local ap,bp=a.d,b.d
    local t1,t2
    i = a.top
    while i>=1 do
        t1=ap[i]
        t2=bp[i]
        if t1 ~= t2 then
            if t1 > t2 then return 1 else return -1 end
        end
        i=i-1
    end
    return 0
end

function bn_zero(a)
    a.neg = 0
    a.top = 0
end

function bn_add(r, a, b)
    local ret, r_neg, cmp_res
    bn_check_top(a)
    bn_check_top(b)
    if(a.neg == b.neg)then
        r_neg = a.neg
        ret = bn_uadd(r, a, b)
    else
        cmp_res = bn_ucmp(a,b)
        if cmp_res > 0 then
            r_neg = a.neg
            ret = bn_usub(r,a,b)
        elseif cmp_res < 0 then
            r_neg = b.neg
            ret = bn_usub(r, b, a)
        else
            r_neg = 0
            bn_zero(r)
            ret = 1
        end
    end
    r.neg = r_neg
    return ret
end

function bn_mul_words(rp, ap, num, w)
    -- rp is pre-expanded
    local c1=0
    local ir, ia=1,1
    while num ~= 0 do
        c1 = c1 + ap[ia] * w
        rp[ir] = bit.band(c1, BN_MASK2)
        c1 = bit.blogic_rshift(c1, BN_BITS2)
        ir=ir+1
        ia=ia+1
        num=num-1
    end
    return c1
end

function bn_mul_add_words(rp, ir, ap, num ,w)
    -- rp is pre-expanded
    local c1=0
    local ia=1
    while num ~= 0 do
        c1 = c1 + rp[ir] + (ap[ia] * w)
        rp[ir] = bit.band(c1, BN_MASK2)
        c1 = bit.blogic_rshift(c1, BN_BITS2)
        ir=ir+1
        ia=ia+1
        num=num-1
    end
    return c1
end

function bn_mul_normal(r, a, na, b, nb)
    if na < nb then
        local itmp, ltmp
        itmp=na
        na=nb
        nb=itmp
        ltmp=a
        a=b
        b=ltmp
    end
    local ir=1 -- irr is for carry
    local ib=1
    local irr=na+1
    r[irr] = bn_mul_words(r, a, na, b[ib])
    irr=irr+1
    ir=ir+1
    ib=ib+1
    while true do
        nb=nb-1
        if nb<=0 then
            break
        end
        print('ib '..ib..' irr '..irr)
        r[irr] = bn_mul_add_words(r, ir, a, na, b[ib])
        irr=irr+1
        ir=ir+1
        ib=ib+1
    end

end

function bn_mul_fixed_top(r, a, b)
    local al, bl, top
    al=a.top
    bl=b.top
    top  = al+bl
    if al==0 or bl==0 then
        return 1
    end
    bn_expand(r, top)
    r.top=top
    bn_mul_normal(r.d, a.d, al, b.d, bl)
    r.neg=bit.bxor(a.neg, b.neg)
    return 1
end

function bn_mul(r,a,b)
    ret = bn_mul_fixed_top(r,a,b)
    bn_check_top(r)
    return ret
end

function bn_div_fixed_top(dv, rm, num, divisor)
    -- dv must be table not nil
    -- rm can be nil
    -- no change to num, divisor
    local snum, sdiv = new_bn(), new_bn()
    bn_copy(snum, num)
    bn_copy(sdiv, div)
    local div_n, num_n=sdiv.top, snum.top
    local loop=num_n-div_n
    local q
    local tmp=new_bn()
    bn_expand(tmp, div_n+1) -- q*div
    loop = loop+1
    local inum, idiv=snum.top, sdiv.top
    local l0
    for i=0,loop do
        q = math.ceil(snum[inum] / sdiv[idiv])
        l0=bn_mul_words(tmp.d, sdiv.d, div_n, q)
        tmp.d[div_n+1]=l0 -- add the carry black

        


    end


end



hex1 = "-aafffe"
d = hex2bn(hex1)
print(textutils.serialiseJSON(d))
print(bn2hex(d))

hex1 = "aaffff"
e = hex2bn(hex1)
print(textutils.serialiseJSON(e))
print(bn2hex(e))

--g = new_bn()
--bn_add(g, d, e)
--print(textutils.serialiseJSON(g))
--print(bn2hex(g))

f = new_bn()
bn_mul(f, d, e)
--bn_check_top(f)
print("f bn")
print(textutils.serialiseJSON(f))
print(bn2hex(f))
