------------------------------------------------------------
-- MCT MENU (1.1.0)
-- Read only by MCT (Mod Configuration Tool), which loads every file in
-- script/mct/settings/. Without MCT this file is never run and the mod
-- uses its defaults. Builds our page: the sections and fields of
-- script/campaign/mod/diplomacy_trade_magic_items_mct_fields_and_checks.lua, each field showing the
-- default of script/campaign/mod/diplomacy_trade_magic_items_default_ai_evaluation_values.lua. Numbers are
-- text fields (user: no slider limits); a value the field refuses gets a
-- popup with the reason. The campaign reads the values back in
-- script/campaign/mod/diplomacy_trade_magic_items_settings.lua.
-- Texts: loc keys mct_diplomacy_trade_magic_items_* (title, section_*,
-- <option>_text, <option>_tooltip, author, description), read by MCT
-- itself; they live in their own file text/diplomacy_trade_magic_items_mct.loc.
------------------------------------------------------------

local defaults = require "script.campaign.mod.diplomacy_trade_magic_items_default_ai_evaluation_values"
local spec = require "script.campaign.mod.diplomacy_trade_magic_items_mct_fields_and_checks"

local mct = get_mct()
local mod = mct:register_mod(spec.MOD_KEY)

-- the mod's own page in MCT. Title, author and description: loc keys
-- mct_diplomacy_trade_magic_items_title / _author / _description.
-- Keep the version in step with AD_VERSION in the deal manager (this file
-- runs before the campaign scripts, so it cannot read it)
mod:set_version(1.1, "1.1.0")
mod:set_workshop_id("3832894578")
-- the Workshop thumbnail, 256x256: shown at its own size, not stretched
mod:set_main_image("ui/mct/diplomacy_trade_magic_items.png", 256, 256)

local SECTION_LOC_PREFIX = "mct_" .. spec.MOD_KEY .. "_section_"
local LABEL_LOC_PREFIX = "mct_" .. spec.MOD_KEY .. "_"


-- a shared label (rarity, attitude tier) instead of the field's own text
-- key: MCT reads the given key when its own one is not in the loc
local function set_label(field, option)
    if option.label then
        field:set_text(LABEL_LOC_PREFIX .. option.label)
    end
end


-- sections in menu order; every option is added after its section, so
-- MCT never makes its own "default" section (it only does for an option
-- added before any section)
for _, section in ipairs(spec.SECTIONS) do
    mod:add_new_section(section, SECTION_LOC_PREFIX .. section)

    for _, option in ipairs(spec.OPTIONS) do
        if option.section == section then
            local default = spec.get(defaults, option.path)

            if option.kind == "checkbox" then
                local field = mod:add_new_option(option.key, "checkbox")

                field:set_default_value(default)
                set_label(field, option)
            else
                local field = mod:add_new_option(option.key, "text_input")
                local kind = option.kind

                field:set_default_value(spec.format(default))
                set_label(field, option)
                field:add_validity_test(function(text)
                    local value, refused = spec.parse(kind, text)

                    if value == nil then
                        return false, refused
                    end

                    return true
                end)
            end
        end
    end
end
