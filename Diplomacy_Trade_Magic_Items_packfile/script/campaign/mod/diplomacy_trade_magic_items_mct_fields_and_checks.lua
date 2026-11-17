------------------------------------------------------------
-- SETTINGS OPTIONS (1.1.0)
-- Every setting the MCT menu shows, in menu order: its section, its MCT
-- option key, where it lives in the defaults / settings table and what
-- values it accepts. Read with require "script.campaign.mod.diplomacy_trade_magic_items_mct_fields_and_checks"
-- by the MCT menu (to build the fields and their checks) and by the
-- campaign settings reader (to read them back), so both always agree.
------------------------------------------------------------

local defaults = require "script.campaign.mod.diplomacy_trade_magic_items_default_ai_evaluation_values"

local spec = {
    -- MCT mod key; loc keys follow MCT's names: mct_<key>_title,
    -- mct_<key>_<option>_text / _tooltip, and ours for the sections:
    -- mct_<key>_section_<section>
    MOD_KEY = "diplomacy_trade_magic_items",

    -- menu order (user: Rules on top). MCT puts the first half of the
    -- sections in the left column and the rest in the right one (by count:
    -- Settings page, per_column = ceil(sections / 2), so 7 = 4 + 3): rules
    -- and prices on the left; deal memory and the two attitude scales on
    -- the right (user: memory above the attitudes is fine)
    SECTIONS = {
        "rules",
        "prices",
        "items",
        "ancillaries",
        "memory",
        "attitude_order",
        "attitude_destruction"
    },

    -- { section =, key =, kind =, path = { field, subfield, ... } }
    -- kind: "checkbox"; "positive" (> 0); "non_negative" (>= 0);
    -- "turns" (whole number >= 1); "any" (any number)
    OPTIONS = {}
}


-- label: a shared text key (mct_<mod>_<label>) for fields that read the
-- same in several places (rarities, attitude tiers); without it MCT uses
-- the field's own key, mct_<mod>_<key>_text
local function add(section, key, kind, path, label)
    table.insert(spec.OPTIONS, { section = section, key = key, kind = kind, path = path, label = label })
end


add("rules", "trade_agreement_only", "checkbox", { "trade_agreement_only" })

add("prices", "payment_per_point", "positive", { "payment_per_point" })

for _, rarity in ipairs({ "common", "uncommon", "rare", "crafted" }) do
    add("items", "item_" .. rarity, "non_negative", { "item_points", rarity }, "rarity_" .. rarity)
end

for _, rarity in ipairs({ "common", "uncommon", "rare" }) do
    add("ancillaries", "ancillary_" .. rarity, "non_negative", { "ancillary_points", rarity }, "rarity_" .. rarity)
end

-- worn sits with the payment rate in Prices (user)
add("prices", "worn_percent", "non_negative", { "worn_percent" })

for _, scale in ipairs({ "order", "destruction" }) do
    for i, tier in ipairs(defaults.attitude_tiers) do
        add("attitude_" .. scale, scale .. "_" .. tier.key, "any", { "attitude_percent", scale, i }, "attitude_" .. tier.key)
    end
end

add("memory", "frequency_first", "non_negative", { "frequency_first" })
add("memory", "frequency_turns", "turns", { "frequency_turns" })
add("memory", "recent_percent", "non_negative", { "recent_percent" })
add("memory", "recent_turns", "turns", { "recent_turns" })
add("memory", "big_deal_rarity", "non_negative", { "big_deal_rarity" })


-- the value at path in a defaults / settings table
function spec.get(t, path)
    local value = t

    for _, step in ipairs(path) do
        value = value[step]
    end

    return value
end


function spec.set(t, path, value)
    local parent = t

    for i = 1, #path - 1 do
        parent = parent[path[i]]
    end

    parent[path[#path]] = value
end


-- the value of an MCT field (text input: a string; checkbox: a boolean)
-- or nil and why it is refused
function spec.parse(kind, raw)
    if kind == "checkbox" then
        if type(raw) == "boolean" then
            return raw
        end

        return nil, "not a yes / no value"
    end

    local value = tonumber(raw)

    -- tonumber also takes "nan", "inf" and overflows (C strtod): refused.
    -- The game has no math.huge; x - x is 0 for every real number and nan
    -- for nan and inf
    if not value or value - value ~= 0 then
        return nil, "not a number (use a dot for decimals: 2.5)"
    elseif kind == "positive" and value <= 0 then
        return nil, "must be more than 0"
    elseif kind == "non_negative" and value < 0 then
        return nil, "must be 0 or more"
    elseif kind == "turns" and (value < 1 or value ~= math.floor(value)) then
        return nil, "must be a whole number of turns, 1 or more"
    end

    return value
end


-- a number as the menu and the log show it: the game keeps numbers with
-- less precision (14.4 prints as 14.39999961853), so at most two decimals,
-- trailing zeros dropped: 14.4, -12.5, 1000
function spec.format(value)
    if type(value) ~= "number" then
        return tostring(value)
    end

    if value == math.floor(value) then
        return string.format("%d", value)
    end

    local text = string.format("%.2f", value)

    text = string.gsub(text, "0+$", "")
    text = string.gsub(text, "%.$", "")

    return text
end


return spec
