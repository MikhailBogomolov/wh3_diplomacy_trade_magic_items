------------------------------------------------------------
-- DEAL MANAGER
-- What a deal is worth and what happens when it is made: the log, the
-- balance numbers, the deal memory in the savegame, the evaluation and
-- the trade itself.
-- No drawing here, the screen shows what this file works out.
------------------------------------------------------------

trade_magic_items = trade_magic_items or {}


local AD_VERSION = "1.1.0"


------------------------------------------------------------
-- DEAL TUNING
-- Every number of the deal evaluation lives here. See DEAL EVALUATION for
-- how they are used. Positive points are for the deal, negative
-- against it; the total is shown on the panel.
------------------------------------------------------------

-- test switch: true ignores the evaluation, OK sends any deal (also
-- gold alone); the chance is still shown
trade_magic_items.IGNORE_DEAL_CHANCE = false

-- the partner agrees when the total is at least this
trade_magic_items.DEAL_ACCEPT_SCORE = 0

-- item rarity (uniqueness group key) -> points: + for an item we
-- offer, - for an item we demand. Each step is x2 + 20% so trading does
-- not beat crafting; crafted stands apart on purpose. Next raise if
-- needed (user): 7, 17, 40, 55
local AD_RARITY_POINTS = {
    wh_main_anc_group_common = 6,
    wh_main_anc_group_uncommon = 15,
    wh_main_anc_group_rare = 36,
    wh_main_anc_group_crafted = 50
}

-- item rarity -> minus for a demanded item worn by one of their characters
local AD_BELONGS_TO_CHARACTER_POINTS = {
    wh_main_anc_group_common = 5,
    wh_main_anc_group_uncommon = 10,
    wh_main_anc_group_rare = 15,
    wh_main_anc_group_crafted = 20
}

-- 1.1.0: the same two tables for ancillaries, the Banners and Followers
-- tabs (banners, banner runes, engineering runes, followers); everything
-- on the Magic Items tab (dwarf character runes and character-type items
-- too) uses the tables above. Numbers by the user (2026-11-15). No
-- tradeable ancillary is crafted: that row only copies rare.
local AD_ANCILLARY_RARITY_POINTS = {
    wh_main_anc_group_common = 2,
    wh_main_anc_group_uncommon = 4,
    wh_main_anc_group_rare = 8,
    wh_main_anc_group_crafted = 8
}

local AD_ANCILLARY_BELONGS_TO_CHARACTER_POINTS = {
    wh_main_anc_group_common = 0.5,
    wh_main_anc_group_uncommon = 1,
    wh_main_anc_group_rare = 1.5,
    wh_main_anc_group_crafted = 1.5
}

-- gold in the deal: this much gold is one point (40000 gold = 40),
-- + when we give it, - when we demand it
trade_magic_items.GOLD_PER_POINT = 1000

-- gold we demand weighs more the less they like us, multiplies the
-- points above; the first tier with attitude <= max_attitude counts.
-- Independent of diplomatic prospects.
local AD_THEIR_GOLD_MULTIPLIERS = {
    { max_attitude = -200, multiplier = 3 },
    { max_attitude = -100, multiplier = 2 }
}

-- their attitude towards us -> diplomatic prospects points. Good
-- attitude: the first tier with attitude >= min_attitude. Bad
-- attitude: the first tier with attitude <= max_attitude. In between:
-- AD_ATTITUDE_MIDDLE_POINTS.
local AD_ATTITUDE_GOOD_TIERS = {
    { min_attitude = 200, points = 20 },
    { min_attitude = 150, points = 15 },
    { min_attitude = 100, points = 10 },
    { min_attitude = 50, points = 5 },
    { min_attitude = 25, points = 0 }
}
local AD_ATTITUDE_BAD_TIERS = {
    { max_attitude = -200, points = -100 },
    { max_attitude = -150, points = -60 },
    { max_attitude = -100, points = -45 },
    { max_attitude = -50, points = -35 },
    { max_attitude = -25, points = -20 }
}
local AD_ATTITUDE_MIDDLE_POINTS = -8

-- recently traded: an item moved between us and them costs extra when it
-- goes back the other way. The minus is the item's rarity points times
-- the share below, right after the deal, and fades evenly to 0 over
-- AD_RECENT_DEAL_TURNS turns. Trading the item again restarts it.
local AD_RECENT_DEAL_TURNS = 10
-- buying from them what any player sold them
local AD_RECENT_SOLD_RARITY_SHARE = 0.5
-- selling back what we bought from them, only for the buyer
local AD_RECENT_BOUGHT_RARITY_SHARE = 0.5

-- deals frequency: a faction that traded items lately, with anyone, is
-- less willing: AD_DEAL_FREQUENCY_FIRST after its first deal, times
-- AD_DEAL_FREQUENCY_GROWTH after each further one (10, 20, 40, 80...).
-- Gone completely after AD_DEAL_FREQUENCY_TURNS turns without a deal.
local AD_DEAL_FREQUENCY_FIRST = 10
local AD_DEAL_FREQUENCY_GROWTH = 2
local AD_DEAL_FREQUENCY_TURNS = 15

-- diplomatic event for a done deal, sent both ways: both sides think
-- better of each other. Value and decay come from cai_personality_
-- diplomatic_event_values_tables: STATE_GIFT_SMALL +10, _MEDIUM +20,
-- _LARGE +40; PAST_EVENT_POSITIVE_MINOR +10, _MODERATE +25, _MAJOR +50.
-- Vanilla values stay untouched (user).
local AD_DEAL_DIPLOMATIC_EVENT = "STATE_GIFT_SMALL"
-- a big deal instead: rarity points of the items on both sides together
-- reach AD_BIG_DEAL_RARITY
local AD_BIG_DEAL_DIPLOMATIC_EVENT = "STATE_GIFT_MEDIUM"
local AD_BIG_DEAL_RARITY = 100


function trade_magic_items.log(message)
    out("[MAGIC_ITEMS_DIPLOMACY " .. AD_VERSION .. "] " .. tostring(message))
end


------------------------------------------------------------
-- DEAL MEMORY
-- What the evaluation remembers between turns, inside the savegame
-- (cm:set_saved_value). Written only by the deal event handlers, so on
-- every client in multiplayer; read by the evaluation.
--   trade_magic_items_recent_items[player][partner][item id] = turn it changed hands
--   trade_magic_items_faction_deals[faction] = { count =, turn = last deal }
-- Items are remembered by the id of the copy, so one copy of two carries
-- the mark and a mirror too. A trade makes a new copy with a new id: the
-- record is written for that id (see the trade watch in TRADE), the old
-- id is gone from the game. The direction needs no field: an id in our
-- list is an item we bought, in theirs one a player sold them. Ids are
-- the same on all clients (MP test 0.12.0), so a record written by one
-- player's deal is found by the other player.
------------------------------------------------------------

local AD_SAVED_ITEMS = "trade_magic_items_recent_items"
local AD_SAVED_FACTION_DEALS = "trade_magic_items_faction_deals"


local function ad_record_item(player, partner, item_id)
    local items = cm:get_saved_value(AD_SAVED_ITEMS) or {}

    items[player] = items[player] or {}
    items[player][partner] = items[player][partner] or {}
    items[player][partner][item_id] = cm:model():turn_number()

    cm:set_saved_value(AD_SAVED_ITEMS, items)
end


-- share of the recently traded minus left (1 on the deal's turn, 0
-- after AD_RECENT_DEAL_TURNS turns or without a record) and how many
-- turns ago the item was traded
local function ad_recent_share(player, partner, item_id)
    local items = cm:get_saved_value(AD_SAVED_ITEMS)
    local turn = items and items[player] and items[player][partner] and items[player][partner][tostring(item_id)]

    if not turn then
        return 0
    end

    local turns_ago = cm:model():turn_number() - turn

    return math.max(0, AD_RECENT_DEAL_TURNS - turns_ago) / AD_RECENT_DEAL_TURNS, turns_ago
end


-- the same for an item in the partner's list: whoever sold it to them
-- (user, 2026-11-01), the freshest deal counts
local function ad_recent_sold_share(partner, item_id)
    local best_share, best_turns = 0, nil

    for player in pairs(cm:get_saved_value(AD_SAVED_ITEMS) or {}) do
        local share, turns = ad_recent_share(player, partner, item_id)

        if share > best_share then
            best_share, best_turns = share, turns
        end
    end

    return best_share, best_turns
end


local function ad_faction_deals_entry(faction)
    local counts = cm:get_saved_value(AD_SAVED_FACTION_DEALS)

    return counts and counts[faction]
end


local function ad_faction_deals_active(entry)
    return entry ~= nil and cm:model():turn_number() - entry.turn < AD_DEAL_FREQUENCY_TURNS
end


-- counts for the faction, whoever the deal was with
local function ad_record_faction_deal(faction)
    local counts = cm:get_saved_value(AD_SAVED_FACTION_DEALS) or {}
    local entry = ad_faction_deals_entry(faction)

    counts[faction] = {
        count = ad_faction_deals_active(entry) and entry.count + 1 or 1,
        turn = cm:model():turn_number()
    }

    cm:set_saved_value(AD_SAVED_FACTION_DEALS, counts)
end


-- the minus, how many turns ago the faction's last deal was and its number
local function ad_deals_frequency_points(faction)
    local entry = ad_faction_deals_entry(faction)

    if not ad_faction_deals_active(entry) then
        return 0
    end

    return -AD_DEAL_FREQUENCY_FIRST * AD_DEAL_FREQUENCY_GROWTH ^ (entry.count - 1),
        cm:model():turn_number() - entry.turn, entry.count
end


------------------------------------------------------------
-- DEAL EVALUATION
-- The working selection and the gold as breakdown values and their
-- total. Numbers: DEAL TUNING above. The screen shows the result.
------------------------------------------------------------

local function ad_attitude_points(attitude)
    for _, tier in ipairs(AD_ATTITUDE_GOOD_TIERS) do
        if attitude >= tier.min_attitude then
            return tier.points
        end
    end

    for _, tier in ipairs(AD_ATTITUDE_BAD_TIERS) do
        if attitude <= tier.max_attitude then
            return tier.points
        end
    end

    return AD_ATTITUDE_MIDDLE_POINTS
end


local function ad_their_gold_multiplier(attitude)
    for _, tier in ipairs(AD_THEIR_GOLD_MULTIPLIERS) do
        if attitude <= tier.max_attitude then
            return tier.multiplier
        end
    end

    return 1
end


-- an item of the Banners or Followers tab (its row's list, see the screen)
local function ad_is_ancillary(info)
    return info.tab == "banners" or info.tab == "followers"
end


local function ad_rarity_points(info)
    local table_of_points = ad_is_ancillary(info) and AD_ANCILLARY_RARITY_POINTS or AD_RARITY_POINTS
    local points = table_of_points[info.rarity]

    if not points then
        trade_magic_items.log("WARNING: no rarity points for " .. tostring(info.key) .. " (rarity " .. tostring(info.rarity) .. ")")
        return 0
    end

    return points
end


local function ad_belongs_points(info)
    local table_of_points = ad_is_ancillary(info) and AD_ANCILLARY_BELONGS_TO_CHARACTER_POINTS or AD_BELONGS_TO_CHARACTER_POINTS

    return table_of_points[info.rarity] or 0
end


-- the working selection + gold as breakdown values and their total
function trade_magic_items.evaluate_deal()
    local player_key = cm:get_local_faction_name(true)
    local partner = trade_magic_items.get_target_faction()
    local partner_key = partner and partner:name()
    local attitude = partner and partner:diplomatic_attitude_towards(player_key)
    local their_items = 0
    local evaluation = {
        attitude = attitude,
        diplomatic_prospects = 0,
        their_gold_multiplier = attitude and ad_their_gold_multiplier(attitude) or 1,
        economic_value = 0,
        deals_frequency = 0,
        offered_rarity = 0,
        offered_recent = 0,
        demanded_rarity = 0,
        demanded_equipped = 0,
        demanded_recent = 0
    }

    if partner_key then
        evaluation.deals_frequency, evaluation.deals_frequency_turns, evaluation.deals_frequency_number =
            ad_deals_frequency_points(partner_key)
    end

    if trade_magic_items.gold then
        local signed = trade_magic_items.gold.direction == "give" and trade_magic_items.gold.amount
            or -trade_magic_items.gold.amount * evaluation.their_gold_multiplier

        evaluation.economic_value = signed / trade_magic_items.GOLD_PER_POINT
    end

    if trade_magic_items.working then
        for item_id, info in pairs(trade_magic_items.working.list_offers) do
            local points = ad_rarity_points(info)

            evaluation.offered_rarity = evaluation.offered_rarity + points

            if partner_key then
                local share, turns = ad_recent_share(player_key, partner_key, item_id)

                evaluation.offered_recent = evaluation.offered_recent - points * AD_RECENT_BOUGHT_RARITY_SHARE * share

                if share > 0 and (not evaluation.offered_recent_turns or turns < evaluation.offered_recent_turns) then
                    evaluation.offered_recent_turns = turns
                end
            end
        end

        for item_id, info in pairs(trade_magic_items.working.list_demands) do
            local points = ad_rarity_points(info)

            their_items = their_items + 1
            evaluation.demanded_rarity = evaluation.demanded_rarity - points

            if partner_key then
                local share, turns = ad_recent_sold_share(partner_key, item_id)

                evaluation.demanded_recent = evaluation.demanded_recent - points * AD_RECENT_SOLD_RARITY_SHARE * share

                if share > 0 and (not evaluation.demanded_recent_turns or turns < evaluation.demanded_recent_turns) then
                    evaluation.demanded_recent_turns = turns
                end
            end

            if info.holder_cqi then
                evaluation.demanded_equipped = evaluation.demanded_equipped - ad_belongs_points(info)
            end
        end
    end

    -- they take our items and pay for them whatever they think of us;
    -- the attitude counts only when they give away something of theirs.
    -- A good attitude can make their items free, never more: it stops at
    -- their price, so it cannot be turned into gold on top
    if attitude and their_items > 0 then
        local price = -(evaluation.demanded_rarity + evaluation.demanded_equipped + evaluation.demanded_recent)

        evaluation.diplomatic_prospects = math.min(ad_attitude_points(attitude), price)
    end

    evaluation.points_without_gold = evaluation.diplomatic_prospects + evaluation.deals_frequency
        + evaluation.offered_rarity + evaluation.offered_recent
        + evaluation.demanded_rarity + evaluation.demanded_equipped + evaluation.demanded_recent
    evaluation.total = evaluation.points_without_gold + evaluation.economic_value

    return evaluation
end


------------------------------------------------------------
-- TRADE (test mode: no AI answer yet, OK executes the deal)
-- Every ticked item moves to the other side, and the gold if set.
-- MP-safe: the clicking machine reads what it can only see in the UI
-- (pooled copy counts) and sends the whole deal as a string through
-- CampaignUI.TriggerCampaignScriptEvent; the UITrigger handler then
-- changes the model on every machine the same way.
--
-- Deal string: "trade_magic_items_trade;" + ops joined by ";"
--   I,<giver>,<receiver>,<key>,<cqi:cqi...>,<pooled taken>,<pooled total>
--     cqis = characters wearing a taken copy (may be empty)
--   G,<payer>,<receiver>,<amount>
--   R,<partner>,<player>,<event>   last op of a deal with the AI
--   H,<partner>,<player>,<event>   last op of a deal between players
--
-- Taking copies (findings E2): a worn copy comes off its character
-- (force_remove_ancillary, deleted). A pooled copy can't be removed
-- alone: all copies go (force_remove_ancillary_from_faction), every
-- remaining holder is re-equipped and the pooled copies that stay are
-- added back - holders of duplicates keep their item.
-- Giving: the original when the receiver may own it (faction set),
-- otherwise its mirror <key>_diplomacy_tradeable (generated, see
-- diplomacy_tradeable_magic_items_mirror.lua); a mirror going back to
-- its own race turns into the original again.
------------------------------------------------------------

trade_magic_items.TRADE_EVENT = "trade_magic_items_trade"

-- TriggerCampaignScriptEvent cuts its string to 255 chars (PROVEN: a
-- 3-item deal arrived cut, the last op crashed the game), so every op
-- is its own event and is checked against this before sending
local AD_TRADE_EVENT_MAX_LENGTH = 255

local AD_MIRROR_SUFFIX = "_diplomacy_tradeable"


local function ad_original_key(key)
    if string.sub(key, -#AD_MIRROR_SUFFIX) == AD_MIRROR_SUFFIX then
        return string.sub(key, 1, -#AD_MIRROR_SUFFIX - 1)
    end

    return key
end


-- what the receiver gets for this item
function trade_magic_items.delivery_key(key, receiver)
    local original = ad_original_key(key)

    if not diplomacy_tradeable_magic_items_mirror then
        trade_magic_items.log("WARNING: mirror table not loaded, giving " .. original)
        return original
    end

    local faction_set = diplomacy_tradeable_magic_items_mirror[original]

    if not faction_set or receiver:is_contained_in_faction_set(faction_set) then
        return original
    end

    return original .. AD_MIRROR_SUFFIX
end


-- copies of the key the faction has (worn + pooled), UI side. By the
-- faction's cqi: on the second player's client the negotiation context
-- may be another faction
local function ad_count_copies(faction, key)
    local count = trade_magic_items.get_context(
        "CcoCampaignFaction",
        tostring(faction:command_queue_index()),
        "AncillaryList.Filter(AncillaryRecordContext.Key == \"" .. key .. "\").Size"
    )

    return type(count) == "number" and count or 0
end


-- ops for one column: giver's items -> receiver. Factions go as their
-- command queue index (short). One op per worn copy, then one op for
-- the pooled copies of a key: the pooled op re-equips whoever still
-- wears the key, so the worn ops must run first.
local function ad_build_item_ops(ops, column, giver, receiver)
    -- key -> { cqis = {}, pooled = n }
    local by_key = {}

    for item_id, info in pairs(column) do
        if info.key then
            by_key[info.key] = by_key[info.key] or { cqis = {}, pooled = 0 }

            if info.holder_cqi then
                table.insert(by_key[info.key].cqis, tostring(info.holder_cqi))
            else
                by_key[info.key].pooled = by_key[info.key].pooled + 1
            end
        else
            trade_magic_items.log("WARNING: selected item without a key skipped: " .. tostring(item_id))
        end
    end

    local giver_cqi = giver:command_queue_index()
    local receiver_cqi = receiver:command_queue_index()

    for key, entry in pairs(by_key) do
        for _, cqi in ipairs(entry.cqis) do
            table.insert(ops, table.concat({ "I", giver_cqi, receiver_cqi, key, cqi, 0, 0 }, ","))
        end

        if entry.pooled > 0 then
            local pooled_total = ad_count_copies(giver, key) - #trade_magic_items.find_holders(giver, key)

            table.insert(ops, table.concat({ "I", giver_cqi, receiver_cqi, key, "", entry.pooled, pooled_total }, ","))
        end
    end
end


local function ad_deal_diplomatic_event(selection)
    local rarity = 0

    if selection then
        for _, column_id in ipairs(trade_magic_items.COLUMNS) do
            for _, info in pairs(selection[column_id]) do
                rarity = rarity + ad_rarity_points(info)
            end
        end
    end

    return rarity >= AD_BIG_DEAL_RARITY and AD_BIG_DEAL_DIPLOMATIC_EVENT or AD_DEAL_DIPLOMATIC_EVENT
end


-- the deal as a list of event strings (one per op), or nil when there
-- is nothing to trade. human: a deal between players, it leaves no mark
-- in the deal memory
function trade_magic_items.build_trade(selection, gold, human)
    local player = cm:get_faction(cm:get_local_faction_name(true))
    local partner = trade_magic_items.get_target_faction()

    if not player or not partner then
        trade_magic_items.log("ERROR: trade without player or partner faction")
        return nil
    end

    local ops = {}

    if selection then
        ad_build_item_ops(ops, selection.list_offers, player, partner)
        ad_build_item_ops(ops, selection.list_demands, partner, player)
    end

    if gold and gold.amount > 0 then
        local payer, receiver = player, partner

        if gold.direction == "demand" then
            payer, receiver = partner, player
        end

        table.insert(ops, table.concat({ "G", payer:command_queue_index(), receiver:command_queue_index(), gold.amount }, ","))
    end

    if #ops == 0 then
        return nil
    end

    -- last: only after everything else in the deal
    table.insert(ops, table.concat({
        human and "H" or "R", partner:command_queue_index(), player:command_queue_index(), ad_deal_diplomatic_event(selection)
    }, ","))

    local events = {}

    for _, op in ipairs(ops) do
        local event = trade_magic_items.TRADE_EVENT .. ";" .. op

        if #event > AD_TRADE_EVENT_MAX_LENGTH then
            trade_magic_items.log("ERROR: trade op too long for the deal event (" .. #event .. " chars), trade cancelled: " .. op)
            return nil
        end

        table.insert(events, event)
    end

    return events
end


-- keeps empty fields ("a,,b" -> a, "", b); gmatch with "*" adds extra
-- empty matches in Lua 5.1. Cuts the rest of the string like vanilla
-- string.split (lib_lua_extensions.lua) and never passes string.find a
-- start position: the old version did, and every trade broke the
-- whole UI right where it ran (findings, X2). Separators are ; , :
-- (no pattern characters). The loop is capped in case find misbehaves.
local AD_SPLIT_MAX_PARTS = 500

local function ad_split(text, separator)
    local parts = {}
    local rest = text

    if type(rest) ~= "string" then
        return parts
    end

    for i = 1, AD_SPLIT_MAX_PARTS do
        local found = string.find(rest, separator)

        if not found then
            table.insert(parts, rest)
            return parts
        end

        table.insert(parts, string.sub(rest, 1, found - 1))
        rest = string.sub(rest, found + 1)
    end

    trade_magic_items.log("ERROR: ad_split stopped after " .. AD_SPLIT_MAX_PARTS .. " parts")
    return parts
end


-- takes the copies from the giver; returns how many were taken
local function ad_take_copies(giver, key, cqis, pooled_taken, pooled_total)
    local taken = 0

    for _, cqi in ipairs(cqis) do
        local character = cm:get_character_by_cqi(tonumber(cqi))

        if character and character:faction():name() == giver:name() and character:has_ancillary(key) then
            cm:force_remove_ancillary(character, key, false, true)
            taken = taken + 1
        else
            trade_magic_items.log("WARNING: " .. key .. " not worn by cqi " .. cqi .. " any more, copy not taken")
        end
    end

    pooled_taken = math.min(pooled_taken, math.max(pooled_total, 0))

    if pooled_taken > 0 then
        local holders = trade_magic_items.find_holders(giver, key)

        cm:force_remove_ancillary_from_faction(giver, key)

        for _, holder in ipairs(holders) do
            cm:force_add_ancillary(holder, key, true, true)
        end

        for i = 1, pooled_total - pooled_taken do
            cm:add_ancillary_to_faction(giver, key, true)
        end

        trade_magic_items.log("  pool of " .. giver:name() .. ": " .. key .. " " .. pooled_total .. " -> " .. (pooled_total - pooled_taken)
            .. ", holders kept " .. #holders)
        taken = taken + pooled_taken
    end

    return taken
end


-- faction from the command queue index in an op, nil if there is none
local function ad_faction_by_cqi(text)
    local cqi = tonumber(text)

    if not cqi then
        return nil
    end

    local faction = cm:model():faction_for_command_queue_index(cqi)

    if not faction or faction:is_null_interface() then
        return nil
    end

    return faction
end


-- "I,giver_cqi,receiver_cqi,key,holder_cqi or empty,pooled_taken,pooled_total"
local function ad_execute_item_op(parts)
    if #parts ~= 7 or parts[4] == "" then
        trade_magic_items.log("ERROR: bad item op (" .. #parts .. " fields), skipped: " .. table.concat(parts, ","))
        return
    end

    local giver = ad_faction_by_cqi(parts[2])
    local receiver = ad_faction_by_cqi(parts[3])
    local key = parts[4]
    local cqis = parts[5] ~= "" and { parts[5] } or {}
    local pooled_taken = tonumber(parts[6]) or 0
    local pooled_total = tonumber(parts[7]) or 0

    if not giver or not receiver then
        trade_magic_items.log("ERROR: bad item op (faction not found), skipped: " .. table.concat(parts, ","))
        return
    end

    local taken = ad_take_copies(giver, key, cqis, pooled_taken, pooled_total)
    local delivered = trade_magic_items.delivery_key(key, receiver)

    for i = 1, taken do
        cm:add_ancillary_to_faction(receiver, delivered, false)
    end

    trade_magic_items.log("  " .. key .. " x" .. taken .. ": " .. giver:name() .. " -> " .. receiver:name()
        .. (delivered ~= key and (" as " .. delivered) or ""))
end


-- "G,payer_cqi,receiver_cqi,amount"
local function ad_execute_gold_op(parts)
    if #parts ~= 4 then
        trade_magic_items.log("ERROR: bad gold op (" .. #parts .. " fields), skipped: " .. table.concat(parts, ","))
        return
    end

    local payer = ad_faction_by_cqi(parts[2])
    local receiver = ad_faction_by_cqi(parts[3])
    local amount = tonumber(parts[4]) or 0

    if not payer or not receiver then
        trade_magic_items.log("ERROR: bad gold op (faction not found), skipped: " .. table.concat(parts, ","))
        return
    end

    -- the treasury may have changed since the deal was made
    amount = math.min(amount, math.max(payer:treasury(), 0))

    cm:treasury_mod(payer:name(), -amount)
    cm:treasury_mod(receiver:name(), amount)
    trade_magic_items.log("  gold " .. amount .. ": " .. payer:name() .. " -> " .. receiver:name())
end


-- "N,player_cqi,partner_cqi,item_id": a copy that changed hands
local function ad_execute_item_record_op(parts)
    if #parts ~= 4 then
        trade_magic_items.log("ERROR: bad record op (" .. #parts .. " fields), skipped: " .. table.concat(parts, ","))
        return
    end

    local player = ad_faction_by_cqi(parts[2])
    local partner = ad_faction_by_cqi(parts[3])

    if not player or not partner then
        trade_magic_items.log("ERROR: bad record op (faction not found), skipped: " .. table.concat(parts, ","))
        return
    end

    ad_record_item(player:name(), partner:name(), parts[4])
    trade_magic_items.log("  recently traded: item " .. parts[4] .. " with " .. partner:name())
end


-- "R,partner_cqi,player_cqi,event": both sides think better of each
-- other. One direction showed +10 only on one side (0.8.7).
-- "H,...": the same between players, without the deal memory (AI logic)
local function ad_execute_relation_op(parts, human)
    if #parts ~= 4 then
        trade_magic_items.log("ERROR: bad relation op (" .. #parts .. " fields), skipped: " .. table.concat(parts, ","))
        return
    end

    local partner = ad_faction_by_cqi(parts[2])
    local player = ad_faction_by_cqi(parts[3])

    if not partner or not player then
        trade_magic_items.log("ERROR: bad relation op (faction not found), skipped: " .. table.concat(parts, ","))
        return
    end

    cm:cai_add_diplomatic_event(player:name(), partner:name(), parts[4])
    cm:cai_add_diplomatic_event(partner:name(), player:name(), parts[4])
    trade_magic_items.log("  " .. parts[4] .. ": " .. player:name() .. " <-> " .. partner:name())

    if not human then
        ad_record_faction_deal(player:name())
        ad_record_faction_deal(partner:name())
        trade_magic_items.log("  deals of " .. partner:name() .. ": " .. ad_faction_deals_entry(partner:name()).count)

        -- this is the deal's last op
        trade_magic_items.check_trade_watch()
    end

    trade_magic_items.on_deal_done()
end


-- one deal event = one op: "trade_magic_items_trade;<op>"
function trade_magic_items.execute_trade_op(event)
    local op = string.sub(event, #trade_magic_items.TRADE_EVENT + 2)
    local parts = ad_split(op, ",")

    -- logged before the op: a crash inside it shows which one it was
    trade_magic_items.log("Trade op: " .. op)

    local ok, err = pcall(function()
        if parts[1] == "I" then
            ad_execute_item_op(parts)
        elseif parts[1] == "G" then
            ad_execute_gold_op(parts)
        elseif parts[1] == "R" then
            ad_execute_relation_op(parts, false)
        elseif parts[1] == "H" then
            ad_execute_relation_op(parts, true)
        elseif parts[1] == "N" then
            ad_execute_item_record_op(parts)
        else
            trade_magic_items.log("ERROR: unknown trade op, skipped")
        end
    end)

    if not ok then
        trade_magic_items.log("ERROR: trade op failed: " .. op .. " | " .. tostring(err))
    end
end


core:add_listener(
    "AD_TradeExecute",
    "UITrigger",

    function(context)
        return string.sub(context:trigger(), 1, #trade_magic_items.TRADE_EVENT + 1) == trade_magic_items.TRADE_EVENT .. ";"
    end,

    function(context)
        trade_magic_items.execute_trade_op(context:trigger())
    end,

    true
)


------------------------------------------------------------
-- HUMAN DEAL EVENTS
-- How two players talk about a deal. These events reach every client but
-- change no model, each client only updates its own window (screen,
-- HUMAN PARTNER: FLOW). The model changes in the trade_magic_items_trade ops the
-- accepting client sends.
--
-- "trade_magic_items_human;" + fields joined by ","; always kind, deal, from, to (the
-- last two: faction command queue index):
--   B,deal,from,to,base,payer,amount,items  a proposal starts. base: the
--       deal it answers or 0; payer: 0 without gold; items: I events to come
--   I,deal,from,to,owner,key,holder         one item, holder empty = pool
--   E,deal,from,to                          the proposal is complete
--   A,deal,from,to                          accepted
--   D,deal,from,to                          declined
------------------------------------------------------------

trade_magic_items.HUMAN_EVENT = "trade_magic_items_human"


-- fields as a list; false when the event would not fit
function trade_magic_items.send_human_event(fields)
    local event = trade_magic_items.HUMAN_EVENT .. ";" .. table.concat(fields, ",")

    if #event > AD_TRADE_EVENT_MAX_LENGTH then
        trade_magic_items.log("ERROR: human deal event too long (" .. #event .. " chars): " .. event)
        return false
    end

    trade_magic_items.log("Human event sent: " .. event)
    CampaignUI.TriggerCampaignScriptEvent(cm:get_faction(cm:get_local_faction_name(true)):command_queue_index(), event)

    return true
end


core:add_listener(
    "AD_HumanDealEvent",
    "UITrigger",

    function(context)
        return string.sub(context:trigger(), 1, #trade_magic_items.HUMAN_EVENT + 1) == trade_magic_items.HUMAN_EVENT .. ";"
    end,

    function(context)
        local fields = string.sub(context:trigger(), #trade_magic_items.HUMAN_EVENT + 2)

        trade_magic_items.log("Human event: " .. fields)

        local ok, err = pcall(trade_magic_items.on_human_event, ad_split(fields, ","))

        if not ok then
            trade_magic_items.log("ERROR: human deal event failed: " .. fields .. " | " .. tostring(err))
        end
    end,

    true
)


trade_magic_items.log("MOD LOADED")
