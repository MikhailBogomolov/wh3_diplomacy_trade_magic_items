------------------------------------------------------------
-- SCREEN
-- Our Trade Magic Items window: item lists, selection, gold, the deal
-- chance, opening and closing it, the OK and Cancel buttons.
------------------------------------------------------------

trade_magic_items = trade_magic_items or {}


local AD_PANEL_ID = "trade_magic_items"

local AD_PANEL_XML =
    "ui/campaign ui/diplomacy_hud_trade_magic_items.twui.xml"


local function ad_setup_magic_items_panel(panel)
    local offer_demand_parent = find_uicomponent(
        panel,
        "offer_demand_parent"
    )

    if not offer_demand_parent then
        trade_magic_items.log("WARNING: offer_demand_parent not found")
        return
    end


    local list_offers = find_uicomponent(
        offer_demand_parent,
        "list_offers"
    )

    if not list_offers then
        trade_magic_items.log("WARNING: list_offers not found")
        return
    end


    local offers_title = find_uicomponent(
        list_offers,
        "offers_title"
    )

    if offers_title then
        offers_title:SetState("offers")
    end


    local existing_demands = find_uicomponent(
        offer_demand_parent,
        "list_demands"
    )

    if existing_demands then
        return
    end


    local demands_address = list_offers:CopyComponent(
        "list_demands"
    )

    if not demands_address then
        trade_magic_items.log("ERROR: failed to copy list_offers into list_demands")
        return
    end


    local list_demands = UIComponent(demands_address)
    list_demands:SetVisible(true)


    local demands_title = find_uicomponent(
        list_demands,
        "offers_title"
    )

    if demands_title then
        demands_title:SetState("demands")
    end


    trade_magic_items.log("Magic items panel two-column layout prepared")
end


------------------------------------------------------------
-- ITEM LISTS
-- Each column has a magic_items_list with the native List
-- callback (copied from the character panel). The game fills
-- the rows from the list's CcoCampaignFaction context:
--   left  (list_offers):  local player's faction
--   right (list_demands): negotiation target
-- Both are set here with SetContextObject. The XML must NOT use
-- ContextInitPlayerFaction: the copied right list would fill itself
-- with the player's items a frame later and keep them as empty rows.
--
-- 1.1.0: three lists per column, one per tab, each with its own filter
-- (tools/build_tabs.js). All stay bound, only the current tab's list is
-- visible. The banners / followers filters (and part of the magic items
-- one) check that both sides can use the item: the partner's key goes
-- to the layout as the script object below, before the lists are bound.
------------------------------------------------------------

-- tab -> list id, in tab order
trade_magic_items.TABS = { "magic", "banners", "followers" }

local AD_ITEM_LIST_IDS = {
    magic = "magic_items_list",
    banners = "banners_list",
    followers = "followers_list"
}

-- read by the list filters (ScriptObjectContext)
local AD_PARTNER_CONTEXT = "trade_magic_items_partner"


-- the partner of a deal that came from another player, while its window
-- is open: on that client the negotiation context may be someone else
trade_magic_items.human_partner = nil


function trade_magic_items.get_target_faction()
    if trade_magic_items.human_partner then
        return cm:get_faction(trade_magic_items.human_partner)
    end

    local ok, key = pcall(
        common.get_context_value,
        "CcoCampaignRoot",
        "",
        "CurrentNegotiatingFactionContext.FactionRecordContext.Key"
    )

    if not ok or type(key) ~= "string" or key == "" then
        return nil
    end

    return cm:get_faction(key)
end


local function ad_get_item_list(panel, column_id, tab)
    local column = find_uicomponent(panel, column_id)

    if not column then
        return nil
    end

    return find_uicomponent(column, AD_ITEM_LIST_IDS[tab])
end


-- { { tab =, list = }, ... } of a column, in tab order
local function ad_get_item_lists(panel, column_id)
    local lists = {}

    for _, tab in ipairs(trade_magic_items.TABS) do
        local list = ad_get_item_list(panel, column_id, tab)

        if list then
            table.insert(lists, { tab = tab, list = list })
        end
    end

    return lists
end


local function ad_bind_item_list(panel, column_id, faction)
    local cqi = tostring(faction:command_queue_index())

    for _, tab in ipairs(trade_magic_items.TABS) do
        local list = ad_get_item_list(panel, column_id, tab)

        if list then
            list:SetContextObject(cco("CcoCampaignFaction", cqi))
        else
            trade_magic_items.log("ERROR: " .. column_id .. " " .. AD_ITEM_LIST_IDS[tab] .. " not found")
        end
    end

    trade_magic_items.log("Item lists bound: " .. column_id .. " -> " .. faction:name() .. " (cqi " .. cqi .. ")")
end


-- The Banners / Followers filters again, for the tab buttons: whether a
-- tab has anything must be known when the window opens, before the lists
-- fill a few frames later (user, test 1: the Banners tab flashed grey on
-- open). KEEP IN SYNC with FILTERS in tools/build_tabs.js. Once the rows
-- are read the tabs go by the rows, so a mismatch shows in the log.
local AD_FILTER_BASE = "AncillaryRecordContext.Transferrable == true"
    .. " && AncillaryRecordContext.UniquenessRecordContext.Key != \"wh_main_anc_group_unique\""
    .. " && AncillaryRecordContext.UniquenessRecordContext.Key != \"wh_main_anc_group_unique_fusable\""
    .. " && AncillaryRecordContext.UniquenessRecordContext.Key != \"wh2_dlc17_anc_group_rune\""
    .. " && AncillaryRecordContext.UniquenessRecordContext.Key != \"wh_main_anc_group_scrap\""
    .. " && AncillaryRecordContext.UniquenessRecordContext.Key != \"wh_main_anc_group_scrap_upgraded\""

local AD_FILTER_SAME_RACE = "AncillaryRecordContext.CanFactionUseAncillary(PlayersFaction.FactionRecordContext)"
    .. " && AncillaryRecordContext.CanFactionUseAncillary(FactionContextFromKey(ScriptObjectContext(\"" .. AD_PARTNER_CONTEXT .. "\").StringValue).FactionRecordContext)"

local AD_TAB_FILTERS = {
    banners = "AncillaryRecordContext.CategoryContext.Category == \"general\""
        .. " && (AncillaryRecordContext.SubcategoryContext.Subcategory == \"banner\""
        .. " || AncillaryRecordContext.SubcategoryContext.Subcategory == \"banner_rune\""
        .. " || AncillaryRecordContext.SubcategoryContext.Subcategory == \"engineering_rune\")"
        .. " && " .. AD_FILTER_BASE
        .. " && " .. AD_FILTER_SAME_RACE
        .. " && AncillaryRecordContext.Key != \"wh3_dlc29_anc_standard_hef_shadow_banner\"",
    followers = "AncillaryRecordContext.CategoryContext.Category == \"general\""
        .. " && AncillaryRecordContext.SubcategoryContext.Subcategory == \"follower\""
        .. " && " .. AD_FILTER_BASE
        .. " && " .. AD_FILTER_SAME_RACE
        .. " && AncillaryRecordContext.Key != \"wh2_dlc17_bst_anc_follower_battle_scarred_ungor_raider\""
        .. " && AncillaryRecordContext.Key != \"wh2_main_anc_follower_lzd_librarian\""
}

-- items of the tab on both sides, counted on binding: tab -> count
local ad_tab_counts = {}


-- needs the partner script object set
local function ad_count_tab_items(player, target)
    ad_tab_counts = {}

    for tab, filter in pairs(AD_TAB_FILTERS) do
        local count = 0

        for _, faction in ipairs({ player, target }) do
            local size = trade_magic_items.get_context("CcoCampaignFaction", tostring(faction:command_queue_index()), "AncillaryList.Filter(" .. filter .. ").Size")

            count = count + (type(size) == "number" and size or 0)
        end

        ad_tab_counts[tab] = count
    end

    trade_magic_items.log("Tab items on binding: banners " .. tostring(ad_tab_counts.banners) .. ", followers " .. tostring(ad_tab_counts.followers))
end


-- TEMP 1.1.0 (test 1: AI partners seemed to have few banners and
-- followers): how many of the faction's banners / followers are left after
-- each step of the tab filters, and which keys each step drops
local AD_DIAG_STEPS = {
    { name = "transferable", test = "AncillaryRecordContext.Transferrable == true" },
    { name = "not unique", test = "AncillaryRecordContext.UniquenessRecordContext.Key != \"wh_main_anc_group_unique\""
        .. " && AncillaryRecordContext.UniquenessRecordContext.Key != \"wh_main_anc_group_unique_fusable\"" },
    { name = "both can use", test = AD_FILTER_SAME_RACE }
}

local AD_DIAG_KINDS = {
    { name = "followers", test = "AncillaryRecordContext.CategoryContext.Category == \"general\" && AncillaryRecordContext.SubcategoryContext.Subcategory == \"follower\"" },
    { name = "banners", test = "AncillaryRecordContext.CategoryContext.Category == \"general\" && AncillaryRecordContext.SubcategoryContext.Subcategory == \"banner\"" }
}

local function ad_log_filter_steps(faction)
    local cqi = tostring(faction:command_queue_index())

    for _, kind in ipairs(AD_DIAG_KINDS) do
        local passed = kind.test
        local counts = { "all " .. tostring(trade_magic_items.get_context("CcoCampaignFaction", cqi, "AncillaryList.Filter(" .. passed .. ").Size")) }
        local dropped = {}

        for _, step in ipairs(AD_DIAG_STEPS) do
            local keys = trade_magic_items.get_context("CcoCampaignFaction", cqi,
                "AncillaryList.Filter(" .. passed .. " && (" .. step.test .. ") == false).JoinString(AncillaryRecordContext.Key, \" \")")

            passed = passed .. " && " .. step.test
            table.insert(counts, step.name .. " " .. tostring(trade_magic_items.get_context("CcoCampaignFaction", cqi, "AncillaryList.Filter(" .. passed .. ").Size")))

            if type(keys) == "string" and keys ~= "" then
                table.insert(dropped, step.name .. ": " .. keys)
            end
        end

        trade_magic_items.log("Filter steps " .. faction:name() .. " " .. kind.name .. ": " .. table.concat(counts, ", "))

        for _, line in ipairs(dropped) do
            trade_magic_items.log("  dropped by " .. line)
        end
    end
end


local function ad_bind_item_lists(panel)
    -- UI only: the local player's faction is correct here even in MP
    local player = cm:get_faction(cm:get_local_faction_name(true))
    local target = trade_magic_items.get_target_faction()

    if not player or not target then
        trade_magic_items.log("ERROR: player or negotiation target faction not found")
        return
    end

    -- before binding: the filters read it when the lists fill
    local set_ok, set_err = pcall(common.set_context_value, AD_PARTNER_CONTEXT, target:name())

    if not set_ok then
        trade_magic_items.log("ERROR: setting the partner for the filters failed: " .. tostring(set_err))
    end

    -- TEMP 1.1.0: is the race check of the filters alive?
    trade_magic_items.log("Filter check: partner context = "
        .. tostring(trade_magic_items.get_context("CcoCampaignRoot", "", "ScriptObjectContext(\"" .. AD_PARTNER_CONTEXT .. "\").StringValue"))
        .. ", partner record = "
        .. tostring(trade_magic_items.get_context("CcoCampaignRoot", "", "FactionContextFromKey(ScriptObjectContext(\"" .. AD_PARTNER_CONTEXT .. "\").StringValue).FactionRecordContext.Key"))
        .. ", player record = "
        .. tostring(trade_magic_items.get_context("CcoCampaignRoot", "", "PlayersFaction.FactionRecordContext.Key")))

    for _, faction in ipairs({ player, target }) do
        local steps_ok, steps_err = pcall(ad_log_filter_steps, faction)

        if not steps_ok then
            trade_magic_items.log("ERROR: filter steps log failed: " .. tostring(steps_err))
        end
    end

    local count_ok, count_err = pcall(ad_count_tab_items, player, target)

    if not count_ok then
        trade_magic_items.log("ERROR: counting the tab items failed: " .. tostring(count_err))
    end

    ad_bind_item_list(panel, "list_offers", player)
    ad_bind_item_list(panel, "list_demands", target)
end


------------------------------------------------------------
-- EQUIPPED-BY PORTRAITS
-- The row's native portrait uses CharacterEquippedToContext, which
-- is only filled for the local player's characters; those rows are
-- left fully native. For every other row we ask the model who wears
-- the item (has_ancillary, per item key) and show our own portrait.
-- Copies of one item are identical, so holders are handed out to
-- that key's rows in order; rows left over are pooled copies.
--
-- The native portrait can't be reused: its tooltip/image setters
-- come from the ancillary_entry template and always win (empty name
-- for AI characters). ad_holder_portrait.twui.xml is a copy of it
-- without any callbacks, created inside the row's ancillary_entry.
------------------------------------------------------------

local AD_HOLDER_PORTRAIT_ID = "ad_holder_portrait"

local AD_HOLDER_PORTRAIT_XML =
    "ui/campaign ui/ad_holder_portrait.twui.xml"


function trade_magic_items.get_context(object_type, object_id, expression)
    local ok, value = pcall(common.get_context_value, object_type, object_id, expression)

    if ok then
        return value
    end
end


function trade_magic_items.find_holders(faction, item_key)
    local holders = {}
    local character_list = faction:character_list()

    for i = 0, character_list:num_items() - 1 do
        local character = character_list:item_at(i)

        if character:has_ancillary(item_key) then
            table.insert(holders, character)
        end
    end

    return holders
end


local function ad_get_holder_portrait(row, create)
    local entry = find_uicomponent(row, "ancillary_entry")

    if not entry then
        return nil
    end

    local portrait = find_uicomponent(entry, AD_HOLDER_PORTRAIT_ID)

    if portrait or not create then
        return portrait
    end

    local address = entry:CreateComponent(AD_HOLDER_PORTRAIT_ID, AD_HOLDER_PORTRAIT_XML)

    if not address then
        trade_magic_items.log("ERROR: holder portrait CreateComponent failed")
        return nil
    end

    return UIComponent(address)
end


-- shows our portrait for the character, or hides it (character = nil)
local function ad_show_holder_portrait(row, character)
    if not character then
        local existing = ad_get_holder_portrait(row, false)

        if existing then
            existing:SetVisible(false)
        end

        return false
    end

    local portrait = ad_get_holder_portrait(row, true)

    if not portrait then
        return false
    end

    local cqi = tostring(character:command_queue_index())
    local image = trade_magic_items.get_context("CcoCampaignCharacter", cqi, "ImageCardPath")

    -- same localised sentence the native tooltip uses ("... assigned to <name>")
    local tooltip = trade_magic_items.get_context("CcoCampaignCharacter", cqi, "Format(Loc(\"ancillary_assigned\"), Name)")

    if type(tooltip) ~= "string" or tooltip == "" then
        tooltip = tostring(trade_magic_items.get_context("CcoCampaignCharacter", cqi, "Name") or character:character_subtype_key())
    end

    if type(image) == "string" and image ~= "" then
        portrait:SetImagePath(image, 0)
    end

    portrait:SetTooltipText(tooltip, "", true)
    portrait:SetVisible(true)

    -- small army/agent icon, same expressions as the native one
    local icon = find_uicomponent(portrait, "ad_holder_icon")

    if icon then
        local icon_path = trade_magic_items.get_context(
            "CcoCampaignCharacter",
            cqi,
            "GetIfElse(IsAgent, CharacterTypeIconPath, AddDefaultSkinPath(\"icon_army.png\"))"
        )
        local icon_tooltip = trade_magic_items.get_context("CcoCampaignCharacter", cqi, "Name + \"||\" + CharacterTypeName")

        if type(icon_path) == "string" and icon_path ~= "" then
            icon:SetImagePath(icon_path, 0)
        end

        if type(icon_tooltip) == "string" then
            icon:SetTooltipText(icon_tooltip, "", true)
        end
    end

    return true
end


-- what each row stands for, rebuilt on every open:
-- ad_row_info[column_id][item_id] = { key = <ancillary key>, holder_cqi = <cqi or nil if pooled>,
--     name = <localised>, rarity = <uniqueness group key>, tab = <tab of its list> }
local ad_row_info = { list_offers = {}, list_demands = {} }

-- false from opening until the rows are read: the tabs go by the counts
-- made on binding until then (see TABS)
local ad_rows_read = false


-- adds the item rows of one list to rows_by_key (item key -> rows of
-- that key, in list order); returns how many there were
local function ad_read_list_rows(list, tab, rows_by_key)
    local count = 0

    for i = 0, list:ChildCount() - 1 do
        local row = UIComponent(list:Find(i))

        -- the item object must come from the row itself:
        -- get_context_value("CcoCampaignAncillary", <id>, ...) returns nil
        if row:GetContextObjectId("CcoCampaignAncillary") then
            local item = row:GetContextObject("CcoCampaignAncillary")
            local ok, key = pcall(function()
                return item:Call("AncillaryRecordContext.Key")
            end)

            if ok and type(key) == "string" then
                -- exact holder of this copy, known only for the local player
                local exact_ok, exact_cqi = pcall(function()
                    return item:Call("CharacterEquippedToContext.CQI")
                end)

                -- localised, for the deal row
                local name_ok, name = pcall(function()
                    return item:Call("Name")
                end)

                local rarity_ok, rarity = pcall(function()
                    return item:Call("AncillaryRecordContext.UniquenessRecordContext.Key")
                end)

                rows_by_key[key] = rows_by_key[key] or {}
                table.insert(rows_by_key[key], {
                    row = row,
                    item_id = row:GetContextObjectId("CcoCampaignAncillary"),
                    exact_cqi = exact_ok and type(exact_cqi) == "number" and exact_cqi or nil,
                    name = name_ok and type(name) == "string" and name or nil,
                    rarity = rarity_ok and type(rarity) == "string" and rarity or nil,
                    tab = tab
                })
                count = count + 1
            end
        end
    end

    return count
end


local function ad_mark_item_holders(panel, column_id, faction)
    ad_row_info[column_id] = {}

    -- one item is in one tab only, so the holders of a key are handed
    -- out within one list
    local rows_by_key = {}
    local per_tab = {}

    for _, entry in ipairs(ad_get_item_lists(panel, column_id)) do
        per_tab[entry.tab] = ad_read_list_rows(entry.list, entry.tab, rows_by_key)
    end

    trade_magic_items.log(column_id .. ": rows magic=" .. tostring(per_tab.magic) .. ", banners=" .. tostring(per_tab.banners)
        .. ", followers=" .. tostring(per_tab.followers))

    local native, marked, pooled = 0, 0, 0

    for key, rows in pairs(rows_by_key) do
        local holders = trade_magic_items.find_holders(faction, key)

        -- rows with a known holder are shown natively; take those holders off
        for _, entry in ipairs(rows) do
            if entry.exact_cqi then
                for i, holder in ipairs(holders) do
                    if holder:command_queue_index() == entry.exact_cqi then
                        table.remove(holders, i)
                        break
                    end
                end
            end
        end

        -- hand out the remaining holders to the other copies
        for _, entry in ipairs(rows) do
            local holder_cqi = entry.exact_cqi

            if entry.exact_cqi then
                native = native + 1
            else
                local holder = table.remove(holders, 1)

                if ad_show_holder_portrait(entry.row, holder) then
                    holder_cqi = holder:command_queue_index()
                    marked = marked + 1
                else
                    pooled = pooled + 1
                end
            end

            ad_row_info[column_id][entry.item_id] = { key = key, holder_cqi = holder_cqi, name = entry.name, rarity = entry.rarity, tab = entry.tab }
        end
    end

    trade_magic_items.log(column_id .. ": holders native=" .. native .. ", own portrait=" .. marked .. ", in pool=" .. pooled)
    ad_rows_read = true
end


------------------------------------------------------------
-- ROW LOCK
-- The item entry inherits drag ("Movable XP") and a click sound from
-- the ancillary_entry template; the template callbacks can't be
-- removed in XML. Not moveable: no drag. Only the checkbox selects
-- an item.
------------------------------------------------------------

local function ad_lock_list_rows(list)
    local locked = 0

    for i = 0, list:ChildCount() - 1 do
        local row = UIComponent(list:Find(i))

        if row:GetContextObjectId("CcoCampaignAncillary") then
            local entry = find_uicomponent(row, "ancillary_entry")

            if entry then
                -- SetDisabled(true) also stopped the click sound, but made
                -- the hover sound unreliable; testing the drag lock alone
                entry:SetMoveable(false)
                locked = locked + 1
            end
        end
    end

    return locked
end


local function ad_lock_item_rows(panel, column_id)
    local locked = 0

    for _, entry in ipairs(ad_get_item_lists(panel, column_id)) do
        locked = locked + ad_lock_list_rows(entry.list)
    end

    trade_magic_items.log(column_id .. ": locked " .. locked .. " item entries")
end


-- the native list changed while our window is open: another player's
-- deal with this partner gives new rows (simultaneous turns, 0.12.3 log)
local function ad_refresh_row_info(panel, column_id)
    local faction = column_id == "list_offers" and cm:get_faction(cm:get_local_faction_name(true))
        or trade_magic_items.get_target_faction()

    trade_magic_items.log("Row info refreshed: " .. column_id)
    ad_mark_item_holders(panel, column_id, faction)
    ad_lock_item_rows(panel, column_id)
end


------------------------------------------------------------
-- SELECTION / PENDING TRADE
-- A selection = { target = <faction key>, list_offers = {}, list_demands = {} }
-- where each column maps item_id -> { key, holder_cqi, name }.
--   trade_magic_items.working: what is ticked while the panel is open
--   trade_magic_items.pending: the selection confirmed with OK (later: the deal terms)
-- Rules (user, 2026-10-25): Cancel throws away changes since opening;
-- OK keeps the selection; reopening restores the ticks; another
-- target faction or closing diplomacy clears it; no item limit.
-- Test mode (2026-10-29): OK executes the trade and clears everything.
------------------------------------------------------------

trade_magic_items.COLUMNS = { "list_offers", "list_demands" }

trade_magic_items.pending = nil
trade_magic_items.working = nil

-- the gold part of the deal: { direction = "give" / "demand", amount }
-- (see GOLD); here because OK depends on it
trade_magic_items.gold = nil

-- the last evaluated deal total (see DEAL CHANCE), nil before the first
local ad_deal_total = nil

-- the deal with a human partner, nil with an AI partner (see HUMAN
-- PARTNER): { state = "compose" / "waiting" / "review" / "counter", partner = <faction key> }
local ad_human_deal = nil

-- a proposal coming in from another player, until it is in the window:
-- { deal, from, from_key, payer, amount, count, items = {}, complete }
local ad_incoming = nil

-- this client's diplomacy was forced open for a proposal: our window is
-- the only reason it is open
local ad_forced_diplomacy = false

-- defined in HUMAN PARTNER: FLOW
local ad_fill_incoming

-- see TRADE WATCH below: the deal whose new item ids are still unknown,
-- and the function that looks for them
local ad_trade_watch = nil
local ad_resolve_trade_watch


local function ad_new_selection(target_key)
    return { target = target_key, list_offers = {}, list_demands = {} }
end


local function ad_copy_selection(selection)
    local copy = ad_new_selection(selection.target)

    for _, column_id in ipairs(trade_magic_items.COLUMNS) do
        for item_id, info in pairs(selection[column_id]) do
            copy[column_id][item_id] = { key = info.key, holder_cqi = info.holder_cqi, name = info.name, rarity = info.rarity, tab = info.tab }
        end
    end

    return copy
end


local function ad_selection_size(selection)
    local count = 0

    if selection then
        for _, column_id in ipairs(trade_magic_items.COLUMNS) do
            for _ in pairs(selection[column_id]) do
                count = count + 1
            end
        end
    end

    return count
end


local function ad_log_selection(tag, selection)
    if not selection then
        trade_magic_items.log(tag .. ": none")
        return
    end

    trade_magic_items.log(tag .. ": target=" .. tostring(selection.target) .. " items=" .. ad_selection_size(selection))

    for _, column_id in ipairs(trade_magic_items.COLUMNS) do
        for item_id, info in pairs(selection[column_id]) do
            trade_magic_items.log(
                "  " .. column_id .. " item=" .. item_id .. " " .. tostring(info.key)
                .. " holder=" .. (info.holder_cqi and tostring(info.holder_cqi) or "pool")
            )
        end
    end
end


function trade_magic_items.clear_selection(reason)
    if trade_magic_items.pending or trade_magic_items.working then
        trade_magic_items.log("Selection cleared: " .. reason)
    end

    trade_magic_items.pending = nil
    trade_magic_items.working = nil
    trade_magic_items.human_partner = nil
    ad_human_deal = nil
    ad_forced_diplomacy = false
end


-- a human partner's proposal or our own, waiting for the answer: the
-- deal can only be looked at
local function ad_items_locked()
    return ad_human_deal ~= nil and (ad_human_deal.state == "waiting" or ad_human_deal.state == "review")
end


-- a deal needs at least one item (gold alone is what the native
-- payment windows are for) and the partner's agreement; a human
-- partner answers for themselves
local function ad_deal_allowed()
    local has_items = ad_selection_size(trade_magic_items.working) > 0

    if ad_human_deal then
        return ad_human_deal.state == "review" or (ad_human_deal.state ~= "waiting" and has_items)
    end

    if trade_magic_items.IGNORE_DEAL_CHANCE then
        return has_items or (trade_magic_items.gold ~= nil and trade_magic_items.gold.amount > 0)
    end

    return has_items and ad_deal_total ~= nil and ad_deal_total >= trade_magic_items.DEAL_ACCEPT_SCORE
end


local function ad_update_ok_button(panel)
    local ok_button = find_uicomponent(panel, "ok_trade_magic_items")

    if not ok_button then
        return
    end

    if ad_deal_allowed() then
        ok_button:SetState("active")
    else
        ok_button:SetState("inactive")
    end
end


-- ticks the rows of the working selection; drops selected items
-- that are no longer listed (traded away, unequipped elsewhere...)
local function ad_restore_ticks(panel)
    if not trade_magic_items.working then
        return
    end

    for _, column_id in ipairs(trade_magic_items.COLUMNS) do
        local listed = {}

        for _, entry in ipairs(ad_get_item_lists(panel, column_id)) do
            local list = entry.list

            for i = 0, list:ChildCount() - 1 do
                local row = UIComponent(list:Find(i))
                local item_id = row:GetContextObjectId("CcoCampaignAncillary")

                if item_id then
                    listed[item_id] = true

                    local checkbox = find_uicomponent(row, "checkbox_toggle")

                    if checkbox then
                        local selected = trade_magic_items.working[column_id][item_id] ~= nil

                        -- grey while we wait; in colour on a proposal to answer, its
                        -- ticks must be easy to see (user, 0.11.1), not clickable either way
                        if ad_human_deal and ad_human_deal.state == "waiting" then
                            checkbox:SetState(selected and "selected_inactive" or "inactive")
                        else
                            checkbox:SetState(selected and "selected" or "active")
                        end

                        checkbox:SetInteractive(not ad_items_locked())
                    end
                end
            end
        end

        for item_id in pairs(trade_magic_items.working[column_id]) do
            if not listed[item_id] then
                trade_magic_items.working[column_id][item_id] = nil
                trade_magic_items.log("Selected item no longer listed, dropped: " .. column_id .. " " .. item_id)
            end
        end
    end

    -- the ticks changed (also a human partner's proposal shown, see HUMAN
    -- PARTNER): the counters on the tabs and column titles follow
    if trade_magic_items.update_tabs then
        local tabs_ok, tabs_err = pcall(trade_magic_items.update_tabs, panel)

        if not tabs_ok then
            trade_magic_items.log("ERROR: updating the tabs failed: " .. tostring(tabs_err))
        end
    end
end


------------------------------------------------------------
-- PANEL HEIGHT
-- The resize handle (button_enlarge_br, native ResizeDragHandle) only
-- resizes the panel itself; the item columns keep their size (test
-- 0.5.0). The watcher makes them follow the panel's height. The width
-- is locked in the layout. The height is remembered for the next open.
-- Default sizes come from the layout (760x425, 4 items per column, also
-- the smallest size; the handle allows up to 788 high), read from the
-- panel when it is created.
------------------------------------------------------------

-- the vertical slider is shorter than the visible list (vanilla: 181 / 121)
local AD_VSLIDER_SHORTER_BY = 60

-- default heights of this panel instance: { address, panel, column, clip }
local ad_panel_base = nil

local ad_panel_height = nil
trade_magic_items.laid_out_height = nil


-- children must keep their own size: Resize scales them by default,
-- which shifted the list up over the column title (0.5.1)
local function ad_set_height(uic, height)
    if not uic then
        return
    end

    uic:SetCanResizeHeight(true)
    uic:Resize(uic:Width(), height, false)
end


-- default heights, read once per panel instance before anything is resized
local function ad_read_panel_base(panel)
    if ad_panel_base and ad_panel_base.address == panel:Address() then
        return
    end

    local column = find_uicomponent(panel, "list_offers")
    local clip = column and find_uicomponent(column, "list_clip")

    -- background images (tile, border, top bar, parchment): their own
    -- sizes stay fixed when the panel is resized (0.5.2: the dark
    -- parchment slid behind the columns)
    local images = {}

    for i = 0, panel:NumCurrentStateImages() - 1 do
        images[i] = { width = panel:GetCurrentStateImageWidth(i), height = panel:GetCurrentStateImageHeight(i) }
    end

    ad_panel_base = {
        address = panel:Address(),
        panel = panel:Height(),
        column = column and column:Height() or 0,
        clip = clip and clip:Height() or 0,
        images = images
    }

    local image_sizes = {}

    for i, image in pairs(images) do
        table.insert(image_sizes, i .. "=" .. image.width .. "x" .. image.height)
    end

    trade_magic_items.log(
        "Panel defaults: panel " .. ad_panel_base.panel .. ", column " .. ad_panel_base.column
        .. ", list " .. ad_panel_base.clip .. ", images " .. table.concat(image_sizes, " ")
    )
end


-- images as tall as most of the panel follow its height; the top bar
-- (55 high) keeps its size
local AD_PANEL_IMAGE_FOLLOWS_FROM = 100

local function ad_layout_background(panel, extra)
    for i, image in pairs(ad_panel_base.images) do
        if image.height >= AD_PANEL_IMAGE_FOLLOWS_FROM then
            panel:SetCanResizeCurrentStateImageHeight(i, true)
            panel:ResizeCurrentStateImage(i, image.width, image.height + extra)
        end
    end
end


local function ad_layout_panel(panel)
    local base = ad_panel_base

    -- the default is also the smallest size (handle min_scale 1.0)
    local extra = math.max(0, panel:Height() - base.panel)

    ad_layout_background(panel, extra)

    ad_set_height(find_uicomponent(panel, "offer_demand_parent"), base.column + extra)

    for _, column_id in ipairs(trade_magic_items.COLUMNS) do
        local column = find_uicomponent(panel, column_id)

        if column then
            ad_set_height(column, base.column + extra)

            -- 1.1.0: one list view per tab, each as tall as the column
            for i = 0, column:ChildCount() - 1 do
                local view = UIComponent(column:Find(i))

                if string.sub(view:Id(), 1, 5) == "view_" then
                    ad_set_height(view, base.column + extra)
                    ad_set_height(find_uicomponent(view, "list_clip"), base.clip + extra)
                    ad_set_height(find_uicomponent(view, "vslider"), base.clip + extra - AD_VSLIDER_SHORTER_BY)
                end
            end
        end
    end

    trade_magic_items.laid_out_height = panel:Height()
end


-- watcher: columns follow the panel height
function trade_magic_items.follow_panel_height()
    local panel = trade_magic_items.panel_cache

    if not panel or not panel:Visible() or not ad_panel_base or panel:Height() == trade_magic_items.laid_out_height then
        return
    end

    ad_layout_panel(panel)
    ad_panel_height = panel:Height()
    trade_magic_items.log("Panel height " .. ad_panel_height)
end


-- on open: the height the player left it at last time
local function ad_restore_panel_height(panel)
    ad_read_panel_base(panel)

    if ad_panel_height and panel:Height() ~= ad_panel_height then
        panel:Resize(panel:Width(), ad_panel_height, false)
    end

    ad_layout_panel(panel)
end


------------------------------------------------------------
-- TABS (1.1.0)
-- Magic Items / Banners / Followers over the columns. One deal: a tab
-- only chooses which list of each column is visible, so it is UI only
-- (nothing for multiplayer). Rules (user, 2026-11-15):
--   every open starts on Magic Items, leaving the window drops the ticks
--   (as before: Cancel throws the working selection away);
--   ticks stay when switching tabs, a tab shows how many of its items
--   are ticked, on both sides together;
--   Banners / Followers are greyed when neither side has anything there
--   to trade, with a tooltip why. Magic Items is never greyed.
-- The buttons are in the layout (tools/build_tabs.js); the script sets
-- their states, a click toggles a button by itself first.
------------------------------------------------------------

local AD_TAB_BUTTON_IDS = {
    magic = "tab_magic_items",
    banners = "tab_banners",
    followers = "tab_followers"
}

local AD_TAB_BY_BUTTON = {
    tab_magic_items = "magic",
    tab_banners = "banners",
    tab_followers = "followers"
}

local AD_TAB_NAME_KEYS = {
    magic = "trade_magic_items_tab_magic_items",
    banners = "trade_magic_items_tab_banners",
    followers = "trade_magic_items_tab_followers"
}

local AD_TAB_TOOLTIP_KEYS = {
    magic = "trade_magic_items_tab_magic_items_tooltip",
    banners = "trade_magic_items_tab_banners_tooltip",
    followers = "trade_magic_items_tab_followers_tooltip"
}

-- greyed tab: the partner is of another race / nobody has anything there
local AD_TAB_OTHER_RACE_KEYS = {
    banners = "trade_magic_items_tab_banners_other_race",
    followers = "trade_magic_items_tab_followers_other_race"
}

local AD_TAB_EMPTY_KEYS = {
    banners = "trade_magic_items_tab_banners_empty",
    followers = "trade_magic_items_tab_followers_empty"
}

local AD_COLUMN_TITLE_KEYS = {
    magic = { list_offers = "trade_magic_items_your_items", list_demands = "trade_magic_items_their_items" },
    banners = { list_offers = "trade_magic_items_your_banners", list_demands = "trade_magic_items_their_banners" },
    followers = { list_offers = "trade_magic_items_your_followers", list_demands = "trade_magic_items_their_followers" }
}

trade_magic_items.current_tab = "magic"


-- rows of the tab in both columns (ad_row_info, as read on open)
local function ad_tab_rows(tab)
    local count = 0

    for _, column_id in ipairs(trade_magic_items.COLUMNS) do
        for _, info in pairs(ad_row_info[column_id]) do
            if info.tab == tab then
                count = count + 1
            end
        end
    end

    return count
end


-- ticked items of the tab in both columns
local function ad_tab_ticked(tab)
    local count = 0

    if trade_magic_items.working then
        for _, column_id in ipairs(trade_magic_items.COLUMNS) do
            for _, info in pairs(trade_magic_items.working[column_id]) do
                if info.tab == tab then
                    count = count + 1
                end
            end
        end
    end

    return count
end


-- by the rows once they are read, by the counts made on binding before
-- (the lists fill a few frames after the window opens)
local function ad_tab_available(tab)
    if tab == "magic" then
        return true
    end

    if ad_rows_read then
        return ad_tab_rows(tab) > 0
    end

    return (ad_tab_counts[tab] or 0) > 0
end


-- TEMP 1.1.0: the counts on binding must match the rows
local function ad_log_tab_counts_vs_rows()
    for tab in pairs(AD_TAB_FILTERS) do
        local rows = ad_tab_rows(tab)

        if rows ~= (ad_tab_counts[tab] or 0) then
            trade_magic_items.log("WARNING: tab " .. tab .. ": " .. tostring(ad_tab_counts[tab]) .. " counted on binding, " .. rows .. " rows")
        end
    end
end


local function ad_localised(key)
    local text = common.get_localised_string(key)

    if text == "" then
        trade_magic_items.log("WARNING: localisation lookup failed for " .. key)
        return key
    end

    return text
end


-- the tooltip of a greyed tab: another race, or simply nothing there
local function ad_greyed_tab_tooltip(tab)
    local player = cm:get_faction(cm:get_local_faction_name(true))
    local partner = trade_magic_items.get_target_faction()

    if player and partner and player:culture() ~= partner:culture() then
        return AD_TAB_OTHER_RACE_KEYS[tab]
    end

    return AD_TAB_EMPTY_KEYS[tab]
end


-- ticked items of the tab in one column
local function ad_column_ticked(column_id, tab)
    local count = 0

    if trade_magic_items.working then
        for _, info in pairs(trade_magic_items.working[column_id]) do
            if info.tab == tab then
                count = count + 1
            end
        end
    end

    return count
end


-- column titles of the current tab with the column's tick counter
-- (user, test 2), e.g. "Your Banners (2)"
local function ad_update_column_titles(panel)
    local tab = trade_magic_items.current_tab

    for _, column_id in ipairs(trade_magic_items.COLUMNS) do
        local title = find_uicomponent(panel, column_id, "offers_title")
        local key = AD_COLUMN_TITLE_KEYS[tab][column_id]

        if title then
            local text = ad_localised(key)
            local ticked = ad_column_ticked(column_id, tab)

            if ticked > 0 then
                text = text .. " (" .. ticked .. ")"
            end

            title:SetStateText(text, key)
        end
    end
end


-- states, texts with the tick counter and tooltips of the tab buttons,
-- and the column titles. Runs on every change of the deal (also a human
-- partner's proposal or counteroffer coming in), so the counters follow.
local function ad_update_tabs(panel)
    -- a tab left empty (its items traded away) can't stay open
    if not ad_tab_available(trade_magic_items.current_tab) then
        trade_magic_items.log("Tab " .. trade_magic_items.current_tab .. " has nothing left, back to magic")
        trade_magic_items.show_tab(panel, "magic")
        return
    end

    ad_update_column_titles(panel)

    for _, tab in ipairs(trade_magic_items.TABS) do
        local button = find_uicomponent(panel, AD_TAB_BUTTON_IDS[tab])

        if button then
            local available = ad_tab_available(tab)
            local ticked = ad_tab_ticked(tab)
            local text = ad_localised(AD_TAB_NAME_KEYS[tab])

            if ticked > 0 then
                text = text .. " (" .. ticked .. ")"
            end

            if not available then
                button:SetState("inactive")
            elseif tab == trade_magic_items.current_tab then
                button:SetState("selected")
            else
                button:SetState("active")
            end

            local label = find_uicomponent(button, "button_txt")

            if label then
                label:SetStateText(text, AD_TAB_NAME_KEYS[tab])
            end

            local tooltip = available and AD_TAB_TOOLTIP_KEYS[tab] or ad_greyed_tab_tooltip(tab)

            button:SetTooltipText(ad_localised(tooltip), tooltip, true)
        else
            trade_magic_items.log("ERROR: tab button not found: " .. AD_TAB_BUTTON_IDS[tab])
        end
    end
end

-- for code above this section (restoring the ticks)
trade_magic_items.update_tabs = ad_update_tabs


-- AD_VIEW_IDS: each tab has its own list view in a column (list_clip,
-- list_box, list, slider), so each scrolls on its own and keeps its place
-- while the window is open (user, test 2). Back to the top on every open
-- (the sliders react to this UiMsg in the layout).
local AD_VIEW_IDS = {
    magic = "view_magic",
    banners = "view_banners",
    followers = "view_followers"
}

local AD_SCROLL_RESET_MSG = "UiMsg(\"trade_magic_items_scroll_reset\")"


-- Esc while our window is open = Cancel (user, test 3), instead of
-- closing the whole diplomacy screen. CA's key steal: persistent, and
-- always released by name on leaving (a non-persistent steal leaves the
-- key stolen after the first press, see lib_campaign_manager)
local AD_ESC_KEY_NAME = "trade_magic_items_esc"
local ad_esc_stolen = false

local function ad_steal_esc_key()
    if ad_esc_stolen then
        return
    end

    local ok, err = pcall(function()
        cm:steal_escape_key_with_callback(AD_ESC_KEY_NAME, function()
            trade_magic_items.log("Esc pressed in our window")
            trade_magic_items.cancel_window("esc")
        end, true)
    end)

    if ok then
        ad_esc_stolen = true
    else
        trade_magic_items.log("ERROR: taking the Esc key failed: " .. tostring(err))
    end
end


local function ad_release_esc_key()
    if not ad_esc_stolen then
        return
    end

    ad_esc_stolen = false

    local ok, err = pcall(function()
        cm:release_escape_key_with_callback(AD_ESC_KEY_NAME)
    end)

    if not ok then
        trade_magic_items.log("ERROR: releasing the Esc key failed: " .. tostring(err))
    end
end


function trade_magic_items.reset_tab_scroll()
    local ok, err = pcall(common.call_context_command, "CcoCampaignRoot", "", AD_SCROLL_RESET_MSG)

    if not ok then
        trade_magic_items.log("ERROR: scroll reset failed: " .. tostring(err))
    end
end


-- shows the tab's list view in both columns
function trade_magic_items.show_tab(panel, tab)
    trade_magic_items.current_tab = tab

    for _, column_id in ipairs(trade_magic_items.COLUMNS) do
        for view_tab, view_id in pairs(AD_VIEW_IDS) do
            local view = find_uicomponent(panel, column_id, view_id)

            if view then
                view:SetVisible(view_tab == tab)
            else
                trade_magic_items.log("ERROR: list view not found: " .. column_id .. " " .. view_id)
            end
        end
    end

    ad_update_tabs(panel)

    -- TEMP 1.1.0: where the tabs ended up and how big the visible lists are
    local tab_button = find_uicomponent(panel, AD_TAB_BUTTON_IDS[tab])
    local list = ad_get_item_list(panel, "list_offers", tab)
    local panel_x, panel_y = panel:Position()

    if tab_button then
        local x, y = tab_button:Position()

        trade_magic_items.log("Tab " .. tab .. " shown: button at " .. (x - panel_x) .. "," .. (y - panel_y)
            .. " size " .. tab_button:Width() .. "x" .. tab_button:Height()
            .. ", panel " .. panel:Width() .. "x" .. panel:Height()
            .. (list and (", left list " .. list:Height() .. " high, " .. list:ChildCount() .. " children") or ", left list not found"))
    end
end

------------------------------------------------------------
-- DEAL CHANCE
-- label_deal_success_chance (copied from the native offers panel) in
-- the bottom bar: the target faction's opinion of our deal, green when
-- >= 0 (they agree), red otherwise. The tooltip follows the native
-- payments one: sentence, "Diplomatic treaty: total", breakdown groups
-- (positive green without a sign, negative red).
-- The total is the sum of the breakdown lines (numbers and sums: deal manager):
--   diplomatic prospects   their attitude towards us, by tier; only
--                          when the deal takes at least one of their items
--   economic value         gold in the deal
--   deals frequency        - for recent deals of theirs (deal manager)
--   items offered: rarity  + per item, recently traded - per item we
--     bought from them lately
--   items demanded: rarity - per item, belongs to their characters -
--     per item worn by one of their characters, recently traded - per
--     item we sold them lately
-- Refreshed on every selection and gold change; OK needs total >=
-- trade_magic_items.DEAL_ACCEPT_SCORE and at least one item (trade_magic_items.IGNORE_DEAL_CHANCE
-- turns this off for tests).
------------------------------------------------------------

local AD_DEAL_CHANCE_ID = "label_deal_success_chance"

-- breakdown in tooltip order; the first group follows the breakdown
-- title directly, the others get a blank line before them:
-- { title = loc key or nil, lines = { { loc key, value key, key of the
-- "turns ago" value shown when the value is not 0, key of the deal
-- number shown with it }, ... } }
local AD_DEAL_CHANCE_GROUPS = {
    {
        lines = {
            { "trade_magic_items_deal_chance_prospects", "diplomatic_prospects" },
            { "trade_magic_items_deal_chance_economic", "economic_value" },
            { "trade_magic_items_deal_chance_frequency", "deals_frequency", "deals_frequency_turns", "deals_frequency_number" }
        }
    },
    {
        title = "trade_magic_items_deal_chance_items_offered",
        lines = {
            { "trade_magic_items_deal_chance_rarity", "offered_rarity" },
            { "trade_magic_items_deal_chance_recent", "offered_recent", "offered_recent_turns" }
        }
    },
    {
        title = "trade_magic_items_deal_chance_items_demanded",
        lines = {
            { "trade_magic_items_deal_chance_rarity", "demanded_rarity" },
            { "trade_magic_items_deal_chance_equipped", "demanded_equipped" },
            { "trade_magic_items_deal_chance_recent", "demanded_recent", "demanded_recent_turns" }
        }
    }
}


-- one decimal, never "-0.0": no sign for what shows as nothing
local function ad_score_text(value)
    local text = string.format("%.1f", value)

    return text == "-0.0" and "0.0" or text
end


local function ad_format_score(value)
    local text = ad_score_text(value)

    if text == "0.0" then
        return text
    elseif value > 0 then
        return "[[col:green]]" .. text .. "[[/col]]"
    end

    return "[[col:red]]" .. text .. "[[/col]]"
end


local function ad_turns_ago_text(turns)
    if turns <= 0 then
        return common.get_localised_string("trade_magic_items_deal_chance_this_turn")
    elseif turns == 1 then
        return common.get_localised_string("trade_magic_items_deal_chance_turn_ago")
    end

    return string.format(common.get_localised_string("trade_magic_items_deal_chance_turns_ago"), turns)
end


-- "(this turn)" or, with the number of the deal, "(2 deal, 4 turns ago)"
local function ad_line_note(turns, deal_number)
    local note = ad_turns_ago_text(turns)

    if deal_number then
        note = string.format(common.get_localised_string("trade_magic_items_deal_chance_deal_number"), deal_number) .. ", " .. note
    end

    return "(" .. note .. ")"
end


-- evaluation = { total = number, offered_rarity = number, ... }; missing
-- values show as 0
local function ad_show_deal_chance(panel, evaluation)
    local label = find_uicomponent(panel, AD_DEAL_CHANCE_ID)

    if not label then
        trade_magic_items.log("ERROR: deal chance label not found")
        return
    end

    -- each state has its own text: switch state first
    label:SetState(evaluation.total >= 0 and "positive" or "negative")
    label:SetStateText(ad_score_text(evaluation.total), "trade_magic_items_deal_chance")

    local lines = {
        common.get_localised_string("trade_magic_items_deal_chance_tooltip"),
        "",
        common.get_localised_string("trade_magic_items_deal_chance_total") .. ": " .. ad_format_score(evaluation.total),
        "",
        common.get_localised_string("trade_magic_items_deal_chance_breakdown")
    }

    for i, group in ipairs(AD_DEAL_CHANCE_GROUPS) do
        if i > 1 then
            table.insert(lines, "")
        end

        if group.title then
            table.insert(lines, common.get_localised_string(group.title))
        end

        for _, line in ipairs(group.lines) do
            local value = evaluation[line[2]] or 0
            local turns = line[3] and evaluation[line[3]]
            local name = common.get_localised_string(line[1])

            if turns and value ~= 0 then
                name = name .. " " .. ad_line_note(turns, line[4] and evaluation[line[4]])
            end

            table.insert(lines, name .. ": " .. ad_format_score(value))
        end
    end

    label:SetTooltipText(table.concat(lines, "\n"), "trade_magic_items_deal_chance_tooltip", true)
end


-- set from here, not by a layout callback: the label's context value
-- showed 0 after switching partner (0.8.1)
local function ad_show_partner_treasury(panel)
    local label = find_uicomponent(panel, "dy_treasury_partner")
    local partner = trade_magic_items.get_target_faction()

    if label and partner then
        label:SetStateText(tostring(math.floor(partner:treasury())), "trade_magic_items_partner_treasury")
    end
end


-- defined in GOLD: it needs the payer's treasury
local ad_update_balance_button


local function ad_refresh_deal_chance(panel)
    -- the deal changed: the tick counters on the tabs too
    local tabs_ok, tabs_err = pcall(ad_update_tabs, panel)

    if not tabs_ok then
        trade_magic_items.log("ERROR: updating the tabs failed: " .. tostring(tabs_err))
    end

    if ad_human_deal then
        ad_show_partner_treasury(panel)
        ad_update_ok_button(panel)
        return
    end

    local evaluation = trade_magic_items.evaluate_deal()

    ad_deal_total = evaluation.total
    ad_show_partner_treasury(panel)
    ad_show_deal_chance(panel, evaluation)
    ad_update_ok_button(panel)
    ad_update_balance_button(panel, evaluation)

    trade_magic_items.log("Deal chance " .. evaluation.total .. ": attitude " .. tostring(evaluation.attitude)
        .. " -> " .. evaluation.diplomatic_prospects .. ", their gold x" .. evaluation.their_gold_multiplier
        .. ", gold " .. evaluation.economic_value
        .. ", frequency " .. evaluation.deals_frequency
        .. ", offered " .. evaluation.offered_rarity .. " recent " .. evaluation.offered_recent
        .. ", demanded " .. evaluation.demanded_rarity .. " recent " .. evaluation.demanded_recent
        .. ", belongs " .. evaluation.demanded_equipped)
end


------------------------------------------------------------
-- GOLD
-- Bottom left, copied from the native payments panel: a give / demand
-- switch (trade_magic_items_gold_direction: pay_offer / pay_demand radio buttons)
-- and an amount field (trade_magic_items_gold_amount, NumericalInput, steps of 500,
-- arrows). Gold moves one way only. Events (see GOLD EVENTS) refresh the
-- deal chance. The amount is capped by the payer's treasury, like
-- native payments: ours when we give, theirs when we demand (native
-- demand cap is lower - not known yet). The field's MaxValue has no
-- effect and text set from Lua is not its value (0.6.5 / 0.6.6 tests),
-- so after every gold event we send UiMsg "trade_magic_items_gold_clamp": the layout
-- reads the user property trade_magic_items_payer we keep in step, caps the value
-- and greys the arrows at the limits.
------------------------------------------------------------

-- display limit of the amount field (6 digits), same as MaxValue in the
-- layout; the real cap is the payer's treasury
local AD_GOLD_FIELD_MAX = 999999

-- radio_button template images are 26 px and ignore the instance size
local AD_RADIO_SIZE = 18
local AD_RADIO_STATES = {
    "active", "down", "down_off", "inactive", "roll",
    "selected", "selected_down", "selected_down_off", "selected_inactive", "selected_roll"
}


-- { direction = "give" / "demand", amount = number } or nil
local function ad_read_gold(panel)
    local demand = find_uicomponent(panel, "trade_magic_items_gold_direction", "pay_demand")
    local amount = find_uicomponent(panel, "trade_magic_items_gold_amount")

    if not demand or not amount then
        return nil
    end

    return {
        direction = string.find(demand:CurrentState(), "selected") and "demand" or "give",
        amount = tonumber(string.match(amount:GetStateText() or "", "%d+")) or 0
    }
end


-- the payer's treasury (0 .. AD_GOLD_FIELD_MAX), nil if the faction is
-- unknown
local function ad_gold_limit(direction)
    local payer = nil

    if direction == "give" then
        payer = cm:get_faction(cm:get_local_faction_name(true))
    else
        payer = trade_magic_items.get_target_faction()
    end

    if not payer then
        return nil
    end

    return math.min(math.max(payer:treasury(), 0), AD_GOLD_FIELD_MAX)
end


-- the payment that brings the deal to 0 or the closest the payer's
-- treasury allows: we pay when the deal is against us, they pay when
-- it is in our favour; rounded so the total stays >= 0 when it can
local function ad_balance_target(evaluation)
    local points = evaluation.points_without_gold
    local direction = points < 0 and "give" or "demand"
    local amount = math.abs(points) * trade_magic_items.GOLD_PER_POINT

    if direction == "give" then
        amount = math.ceil(amount)
    else
        amount = math.floor(amount / evaluation.their_gold_multiplier)
    end

    return direction, math.min(amount, ad_gold_limit(direction) or 0)
end


-- greyed out without items (nothing to balance) and when the gold
-- already is what the button would set. Assigns the local declared in
-- DEAL CHANCE.
function ad_update_balance_button(panel, evaluation)
    local button = find_uicomponent(panel, "trade_magic_items_balance_button")

    if not button then
        return
    end

    local direction, amount = ad_balance_target(evaluation)
    local current = trade_magic_items.gold and trade_magic_items.gold.amount or 0
    local balanced = amount == current and (amount == 0 or trade_magic_items.gold.direction == direction)

    if ad_selection_size(trade_magic_items.working) == 0 or balanced then
        button:SetState("inactive")
    elseif button:CurrentState() == "inactive" then
        button:SetState("active")
    end
end


-- every state has its own images: visit each one, then restore
local function ad_shrink_radio(radio)
    local current = radio:CurrentState()

    radio:SetCanResizeWidth(true)
    radio:SetCanResizeHeight(true)
    radio:Resize(AD_RADIO_SIZE, AD_RADIO_SIZE, false)

    for _, state in ipairs(AD_RADIO_STATES) do
        radio:SetState(state)

        for i = 0, radio:NumCurrentStateImages() - 1 do
            radio:SetCanResizeCurrentStateImageWidth(i, true)
            radio:SetCanResizeCurrentStateImageHeight(i, true)
            radio:ResizeCurrentStateImage(i, AD_RADIO_SIZE, AD_RADIO_SIZE)
        end
    end

    radio:SetState(current)
end


-- first open of a panel instance: tooltips the layout does not have
-- (ours, top left, keeps the native treasury tooltip)
local function ad_setup_tooltips(panel)
    local treasury = find_uicomponent(panel, "dy_treasury_partner")

    if treasury then
        treasury:SetTooltipText(common.get_localised_string("trade_magic_items_their_treasury"), "trade_magic_items_their_treasury", true)
    end

    local balance = find_uicomponent(panel, "trade_magic_items_balance_button")

    if balance then
        balance:SetTooltipText(common.get_localised_string("trade_magic_items_balance_tooltip"), "trade_magic_items_balance_tooltip", true)
    end
end


-- first open of a panel instance: our own texts. The layout keeps them in
-- English with textlocalised="false" (their vanilla labels would show the
-- settlement texts); texts copied from vanilla stay with the engine.
local function ad_setup_texts(panel)
    local texts = {
        { { "tx_trade_magic_items" }, "trade_magic_items_panel_title" },
        { { "label_trade_magic_items_rules" }, "trade_magic_items_rules_hint" },
        { { "list_offers", "offers_title" }, "trade_magic_items_your_items" },
        { { "list_demands", "offers_title" }, "trade_magic_items_their_items" }
    }

    for _, entry in ipairs(texts) do
        local uic = find_uicomponent_from_table(panel, entry[1])
        local text = common.get_localised_string(entry[2])

        if not uic then
            trade_magic_items.log("WARNING: text component not found for " .. entry[2])
        elseif text == "" then
            trade_magic_items.log("WARNING: text localisation lookup failed for " .. entry[2])
        else
            uic:SetStateText(text, entry[2])
        end
    end
end


-- first open of a panel instance: labels, radio size, default direction
local function ad_setup_gold(panel)
    local labels = {
        { "pay_offer", "once_tx", "trade_magic_items_offer_payment" },
        { "pay_demand", "repeatedly_tx", "trade_magic_items_demand_payment" }
    }

    for _, entry in ipairs(labels) do
        local label = find_uicomponent(panel, "trade_magic_items_gold_direction", entry[1], entry[2])

        if label then
            label:SetStateText(common.get_localised_string(entry[3]), entry[3])
        end
    end

    local give = find_uicomponent(panel, "trade_magic_items_gold_direction", "pay_offer")
    local demand = find_uicomponent(panel, "trade_magic_items_gold_direction", "pay_demand")

    if give and demand then
        local shrink_ok, shrink_err = pcall(function()
            ad_shrink_radio(give)
            ad_shrink_radio(demand)
        end)

        if not shrink_ok then
            trade_magic_items.log("ERROR shrinking gold radio buttons: " .. tostring(shrink_err))
        end

        if not string.find(give:CurrentState(), "selected") and not string.find(demand:CurrentState(), "selected") then
            give:SetState("selected")
        end
    end
end


-- the layout's cap reads the partner's treasury from here
local function ad_set_partner_treasury(amount)
    local partner = trade_magic_items.get_target_faction()

    if partner then
        amount:SetProperty("trade_magic_items_partner_treasury", tostring(math.max(math.floor(partner:treasury()), 0)))
    end
end


local function ad_send_gold_clamp()
    local clamp_ok, clamp_err = pcall(common.call_context_command, "CcoCampaignRoot", "", "UiMsg(\"trade_magic_items_gold_clamp\")")

    if not clamp_ok then
        trade_magic_items.log("ERROR: gold clamp failed: " .. tostring(clamp_err))
    end
end


-- gold changes refresh the deal chance; called on events only (panel
-- open, arrow / switch clicks, the field's value / text events).
-- direction: set when a switch click names it (the radio state may not
-- have changed yet). The layout caps the field and colours the arrows
-- on UiMsg "trade_magic_items_gold_clamp", after reading trade_magic_items_payer.
local function ad_on_gold_changed(source, direction)
    local panel = trade_magic_items.panel_cache

    if not panel or not panel:Visible() or ad_items_locked() then
        return
    end

    local gold = ad_read_gold(panel)
    local amount = find_uicomponent(panel, "trade_magic_items_gold_amount")

    if not gold or not amount then
        return
    end

    gold.direction = direction or gold.direction
    amount:SetProperty("trade_magic_items_payer", gold.direction == "give" and "us" or "them")
    ad_set_partner_treasury(amount)
    ad_send_gold_clamp()

    local limit = ad_gold_limit(gold.direction)

    if limit and gold.amount > limit then
        trade_magic_items.log("Gold over the payer's treasury (" .. gold.amount .. " > " .. limit .. "), field clamped")
        gold.amount = limit
    end

    if trade_magic_items.gold and gold.direction == trade_magic_items.gold.direction and gold.amount == trade_magic_items.gold.amount then
        return
    end

    trade_magic_items.gold = gold
    trade_magic_items.log("Gold (" .. source .. "): " .. gold.direction .. " " .. gold.amount)
    ad_refresh_deal_chance(panel)
end


-- balance button: switch and amount as if the player had set them. The
-- layout reads the value from a user property on UiMsg
-- "trade_magic_items_gold_balance"; its value event then refreshes the chance.
-- trade_magic_items_payer goes first: the layout caps the value by that treasury.
local function ad_balance_deal()
    local panel = trade_magic_items.panel_cache
    local give = find_uicomponent(panel, "trade_magic_items_gold_direction", "pay_offer")
    local demand = find_uicomponent(panel, "trade_magic_items_gold_direction", "pay_demand")
    local field = find_uicomponent(panel, "trade_magic_items_gold_amount")

    if not give or not demand or not field then
        trade_magic_items.log("ERROR: balance: gold controls not found")
        return
    end

    local direction, amount = ad_balance_target(trade_magic_items.evaluate_deal())

    give:SetState(direction == "give" and "selected" or "active")
    demand:SetState(direction == "demand" and "selected" or "active")
    field:SetProperty("trade_magic_items_payer", direction == "give" and "us" or "them")
    ad_set_partner_treasury(field)
    field:SetProperty("trade_magic_items_balance_value", tostring(amount))
    common.call_context_command("CcoCampaignRoot", "", "UiMsg(\"trade_magic_items_gold_balance\")")

    trade_magic_items.log("Balance: " .. direction .. " " .. amount)
    ad_on_gold_changed("balance", direction)
end


------------------------------------------------------------
-- HUMAN PARTNER: VIEW
-- With a human partner there is no chance and no balance button: the
-- other player decides. New in the window: Counteroffer between Propose
-- and Cancel, the button plaque grows to the right (the gold arrows on
-- its left stay free) and "Waiting on player..." in the bottom bar.
--   compose  we build the deal
--   waiting  proposed, nothing can be changed, Cancel blocked
--   review   they proposed: OK = Accept, Counteroffer, Cancel = Decline;
--            items and gold locked, the lists still scroll
--   counter  we change their deal: Propose, Cancel = Decline
-- With an AI partner nothing here changes the window.
------------------------------------------------------------

-- x of the plaque in the bottom bar, x of the buttons on the plaque
local AD_PLATE_NARROW = { width = 130, image_width = 152, x = 0, ok_x = -30, counter_x = 0, cancel_x = 30 }
local AD_PLATE_WIDE = { width = 190, image_width = 212, x = 30, ok_x = -60, counter_x = 0, cancel_x = 60 }

-- addresses of the panel instance that is wide / locked now: a panel is
-- created new in every diplomacy session
local ad_wide_plate_address = nil
local ad_gold_locked_address = nil

-- the layout's tooltips of this panel instance, while ours replace them:
-- { address, ok, cancel }
local ad_button_tooltips = nil


local function ad_set_visible(panel, id, visible)
    local uic = find_uicomponent(panel, id)

    if uic then
        uic:SetVisible(visible)
    else
        trade_magic_items.log("ERROR: component not found: " .. id)
    end
end


local function ad_set_dock_x(panel, id, x)
    local uic = find_uicomponent(panel, id)

    if not uic then
        trade_magic_items.log("ERROR: component not found: " .. id)
        return
    end

    local _, y = uic:GetDockOffset()

    uic:SetDockOffset(x, y)
end


local function ad_set_wide_plate(panel, wide)
    if (ad_wide_plate_address == panel:Address()) == wide then
        return
    end

    local plate = find_uicomponent(panel, "both_buttongroup")

    if not plate then
        trade_magic_items.log("ERROR: button plaque not found")
        return
    end

    local layout = wide and AD_PLATE_WIDE or AD_PLATE_NARROW

    plate:SetCanResizeWidth(true)
    plate:Resize(layout.width, plate:Height(), false)
    plate:SetCanResizeWidth(false)
    plate:SetCanResizeCurrentStateImageWidth(0, true)
    plate:ResizeCurrentStateImage(0, layout.image_width, plate:GetCurrentStateImageHeight(0))

    ad_set_dock_x(panel, "both_buttongroup", layout.x)
    ad_set_dock_x(panel, "ok_trade_magic_items", layout.ok_x)
    ad_set_dock_x(panel, "counter_trade_magic_items", layout.counter_x)
    ad_set_dock_x(panel, "cancel_trade_magic_items", layout.cancel_x)

    ad_wide_plate_address = wide and panel:Address() or nil
end


-- radio state <-> its inactive twin
local function ad_set_radio_locked(radio, locked)
    local state = radio:CurrentState()
    local selected = string.find(state, "selected") ~= nil

    if locked then
        radio:SetState(selected and "selected_inactive" or "inactive")
    else
        radio:SetState(selected and "selected" or "active")
    end
end


local function ad_lock_gold(panel, locked)
    if (ad_gold_locked_address == panel:Address()) == locked then
        return
    end

    local field = find_uicomponent(panel, "trade_magic_items_gold_amount")
    local give = find_uicomponent(panel, "trade_magic_items_gold_direction", "pay_offer")
    local demand = find_uicomponent(panel, "trade_magic_items_gold_direction", "pay_demand")

    if not field or not give or not demand then
        trade_magic_items.log("ERROR: gold controls not found")
        return
    end

    field:SetInteractive(not locked)
    field:SetProperty("trade_magic_items_locked", locked and "true" or "false")
    ad_set_radio_locked(give, locked)
    ad_set_radio_locked(demand, locked)
    ad_gold_locked_address = locked and panel:Address() or nil

    -- the layout colours the arrows on a clamp, grey while locked
    if locked then
        ad_send_gold_clamp()
    else
        ad_on_gold_changed("gold unlocked")
    end
end


local function ad_set_tooltip(uic, key)
    local text = common.get_localised_string(key)

    if text == "" then
        trade_magic_items.log("WARNING: tooltip localisation lookup failed for " .. key)
        return
    end

    uic:SetTooltipText(text, key, true)
end


local function ad_apply_button_tooltips(panel, state)
    local ok_button = find_uicomponent(panel, "ok_trade_magic_items")
    local cancel = find_uicomponent(panel, "cancel_trade_magic_items")

    if not ok_button or not cancel then
        return
    end

    local same_panel = ad_button_tooltips ~= nil and ad_button_tooltips.address == panel:Address()

    if not state then
        if same_panel then
            ok_button:SetTooltipText(ad_button_tooltips.ok, "", true)
            cancel:SetTooltipText(ad_button_tooltips.cancel, "", true)
            ad_button_tooltips = nil
        end

        return
    end

    if not same_panel then
        ad_button_tooltips = {
            address = panel:Address(),
            ok = ok_button:GetTooltipText() or "",
            cancel = cancel:GetTooltipText() or ""
        }
    end

    ad_set_tooltip(ok_button, state == "review" and "trade_magic_items_accept_tooltip" or "trade_magic_items_propose_player_tooltip")

    if state == "review" or state == "counter" then
        ad_set_tooltip(cancel, "trade_magic_items_decline_tooltip")
    else
        cancel:SetTooltipText(ad_button_tooltips.cancel, "", true)
    end
end


-- the window as ad_human_deal says; with an AI partner only takes back
-- what a human deal changed on this panel
local function ad_apply_human_view(panel)
    local state = ad_human_deal and ad_human_deal.state

    ad_set_wide_plate(panel, state ~= nil)
    ad_set_visible(panel, "counter_trade_magic_items", state ~= nil)
    ad_set_visible(panel, "trade_magic_items_waiting", state == "waiting")
    ad_apply_button_tooltips(panel, state)
    ad_lock_gold(panel, ad_items_locked())

    if state then
        ad_set_visible(panel, "label_deal_success_chance", false)
        ad_set_visible(panel, "trade_magic_items_balance_button", false)

        local counter = find_uicomponent(panel, "counter_trade_magic_items")
        local cancel = find_uicomponent(panel, "cancel_trade_magic_items")

        if counter then
            counter:SetState(state == "review" and "active" or "inactive")
        end

        if cancel then
            cancel:SetState(state == "waiting" and "inactive" or "active")
        end

        ad_restore_ticks(panel)
        ad_update_ok_button(panel)
    end
end


-- the player list keeps a player who dropped out, the deal is still theirs
local function ad_partner_is_human(partner)
    for _, key in ipairs(cm:get_human_factions()) do
        if key == partner:name() then
            return true
        end
    end

    return false
end


------------------------------------------------------------
-- OPEN / CLOSE
-- Plan B: our panel is a standalone window with its own background
-- (850x475, like the faction panel), created directly in
-- diplomacy_dropdown. It used to sit on the native subpanel_group
-- (760x365 background), like vanilla Trade Settlement.
--   open:  offers_panel hidden, our panel visible
--   close: the reverse
------------------------------------------------------------

-- the "they accepted" view: the native answer (frame + text) in place
-- of the deal; the confirm button closes it
local AD_DEAL_VIEW_IDS = {
    "offer_demand_parent",
    "tab_magic_items",
    "tab_banners",
    "tab_followers",
    "label_trade_magic_items_rules",
    "ok_trade_magic_items",
    "cancel_trade_magic_items",
    "trade_magic_items_balance_button",
    "trade_magic_items_gold_direction",
    "trade_magic_items_gold_amount",
    "label_deal_success_chance"
}

local AD_RESULT_VIEW_IDS = {
    "trade_magic_items_deal_result_frame",
    "confirm_trade_magic_items"
}

-- the native answers
local AD_DEAL_ACCEPTED_SOUND = "UI_CAM_HUD_Diplomacy_Response_Deal_Accepted"
local AD_DEAL_DECLINED_SOUND = "UI_CAM_HUD_Diplomacy_Response_Deal_Declined"


-- result_state: a state of trade_magic_items_deal_result (they_accepted,
-- they_declined, you_accepted), when show is true
local function ad_show_result_view(panel, show, result_state)
    if show then
        local result = find_uicomponent(panel, "trade_magic_items_deal_result")

        if result then
            result:SetState(result_state or "they_accepted")
        else
            trade_magic_items.log("ERROR: result text not found")
        end
    end

    for _, id in ipairs(AD_DEAL_VIEW_IDS) do
        local uic = find_uicomponent(panel, id)

        if uic then
            uic:SetVisible(not show)
        else
            trade_magic_items.log("ERROR: deal view component not found: " .. id)
        end
    end

    for _, id in ipairs(AD_RESULT_VIEW_IDS) do
        local uic = find_uicomponent(panel, id)

        if uic then
            uic:SetVisible(show)
        else
            trade_magic_items.log("ERROR: result view component not found: " .. id)
        end
    end

    local view_ok, view_err = pcall(ad_apply_human_view, panel)

    if not view_ok then
        trade_magic_items.log("ERROR: human partner view failed: " .. tostring(view_err))
    end
end


function trade_magic_items.open_trade_magic_items_panel()
    local diplomacy = trade_magic_items.get_diplomacy()

    if not diplomacy then
        trade_magic_items.log("ERROR: diplomacy_dropdown not found")
        return
    end


    -- may be missing on the second player's client: no negotiation there yet
    local offers_panel = trade_magic_items.get_offers_panel()

    if not offers_panel then
        trade_magic_items.log("WARNING: offers_panel not found")
    end


    local panel = find_uicomponent(
        diplomacy,
        AD_PANEL_ID
    )

    if not panel then
        trade_magic_items.log("Creating trade magic items panel")

        local panel_address = diplomacy:CreateComponent(
            AD_PANEL_ID,
            AD_PANEL_XML
        )

        if not panel_address then
            trade_magic_items.log("ERROR: trade magic items panel CreateComponent failed")
            return
        end

        panel = UIComponent(panel_address)

        -- one-time setup: duplicating list_offers must not run twice
        ad_setup_magic_items_panel(panel)

        local gold_ok, gold_err = pcall(ad_setup_gold, panel)

        if not gold_ok then
            trade_magic_items.log("ERROR: gold setup failed: " .. tostring(gold_err))
        end

        local tooltips_ok, tooltips_err = pcall(ad_setup_tooltips, panel)

        if not tooltips_ok then
            trade_magic_items.log("ERROR: tooltip setup failed: " .. tostring(tooltips_err))
        end

        local texts_ok, texts_err = pcall(ad_setup_texts, panel)

        if not texts_ok then
            trade_magic_items.log("ERROR: text setup failed: " .. tostring(texts_err))
        end

        trade_magic_items.log("Trade magic items panel created successfully")
    end


    trade_magic_items.panel_cache = panel

    local incoming = ad_incoming ~= nil and ad_incoming.complete

    if incoming then
        trade_magic_items.human_partner = ad_incoming.from_key
    end

    local partner = trade_magic_items.get_target_faction()

    ad_human_deal = nil

    if partner and ad_partner_is_human(partner) then
        ad_human_deal = { state = incoming and "review" or "compose", partner = partner:name() }
    end

    trade_magic_items.log("Partner " .. tostring(partner and partner:name()) .. ": " .. (ad_human_deal and "human" or "AI")
        .. (incoming and ", proposal " .. ad_incoming.deal or ""))

    if offers_panel then
        offers_panel:SetVisible(false)
    end
    -- a panel left on the result view (diplomacy target changed) or a new
    -- one, whose result view the layout shows
    ad_show_result_view(panel, false)
    panel:SetVisible(true)
    ad_steal_esc_key()

    local height_ok, height_err = pcall(ad_restore_panel_height, panel)

    if not height_ok then
        trade_magic_items.log("ERROR: restoring panel height failed: " .. tostring(height_err))
    end

    -- the deal is evaluated once the selection is known (below)
    trade_magic_items.gold = nil
    ad_deal_total = nil

    local gold_field = find_uicomponent(panel, "trade_magic_items_gold_amount")

    if gold_field then
        ad_set_partner_treasury(gold_field)
    end

    local gold_ok, gold_err = pcall(ad_on_gold_changed, "panel opened")

    if not gold_ok then
        trade_magic_items.log("ERROR: reading the gold failed: " .. tostring(gold_err))
    end

    -- rows of the last open belong to the last partner: the tabs must not
    -- count them until the new rows are read (below)
    ad_row_info = { list_offers = {}, list_demands = {} }
    ad_rows_read = false

    -- the target can change between negotiations, so bind on every open.
    -- pcall: the item lists are new; a failure must not break opening
    local ok, err = pcall(ad_bind_item_lists, panel)

    if not ok then
        trade_magic_items.log("ERROR: binding item lists failed: " .. tostring(err))
    end

    -- every open starts on Magic Items (user, 1.1.0). The lists were put
    -- back to the top when the window was left (ad_reset_window_on_close);
    -- this only makes sure of the tab, which is already the shown one
    trade_magic_items.current_tab = "magic"

    local tab_ok, tab_err = pcall(trade_magic_items.show_tab, panel, "magic")

    if not tab_ok then
        trade_magic_items.log("ERROR: showing the magic items tab failed: " .. tostring(tab_err))
    end

    -- working copy of the pending selection; a pending selection for
    -- another target faction is stale
    local target = trade_magic_items.get_target_faction()
    local target_key = target and target:name()

    if trade_magic_items.pending and trade_magic_items.pending.target ~= target_key then
        trade_magic_items.clear_selection("target faction changed")
    end

    trade_magic_items.working = trade_magic_items.pending and ad_copy_selection(trade_magic_items.pending) or ad_new_selection(target_key)

    local chance_ok, chance_err = pcall(ad_refresh_deal_chance, panel)

    if not chance_ok then
        trade_magic_items.log("ERROR: evaluating the deal failed: " .. tostring(chance_err))
    end

    trade_magic_items.log("Trade magic items panel opened")

    -- rows are created by the native list a few frames after binding
    cm:real_callback(
        function()
            local columns = {
                list_offers = cm:get_faction(cm:get_local_faction_name(true)),
                list_demands = trade_magic_items.get_target_faction()
            }

            for column_id, faction in pairs(columns) do
                local mark_ok, mark_err = pcall(ad_mark_item_holders, panel, column_id, faction)

                if not mark_ok then
                    trade_magic_items.log("ERROR: marking item holders in " .. column_id .. " failed: " .. tostring(mark_err))
                end

                local lock_ok, lock_err = pcall(ad_lock_item_rows, panel, column_id)

                if not lock_ok then
                    trade_magic_items.log("ERROR: locking item rows in " .. column_id .. " failed: " .. tostring(lock_err))
                end
            end

            pcall(ad_log_tab_counts_vs_rows)

            local tick_ok, tick_err = pcall(ad_restore_ticks, panel)

            if not tick_ok then
                trade_magic_items.log("ERROR: restoring ticks failed: " .. tostring(tick_err))
            end

            if ad_human_deal and ad_incoming and ad_incoming.complete then
                local fill_ok, fill_err = pcall(ad_fill_incoming, panel)

                if not fill_ok then
                    trade_magic_items.log("ERROR: showing the proposal failed: " .. tostring(fill_err))
                end
            end

            local watch_ok, watch_err = pcall(ad_resolve_trade_watch)

            if not watch_ok then
                trade_magic_items.log("ERROR: trade watch failed: " .. tostring(watch_err))
            end

            -- ticks of items no longer listed were just dropped
            local chance_ok, chance_err = pcall(ad_refresh_deal_chance, panel)

            if not chance_ok then
                trade_magic_items.log("ERROR: evaluating the deal failed: " .. tostring(chance_err))
            end

            ad_log_selection("Selection on open", trade_magic_items.working)
        end,
        200
    )
end


-- whatever way the window is left (our closes and diplomacy closing):
-- no gold, no working selection (the pending one stays: a human deal),
-- Magic Items tab, all lists at the top. Done on leaving, not on opening,
-- so the next open shows nothing moving (user, test 3). Called while the
-- panel is still visible, like the gold reset always was.
local function ad_reset_window_on_close(panel)
    ad_release_esc_key()
    trade_magic_items.gold = nil
    trade_magic_items.working = nil

    local reset_ok, reset_err = pcall(common.call_context_command, "CcoCampaignRoot", "", "UiMsg(\"trade_magic_items_gold_reset\")")

    if not reset_ok then
        trade_magic_items.log("ERROR: gold reset failed: " .. tostring(reset_err))
    end

    trade_magic_items.reset_tab_scroll()

    if panel then
        local tab_ok, tab_err = pcall(trade_magic_items.show_tab, panel, "magic")

        if not tab_ok then
            trade_magic_items.log("ERROR: showing the magic items tab failed: " .. tostring(tab_err))
        end
    end
end


local function ad_close_trade_magic_items_panel()
    local diplomacy = trade_magic_items.get_diplomacy()

    if not diplomacy then
        trade_magic_items.log("ERROR: diplomacy_dropdown not found")
        return
    end

    local panel = find_uicomponent(
        diplomacy,
        AD_PANEL_ID
    )

    ad_reset_window_on_close(panel)

    if panel then
        panel:SetVisible(false)
    end

    -- back to the native deal, like vanilla Trade Settlement; forced
    -- diplomacy closes right after, there the offers panel would only flash
    local offers_panel = trade_magic_items.get_offers_panel()

    if not offers_panel then
        trade_magic_items.log("ERROR: offers_panel not found")
    elseif not ad_forced_diplomacy then
        offers_panel:SetVisible(true)
    end

    trade_magic_items.log("Trade magic items panel closed")
end


-- Diplomacy closed while our window was open (Esc, the turn...): the
-- panel is not destroyed with diplomacy and came back with the old
-- result view on the next open (0.13.1 log). Called by the
-- diplomacy-closed listener.
function trade_magic_items.hide_window_after_diplomacy()
    local panel = find_uicomponent(core:get_ui_root(), "diplomacy_dropdown", AD_PANEL_ID)

    if panel and panel:Visible() then
        ad_reset_window_on_close(panel)
        panel:SetVisible(false)
        trade_magic_items.log("Diplomacy closed with our window open: window hidden")

        local offers_panel = find_uicomponent(core:get_ui_root(), "diplomacy_dropdown", "offers_panel")

        if offers_panel then
            offers_panel:SetVisible(true)
        end
    end
end


------------------------------------------------------------
-- HUMAN PARTNER: FLOW
-- Propose -> the other player answers -> Accept, Decline or Counteroffer,
-- until they agree (design: findings 7.1a). Everything here is one
-- client's window; the events are in the deal manager, HUMAN DEAL EVENTS.
-- The accepting client builds the trade from what its window shows, the
-- ops run on every client like any trade.
------------------------------------------------------------

-- the proposal both clients count as current: { id, from = <cqi> }. Set
-- and cleared only by events, which arrive in the same order everywhere,
-- so two proposals crossing each other end the same on both clients:
-- the first one stands.
local ad_live_deal = nil

local ad_deal_counter = 0

local AD_BRING_IN_LISTENER = "AD_HumanBringIn"


local function ad_local_cqi()
    return cm:get_faction(cm:get_local_faction_name(true)):command_queue_index()
end


local function ad_set_human_state(panel, state, reason)
    ad_human_deal.state = state
    trade_magic_items.log("Human deal: " .. state .. " (" .. reason .. ")")
    ad_apply_human_view(panel)
end


-- The forced diplomacy closes with our window (user, simultaneous turns),
-- by the game's own command: CampaignUI.ClosePanel left the campaign HUD
-- hidden until a restart (0.12.3). A moment later: this runs inside the
-- click of a button of that panel.
local AD_FORCED_CLOSE_DELAY_MS = 100


-- With forced diplomacy the native offers panel loads seconds after our
-- window opened and comes up behind it (log 0.12.2: 5 and 10 s later).
-- The button watcher calls this; the game shows the panel again with the
-- next negotiation (0.12.8 log), nothing has to be restored.
function trade_magic_items.keep_offers_hidden()
    if not ad_forced_diplomacy then
        return
    end

    local offers_panel = trade_magic_items.get_offers_panel()

    if offers_panel and offers_panel:Visible() then
        offers_panel:SetVisible(false)
        trade_magic_items.log("Forced diplomacy: offers panel hidden")
    end
end


local function ad_close_forced_diplomacy()
    if not ad_forced_diplomacy then
        return
    end

    trade_magic_items.log("Forced diplomacy closes with the deal")

    cm:real_callback(
        function()
            local ok, err = pcall(common.call_context_command, "CcoCampaignRoot", "", "CloseDiplomacyPanel")

            if not ok then
                trade_magic_items.log("ERROR: closing the forced diplomacy failed: " .. tostring(err))
            end
        end,
        AD_FORCED_CLOSE_DELAY_MS
    )
end


-- the deal is over for this window: the result view, its confirm button
-- closes the window. The two players are no longer tied to each other
-- here, each one leaves on their own.
local function ad_finish_human_deal(panel, result_state)
    trade_magic_items.log("Human deal finished: " .. result_state)

    ad_human_deal = nil
    trade_magic_items.pending = nil
    trade_magic_items.working = nil

    ad_show_result_view(panel, true, result_state)
    cm:trigger_2d_ui_sound(result_state == "they_declined" and AD_DEAL_DECLINED_SOUND or AD_DEAL_ACCEPTED_SOUND, 0)
    trade_magic_items.human_partner = nil
end


-- "A" or "D" to the partner of this window
local function ad_send_answer(kind)
    local partner = cm:get_faction(ad_human_deal.partner)

    trade_magic_items.send_human_event({
        kind, ad_live_deal and ad_live_deal.id or "0", ad_local_cqi(), partner:command_queue_index()
    })
end


-- the working selection and the gold as a proposal; false when it can't be sent
local function ad_send_proposal()
    local partner = cm:get_faction(ad_human_deal.partner)
    local from = ad_local_cqi()
    local to = partner:command_queue_index()
    local gold = trade_magic_items.gold
    local payer, amount = 0, 0

    if gold and gold.amount > 0 then
        amount = gold.amount
        payer = gold.direction == "give" and from or to
    end

    ad_deal_counter = ad_deal_counter + 1

    local deal = from .. "x" .. ad_deal_counter
    local owners = { list_offers = from, list_demands = to }
    local items = {}

    for _, column_id in ipairs(trade_magic_items.COLUMNS) do
        for _, info in pairs(trade_magic_items.working[column_id]) do
            if info.key then
                table.insert(items, { "I", deal, from, to, owners[column_id], info.key, info.holder_cqi or "" })
            end
        end
    end

    local sent = trade_magic_items.send_human_event({
        "B", deal, from, to, ad_live_deal and ad_live_deal.id or 0, payer, amount, #items
    })

    for _, item in ipairs(items) do
        sent = sent and trade_magic_items.send_human_event(item)
    end

    return sent and trade_magic_items.send_human_event({ "E", deal, from, to })
end


-- OK in the human modes
local function ad_human_ok(panel)
    if ad_human_deal.state == "review" then
        local events = trade_magic_items.build_trade(trade_magic_items.working, trade_magic_items.gold, true)

        if not events then
            trade_magic_items.log("ERROR: the proposal can't be traded, declined")
            ad_send_answer("D")
            ad_finish_human_deal(panel, "they_declined")
            return
        end

        ad_log_selection("Trading with a player", trade_magic_items.working)

        for _, event in ipairs(events) do
            CampaignUI.TriggerCampaignScriptEvent(ad_local_cqi(), event)
        end

        ad_send_answer("A")
        ad_finish_human_deal(panel, "you_accepted")
        return
    end

    local gold_ok, gold_err = pcall(ad_on_gold_changed, "OK")

    if not gold_ok then
        trade_magic_items.log("ERROR: reading the gold failed: " .. tostring(gold_err))
    end

    if not ad_deal_allowed() then
        trade_magic_items.log("Propose ignored: state=" .. ad_human_deal.state .. " items=" .. ad_selection_size(trade_magic_items.working))
        return
    end

    ad_log_selection("Proposing", trade_magic_items.working)

    if not ad_send_proposal() then
        trade_magic_items.log("ERROR: the proposal could not be sent")
        return
    end

    ad_set_human_state(panel, "waiting", "proposed")
end


-- their accept / decline of our proposal
local function ad_on_human_answer(result_state)
    local panel = trade_magic_items.panel_cache

    if not panel or not ad_human_deal or ad_human_deal.state ~= "waiting" then
        trade_magic_items.log("Human answer ignored: " .. result_state .. ", state=" .. tostring(ad_human_deal and ad_human_deal.state))
        return
    end

    ad_finish_human_deal(panel, result_state)
end


-- the row of a column for an item of the proposal, not taken yet: the
-- same copy (key + holder), or another of that key. Rows are looked up
-- this way so a proposal never depends on item ids (the MP runs showed
-- them equal on both clients).
local function ad_find_proposal_row(selection, column_id, item)
    local same_key = nil

    for item_id, info in pairs(ad_row_info[column_id]) do
        if info.key == item.key and not selection[column_id][item_id] then
            if info.holder_cqi == item.holder then
                return item_id
            end

            same_key = same_key or item_id
        end
    end

    if same_key then
        trade_magic_items.log("WARNING: proposal item " .. item.key .. " holder " .. tostring(item.holder) .. " matched another copy")
    end

    return same_key
end


-- the gold of a proposal in the locked controls
local function ad_show_proposal_gold(panel, gold)
    local give = find_uicomponent(panel, "trade_magic_items_gold_direction", "pay_offer")
    local demand = find_uicomponent(panel, "trade_magic_items_gold_direction", "pay_demand")
    local field = find_uicomponent(panel, "trade_magic_items_gold_amount")

    if not give or not demand or not field then
        trade_magic_items.log("ERROR: gold controls not found")
        return
    end

    local direction = gold and gold.direction or "give"

    give:SetState(direction == "give" and "selected_inactive" or "inactive")
    demand:SetState(direction == "demand" and "selected_inactive" or "inactive")
    field:SetProperty("trade_magic_items_payer", direction == "give" and "us" or "them")
    ad_set_partner_treasury(field)
    field:SetProperty("trade_magic_items_balance_value", tostring(gold and gold.amount or 0))
    common.call_context_command("CcoCampaignRoot", "", "UiMsg(\"trade_magic_items_gold_balance\")")
end


-- the whole proposal in the window, seen from this side. Assigns the
-- local declared in SELECTION.
function ad_fill_incoming(panel)
    local incoming = ad_incoming
    local player_cqi = ad_local_cqi()
    local selection = ad_new_selection(incoming.from_key)

    ad_incoming = nil

    for _, item in ipairs(incoming.items) do
        local column_id = item.owner == player_cqi and "list_offers" or "list_demands"
        local item_id = ad_find_proposal_row(selection, column_id, item)

        if item_id then
            local info = ad_row_info[column_id][item_id]

            selection[column_id][item_id] = { key = info.key, holder_cqi = info.holder_cqi, name = info.name, rarity = info.rarity, tab = info.tab }
        else
            trade_magic_items.log("WARNING: proposal item not found in " .. column_id .. ": " .. item.key .. " holder " .. tostring(item.holder))
        end
    end

    trade_magic_items.working = selection
    trade_magic_items.gold = nil

    if incoming.amount > 0 then
        trade_magic_items.gold = { direction = incoming.payer == player_cqi and "give" or "demand", amount = incoming.amount }
    end

    ad_set_human_state(panel, "review", "proposal " .. incoming.deal)
    ad_show_proposal_gold(panel, trade_magic_items.gold)
    ad_log_selection("Proposal shown", selection)
    trade_magic_items.log("Proposal gold: " .. tostring(trade_magic_items.gold and trade_magic_items.gold.direction) .. " " .. incoming.amount)
end


-- gets the player into our window: at once in diplomacy, after the panel
-- they are in, or (simultaneous turns only) diplomacy is forced open
-- (findings 7.1a)
local function ad_bring_in()
    if not ad_incoming then
        return
    end

    local ui = cm:get_campaign_ui_manager()

    core:remove_listener(AD_BRING_IN_LISTENER)

    if ui:is_panel_open("diplomacy_dropdown") then
        trade_magic_items.log("Bring in: diplomacy is open")
        trade_magic_items.open_trade_magic_items_panel()
        return
    end

    local blocking = ui:get_open_blocking_or_event_panel()

    if blocking then
        trade_magic_items.log("Bring in: waiting for panel " .. tostring(blocking))

        core:add_listener(
            AD_BRING_IN_LISTENER,
            "PanelClosedCampaign",

            true,

            function()
                -- the UI manager notes the closed panel on the same event
                cm:real_callback(ad_bring_in, 100)
            end,

            false
        )

        return
    end

    -- turn by turn the game pulls this player into diplomacy itself, the
    -- listener below opens the window then
    if common.get_context_value("IsSimultaneousTurns") ~= true then
        trade_magic_items.log("Bring in: waiting for native diplomacy")
        return
    end

    -- the force of 0.12.0 (user, MP test build 2026-11-02)
    trade_magic_items.log("Bring in: forcing diplomacy with cqi " .. ad_incoming.from)
    ad_forced_diplomacy = true

    local ok, err = pcall(common.call_context_command, "CcoCampaignFaction", tostring(ad_incoming.from), "OpenDiplomacyWith")

    if not ok then
        trade_magic_items.log("ERROR: forcing diplomacy failed: " .. tostring(err))
        ad_forced_diplomacy = false
    end
end


-- also opens the window when diplomacy came up some other way
core:add_listener(
    "AD_HumanDiplomacyOpened",
    "PanelOpenedCampaign",

    function(context)
        return context.string == "diplomacy_dropdown" and ad_incoming ~= nil and ad_incoming.complete == true
    end,

    function()
        trade_magic_items.log("Bring in: diplomacy opened")
        core:remove_listener(AD_BRING_IN_LISTENER)
        cm:real_callback(ad_bring_in, 300)
    end,

    true
)


local function ad_show_incoming()
    local panel = trade_magic_items.panel_cache

    -- our window is open for this player: a counteroffer, or they were
    -- quicker than our own deal
    if panel and panel:Visible() and ad_human_deal and ad_human_deal.partner == ad_incoming.from_key then
        ad_fill_incoming(panel)
    else
        ad_bring_in()
    end
end


local function ad_on_proposal_start(fields, from, for_us)
    local base = fields[5]

    if ad_live_deal and base ~= ad_live_deal.id and ad_live_deal.from ~= from then
        trade_magic_items.log("Proposal " .. fields[2] .. " dropped: " .. ad_live_deal.id .. " came first")
        return
    end

    ad_live_deal = { id = fields[2], from = from }

    if for_us then
        ad_incoming = {
            deal = fields[2],
            from = from,
            from_key = cm:model():faction_for_command_queue_index(from):name(),
            payer = tonumber(fields[6]),
            amount = tonumber(fields[7]),
            count = tonumber(fields[8]),
            items = {}
        }
    end
end


-- a deal event from the deal manager; only the two players of the deal
-- do anything
function trade_magic_items.on_human_event(fields)
    local kind, deal, from, to = fields[1], fields[2], tonumber(fields[3]), tonumber(fields[4])
    local player_cqi = ad_local_cqi()
    local for_us = to == player_cqi

    if not for_us and from ~= player_cqi then
        return
    end

    if kind == "B" then
        ad_on_proposal_start(fields, from, for_us)
    elseif kind == "I" and for_us and ad_incoming and ad_incoming.deal == deal then
        table.insert(ad_incoming.items, { owner = tonumber(fields[5]), key = fields[6], holder = tonumber(fields[7]) })
    elseif kind == "E" and for_us and ad_incoming and ad_incoming.deal == deal then
        if #ad_incoming.items ~= ad_incoming.count then
            trade_magic_items.log("WARNING: proposal " .. deal .. " has " .. #ad_incoming.items .. " of " .. ad_incoming.count .. " items")
        end

        ad_incoming.complete = true
        ad_show_incoming()
    elseif kind == "A" or kind == "D" then
        ad_live_deal = nil

        if for_us then
            ad_on_human_answer(kind == "A" and "they_accepted" or "they_declined")
        end
    end
end


-- Any deal on the map, called on every client after its last op. With
-- simultaneous turns the other player's deal can change the lists of a
-- window open here: its ticks on items that are gone must leave the deal
-- (user, 0.12.5: they still counted in the chance). Rows take a moment,
-- like on open. A locked window keeps the deal it is showing.
local AD_LISTS_SETTLE_MS = 300

function trade_magic_items.on_deal_done()
    cm:real_callback(
        function()
            -- read now: closing diplomacy destroys the panel
            local panel = trade_magic_items.panel_cache

            if not panel or not panel:Visible() or not trade_magic_items.working or ad_items_locked() then
                return
            end

            local ok, err = pcall(function()
                for _, column_id in ipairs(trade_magic_items.COLUMNS) do
                    ad_refresh_row_info(panel, column_id)
                end

                ad_restore_ticks(panel)
                ad_refresh_deal_chance(panel)
            end)

            if not ok then
                trade_magic_items.log("ERROR: refreshing after a deal failed: " .. tostring(err))
            end
        end,
        AD_LISTS_SETTLE_MS
    )
end


-- a proposal nobody answered (a player left the window) stops counting
-- with the next turn; a model event, so on both clients at the same point
core:add_listener(
    "AD_HumanDealTurnStart",
    "FactionTurnStart",

    function(context)
        return ad_live_deal ~= nil and context:faction():is_human()
    end,

    function()
        trade_magic_items.log("Proposal " .. ad_live_deal.id .. " no longer counts: new turn")
        ad_live_deal = nil
    end,

    true
)


core:add_listener(
    "AD_TradeMagicItemsCounter",
    "ComponentLClickUp",

    function(context)
        return context.string == "counter_trade_magic_items"
    end,

    function()
        trade_magic_items.log("Counteroffer clicked, state=" .. tostring(ad_human_deal and ad_human_deal.state))

        if ad_human_deal and ad_human_deal.state == "review" and trade_magic_items.panel_cache then
            ad_set_human_state(trade_magic_items.panel_cache, "counter", "counteroffer")
        end
    end,

    true
)


------------------------------------------------------------
-- GOLD EVENTS
-- Arrow and give / demand clicks: ComponentLClickUp (0.6.3 log: the
-- field already shows the new number then; 0.6.5 log: the switch is
-- clicked on its label as often as on the radio). Typing: in the layout
-- the field's value_changed_event and TextInputChanged run
-- TriggerUIScriptEvent("trade_magic_items_gold_changed"), which reaches Lua as
-- ContextUITriggerEvent, context.string (UI only, local; vanilla:
-- wh3_dlc29_ulric_decrees_req.lua). It is not UITrigger, that is why
-- typing did not refresh the chance before 0.8.0.
------------------------------------------------------------

-- clicked id -> direction it selects (false: arrows, keep the direction)
local AD_GOLD_CLICK_IDS = {
    l_arrow_amount = false,
    r_arrow_amount = false,
    pay_offer = "give",
    once_tx = "give",
    pay_demand = "demand",
    repeatedly_tx = "demand"
}


core:add_listener(
    "AD_GoldClicked",
    "ComponentLClickUp",

    function(context)
        -- pay_offer / pay_demand also exist in the native payments panel
        return AD_GOLD_CLICK_IDS[context.string] ~= nil
            and trade_magic_items.panel_cache ~= nil
            and uicomponent_descended_from(UIComponent(context.component), "trade_magic_items")
    end,

    function(context)
        local direction = AD_GOLD_CLICK_IDS[context.string] or nil
        local ok, err = pcall(ad_on_gold_changed, "click " .. context.string, direction)

        if not ok then
            trade_magic_items.log("ERROR: gold click failed: " .. tostring(err))
        end
    end,

    true
)


core:add_listener(
    "AD_BalanceClicked",
    "ComponentLClickUp",

    function(context)
        return context.string == "trade_magic_items_balance_button" and trade_magic_items.panel_cache ~= nil
    end,

    function()
        local ok, err = pcall(ad_balance_deal)

        if not ok then
            trade_magic_items.log("ERROR: balancing the deal failed: " .. tostring(err))
        end
    end,

    true
)


core:add_listener(
    "AD_GoldValueChanged",
    "ContextUITriggerEvent",

    function(context)
        return context.string == "trade_magic_items_gold_changed"
    end,

    function()
        local ok, err = pcall(ad_on_gold_changed, "value event")

        if not ok then
            trade_magic_items.log("ERROR: gold value event failed: " .. tostring(err))
        end
    end,

    true
)


------------------------------------------------------------
-- MAGIC ITEMS PANEL CANCEL
------------------------------------------------------------

-- the Cancel button and Esc (source: "button" / "esc")
function trade_magic_items.cancel_window(source)
    trade_magic_items.log("Trade magic items panel cancel: " .. tostring(source))

    if ad_human_deal and ad_human_deal.state == "waiting" then
        trade_magic_items.log("Cancel ignored: waiting for the other player")
        return
    end

    if ad_human_deal and ad_human_deal.state ~= "compose" then
        trade_magic_items.log("Human deal declined")
        ad_send_answer("D")
        ad_human_deal = nil
        trade_magic_items.human_partner = nil
    end

    -- like vanilla: changes since opening are thrown away
    trade_magic_items.working = nil
    ad_log_selection("Pending selection kept", trade_magic_items.pending)

    ad_close_trade_magic_items_panel()
    ad_close_forced_diplomacy()
end


core:add_listener(
    "AD_TradeMagicItemsCancel",
    "ComponentLClickUp",

    function(context)
        return context.string == "cancel_trade_magic_items"
    end,

    function()
        trade_magic_items.cancel_window("button")
    end,

    true
)


-- TRADE WATCH: the model has no ids and a transfer does not return one,
-- but our two lists show exactly the two factions of the deal. On OK the
-- ids listed so far are noted with what each side should receive; after
-- the last op the lists are read again and ids that are new, with the
-- expected key, are the traded copies. Runs only on the client that made
-- the deal; "N" ops then write the records on every client.
local function ad_expected_items(column, receiver)
    local expected = {}

    for _, info in pairs(column) do
        if info.key then
            local delivered = trade_magic_items.delivery_key(info.key, receiver)

            expected[delivered] = (expected[delivered] or 0) + 1
        end
    end

    return expected
end


local function ad_listed_ids(column_id)
    local ids = {}

    for item_id in pairs(ad_row_info[column_id]) do
        ids[tostring(item_id)] = true
    end

    return ids
end


local function ad_start_trade_watch(selection, player, partner)
    ad_trade_watch = {
        player_cqi = player:command_queue_index(),
        partner_cqi = partner:command_queue_index(),
        partner = partner:name(),
        list_offers = { known = ad_listed_ids("list_offers"), expected = ad_expected_items(selection.list_demands, player) },
        list_demands = { known = ad_listed_ids("list_demands"), expected = ad_expected_items(selection.list_offers, partner) }
    }
end


-- ad_row_info must be fresh. Copies not found yet stay in the watch for
-- the next time the panel opens for this partner.
function ad_resolve_trade_watch()
    local watch = ad_trade_watch
    local target = trade_magic_items.get_target_faction()

    if not watch or not target or target:name() ~= watch.partner then
        return
    end

    local waiting = 0

    for _, column_id in ipairs(trade_magic_items.COLUMNS) do
        local column = watch[column_id]

        for item_id, info in pairs(ad_row_info[column_id]) do
            local id = tostring(item_id)

            if not column.known[id] and (column.expected[info.key] or 0) > 0 then
                column.known[id] = true
                column.expected[info.key] = column.expected[info.key] - 1
                trade_magic_items.log("Traded copy found: " .. column_id .. " item=" .. id .. " " .. info.key)
                CampaignUI.TriggerCampaignScriptEvent(watch.player_cqi, table.concat({
                    trade_magic_items.TRADE_EVENT .. ";N", watch.player_cqi, watch.partner_cqi, id
                }, ","))
            end
        end

        for _, count in pairs(column.expected) do
            waiting = waiting + count
        end
    end

    if waiting == 0 then
        ad_trade_watch = nil
    else
        trade_magic_items.log("Trade watch: " .. waiting .. " copies not listed yet")
    end
end


-- the lists have to be bound again to show the deal's result; rows come
-- a few frames later, like on open
function trade_magic_items.check_trade_watch()
    local panel = trade_magic_items.panel_cache
    local partner = trade_magic_items.get_target_faction()

    if not ad_trade_watch or not panel or not partner then
        return
    end

    ad_bind_item_lists(panel)

    cm:real_callback(
        function()
            local ok, err = pcall(function()
                ad_mark_item_holders(panel, "list_offers", cm:get_faction(cm:get_local_faction_name(true)))
                ad_mark_item_holders(panel, "list_demands", partner)
                ad_resolve_trade_watch()
            end)

            if not ok then
                trade_magic_items.log("ERROR: trade watch failed: " .. tostring(err))
            end
        end,
        200
    )
end


------------------------------------------------------------
-- MAGIC ITEMS PANEL OK
-- Test mode: executes the deal (see the deal manager). Later: propose, the AI
-- answers, then the trade.
------------------------------------------------------------

core:add_listener(
    "AD_TradeMagicItemsOk",
    "ComponentLClickUp",

    function(context)
        return context.string == "ok_trade_magic_items"
    end,

    function()

        trade_magic_items.log("Trade magic items panel OK clicked")

        if ad_human_deal and trade_magic_items.panel_cache then
            ad_human_ok(trade_magic_items.panel_cache)
            return
        end

        -- the deal as it stands right now, whatever events came before
        local gold_ok, gold_err = pcall(ad_on_gold_changed, "OK")

        if not gold_ok then
            trade_magic_items.log("ERROR: reading the gold failed: " .. tostring(gold_err))
        end

        if not ad_deal_allowed() then
            trade_magic_items.log("OK ignored: deal not allowed, items=" .. ad_selection_size(trade_magic_items.working) .. " total=" .. tostring(ad_deal_total))
            return
        end

        local events = trade_magic_items.build_trade(trade_magic_items.working, trade_magic_items.gold)

        if not events then
            trade_magic_items.log("OK ignored: nothing to trade")
            return
        end

        local player = cm:get_faction(cm:get_local_faction_name(true))

        ad_log_selection("Trading", trade_magic_items.working)
        trade_magic_items.log("Sending " .. #events .. " trade ops")
        ad_start_trade_watch(trade_magic_items.working, player, trade_magic_items.get_target_faction())

        for _, event in ipairs(events) do
            CampaignUI.TriggerCampaignScriptEvent(player:command_queue_index(), event)
        end

        -- the deal is done: nothing stays selected
        trade_magic_items.pending = nil
        trade_magic_items.working = nil

        local panel = trade_magic_items.panel_cache

        if panel then
            ad_show_result_view(panel, true)
            cm:trigger_2d_ui_sound(AD_DEAL_ACCEPTED_SOUND, 0)
        else
            ad_close_trade_magic_items_panel()
        end

    end,

    true
)


------------------------------------------------------------
-- RESULT CONFIRM
-- Closes the "they accepted" view and the panel.
------------------------------------------------------------

core:add_listener(
    "AD_TradeMagicItemsConfirm",
    "ComponentLClickUp",

    function(context)
        return context.string == "confirm_trade_magic_items"
    end,

    function()
        trade_magic_items.log("Trade magic items result confirmed")

        if trade_magic_items.panel_cache then
            ad_show_result_view(trade_magic_items.panel_cache, false)
        end

        ad_close_trade_magic_items_panel()
        ad_close_forced_diplomacy()
    end,

    true
)


------------------------------------------------------------
-- ITEM CHECKBOX
-- Adds/removes the row's item in the working selection.
-- checkbox_toggle also exists in the character panel, so only clicks
-- inside our panel count.
------------------------------------------------------------

local function ad_is_inside_panel(uic)
    local root = core:get_ui_root()
    local current = uic

    while current and current:Address() ~= root:Address() do
        if current:Id() == AD_PANEL_ID then
            return true
        end

        local parent_address = current:Parent()

        if not parent_address then
            return false
        end

        current = UIComponent(parent_address)
    end

    return false
end


-- "list_offers" / "list_demands" for a component inside one of the columns
local function ad_get_column_of(uic)
    local current = uic

    while current do
        local id = current:Id()

        if id == "list_offers" or id == "list_demands" then
            return id
        end

        if id == AD_PANEL_ID then
            return nil
        end

        local parent_address = current:Parent()

        if not parent_address then
            return nil
        end

        current = UIComponent(parent_address)
    end
end


core:add_listener(
    "AD_TradeMagicItemsCheckbox",
    "ComponentLClickUp",

    function(context)
        return context.string == "checkbox_toggle"
    end,

    function(context)
        local checkbox = UIComponent(context.component)

        if not ad_is_inside_panel(checkbox) then
            return
        end

        if ad_items_locked() then
            trade_magic_items.log("Item checkbox ignored: the deal is locked")
            return
        end

        local row = UIComponent(checkbox:Parent())
        local column_id = ad_get_column_of(row)

        -- the checkbox switches its own state; read it a moment later
        cm:real_callback(
            function()
                local item_id = row:GetContextObjectId("CcoCampaignAncillary")
                local state = tostring(checkbox:CurrentState())
                local selected = string.find(state, "selected") ~= nil

                if not item_id or not column_id or not trade_magic_items.working then
                    trade_magic_items.log("Item checkbox ignored: item=" .. tostring(item_id) .. " column=" .. tostring(column_id))
                    return
                end

                if selected and not ad_row_info[column_id][item_id] and trade_magic_items.panel_cache then
                    local refresh_ok, refresh_err = pcall(ad_refresh_row_info, trade_magic_items.panel_cache, column_id)

                    if not refresh_ok then
                        trade_magic_items.log("ERROR: refreshing the rows failed: " .. tostring(refresh_err))
                    end
                end

                if selected then
                    local info = ad_row_info[column_id][item_id] or {}
                    trade_magic_items.working[column_id][item_id] = { key = info.key, holder_cqi = info.holder_cqi, name = info.name, rarity = info.rarity, tab = info.tab }
                else
                    trade_magic_items.working[column_id][item_id] = nil
                end

                trade_magic_items.log(
                    "Item " .. (selected and "selected" or "unselected") .. ": "
                    .. column_id .. " item=" .. item_id .. " " .. tostring((ad_row_info[column_id][item_id] or {}).key)
                    .. " | selection size=" .. ad_selection_size(trade_magic_items.working)
                )

                local panel = find_uicomponent(core:get_ui_root(), "diplomacy_dropdown", AD_PANEL_ID)

                if panel then
                    local chance_ok, chance_err = pcall(ad_refresh_deal_chance, panel)

                    if not chance_ok then
                        trade_magic_items.log("ERROR: evaluating the deal failed: " .. tostring(chance_err))
                    end
                end
            end,
            100
        )
    end,

    true
)


------------------------------------------------------------
-- TAB BUTTONS
-- UI only: shows the tab's lists, the deal stays as it is. A greyed tab
-- ignores the click (its state may still have flipped: set back).
------------------------------------------------------------

core:add_listener(
    "AD_TradeMagicItemsTab",
    "ComponentLClickUp",

    function(context)
        return AD_TAB_BY_BUTTON[context.string] ~= nil
    end,

    function(context)
        local button = UIComponent(context.component)
        local tab = AD_TAB_BY_BUTTON[context.string]

        if not ad_is_inside_panel(button) then
            return
        end

        -- the button toggles its own state on the click; set ours after
        cm:real_callback(
            function()
                local panel = trade_magic_items.panel_cache

                if not panel then
                    return
                end

                local ok, err = pcall(function()
                    if ad_tab_available(tab) then
                        trade_magic_items.show_tab(panel, tab)
                    else
                        trade_magic_items.log("Tab " .. tab .. " click ignored: nothing to trade there")
                        ad_update_tabs(panel)
                    end
                end)

                if not ok then
                    trade_magic_items.log("ERROR: switching to tab " .. tab .. " failed: " .. tostring(err))
                end
            end,
            50
        )
    end,

    true
)
