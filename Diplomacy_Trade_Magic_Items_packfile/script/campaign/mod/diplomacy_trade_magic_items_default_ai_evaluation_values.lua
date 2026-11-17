------------------------------------------------------------
-- DEFAULT SETTINGS (1.1.0)
-- The mod's balance, the only place its numbers are written. Plain data:
-- read with require "script.campaign.mod.diplomacy_trade_magic_items_default_ai_evaluation_values" by the
-- campaign (script/campaign/mod/diplomacy_trade_magic_items_settings.lua,
-- which overlays the MCT values when MCT is installed) and by the MCT menu
-- (script/mct/settings/diplomacy_trade_magic_items.lua), which shows these
-- as the defaults. The campaign loader also runs this folder by itself
-- (it returns data only, harmless; user: keep it with our scripts).
-- Numbers: findings §7.6 / §7.7 (user, 2026-11-16).
------------------------------------------------------------

return {
    -- item trading only with a trade agreement (the button greys out
    -- without one, like at war)
    trade_agreement_only = false,

    -- gold in the deal: this much gold is one point
    payment_per_point = 1000,

    -- rarity points of a magic item: + offered, - demanded. Each step
    -- x2.4 (x2 + 20%) so trading does not beat crafting; crafted stands
    -- apart (rare x 1.39)
    item_points = {
        common = 2.5,
        uncommon = 6,
        rare = 14.4,
        crafted = 20
    },

    -- the same for ancillaries, the Banners and Followers tabs; none is
    -- crafted (a crafted one would count as rare)
    ancillary_points = {
        common = 2,
        uncommon = 4,
        rare = 8
    },

    -- a demanded item worn by one of their characters costs this percent
    -- of its rarity points more
    worn_percent = 30,

    -- their attitude towards us -> percentage on the price of their items
    -- (rarity + worn): + dearer, - cheaper for us. The borders are fixed,
    -- in menu order; the values per scale are in attitude_percent, same
    -- order. min_attitude: this or better; max_attitude: this or worse;
    -- middle: strictly between -25 and 25
    attitude_tiers = {
        { key = "300", min_attitude = 300 },
        { key = "200", min_attitude = 200 },
        { key = "150", min_attitude = 150 },
        { key = "100", min_attitude = 100 },
        { key = "50", min_attitude = 50 },
        { key = "25", min_attitude = 25 },
        { key = "middle", middle = true },
        { key = "minus_25", max_attitude = -25 },
        { key = "minus_50", max_attitude = -50 },
        { key = "minus_100", max_attitude = -100 },
        { key = "minus_150", max_attitude = -150 },
        { key = "minus_200", max_attitude = -200 },
        { key = "minus_300", max_attitude = -300 }
    },

    attitude_percent = {
        order = { -25, -20, -15, -10, -5, 0, 5, 10, 20, 35, 50, 70, 100 },
        -- easier without good relations: smaller penalties that start
        -- later, smaller bonuses
        destruction = { -12.5, -10, -7.5, -5, -2.5, 0, 0, 0, 5, 10, 20, 30, 50 }
    },

    -- deals frequency: a faction that traded items lately, with anyone, is
    -- less willing: this many points after its first deal, x2 after each
    -- further one; gone after frequency_turns turns without a deal
    frequency_first = 5,
    frequency_turns = 15,

    -- recently traded: an item moved between us and them costs this
    -- percent of its rarity points when it goes back the other way, fading
    -- to 0 over recent_turns turns
    recent_percent = 50,
    recent_turns = 10,

    -- a deal whose rarity points (both sides) reach this is a big deal:
    -- STATE_GIFT_MEDIUM instead of STATE_GIFT_SMALL
    big_deal_rarity = 35
}
