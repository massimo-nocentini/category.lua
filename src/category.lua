
local lua = require 'liblualua'

local C = { }

-----------------------------------------------------------------------

local just = {}

local just_mt = {
    __index = just, -- where you can find functions.
}

function just_mt.__eq (v, w)
    if getmetatable (w) == just_mt then return v.value == w.value
    else return false end
end

function just_mt.__tostring (cat)
    return string.format ('%s :: just', tostring (cat.value))
end

function C.just (v)

    local j = {value = v}
    setmetatable (j, just_mt)

    return j
end

function just.fmap (cat, f) return C.just ( f (cat.value) ) end
function just.pure (cat, v) return C.just (v) end
function just.applicative (cat, cat_f) return cat:fmap (cat_f.value) end
just.ret = just.pure
function just.bind (cat, f) return f (cat.value) end

function just.mappend (cat, another)
    return C.just (cat.value:mappend (another.value))
end

just_mt.__concat = just.mappend

-----------------------------------------------------------------------

local list = {}
local list_mt = {__index = list}

function list_mt.__eq (v, w)
    if getmetatable (w) == list_mt then 
        local lv, lw = v.value, w.value
        if #lv == #lw then
            local eq = true
            for i = 1, #lv do eq = eq and lv[i] == lw[i] end
            return eq
        else return false end
    else return false end
end

function list_mt.__tostring (cat)
    local s = {}
    for i, v in ipairs (cat.value) do s[i] = tostring (v) end
    return string.format ('{ %s } :: list', table.concat (s, ', '))
end

function C.list (v)

    local j = {value = v}
    setmetatable (j, list_mt)

    return j
end

function list.fmap (cat, f)
    local l = {}
    for i, v in pairs (cat.value) do l[i] = f (v) end
    return C.list (l)
end

function list.pure (cat, v) return C.list {v} end

function list.applicative (cat, cat_f)
    local l = {}
    for i, f in ipairs (cat_f.value) do
        for j, v in ipairs (cat.value) do
            table.insert (l, f(v))
        end
    end
    return C.list (l)
end

function list.mempty (cat) return C.list {} end

function list.mappend (cat, rest_cat)
    local l = {}
    for i, v in ipairs (cat.value) do table.insert (l, v) end
    for i, v in ipairs (rest_cat.value) do table.insert (l, v) end
    return C.list (l)
end

list_mt.__concat = list.mappend

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

function list.bind (cat, f) return cat:fmap (f):concat () end

-----------------------------------------------------------------------

local fun = {}
local fun_mt = {__index = fun}

function fun_mt.__eq (v, w)
    if getmetatable (w) == fun_mt then return v.value == w.value 
    else return false end
end

function fun_mt.__tostring (cat)
    return string.format ('%s :: fun', tostring (cat.value))
end

function fun_mt.__call (cat, ...)
    return cat.value (...)
end

function C.fun (v)

    local j = {value = v}
    setmetatable (j, fun_mt)

    return j
end

function fun.fmap (cat, f)
    return C.fun (function (...) return f (cat.value (...)) end)
end

function fun.pure (cat, v)
    return C.fun (function (...) return v end)
end

function fun.applicative (cat, cat_f)
    return C.fun(function (w) return  cat_f.value (w) (cat.value (w)) end)
end

-----------------------------------------------------------------------

local product = {}
local product_mt = {__index = product}

function product_mt.__eq (v, w)
    if getmetatable (w) == product_mt then return v.value == w.value
    else return false end
end

function product_mt.__tostring (cat)
    return string.format ('%s :: product', tostring (cat.value))
end

function C.product (v)

    local j = {value = v}
    setmetatable (j, product_mt)

    return j
end

function product.mempty (cat)
    return C.product (1)
end

function product.mappend (cat, rest_cat)
    return C.product (cat.value * rest_cat.value)
end

product_mt.__concat = product.mappend

-----------------------------------------------------------------------


local stream = {}
local stream_mt = {__index = stream}

function stream_mt.__eq (v, w)
    if getmetatable (w) == stream_mt then return v.value == w.value
    else return false end
end

function stream_mt.__tostring (cat)
    return string.format ('%s :: stream', tostring (cat.value))
end

function C.stream (s)

    local S = lua.lua_newthread ()

    assert (type(s) == 'function', 'Expected a function as lone argument.')

    lua.push (S, s)

    local j = {value = S}
    setmetatable (j, stream_mt)

    return j
end

function stream.mempty (cat)
    return C.stream (function () end)
end

function stream.mappend (cat, rest_cat)
    return C.stream (function ()     
        cat:do_ (coroutine.yield)
        rest_cat:do_ (coroutine.yield)
    end)
end

function stream.tolist (cat)

    local M = lua.current_thread ()
    local L = cat.value
    
    local tbl = {}

    cat:do_ (function (...)
        for i, v in ipairs (table.pack(...)) do table.insert (tbl, v) end
    end)

    return C.list (tbl)
end

function stream.fmap (cat, f)
    return C.stream (function ()
        cat:do_ (function (...) coroutine.yield (f (...)) end)    
    end)
end

function stream.do_ (cat, f)

    local M = lua.current_thread ()
    local L = cat.value
    
    while true do
        
        local retcode, nres = lua.lua_resume (L, M, 0)

        if retcode == lua.LUA_YIELD then f (lua.pop (L, nres))
        else break end
    end

end

function stream.take (cat, n)

    local M = lua.current_thread ()
    local L = cat.value
    
    return C.stream (function () 

        for i = 1, n do
        
            local retcode, nres = lua.lua_resume (L, M, 0)
    
            if retcode == lua.LUA_YIELD then coroutine.yield (lua.pop (L, nres))
            else break end
        end    
    end)
end

function C.nats (s)

    s = s or 0

    return C.stream (function ()
        while true do 
            coroutine.yield (s)
            s = s + 1
        end
    end)

end

stream_mt.__concat = stream.mappend

-----------------------------------------------------------------------

return C
