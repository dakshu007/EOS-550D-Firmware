-- The single background task: runs queued jobs, then the tickers, then sleeps.
-- Every job and ticker runs in pcall, so an error is recorded (see
-- Focus > LUMEN Focus > Status) instead of stopping the task.
local function monitor()
    while true do
        lumen.heartbeat = dryos.ms_clock
        local sleep = 100

        local job = table.remove(lumen.jobs, 1)
        while job ~= nil do
            local ok, err = pcall(job)
            if not ok then lumen.last_error = tostring(err) end
            job = table.remove(lumen.jobs, 1)
        end

        for _, tick in ipairs(lumen.tickers) do
            local ok, s = pcall(tick, dryos.ms_clock)
            if not ok then
                lumen.last_error = tostring(s)
            elseif type(s) == "number" and s < sleep then
                sleep = s
            end
        end

        task.yield(sleep)
    end
end

-- The 550D can't spare 32-64 KB task stacks ("task not started"):
-- use 16 KB, then 8 KB (ML's own C tasks use 4-8 KB).
--
-- IMPORTANT: ML's task.create (lua_task.c) stores whatever is on TOP of the
-- Lua stack as the function to run (luaL_ref), i.e. the LAST argument. With
-- task.create(fn, prio, stack) that is the stack size, and the task dies with
-- "ML ASSERT ... lua_task.c:80". So the function is passed again as the last
-- argument: task.create(fn, priority, stack, disable_powersave, fn).
local started = false
for _, stack in ipairs({ 0x4000, 0x2000 }) do
    if pcall(task.create, monitor, 0x1c, stack, false, monitor) then
        started = true
        break
    end
end
lumen.start_failed = not started
