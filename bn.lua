ptr=require('ptr')
_G.new_ptr=ptr.new_ptr
BN_MASK2 = 0xffff
BN_BITS2 = 16

function new_bn()
    local bn = {
        d = new_ptr(),
        top = 0,
        dmax = 0,
        neg = 0
    }
    return bn
end

function bn_copy(a, b)
    bn_expand(a, b)
    for i=0, b.top-1 do
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
    local k,ir = -1,0
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
            k = -1
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
    local i = bn.top-1
    while i>=0 do
        --hex = hex..string.format("%x", bn.d[i])
        hex = hex..string.format('%04x',bn.d[i])
        i = i-1
        if i>=0 then
            hex=hex.." "
        end
    end
    return hex
end

function bn_expand(bn, w)
    if(bn.dmax >= w) then
        return bn
    end
    for i = bn.top, w-1 do
        -- append at higher index
        table.insert(bn.d, 0)
    end
    bn.dmax = w
    bn.top = w
    return bn
end

function bn_check_top(bn)
    local i=bn.top-1
    while bn.d[i] == 0 do
        bn.top = bn.top-1
        i=i-1
    end
    return bn
end

function bn_add_words(r, a, b, n)
    -- r, a, b are ptr
    a=new_ptr(a)
    b=new_ptr(b)
    r=new_ptr(r)
    local ll=0
    while n ~= 0 do
        ll = ll + (a[0] + b[0])
        r[0] = bit.band(ll, BN_MASK2)
        ll = bit.blogic_rshift(ll, BN_BITS2)
        a=a+1
        b=b+1
        r=r+1
        n = n - 1
    end
    return ll
end

function bn_sub_words(r, a, b, n)
    -- a,b,r are ptr
    a=new_ptr(a)
    b=new_ptr(b)
    r=new_ptr(r)
    local t1, t2
    local c = 0
    while n ~= 0 do
        t1 = a[0]
        t2 = b[0]
        r[0] = bit.band(t1 - t2 - c, BN_MASK2)
        if t1 ~= t2 then
            if t1 < t2 then
                c = 1
            else
                c = 0
            end
        end
        a = a + 1
        b = b + 1
        r = r + 1
        n = n - 1
    end
    return c
end

function bn_uadd(r, a, b)
    local max, min, dif
    local ap, bp
    local rp, carry, t1, t2

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
    ap = new_ptr(a.d)
    bp = new_ptr(b.d)
    rp = new_ptr(r.d)

    carry = bn_add_words(rp, ap, bp, min)
    rp=rp+min
    ap=ap+min

    while(dif ~= 0)do
        dif = dif-1
        t1 = ap[0]
        ap=ap+1
        t2 = bit.band(t1+carry, BN_MASK2)
        rp[0] = t2
        rp=rp+1
        if t2 == 0 then carry = bit.band(carry, 1) else carry = bit.band(carry, 0) end
    end
    rp[0] = carry
    r.top = r.top + carry
    r.neg = 0

    return 1
end

function bn_usub(r, a, b)
    local max, min, dif
    local t1, t2, borrow, rp
    local ap, bp

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

    ap = new_ptr(a.d)
    bp = new_ptr(b.d)
    rp = new_ptr(r.d)

    borrow = bn_sub_words(rp, ap, bp, min);
    ap = ap + min
    rp = rp + min

    -- borrow process (borrow 1 from left number)
    while (dif ~= 0) do
        dif = dif - 1
        --t1 = *(ap++)
        t1 = ap[0]
        ap=ap+1
        --t2 = (t1 - borrow) & BN_MASK2
        t2 = bit.band((t1 - borrow), BN_MASK2)
        --*(rp++) = t2;
        rp[0] = t2
        rp=rp+1
        ir = ir+1
        --borrow &= (t1 == 0) -- borrow from the next number, if the number != 0 it can handle it, then borrow stop.
        if t1 == 0 then borrow = bit.band(borrow, 1) else borrow = bit.band(borrow, 0) end
    end

    rp=rp-1
    while (max and (rp[0] == 0)) do--// correct the new top
        max = max-1
        rp=rp-1
    end
    rp=rp+1
    r.top = max;
    r.neg = 0;

    return 1;
end

function bn_ucmp(a, b)
    local i
    local t1,t2,ap,bp

    i=a.top-b.top
    if i~=0 then
        return i
    end

    ap=new_ptr(ap)
    bp=new_ptr(bp)
    i = a.top-1
    while i>=0 do
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

function bn_sub(r, a, b)
    local ret, r_neg, cmp_res
    if(a.neg~=b.neg)then
        r_neg=a.neg
        ret=bn_add(r,a,b)
    else
        cmp_res=bn_ucmp(a,b)
        if(cmp_res>0)then
            r_neg=a.neg
            ret=bn_usub(r,a,b)
        elseif(cmp_res<0)then
            if b.neg then r_neg=0 else r_neg=1 end
            ret=bn_usub(r,b,a)
        else
            r_neg=0
            bn_zero(r)
            ret=1
        end
    end
    r.neg=r_neg
    return ret
end


function bn_mul_words(rp, ap, num, w)
    -- rp is pre-expanded
    rp=new_ptr(rp)
    ap=new_ptr(ap)
    local c1=0
    while num ~= 0 do
        c1 = c1 + ap[0] * w
        rp[0] = bit.band(c1, BN_MASK2)
        c1 = bit.blogic_rshift(c1, BN_BITS2)
        rp=rp+1
        ap=ap+1
        num=num-1
    end
    return c1
end

function bn_mul_add_words(rp, ap, num ,w)
    -- rp is pre-expanded
    rp=new_ptr(rp)
    ap=new_ptr(ap)
    local c1=0
    while num ~= 0 do
        c1 = c1 + rp[0] + (ap[0] * w)
        rp[0] = bit.band(c1, BN_MASK2)
        c1 = bit.blogic_rshift(c1, BN_BITS2)
        rp=rp+1
        ap=ap+1
        num=num-1
    end
    return c1
end

function bn_mul_normal(r, a, na, b, nb)
    local rr
    if na < nb then
        local itmp, ltmp
        itmp=na
        na=nb
        nb=itmp
        ltmp=a
        a=b
        b=ltmp
    end
    rr=new_ptr(r)
    rr=rr+na --&(r[na])
    rr[0] = bn_mul_words(r, a, na, b[0])
    rr=rr+1
    r=r+1
    b=b+1
    while true do
        nb=nb-1
        if nb<=0 then
            break
        end

        rr[0] = bn_mul_add_words(r, a, na, b[0])
        rr=rr+1
        r=r+1
        b=b+1
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
    local rr=r
    bn_expand(rr, top)
    rr.top=top
    bn_mul_normal(rr.d, a.d, al, b.d, bl)
    rr.neg=bit.bxor(a.neg, b.neg)
    return 1
end

function bn_mul(r,a,b)
    ret = bn_mul_fixed_top(r,a,b)
    bn_check_top(r)
    return ret
end

function bn_num_bit_word(l)
    local bits, keep, mask
    mask=bit.blshift(1, BN_BITS2-1)
    bits=0
    keep=0
    for i=1,BN_BITS2 do
        if bit.band(l, mask)~=0 then
            break
        end
        l=bit.blshift(l,1)
        bits=bits+1
    end
    return bits
end

function bn_left_align(num)
    local d,n,m,rmask
    d=new_ptr(num.d)
    local top=num.top
    local rshift=bn_num_bit_word(d[top-1])
    local lshift,i

    lshift=BN_BITS2-rshift
    rshift=rshift%BN_BITS2
    if rshift==1 then rmask=BN_MASK2 else rmask=0 end
    
    m=0
    for i=0, top-1 do
        n=d[i]
        d[i]=bit.band((bit.bor(bit.blshift(n, lshift), m), BN_MASK2)
        m=bit.band(bit.blogic_rshift(n, rshift), rmask)
    end
    return lshift
end

function bn_div_fixed_top(dv, rm, num, divisor)
    -- all args are BIGNUM
    -- rm can be nil
    -- no change to num, divisor
    
    local norm_shift,i,j,loop
    local tmp,snum,sdiv,res
    local resp, wnum, wnumtop
    local d0,d1
    local num_n,div_n
    if dv==nil then
        res=bn_new()
    else
        res=dv
    end
    tmp=bn_new()
    snum=bn_new()
    sdiv=bn_new()

    bn_copy(sdiv, divisor)
    norm_shift=bn_left_align(sdiv)
    sdiv.neg=0

    bn_lshift_fixed_top(snum, num, norm_shift)

    div_n=sdiv.top
    num_n=snum.top

    if(num_n <= div_n)then
        bn_expand(snum, div_n+1)
        num_n=div_n+1
        snum.top=num_n
    end

    loop=num_n-div_n

    wnum=new_ptr(snum.d, loop)
    wnumtop=new_ptr(snum.d, num_n-1)

    -- Get the top 2 words of sdiv
    d0=sdiv.d[div_n-1]
    if div_n==1 then
        d1=0
    else
        d1=sdiv.d[div_n-2]
    end

    bn_expand(res, loop)
    res.neg=bit.bxor(num.neg, divisor.neg)
    res.top=loop
    resp=new_ptr(res.d, loop)

    bn_expand(tmp, div_n+1)

    local q, l0
    for i=0,loop-1 do
        q = math.ceil(snum[inum] / sdiv[idiv])
        l0=bn_mul_words(tmp.d, sdiv.d, div_n, q)
        tmp.d[div_n]=l0 -- add the carry black
        wnum=wnum-1

        l0=bn_sub_words(wnum,wnum,tmp.d, div_n+1)
        q=q-l0

        --l0=0-l0
        if l0==0 then l0=0 else l0=BN_MASK2 end

        for j=0,div_n-1 do
            tmp.d[j]=bit.band(sdiv.d[j], l0)
        end
        l0=bn_add_words(wnum,wnum,tmp.d,div_n)
        wnumtop[0]=wnumtop[0]+l0

        if(wnumtop[0]~=0)then
            error('error *wnumtop==0')
        end

        resp=resp-1
        resp[0]=q

        -- loop
        wnumtop=wnumtop-1
    end
    snum.neg=num.neg
    snum.top=div_n
    if(rm~=nil)then
        bn_rshift_fixed_top(rm,snum,norm_shift)
    end
    return 1
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
