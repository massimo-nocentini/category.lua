
local C = { }

function C.nats (s)
    s = s or 0
    return C.stream { 
        head = s,
        tail = C.stream (function () return C.nats (s + 1) end) 
    }
end

function C.primes ()

    local function P (S)

        local p, T = S:head_tail ()

        local function isntmultiple (n) return n % p > 0 end

        return C.stream { 
            head = p, 
            tail = C.stream (function () return P (T:filter (isntmultiple)) end) 
        }        
    end

    return P (C.nats (2))
end

function C.mconcat (cat, tbl)

    local r = cat:mempty ()
    
    for i = #tbl, 1, -1 do r = tbl[i]:mappend (r) end

    return r
end

function C.tell (monoid)
    -- tell :: Monoid w => w -> Writer w ()

    return C.writer (nil, monoid)
end

function C.diffmonoid (cat)
    return C.diffmonoid_new (function (rest) return cat:mappend (rest) end, cat:mempty ())
end

C.monoid = {
    pow = function (cat, n)

        -- mpow :: Monoid w => int -> w -> w

        local function P (r, a, i)

            if i == 0 then return r
            else
                if i % 2 == 1 then r = a .. r end
                return P (r, a .. a, i // 2)
            end

        end

        return P (cat:mempty (), cat, n)
    
    end,
    mempty = function (cat) error ('mempty is required for ' .. tostring (cat)) end,
    mappend = function (cat, another) error ('mappend is required for ' .. tostring (cat)) end,
    create = function (monoid, m)
    
        m = m or {}
    
        monoid.__index = monoid
        monoid.__concat = function (cat, another) return cat:mappend (another) end
        monoid.__pow = monoid.pow
    
        setmetatable (m, monoid)
    
        return m
    end,
}

-----------------------------------------------------------------------

--[[

    newtype Writer w a = Writer { runWriter :: (a, w) }

    instance (Monoid w) => Monad (Writer w) where
        return x = Writer (x, mempty)
        (Writer (x, v)) >>= f = let (Writer (y, v')) = f x in Writer (y, v `mappend` v')

]]

local writer = {}
local writer_mt = {__index = writer}

function C.writer (s, w)

    if not (w.mempty and w.mappend) then error 'A monoid is required as second argument.' end

    local j = {value = s, monoid = w}
    setmetatable (j, writer_mt)

    return j
end

function writer_mt.__tostring (cat)
    return string.format ('(%s, %s) :: writer', tostring (cat.value), tostring (cat.monoid))
end

function writer.ret (cat, v) return C.writer (v, cat.monoid:mempty ()) end

function writer.bind (cat, f)
    -- bind :: (Writer w) a -> (a -> (Writer w) b) -> (Writer w) b
    local w = f (cat.value, cat)
    return C.writer (w.value, cat.monoid:mappend (w.monoid))
end

-----------------------------------------------------------------------

local nothing = {}

local nothing_mt = {
    __index = nothing, -- where you can find functions.
}

function nothing_mt.__eq (v, w)
    return getmetatable (w) == nothing_mt
end

function nothing_mt.__tostring (cat)
    return '• :: nothing'
end

function C.nothing ()

    local j = {}
    setmetatable (j, nothing_mt)

    return j
end

function nothing.fmap (cat, f) return cat end
function nothing.pure (cat, v) return C.just (v) end
function nothing.applicative (cat, cat_f) return cat end
nothing.ret = nothing.pure
function nothing.bind (cat, f) return cat end
function nothing.mappend (cat, another) return another end

nothing_mt.__concat = nothing.mappend

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
    if getmetatable (another) == just_mt then
        return C.just (cat.value:mappend (another.value))
    else return cat end
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

list.mconcat = C.mconcat

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

list.tell = C.tell
list.diffmonoid = C.diffmonoid

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

fun.ret = fun.pure

function fun.bind (cat, f)
    return C.fun (function (w) return f (cat.value (w), cat) (w) end)
end

-----------------------------------------------------------------------

local product = C.monoid:create ()

function product.mempty (cat)
    return C.product (1)
end

function product.mappend (cat, rest_cat)
    return C.product (cat.value * rest_cat.value)
end

function product.__eq (v, w)
    if getmetatable (w) == product_mt then return v.value == w.value
    else return false end
end

function product.__tostring (cat)
    return string.format ('%s :: product', tostring (cat.value))
end

function C.product (v)
    return product:create { value = v }
end

-----------------------------------------------------------------------
--[[ 
    data Either a b = Left a | Right b

    fmap :: (b -> c) -> (Either a) b -> (Either a) c

    ret :: b -> (Either a) b

    bind :: m a -> (a -> m b) -> m b
    bind :: (Either c) a -> (a -> (Either c) b) -> (Either c) b
--]]

local succeed = {}
local succeed_mt = {__index = succeed}

function succeed_mt.__eq (v, w)
    if getmetatable (w) == succeed_mt then return v.value == w.value
    else return false end
end

function succeed_mt.__tostring (cat)
    return string.format ('%s :: succeed', tostring (cat.value))
end

function C.succeed (v)

    local j = {value = v}
    setmetatable (j, succeed_mt)

    return j
end

function succeed.fmap (cat, f) return C.succeed (f (cat.value)) end

function succeed.ret (cat, v) return C.succeed (v) end

function succeed.bind (cat, f) return f (cat.value) end

local failure = {}
local failure_mt = {__index = failure}

function failure_mt.__eq (v, w)
    if getmetatable (w) == failure_mt then return v.value == w.value
    else return false end
end

function failure_mt.__tostring (cat)
    return string.format ('%s :: failure', tostring (cat.value))
end

function C.failure (v)

    local j = {value = v}
    setmetatable (j, failure_mt)

    return j
end

function failure.fmap (cat, f) return cat end

function failure.ret (cat, v) return C.succeed (v) end

function failure.bind (cat, f) return cat end

function C.pcall (f, ...)

    local flag, v = pcall (f, ...)
    if flag then return C.succeed (v)
    else return C.failure (v) end

end

-----------------------------------------------------------------------


local stream = {}
local stream_mt = {__index = stream}

function stream_mt.__tostring (cat)
    return string.format ('%s :: stream', tostring (cat.value))
end

function C.stream (s)

    local j = {value = s}
    setmetatable (j, stream_mt)

    return j
end

function stream.mempty (cat)
    return C.stream ()
end

function stream.dbind (cat, empty_f, table_f, susp_f)

    if cat.value == nil then return empty_f (cat)
    elseif type (cat.value) == 'table' then return table_f (cat.value.head, cat.value.tail, cat)
    elseif type (cat.value) == 'function' then return susp_f (cat.value, cat)
    else error 'Unknown stream variant.' end
end

function stream.mappend (cat, rest_cat)
   
    return cat:dbind (
        function () return rest_cat end,
        function (head, tail) return C.stream { 
            head = head, 
            tail = tail:mappend (rest_cat)
        } end,
        function (f) return C.stream (
            function () return f ():mappend (rest_cat) end
        ) end
    )
end

function stream.tolist (cat)
    
    local tbl = {}

    local function L (c)

        return c:dbind (
            function () end,
            function (head, tail) 
                table.insert (tbl, head)
                L (tail)
            end,
            function (f) L (f ()) end
        )
    end

    L (cat)

    return C.list (tbl)
end

function stream.fmap (cat, f)
    return cat:dbind (
        function () return C.stream () end,
        function (head, tail) return C.stream { 
            head = f(head), 
            tail = tail:fmap (f)
        } end,
        function (g) return C.stream (function () 
            return g ():fmap (f)
        end) end
    )
end

function stream:isempty (cat)
    return cat.value == nil
end

function stream.filter (cat, p)

    return cat:dbind (
        function () return C.stream () end,
        function (head, tail) 
            if p (head) then return C.stream { 
                head = head, tail = tail:filter (p)
            } else return tail:filter (p) end
        end,
        function (f) return C.stream (function () 
            return f ():filter (p)
        end) end
    )

end

function stream.take (cat, n)

    if n == 0 then return C.stream ()
    else
        return cat:dbind (
            function () return C.stream () end,
            function (head, tail) return C.stream { head = head, tail = tail:take (n-1) } end,
            function (f) return C.stream (function () return f ():take (n) end) end
        )
    end
end

function stream.ret (cat, v)
    return C.stream { head = v, tail = C.stream () }
end

function stream.head_tail (cat)

    return cat:dbind (
        function () error "An empty stream doesn't have a head." end,
        function (head, tail) return head, tail end,
        function (f) return f ():head_tail () end
    )
    
end

stream_mt.__concat = stream.mappend

-----------------------------------------------------------------------


--[[

    newtype DiffList a = DiffList { getDiffList :: [a] -> [a] }

    instance Monoid (DiffList a) where
        mempty = DiffList (\xs -> [] ++ xs)
        (DiffList f) `mappend` (DiffList g) = DiffList (\xs -> f (g xs))

]]

local diffmonoid = {}
local diffmonoid_mt = {__index = diffmonoid}

function C.diffmonoid_new (f, empty)
    -- a private constructor for difference monoid.

    local j = {value = f, empty = empty}

    setmetatable (j, diffmonoid_mt)

    return j
end

function diffmonoid_mt.__tostring (cat)
    return string.format ('%s :: diffmonoid', tostring (cat ()))
end

function diffmonoid.mempty (cat)
    return C.diffmonoid_new (function (monoid) return monoid:mempty ():mappend (monoid) end, cat.empty)
end

function diffmonoid.mappend (cat, another)
    return C.diffmonoid_new (function (monoid) return cat.value (another.value (monoid)) end, cat.empty)
end

diffmonoid_mt.__concat = diffmonoid.mappend

function diffmonoid_mt.__call (cat) return cat.value (cat.empty) end

diffmonoid.tell = C.tell

-----------------------------------------------------------------------

--[[

    newtype State s a = State { runState :: s -> (a, s) }

    instance Monad (State s) where
        return x = State $ \s -> (x, s)
        (State h) >>= f = State $ \s -> let (a, newState) = h s
                                            (State g) = f a
                                            in g newState

]]

local state = {}
local state_mt = {__index = state}

function C.state (s)

    local j = {value = s}
    setmetatable (j, state_mt)

    return j
end

function state_mt.___tostring (cat)
    return string.format ('%s :: state', tostring (cat.value))
end

function state.ret (cat, v) return C.state (function (s) return v, s end) end

function state.bind (cat, f)
    -- bind :: (w -> (a, w)) -> (a -> (w -> (b, w)) -> (w -> (b, w))
    return C.state (function (s)
        local v, r = cat.value (s)
        local state_cat = f (v, cat)
        return state_cat.value (r)
    end)
end

state.get = C.state (function (s) return s, s end)
function state.put (r) return C.state (function (s) return s, r end) end

function state_mt.__call (cat, s)
    return cat.value (s)
end

-----------------------------------------------------------------------

return C
