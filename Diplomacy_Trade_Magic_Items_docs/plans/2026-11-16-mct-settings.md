# 1.1.0 Settings Window (MCT) and Trade Agreement Rule — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans (user chose inline). Steps use checkbox (`- [ ]`) syntax.

**Goal:** All balance numbers come from one defaults file, overlaid by MCT values when MCT is installed; MCT shows 41 text fields; an optional rule greys the button without a trade agreement.

**Architecture:** `defaults.lua` (plain data, `require`d by both MCT and the campaign) → `settings.lua` (campaign: current values = deep copy of defaults, overlaid by MCT on `MctInitialized` / `MctFinalized`) → the deal manager and the button script read `trade_magic_items.settings`. The MCT settings file only describes the menu.

**Tech Stack:** Lua 5.1 (game), MCT (optional Workshop mod).

**Spec:** `Diplomacy_Trade_Magic_Items_docs/01_decisions_and_findings.md` §7.7 (numbers from §7.6).

## Global Constraints

- MCT mod key: `diplomacy_trade_magic_items`. Loc keys follow MCT's auto names: `mct_diplomacy_trade_magic_items_title`, `…_<option>_text`, `…_<option>_tooltip`; section names `mct_diplomacy_trade_magic_items_section_<key>`.
- Option order and defaults exactly as §7.7: rules, prices, items, ancillaries, worn, Order 13 tiers, Destruction 13 tiers, deal memory.
- MCT text inputs hold strings: defaults are written as strings in MCT (`"2.5"`), parsed with `tonumber` in `settings.lua`; invalid or out of range → the default, with a log line.
- Validation in MCT and again in `settings.lua`: numbers only; prices, worn %, recent %, frequency penalty, big deal ≥ 0; gold per point > 0; turns whole ≥ 1; tier values any number.
- Evaluation guard: attitude discount on their items capped at 100% (`percent >= -100`).
- Without MCT (`get_mct` nil, or our mod not registered): defaults, no error. Nothing from MCT is written to our saved values.
- Trade agreement rule: option on and no agreement → button inactive with its own tooltip; war first. `faction:trade_agreement_with(other)` in a pcall (HYPOTHESIS).
- English texts only; Russian in the RU pass. Commit only when the user asks.

## Review Focus

- MCT missing entirely, or present but our settings file failed to load: the mod runs on defaults.
- A player types "1,5" / "abc" / "-3" into a price: MCT refuses it (validity test), and if a bad value ever arrives `settings.lua` falls back to the default.
- Settings applied mid-campaign (`MctFinalized`): the next deal evaluation uses them without a reload.
- Tier values typed in any order (e.g. a discount bigger than 100%): no free or negative price.
- Rule on, at war: the war tooltip, not the trade agreement one.

---

### Task 1: Defaults, settings reader, deal manager on settings

**Files:**
- Create: `Diplomacy_Trade_Magic_Items_packfile/script/campaign/mod/diplomacy_trade_magic_items_default_ai_evaluation_values.lua`
- Create: `Diplomacy_Trade_Magic_Items_packfile/script/campaign/mod/diplomacy_trade_magic_items_settings.lua`
- Modify: `…/script/campaign/mod/diplomacy_trade_magic_items_deal_manager.lua` (DEAL TUNING block, evaluation, memory helpers, big deal)

**Interfaces:**
- Produces `defaults.lua` returning:
  `{ trade_agreement_only = false, payment_per_point = 1000, item_points = { common, uncommon, rare, crafted }, ancillary_points = { common, uncommon, rare }, worn_percent = 30, attitude_tiers = { 13 × { key =, min_attitude = | max_attitude = | middle = true } in menu order ≥300 … ≤−300 }, attitude_percent = { order = {13}, destruction = {13} }, frequency_first = 5, frequency_turns = 15, recent_percent = 50, recent_turns = 10, big_deal_rarity = 35 }`
- Produces `trade_magic_items.settings` (same shape, current values) and `trade_magic_items.SETTINGS_MCT_KEY`.
- The rarity keys map `wh_main_anc_group_common` → `common` etc. in the deal manager; crafted ancillaries use `ancillary_points.rare`.

- [ ] Step 1: write `defaults.lua` with the §7.7 values.
- [ ] Step 2: write `settings.lua`: deep copy of defaults; `trade_magic_items.read_mct_settings(reason)` maps every MCT option key to its field with validation; listeners on `MctInitialized` and `MctFinalized`; logs "Settings: defaults" / "Settings from MCT (<reason>): <changed keys>".
- [ ] Step 3: deal manager: remove the tuning constants (keep `AD_DESTRUCTION_SUBCULTURES`, frequency growth 2, events); every use reads `trade_magic_items.settings`; `GOLD_PER_POINT` becomes a read of the setting (the screen uses `trade_magic_items.GOLD_PER_POINT` → replace with a getter `trade_magic_items.payment_per_point()`); attitude percent walks good tiers in menu order and bad tiers from ≤−300 up, middle otherwise; cap at −100.
- [ ] Step 4: Lua check → `0 with syntax errors, 0 unknown globals`; grep the old constant names → none.

### Task 2: MCT menu and its texts

**Files:**
- Create: `Diplomacy_Trade_Magic_Items_packfile/script/mct/settings/diplomacy_trade_magic_items.lua`
- Modify: `Diplomacy_Trade_Magic_Items_packfile/text/diplomacy_trade_magic_items.loc.tsv` (append MCT keys)

- [ ] Step 1: register the mod (`get_mct():register_mod(key)`), sections in §7.7 order, one checkbox + 40 text inputs with defaults from `defaults.lua` (as strings) and validity tests matching the Global Constraints.
- [ ] Step 2: English loc: title, 8 section names, 41 option texts, tooltips for the non-obvious ones (gold per point, worn, the two tier sections' first field, frequency, recent, big deal, rule).
- [ ] Step 3: Lua check (also run on the new MCT file) → 0 errors.

### Task 3: Trade agreement rule on the button

**Files:**
- Modify: `…/script/campaign/mod/diplomacy_trade_magic_items_diplomacy_option_button.lua` (the at-war block ~267–330 and its click guard ~459)
- Modify: loc (one tooltip key `diplomacy_strings_string_diplomatic_option_trade_magic_items_no_trade_agreement_tooltip`, draft text for the user)

- [ ] Step 1: the block that greys the button for war also greys it when `settings.trade_agreement_only` and no agreement; state tracked like `ad_at_war`; war tooltip wins; the click guard refuses the same way.
- [ ] Step 2: Lua check → 0 errors.

### Task 4: Docs

- [ ] §7.7 status → built, awaiting test, with the in-game check list; 00_START_HERE 1.1.0 line and file table rows for the three new files.
