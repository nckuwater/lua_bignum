ptr=require('ptr')
prime_lib=require('bn_prime')
local primes=new_ptr(prime_lib.primes)

_G.new_ptr=ptr.new_ptr
BN_MASK2 = 0xffff
BN_BITS2 = 16
--BN_MASK2 = 0xffffffff
--BN_BITS2 = 32
BN_BYTES2=math.floor(BN_BITS2/8)

local RSA_FIPS1864_MIN_KEYGEN_KEYSIZE = 2048

local inv_sqrt_2_val={
    0x8333,0x9916, 0xED17,0xAC85, 0x0893,0xBA84, 0x1D6F,0x60BA,
    0x754A,0xBE9F, 0x597D,0x89B3, 0xF9DE,0x6484, 0xB504,0xF333
}


function new_bn()
    local bn = {
        d = new_ptr(),
        top = 0,
        dmax = 0,
        neg = 0
    }
    return bn
end

local inv_sqrt_2_val_ptr=new_ptr(inv_sqrt_2_val)
local ossl_bn_inv_sqrt_2=new_bn()
ossl_bn_inv_sqrt_2.d=inv_sqrt_2_val_ptr
ossl_bn_inv_sqrt_2.dmax=#inv_sqrt_2_val_ptr.d
ossl_bn_inv_sqrt_2.top=#inv_sqrt_2_val_ptr.d

function bn_new()
    return new_bn()
end
function bn_copy(a, b)
    if a==b then
        return a
    end
    bn_expand(a, b.dmax)
    for i=0, b.dmax-1 do
        a.d[i] = b.d[i]
    end
    a.neg = b.neg
    a.top = b.top
    return a
end
function bn_dup(a)
    local t
    if a==nil then return nil end
    bn_check_top(a)
    t=bn_new()
    bn_copy(t,a)
    bn_check_top(t)
    return t
end

function memset(ptr, num, words)
    ptr=new_ptr(ptr)
    for i=0, words-1 do
        ptr[i]=num
    end
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
    local k,ir = 0,0
    local bsize = BN_BITS2 / 4 -- 1 hex = 4bit, # of hex in a block
    local bstr
    --print('bsize'..bsize..' len'..len)
    bn_expand(bn, blocks+1)
    bn.top=blocks+1
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
function printbn(bn)
    print(bn2hex(bn))
end

function bn_expand(bn, w)
    if(bn.dmax >= w) then
        return bn
    end
    local i
    for i = bn.top, w-1 do
        -- append at higher index
        table.insert(bn.d.d, 0)
    end
    bn.dmax = w
    --bn.top = w
    return bn
end

function bn_check_top(bn)
    --[[if bn==nil then return end
    local i=bn.top-1
    while bn.d[i] == 0 do
        bn.top = bn.top-1
        i=i-1
    end
    return bn
    ]]--
    if bn~=nil then
        local top=bn.top
        if(top==0 and bn.neg==0)then return 1 end
        if(bn.d[top-1]~=0)then return 1 end
        return 0
    end
    return 1
end

function bn_correct_top(a)
    local ftl
    local tmp_top=a.top
    if tmp_top>0 then
        ftl=new_ptr(a.d,tmp_top)
        while(tmp_top>0)do
            ftl=ftl-1
            if(ftl[0]~=0)then break end

            tmp_top=tmp_top-1
        end
        a.top=tmp_top
    end
    if a.top==0 then
        a.neg=0
    end

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
        --r[0] = t1 - t2 - c
        r=r+1
        if t1 ~= t2 then
            if t1 < t2 then
                c = 1
            else
                c = 0
            end
        end
        a = a + 1
        b = b + 1
        n = n - 1
    end
    return c
end

function bn_uadd(r, a, b)
    local max, min, dif
    local ap, bp
    local rp, carry, t1, t2
    bn_check_top(a)
    bn_check_top(b)

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
    bn_check_top(a)
    bn_check_top(b)

    max = a.top
    min = b.top
    dif = max - min

    if (dif < 0) then              --/* hmm... should not be happening */
        printf("dif error\n")
        return 0
    end

    bn_expand(r, max)

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

    ap=new_ptr(a.d)
    bp=new_ptr(b.d)
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
function bn_cmp(a,b)
    local i
    local gt,lt
    local t1,t2
    if a==nil or b==nil then
        if a~=nil then return -1
        elseif b~=nil then return 1
        else return 0
        end
    end
    if a.neg~=b.neg then
        if a.neg==1 then return -1
        else return 1 end
    end
    if a.neg==0 then
        gt=1
        lt=-1
    else
        gt=-1
        lt=1
    end
    if a.top>b.top then
        return gt
    end
    if a.top<b.top then
        return lt
    end
    for i=a.top-1,0,-1 do
        t1=a.d[i]
        t2=b.d[i]
        if t1>t2 then return gt end
        if t1<t2 then return lt end
    end
    return 0
end

function bn_zero(a)
    a.neg = 0
    a.top = 0
end

function bn_one(a)
    bn_set_word(a,1)
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

function bn_sub_word_bad(a, w)
    local word=bn_new()
    bn_set_word(word,w)
    bn_sub(a,a,word)
    return 1
end


function bn_mul_words(rp, ap, num, w)
    -- rp is pre-expanded
    rp=new_ptr(rp)
    ap=new_ptr(ap)
    local c1=0
    while num ~= 0 do
        c1 = c1 + (ap[0] * w)
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
    -- all ptr
    r=new_ptr(r)
    a=new_ptr(a)
    b=new_ptr(b)

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
    -- all BIGNUM
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
    bn_correct_top(r)
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
    return BN_BITS2-bits
end

function bn_left_align(num)
    bn_correct_top(num)
    local d,n,m,rmask
    d=new_ptr(num.d)
    local top=num.top
    local rshift=bn_num_bit_word(d[top-1])
    local lshift,i

    lshift=BN_BITS2-rshift
    rshift=rshift%BN_BITS2
    if rshift==0 then rmask=0 else rmask=BN_MASK2 end
    
    m=0

    for i=0, top-1 do
        n=d[i]
        d[i]=bit.band(bit.bor(bit.blshift(n, lshift), m), BN_MASK2)
        m=bit.band(bit.blogic_rshift(n, rshift), rmask)
    end
    return lshift
end

function bn_lshift_fixed_top(r,a,n)
    local i,nw
    local lb,rb
    local t,f
    local l,m,rmask
    rmask=0

    nw=math.floor(n/BN_BITS2)

    bn_expand(r,a.top+nw+1)

    if(a.top~=0)then
        lb=n%BN_BITS2
        rb=BN_BITS2-lb
        rb=rb%BN_BITS2
        if rb==0 then rmask=0 else rmask=BN_MASK2 end
        f=new_ptr(a.d)
        t=new_ptr(r.d,nw)
        l=f[a.top-1]
        t[a.top]=bit.band(rmask, bit.blogic_rshift(l, rb))
        for i=a.top-1, 1, -1 do
            m=bit.blshift(l,lb)
            l=f[i-1]
            t[i]=bit.band(BN_MASK2, bit.bor(m, bit.band(BN_MASK2, bit.blogic_rshift(l, rb))))

        end
        t[0]=bit.band(BN_MASK2, bit.blshift(l, lb))
    else
        r.d[nw]=0
    end
    if(nw~=0)then
        memset(new_ptr(r.d), 0, nw)
    end
    r.neg=a.neg
    r.top=a.top+nw+1
    return 1
end
function bn_rshift_fixed_top(r,a,n)
    local i,top,nw
    local lb,rb
    local t,f
    local l,m,mask

    nw=math.floor(n/BN_BITS2)
    if nw>=a.top then
        bn_zero(r)
        return 1
    end

    rb=n%BN_BITS2
    lb=BN_BITS2-rb
    lb=lb%BN_BITS2
    if lb==0 then mask=0 else mask=BN_MASK2 end
    top=a.top-nw
    if(r~=a) then
        bn_expand(r,top)
    end
    t=new_ptr(r.d)
    f=new_ptr(a.d, nw)
    l=f[0]
    i=0
    while i<top-1 do
        m=f[i+1]
        t[i]=bit.bor(bit.blogic_rshift(l, rb), bit.band(bit.blshift(m, lb), BN_MASK2))
        l=m
        i=i+1
    end
    t[i]=bit.blogic_rshift(l, rb)
    r.neg=a.neg
    r.top=top
    return 1
end

function bn_lshift(r,a,n)
    local ret
    if n<0 then
        return 0
    end
    ret=bn_lshift_fixed_top(r,a,n)
    bn_correct_top(r)
    bn_check_top(r)
    return ret
end
function bn_rshift(r,a,n)
    local reet=0
    if n<0 then return 0 end
    ret=bn_rshift_fixed_top(r,a,n)
    bn_correct_top(r)
    bn_check_top(r)
    return ret
end
function bn_lshift1(r,a)
    local ap,rp,t,c
    local i
    if r~= a then
        r.neg=a.neg
        bn_expand(r,a.top+1)
        r.top=a.top
    else
        bn_expand(r,a.top+1)
    end
    ap=new_ptr(a.d)
    rp=new_ptr(r.d)
    c=0
    for i=0,a.top-1 do
        t=ap[0]
        ap=ap+1
        rp[0]=bit.band(bit.bor(bit.blshift(t,1),c),BN_MASK2)
        rp=rp+1
        c=bit.blogic_rshift(t,(BN_BITS2-1))
    end
    rp[0]=c
    r.top=r.top+c
    return 1
end
function bn_rshift1(r,a)
    local ap,rp,t,c
    local i
    if bn_is_zero(a)~=0 then
        bn_zero(r)
        return 1
    end
    i=a.top
    ap=new_ptr(a.d)
    if a~=r then
        bn_expand(r,i)
        r.neg=a.neg
    end
    rp=new_ptr(r.d)
    r.top=i
    i=i-1
    --print(textutils.serialiseJSON(a))
    t=ap[i]
    if t==nil then
        printError('t is nil')
        print(textutils.serialiseJSON(a))
    end
    rp[i]=bit.blogic_rshift(t,1)
    c=bit.blshift(t,BN_BITS2-1)
    if t==1 then r.top=r.top-1 else r.top=r.top-0 end
    while i>0 do
        i=i-1
        t=ap[i]
        rp[i]=bit.bor(bit.band(bit.blogic_rshift(t,1),BN_MASK2),c)
        c=bit.blshift(t,BN_BITS2-1)
    end
    if r.top==0 then
        r.neg=0
    end
    return 1
end



function bn_div_3_words(m,d1,d0)
    m=new_ptr(m)
    local R=bit.bor(bit.blshift(m[0], BN_BITS2), m[-1])
    local D=bit.bor(bit.blshift(d0, BN_BITS2), d1)
    local Q, mask,i
    Q=0

    for i=0, BN_BITS2-1 do
        Q=bit.blshift(Q,1)
        if(R>=D)then
            Q=bit.bor(Q,1)
            R=R-D
        end
        D=bit.blogic_rshift(D, 1)
    end
    Q=bit.band(Q,BN_MASK2)
    if bit.blogic_rshift(Q, BN_BITS2-1)==0 then mask=0 else mask=BN_MASK2 end
    
    Q=bit.blshift(Q,1)
    if R>=D then Q=bit.bor(Q, 1) else Q=bit.bor(Q,0) end

    return bit.band(BN_MASK2, bit.bor(Q, mask))
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

    bn_check_top(num)
    bn_check_top(divisor)
    bn_check_top(dv)
    bn_check_top(rm)
    bn_correct_top(num)
    bn_correct_top(divisor)

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
    --print('normshift=',norm_shift)

    --print("INIT snum")
    --print(bn2hex(snum))

    --print("INIT sdiv")
    --print(bn2hex(sdiv))
    div_n=sdiv.top
    num_n=snum.top
    
    if(num_n <= div_n)then
        bn_expand(snum, div_n+1)
        memset(new_ptr(snum,num_n),0,div_n-num_n+1)
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
        --print('i=',i)
        --print(string.format("%04x %04x", wnumtop[0], wnumtop[-1]))
        --print(string.format("%04x %04x", d0, d1))
        --print(bn2hex(snum))
        q = bn_div_3_words(wnumtop,d1,d0)
        --print(string.format("Q=%x", q))
        l0=bn_mul_words(tmp.d, sdiv.d, div_n, q)
        tmp.d[div_n]=l0 -- add the carry black
        wnum=wnum-1

        --print("snum")
        --print(bn2hex(snum))
        --print("tmp")
        --print(bn2hex(tmp))

        l0=bn_sub_words(wnum,wnum,tmp.d, div_n+1)

        --print("after sub")
        --print(bn2hex(snum))
        q=q-l0

        --l0=0-l0
        if l0==0 then l0=0 else l0=BN_MASK2 end

        for j=0,div_n-1 do
            tmp.d[j]=bit.band(sdiv.d[j], l0)
        end
        --print(bn2hex(tmp))
        l0=bn_add_words(wnum,wnum,tmp.d,div_n)
        wnumtop[0]=bit.band(wnumtop[0]+l0, BN_MASK2)
        --wnumtop[0]=wnumtop[0]+l0
        --print(bn2hex(snum))
        if(wnumtop[0]~=0)then
            -- this number should be zero after this part of division
            -- otherwise something went wrong
            print("snum")
            printbn(snum)
            print("sdiv")
            printbn(sdiv)
            error('error *wnumtop~=0')
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
function bn_div(dv,rm,num,divisor)
    local ret
    ret=bn_div_fixed_top(dv,rm,num,divisor)
    if(ret==1)then
        if dv~=nil then
            bn_correct_top(dv)
        end
        if rm~=nil then
            bn_correct_top(rm)
        end
    end
    return ret
end

function bn_nnmod(r,m,d)
    bn_mod(r,m,d)
    if r.neg==0 then
        return 1
    end
    if d.neg==1 then
        bn_sub(r,r,d)
    else
        bn_add(r,r,d)
    end
    return 1
end

function bn_mod(rem,m,d)
    return bn_div(nil, rem, m ,d)
end

function bn_mod_sub(r,a,b,m)
    bn_sub(r,a,b)
    return bn_nnmod(r,r,m)
end

function bn_mod_mul(r,a,b,m)
    local t
    local ret=0
    bn_check_top(a)
    bn_check_top(b)
    bn_check_top(m)
    t=bn_new()
    bn_mul(t,a,b)
    bn_nnmod(r,t,m)
    bn_check_top(r)
    ret=1
    return ret
end
function neg(num)
    return bit.bnot(num)+1
end

function bn_gcd(r,in_a, in_b)-- not test yet
    local g,temp
    temp=nil
    local mask=0
    local i,j,top,rlen,glen,m
    local tbit,delta,cond,shifts,ret=1,1,0,0,0
    if bn_is_zero(in_b)==1 then
        ret=bn_copy(r,in_a)
        r.neg=0
        return ret
    elseif bn_is_zero(in_a)==1 then
        ret=bn_copy(r,in_b)
        r.neg=0
        return ret
    end
    --[[print('ina')
    print(textutils.serialiseJSON(in_a))
    print('inb')
    print(textutils.serialiseJSON(in_b))]]--
    bn_check_top(in_a)
    bn_check_top(in_b)

    temp=bn_new()
    g=bn_new()

    bn_lshift1(g,in_b)
    bn_lshift1(r,in_a)

    i=0
    while(i<r.dmax and i<g.dmax) do
        mask=bit.bnot(bit.bor(r.d[i],g.d[i]))
        for j=0,BN_BITS2-1 do
            tbit=bit.band(tbit,mask)
            shifts=shifts+tbit
            mask=bit.blogic_rshift(mask,1)
        end

        --loop end
        
        i=i+1
    end
    bn_rshift(r,r,shifts)
    bn_rshift(g,g,shifts)
    if r.top>=g.top then top=1+r.top else top=1+g.top end
    bn_expand(r,top)
    bn_expand(g,top)
    bn_expand(temp,top)

    bn_consttime_swap(bit.band(1,bit.bnot(r.d[0])),r,g,top)
    rlen=bn_num_bits(r)
    glen=bn_num_bits(g)
    if rlen>=glen then m=4+3*rlen else m=4+3*glen end

    for i=0, m-1 do
        --print(i)
        cond=bit.band(bit.blogic_rshift(-delta,8*2-1), g.d[0])
        cond=bit.band(cond, 1)
        cond=bit.band(cond,bit.blogic_rshift(bit.bnot(g.top-1), 2*8-1))
        delta=bit.bor(bit.band(-cond, -delta), bit.band((cond-1),delta))
        r.neg=bit.bxor(r.neg, cond)
        bn_consttime_swap(cond,r,g,top)
        delta=delta+1
        bn_add(temp,g,r)

        --print('temp')
        --print(textutils.serialiseJSON(temp))
        --print(textutils.serialiseJSON(g))

        local arg1=bit.blogic_rshift(bit.bnot(g.top-1),(2*8-1))
        arg1=bit.band(arg1,bit.band(g.d[0],1))
        bn_consttime_swap(arg1,g,temp,top)

        --print(textutils.serialiseJSON(temp))
        --print(textutils.serialiseJSON(g))
        --print('swap')

        bn_rshift1(g,g)
    end
    print("endloop shifts=",shifts)
    r.neg=0
    bn_lshift(r,r,shifts)
    print('shifted')
    print(textutils.serialiseJSON(r))
    bn_rshift1(r,r)
    
    ret=1
    return ret
end

function int_bn_mod_inverse(inn, a, n)--pnoinv=if no inverse exists
    -- but lua have no int pointer
    local A,B,X,Y,M,D,T,R
    local ret
    local sign
    local pnoinv
    bn_check_top(a)
    bn_check_top(n)

    A=bn_new()
    B=bn_new()
    X=bn_new()
    D=bn_new()
    M=bn_new()
    Y=bn_new()
    T=bn_new()
    if inn==nil then
        R=bn_new()
    else
        R=inn
    end
    bn_one(X)
    bn_zero(Y)
    bn_copy(B,a)
    bn_copy(A,n)
    A.neg=0

    if B.neg==1 or bn_ucmp(B,A)>=0 then
        bn_nnmod(B,B,A)
    end
    sign=-1
    local tmp
    while(bn_is_zero(B)==0)do

        bn_div(D,M,A,B)
        tmp=A
        A=B
        B=M
        if bn_is_one(D)==1 then
            bn_add(tmp,X,Y)
        else
            bn_mul(tmp,D,X)
            bn_add(tmp,tmp,Y)
        end
        M=Y
        Y=X
        X=tmp
        sign=-sign
    end

    if sign<0 then
        bn_sub(Y,n,Y)
    end
    if bn_is_one(A)==1 then
        if Y.neg==0 and bn_ucmp(Y,n)<0 then
            bn_copy(R,Y)
        else
            bn_nnmod(R,Y,n)
        end
    else
        pnoinv=1
        error('what')
    end 
    ret=R
    bn_check_top(ret)
    -- ret is the result, because inn can be nil and allocate by this function
    return ret 
end

function bn_mod_inverse(inn, a, n)
    local rv
    local noinv=0
    rv=int_bn_mod_inverse(inn, a, n)
    return rv
end

function bn_is_zero(a)
    if a.top==0 then return 1 else return 0 end
end

function bn_is_one(a)
    if bn_abs_is_word(a,1)==1 and a.neg==0 then return 1 else return 0 end
end
function bn_is_word(a,w)
    if bn_abs_is_word(a,w)==1 and (w==0 or a.neg==0) then
        return 1 
    else
        return 0
    end
end

function bn_abs_is_word(a, w)
    bn_correct_top(a)
    if (a.top==1 and a.d[0]==w) or (w==0 and a.top==0) then 
    return 1 else return 0 end
end
function bn_is_odd(a)
    if a.top>0 and bit.band(a.d[0],1)==1 then return 1 else return 0 end
end
function bn_is_bit_set(a,n)
    local i,j
    bn_check_top(a)
    if n<0 then return 0 end
    i=math.floor(n/BN_BITS2)
    j=n%BN_BITS2
    if a.top<=i then return 0 end
    return bit.band(bit.blogic_rshift(a.d[i],j),1)
end

function bn_set_bit(a, n)
    -- n is index of bit, not number of bit
    local i,j,k
    if n<0 then
        return 0
    end
    i=math.floor(n/BN_BITS2)
    j=n%BN_BITS2
    if(a.top<=i)then
        bn_expand(a, i+1)
        for k=a.top, i do
            a.d[k]=0
        end
        a.top=i+1
    end
    a.d[i] = bit.bor(a.d[i],bit.blshift(1,j))
    bn_check_top(a)

    return 1
end

function bn_num_bits(bn)
    local i=bn.top-1
    bn_check_top(bn)
    if bn_is_zero(bn)==1 then return 0 end
    return ((i*BN_BITS2)+bn_num_bit_word(bn.d[i]))
end

function bn_set_word(a,w)
    bn_check_top(a)
    bn_expand(a,1)
    a.neg=0
    a.d[0]=w
    if w==0 then
        a.top=0
    else
        a.top=1
    end
    bn_check_top(a)
    return 1
end

function bn_value_one()
    local const_one=bn_new()
    bn_set_word(const_one, 1)
    return const_one
end

function bn_mod_word(a,w)
    local ret=0
    local i
    if w==0 then
        return BN_MASK2
    end
    w=bit.band(w,BN_MASK2)
    for i=a.top-1, 0, -1 do
        ret=bit.bor(bit.blshift(ret,BN_BITS2),a.d[i])%w
    end
    return ret
end

function bn_add_word(a,w)
    local l,i
    w=bit.band(w,BN_MASK2)
    if w==0 then return 1 end
    if bn_is_zero(a)==1 then
        return bn_set_word(a,w)
    end
    if a.neg==1 then
        a.neg=0
        i=bn_sub_word(a,w)
        if bn_is_zero(a)==0 then
            a.neg=bit.bnot(a.neg)
        end
        return i
    end
    --else
    i=0
    while w~=0 and i<a.top do
        l=bit.band((a.d[i]+w),BN_MASK2)
        a.d[i]=l
        if w>l then w=1 else w=0 end
        --loopend
        i=i+1
    end
    if w==1 and i==a.top then
        bn_expand(a,a.top+1)
        a.top=a.top+1
        a.d[i]=w
    end
    return 1
end
function bn_sub_word(a,w)
    local i
    w=bit.band(w,BN_MASK2)
    if w==0 then return 1 end
    if bn_is_zero(a)==1 then
        i=bn_set_word(a,w)
        if i~=0 then
            a.neg=1
        end
        return i
    end
    if a.neg==1 then
        a.neg=0
        i=bn_add_word(a,w)
        a.neg=1
        return i
    end
    if a.top==1 and a.d[0]<w then
        a.d[0]=w-a.d[0]
        a.neg=1
        return 1
    end
    i=0
    while true do
        if a.d[i]>=w then
            a.d[i]=a.d[i]-w
            break
        else
            a.d[i]=bit.band(a.d[i]-w)
            i=i+1
            w=1
        end

    end
    if a.d[i]==0 and i==(a.top-1) then
        a.top=a.top-1
    end
    return 1
end
function bitstr(num)
    local bitstr=''
    for i=1,32 do
        if bit.band(num, 0x80000000)==0 then
            bitstr=bitstr..'0'
        else
            bitstr=bitstr..'1'
        end
        if i%8==0 and i~=32 then
            bitstr=bitstr..' '
        end
        num=bit.blshift(num,1)
    end
    --print(bitstr)
    return bitstr
end

---- MONT ----
function bn_consttime_swap(condition, a, b, nwords)
    local t, i
    if(a==b) then return end

    condition=(bit.blogic_rshift(bit.band(bit.bnot(condition),(condition-1)),(BN_BITS2-1)))
    if condition==0 then
        condition=BN_MASK2
    end
    --print('condition:',bitstr(condition))
    t=bit.band(bit.bxor(a.top, b.top), condition)
    a.top=bit.bxor(a.top,t)
    b.top=bit.bxor(b.top,t)
    t=bit.band(bit.bxor(a.neg, b.neg), condition)
    a.neg=bit.bxor(a.neg,t)
    b.neg=bit.bxor(b.neg,t)
    for i=0, nwords-1 do
        t=bit.band(bit.bxor(a.d[i],b.d[i]), condition)
        a.d[i]=bit.band(bit.bxor(a.d[i],t),BN_MASK2)
        b.d[i]=bit.band(bit.bxor(b.d[i],t),BN_MASK2)
    end
end

function bn_mont_ctx_new()
    local ret
    ret={}
    ret = bn_mont_ctx_init(ret)
    return ret
end

function bn_mont_ctx_init(ctx)
    ctx.ri=0
    ctx.RR=bn_new()
    ctx.N=bn_new()
    ctx.Ni=bn_new()
    bn_zero(ctx.RR)
    bn_zero(ctx.N)
    bn_zero(ctx.Ni)
    ctx.n0=new_ptr({0,0})
    return ctx
end

function bn_mont_ctx_set(mont, mod)
    -- RR, ri, N, Ni
    local i, ret
    ret=0
    local Ri, R
    Ri=bn_new()
    R=mont.RR
    bn_copy(mont.N, mod)
    mont.N.neg=0

    mont.ri=bn_num_bits(mont.N)
    bn_zero(R)
    
    bn_set_bit(R, mont.ri)
    --print("R")
    --print(bn2hex(mont.N))
    bn_mod_inverse(Ri,R,mont.N) --ERR
    --print("EEE")
    bn_lshift(Ri,Ri,mont.ri)
    bn_sub_word(Ri, 1)
    -- Ni=(R*Ri-1)/N
    
    bn_div(mont.Ni, nil, Ri, mont.N)
    --print("EEE")
    bn_zero(mont.RR)
    bn_set_bit(mont.RR, mont.ri*2)
    bn_mod(mont.RR, mont.RR, mont.N)
    ret=mont.N.top
    for i=mont.RR.top, ret-1 do
        mont.RR.d[i]=0
    end
    mont.RR.top=ret
    ret=1
    return ret
end

function bn_mask_bits(a,n)
    local b,w
    bn_check_top(a)
    w=math.floor(n/BN_BITS2)
    b=n%BN_BITS2
    if w>=a.top then return 0 end
    if b==0 then
        a.top=w
    else
        a.top=w+1
        a.d[w]=bit.band(a.d[w],bit.bnot(bit.blshift(BN_MASK2,b)))
    end
    bn_check_top(a)
    return 1
end

function bn_from_mont_fixed_top(ret, a, mont)
    local retn=0
    local t1,t2
    t1=bn_new()
    t2=bn_new()
    bn_copy(t1,a)
    bn_mask_bits(t1,mont.ri)

    bn_mul(t2,t1,mont.Ni)
    bn_mask_bits(t2,mont.ri)

    bn_mul(t1,t2,mont.N)
    bn_add(t2,a,t1)
    bn_rshift(ret,t2,mont.ri)
    if bn_ucmp(ret, mont.N)>=0 then
        bn_usub(ret,ret,mont.N)
    end
    retn=1
    bn_check_top(ret)
    return retn
end

function bn_from_montgomery(ret, a, mont)
    local retn
    retn = bn_from_mont_fixed_top(ret, a, mont)
    bn_correct_top(ret)
    bn_check_top(ret)
    if retn==0 then
        error('ERR bn_from_mont')
    end
    return retn
end

function bn_mul_mont_fixed_top(r,a,b,mont)
    local tmp
    local ret
    local num=mont.N.top
    if (a.top+b.top)>2*num then return 0 end

    tmp=bn_new()
    bn_check_top(tmp)
    bn_mul_fixed_top(tmp,a,b)
    bn_from_montgomery(r,tmp,mont)
    ret=1
    return ret
end

function bn_to_mont_fixed_top(r,a,mont)
    return bn_mul_mont_fixed_top(r,a,mont.RR, mont)
end


function bn_window_bits_for_exponent_size(b)
    if b>671 then return 6 end
    if b>239 then return 5 end
    if b>79 then return 4 end
    if b>23 then return 3 end
    return 1
end

function bn_mod_exp_mont(rr,a,p,m, in_mont)
    local i,j,bits,ret,wstart,wend,window,wvalue
    ret=0
    local start=1
    local d,r
    local aa
    local val=new_ptr()
    for i=1,32 do table.insert(val,0) end
    local mont=nil

    bn_check_top(a)
    bn_check_top(p)
    bn_check_top(m)

    --print(bn2hex(p))
    --print(textutils.serialiseJSON(p))
    bits=bn_num_bits(p)
    
    if(bits==0)then
        if bn_abs_is_word(m,1)then
            ret=1
            bn_zero(rr)
        else 
            ret=bn_one(rr)
        end
        return ret
    end

    d=bn_new()
    r=bn_new()
    val[0]=bn_new()
    --print("START MONT set")
    if in_mont~=nil then
        mont=in_mont
    else
        mont=bn_mont_ctx_new()
        bn_mont_ctx_set(mont, m)
    end
    --print("MONT CTX set")
    if a.neg==1 or bn_ucmp(a,m)>=0 then
        bn_nnmod(val[0],a,m)
        aa=val[0]
    else
        aa=a
    end
    bn_to_mont_fixed_top(val[0],aa,mont)
    window = bn_window_bits_for_exponent_size(bits)
    if window>1 then
        bn_mul_mont_fixed_top(d,val[0],val[0],mont)
        j = bit.blshift(1,window-1)
        for i=1, j-1 do
            val[i]=bn_new()
            bn_mul_mont_fixed_top(val[i],val[i-1],d,mont)
        end
    end
    start=1

    wvalue=0
    wstart=bits-1
    wend=0
    
    bn_to_mont_fixed_top(r, bn_value_one(), mont)
    local CONTINUE=false
    --print("LOOP start")
    while true do
        if bn_is_bit_set(p,wstart)==0 then
            if start==0 then
                bn_mul_mont_fixed_top(r,r,r,mont)
            end
            if wstart==0 then
                break
            end
            wstart=wstart-1
            --goto continue
            CONTINUE=true
        end
        if not CONTINUE then
            wvalue=1
            wend=0
            for i=1, window-1 do
                if (wstart-i)<0 then break end

                if bn_is_bit_set(p, wstart-i)==1 then
                    wvalue=bit.blshift(wvalue,i-wend)
                    wvalue=bit.bor(wvalue,1)
                    wend=i
                end
            end

            j=wend+1
            if start==0 then
                for i=0, j-1 do
                    bn_mul_mont_fixed_top(r,r,r,mont)
                end
            end
            bn_mul_mont_fixed_top(r,r,val[bit.blogic_rshift(wvalue,1)],mont)

            wstart=wstart-(wend+1)
            wvalue=0
            start=0
            if wstart<0 then
                break 
            end

        end
        CONTINUE=false
        --::continue::
    end
    --print(bn2hex(r))
    bn_from_montgomery(rr,r,mont)
    ret=1
    return ret
end

function RAND_bytes(buf,num)
    math.randomseed(os.epoch('utc'))
    local words=math.ceil(num/BN_BYTES2)
    local byte=num%BN_BYTES2
    for i=1,words do
        table.insert(buf.d, math.random(0,BN_MASK2))
    end
    if byte~=0 then
        buf[words-1]=bit.band(buf[words-1], bit.blogic_rshift(BN_MASK2,BN_BYTES2-byte))
    end
    return 1
end
function bnrand(rnd,bits,top,bottom)
    local buf=new_ptr()
    local tbit,bytes,mask, words,byte

    bytes=math.floor((bits+7)/8)
    words=math.floor((bits+BN_BITS2-1)/BN_BITS2)
    tbit=(bits-1)%BN_BITS2
    byte=tbit%8
    mask=bit.blshift(BN_MASK2, tbit+1)

    RAND_bytes(buf,bytes)
    --print('buf')
    --print(textutils.serialiseJSON(buf))
    local w1=words-1
    if top>=0 then
        if top~=0 then
            if byte==0 then
                buf[words-1]=1
                buf[words-2]=bit.bor(buf[words-2],bit.blshift(0x80),byte*8)
            else
                buf[words-1]=bit.bor(buf[words-1], bit.blshift(3,tbit-1))
            end
        else
            buf[words-1]=bit.bor(buf[words-1], bit.blshift(1,tbit))
        end
    end
    buf[w1]=bit.band(buf[w1],bit.bnot(mask))
    if bottom~=0 then
        buf[0]=bit.bor(buf[0],1)
    end
    bn_expand(rnd,words)
    rnd.top=words
    rnd.d=buf
    return 1
end
function bnrand_range(r, range)
    local n
    local count=100

    if range.neg==1 or bn_is_zero(range) then return 0 end

    n=bn_num_bits(range)
    if n==1 then
        bn_zero(r)
    else
        bnrand(r,n,-1,0)
        count=count-1
        while(bn_cmp(r,range)>=0)do
            bnrand(r,n,-1,0)
            count=count-1
            if count==0 then
                error("bnrand_range TOO MANY ITERATIONS")
                return 0
            end
        end
    end
    bn_check_top(r)
    return 1
end
local bn_priv_rand_range_ex=bnrand_range
local bn_priv_rand_ex=bnrand
local bn_rand_ex=bnrand

function calc_trial_divisions(bits)
    if bits<= 512 then return 64 end
    if bits<= 1024 then return 128 end
    if bits<= 2048 then return 384 end
    if bits<= 4096 then return 1024 end
    error("TOO LARGE")
end
function bn_mr_min_checks(bits) if bits>2048 then return 128 else return 64 end end
--function bn_mr_min_checks(bits) if bits>2048 then return 10 else return 10 end end


function ossl_bn_miller_rabin_is_prime(w, iterations, enhanced, status)
    local i,j,a,ret
    ret=0
    local g,w1,w3,x,m,z,b
    local mont=nil

    if bn_is_odd(w)==0 then return 0 end
    g=bn_new()
    w1=bn_new()
    w3=bn_new()
    x=bn_new()
    m=bn_new()
    z=bn_new()
    b=bn_new()
    bn_copy(w1,w)
    bn_sub_word(w1,1)
    bn_copy(w3,w)
    bn_sub_word(w3,3)
    print('w:')
    print(bn2hex(w))
    if bn_is_zero(w3)==1 or w3.neg==1 then error('miller rabin err') end

    a=1
    while(bn_is_bit_set(w1,a)==0)do a=a+1 end

    bn_rshift(m,w1,a)

    mont=bn_mont_ctx_new()
    bn_mont_ctx_set(mont,w)
    if iterations==0 then iterations=bn_mr_min_checks(bn_num_bits(w)) end
    local GOTO_COMPOSITE, GOTO_OUTERLOOP, GOTO_ERR=false,false,false
    for i=0, iterations-1 do
        sleep(0.0000001)
        bn_priv_rand_range_ex(b,w3)
        bn_add_word(b,2)
        if enhanced~=0 then
            bn_gcd(g,b,w)
            if bn_is_one(g)==0 then 
                status.status=0
                GOTO_ERR=true--maybe just break this for loop
                ret=1
                break
            end --composite
        end

        bn_mod_exp_mont(z,b,m,w,mont)
        if bn_is_one(z)==1 or bn_cmp(z,w1)==0 then
            GOTO_OUTERLOOP=true
        end
        if not GOTO_OUTERLOOP then
            for j=1,a-1 do
                bn_copy(x,z)
                bn_mod_mul(z,x,x,w)
                if bn_cmp(z,w1)==0 then
                    GOTO_OUTERLOOP=true
                    break
                end
                if bn_is_one(z)~=0 then
                    GOTO_COMPOSITE=true
                    break
                end
            end
        end
        if not (GOTO_OUTERLOOP or GOTO_COMPOSITE) then
            bn_copy(x,z)
            bn_mod_mul(z,x,x,w)
            if bn_is_one(z)==1 then
                GOTO_COMPOSITE=true
            end
            if not GOTO_COMPOSITE then
                bn_copy(x,z)
            end
        end
        -- composite:
        if not GOTO_OUTERLOOP then
            if enhanced~=0 then
                bn_sub_word(x,1)
                bn_gcd(g,x,w)
                if bn_is_one(g)~=0 then
                    status.status=0
                else
                    status.status=0
                end
            else --not enhanced
                status.status=0
            end 
            ret=1
            GOTO_ERR=true
            break
        end
        GOTO_COMPOSITE=false
        -- outerloop:
        GOTO_OUTERLOOP=false
    end--end for
    if not GOTO_ERR then
        status.status=1
        ret=1
    end
    --err
    return ret
end

function bn_is_prime_int(w,checks,do_trial_division)
    local i,status, ret
    ret=-1
    if bn_cmp(w,bn_value_one())<=0 then return 0 end

    if bn_is_odd(w)==1 then
        if bn_is_word(w,3)==1 then
            return 1
        end
    else
        return bn_is_word(w,2)
    end
    local trial_divisions, mod
    if do_trial_division~=0 then
        trial_divisions=calc_trial_divisions(bn_num_bits(w))
        for i=1,trial_divisions-1 do
            mod=bn_mod_word(w,primes[i])
            if mod==BN_MASK2 then
                error('mod error')
                return -1--ERR
            end
            if mod==0 then
                return bn_is_word(w,primes[i])
            end
        end
    end
    status={status=nil}
    print("ml")
    ret=ossl_bn_miller_rabin_is_prime(w,checks,0, status)
    print("mlend", textutils.serialiseJSON(status))
    if status.status==1 then
        ret=1
    else
        ret=0
    end
    return ret
end
function bn_check_prime_int(w,checks,do_trial_division)
    local min_checks=bn_mr_min_checks(bn_num_bits(w))
    if checks<min_checks then
        checks=min_checks
    end
    local r=bn_is_prime_int(w,checks,do_trial_division)
    return r
end
function bn_check_prime(p)
    local r=bn_check_prime_int(p,0,1)
    return r
end
function bn_rsa_fips186_4_aux_prime_min_size(nbits)
    if nbits>=3072 then return 171 end
    if nbits>=2048 then return 141 end
    return 0
end
function bn_rsa_fips186_4_aux_prime_max_sum_size_for_prob_primes(nbits)
    if nbits>=3072 then return 1518 end
    if nbits>=2048 then return 1007 end
    return 0
end
function bn_rsa_fips186_4_find_aux_prob_prime(Xp1,p1)
    local ret=0
    local i=0
    bn_copy(p1,Xp1)
    while true do
        i=i+1
        if bn_check_prime(p1)==1 then break end
        bn_add_word(p1,2)
    end
    ret=1
    return ret
end
--function ternary(cont,T,F) if cont then return T else return F end

function ossl_bn_rsa_fips186_4_gen_prob_primes(p,Xpout,
                                               p1,p2,Xp,Xp1,Xp2,nlen,e)
    local ret=0
    local p1i,p2i,Xp1i,Xp2i=nil,nil,nil,nil
    local bitlen
    if p1~=nil then p1i=p1 else p1i=bn_new() end
    if p2~=nil then p2i=p2 else p2i=bn_new() end
    if Xp1~=nil then Xp1i=Xp1 else Xp1i=bn_new() end
    if Xp2~=nil then Xp2i=Xp2 else Xp2i=bn_new() end
    bitlen=bn_rsa_fips186_4_aux_prime_min_size(nlen)
    if bitlen==0 then error('bitlen==0') end
    print("XP1 go")
    if Xp1==nil then
        bn_priv_rand_ex(Xp1i,bitlen,0,1)
    end
    print('XP1 gened')
    if Xp2==nil then
        bn_priv_rand_ex(Xp2i,bitlen,0,1)
    end

    bn_rsa_fips186_4_find_aux_prob_prime(Xp1i,p1i)
    bn_rsa_fips186_4_find_aux_prob_prime(Xp2i,p2i)
    print("two aux found")
    if bn_num_bits(p1i)+bn_num_bits(p2i)>=bn_rsa_fips186_4_aux_prime_max_sum_size_for_prob_primes(nlen)then
        error('sum error')
        return 0
    end
    print("start derive prime")
    ossl_bn_rsa_fips186_4_derive_prime(p,Xpout,Xp,p1i,p2i,nlen,e)
    return 1
end
function ossl_bn_rsa_fips186_4_derive_prime(Y,X,Xin,r1,r2,nlen,e)
    if (Y==nil or X==nil or r1==nil or r2==nil or e==nil) then 
        error("4 derive prime get nil")
    end
    local ret=0
    local i,imax
    local bits=bit.blogic_rshift(nlen,1)
    local tmp,R,r1r2x2,y1,r1x2
    local base,range

    base=bn_new()
    range=bn_new()
    R=bn_new()
    tmp=bn_new()
    r1r2x2=bn_new()
    y1=bn_new()
    r1x2=bn_new()

    if Xin~=nil then
        bn_copy(X,Xin)
    end
    if Xin==nil then
        print("NUMING inv")
        if bits<bn_num_bits(ossl_bn_inv_sqrt_2) then
            error('ERR')
            return 0
        end
        print("NUMING inv")
        bn_lshift(base,ossl_bn_inv_sqrt_2,bits-bn_num_bits(ossl_bn_inv_sqrt_2))
        bn_lshift(range,bn_value_one(),bits)
        bn_sub(range,range,base)
    end
    bn_lshift1(r1x2,r1)
    print("Gcd")
    bn_gcd(tmp,r1x2,r2)
    print("Gcdend")
    if bn_is_one(tmp)==0 then return 0 end
    print("modinv")
    bn_mod_inverse(R,r2,r1x2)
    bn_mul(R,R,r2)
    bn_mod_inverse(tmp,r1x2,r2)
    print("modinvend")
    bn_mul(tmp,tmp,r1x2)
    bn_sub(R,R,tmp)
    bn_mul(r1r2x2,r1x2,r2)

    if R.neg==1 and bn_add(R,R,r1r2x2) then
        error("ERR")
        return 0
    end
    print("Lstart")
    imax=5*bits
    local GOTO_END=false
    while true do
        sleep(0.000001)
        if Xin==nil then
            bn_priv_rand_range_ex(X,range)
            bn_add(X,X,base)
        end
        bn_mod_sub(Y,R,X,r1r2x2)
        bn_add(Y,Y,X)
        i=0
        while true do
            sleep(0.000001)
            if bn_num_bits(Y)>bits then
                if Xin==nil then
                    break
                else
                    error("ERR")
                end
            end
            bn_copy(y1,Y)
            bn_sub_word(y1,1)
            bn_gcd(tmp,y1,e)
            if bn_is_one(tmp)~=0 and bn_check_prime(Y)==1 then
                GOTO_END=true
                break
            end
            i=i+1
            if i>=imax then error('i>=imax') end
            bn_add(Y,Y,r1r2x2)
            
        end
        
        if GOTO_END then break end
    end
    print("Lend")
    ret=1
    return ret
end
--RSA_CHECK
function ossl_rsa_check_pminusq_diff(diff,p,q,nbits)
    local bitlen=bit.blogic_rshift(nbits,1)-100
    bn_sub(diff,p,q)
    diff.neg=0
    if bn_is_zero(diff)==1 then
        return 0
    end
    bn_sub_word(diff,1)
    if bn_num_bits(diff)>bitlen then return 1 else return 0 end
end
function ossl_rsa_check_public_exponent(e)
    local bitlen
    if bn_is_word(e,3)==1 then
        return 1
    end
    bitlen=bn_num_bits(e)
    print(textutils.serialiseJSON(e))
    print("bitlen=",bitlen)
    if bn_is_odd(e)==1 and bitlen>16 and bitlen<257 then
        return 1 
    else
        return 0 
    end
end

function ossl_rsa_fips186_4_gen_prob_primes(rsa,nbits,e)
    local ret,ok
    ret=0
    local Xpo,Xqo,tmp=nil,nil,nil
    local p1,p2
    local q1,q2
    local Xpout,Xqout
    local Xp,Xp1,Xp2
    local Xq,Xq1,Xq2

    if nbits < RSA_FIPS1864_MIN_KEYGEN_KEYSIZE then
        error("RSA bit too small")
    end
    if ossl_rsa_check_public_exponent(e)==0 then
        error("ERR rsa public exponenet check error")
    end

    tmp=bn_new()
    if Xpout~=nil then Xpo=Xpout else Xpo=bn_new() end
    if Xqout~=nil then Xqo=Xqout else Xqo=bn_new() end

    if rsa.p==nil then rsa.p=bn_new() end
    if rsa.q==nil then rsa.q=bn_new() end
    print("start gen p,Xp")
    ossl_bn_rsa_fips186_4_gen_prob_primes(rsa.p, Xpo,p1,p2,Xp,Xp1,Xp2,
                                          nbits, e)
    print("p gened")
    while true do
        ossl_bn_rsa_fips186_4_gen_prob_primes(rsa.q, Xqo,q1,q2,Xq,Xq1,Xq2,
                                              nbits,e)
        ok=ossl_rsa_check_pminusq_diff(tmp,Xqo,Xqo,nbits)
        if ok<0 then return 0 end
        if ok~=0 then --ok==0 continue
            ok=ossl_rsa_check_pminusq_diff(tmp,rsa.p,rsa.q,nbits)
            if ok<0 then return 0 end
            if ok~=0 then --ok==0 continue
                break 
            end
        end
    end
    ret=1
    if Xpo~=Xpout then
        --bn_clear(Xpo)
    end
    if Xqo~=Xqout then
        --bn_clear(Xqo)
    end
    --bn_clear(tmp)
    return ret
end

function ossl_rsa_sp800_56b_derive_params_from_pq(rsa,nbits,e)
    local ret=-1
    local p1,q1,lcm,p1q1,gcd
    p1=bn_new()
    q1=bn_new()
    lcm=bn_new()
    p1q1=bn_new()
    gcd=bn_new()
    ossl_rsa_get_lcm(rsa.p,rsa.q,lcm,gcd,p1,q1,p1q1)
    print('get lcm')
    --bn_free(e)
    rsa.e=bn_dup(e)
    --bn_clear_free(rsa.d)
    rsa.d=bn_new()
    bn_mod_inverse(rsa.d,e,lcm)
    if bn_num_bits(rsa.d)<=bit.blogic_rshift(nbits,1) then
        return 0
    end
    -- n=p*q
    if rsa.n==nil then rsa.n=bn_new()end
    bn_mul(rsa.n,rsa.p,rsa.q)
    -- dP = d mod(p-1)
    if rsa.dmp1==nil then rsa.dmp1=bn_new() end
    bn_mod(rsa.dmp1,rsa.d,p1)
    -- dQ = d mod(q-1)
    if rsa.dmq1==nil then rsa.dmq1=bn_new() end
    bn_mod(rsa.dmq1,rsa.d,q1)
    --bn_free(rsa.iqmp)
    rsa.iqmp=bn_new()
    bn_mod_inverse(rsa.iqmp, rsa.q, rsa.p)
    ret=1
    ---ret==0 ...some error free process
    return ret
end
function ossl_rsa_sp800_56b_pairwise_test(rsa)
    local ret=0
    local k,tmp

    tmp=bn_new()
    k=bn_new()
    bn_set_word(k,2)
    bn_mod_exp(tmp,k,rsa.e,rsa.n)
    bn_mod_exp(tmp,tmp,rsa.d,rsa.n)
    if bn_cmp(k,tmp)==0 then
        ret=1
    else
        ret=0
    end
    if ret==0 then
        print("rsa pairwise test failed")
    end
    return ret
end
function ossl_rsa_sp800_56b_generate_key(rsa,nbits,efixed)
    local ret=0
    local ok
    local e=nil
    if efixed==nil then 
        --e=bn_new()
        --bn_set_word(e,65537)
        e=hex2bn('10001')
    else
        e=efixed
    end

    while true do
        ossl_rsa_fips186_4_gen_prob_primes(rsa,nbits,e)
        print("rsa gen prime ok")
        ok=ossl_rsa_sp800_56b_derive_params_from_pq(rsa,nbits,e)
        if ok<0 then
            error('rsa derive prime failed')
        end
        if ok>0 then
            break
        end
        print("rsa derive prime ok")
    end
    ret=ossl_rsa_sp800_56b_pairwise_test(rsa)
    if ret==0 then
        print("rsa pairwise test failed")
    end
    if efixed==nil then
        --bn_free(e)
    end
    return ret
end

function mul_test()
    local hex1 = "-aafffe"
    local d = hex2bn(hex1)
    print(textutils.serialiseJSON(d))
    print(bn2hex(d))

    local hex1 = "aaffff"
    local e = hex2bn(hex1)
    print(textutils.serialiseJSON(e))
    print(bn2hex(e))

    local hex10="10"
    local ten=hex2bn(hex10)
    print(textutils.serialiseJSON(ten))
    print(bn2hex(ten))

    --g = new_bn()
    --bn_add(g, d, e)
    --print(textutils.serialiseJSON(g))
    --print(bn2hex(g))

    local f = new_bn()
    bn_mul(f, d, e)
    --bn_check_top(f)
    print("f bn")
    print(textutils.serialiseJSON(f))
    print(bn2hex(f))
end
function div_test()
    local ha="abeef110"
    local hb="accdeee"

    local a,b=hex2bn(ha),hex2bn(hb)
    local dv,rm=new_bn(),new_bn()

    
    print(bn2hex(a))
    print(bn2hex(b))
    print("start div")
    bn_div(dv,rm,a,b)
    print("result")
    print(textutils.serialiseJSON(dv))
    print(bn2hex(dv))
    print(textutils.serialiseJSON(rm))
    print(bn2hex(rm))
end

function exp_test()
    local start_epoch=os.epoch('utc')
    local he='10001'
    local hd='10f22727e552e2c86ba06d7ed6de28326eef76d0128327cd64c5566368fdc1a9f740ad8dd221419a5550fc8c14b33fa9f058b9fa4044775aaf5c66a999a7da4d4fdb8141c25ee5294ea6a54331d045f25c9a5f7f47960acbae20fa27ab5669c80eaf235a1d0b1c22b8d750a191c0f0c9b3561aaa4934847101343920d84f24334d3af05fede0e355911c7db8b8de3bf435907c855c3d7eeede4f148df830b43dd360b43692239ac10e566f138fb4b30fb1af0603cfcf0cd8adf4349a0d0b93bf89804e7c2e24ca7615e51af66dccfdb71a1204e2107abbee4259f2cac917fafe3b029baf13c4dde7923c47ee3fec248390203a384b9eb773c154540c5196bce1'
    local hn='a709e2f84ac0e21eb0caa018cf7f697f774e96f8115fc2359e9cf60b1dd8d4048d974cdf8422bef6be3c162b04b916f7ea2133f0e3e4e0eee164859bd9c1e0ef0357c142f4f633b4add4aab86c8f8895cd33fbf4e024d9a3ad6be6267570b4a72d2c34354e0139e74ada665a16a2611490debb8e131a6cffc7ef25e74240803dd71a4fcd953c988111b0aa9bbc4c57024fc5e8c4462ad9049c7f1abed859c63455fa6d58b5cc34a3d3206ff74b9e96c336dbacf0cdd18ed0c66796ce00ab07f36b24cbe3342523fd8215a8e77f89e86a08db911f237459388dee642dae7cb2644a03e71ed5c6fa5077cf4090fafa556048b536b879a88f628698f0c7b420c4b7'
    local hplain='1234'

    local e=hex2bn(he)
    local d=hex2bn(hd)
    local n=hex2bn(hn)
    local plain=hex2bn(hplain)
    local rs=new_bn()
    --print(bn2hex(e))
    --print(bn2hex(d))
    --print(bn2hex(n))
    print(bn2hex(plain))
    print("start exp")
    bn_mod_exp_mont(rs,plain,e,n,nil)
    print(textutils.serialiseJSON(rs))
    print(bn2hex(rs))
    --bn_mod_exp_mont(plain,rs,d,n,nil)
    print('plain result:')
    print(bn2hex(plain))
    print("time elapsed: ",(os.epoch('utc')-start_epoch)/1000, " s")
end

function rsa_test()
    local rsa={}
    local nbits=2048
    local efixed=nil
    ossl_rsa_sp800_56b_generate_key(rsa,nbits,efixed)
    print(textutils.serialiseJSON(rsa))
end
function prime_test()
    local ph='10001'
    local pbn=hex2bn(ph)
    print(textutils.serialiseJSON(pbn))
    local status={status=0}
    local res=ossl_bn_miller_rabin_is_prime(pbn,0,0, status)
    print(textutils.serialiseJSON(status))
end

ok,err=xpcall(rsa_test, function(err) print(err) end)

if not ok then
    --printError(debug.traceback(err))
end
