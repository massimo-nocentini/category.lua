
local lu = require 'luaunit'
local C = require 'category'
local lambda = require 'operator'

local function string_append (a)
    return function (b) return a .. b end
end

local function mul (a)
    return function (b) return a * b end
end

local function add (a)
    return function (b) return a + b end
end

local function replicate (n)
    return function (v)
        local t = {}
        for i = 1, n do t[i] = v end
        return C.list (t)
    end
end

Test_just = {}

function Test_just:test_eq ()
    local j = C.just (3)
    lu.assertEquals (j, C.just (4 - 1))
end

function Test_just:test_tostring ()
    local j = C.just (4 - 1)
    lu.assertEquals (tostring(j), '3 :: just')
end

function Test_just:test_fmap ()
    lu.assertEquals (C.just (3):fmap (add (1)) , C.just (3 + 1))
end

function Test_just:test_replicate ()
    local three = 3
    lu.assertEquals ( C.just (three):fmap (replicate (4)) , C.just (C.list {three, three, three, three}))
end

function Test_just:test_applicative ()
    local three = 3
    local cat = C.just (three)
    lu.assertEquals (cat:applicative (cat:pure (add (1))), C.just (three + 1))
end

function Test_just:test_applicative_fmap ()
    local john = 'john'
    local w = C.just (john):fmap (string_append)
    lu.assertEquals (C.just ' travolta':applicative (w), C.just ('john travolta'))
end

function Test_just:test_mappend ()
    lu.assertEquals (C.just (C.product (3)) .. C.just (C.product (4)), C.just (C.product (12)))
end

--------------------------------------------------------------------------------

Test_list = {}

function Test_list:test_tostring ()
    local j = C.list {2, 3, 4, 5}
    lu.assertEquals (tostring(j), '{ 2, 3, 4, 5 } :: list')
end

function Test_list:test_eq ()
    local i = C.list {2, 3, 4, 5}
    local j = C.list {2, 3, 4, 6}
    local k = C.list {2, 3, 4, 5, 6}
    local l = C.list {2, 3, 4, 6 - 1}
    lu.assertEquals (i, l)
    lu.assertNotEquals (i, j)
    lu.assertNotEquals (j, k)
    lu.assertNotEquals (k, i)
end

function Test_list:test_fmap ()
    lu.assertEquals (C.list {2, 3, 4, 5}:fmap (add (1)) , C.just {3, 4, 5, 6})
end

function Test_list:test_replicate ()
    lu.assertEquals ( C.list {2, 3, 4, 5}:fmap (replicate (3)), 
        C.list {
            C.list {2, 2, 2}, 
            C.list {3, 3, 3}, 
            C.list {4, 4, 4}, 
            C.list {5, 5, 5},
        }
    )
end

function Test_list:test_pure ()
    lu.assertEquals( C.list {}:pure (3), C.list {3})
end

function Test_list:test_applicative ()
    local three = 3
    local functions = 
        C.list {
            function (v) return v * 0 end, 
            function (v) return v + 100 end, 
            function (v) return v ^ 2 end,
        }
    
    lu.assertEquals (C.list {2, 3, 4, 5}:applicative (functions), C.list {
        0, 0, 0, 0, 102, 103, 104, 105, 4.0, 9.0, 16.0, 25.0,
    })
end

function Test_list:test_applicative_add_mul ()
    
    local w = C.list {1, 2}:applicative (C.list { add, mul })
    lu.assertEquals (C.list {3, 4}:applicative (w), C.list {4, 5, 5, 6, 3, 4, 6, 8})
end

function Test_list:test_applicative_string_append ()

    local w = C.list {"ha","heh","hmm"}:fmap (string_append)
    
    lu.assertEquals (C.list {"?","!","."}:applicative (w), 
                     C.list {'ha?', 'ha!', 'ha.', 'heh?', 'heh!', 'heh.', 'hmm?', 'hmm!', 'hmm.'})
end

function Test_list:test_applicative_mul ()

    local w = C.list {2, 5, 10}:fmap (mul)
    
    lu.assertEquals (C.list {8, 10, 11}:applicative (w), 
                     C.list {16, 20, 22, 40, 50, 55, 80, 100, 110})
end

function Test_list:test_mappend ()

    lu.assertEquals (C.list {1, 2, 3}:mappend (C.list {8, 10, 11}), 
                     C.list {1, 2, 3, 8, 10, 11})
    
    lu.assertEquals (C.list {1, 2, 3} .. C.list {8, 10, 11}, 
                     C.list {1, 2, 3, 8, 10, 11})
end

function Test_list:test_bind ()

    lu.assertEquals (C.list {1, 2, 3}:bind (function (v) return C.list {v, -v} end), 
                     C.list {1, -1, 2, -2, 3, -3})
end

function Test_list:test_return ()

    local cat = C.list {1, 2, 3}
    lu.assertEquals (cat:bind (function (v) return 
                     C.list {'a', 'b'}:bind (function (c) return 
                     cat:ret ( v..c ) end) end),
                     C.list { '1a','1b', '2a', '2b', '3a', '3b', })
end

--------------------------------------------------------------------------------

Test_product = {}

function Test_product:test_mappend ()
    lu.assertEquals (C.product (4):mappend (C.product (11)), C.product (4 * 11))
    lu.assertEquals (C.product (4) .. C.product (11), C.product (4 * 11))
end

--------------------------------------------------------------------------------

Test_fun = {}

function Test_fun:test_fmap ()
    local cat = C.fun (mul (2)):fmap (add (1))
    lu.assertEquals (cat (3), 3 * 2 + 1 )
end

function Test_fun:test_replicate ()
    local cat = C.fun (mul (2)):fmap (replicate (3))
    lu.assertEquals ( cat (3) , C.list {6, 6, 6})
end

function Test_fun:test_pure ()
    local cat = C.fun ():pure (42)
    lu.assertEquals ( cat (3) , 42)
end

function Test_fun:test_applicative_add_mul ()
    local cat = C.fun (add (3))
    local w = C.fun (mul (100)):applicative (cat:fmap (add))
    lu.assertEquals (w (5), 508)
end

function Test_fun:test_applicative ()
    local function A (x)
        return function (y)
            return function (z)
                return C.list {x, y, z}
            end
        end
    end
    
    local cat = C.fun (mul (1/2)):applicative (C.fun (mul (2)):applicative (C.fun (add (3)):fmap (A)))
    lu.assertEquals (cat (5), C.list {8, 10, 2.5})
end

--------------------------------------------------------------------------------

Test_stream = {}

function Test_stream:test_tolist ()
    
    local function s ()
        for i = 1, 10 do coroutine.yield (i) end
    end

    local cat = C.stream (s)
    lu.assertEquals (cat:tolist (), C.list { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 } )
end

function Test_stream:test_take ()

    local cat = C.nats ():take (10)
    lu.assertEquals (cat:tolist (), C.list { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 } )
end

function Test_stream:test_fmap ()
    
    local i = 1
    local function s () while i < 11 do coroutine.yield (i); i = i + 1 end end

    local cat = C.stream (s):fmap(add (1))
    lu.assertEquals (cat:tolist (), C.list { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }:fmap (add (1)) )
end

function Test_stream:test_mappend ()

    local cat = C.nats ():take (10)
    lu.assertEquals ((C.nats ():take (10) .. C.nats (100)):take(20):tolist (), 
                     C.list { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109 } )
end

function Test_stream:test_primes ()

    local cat = C.primes ()
    lu.assertEquals (cat:take (20):tolist (), 
                     C.list { 2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71 })
end

--------------------------------------------------------------------------------
os.exit( lu.LuaUnit.run() )