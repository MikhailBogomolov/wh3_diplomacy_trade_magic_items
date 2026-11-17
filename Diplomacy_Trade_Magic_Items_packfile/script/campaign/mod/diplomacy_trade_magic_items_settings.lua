------------------------------------------------------------
-- SETTINGS (1.1.0)
-- The numbers the rest of the mod reads: trade_magic_items.settings.
-- Always starts as the mod's defaults (script/campaign/mod/
-- diplomacy_trade_magic_items_default_ai_evaluation_values.lua). When MCT (Mod Configuration Tool) is installed, its
-- values replace them: when the game has loaded (MctInitialized) and each
-- time the player applies the menu (MctFinalized). Without MCT the mod
-- keeps its defaults. Nothing here is saved by us: MCT keeps its values in
-- its own part of the save, so with MCT turned off they are not used.
-- In multiplayer MCT sends the host's values to the other player; they are
-- read again before every deal and when diplomacy opens
-- (trade_magic_items.refresh_settings), so both evaluate and record deals
-- with the same numbers even before MCT's next event.
------------------------------------------------------------

trade_magic_items = trade_magic_items or {}

local defaults = require "script.campaign.mod.diplomacy_trade_magic_items_default_ai_evaluation_values"
local spec = require "script.campaign.mod.diplomacy_trade_magic_items_mct_fields_and_checks"


local function ad_copy(t)
    if type(t) ~= "table" then
        return t
    end

    local copy = {}

    for key, value in pairs(t) do
        copy[key] = ad_copy(value)
    end

    return copy
end


trade_magic_items.settings = ad_copy(defaults)


local function ad_settings_log(message)
    if trade_magic_items.log then
        trade_magic_items.log(message)
    end
end


-- our MCT mod, or nil and why not
local function ad_get_mct_mod()
    if type(get_mct) ~= "function" then
        return nil, "MCT not installed"
    end

    local ok, mct = pcall(get_mct)

    if not ok or not mct then
        return nil, "MCT not available"
    end

    local mod_ok, mod = pcall(function() return mct:get_mod_by_key(spec.MOD_KEY) end)

    if not mod_ok or not mod then
        return nil, "our MCT menu not registered"
    end

    return mod
end


-- what the last read gave, so a quiet read only logs a change
local ad_last_summary = nil


-- defaults, then every MCT value that is valid; a refused value keeps
-- its default. quiet: log only when the result differs from the last one
function trade_magic_items.read_mct_settings(reason, quiet)
    local fresh = ad_copy(defaults)
    local mod, why = ad_get_mct_mod()

    if not mod then
        trade_magic_items.settings = fresh

        local summary = "defaults (" .. why .. ")"

        if summary ~= ad_last_summary or not quiet then
            ad_settings_log("Settings: " .. summary .. ", " .. reason)
            ad_last_summary = summary
        end

        return
    end

    local changed = {}

    for _, option in ipairs(spec.OPTIONS) do
        local ok, raw = pcall(function()
            local mct_option = mod:get_option_by_key(option.key)

            return mct_option and mct_option:get_finalized_setting()
        end)

        if not ok or raw == nil then
            ad_settings_log("WARNING: setting " .. option.key .. " not found in MCT, default kept")
        else
            local value, refused = spec.parse(option.kind, raw)

            if value == nil then
                ad_settings_log("WARNING: setting " .. option.key .. " = " .. tostring(raw) .. " refused (" .. refused .. "), default kept")
            elseif value ~= spec.get(fresh, option.path) then
                spec.set(fresh, option.path, value)
                table.insert(changed, option.key .. "=" .. spec.format(value))
            end
        end
    end

    trade_magic_items.settings = fresh

    -- the refresh before every deal only logs when something changed
    local summary = #changed > 0 and table.concat(changed, ", ") or "all defaults"

    if summary ~= ad_last_summary or not quiet then
        ad_settings_log("Settings from MCT (" .. reason .. "): " .. summary)
        ad_last_summary = summary
    end
end


-- before a deal is evaluated or recorded, and when diplomacy opens:
-- MCT's own events do not cover every case (review 2026-11-16: in a new
-- multiplayer campaign the host's values reach the other player without
-- MctFinalized), so the current MCT values are read again. Only local
-- reads, quiet unless something changed
function trade_magic_items.refresh_settings(reason)
    local ok, err = pcall(trade_magic_items.read_mct_settings, reason, true)

    if not ok then
        ad_settings_log("ERROR: reading the settings failed: " .. tostring(err))
    end
end


core:add_listener(
    "AD_TradeMagicItemsMctInitialized",
    "MctInitialized",
    true,
    function()
        trade_magic_items.read_mct_settings("game loaded")
    end,
    true
)


core:add_listener(
    "AD_TradeMagicItemsSettingsOnDiplomacy",
    "PanelOpenedCampaign",
    function(context)
        return context.string == "diplomacy_dropdown"
    end,
    function()
        trade_magic_items.refresh_settings("diplomacy opened")
    end,
    true
)


-- without MCT no event comes: say once in the log which numbers are used
cm:add_first_tick_callback(function()
    if type(get_mct) ~= "function" then
        trade_magic_items.read_mct_settings("first tick")
    end
end)


core:add_listener(
    "AD_TradeMagicItemsMctFinalized",
    "MctFinalized",
    true,
    function()
        trade_magic_items.read_mct_settings("settings applied")
    end,
    true
)
