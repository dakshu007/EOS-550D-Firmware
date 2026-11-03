-- LUMEN Astro
-- Night-sky helpers for the EOS 550D (APS-C, 1.6x crop).
--
-- Star Limit: longest exposure before stars start to trail, shown in the
--             Live View info bar (500 rule, adjusted for the 1.6x crop).
-- Star Focus: jumps Live View to 10x zoom so you can focus on a bright star.
--
-- Part of LUMEN for EOS 550D. GPL v2 or later.


local CROP = 1.6


local RULES =
{
    ["500 rule"]           = 500,
    ["400 rule (sharper)"] = 400,
    ["300 rule (pixel)"]   = 300,
}

local function star_limit_s()
    local f = lens.focal_length
    if f == nil or f <= 0 then return nil end
    local k = RULES[lastro_menu.submenu["Rule"].value] or 500
    return k / (f * CROP)
end

lastro_menu = menu.new
{
    parent  = "Shoot",
    name    = "LUMEN Astro",
    help    = "Star-trail limit and star focusing helpers.",
    submenu =
    {
        {
            name    = "Star Limit",
            choices = { "OFF", "ON" },
            help    = "Show the longest exposure before stars trail (Live View).",
            rinfo   = function(this)
                local s = star_limit_s()
                if s then return string.format("%.0f s at %d mm", s, lens.focal_length) end
            end,
        },
        {
            name    = "Rule",
            choices = { "500 rule", "400 rule (sharper)", "300 rule (pixel)" },
            help    = "Lower number = shorter exposures, sharper stars.",
        },
        {
            name    = "Star Focus",
            help    = "Live View 10x zoom: focus manually until the star is a tiny dot.",
            select  = function(this)
                local ok = lumen.run(function()
                    if not (lv.enabled and lv.running) then
                        display.notify_box("Turn on Live View first", 2000)
                        return
                    end
                    menu.close()
                    local ok = pcall(function() lv.zoom = 10 end)
                    task.yield(500)   -- let Canon apply the zoom (runs in the LUMEN task, so it may yield)
                    if ok and lv.zoom == 10 then
                        display.notify_box("10x: focus until the star is smallest", 3000)
                    else
                        display.notify_box("Zoom not available here: press the zoom button", 3000)
                    end
                end)
                if not ok then
                    display.notify_box("Astro: not enough free memory (turn off other scripts)", 5000)
                end
            end,
        },
    },
    update = function(this)
        if this.submenu["Star Limit"].value == "OFF" then return "OFF" end
        local s = star_limit_s()
        if s then return string.format("%.0f s", s) end
        return "ON"
    end,
}

-- settings: only the two choice items are saved; missing or unknown values
-- fall back to defaults, so future versions can add items safely
local LIMIT_CHOICES = { "OFF", "ON" }
local function valid(choices, v)
    for _, c in ipairs(choices) do if c == v then return true end end
    return false
end

lastro_cfg = lumen.config({ limit = "OFF", rule = "500 rule" })
lastro_menu.submenu["Star Limit"].value =
    valid(LIMIT_CHOICES, lastro_cfg.data.limit) and lastro_cfg.data.limit or "OFF"
lastro_menu.submenu["Rule"].value =
    RULES[lastro_cfg.data.rule] and lastro_cfg.data.rule or "500 rule"
lastro_cfg.saving = function(self)
    self.data =
    {
        limit = lastro_menu.submenu["Star Limit"].value,
        rule  = lastro_menu.submenu["Rule"].value,
    }
end

lv.info
{
    name     = "LUMEN Star Limit",
    value    = "",
    priority = 50,
    update   = function(this)
        this.value = ""
        if lastro_menu.submenu["Star Limit"].value ~= "ON" then return end
        local s = star_limit_s()
        if s then
            this.value = string.format("STAR %.0fs", s)
        end
    end,
}
