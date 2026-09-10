local Harness = { failures = 0 }

function Harness.equal(actual, expected, message)
    if actual ~= expected then
        Harness.failures = Harness.failures + 1
        print(('not ok - %s: expected %s, got %s'):format(message, tostring(expected), tostring(actual)))
    else
        print('ok - ' .. message)
    end
end

function Harness.finish()
    if Harness.failures > 0 then os.exit(1) end
end

return Harness
