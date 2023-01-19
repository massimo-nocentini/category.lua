
local lu = require 'luaunit'
local C = require 'category'
local lambda = require 'operator'

local inc = C.fmap (function (v) return v + 1 end)

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
    local j = C.just (3)
    lu.assertEquals (inc (j) , C.just (3 + 1))
end

function Test_just:test_replicate ()
    local three = 3
    local j = C.just (three)
    local repl = C.fmap (replicate (4))
    lu.assertEquals ( repl (j) , C.just (C.list {three, three, three, three}))
end

function Test_just:test_applicative ()
    local three = 3
    local j = C.just (function (v) return v + 1 end)
    local w = j:pure (three)
    lu.assertEquals (C.applicative (j) (w), C.just (three + 1))
end

function Test_just:test_applicative_fmap ()
    local john = 'john'
    local w = C.fmap (string_append) (C.just (john))
    lu.assertEquals (C.applicative (w) (C.just ' travolta'), C.just ('john travolta'))
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
    local j = C.list {2, 3, 4, 5}
    lu.assertEquals (inc (j) , C.just {3, 4, 5, 6})
end

function Test_list:test_replicate ()
    local j = C.list {2, 3, 4, 5}
    local repl = C.fmap (replicate (3))
    lu.assertEquals ( repl (j) , C.list {
        C.list {2, 2, 2}, 
        C.list {3, 3, 3}, 
        C.list {4, 4, 4}, 
        C.list {5, 5, 5},
    })
end

function Test_list:test_pure ()
    lu.assertEquals( C.list {}:pure (3), C.list {3})
end

function Test_list:test_applicative ()
    local three = 3
    local elements = C.list {2, 3, 4, 5}
    local functions = C.applicative (
        C.list {
            function (v) return v * 0 end, 
            function (v) return v + 100 end, 
            function (v) return v ^ 2 end,
        }
    )
    lu.assertEquals (functions (elements), C.list {
        0, 0, 0, 0, 102, 103, 104, 105, 4.0, 9.0, 16.0, 25.0,
    })
end

function Test_list:test_applicative_add_mul ()
    
    local w = C.applicative (C.list { add, mul }) (C.list {1, 2})
    
    lu.assertEquals (C.applicative (w) (C.list {3, 4}), C.list {4, 5, 5, 6, 3, 4, 6, 8})
end

function Test_list:test_applicative_string_append ()

    local w = C.fmap (string_append) (C.list {"ha","heh","hmm"})
    
    lu.assertEquals (C.applicative (w) (C.list {"?","!","."}), 
                     C.list {'ha?', 'ha!', 'ha.', 'heh?', 'heh!', 'heh.', 'hmm?', 'hmm!', 'hmm.'})
end

function Test_list:test_applicative_mul ()

    local w = C.fmap (mul) (C.list {2, 5, 10})
    
    lu.assertEquals (C.applicative (w) (C.list {8, 10, 11}), 
                     C.list {16, 20, 22, 40, 50, 55, 80, 100, 110})
end

function Test_list:test_mappend ()

    lu.assertEquals (C.mappend (C.list {1, 2, 3}) (C.list {8, 10, 11}), 
                     C.list {1, 2, 3, 8, 10, 11})
end

function Test_list:test_bind ()

    lu.assertEquals (C.bind (C.list {1, 2, 3}) (function (v) return C.list {v, -v} end), 
                     C.list {1, -1, 2, -2, 3, -3})
end

function Test_list:test_return ()

    lu.assertEquals (C.bind (C.list {1, 2, 3}) (function (v) return 
                     C.bind (C.list {'a', 'b'}) (function (c) return 
                     C.list {}:ret (C.list {v, c}) end)
    end))
end

--------------------------------------------------------------------------------

Test_product = {}

function Test_product:test_mappend ()
    lu.assertEquals (C.mappend (C.product (4)) (C.product (11)), C.product (4 * 11))
end

--------------------------------------------------------------------------------

Test_fun = {}

function Test_fun:test_fmap ()
    local double = C.fun (function (v) return v * 2 end)
    lu.assertEquals (inc (double) (3), 3 * 2 + 1 )
end

function Test_fun:test_replicate ()
    local double = C.fun (function (v) return v * 2 end)
    local repl = C.fmap (replicate (3))
    lu.assertEquals ( repl (double) (3) , C.list {6, 6, 6})
end

function Test_fun:test_pure ()
    local w = C.fun ():pure (42)
    lu.assertEquals ( w (3) , 42)
end

function Test_fun:test_applicative_add_mul ()
    local w = C.fmap (add) (C.fun (add (3)))
    w = C.applicative (w) (C.fun (mul (100)))
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
    local w = C.fmap (A) (C.fun (add (3)))
    w = C.applicative (w) (C.fun (mul (2)))
    w = C.applicative (w) (C.fun (mul (1/2)))
    lu.assertEquals (w (5), C.list {8, 10, 2.5})
end

--------------------------------------------------------------------------------

os.exit( lu.LuaUnit.run() )