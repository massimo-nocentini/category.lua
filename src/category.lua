
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
    return string.format ('just (%s)', tostring (cat.value))
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
    return string.format ('list (%s)', table.concat (s, ', '))
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
    return string.format ('fun (%s)', tostring (cat.value))
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

return C
