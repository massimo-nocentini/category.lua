
local C = { }

local just = {}
just.__index = just

function C.just (v)

    local j = {value = v}
    setmetatable (j, just)

    return j
end

function just.__eq (v, w)
    if getmetatable (w) == just then return v.value == w.value
    else return false end
end

function just.__tostring (cat)
    return string.format ('%s :: just', tostring (cat.value))
end

function just.fmap (cat, f)
    return C.just ( f (cat.value) )
end

function just.pure (cat, v)
    return C.just (v)
end

function just.applicative (cat, cat_f)
    return cat:fmap (cat_f.value)
end

just.ret = just.pure

function just.bind (cat, f)
    return f (cat.value)
end


local list = {}
list.__index = list

function C.list (v)

    local j = {value = v}
    setmetatable (j, list)

    return j
end

function list.__eq (v, w)
    if getmetatable (w) == list then 
        local lv, lw = v.value, w.value
        if #lv == #lw then
            local eq = true
            for i = 1, #lv do eq = eq and lv[i] == lw[i] end
            return eq
        else return false end
    else return false end
end

function list.__tostring (cat)
    local s = {}
    for i, v in ipairs (cat.value) do s[i] = tostring (v) end
    return string.format ('{ %s } :: list', table.concat (s, ', '))
end

function list.fmap (cat, f)
    local l = {}
    for i, v in pairs (cat.value) do l[i] = f (v) end
    return C.list (l)
end

function list.pure (cat, v)
    return C.list {v}
end

function list.applicative (cat, cat_f)
    local l = {}
    for i, f in ipairs (cat_f.value) do
        for j, v in ipairs (cat.value) do
            table.insert (l, f(v))
        end
    end
    return C.list (l)
end

function list.mempty (cat)
    return C.list {}
end

function list.mappend (cat, rest_cat)
    local l = {}
    for i, v in ipairs (cat.value) do table.insert (l, v) end
    for i, v in ipairs (rest_cat.value) do table.insert (l, v) end
    return C.list (l)
end

list.ret = list.pure

function list.concat (cat)
    local l = {}
    for i, v in ipairs (cat.value) do
        for j, w in ipairs (v.value) do
            table.insert (l, w)
        end
    end
    return C.list (l)
end

function list.bind (cat, f)
    return cat:fmap (f):concat ()
end

local fun = {}
fun.__index = fun

function C.fun (v)

    local j = {value = v}
    setmetatable (j, fun)

    return j
end

function fun.__eq (v, w)
    if getmetatable (w) == fun then return v.value == w.value 
    else return false end
end

function fun.__tostring (cat)
    return string.format ('%s :: fun', tostring (cat.value))
end

function fun.__call (cat, ...)
    return cat.value (...)
end

function fun.fmap (cat, f)
    return C.fun (function (...) return f (cat.value (...)) end)
end

function fun.pure (cat, v)
    return function (...) return v end
end

function fun.applicative (cat, cat_f)
    return C.fun(function (w) return  cat_f.value (w) (cat.value (w)) end)
end


local product = {}
product.__index = product

function C.product (v)

    local j = {value = v}
    setmetatable (j, product)

    return j
end

function product.__eq (v, w)
    if getmetatable (w) == product then return v.value == w.value
    else return false end
end

function product.__tostring (cat)
    return string.format ('%s :: product', tostring (cat.value))
end

function product.mempty (cat)
    return C.product (1)
end

function product.mappend (cat, rest_cat)
    return C.product (cat.value * rest_cat.value)
end

-----------------------------------------------------------------------

function C.fmap (f)
    return function (cat) 
        return cat:fmap (f)
    end
end

function C.applicative (cat_f)
    return function (cat) 
        return cat:applicative (cat_f)
    end
end

function C.bind (cat)
    return function (f) 
        return cat:bind (f)
    end
end

function C.mempty (cat)
    return cat:mempty ()
end

function C.mappend (cat)
    return function (another_cat)
        return cat:mappend (another_cat)
    end
end

return C
