
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

Test_nothing = {}

function Test_nothing:test_tostring ()
    local j = C.nothing ()
    lu.assertEquals (tostring (j), '• :: nothing')
end

--------------------------------------------------------------------------------

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

function Test_list:test_mconcat ()

    lu.assertEquals (C.list ():mconcat {}, C.list {})

    lu.assertEquals (C.list ():mconcat {
        C.list {1, 2, 3}, 
        C.list {4, 5, 6, 7}, 
        C.list {8, 10, 11}
    }, C.list {1, 2, 3, 4, 5, 6, 7, 8, 10, 11})
    
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
    
    local function S (n)
        if n > 10 then return C.stream ()
        else return C.stream { 
            head = n, 
            tail = C.stream (function () return S (n + 1) end) 
        } end
    end

    local cat = C.stream (function () return S(1) end)
    lu.assertEquals (cat:tolist (), C.list { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 } )
end

function Test_stream:test_take ()

    local cat = C.nats ():take (10)
    lu.assertEquals (cat:tolist (), C.list { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 } )
end

function Test_stream:test_fmap ()
    
    local cat = C.nats (1):fmap(add (1))
    lu.assertEquals (cat:take (10):tolist (), C.list { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }:fmap (add (1)) )
end

function Test_stream:test_mappend ()

    local cat = C.nats ():take (10)
    lu.assertEquals ((C.nats ():take (10) .. C.nats (100)):take(20):tolist (), 
                     C.list { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109 } )
end

function Test_stream:test_primes ()

    local cat = C.primes ()
    lu.assertEquals (cat:take (200):tolist (), 
                     C.list { 2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89, 97, 101, 103, 107, 109, 113, 127, 131, 137, 139, 149, 151, 157, 163, 167, 173, 179, 181, 191, 193, 197, 199, 211, 223, 227, 229, 233, 239, 241, 251, 257, 263, 269, 271, 277, 281, 283, 293, 307, 311, 313, 317, 331, 337, 347, 349, 353, 359, 367, 373, 379, 383, 389, 397, 401, 409, 419, 421, 431, 433, 439, 443, 449, 457, 461, 463, 467, 479, 487, 491, 499, 503, 509, 521, 523, 541, 547, 557, 563, 569, 571, 577, 587, 593, 599, 601, 607, 613, 617, 619, 631, 641, 643, 647, 653, 659, 661, 673, 677, 683, 691, 701, 709, 719, 727, 733, 739, 743, 751, 757, 761, 769, 773, 787, 797, 809, 811, 821, 823, 827, 829, 839, 853, 857, 859, 863, 877, 881, 883, 887, 907, 911, 919, 929, 937, 941, 947, 953, 967, 971, 977, 983, 991, 997, 1009, 1013, 1019, 1021, 1031, 1033, 1039, 1049, 1051, 1061, 1063, 1069, 1087, 1091, 1093, 1097, 1103, 1109, 1117, 1123, 1129, 1151, 1153, 1163, 1171, 1181, 1187, 1193, 1201, 1213, 1217, 1223, })
end

--------------------------------------------------------------------------------

Test_writer = {}

function Test_writer:test_mult_with_log ()

    local function mult_with_log (x) return C.writer (x, C.list { 'Got number: ' .. x}) end

    local cat = mult_with_log (3)
    
    local m = cat:bind (
        function (a)
            return mult_with_log (5):bind (
                function (b)
                    return cat:ret (a * b)
                end
            )
        end
    )
    
    lu.assertEquals (m, C.writer (15, C.list {'Got number: 3', 'Got number: 5'}) )
end

function Test_writer:test_gcd ()

    -- gcd :: (int, int) -> writer int [string]
    local function gcd (a, b)

        if b == 0 then
            local writer = C.list {'Finished with ' .. a}:tell ()
            return writer:bind (function () return writer:ret (a) end)
        else 
            local m = a % b
            local writer = C.list {a .. ' mod ' .. b .. ' = ' .. m}:tell ()
            return writer:bind (function () return gcd (b, m) end)
        end
    end

    lu.assertEquals (gcd (8, 5), C.writer (1, C.list {
        '8 mod 5 = 3', 
        '5 mod 3 = 2', 
        '3 mod 2 = 1', 
        '2 mod 1 = 0', 
        'Finished with 1'
    }))
end


function Test_writer:test_gcd_diffmonoid ()

    -- gcd :: (int, int) -> writer int [string]
    local function gcd (a, b)

        if b == 0 then
            return C.list {'Finished with ' .. a}
                    :diffmonoid ()
                    :tell ()
                    :bind (function (_, writer) return writer:ret (a) end)
        else 
            local m = a % b
            return C.list {a .. ' mod ' .. b .. ' = ' .. m}
                    :diffmonoid ()
                    :tell ()
                    :bind (function () return gcd (b, m) end)
        end
    end

    local writer = gcd (8, 5)

    lu.assertEquals (writer.value, 1)
    lu.assertEquals (tostring (writer.monoid), '{ Finished with 1, 2 mod 1 = 0, 3 mod 2 = 1, 5 mod 3 = 2, 8 mod 5 = 3 } :: list :: diffmonoid')
end

function Test_writer:test_gcd_diffmonoid_swap ()

    -- gcd :: (int, int) -> writer int [string]
    local function gcd (a, b)

        if b == 0 then
            return C.list {'Finished with ' .. a}
                    :diffmonoid ()
                    :tell ()
                    :bind (function (_, writer) return writer:ret (a) end)
        else 
            local r = a % b

            return gcd (b, r):bind (
                function (m) 
                    return C.list {a .. ' mod ' .. b .. ' = ' .. r}
                            :diffmonoid ()
                            :tell ()
                            :bind (function (_, writer) return writer:ret (m) end)
                end
            )
        end
    end

    local writer = gcd (8, 5)

    lu.assertEquals (writer.value, 1)
    lu.assertEquals (tostring (writer.monoid), '{ 8 mod 5 = 3, 5 mod 3 = 2, 3 mod 2 = 1, 2 mod 1 = 0, Finished with 1 } :: list :: diffmonoid')

end


--------------------------------------------------------------------------------

os.exit( lu.LuaUnit.run() )