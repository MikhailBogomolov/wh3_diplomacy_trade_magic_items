------------------------------------------------------------
-- DIPLOMACY OPTION BUTTON
-- Our button in the native action row: when it shows, its place, the
-- war lock, opening our screen; and the diplomacy panel helpers.
------------------------------------------------------------

trade_magic_items = trade_magic_items or {}


local AD_BUTTON_ID = "diplomatic_option_trade_magic_items"
local AD_BUTTON_XML =
    "ui/campaign ui/diplomatic_option_trade_magic_items.twui.xml"

-- set while the diplomacy panel is open (the button watcher runs
-- ~30 times a second, so it must not search from the UI root each time)
local ad_diplomacy_cache = nil

-- our panel, once created in this diplomacy session (it is destroyed
-- together with the diplomacy panel)
trade_magic_items.panel_cache = nil


function trade_magic_items.get_diplomacy()
    if ad_diplomacy_cache then
        return ad_diplomacy_cache
    end

    return find_uicomponent(
        core:get_ui_root(),
        "diplomacy_dropdown"
    )
end


local function ad_get_action_list()
    local diplomacy = trade_magic_items.get_diplomacy()

    if not diplomacy then
        return nil
    end

    return find_uicomponent(
        diplomacy,
        "list_possible_actions"
    )
end


function trade_magic_items.get_offers_panel()
    local diplomacy = trade_magic_items.get_diplomacy()

    if not diplomacy then
        return nil
    end

    return find_uicomponent(
        diplomacy,
        "offers_panel"
    )
end


-- native action order (diplomatic_actions_tables sort_order, "default"
-- group): state_gift 200, state_gift_unilateral 201, payment 202,
-- join_war 203, peace 204, declare_war 205, ... trade_regions 300
local AD_BUTTON_ANCHORS_AFTER = {
    "diplomatic_option_payment",
    "diplomatic_option_state_gift_unilateral",
    "diplomatic_option_state_gift"
}

local AD_BUTTON_ANCHORS_BEFORE = {
    "diplomatic_option_join_war",
    "diplomatic_option_peace",
    "diplomatic_option_declare_war",
    "diplomatic_option_trade_regions",
    "diplomatic_option_trade_technology",
    "diplomatic_option_hostage",
    "diplomatic_option_mariiage"
}


-- index of the direct child with this id, or nil
-- (there is no GetIndex(); compare addresses while iterating)
local function ad_get_child_index(parent, child_id)
    local child = find_uicomponent(parent, child_id)

    if not child then
        return nil
    end

    for i = 0, parent:ChildCount() - 1 do
        if UIComponent(parent:Find(i)):Address() == child:Address() then
            return i
        end
    end
end


local AD_BUTTON_TITLE_KEY = "diplomacy_strings_string_diplomatic_option_trade_magic_items"
local AD_BUTTON_TOOLTIP_KEY = "diplomacy_strings_string_diplomatic_option_trade_magic_items_tooltip"
local AD_BUTTON_AT_WAR_KEY = "trade_magic_items_button_needs_peace"


-- "title||body", body from body_key
local function ad_set_button_tooltip(button, body_key)
    local title_text = common.get_localised_string(AD_BUTTON_TITLE_KEY)
    local body_text = common.get_localised_string(body_key)

    if title_text == "" or body_text == "" then
        trade_magic_items.log("WARNING: tooltip localisation lookup failed for " .. body_key .. "; keeping the old tooltip")
        return
    end

    button:SetTooltipText(title_text .. "||" .. body_text, body_key, true)
end


local function ad_create_trade_magic_items_button()
    local action_list = ad_get_action_list()

    if not action_list then
        trade_magic_items.log("ERROR: list_possible_actions not found")
        return
    end


    if find_uicomponent(action_list, AD_BUTTON_ID) then
        return
    end


    local button_address = action_list:CreateComponent(
        AD_BUTTON_ID,
        AD_BUTTON_XML
    )

    if not button_address then
        trade_magic_items.log("ERROR: magic items button CreateComponent failed")
        return
    end


    local button = UIComponent(button_address)
    button:SetVisible(true)


    ad_set_button_tooltip(button, AD_BUTTON_TOOLTIP_KEY)


    ------------------------------------------------------------
    -- PLACEMENT
    -- Keep the same spot in the native order: right after payment.
    -- When payment is gone (already a term), take payment's place:
    -- after the gift buttons / before the actions that follow payment.
    ------------------------------------------------------------

    local placed_after, placed_before

    for _, anchor in ipairs(AD_BUTTON_ANCHORS_AFTER) do
        local index = ad_get_child_index(action_list, anchor)

        if index then
            action_list:Adopt(button:Address(), index + 1)
            placed_after = anchor
            break
        end
    end

    if not placed_after then
        for _, anchor in ipairs(AD_BUTTON_ANCHORS_BEFORE) do
            local index = ad_get_child_index(action_list, anchor)

            if index then
                action_list:Adopt(button:Address(), index)
                placed_before = anchor
                break
            end
        end
    end


    trade_magic_items.log(
        "Trade magic items button created "
        .. (placed_after and ("after " .. placed_after) or (placed_before and ("before " .. placed_before) or "at the end"))
    )
end


------------------------------------------------------------
-- BUTTON WATCHER
-- The native UI rebuilds list_possible_actions whenever the deal or
-- the negotiation changes (term added/removed, proposal answered,
-- entering through the map instead of the faction list), which
-- destroys our button. While diplomacy is open, a real-time (UI)
-- timer puts it back. UI only - safe in multiplayer.
------------------------------------------------------------

local AD_BUTTON_WATCHER = "ad_trade_magic_items_button_watcher"

-- ~2 frames: keeps the pop-in after a native rebuild barely visible
local AD_BUTTON_WATCHER_INTERVAL_MS = 33

-- trading items is possible under the same conditions as these
-- actions: at war (peace only) or with confederation chosen they
-- are not offered
local AD_TRADE_ACTIONS = {
    "diplomatic_option_payment",
    "diplomatic_option_trade_regions"
}

local ad_button_available = nil


-- a payment / settlement term already in the deal removes its action
-- button, but trading is still possible
local function ad_get_deal_term_ids()
    local ids = {}
    local diplomacy = trade_magic_items.get_diplomacy()

    if not diplomacy then
        return ids
    end

    for _, list_id in ipairs({ "your_offers_list", "their_offers_list" }) do
        local list_box = find_uicomponent(diplomacy, list_id, "list_box")

        if list_box then
            for i = 0, list_box:ChildCount() - 1 do
                table.insert(ids, UIComponent(list_box:Find(i)):Id())
            end
        end
    end

    return ids
end


local function ad_is_item_trading_available(action_list)
    -- an offer from them: only Accept / Reject / Counter until countered
    local accept = find_uicomponent(trade_magic_items.get_diplomacy(), "button_accept")

    if accept and accept:VisibleFromRoot() then
        return false, "their offer is on the table"
    end

    for _, action_id in ipairs(AD_TRADE_ACTIONS) do
        if find_uicomponent(action_list, action_id) then
            return true, "action " .. action_id
        end
    end

    for _, term_id in ipairs(ad_get_deal_term_ids()) do
        if string.find(term_id, "payment") or string.find(term_id, "trade_region") then
            return true, "deal term " .. term_id
        end
    end

    return false, "no payment / trade settlement (terms: " .. table.concat(ad_get_deal_term_ids(), ", ") .. ")"
end


------------------------------------------------------------
-- AT WAR / NO TRADE AGREEMENT
-- With Peace in the deal the native actions (payment...) come back
-- while the factions are still at war; our button stays greyed out
-- with a tooltip until peace is actually made (user, 2026-10-28).
-- 1.1.0: with the setting trade_agreement_only (MCT, off by default)
-- the button is also greyed while there is no trade agreement with the
-- partner (user, 2026-11-16); war comes first. Neither can change while
-- our window is open (user), so the button is all that needs it.
-- The model is asked on every new button and every ~0.5 s.
------------------------------------------------------------

local AD_WAR_CHECK_TICKS = 15
local AD_BUTTON_NO_TRADE_AGREEMENT_KEY = "trade_magic_items_button_needs_trade_agreement"

-- why the button is greyed: "war", "no_trade_agreement" or false
local ad_blocked = false
local ad_war_ticks = 0
local ad_war_button_address = nil


-- trade_agreement_with is not in CA's docs we have (seen in another mod):
-- if it fails, trading is not blocked by it
local ad_trade_agreement_error_logged = false

local function ad_has_trade_agreement(player, target)
    local ok, result = pcall(function() return player:trade_agreement_with(target) end)

    if not ok then
        -- asked about twice a second while diplomacy is open: log it once
        if not ad_trade_agreement_error_logged then
            trade_magic_items.log("ERROR: trade_agreement_with failed, the rule is not applied: " .. tostring(result))
            ad_trade_agreement_error_logged = true
        end

        return true
    end

    return result == true
end


local function ad_block_reason(player, target)
    if player == nil or target == nil then
        return false
    end

    if player:at_war_with(target) then
        return "war"
    end

    if trade_magic_items.settings.trade_agreement_only and not ad_has_trade_agreement(player, target) then
        return "no_trade_agreement"
    end

    return false
end


local function ad_follow_war(button)
    ad_war_ticks = ad_war_ticks + 1

    if button:Address() == ad_war_button_address and ad_war_ticks < AD_WAR_CHECK_TICKS then
        return
    end

    ad_war_ticks = 0
    ad_war_button_address = button:Address()

    local player = cm:get_faction(cm:get_local_faction_name(true))
    local target = trade_magic_items.get_target_faction()
    local blocked = ad_block_reason(player, target)

    if blocked ~= ad_blocked then
        trade_magic_items.log("Item trading " .. (blocked and ("blocked (" .. blocked .. "): ") or "unblocked: ") .. tostring(target and target:name()))
        ad_blocked = blocked

        local tooltip = AD_BUTTON_TOOLTIP_KEY

        if blocked == "war" then
            tooltip = AD_BUTTON_AT_WAR_KEY
        elseif blocked == "no_trade_agreement" then
            tooltip = AD_BUTTON_NO_TRADE_AGREEMENT_KEY
        end

        ad_set_button_tooltip(button, tooltip)
    end

    if blocked and button:CurrentState() ~= "inactive" then
        button:SetState("inactive")
    elseif not blocked and button:CurrentState() == "inactive" then
        button:SetState("active")
    end
end


local function ad_ensure_trade_magic_items_button()
    local action_list = ad_get_action_list()

    if not action_list then
        return
    end

    local available, reason = ad_is_item_trading_available(action_list)
    local button = find_uicomponent(action_list, AD_BUTTON_ID)

    if available ~= ad_button_available then
        trade_magic_items.log("Item trading " .. (available and "available" or "NOT available") .. ": " .. reason)
        ad_button_available = available
    end

    if button and available then
        ad_follow_war(button)
        return
    end

    if available and not button then
        ad_create_trade_magic_items_button()

        -- a new button starts active with the normal tooltip
        ad_blocked = false
        ad_war_button_address = nil

        button = find_uicomponent(action_list, AD_BUTTON_ID)

        if button then
            ad_follow_war(button)
        end
    elseif not available and button then
        button:Destroy()
    else
        return
    end

    -- the action list was rebuilt (button missing or no longer allowed):
    -- the negotiation partner may have changed, and a pending
    -- selection belongs to one partner
    if trade_magic_items.pending then
        local target = trade_magic_items.get_target_faction()

        if target and trade_magic_items.pending.target ~= target:name() then
            trade_magic_items.clear_selection("negotiation target changed")
        end
    end
end


local function ad_start_button_watcher()
    cm:remove_real_callback(AD_BUTTON_WATCHER)
    ad_button_available = nil
    trade_magic_items.laid_out_height = nil
    ad_diplomacy_cache = find_uicomponent(core:get_ui_root(), "diplomacy_dropdown") or nil

    cm:repeat_real_callback(
        function()
            local ok, err = pcall(ad_ensure_trade_magic_items_button)

            if not ok then
                trade_magic_items.log("ERROR: button watcher failed: " .. tostring(err))
            end

            local size_ok, size_err = pcall(trade_magic_items.follow_panel_height)

            if not size_ok then
                trade_magic_items.log("ERROR: panel height follow failed: " .. tostring(size_err))
            end

            local hide_ok, hide_err = pcall(trade_magic_items.keep_offers_hidden)

            if not hide_ok then
                trade_magic_items.log("ERROR: hiding the offers panel failed: " .. tostring(hide_err))
            end
        end,
        AD_BUTTON_WATCHER_INTERVAL_MS,
        AD_BUTTON_WATCHER
    )

    trade_magic_items.log("Button watcher started")
end


local function ad_stop_button_watcher()
    cm:remove_real_callback(AD_BUTTON_WATCHER)
    ad_diplomacy_cache = nil
    trade_magic_items.panel_cache = nil
    trade_magic_items.log("Button watcher stopped")
end


------------------------------------------------------------
-- DIPLOMACY OPENED
------------------------------------------------------------

core:add_listener(
    "AD_DiplomacyOpened",
    "PanelOpenedCampaign",

    function(context)
        return context.string == "diplomacy_dropdown"
    end,

    function()
        trade_magic_items.log("Diplomacy opened")
        ad_start_button_watcher()
    end,

    true
)


core:add_listener(
    "AD_DiplomacyClosed",
    "PanelClosedCampaign",

    function(context)
        return context.string == "diplomacy_dropdown"
    end,

    function()
        local ok, err = pcall(trade_magic_items.hide_window_after_diplomacy)

        if not ok then
            trade_magic_items.log("ERROR: hiding our window failed: " .. tostring(err))
        end

        ad_stop_button_watcher()
        trade_magic_items.clear_selection("diplomacy closed")
    end,

    true
)


------------------------------------------------------------
-- TRADE MAGIC ITEMS BUTTON CLICKED
------------------------------------------------------------

core:add_listener(
    "AD_TradeMagicItemsClicked",
    "ComponentLClickUp",

    function(context)
        return context.string == AD_BUTTON_ID
    end,

    function()

        trade_magic_items.log("TRADE MAGIC ITEMS BUTTON CLICKED")

        if ad_blocked then
            trade_magic_items.log("Ignored: item trading blocked (" .. ad_blocked .. ")")
            return
        end

        trade_magic_items.open_trade_magic_items_panel()

    end,

    true
)
