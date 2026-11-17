# Trade Magic Items — Decisions & Findings

Living document. Newest facts win. `00_handoff_original.md` is the frozen starting point;
where this file disagrees with it, this file is correct.

Legend: **PROVEN** = confirmed in game. **DOC** = from vanilla files / official script docs, not yet tested by us. **HYPOTHESIS** = untested guess.

---

## 1. Product decisions (from user, 2026-10-24)

| Topic | Decision |
|---|---|
| Deal shape | Ideal: items are part of the normal diplomacy deal (like gold / settlements). One proposal per side for the whole deal, items listed by name. Fallback acceptable: whatever actually works. |
| Multiplayer | Single-player is fine for experiments. **MVP requires player-to-player item trade in MP** — this is the reason the mod exists. A second tester is available. |
| Tradeable items | All magic items **except rarity "unique"** (purple — quest / faction / character-locked). |
| Equipped items | Should be tradeable. AI should be less willing to give away equipped items. |
| Followers | Deferred (handoff §28). |
| Item list UI donor | Character details → Equipment → global pool magic items list (see §4). |

## 2. Current pack contents (verified 2026-10-24)

The folder `Diplomacy_Trade_Magic_Items_packfile/` matches the pack.

```text
db/diplomatic_actions_tables/items_diplomacy_trading            (key, category, sort_order = 210)
script/campaign/mod/items_diplomacy_trading.lua                  (AD_VERSION 0.1.0)
script/campaign/mod/items_diplomacy_trading_debug.lua            (experiments, throwaway)
ui/campaign ui/ad_holder_portrait.twui.xml                       (equipped-by portrait for other factions, no callbacks)
script/enable_console_logging
text/artifact_diplomacy_trading.loc                              (2 keys)
ui/campaign ui/diplomatic_option_trade_magic_items.twui.xml      (action button)
ui/campaign ui/diplomacy_hud_trade_magic_items.twui.xml          (panel)
ui/campaign ui/diplomacy_icons/diplomatic_option_trade_magic_items.png
```

- `diplomacy_strings_tables` row was removed by the user: after a vanilla update it is no longer needed.
- Handoff names (`artifact_diplomacy_trading.lua`, `text/db/...`) are outdated. The Lua file is `items_diplomacy_trading.lua`.
- Note: `.loc` currently sits at `text/artifact_diplomacy_trading.loc` (not `text/db/`) and the user reports it works. Handoff §4 claimed root-of-pack failed; `text/` subfolder apparently is fine.

## 3. Vanilla diplomacy layout — `ui/campaign ui/diplomacy_hud.twui.xml` (DOC)

There is no `diplomacy_dropdown.twui.xml`; the dropdown layout lives in `diplomacy_hud.twui.xml`.

```text
diplomacy_hud
├── subpanel_group     visible by default, 760x365, Bottom Center, offset 420,535, has panel background images
│   ├── panel_smoke_t
│   ├── war_declared
│   ├── end_trade
│   ├── payments       visible=false, 760x365, ComponentCreator -> ui/campaign ui/diplomacy_hud_payments
│   ├── request_join_war
│   └── trade_regions  visible=false, 760x365, ComponentCreator -> ui/campaign ui/diplomacy_hud_trade_regions
├── faction_panel
├── offers_panel       visible=false, 810x365, Bottom Center, offset 395,535,
│                      ComponentCreator -> ui/campaign ui/diplomacy_hud_offers_panel
└── faction_right_status_panel
```

Observations:
- `offers_panel` and `subpanel_group` occupy the **same screen spot** (bottom center, same size class). Native code shows one and hides the other.
- Each vanilla subpanel is an **empty 760x365 holder** whose content is loaded by the `ComponentCreator` callback. Our panel is created by Lua instead — equivalent idea.
- HYPOTHESIS for open: `offers_panel` → hidden; `subpanel_group` → visible; our holder → visible; other subpanel children → hidden. Close = reverse. To be confirmed by the state logger (Block 1).

## 4. Magic items list donor — `character_details_panel_details.twui.xml` (DOC)

Path to the list shown in the user's screenshot:

```text
global_pool
└── global_ancillaries_listview
    └── list_clip > list_box
        ├── magic_items_panel            <- magic items
        │   └── template_item_holder
        │       ├── checkbox_toggle (tx_assigned, icon)
        │       └── ancillary_entry (dy_label, dy_name, magic_effect,
        │            equipment_items_frame/dy_icon, cooldown,
        │            assigned_char_portrait/forces_icon, dy_set_icon, icon_new)
        └── general_ancillaries_panel    <- followers, same template
```

`magic_items_panel` gets its rows from the native `List` callback:

```text
context_object_id   = CcoCampaignFaction
context_function_id = AncillaryList.Filter(
    AncillaryRecordContext.CategoryContext.IsHidden == false
    && AncillaryRecordContext.CategoryContext.Category != "general"
    && AncillaryRecordContext.CategoryContext.Category != "mount")
sort_func           = AncillaryRecordContext.UniquenessScore (descending)
refresh events      = AncillaryAddedToPool, CampaignAncillaryAssigned
plus callback       = ContextInitPlayerFaction   (binds list to the local player's faction)
```

Why this matters:
- **`CcoCampaignFaction.AncillaryList` is how the game lists a faction's items** (pool + equipped; rows show the assigned character portrait).
- The script model (Lua `FACTION_SCRIPT_INTERFACE`) has **no** list-all-items call — only `ancillary_exists(key)`, `num_ancillaries_owned`, `character:has_ancillary(key)`, `model:characters_owning_ancillary(key)`.
- So enumeration should go through the context system, e.g. `common.get_context_value(...)` from Lua, or by binding a cloned list component to the target faction instead of `ContextInitPlayerFaction`.
- Same filter expression gives us "magic items only" for free; "exclude unique" will need a rarity check on `AncillaryRecordContext` (exact field TBD — inspect in Context Viewer).

### 4.1 In-game observations of the donor list (Context Viewer, 2026-10-24)

- Native `List` callback instantiates one row per item from `template_item_holder` and **names each row `CcoCampaignAncillary<id>`**. Lua can iterate `magic_items_panel` children and read item ids from names.
- `equipment_items_frame` carries rarity as images/states:
  `equipment_items_frame.png` (base), `item_frame.png` (round, likely mounts),
  `equipment_items_frame_common` (grey-green), `_uncommon` (green), `_rare` (blue),
  `_legendary` (purple = what we call "unique", **excluded from trade**), `_crafted` (olive).
- Row parts: `dy_label` (category: Armour/Weapon/Talisman…), `dy_name`, `equipment_items_frame/dy_icon`,
  `assigned_char_portrait/forces_icon` (equipped by), `dy_set_icon` (item set badge), `icon_new`, `checkbox_toggle`.
- Some rows render greyed out with a dim checkbox (e.g. equipped elsewhere). Driving property: TBD.
- Sort controls live in `global_pool > sort_holder`: `toggle_unassigned`, `dropdown_holder/dropdown_sort`
  (Rarity, Category, Name, Equippable, Unequipped, Fusible, Salvageable), `sort_type_button`. **Nice-to-have**, optional in Block 5.
- Context Viewer shows `CurrentPriorityLocker` (which panel owns input) — useful for freeze/input debugging.

## 4.2 Diplomacy screenshots — observed states (2026-10-24)

| State | What is on screen |
|---|---|
| A. Normal negotiation | `offers_panel`: Your Offers / Your Demands / Treaties columns, action buttons row (our armour button is right after Payment; Trade Settlement is last), bottom bar with propose/close buttons. |
| B. Vanilla Trade Settlement open | Whole `offers_panel` gone (columns, action buttons, propose buttons). Panel with title plaque taller than the box; bottom bar shows only ✓ / ✗. Faction info side panels stay. |
| C. Deal assembled | Each term is a row with its own ✗ remove button ("Trade Settlement / Mount Gunbad", "Payments 401", treaties). **Used actions (Payment, Trade Settlement) are removed from the action row; our button also disappears (rebuild bug)**. Bottom bar gains a 5th (scales) button. Green number bottom-right (e.g. 98.1) = AI acceptance score of the whole deal; propose is possible when green. |
| D. Our panel, first click | Looks identical to state B in layout (title, two columns, ✓/✗), with placeholder rows. Whether `offers_panel` is really hidden or just covered — to be confirmed by the logger. |

Context Viewer, state A (normal negotiation, after our panel had been opened once):

```text
diplomacy_dropdown                 visible
├── subpanel_group                 eye dimmed (hidden)
│   ├── panel_smoke_t, war_declared, end_trade, payments, request_join_war, trade_regions   hidden
│   └── trade_magic_items          hidden, has children (ours, created by Lua)
├── faction_panel                  hidden
└── offers_panel                   visible
    └── diplomacy_hud_offers_panel visible   (holder > layout-root naming pattern, same as trade_regions > diplomacy_hud_trade_regions)
        ├── panel_smoke_t, small_bar_bottom, strength_balance_bar, panel_diplomacy, ...
```

So in normal negotiation `subpanel_group` itself is hidden and `offers_panel` is visible — strong support for the open/close hypothesis in §3.

Context Viewer, state B (vanilla Trade Settlement button pressed) — **PROVEN by observation**:

| Component | State A (negotiation) | State B (Trade Settlement open) |
|---|---|---|
| `subpanel_group` | hidden | **visible** |
| `trade_regions` | hidden | **visible** |
| other subpanels (`panel_smoke_t`, `war_declared`, `end_trade`, `payments`, `request_join_war`, `trade_magic_items`) | hidden | hidden |
| `offers_panel` | visible | **hidden** |
| `diplomacy_hud_offers_panel` and its children | visible | eye dimmed (likely just because the parent is hidden; own flag probably unchanged) |
| `faction_panel` | hidden | hidden |

Also: in state B the ✓ (OK) button is greyed out while nothing is checked; ✗ (Cancel) is active.
Still unknown: state C transition (after Cancel / after OK) and whether any `SetState`/priority/input lock changes happen. Logger in Block 1 will capture both.

Consequences:
- The rebuild bug triggers as soon as the deal gets any term → Block 3 must ship together with open/close, not later.
- The AI score and deal execution are native and only know native terms. A custom "Magic Items" row in Your Offers is visually easy but likely does not affect the score or execute. Main risk of Block 6.
- Value badges above treaty buttons are irrelevant to us.

Target look (user mockup): Trade Settlement frame, two columns "Your …" / "Their …", each filled with donor item rows (checkbox, rarity-framed icon, category, name, equipped-by portrait, scrollbar).

### 4.3 Context-system names found in vanilla layouts (DOC, 2026-10-24)

Calling from Lua (pattern used by vanilla battle scripts):

```lua
common.get_context_value("CcoBattleRoot", "", "CapturePointList().Size")
common.get_context_value("CcoBattleRoot", "", "CapturePointList().At(" .. i .. ").TypeRecordContext().Key")  -- At() is 0-based
```

Diplomacy (`diplomacy_hud.twui.xml`, `diplomacy_hud_offers_panel.twui.xml`):
- `CurrentNegotiatingFactionContext` — the faction being negotiated with (used by the war coordination button).
- `PlayersFaction` — local player's faction.
- `CampaignRoot.DiplomacyManagerContext` → `CcoCampaignDiplomacyManager` (`PendingNegotiationList`, `SentNegotiationList`).
- `CcoCampaignNegotiation.TargetFactionContext`.
- Dev button in offers panel: `RunCLIMultiplayer("cai_force_deal_acceptance true")` — forces AI to accept deals. Possibly useful for MVP "AI always accepts" testing.

Item (`CcoCampaignAncillary`) fields used by the character panel (`character_details_panel_details.twui.xml`):

| Field | Meaning |
|---|---|
| `Name`, `OnscreenName` | display name |
| `AncillaryRecordContext` | DB record: `.Key`?, `.RarityName`, `.UniquenessRecordContext.Max`, `.CategoryContext.Category`, `.AncillarySetContext`, `.CanBeDestroyed` |
| `FrameState` | rarity frame state for `equipment_items_frame` |
| `IconState` | icon state |
| `CharacterEquippedToContext` | character who has it equipped (`.Name`, `.ImageCardPath`, `.IsAgent`); invalid if unequipped |
| `HasSeen` | "new" marker |
| `SalvageValue` | salvage value |
| `FactionContext` | owning faction |

UI commands seen (context commands, not Lua): `EquipToCharacter(character, ancillary)`, `RemoveAncillary`, `SalvageAncillaries(list)`, `DevAddAllAncillaries`.

## 5. Script API notes (DOC — chadvandy WH3 docs)

Item transfer (campaign model side):

```lua
cm:force_add_ancillary(character, ancillary_key, force_equip, suppress_event_feed)
cm:force_remove_ancillary(character, ancillary_key, remove_to_pool, suppress_event_feed)
cm:add_ancillary_to_faction(faction, ancillary_key, suppress_event_feed)
cm:force_remove_ancillary_from_faction(faction, ancillary_key)
```

Multiplayer:
- `CampaignUI.TriggerCampaignScriptEvent(...)` → `UITrigger` event received by all clients.
- `cm:progress_on_all_clients_ui_triggered(...)` — wait until all clients sent the same UI event.
- `cm` "multiplayer queries" — run a query on the owning client and broadcast the result.
- Docs warn: UI events are not synchronised with the model; **never change model state directly from a UI callback** in MP.

**Warning (DOC):** `cm:force_remove_ancillary_from_faction(faction, key)` removes **all instances** of that key — from every character and from the pool. There is no documented call to remove exactly one pooled copy. `force_remove_ancillary(character, key, remove_to_pool, ...)` targets one character's copy.

Docs: https://chadvandy.github.io/tw_modding_resources/WH3/

## 6. Bugs found in code review (2026-10-24)

### 6.1 Double `UIComponent()` wrap — likely cause of both hard freezes (HYPOTHESIS, strong)

`find_uicomponent(...)` returns a UI component object, not an address (vanilla uses the result directly: `uic:Visible()`).
Our code wraps it again:

- `items_diplomacy_trading.lua:140` `UIComponent(existing)` — runs on **second click** of the action button.
- `items_diplomacy_trading.lua:192` `UIComponent(panel)` — runs on **Cancel / OK**.

The first click works because `CreateComponent` returns a real address. Matches all observed freezes.

Rule: `UIComponent(x)` only for raw addresses (`CreateComponent`, `CopyComponent`, `Find(i)`). Never for `find_uicomponent` results.

### 6.2 ~~Duplicate component name~~ — WRONG, retracted

Claude assumed `CreateComponent(name, layout)` creates a wrapper named `name` plus the layout's top component inside it.
Context Viewer (user screenshot, 2026-10-24) shows **only one** `trade_magic_items` directly under `subpanel_group`, with `offer_demand_parent`, `small_bar`, `title_plaque`, `both_buttongroup`, `label_trade_magic_items_rules` as its children.

**PROVEN:** `parent:CreateComponent(name, layout)` creates the layout's top component itself, named `name`. No extra wrapper. No rename needed.
(Vanilla has `trade_regions > diplomacy_hud_trade_regions` because there the holder comes from `diplomacy_hud.twui.xml` and the layout is loaded into it by `ComponentCreator`.)

## 7. Roadmap (agreed 2026-10-24)

Decisions:
- Feasibility experiments run **before** the polished item list.
- MVP: player-to-player trade in MP. **AI always accepts** item terms in the MVP (no valuation) — also lets us test against AI in single-player. Real AI valuation after MVP.
- Rules: one testable block at a time; docs updated after each test; experiment code lives in a separate debug file, never in the main Lua.

| Phase | Content | Tested by | Status |
|---|---|---|---|
| 1. UI shell | Freeze fix (6.1), open/close mimicking vanilla (§4.2 table), Cancel/OK close, small logger capturing the vanilla close transition | user, SP | **done** (0.1.0) |
| 2. Experiments (throwaway, SP only, player vs AI) | **E1** list items ✅. **E2** transfer by script ✅ (works; race lock `faction_set` is the wall → mirror items, variant D, accepted; modders asked). **E3** which events fire on native deal propose/accept/decline, what they expose; can a deal with only custom terms be proposed at all. | user | E1/E2 done, **E3 open** |
| 3. Item list UI | ✅ native rows both columns, category sort, checkboxes give item ids, holders incl. AI portraits (0.2.8), filter (unique, unique_fusable, rune, scrap, non-transferrable), selection state / pending trade + ✓ greyed (0.3.0), no drag (0.3.1). Not done by decision: marking race-locked items | user | **done** (0.3.1) |
| 4. Deal integration | Spike S1 ✅ proved the AI score can be pushed (effect bundle on the proposer, §7.0.8). Next: E3a carrier payment by script, E3b accept/decline events; then "Magic Items" row in Your Offers/Demands, item value bundle, execute on native acceptance | user | **next** (see `00_START_HERE.md` §7) |
| 5. MP MVP | Player-to-player trade, synced. **First MP test happens here**, with items picked from the real list — no MP-only experiments before. | user + tester | |
| 6. AI | Valuation (equipped items worth more to owner), accept/decline | | after MVP |
| 7. Polish | ~~Button survives action-list rebuild~~ (done early, §7.0.9), silence click sound on item entries, tooltips, localisation, edge cases (sort and unique filter done in Phase 3) | | |

Changes by user (2026-10-24): fix only what blocks testing. Button rebuild bug and the unique filter moved to Polish. No separate MP experiment (old E4) — MP is first tested at the MVP.

### 7.0 Phase 1 — implemented in Lua 0.1.0 (2026-10-24), awaiting in-game test

Changes in `items_diplomacy_trading.lua`:
- Freeze fix: no `UIComponent()` around `find_uicomponent` results.
- `ad_open_trade_magic_items_panel`: create + two-column setup only once; then `offers_panel` hidden, `subpanel_group` visible, panel visible.
- `ad_close_trade_magic_items_panel` (✗ and ✓): panel hidden, `subpanel_group` hidden, `offers_panel` visible.
- Debug logger `ad_log_ui_state(tag)`: logs `visible` (own flag), `on_screen` (`Visible(true)`), `state` for `diplomacy_dropdown`, `offers_panel`, `subpanel_group` and every `subpanel_group` child. Fires immediately and 0.1 s after: our open / cancel / ok, and vanilla `diplomatic_option_trade_regions` / `ok_trade_regions` / `cancel_trade_regions`. Log lines start with `[MAGIC_ITEMS_DIPLOMACY 0.1.0]` and blocks are framed by `---- UI STATE [...] ----`.

Test checklist:
1. Open our panel → ✗ → open again → ✗ (used to freeze).
2. Open → ✓ → open again → ✓.
3. Vanilla Trade Settlement: open → ✗, then open → tick one settlement → ✓.
4. Send the log blocks. Compare `ours: open` vs `vanilla: open`, `ours: cancel` vs `vanilla: cancel`.

Results (user test 2026-10-24, log `script_log_241026_1403.txt`) — **PHASE 1 DONE**:
- No freezes: open → ✗ → open → ✗ → open → ✓ → open → ✓ all worked; user: "like a native screen". **6.1 PROVEN** as the freeze cause.
- No script errors in the log.
- Our open/cancel/ok produce **exactly the same** visibility as vanilla open/cancel/ok, both immediately and 0.1 s later (game does not undo our changes):

  | | `offers_panel` | `subpanel_group` | holder (`trade_regions` / `trade_magic_items`) | other subpanels |
  |---|---|---|---|---|
  | open | false | true | true | false |
  | ✗ / ✓ | true | false | false | false |

- Vanilla's own handler runs **before** our `ComponentLClickUp` listener (the "immediate" vanilla snapshot already shows the new state).
- All `state` values are unchanged (`NewState`, `panel_smoke_t` = `default`) → no state switches involved, visibility only.

Bonus findings from the same log:
- The game's `[ui]` log channel prints every clicked component with its **full path from root**, position, size, state, priority — free debugging aid.
- Vanilla Trade Settlement rows are named by a number (`list_box > 546 > checkbox`, likely the region id). Clicked checkbox state = `selected_hover`.

### 7.0.1 E1 — list items (throwaway script, awaiting test)

File: `script/campaign/mod/items_diplomacy_trading_debug.lua` (delete after E1/E2/E3 are done).
On click of our action button it logs (prefix `[MAGIC_ITEMS_E1 E1.1]`):
- probes `PlayersFaction.Name`, `.FactionRecordContext.Key`, `.AncillaryList.Size`;
- finds the target faction by trying `CurrentNegotiatingFactionContext`, then `DiplomacyManagerContext.CurrentNegotiatingFactionContext`;
- for both factions, the magic-items-filtered list (max 60 rows): key, name, category, rarity name, frame state, uniqueness max, equipped-by name.
Every call is wrapped in `pcall`, so a wrong field name logs an error instead of breaking anything.

Questions E1 answers: does `get_context_value` work on `CcoCampaignRoot` in campaign; which expression gives the target faction; which field identifies "unique/legendary"; can we see equipped state of the *other* faction's items.

Results (log `script_log_241026_1440.txt`, Neferata vs Disciples of Hashut) — **E1 DONE, all PROVEN**:
- `common.get_context_value("CcoCampaignRoot", "", expr)` works in campaign, returns real Lua strings/numbers. Took < 0.1 s for ~30 items.
- **Target faction = `CurrentNegotiatingFactionContext`** (first candidate worked). `.FactionRecordContext.Key` gives the faction key for `cm:get_faction()`.
- Player: 36 ancillaries total, 15 magic items after the vanilla filter. Target: 13 total, 12 magic items.
- Working fields: `AncillaryRecordContext.Key`, `Name` (localised), `AncillaryRecordContext.CategoryContext.Category` (weapon/armour/talisman/enchanted_item/arcane_item), `AncillaryRecordContext.RarityName` (localised with colour tags), `AncillaryRecordContext.UniquenessRecordContext.Max`, `CharacterEquippedToContext.Name` (`nil` when unequipped).
- `FrameState` → `nil` (not a field of `CcoCampaignAncillary`). Not needed.
- **Rarity by `UniquenessRecordContext.Max`** (language-independent, use this, not `RarityName`):

  | Max | Rarity | Tradeable |
  |---|---|---|
  | 50 | Common | yes |
  | 100 | Uncommon | yes |
  | 150 | Rare | yes |
  | 199 | Crafted | yes |
  | 200 | Unique (purple) | **no** |

- ~~Equipped state is visible for the other faction too.~~ **WRONG (user, 2026-10-24):** `CharacterEquippedToContext` is `nil` for items an **AI** character has equipped (Empire AI: Beast Slayer worn by a lord, log says `nil`). It is only filled for the player's own characters (maybe other humans too — unverified). The AI items are still listed in `AncillaryList`.
  → Equipped detection for other factions must use the **model**: iterate `faction:character_list()` and check `character:has_ancillary(key)`. Debug script E2.2 logs this as `model_holders=` next to the context value, to verify.
  **PROVEN (log `script_log_241026_1522.txt`, Aislinn vs Reikland):** `model_holders` finds AI holders correctly (Beast Slayer → `wh_main_emp_karl_franz`). For the player both sources agree.

More from the same log:
- Context gives **per-copy** holder only for the player (3 Emerald Collars → 3 different names). The model gives **per-key** holders (`has_ancillary` = yes/no per character). Copies of one key are interchangeable, so the trade unit can be **(key, holder-or-pool)**: e.g. Reaver Bow = 2 copies, 1 worn by Eltharion, 1 in pool.
- AI factions here wore **everything** (Reikland: 34 items, 0 in pool). Trading with AI will nearly always mean taking an item off an AI character.
- **`Max = 199` = Crafted** (user; earlier log showed `RarityName=[[col:ancillary_crafted]]Crafted[[/col]]`). Crafted items have no race restrictions → **tradeable** (decision 2026-10-25).
- **Rarity decision (2026-10-25): use `AncillaryRecordContext.UniquenessRecordContext.Key`** (`wh_main_anc_group_unique` = not tradeable; others tradeable). Proven in E2.4.
- Rarity identification (background): `RarityName` is localised display text (would read differently in a Russian game). Its colour tag (`ancillary_unique`, `ancillary_rare`, `ancillary_uncommon`, `ancillary_crafted`; Common has no tag) is language-independent but is formatting, not data. E2.4 probes `UniquenessRecordContext.Key` — if it returns readable keys (unique/crafted/…), use that: readable **and** language-independent. Fallback: `Max` number.
- Some unique items return unresolved names like `{{tr:...}}` from `Name`, while the character panel shows them correctly. The panel uses `OnscreenName` (7 bindings in the layout) → E2.4 logs `OnscreenName` to compare.
- Model holders are per **key**: `has_ancillary` says whether a character wears that item, not which copy. Debug output repeats the same `model_holders=4` on all 4 copies. Since copies are identical, the trade unit is built from the model: one unit per holder + (total − holders) pool units. E.g. Armour of Silvered Steel ×4 → Karl Franz, Witch Hunter, Captain, Master Engineer.
- AI factions *can* have pooled items (Hashut save) and fully-equipped ones (Reikland save) — both transfer paths are needed.
- **Performance:** ~5 context calls per item, 60 items took ~0.6 s (~2 ms per call). Player faction had 141 magic items. The real UI must use few calls per item, or let the native `List` callback build rows.
- **Duplicates exist**: player has two `wh3_dlc29_anc_talisman_wristbands_of_black_gold`, one in the pool, one equipped. Item key alone does not identify one copy → UI rows must track instances (row index / `CcoCampaignAncillary<id>`), and transfer logic must handle "which copy".
- Character names come localised (game language), e.g. `Ванесса Ванхал`.

### 7.0.2 E2 — transfer by script (throwaway, awaiting test)

Same debug file, now `E2.2` (log prefix `[MAGIC_ITEMS_E1 E2.2]`). Trigger: ✓ of our panel. **Changes the campaign — throwaway save.**
E2.2: equipped copies are counted on the model side (`has_ancillary`) for both factions, because the context field is blind to AI equipment. E1 output now adds `model_holders=<count> [subtype#cqi, ...]` per item.
Picks items from live data before changing anything, then runs:

| Test | What | Calls | Expected pick (Neferata vs Hashut) |
|---|---|---|---|
| T1 | target single copy → player (pooled preferred; else taken off the AI character, E2.3) | pooled: `force_remove_ancillary_from_faction(target)`; equipped: `force_remove_ancillary(ai_holder, key, false)`; then `add_ancillary_to_faction(player)` | Potion of Healing (Hashut save) / Obsidian Blade off a Witch Hunter (Reikland save) |
| T2 | player equipped single copy → target | `force_remove_ancillary(holder, key, false)` + `add_ancillary_to_faction(target)` | Obsidian Blade (Ванесса Ванхал) |
| T3 | player key with pooled + equipped copies: move only the pooled one | `force_remove_ancillary_from_faction(player)` (removes all), `force_add_ancillary(holder, key, true)` for each holder, `add_ancillary_to_faction(target)` | Wristbands of Black Gold |

For each test it logs copy counts (total / equipped) for both factions BEFORE and 1 s AFTER.

Checks for the user in game: item appears in the receiver's Magic Items list; T2 holder lost the item; T3 holder still wears the Wristbands, player pool lost one copy; event feed messages; nothing odd after end turn / save + load.

Results (log `script_log_251026_0827.txt`, E2.4, Neferata vs Disciples of Hashut, 2026-10-25):

| Test | Item | Player before → after | Target before → after | Verdict |
|---|---|---|---|---|
| T1 | Potion of Healing, **worn by AI** Sorcerer-Prophet (context had said "unequipped") | 0 → 1 (pool) | 1 (worn) → 0 | **WORKS** — taking off AI character + add to player pool |
| T2 | Obsidian Blade worn by Ванесса Ванхал | 1 (worn) → 0 | 0 → 1 (pool) | **WORKS** — taking off player character + add to AI pool |
| T3 | Wristbands of Black Gold, spare pool copy | 2 (1 worn) → 1 (worn) | 0 → **0** | **PARTLY**: remove-all + re-equip worked (Ванесса still wears hers, user confirmed); but **target never received the copy — item destroyed** |

- `add_ancillary_to_faction` seems to **silently do nothing** for Wristbands → Hashut. HYPOTHESIS: Wristbands of Black Gold is a Neferata DLC (dlc29, Lahmian) item restricted to certain factions/cultures/agents; Obsidian Blade and Potion of Healing are generic. Needs DB check (`ancillaries_tables` not in the extracted set) and/or an in-game test.
- Consequence for the real transfer: **check the receiver can own the item before removing it from the giver, and verify after**. Never remove first and hope.
- Model changes are visible in the context system 1 s later (AFTER lines correct). Immediate visibility not yet tested.
- `UniquenessRecordContext.Key` works and is a **DB key**, language-independent: `wh_main_anc_group_unique`, `_rare`, `_uncommon`, `_common` (crafted key not yet seen, probably `wh_main_anc_group_crafted`). **Use this for rarity.**
- `OnscreenName` on `CcoCampaignAncillary` → `nil` (the panel's 7 `OnscreenName` bindings are on another object). Name issue only seen in the Aislinn save; revisit later.

Second run (log `script_log_251026_0849.txt`): user had un-equipped Vanessa's Wristbands, so both copies were in the pool → T3 needs one worn copy → **T3 SKIPPED** (that's why nothing disappeared; not a game quirk). T1/T2 worked again. The AFTER read of the target failed (`could not read items of CurrentNegotiatingFactionContext`) — diplomacy was closed within 1 s; T2's "target 0" there is a read failure, not a lost item.

**E2 DONE** (2026-10-25). E2 disabled in the debug script (`E2_ENABLED = false`).

### 7.0.3 Item restrictions — `db/ancillaries_tables` (DOC, extracted 2026-10-25)

Relevant columns: `key, transferrable, unique_to_world, unique_to_faction, legendary_item, category, uniqueness_score, can_be_stolen, can_be_destroyed, faction_set`. 2874 rows.

**Cause of the lost Wristbands — CONFIRMED by data:**
```text
wh3_dlc29_anc_talisman_wristbands_of_black_gold  faction_set = anc_set_exclusive_vampire_counts
wh_main_anc_weapon_obsidian_blade               faction_set = all
wh_main_anc_enchanted_item_healing_potion       faction_set = all
```
Chaos Dwarfs are not in the vampire set → `add_ancillary_to_faction` silently refused it.

`faction_set` distribution: `all` 628, the rest are race/culture-exclusive sets (`anc_set_exclusive_<race>`, `anc_set_vampire_counts_nagash`, `anc_set_multi_tzeentch_daemons`, …).
→ **Rule: an item can go to a receiver only if the receiver is in the item's faction set.** Model check available: `faction:is_contained_in_faction_set(set_key)`. Open question: how to read the item's `faction_set` at runtime (E2.5 probes `AncillaryRecordContext.FactionSetContext.Key` / `.FactionSetKey` / `.FactionSet`).

`transferrable = false`: 1141 rows = all 774 mounts, 37 followers and 330 magic items — of those 320 are unique (200/198), plus a few special ones (e.g. `the_vial_of_hashut` 95, dwarf runes 35, hidden Cathay/Ogre items 80). → **Exclude `transferrable = false` items from trading** (E2.5 probes `Transferrable` / `IsTransferrable`). Note: some uniques ARE transferrable (e.g. Tomb Kings, Norsca uniques) — they are still excluded by the rarity rule.

`unique_to_world`, `unique_to_faction`, `legendary_item`: always `false` in vanilla — ignore.

`db/ancillary_uniqueness_groupings_tables` (rarity groups):

| group_key | score range | ui_state (frame) | fusable | Tradeable? |
|---|---|---|---|---|
| `wh_main_anc_group_common` | 35–50 | common | yes | yes |
| `wh_main_anc_group_uncommon` | 80–100 | uncommon | yes | yes |
| `wh_main_anc_group_rare` | 130–150 | rare | yes | yes |
| `wh2_dlc17_anc_group_rune` | 151 | crafted | no | yes? (runes — decide) |
| `wh_main_anc_group_unique_fusable` | 198 | legendary (purple) | yes | **no** (purple) — confirm |
| `wh_main_anc_group_crafted` | 199 | crafted | no | yes |
| `wh_main_anc_group_unique` | 200 | legendary (purple) | no | **no** |
| `wh_main_anc_group_scrap`, `_scrap_upgraded` | -999 / -998 | crafted | yes | ? (scrap — decide) |

**Decisions (user, 2026-10-25):**
- Tradeable groups: common, uncommon, rare, crafted. **Not shown / not traded:** unique, unique_fusable, rune, scrap.
- Exclude `transferrable = false` items (mostly lord legendaries and mounts).
- The race restriction (`faction_set`) is **not acceptable** as a limit — e.g. Dwarf crafted items must be tradeable to anyone. A workaround is required.

**Workaround options for `faction_set`:**

| # | Idea | Risk |
|---|---|---|
| A | `cm:force_add_ancillary(char, key, force_equip = true)` — docs: "bypass any cooldowns or pre-conditions". Maybe also bypasses `faction_set`. Then optionally move to pool with `force_remove_ancillary(char, key, true)`. | Item may be stuck on the character / unusable after un-equip; game may strip it later. **Testing in E2W.** |
| B | DB patch in our pack: override `ancillaries_tables` rows → `faction_set = all`. | Global gameplay change: affects random drops, AI equipping, other mods editing the same rows. Last resort. |
| C | Patch faction set membership (`faction_set_items_tables`, not extracted) | Same global side effects as B. |

There is no way to write a custom "item giver": items are engine objects; script can only use the documented add/remove calls or change DB data.

### 7.0.4 E2W — force-add bypass experiment (awaiting test)

Debug file `E2.6`, trigger ✓ (E2 itself is disabled). Hardcoded for the Neferata vs Hashut save:
- **W1** Furnace Blast Gem (`anc_set_exclusive_chaos_dwarfs`, worn by an AI Bull Centaur) → Neferata via `force_add_ancillary(leader, key, true)`; if it arrives, remove from the AI; at 2 s move it to Neferata's pool.
- **W2** Wristbands of Black Gold (`anc_set_exclusive_vampire_counts`) → Astragoth via force-add (copy, not removed from player); at 2 s move to Hashut's pool.
- Logs `is_contained_in_faction_set` and `can_equip_ancillary` before, and copies/holders at 0 s, 1 s, 3 s.

User checks in game: Furnace Blast Gem in Neferata's pool? Can a vampire character equip it (drag)? Still there after end turn and save/load?

Results (log `script_log_251026_1050.txt`, 2026-10-25) — **Workaround A FAILED**:
- `force_add_ancillary(leader, key, force_equip = true)` does **not** bypass `faction_set`: neither item arrived (0 copies at 0 s, 1 s, 3 s). Nothing was lost — W1 only removes from the AI after arrival.
- Model checks work: `faction:is_contained_in_faction_set(set)` → false/false as expected; `character:can_equip_ancillary(key)` → false for both. **Use these as pre-checks before any transfer.**
- Context probes: `AncillaryRecordContext.Transferrable` **works** (true/false); `UniquenessRecordContext.UiState` **works** (`legendary`, `rare`, `uncommon`, `common` = frame state). `IsTransferrable` → nil. `FactionSetContext.Key`, `FactionSetKey`, `FactionSet` → nil (faction set key of an item not found in context yet).

Tradeable vanilla items by restriction (`transferrable = true`, magic categories, from `ancillaries_tables`):

| Group | `faction_set = all` | race-restricted |
|---|---|---|
| common | 44 | 136 |
| uncommon | 28 | 314 |
| rare | 11 | 168 |
| crafted | 33 | 19 |
| **total** | **116** | **637** |

→ Race restriction is the norm (85 % of tradeable items). Without a workaround, cross-race trading is basically impossible.

Items are defined in 4 tables: `ancillaries_tables`, `ancillary_info_tables`, `ancillary_to_effects_tables` (effects incl. abilities, e.g. `wh3_dlc23_item_ability_enable_spell_hell_hammer`), `ancillary_ownership_content_pack_junctions_tables` (DLC ownership) + loc `text/db/ancillaries__.loc`.

**Remaining workaround options:**

| # | Idea | Pros | Cons |
|---|---|---|---|
| B | **Open sets**: pack overrides `ancillaries_tables` rows of tradeable items → `faction_set = all` | Simple, one generated table; original items keep scripts/effects | Global: random loot and AI equipping become cross-race; conflicts with mods editing the same rows |
| D | **Mirror items**: generated copy per restricted item (`<key>` + suffix) with `faction_set = all`, `randomly_dropped = false`, same effects/info/loc. Trade delivers the mirror when the receiver is outside the set | No change to vanilla loot or AI; only traded items are affected | Generator needed (~637 items × 3–4 tables + loc); scripted behaviour keyed on the original key won't fire for mirrors; items from other mods not covered; DLC ownership edge cases |

**User decision (2026-10-25): variant D (mirror items) is acceptable**, but more tests first. API reference collected in `02_item_api_reference.md`.

### 7.0.5 E2R — same-race control test (awaiting test)

Debug file `E2.7`, trigger ✓ (E2 and E2W disabled). Gives a **copy** of the vampire-only Wristbands of Black Gold to the faction open in diplomacy with the normal `add_ancillary_to_faction`, and logs subculture, `is_contained_in_faction_set`, `can_equip_ancillary`, and copies/holders before and 1 s after.
Run it with **another Vampire Counts faction** (not Vampire Coast — different set). Expected if the race set is the only blocker: `in set = true`, copy arrives. (Chaos Dwarfs: `false`, nothing arrived.)

Results (log `script_log_251026_1134.txt`, Neferata → Sylvania `wh_main_vmp_schwartzhafen`, 2026-10-25) — **CONFIRMED**:
- subculture `wh_main_sc_vmp_vampire_counts`, `is_contained_in_faction_set(anc_set_exclusive_vampire_counts) = true`, Vlad `can_equip_ancillary = true`.
- Copy arrived in Sylvania's pool: 0 → 1 copies.
- Same call, same item → Chaos Dwarfs: nothing arrived. **The block is purely the item's `faction_set` vs the receiver faction.**
- Repeated with 3 more factions (log `script_log_251026_1141.txt`):

  | Target | Subculture | In set | Leader can equip | Copies before → after |
  |---|---|---|---|---|
  | Disciples of Hashut | `wh3_dlc23_sc_chd_chaos_dwarfs` | false | false | 0 → 0 |
  | Bonerattlaz (Azhag) | `wh_main_sc_grn_greenskins` | false | false | 0 → 0 |
  | Caravan of Blue Roses (Ghorst) | `wh_main_sc_vmp_vampire_counts` | true | true | 0 → **1** |

  5 of 5 runs match the pre-checks exactly. The pre-checks `is_contained_in_faction_set` / `can_equip_ancillary` predict the outcome correctly.

Still open before building mirror items: will a mirror with `faction_set = all` be **equippable** by a foreign race? Equip may have extra rules (`ancillaries_included_agent_subtypes_tables`, `ancillaries_categories_faction_junctions_tables`, `ancillary_to_included_agents_tables`). → Next test: one hand-made mirror item.

Mirror item = rows needed (Furnace Blast Gem as example):

| Table | Vanilla row | Mirror |
|---|---|---|
| `ancillaries_tables` | `wh3_dlc23_anc_enchanted_item_furnace_blast_gem`, faction_set `anc_set_exclusive_chaos_dwarfs` | same columns, new key, `faction_set = all`, `randomly_dropped = false` |
| `ancillary_info_tables` | key only | new key |
| `ancillary_to_effects_tables` | 3 effects (walls damage scripted, Hell Hammer spell, wallbreaker) | same effects, new key |
| `ancillary_ownership_content_pack_junctions_tables` | `wh3_dlc23_chaos_dwarfs` | probably copy (DLC ownership) — decide |
| loc `ancillaries__.loc` | `ancillaries_onscreen_name_<key>`, `ancillaries_colour_text_<key>`, `ancillaries_explanation_text_<key>` | same texts, new key |

Open question for both: is `faction_set` the **only** blocker, or can equip also be blocked by agent/category rules (`ancillaries_included_agent_subtypes_tables`, `ancillaries_categories_faction_junctions_tables`)? → validate on **one item** first.

`ui_state` is exactly the frame image suffix (`equipment_items_frame_legendary` etc.) → row frame = `UniquenessRecordContext.UiState` if exposed (probed in E2.5).

### 7.0.6 Phase 3 — item list UI, step 3.1 (awaiting test)

Approach 1 chosen (user, 2026-10-25): native list. Requirements from user: the **checkbox** selects an item for trade; **clicking the item itself must do nothing**.

Findings while building:
- Donor rows use templates `ui/templates/ancillary_entry.twui.xml` and `checkbox_toggle.twui.xml` (user extracted them; no further nested templates). Instances in the donor file store only **overrides** (`state_uniqueguids`, `callbacks_with_context`, `override_images`) on top of the template.
- Our panel's old Trade Settlement checkbox was already a `part_of_template` instance of `checkbox_toggle` and rendered fine → **template instances work in layouts created with `CreateComponent`**. The earlier crash in the handoff (§9) was most likely something else (probably the double `UIComponent()` wrap).
- `uicomponent:SetContextObject(cco("<CcoType>", "<id>"))` and `uicomponent:GetContextObjectId("<CcoType>")` are documented → Lua can point native lists/rows at any faction/item.

What was built (script `scratchpad/build_item_list.ps1`, backup of the previous XML saved next to it):
- In `diplomacy_hud_trade_magic_items.twui.xml`, the placeholder row (`template_magic_item_list_item` + `checkbox`) was replaced by
  `list_box > magic_items_list > template_item_holder > [checkbox_toggle, ancillary_entry > (dy_label, dy_name, magic_effect, equipment_items_frame/dy_icon, cooldown, assigned_char_portrait/forces_icon, dy_set_icon)]`, copied from the character panel with new GUIDs (67).
- `magic_items_list`: native `List` callback on `CcoCampaignFaction`, **vanilla filter for now** (our rarity/transferrable filter comes in step 3.4), `ContextInitPlayerFaction` kept.
- Removed: holder's visibility setter (pointed at the character panel's `global_pool`); checkbox `ContextSelectableItem`/`ContextCommandGiverOnContextSet` → replaced by plain `Checkbox` callback; entry `ContextSlotItem` (click/drag), `ContextCommandMouseOn` (mark as seen), `ContextInactiveStateSetter`, `TopmostWhenDraggingCallback`. Kept: tooltip, rarity frame, icon, name, category, equipped portrait.
- Not copied: `tx_assigned`, `icon` (hidden extras of the donor checkbox), `icon_new` ("new" marker).

Lua 0.2.0:
- On every open: right column's `magic_items_list` gets `SetContextObject(cco("CcoCampaignFaction", <target cqi>))`; left column stays on the player via XML.
- Logs each column's faction context, row count and first 3 rows (name + `CcoCampaignAncillary` id) 0.2 s after opening.
- Logs checkbox clicks inside our panel: row, item id, checkbox state.
- Debug experiments E2/E2W/E2R all disabled.

Test checklist:
1. Left column shows your magic items (icons, rarity frames, names, scroll).
2. Right column shows the **other faction's** items (expected risk: it may show yours, or be empty).
3. Hover an item → tooltip. Click the item itself → nothing happens.
4. Click checkboxes → tick/untick; log shows the item id.
5. Open/close several times and with different factions — no freeze; right column changes with the faction.

Results (user + log `script_log_251026_1320.txt`, 2026-10-25) — **step 3.1 WORKS** ("for the first try, it is magnificent"):
1. Left column: player's items with icons, rarity frames, category, name, equipped portrait; fits the column; scroll works. ✅
2. Right column: **target's items shown** (Hashut, Bretonnia, Dwarfs) — `SetContextObject(cco("CcoCampaignFaction", "<cqi>"))` works. ❌ But many **empty rows (checkbox only)** above the target's items.
3. Clicking an item does nothing; tooltips work. ✅
4. Checkboxes tick/untick. Log: `row=CcoCampaignAncillary1310 item=1310 state=selected_hover`. ✅ → **row name = `CcoCampaignAncillary<id>`, `GetContextObjectId("CcoCampaignAncillary")` = item instance id, ticked state = `selected*`**.
5. Not tested yet.

Other log facts:
- `list:GetContextObjectId("CcoCampaignFaction")` returns the **faction key** (`wh3_dlc29_vmp_neferata`), although we set the target via cqi and that worked too.
- `list_offers` had 16 children for 15 items: 15 rows + the `template_item_holder` template.
- Panel is re-created when diplomacy is reopened, but reused when switching target inside one diplomacy session (no "Creating panel" line).
- Bug in our logger: `tostring(uic:GetContextObjectId(...))` throws "value expected" when the id is unset (function returns *no value*, not nil). Store in a local first.

**Empty rows — cause:** `list_demands` is a `CopyComponent` of `list_offers` made right after creation, when the native list had already filled the left column with the player's 15 rows. The copied rows keep player contexts; after `SetContextObject(target)` the native list adds the target's rows but leaves the copies, whose `ancillary_entry` hides (`IsValidContext` false) → checkbox-only rows.
**Sorting (user, 2026-10-25):** no sort dropdown/button; items always sorted by category, which is all we need.
Vanilla sort options (`character_details_panel_details.twui.xml`, `sort_func` per dropdown entry): rarity `AncillaryRecordContext.UniquenessScore`, category `AncillaryRecordContext.CategoryContext.SortOrder`, name `Name`, unassigned `IsContextValid(CharacterEquippedToContext)`, available `SelectedOrContainedCharacter.CanEquipAncillary(this)`, fusable `IsFusable && AncillaryRecordContext.CanBeDestroyed`, salvageable `AncillaryRecordContext.CanBeDestroyed`.
Our list (XML, `sort_desc` kept): `sort_func = AncillaryRecordContext.UniquenessScore - AncillaryRecordContext.CategoryContext.SortOrder * 1000` → categories in vanilla order, rarest first inside each category (needs in-game check; if arithmetic is not supported, fall back to plain `CategoryContext.SortOrder`).

**Test of 0.2.1 + sort (log `script_log_251026_1355.txt`):** sorting by category works ✅. Empty rows still there ❌. Target always correct when switching factions (as far as visible).
- `Removed 0 copied item rows` → at copy time `list_offers` had no item rows yet; the "copied rows" theory was **wrong**.
- Clue: a click on row `CcoCampaignAncillary1184` gave `item=nil`, the next click `item=1184` → two rows named after the *player's* item 1184, one of them in the right column without context.
- Child counts = 1 template + 15 player rows + target items (Hashut 28 = 1+15+12, Norsca 22 = 1+15+6, Imrik 18 = 1+15+2). When switching target, the previous target's rows are replaced correctly; the 15 player-named rows stay.
- **New explanation:** the copied list also has `ContextInitPlayerFaction`, which fills it with the player's items on a later frame, after our `SetContextObject(target)`. Those rows stay without valid context → empty.
- **Fix (Lua 0.2.2 + XML):** `ContextInitPlayerFaction` removed from `magic_items_list`; Lua binds **both** columns (`list_offers` → local player faction, `list_demands` → target) on every open. Copy-cleanup code removed. Logger now counts rows with/without item context and lists the first 6 child names, at 0.2 s and 1 s.

**Test of 0.2.2 (log `script_log_251026_1415.txt`): empty rows FIXED ✅, switching factions works ✅.** Removing `ContextInitPlayerFaction` and binding both lists from Lua was the right fix.

**Equipped-by portraits for the other faction (Lua 0.2.3, awaiting test):** as expected, the native portrait only works for the player's own characters. The portrait's visibility/image setters only refresh on `CampaignAncillaryAssigned`, so Lua fills them 0.2 s after binding:
- group right-column rows by item key (`common.get_context_value("CcoCampaignAncillary", "<item id>", "AncillaryRecordContext.Key")`),
- holders per key from the model (`has_ancillary`), handed out to that key's rows in list order; leftover rows = pooled copies (portrait hidden),
- portrait image from `common.get_context_value("CcoCampaignCharacter", "<cqi>", "ImageCardPath")`, tooltip = character `Name` (untested object id format), `SetImagePath(image, 0)`, `SetVisible(true)`.
- Logs `list_demands: holder portraits set=N, in pool=M`.
This row → holder assignment is also what the trade itself will need (which character loses which copy).

Result 0.2.3 (log `script_log_251026_1434.txt`): ❌ no portraits — `holder portraits set=0, in pool=0`: **`common.get_context_value("CcoCampaignAncillary", "<id>", "AncillaryRecordContext.Key")` returns nothing**, so no row got a key. The row ids themselves are fine (`CcoCampaignAncillary1422 = 1422`). Looking up an item object by type + id is not how this works (or needs other construction data).
**P1 results (log `script_log_251026_1559.txt`, Hashut and Karaz-a-Karak) — PROVEN:**

| Method | Result |
|---|---|
| a) `get_context_value("CcoCampaignAncillary", "<id>", expr)` | **nil** (any field) |
| b) `row:GetContextObject("CcoCampaignAncillary"):Call("AncillaryRecordContext.Key")` | **works** → `wh3_dlc23_anc_weapon_chd_dagger_of_malice` |
| c) `AncillaryList.FirstContext(CQI/Cqi/Id/ObjectId/AncillaryCqi == id)` | nil for all |
| d) `dy_name` `GetStateText()` | works (localised name) |
| e) `get_context_value("CcoCampaignCharacter", "<cqi>", "Name" / "ImageCardPath")` | **works** → `Astragoth Ironhand`, `ui/portraits/units/no_culture/chd_astragoth_ironhand_0.png` |
| e3/e4) `CharacterList.FirstContext(CQI == cqi).ImageCardPath`, `FactionLeaderContext.ImageCardPath` | work |

Rules learned:
- **To read a row's item, use the cco stored on the row and `cco:Call(expression)`.** `get_context_value` with an explicit object id works for characters (`CcoCampaignCharacter` + cqi) and factions, but **not** for `CcoCampaignAncillary`.
- `CQI` is a valid field on characters inside context expressions.

Lua 0.2.4: `ad_mark_item_holders` reads the key with `cco:Call`. Debug P1 and E1 dump disabled.

Result 0.2.4 (user, 2026-10-25): ✅ **portraits of AI holders show** (Astragoth on Black Hammer and Stone Mantle, others on their items). ❌ Tooltip reads "This item or follower is currently assigned to ." with no name — the portrait's native `ContextTooltipSetter` (`Format(Loc("ancillary_assigned"), CharacterEquippedToContext.Name)`) runs on hover and overwrites our `SetTooltipText`. Names were fine in the player's column (native).

Fix (Lua 0.2.5 + XML, awaiting test):
- XML: the portrait's `ContextTooltipSetter` now uses `self.GetProperty("ad_tooltip")` (same callback id, so it overrides the template's setter rather than relying on removal).
- Lua sets `portrait:SetProperty("ad_tooltip", text)` with `text = common.get_context_value("CcoCampaignCharacter", "<cqi>", 'Format(Loc("ancillary_assigned"), Name)')` — the same localised sentence, with the name.
- Result 0.2.5 (user): ✅ player column names, ❌ opponent still "assigned to ." → our instance setter was ignored.
- **Cause — template override rule (strong HYPOTHESIS):** an instance's user property `disable_override<N> = <CallbackId>` tells the game to **ignore the instance's version of that callback and use the template's**. The portrait had `disable_override0 = ContextTooltipSetter`, so the template's native tooltip setter kept running. Also: callbacks simply **removed** from an instance still come from the template (that's why rows can still be dragged — the template's `ContextSlotItem` is inherited). → To change a template callback: keep the same `callback_id` in the instance with a new expression **and** make sure no `disable_override*` names it.
- Fix (Lua 0.2.6 + XML): removed `disable_override0` from `assigned_char_portrait`; same treatment for `forces_icon` (army/agent icon on the portrait): its image and tooltip setters now read `ad_icon` / `ad_tooltip` properties, both `disable_override*` removed, Lua fills them with the native expressions evaluated on `CcoCampaignCharacter` (`GetIfElse(IsAgent, CharacterTypeIconPath, AddDefaultSkinPath("icon_army.png"))`, `Name + "||" + CharacterTypeName`).
- Result 0.2.6 (user + log `script_log_251026_1651.txt`): ❌ still native tooltips on the opponent side (portrait "assigned to .", icon tooltip an empty box = native `Name || CharacterTypeName` with empty values). Our code ran (`holder portraits set=12` / `7`). → **The `disable_override` hypothesis is WRONG / not sufficient**: the template's tooltip setters keep running even with the instance callback changed and `disable_override` removed. Rule that holds: **template callbacks cannot be removed or replaced from the instance in our layout**; work around them at runtime.
- Fix (Lua 0.2.7, awaiting test): our tooltip texts are stored per component address; a `ComponentMouseOn` listener for `assigned_char_portrait` / `forces_icon` re-applies `SetTooltipText` immediately and 0.05 s later, to win over the native setter. (XML property changes from 0.2.6 left in place, harmless.)
- Result 0.2.7 (user, log `script_log_251026_1713.txt`): ❌ still empty on the opponent side. Re-applying `SetTooltipText` on `ComponentMouseOn` (+0.05 s) does not beat the native setter either (it most likely recomputes when the tooltip is actually shown).
- **Final approach (Lua 0.2.8 + new layout, awaiting test):** stop reusing the native portrait for rows it can't fill.
  - New file `ui/campaign ui/ad_holder_portrait.twui.xml` (script `scratchpad/build_holder_portrait.ps1`): copy of the template's `assigned_char_portrait` + `forces_icon` (renamed `ad_holder_portrait` / `ad_holder_icon`), **all callbacks and template links removed**, fresh GUIDs.
  - Rows where the game knows the exact holder (`item:Call("CharacterEquippedToContext.CQI")`, i.e. the local player's copies) stay **fully native**.
  - Other rows: model holders (minus the natively known ones) are handed out per key; for a row with a holder Lua `CreateComponent`s `ad_holder_portrait` inside `ancillary_entry` (docked Center Right like the native one) and sets image (`ImageCardPath`), tooltip (`Format(Loc("ancillary_assigned"), Name)`), icon (`GetIfElse(IsAgent, CharacterTypeIconPath, …icon_army.png)`) and icon tooltip (`Name || CharacterTypeName`). Pooled copies hide it.
  - Log line: `<column>: holders native=N, own portrait=M, in pool=K`.
  - The 0.2.6 XML edits and the 0.2.7 hover listener are reverted/removed; the native portrait XML is vanilla again.
  - **Result 0.2.8 (user, log `script_log_251026_1742.txt`, 2026-10-25): WORKS ✅** — opponent portraits with picture, tooltip "…assigned to Felman Ingersson", corner icon tooltip "Haubr / Great Shaman-Sorcerer (Death)". Player column unchanged.
  - **Step 3.4 + polish (Lua 0.2.9 + XML, awaiting test, 2026-10-25):**
    - List filter extended: `... && AncillaryRecordContext.Transferrable == true && UniquenessRecordContext.Key` not in `wh_main_anc_group_unique`, `wh_main_anc_group_unique_fusable`, `wh2_dlc17_anc_group_rune`, `wh_main_anc_group_scrap`, `wh_main_anc_group_scrap_upgraded`.
    - Race-locked items are **not** greyed out (user: not needed).
    - Row lock: the template gives `ancillary_entry` `moveable="Movable XP"` and `soundcategory="UI_CAM_CLICK_Character_Details_Ancillaries"`. Lua now calls `entry:SetMoveable(false)` + `entry:SetDisabled(true)` on every item row (docs: disabled = no clicks, mouse-over still works). Expected: no drag, no click sound, tooltip + hover sound kept.
  - **Step 3.3 selection state (Lua 0.3.0, awaiting test, 2026-10-25).** User decisions: (1) ✗ Cancel throws away changes since opening, like vanilla; (2) ✓ OK keeps the selection as the "pending trade"; (3) reopening the panel in the same negotiation restores the ticks; (4) another target faction or closing diplomacy clears it; (5) no item limit.
    - Data: `ad_row_info[column][item_id] = { key, holder_cqi }` rebuilt on every open by the holder marking (holder = exact native holder for player copies, assigned model holder for others, nil = pool). Selection = `{ target = faction key, list_offers = {item_id → info}, list_demands = {…} }`; `ad_working` while open, `ad_pending` after OK.
    - Checkbox click → after 0.1 s reads checkbox state (`selected*` = ticked) and adds/removes the item in `ad_working`.
    - Open → stale pending for another target is dropped; `ad_working` = copy of pending; after rows exist, ticks are restored with `checkbox:SetState("selected"/"active")`; selected items no longer listed are dropped.
    - ✓ state: `inactive` unless something is ticked or a pending selection exists (OK with everything unticked clears it). OK click while nothing to do is ignored.
    - Clear on `PanelClosedCampaign` `diplomacy_dropdown` and when `button_ok` confirms a different negotiation partner.
    - Log lines: `Item selected/unselected: …`, `Selection on open: …`, `Pending selection: …` (lists key + holder or pool).
    - UI only: nothing synced or applied to the game yet.
  - **Result 0.2.9 + 0.3.0 (user + log `script_log_251026_1953.txt`):** filter ✅; drag blocked ✅; selection ✅ (select/unselect, pending on OK, restore on reopen, Cancel keeps the old pending, cleared on target change, holders recorded e.g. both Wristbands copies 578 / 1446).
    - ⚠️ Hover sound on item entries is now inconsistent (plays only on the first row hovered, again after hovering a checkbox) — side effect of `SetDisabled(true)`.
    - ⚠️ After reopening with a pending selection and unticking everything, ✓ stays active — by design (OK with nothing ticked clears the pending selection), but it surprised the user. User understood the rule, **kept as is**.
    - Test Lua 0.3.1 (awaiting): `SetDisabled(true)` removed, only `SetMoveable(false)` kept, to learn which call blocks the drag. If drag comes back → restore `SetDisabled` (drag must stay blocked, user requirement). If not → hover sound reliable, click on an item plays a sound but does nothing.
    - **Result 0.3.1 (user, 2026-10-26): `SetMoveable(false)` alone blocks the drag ✅; hover sound consistent again ✅; click on an item plays the click sound (does nothing) — accepted for now.** `SetDisabled(true)` = no click sound but unreliable hover sound → not used. Silencing only the click sound stays a polish item (Phase 7).
  - **Lesson:** when a template-instance component's native callbacks can't do what we need, don't fight them — hide/leave it and add our own callback-free component from a small standalone layout via `CreateComponent`.
- (earlier) Because the XML change affects both columns, holder marking now runs for **both** columns. For the player's rows the exact holder per copy comes from `item:Call("CharacterEquippedToContext.CQI")` (keeps duplicates like the two Wristbands on the right rows); remaining model holders are handed out to the other copies (AI side).

Probe P1 (debug file `P1.1`, on our button, 0.5 s later, first right-column row) tried: (a) type+id again with raw output, (b) `row:GetContextObject("CcoCampaignAncillary")` + `cco:Call(expr)`, (c) `AncillaryList.FirstContext(<field> == id)` with field `CQI/Cqi/Id/ObjectId/AncillaryCqi`, (d) the row's `dy_name` text, (e) character picture/name by cqi (`CcoCampaignCharacter`, `CharacterList.FirstContext(CQI == …)`, `FactionLeaderContext.ImageCardPath`).

**Later (polish, user 2026-10-25):** item rows can still be **dragged** (no effect, but should be blocked) and play the **click sound** on the item entry (should be silent; keep the hover sound). Suspects: `moveable`/template `ContextSlotItem` still inherited from the `ancillary_entry` template; `sound_category="UI_CAM_CLICK_Character_Details_Ancillaries"` on the instance. Likely fix (per the override rule above): add an instance `ContextSlotItem` with `is_draggable = false` and no mouse events, instead of removing it. **Update:** the override rule turned out wrong (0.2.6) — template callbacks can't be overridden from the instance; drag/click must be handled differently (e.g. runtime: `SetInteractive`/`SetDisabled` on the entry while keeping tooltips, or a non-template copy of the entry).

**Old fix (Lua 0.2.1, did not help):** right after copying, destroy all `CcoCampaignAncillary*` children of `list_demands > magic_items_list` (keeping `template_item_holder`). Logger now reports `item rows` / `EMPTY rows` per column.

### 7.0.7 E3 — native deal, first look (DOC, 2026-10-26)

User description of the native flow (screenshots): a subpanel's OK adds a **term row** to Your Offers / Your Demands; each row has a ✗ (remove term) and clicking its name reopens the subpanel; each term changes the AI's opinion (tooltip on the green/red number: Baseline evaluation, Relative faction strength, Diplomatic prospects, Economic value; Trade Settlement mostly moves *Economic value*). Goal: integrate items the same way.

From `diplomacy_hud_offers_panel.twui.xml`:
- Term rows are templates `offer_button_payment`, `offer_button_trade_regions`, `offer_button_trade_agreement`, `offer_button_alliance`, `offer_button_confederation`, `offer_button_break_treaty`, `offer_button_marriage` (each `diplomacy_button` + `delete_button`), driven by **native** callbacks `DiplomacyListPaymentButton`, `DiplomacyListTradeRegionsButton`, `DiplomacyListButton`, … — not the context system. Lists: `center_panel > your_offers > your_offers_list > list_clip > list_box`, `their_offers > their_offers_list > …`.
- Buttons: `button_set1` = `button_send`, `button_counter_offer`, `button_makeitwork` (scales), `button_threat_of_force`, `button_war_coordination`, `button_cancel`; `button_set2/3/4` for AI counter-offers / accept. `deal_success_holder > label_deal_success_chance` = the green/red number. `dev_button_force_accept` runs `RunCLIMultiplayer("cai_force_deal_acceptance true")`.
- **No context bindings** for the deal, its terms or its score in this layout → deal content and evaluation are native/opaque from the UI side. `CcoCampaignNegotiation` exists (`TargetFactionContext`) — its other fields are unknown (to explore in Context Viewer).
- Vanilla scripts listen to `PositiveDiplomaticEvent` / `NegativeDiplomaticEvent` with `context:proposer()`, `recipient()`, `is_alliance()`, `is_military_alliance()`, `is_defensive_alliance()`, `is_non_aggression_pact()`, `is_peace_treaty()`, `is_trade_agreement()`, `is_vassalage()`, `proposer_is_vassal()`, `is_state_gift()`. Unknown whether payments / settlement trades fire anything.
- Consequence: we can't add a native term type; the AI score can't be changed directly. A "Magic Items" row must be our own component placed into the offers list (like the holder portrait), and the trade must be executed by us when the native deal is accepted.

**User requirement (2026-10-26):** the AI must have a real chance to refuse — otherwise players rob NPC factions. Options named by user: (1) become part of the native deal system (preferred), (2) a fully custom items-only deal inside our panel with our own evaluation (fallback).

DB findings for option 1:
- `diplomatic_actions_tables`: 34 action keys (+ ours) — ordering/category of action buttons only.
- `cai_personality_deal_evaluation_deal_component_names_tables`: **fixed list of 45 engine deal components** (`OFFER_GIFT`, `REQUEST_GIFT`, `OFFER_REGION`, `REQUEST_REGION`, `PEACE`, `TRADE_AGREEMENT`, `NON_AGGRESSION_PACT`, `OFFER/REQUEST_JOIN_WAR`, `STRATEGIC_BALANCE_CHANGE`, `ULTIMATUM_*`, …). Each needs engine code → **a new native term type is not possible** via DB.
- `cai_personality_deal_evaluation_*` (79 profiles per race/minor/major/unfriendly) — AI personalities for deal evaluation.
- **`effect_bonus_value_cai_deal_component_junctions_tables`** (`cai_deal_component`, `effect`, `bonus_value_id`): vanilla has 1 row `PEACE ← wh3_dlc29_major_alliances_deal_evaluation_all_effect_test, evaluation_add`. → An **effect on a faction can add points to the AI's evaluation of a deal component.**
- Script can build effect bundles with arbitrary values: `cm:create_new_custom_effect_bundle(base_bundle_key)` → add effects with values → `cm:apply_custom_effect_bundle_to_faction(bundle, faction)` (also `cm:apply_effect_bundle(key, faction_key, turns)`).

**Hybrid idea for option 1 (to be proven by spike S1):** our own effect(s) linked to the native components used by a payment (`OFFER_GIFT` / `REQUEST_GIFT`, to verify). When items are in the deal, Lua applies a custom bundle to the **AI target** whose value = our item valuation (positive when the AI gains items, negative when it loses them). The native score (green/red number, accept/decline, counter-offers, "make it work") then includes items. Needs a native carrier term in the deal (e.g. a payment) — whether a tiny/zero payment is possible is unknown.

### 7.0.8 Spike S1 — effect-based deal evaluation (building, 2026-10-26)

Question: does an effect bundle on the AI faction change its native evaluation of deal terms, and which components react?

Pack additions (DB TSVs, all keys prefixed `items_trading_`):
- `effects_tables`: 7 effects `items_trading_s1_deal_eval_<component>` (icon `fx_icon_diplomacy.png`, priority 100, category campaign).
- `effect_bonus_value_cai_deal_component_junctions_tables`: each effect → its component, `evaluation_add`.
- `effect_bundles_to_effects_junctions_tables` (version 3): bundle `items_trading_s1_deal_eval_probe`, scope `faction_to_faction_own_unseen`, stage `start_turn_completed`, values: `OFFER_GIFT` 10, `REQUEST_GIFT` 20, `OFFER_REGION` 40, `REQUEST_REGION` 80, `PEACE` 160, `TRADE_AGREEMENT` 320, `NON_AGGRESSION_PACT` 640 (powers of two → any jump identifies the components).
- loc: `effects_description_items_trading_s1_deal_eval_*`, `effect_bundles_localised_title/description_items_trading_s1_deal_eval_probe`.
- `effect_bundles_tables` (version 4: `key, localised_description, localised_title, bundle_target, priority, ui_icon, is_global_effect, show_in_3d_space, owner_only`): `items_trading_s1_deal_eval_probe`, target `faction`, priority 1, `diplomacy.png`, `true, false, true` (like vanilla diplomacy bundles). The two localised columns carry the same text as our loc lines.
- Other diplomacy tables extracted by the user (2026-10-26), nothing decisive: `diplomacy_quick_deal_offers` (9 treaty actions), `diplomacy_components` (only `placeholder`), `diplomacy_negotiation_string_options` (AI response lines), `effect_bonus_value_diplomacy_manipulation_category_junctions` (Tzeentch manipulation effects).

Debug `S1.1`: clicking our action button applies the bundle to the negotiation target (`cm:apply_effect_bundle(key, faction, 0)`, logs `has_effect_bundle`); closing diplomacy removes it.

Test plan: build a deal with one native term (e.g. demand a payment) → note the number → click our button (bundle applied) → close our panel → does the number change (live?) → change/re-add the term → note again. Repeat with: offer a payment, offer/demand a settlement, peace, trade agreement, non-aggression pact. Also: smallest payment the slider allows.

### 7.0.9 Button rebuild bug — fixed with a watcher (Lua 0.3.2, awaiting test, 2026-10-26)

User report: S1 can't be tested because our action button disappears after **every** rebuild of the offers UI — after each proposal, and when entering diplomacy through the map (double-click a faction) instead of the faction list. Only the `button_ok` path (faction list → confirm) created it.

Fix:
- **Button watcher:** on `PanelOpenedCampaign` `diplomacy_dropdown` start `cm:repeat_real_callback(fn, 250, "ad_trade_magic_items_button_watcher")`; every 250 ms, if `list_possible_actions` exists and has no `diplomatic_option_trade_magic_items`, recreate it. Stopped on `PanelClosedCampaign`. Real timers follow UI updates, not the model → UI only, MP-safe.
- The watcher also clears a pending selection when the negotiation partner changes (any entry path).
- Placement: after `diplomatic_option_payment`; if missing, before `diplomatic_option_trade_regions`; else at the end (payment was missing once in a log).
- Removed the `button_ok` listener (it also fired for every other `button_ok` in the game). Creation logs reduced to one line.
- Docs: `cm:real_callback` / `repeat_real_callback` intervals are **milliseconds**; `cm:callback` / `repeat_callback` are seconds and follow the model.
- **Decision (user, 2026-10-26): keep the timer for now.** Alternative considered: event-driven (diplomacy open + clicks inside diplomacy with re-checks over ~1.5 s + hover on action buttons). Rejected for now because there is no "list rebuilt" event: rebuilds without a local click (AI counter-offers, the other player in MP) would leave the button missing until the next hover. UI events available to Lua (from vanilla scripts): `ComponentLClickUp`, `ComponentMouseOn/Off`, `ComponentMoved`, `ComponentAnimationFinished`, `PanelOpened/ClosedCampaign`, `UICreated/Reloaded`, `UITrigger`. CA itself polls this panel (`cm:start_diplomacy_panel_context_listener`, 0.2 s).

**Test of 0.3.2 + S1.1 (user + log `script_log_261026_1250.txt`, 2026-10-26):**
- Watcher works: button present on every entry path and after every rebuild (10 recreations in one session). Problems:
  1. Pop-in is very noticeable — the whole action row shifts when the button is added up to 250 ms after a rebuild.
  2. Button must **not** appear at war (only Peace is offered then; after choosing Peace the other actions appear) — same availability as the Payment action.
  3. Same when Join Confederation is chosen.
  4. When Payment is already a term (its action button disappears), our button moved to "before trade settlement" — should stay in the same place.
- **S1.1: bundle applied to the AI (`has_effect_bundle=true`) but the deal number did not change.**

Fixes (Lua 0.3.3):
- Interval 250 → **33 ms** (~2 frames); diplomacy panel cached while open; target check only after a detected rebuild (keeps each tick cheap).
- **Availability rule:** show the button only if `diplomatic_option_payment` or `diplomatic_option_trade_regions` is in the action row, or a payment / settlement term is already in the deal (child ids of `your_offers_list` / `their_offers_list` `list_box` containing "payment" or "trade_region" — **id names unverified**; the log line "Item trading NOT available: … (terms: …)" lists them). Otherwise our button is destroyed.
- **Placement:** after payment → else after state gift (unilateral) → else before the first of join_war, peace, declare_war, trade_regions, trade_technology, hostage, marriage (= payment's slot in the native sort order).

S1.2 (debug `S1.2`): second bundle `items_trading_s1_deal_eval_probe_own` (same effects, scope `faction_to_faction_own`, values ×100: 1000 … 64000). 1st click on our button → both bundles on the AI; 2nd click → also on the player. Closing diplomacy removes all.

**Test of 0.3.3 + S1.2 (user + log `script_log_261026_1351.txt`, Neferata vs Hashut, 2026-10-26):**
- Button: ✅ not shown at war (Peace only) or with Confederation chosen; ✅ pop-in no longer noticeable at 33 ms; ✅ correct slot when Payment is already a term. **Button work done.**
- S1.2: stage 1 (bundles on the AI only) → no visible change (user: "first cancel seems no effect" — whether the term was re-added after stage 1 is unclear). Stage 2 (also on the player) + any deal change → **huge jumps**:

  | Seen | Probe | Reading |
  |---|---|---|
  | NAP action badge 64630 | 64000 (own) + 640 (unseen) − 10 | `NON_AGGRESSION_PACT` bonus from **both** scopes |
  | Trade agreement badge 32311 / 32292 | 32000 + 320 | `TRADE_AGREEMENT` bonus from both scopes |
  | Deal "Trade Agreement + Payments 601" = 32292.3 (breakdown sums to −27.8: baseline −30, strength +4.6, prospects −1.1, economic −1.1, distance −0.2) | | bonus goes into the total ("Diplomatic treaty"), **not itemised** in the breakdown; **`REQUEST_GIFT` (+2020) not counted** |
  | Payment-only demand shows 0.0 (no breakdown) | | unexplained |
  | Other badges (−34, −38, −59, −68, −108) unchanged | | components without our effect unaffected |

- **Conclusions so far: the effect lever works** (`effect_bonus_value_cai_deal_component_junctions` + `evaluation_add`), both `faction_to_faction_own` and `_unseen` scopes work. **Open:** which faction must hold the effect (looks like the player / proposer); whether payments (`OFFER_GIFT` / `REQUEST_GIFT`) can carry a bonus at all.
- S1.3 (debug `S1.3`): stage 1 = bundles on the **player only**, stage 2 = also on the AI. Test focus: (a) does stage 1 alone give the jump (proposer side)? (b) payments: offer-only and demand-only payment deals, number with vs without bundles (expected +1010 / +2020 if the gift components carry the bonus).
- **S1.3 result (user + log `script_log_261026_1422.txt`, 2026-10-26): PROVEN — the bundle on the PLAYER (proposer) alone is enough.** After the 1st click (player only) + any deal change, Trade Agreement deal = 32294.0 (breakdown −26.0 + 32320). The evaluation is recomputed only when the deal changes; the bonus is not itemised in the breakdown tooltip ("Diplomatic treaty" total only).
  Earlier S1.2 detail confirmed by user: bundles on the AI only + deal change → no effect.
  Labels: a payment **alone** shows as "Payments (Gift)" (→ gift components); inside a bigger deal it shows as "Payments" (valued elsewhere, our `REQUEST_GIFT` bonus not counted there). A lone payment demand showed 0.0 with bundles and could be fulfilled (user). AI always accepts an offered gift (balance rule).
- **Payments (user, 2026-10-26): a lone payment demand ("Payments (Gift)") goes from red to "0.0" green after the bundle on the player + a deal change, and the AI accepts → `REQUEST_GIFT` carries the bonus.** The panel shows accepted gift demands as 0.0 (display, not the real value). Offered gifts are always accepted anyway.
- **=> Spike S1 DONE: option 1 (native integration) is feasible for the AI decision.** Mechanism: custom effect bundle on the **proposer** with `evaluation_add` effects on the deal components present; recomputed on the next deal change; not itemised in the tooltip.
- All 45 components: BREAK_/CANCEL_/OFFER_/REQUEST_ variants of alliances, access, NAP, client state, vassalage, confederation, join/declare war, gift, region; plus PEACE, TRADE_AGREEMENT, STRATEGIC_BALANCE_CHANGE, ULTIMATUM_ISSUING/RECEIVING, WAR.

### 7.0.10 Carrier term and recalculation (2026-10-27)

User answers: **Propose is greyed out with an empty deal**; **minimum payment = 1 gold**. User concern: the bonus only shows after the *next* deal change → stale number right after our OK = UX problem.

Folder reorganised by the user: vanilla files now in `Vanilla_files/` (db, script, text, ui). The folder `Other modders examples/` was **reviewed later the same day** → `04_other_mods_review.md` (ideas only, no decisions). Key points: no mod changes the evaluation of one specific deal at runtime and none uses `effect_bonus_value_cai_deal_component_junctions`; gold can move a deal by at most `max_payment_value` = 15 points (`cai_personality_deal_evaluation_components_tables`); `cm:cai_evaluate_quick_deal_action(from, to, action)` returns the native AI rating for the 9 quick-deal treaty actions (DOC, also used by vanilla scripts) — a possible probe for our bonus.

Payments subpanel (`Vanilla_files/ui/campaign ui/diplomacy_hud_payments.twui.xml`): `buttongroup_offer_demand > pay_offer / pay_demand`, `payment_parent > buttongroup > pay_once / pay_repeatedly`, `amount` (`NumericalInput`, arrows `l_arrow_amount` / `r_arrow_amount`), `turns`, `gift_parent > button_small/medium/large_gift`, `both_buttongroup > ok_payments / cancel_payments`, native callback `DiplomacyPaymentPanel`.
→ Idea: our OK drives this panel with `SimulateLClick` (demand / offer, amount 1, OK) to add a **1-gold carrier term** = a native deal change → instant recalculation, and the deal becomes proposable even with items only.

**Decision (user, 2026-10-27): REJECTED in this form.** A script that visibly opens the Payments panel, clicks through it and adds a gold coin looks bad. A carrier is acceptable only if added purely by code with nothing visible, otherwise another solution is needed. The E3a.1 probe was written and rolled back the same day, never tested.

Search for a code-only way to add a term (2026-10-27, DOC):
- Script API (`Vanilla_files/script`): diplomacy calls are only `force_diplomacy`, `make_diplomacy_available`, `enable_all_diplomacy`, `apply_dilemma_diplomatic_bonus`, `cai_evaluate_quick_deal_action`, `cai_add_diplomatic_event`, `cai_insert_caravan_diplomatic_event`. **None builds or edits the open negotiation.**
- UI layouts (`Vanilla_files/ui`): the only context command on negotiations is `DiplomacyManagerContext.OpenNegotiation(this)`; other negotiation fields are lists (`PendingNegotiationList`, `SentNegotiationList`). No "add term" command. Deal panels use native callbacks (`DiplomacyPaymentPanel`, `DiplomacyList*Button`).
- → A native term can only come from the native UI (a real or simulated click). Unexplored: `CcoCampaignNegotiation` queries in the Context Viewer (user task in `00_START_HERE.md` §8).
- User (2026-10-27): the "invisible same-frame carrier" idea is also rejected as too hacky.

### 7.0.11 Research: other ways into the deal (2026-10-27, DOC)

Sources: `Vanilla_files/script/events.lua` (full engine event list), chadvandy docs `scripting_doc.html` (model hierarchy) and `campaign/episodic_scripting.html`, `lib_campaign_manager.lua`, vanilla DB.

**`cm:cai_evaluate_quick_deal_action(proposer, recipient, action_key)`** (DOC): evaluates a one-term "quick deal" and returns `score, can_propose`; score > 0 = an AI recipient would likely accept. Actions = the 9 in `diplomacy_quick_deal_offers_tables` (treaties only, no payments / settlements). Vanilla uses it only in `wh3_narrative_shared_chains.lua` to pick the best faction for NAP / trade / alliance / confederation missions. Model-side, no UI → MP-safe (HYPOTHESIS).

**Diplomacy events** (`events.lua`): `DiplomacyNegotiationStarted` (context undocumented → probe), `DiplomaticOfferRejected` (`proposer`, `recipient`), `PositiveDiplomaticEvent` (`proposer`, `recipient`, `is_*` treaty flags, **`is_state_gift`, `state_gift_amount`**), `NegativeDiplomaticEvent`, `FactionLeaderSignsPeaceTreaty`, `FactionJoinsConfederation`, `RegionFactionChangeEvent`. → accept *and* reject are observable for at least treaty/gift deals (E3b).

**Engine diplomacy types** (`campaign_manager.diplomacy_types`, bitmask for `force_diplomacy`): besides the visible ones there are **`technology` (2^5)** and **`hostages` (2^14)**; `diplomatic_actions_tables` still has `diplomatic_option_trade_technology`, `diplomatic_option_hostage`, `diplomatic_option_mariiage`. Legacy from older titles, hidden in WH3. No matching deal component in the 45 names. Unknown whether enabling them shows a button, what the term does, and how the AI values it.

**Other levers seen:** `cm:apply_dilemma_diplomatic_bonus` (−6…+6 attitude), payload `diplomatic_attitude_adjustment(_between)`, `cm:cai_add_diplomatic_event(from, to, event)` with events from `cai_personality_diplomatic_event_values_tables` (`PAST_EVENT_POSITIVE_MINOR/MODERATE/MAJOR` …) — all change **relations**, not one deal. `cm:seek_exchange` = unit exchange between armies (not items).

Ideas list → `00_START_HERE.md` §7.

Follow-up checks (2026-10-27):
- **`technology` / `hostages` are dead leftovers in the UI:** no subpanel holder in `diplomacy_hud.twui.xml`, no icon in `diplomacy_icons/`, no button/tooltip strings in `diplomacy_strings__.loc` (only `diplomatic_factor_technology` = "Technology" and an AI line about hostages). Even if `force_diplomacy` enabled them, clicking the action would have no panel, and no deal component exists to price them. → Very unlikely to work; low priority.
- **Where the diplomacy context objects live (for Context Viewer):** `CcoCampaignDiplomacyManager` (= `CampaignRoot.DiplomacyManagerContext`) is propagated onto `pending_negotiation_list` and `sent_negotiation_list` in `diplomacy_hud.twui.xml` (lists `PendingNegotiationList` / `SentNegotiationList`). Their rows carry `CcoCampaignNegotiation` (= an offer waiting for an answer: from the AI to us, or sent by us — likely also player-to-player in MP). Whether the deal being edited right now is a context object at all is unknown.
- **`cm:treasury_mod` with a negative amount** is used by AST (`ast_lib.lua:1508`) despite the doc saying "must be positive" → gold can be moved by script.
- **Treaties by script exist:** `force_make_peace`, `force_make_trade_agreement`, `force_non_aggression_pact`, `force_alliance`, `force_grant_military_access`, `force_make_vassal`, `force_confederation` (names in episodic docs). In theory an own deal could include them; it would duplicate native diplomacy.

**Decisions (user, 2026-10-27):** hidden types `technology` / `hostages` dropped. Own items deal (D) = **fallback only**, if items can't be combined with native terms.

**Context Viewer on the offers panel (user screenshots, 2026-10-27) — PROVEN:**
- Deal term rows in `your_offers_list` / `their_offers_list > list_clip > list_box` are **named after the action key**: `diplomatic_option_trade_regions`, `diplomatic_option_trade_agreement`, … (children `diplomacy_button > button_tx, region_names`, `delete_button`). → Our v0.3.3 term check (`payment` / `trade_region` in the id) matches real names.
- `diplomacy_hud_offers_panel` and the term rows have `ContextsList (0)` → **no context object behind the deal UI**; the deal is native-only on the UI side.
- The Context Viewer has a left "Context shortcuts" list incl. **Campaign UI Root (CcoCampaignRoot)** → direct route to `DiplomacyManagerContext` without searching components.

**`CcoCampaignDiplomacyManager` (Context Viewer, user screenshot, 2026-10-27) — PROVEN, complete list:**
- Queries: `PendingNegotiationList` (CcoCampaignNegotiation-List), `SentNegotiationList` (same), **`NegotiationForFaction(CcoCampaignFaction)` → `CcoCampaignNegotiation`**.
- Commands: only `OpenNegotiation(CcoCampaignFaction)` — "Opens up negotiation in diplomacy to accept/counter/modify if there is one". No add / modify / evaluate commands on the manager.
- Both lists were empty (0) during a normal negotiation with an assembled deal (Trade Agreement + Trade Settlement + Payments 201).
- The Context Viewer has an **expression test input at the bottom** for calls with arguments.
- **`NegotiationForFaction(CampaignRoot.CurrentNegotiatingFactionContext)` works** (expression input, 2026-10-27): during a normal negotiation with an assembled deal it returns a `CcoCampaignNegotiation` (object id `4729591504` in that session) → **the deal being edited IS a context object**. First visible query: `TargetFactionContext` → `wh3_dlc23_chd_astragoth` ("the non player faction in the negotiation"). Rest of its queries / commands not yet seen (panel cut off).

### 7.0.12 Vanilla documentation + Context Viewer events (2026-10-27)

User extracted CA's own docs to `Vanilla_files/documentation/` (`ui/documentation.html` = all 548 context objects, `ui/callback_documentation.html` = all UI callbacks, `ui/context_viewer_doc.odt`, `script/...` = offline copy of the script docs incl. `campaign/campaignui.html`, `model_hierarchy.html`) and `Vanilla_files/ui/autocomplete.json` (context function / event names).
Flattened list: `docs/tools/cco_functions.txt` (one line per `Object.Function | return | args | description | tags | events`, built by `tools/cco_dump.js` with node). Search it instead of the 2 MB HTML.

**Deal as a context object — DEAD END (DOC, CA's own words):** `CcoCampaignDiplomacyManager` = "so we can get pending negotiations for MPC sim turns, etc. **Not meant as a full replacement for diplomacy since we dont have resource to rewrite diplomacy to cco in wh3!**". `CcoCampaignNegotiation` has exactly one function, `TargetFactionContext`. Docs say Pending/Sent lists are "only in mpc sim turns", but the user saw an AI offer (Goldtooth) in `PendingNegotiationList (1)` in single player. Clicking that pending row in the Context Viewer **froze the game hard**.
→ No context-side way to read or change the deal. Native terms only via the native UI.
`CampaignUI` (offline `script/campaign/campaignui.html`) has no diplomacy functions either: only HUD/overlay/whitelist helpers, `TriggerCampaignScriptEvent`, `TriggerIncident`, `ClosePanel`, `ZoomToSmooth` etc.

**UI events seen in the Context Viewer "Events" tab (user, 2026-10-27):**
- `CampaignNegotiationChange` fires when the deal changes (term added / removed). Listed in `autocomplete.json` among UI context events.
- Payment amount changes fire `TextInputChanged` (the success-chance label listens to it).

**UI → Lua bridge (DOC, `cco_functions.txt` / `callback_documentation.html`):**
- Context commands `TriggerUIScriptEvent("key")` ("Sends a UITrigger event with the specified key to script … Should not be used to directly change the model" = local only) and `TriggerScriptEvent("key")` ("In campaign will go via command queue" = synced like `CampaignUI.TriggerCampaignScriptEvent`). Vanilla dev UI uses `TriggerScriptEvent(Format("episodes_manager_cheats:…", …))`. Lua receives them as `UITrigger`, key in `context:trigger()`.
- Callback **`ContextCommandEvent`**: "Calls context function on the events specified by event%d" — user property `event0 = <event name>`, `context_function_id = <expression>`; optional `disable_when_invisible`. Vanilla example: `narrative_viewer.twui.xml:735` (`event0 = MoviePlaybackFinished_movie_screen`, `self.SetVisible(false)`).
- → **Idea (HYPOTHESIS): event-driven button watcher.** A small callback-free layout created under `diplomacy_dropdown` (not inside the rebuilt action row) with `ContextCommandEvent`, `event0 = CampaignNegotiationChange`, expression `TriggerUIScriptEvent("items_trading_negotiation_changed")` → Lua `UITrigger` listener runs `ad_ensure_trade_magic_items_button` (maybe one frame later, if the rebuild comes after the event). Open: does the event also fire on partner change / AI counter-offer / MP partner's change? Could replace or slow down the 33 ms timer.
- `UIComponent:AddScriptEventReporter()` (DOC) makes a component report `ComponentMouseOn`, `ComponentAnimationFinished` etc. to Lua.

**Item data found in the docs (useful later):** `CcoCampaignAncillary.SalvageValue` (gold value if salvaged → a ready base price for the item value formula), `CcoAncillaryRecord.CanFactionUseAncillary(CcoFactionRecord)` and `IncludedSubculturesList` (race-lock check from the UI side), `UniquenessScore`, `RandomlyDropped`.

**Donor for our "Magic Items" deal row (DOC):** `diplomacy_hud_offers_panel.twui.xml`, hidden template `offer_button_trade_regions` (line ~6698, 250×80, native callback `DiplomacyListTradeRegionsButton`) → `diplomacy_button` (callback `Button`, images `parchment_button_square_*.png`) > `button_tx` ("dy_item"), `region_names` ("dy_item"); `delete_button` (template instance `round_extra_small_button`). The game clones this per term and names the clone after the action key (`diplomatic_option_trade_regions`). Plan: copy into a standalone layout without the native callback (same approach as `ad_holder_portrait`), `CreateComponent` it into `your_offers_list` / `their_offers_list > list_box`.

**Script docs (offline, `Vanilla_files/documentation/script/`) — useful bits (DOC):**
- `cm:build_and_apply_custom_effect_bundle_to_faction(params, faction, bundle_key, {effect_key = value, …}, [overwrite], [duration])` — lib helper that builds and applies a custom bundle in one call → the Phase 4 item-value bundle on the proposer.
- `cm:progress_on_mp_query(query_command, faction_key, [query_data], callback)` — "query information that is only available to the script on one machine, and have the result … sent across the network to all machines" → MP sync of UI-only data (e.g. the selected items).
- `uicomponent:InterfaceFunction(name, …)` / `HasInterface()` / `CallbackId()` — call script-exposed functions of a native callback. Vanilla uses it for help pages, pending-action notifications, `QuitForScript`. `callback_documentation.html` lists functions only for a few callbacks (diplomacy: only `DiplomacyTacticalZoom.InitialiseCamera`); `DiplomacyDropdown` lists none → could be probed with `HasInterface()` but unlikely.
- Full UIComponent method list incl. `SetDisabled`, `SetInteractive`, `SetState`, `SetStateText`, `SetText`, `SetTooltipText`, `StartPulseHighlight`, `AddScriptEventReporter`, `TriggerShortcut`.
- `button_send` / `button_makeitwork` in `diplomacy_hud_offers_panel.twui.xml` are plain `Button` template instances (`round_medium_button`) with no context callbacks; `label_deal_success_chance` has states `negative` / `positive`, no context callbacks → both are driven by the native `DiplomacyDropdown` code.

### 7.0.13 Idea: override the shown score and the Send button (user, 2026-10-27) — under evaluation

Idea: we write our own number into `label_deal_success_chance` (native number ± our item value), and enable / disable `button_send` ourselves. User's theory: an enabled Send always makes the AI accept; it is greyed exactly because the AI would refuse.

Assessment (Claude):
- **Blocking direction works for sure** (UI only): if our total is negative, we grey Send → the player can't get items for free from the AI.
- **Enabling direction is doubtful:** the AI most likely decides in the model when it receives the proposal, with its own evaluation (the dev command `cai_force_deal_acceptance` exists exactly to override that). A natively negative deal sent anyway would then be refused (`DiplomaticOfferRejected`). If so, items could only make the AI stricter, never more generous; the S1 bundle stays the lever for "more generous".
- **Display override is a good UX layer** on top of the S1 bundle: no stale number. Costs: native code rewrites the label / tooltip / Send state on every deal change (need the `CampaignNegotiationChange` hook), action badges and the breakdown tooltip show native values, "make it work" and AI counter-offers use the native evaluation.
- **MP player-to-player** (the MVP) has no AI score at all — the human decides — so this idea doesn't help there; the open problems for MP are: items visible to the recipient, items-only deals, accept detection.
- **Open, worth testing:** what Send does on an **empty** deal if force-enabled (nothing / error / AI answers). If the engine accepts an empty proposal and fires an event, that would be a carrier-free items-only path.
- Proposed test **E3c (throwaway save)**: force `button_send` active (a) on a red deal, (b) on an empty deal; the user clicks Send; log state, AI answer and E3b events.

### 7.0.14 E3c forced Send + deal rows v0.4.0 (2026-10-27, awaiting test)

User: "don't guess, test it" — work plan: (1) Send always active, user proposes a red deal; (2) a "Trade Magic Items" deal row per side.

**E3c.1 (debug):** while diplomacy is open a 33 ms real-time timer puts `button_set1 > button_send` back to `active` (and `SetDisabled(false)`) whenever the game greys it; logs each time the game changed it (with the score). On a Send click it logs score, deal term ids, visibility of `button_set1..4`, texts under `offer_response` — immediately, +0.5 s, +1.5 s, +3 s. **E3b**: while diplomacy is open, logs `DiplomacyNegotiationStarted`, `PositiveDiplomaticEvent`, `NegativeDiplomaticEvent`, `DiplomaticOfferRejected`, `RegionFactionChangeEvent` with every known method that answers (`proposer`, `recipient`, `is_state_gift`, `state_gift_amount`, `is_*`, `region`, `previous_faction`, …) and the metatable method list if readable. S1 switched off. Throwaway save (a deal may go through).

**Main mod 0.4.0 — deal rows (visual only):**
- Pending items of a side → row `ad_offer_magic_items_offers` in `your_offers_list > list_box` / `ad_offer_magic_items_demands` in `their_offers_list > list_box` (layout `ad_offer_magic_items.twui.xml`). Title = our button's loc title; `item_names` = localised item names (sorted), one per line; row and `diplomacy_button` grow with `TextDimensions()` (min 80).
- Item names now stored in the selection (`name` from `item:Call("Name")` when holders are marked).
- Click on the row (`diplomacy_button` whose parent is our row) → opens our panel with the pending ticks. `delete_button` of our row → that side's items dropped; both empty → pending cleared.
- While anything is pending our action button is destroyed ("items already in the deal"); it comes back when both rows are gone.
- The button watcher (33 ms) also puts missing rows back; a missing row triggers a target check (partner changed → selection cleared).
- Not done: the rows are not native terms (no AI effect, no Propose with items only).
- "Send CampaignNegotiationChange ourselves" (user idea): not needed — our own actions call the row update directly. Lua can't fire native model events; a UI broadcast of that name (`ContextEventBroadcaster`) might make native lists refresh and destroy our rows.

Test checklist:
1. E3c: build a red deal (e.g. demand a settlement), Send should be clickable → click → what does the AI answer, does the deal go through? Then Send on an **empty** deal.
2. Rows: tick items on both sides → OK → two rows with names, our action button gone. Add a native term (payment) → rows survive / come back. Click a row → our panel with ticks. Delete one row → other stays; delete both → button back. Many items (5+) → row height.
3. Send the log (`[MAGIC_ITEMS_E1 E3c.1]`, `[MAGIC_ITEMS_DIPLOMACY 0.4.0]`) + screenshots.

**Test of 0.4.0 + E3c.1 (user + log `script_log_271026_2053.txt`, 2026-10-27):**
- ✅ Row logic: OK creates rows (one or both sides), row click reopens our panel with ticks, ✗ removes one side, both gone → our button back, button hidden while items pending. User: "works pretty good, I like it".
- ❌ Text: names were squeezed and overlapped the title. Cause: the title is docked **Center** (moves down when the row grows) and `item_names` was only 38 high when the text was set, so the game **shrank the font** to fit; `TextDimensions()` then measured the shrunk text (5 items → row only 105 high).
- ❌ **Crash**: removing the native Trade Settlement term while our rows were in the deal lists → hard crash (`crash_report/D2026-10-27_T20-59-26`, stack all inside Warhammer3.exe). The click never reached Lua (no `[ui]` click line) → crash inside the native term removal. It was the first native deal change with our rows present. **HYPOTHESIS (strong): the native code walks `list_box` children expecting its own term rows / callbacks; a foreign child there crashes it.** Rule: don't put foreign components into native `list_box`es of the deal.
- E3c not exercised (no Send click in the log). `DiplomacyNegotiationStarted` fired when entering the negotiation; context is a plain **string** (metatable `string`, no methods) — value not logged yet.
- User wishes: row height follows the text, font must not shrink; numbered items `1) …`.

**Fix (0.4.1, awaiting test):**
- Rows are created in the **column** (`your_offers` / `their_offers`), not in `list_box`; every watcher tick moves them (`MoveTo`, screen coords) just below the last visible native term row, clamped to the bottom of `list_clip` (with many native terms our row overlaps the lowest ones — accepted for now; the native scrollbar doesn't know our row).
- Partner change: rows are no longer destroyed by native rebuilds, so the watcher checks the target every 15 ticks (~0.5 s, one context call).
- Layout: `button_tx` docked **Top Center**, offset 12 (rebuilt with `tools/build_offer_row.ps1`).
- Names: `item_names` first resized to 40 px per line, then text set, then measured and shrunk to the text height → no font shrinking. Lines numbered `1) name`.

**E3c result (user + log `script_log_271026_2106.txt`, 2026-10-27, run on 0.4.0) — PROVEN:**
- Force-enabled Send on red deals (vassal demand −105.8, trade agreement −26.0, 7 sends): **the AI refuses every time** ("They have rejected your offer", `button_set3` = rejection buttons). Once (trade agreement −26) the AI answered with a **counter-offer** instead (`button_set2`, deal replaced by "you join their war"). **The user's theory "enabled Send = accepted" is wrong:** the AI evaluates the proposal itself when it receives it. Our UI can only make the AI *stricter* (by greying Send), never more generous — that still needs the effect bundle (S1).
- **`DiplomaticOfferRejected` fires on every refusal** (twice per refusal in our log), context `proposer()` / `recipient()` (faction interfaces), metatable also lists `character`. → Reject detection works.
- `DiplomacyNegotiationStarted` fires when entering a negotiation; context is a plain string.
- Not tested yet: Send on an **empty** deal; which event fires on **acceptance** (treaty / payment / settlement / mixed).
- The game also toggles Send between `hover` / `down` on mouse-over — E3c.2 logs only `inactive` resets.

**Test of 0.4.1 + E3c.2 (user + log `script_log_271026_2121.txt`, 2026-10-27):**
- ✅ **No crashes**: native terms added / removed (trade agreement, settlement, payment) while our rows were shown. Same actions crashed 0.4.0 → the crash cause "our row inside the native `list_box`" is **confirmed in practice** (not isolated in a separate test, but it is the only change).
- ❌ Visuals: our rows overlay native term rows (clamped to the list bottom, native scroll doesn't know them); the row background doesn't match the text (5 items: text runs past the box; title still not at the top in the screenshot). User: "looks like a defeat in making it part of the vanilla deal".
- 🔥 **Forced Send on an EMPTY deal → the AI ACCEPTS** ("They have accepted your offer", 8 sends). The "scores" 10 / 3.4 logged for empty deals are **not real**: `10` is the default text of `label_deal_success_chance` in the layout, 3.4 was left over from the previous deal → an empty deal has no evaluation at all. **No event fires** for it (no Positive / Rejected). → An items-only deal can be proposed through the native flow; the AI has nothing to judge, so the decision for items must be ours (grey Send when our evaluation says no).
- **Accept events (PROVEN):** state gift → `PositiveDiplomaticEvent` with `is_state_gift=true`, `state_gift_amount=2027`; big mixed deal (trade agreement + settlement + payment + vassal) → **one** `PositiveDiplomaticEvent` (`is_trade_agreement=true`, `is_vassalage=true`) + `RegionFactionChangeEvent` (`region`, `previous_faction`, `reason = "diplomacy trade"`) + a burst of `NegativeDiplomaticEvent` side effects (vassal's wars). Refusal → `DiplomaticOfferRejected` (twice).
- **UI-side result (works for every deal incl. empty):** ~0.5 s after Send, `button_set3` visible and `offer_response > dy_text` = "They have [[col:green]]accepted[[/col]]…" / "[[col:red]]rejected[[/col]]" — the colour tag is language-independent. `button_set2` = AI counter-offer.

### 7.0.15 Hybrid plan + spike S2 scope (discussion, 2026-10-28)

Hybrid (proposed): AI recipient + items only → empty native deal, our evaluation decides whether Send is enabled; AI recipient + native terms → effect bundle carries the item value; human recipient (MP) → no evaluation, the human decides, we only sync the item rows and the result.

User decisions / answers:
- **Bundle not needed for player-to-player** — the human decides. (Claude's note: in an MP campaign where a human negotiates with an AI, the bundle is a model change and must be applied on all machines via `UITrigger`, or the game desyncs.)
- Item value is computed once by us; the bundle carries one total. It still has to sit on a component that is actually in the deal → one effect per component, value set only on one present component (no double counting).
- Add effects for **military / defensive alliance** too (`MILITARY_ALLIANCE`, `DEFENSIVE_ALLIANCE` are in the 45 components; any of them can get an effect + junction).
- Must test: script-set values (custom bundle), negative values.
- User idea: after applying the bundle, **send `CampaignNegotiationChange` ourselves** so the AI number refreshes at once.

Multiplayer rule (DOC, CA docs + vanilla `UITrigger` usage): the model is **not** synced by the network — every machine runs the same script on the same inputs (lockstep). An item add/remove (or bundle) done on one machine only = desync. Model changes go in a `UITrigger` handler that runs on every machine.

S2 test list (proposed): (1) does the AI re-evaluate on Send with a bundle applied after the last deal change (if yes, the stale number is display-only); (2) custom bundle with a script-set value; (3) negative value; (4) can a UI broadcast of `CampaignNegotiationChange` (hidden component with `ContextEventBroadcaster`, `SimulateLClick`) refresh the number; (5) alliance components.

More user answers (2026-10-28):
- "Why several components?" → linking **one** effect to all 45 components is possible (one junction row each). Open: does the AI then add the value once per deal or once per term present? S2 measures it.
- MP + AI negotiation, bundle only on the proposer's machine: Claude's answer — the AI's decision is computed on every machine; a bundle on one machine only gives different results / model state → desync. Use `UITrigger`.
- **Redrawing the AI number ourselves is rejected** ("either everywhere or nowhere") → find a way to make the native number pick up the bundle.

**S2.1 built (2026-10-28, awaiting test):**
- DB: effect `items_trading_item_value_all` + junction rows (`evaluation_add`). Started with all 45 components; **user decision (2026-10-28): drop `OFFER_JOIN_CONFEDERATION`, `WAR`, our own treaty breaks (`BREAK_DEFENSIVE_ALLIANCE`, `BREAK_MILITARY_ALLIANCE`, `BREAK_NON_AGGRESSION_PACT`, `CANCEL_CLIENT_STATE`, `CANCEL_MILITARY_ACCESS`, `CANCEL_TRADE_AGREEMENT`, `CANCEL_VASSALAGE`) the ultimatums, `STRATEGIC_BALANCE_CHANGE` and `REQUEST_JOIN_CONFEDERATION`** → 32 components remain, base bundle `items_trading_item_value` (that effect, scope `faction_to_faction_own_unseen`, value 0), loc texts. S1 rows kept for now.
- UI: `ui/campaign ui/items_trading_negotiation_broadcaster.twui.xml` — invisible 1×1 component, callback `ContextEventBroadcaster` with `lclick = CampaignNegotiationChange` (format copied from `beastmen_panel.twui.xml`).
- Debug `S2.1`: our action button click = next stage (+1000 → −1000 → removed); closing our panel (✗ or ✓) applies it: `cm:create_new_custom_effect_bundle("items_trading_item_value")` → `set_effect_value` (fallback `add_effect`) → `apply_custom_effect_bundle_to_faction(player)`; logs the effect value read back from the faction, the deal number before / right after / +100 / +400 ms, then the broadcast (simulated click) and the number +100 / +500 / +1500 ms after it. Each log line also has `cai_evaluate_quick_deal_action(player, target, trade_agreement)` (model-side rating — does it see the bundle at once?) and the term ids. Diplomacy close removes the bundle. E3c (Send always active) stays on.

S2 test plan (throwaway save, Neferata vs Hashut):
1. Deal: trade agreement only (≈ −26). Our button → ✗ (stage +1000). Number jumps after the broadcast? If not: Send → accepted (= AI uses the bundle on receipt)?
2. Our button → ✗ (stage −1000) on a positive deal → number / Send → refused?
3. Deal with 2–3 terms (trade agreement + NAP / alliance + settlement) with +1000 → after any deal change, is the bonus +1000 or ×number of terms?
4. Our button → ✗ (removed) → number back.

**S2.1 result (user + log `script_log_281026_1026.txt`, 2026-10-28) — PROVEN:**
- **Custom bundle with a script-set value works** (`create_new_custom_effect_bundle` + `set_effect_value`; read back from the faction: 1000 / −1000).
- **The model sees it instantly:** `cai_evaluate_quick_deal_action(player, Hashut, trade_agreement)` −26.0 → **974.0** right after applying, no deal change needed.
- **The AI decides with the bundle on Send even when the shown number is stale:** trade agreement shown −26.0 with +1000 applied → Send → **accepted** (`PositiveDiplomaticEvent`). With −1000: NAP / defensive alliance (Bonerattlaz) shown −1002 / −1036 → **rejected**.
- **Negative values work.**
- **Added once per deal, not per term:** military access (both columns) −31.1 → 968.9; defensive alliance −36.5 ↔ −1036.5; military alliance −1055 → exactly ±1000. (Deals with two *different* components, e.g. trade agreement + settlement, not measured yet.)
- Quick-deal badges above the action buttons also show the bundle (empty deal with −1000: −1002, −1031, −1036, −1055, −1059).
- ❌ **The shown deal number still only refreshes on a native deal change.** The `CampaignNegotiationChange` broadcast (simulated click on `items_trading_negotiation_broadcaster`) **changed nothing**. Without E3c, Send would stay greyed while the AI would actually accept.
- The bundle is visible in the faction's effects only for a split second when diplomacy closes — acceptable.
- User: the bundle **must be removed when leaving the negotiation with that faction** (it affects deals with every faction while applied) — so also on partner change, not only on diplomacy close.
- User: values must be careful — a big bonus makes the AI accept any other terms in the same deal ("cascade"). The item value has to be on the native scale (treaties here are about −30…−110; gold is capped at 15 points per `max_payment_value`).

**S3.1 — refresh probe (2026-10-28, awaiting test):** the broadcast was replaced by context commands (`common.call_context_command("CcoCampaignRoot", "", expr)`, signature from the offline `common.html`): `DiplomacyManagerContext.OpenNegotiation(CurrentNegotiatingFactionContext)` and `CurrentNegotiatingFactionContext.OpenDiplomacyWith`. Stages on our button: +1000/OpenNegotiation → removed/OpenNegotiation → +1000/OpenDiplomacyWith → removed/OpenDiplomacyWith; closing our panel applies the bundle and calls the command 0.5 s later; logs number + terms before / after (does the deal survive?). `items_trading_negotiation_broadcaster.twui.xml` deleted (broadcast failed).
Test: deal with one native term (e.g. trade agreement), run the 4 stages; watch whether the number jumps by ±1000 after the command and whether the deal terms stay. Throwaway save — the commands might reset the deal or the panel.

User (2026-10-28): "the UI must re-read the numbers on some event". Claude's reading: the number is written by native C++ (`DiplomacyDropdown`, no context bindings on the label); the native code re-evaluates when **its negotiation object changes** and then notifies the UI (`CampaignNegotiationChange` = consequence, not cause — our UI broadcast of it did nothing). So we look for a model change the panel reacts to. **S3.2** adds two such nudges (both model changes → in MP they would have to run via `UITrigger` on all machines): `treasury` (`cm:treasury_mod(player, +1)`, −1 50 ms later; the panel shows the treasury and payments depend on it) and `force_diplomacy` (allow the hidden `technology` type between the two factions, block again 50 ms later; availability changes rebuild the action row). Stages now: 8 (4 commands × apply/remove).

**S3.2 result (log `script_log_281026_1054.txt`) — PROVEN:** `common.call_context_command("CcoCampaignRoot", "", "DiplomacyManagerContext.OpenNegotiation(CurrentNegotiatingFactionContext)")` fires `DiplomacyNegotiationStarted` and then **closes the whole diplomacy panel** (`Panel closed diplomacy_dropdown`), twice in a row. Not usable. (Both runs had an empty deal; the stage counter was reset by the diplomacy close, so the other stages were never reached.)
**S3.3:** OpenNegotiation dropped; order treasury → force_diplomacy → OpenDiplomacyWith; the stage counter is no longer reset when diplomacy closes.

**S3.3 result (user + log `script_log_281026_1806.txt`, military access deal −31.2) — PROVEN:**
- `treasury_mod` +1/−1 → number unchanged (−31.2 stayed −31.2 1.5 s later).
- `force_diplomacy` technology allow/block → number unchanged.
- `OpenDiplomacyWith` → **closes diplomacy** like `OpenNegotiation`.
- (Number changes seen in the log, e.g. 1966.3, came from the user editing terms.)
- **All five refresh attempts failed** (UI broadcast, OpenNegotiation, OpenDiplomacyWith, treasury, force_diplomacy). The shown number is only recomputed on a real native deal change.
- User check by hand: opening the Payments / Trade Settlement subpanel and cancelling does **not** refresh; only an actually confirmed term does.

**S4.1 (2026-10-28, awaiting test)** — stages on our button: +1000/interface → removed/interface → +1000/add_remove → removed/add_remove.
- `interface`: for `diplomacy_dropdown`, `offers_panel`, `diplomacy_hud_offers_panel`, `panel_diplomacy`, `offers_list_panel`, `deal_success_holder`, `label_deal_success_chance`, `button_set1`, `button_send`, `list_possible_actions`, `your/their_offers_list` logs `HasInterface()` + `CallbackId()`; where an interface exists, tries `InterfaceFunction` with guessed names (Refresh, RefreshDeal, RefreshNegotiation, RefreshEvaluation, Update, UpdateDeal, UpdateEvaluation, Evaluate, Reevaluate, Initialise, Init, Reset) in `pcall`.
- `add_remove` (user's idea, refined): the available actions are exactly the buttons in `list_possible_actions`, so the script clicks the first visible one-click treaty (NAP → trade agreement → military access → defensive → military alliance) that is not already a term, then clicks the new term row's `delete_button` (same frame if the row exists, else one retry per tick, max 10). Deal ends unchanged but changed twice. Logs on which tick the row appeared. Throwaway save: if the row never shows up, the treaty stays in the deal.
Test: deal with one native term, 4 stages; watch the number after each stage and whether anything flickers on screen.

**S4.1 result (user + log `script_log_281026_1848.txt`):**
- `HasInterface()` true on `diplomacy_dropdown` (`CallbackId = DiplomacyDropdown`), `offers_panel` (`ComponentCreator`), `button_send` (`Button`), `your/their_offers_list` (`Listview`); error on plain components. **`InterfaceFunction(name)` returns ok/nil for ANY name** (known or not) and changed nothing → can't discover names this way; dropped.
- `add_remove`: the click on the NAP / trade agreement action **added the term** (in the log 0.1–0.2 s later; user saw it after "a second or two"), but the script gave up before it appeared: `cm:real_callback(fn, 0)` re-ran 10 times **within the same frame**. → Use a timed poll (S4.2: every 33 ms, up to 3 s). Rule: `real_callback(…, 0)` is not "next frame".
- **CORRECTION — the bonus is added once per COMPONENT, not once per deal.** Military access (bilateral, both columns) = one component → +1000. Military access −15.5 + NAP ≈ +1.2 with +1000 applied → **1985.7 = −14.3 + 2×1000**. → Put the item value on exactly **one** component that is in the deal (one effect per component, value only on that one) or divide by the number of distinct components. Term → component mapping needed (trade_agreement → `TRADE_AGREEMENT`, nonaggression_pact → `NON_AGGRESSION_PACT`, soft_access → `MILITARY_ACCESS`, defensive/military alliance, peace, trade_regions → `OFFER/REQUEST_REGION` by column, …; payments inside bigger deals may not count as gift components — see S1).

**S4.2:** only the add_remove stages (+1000 / removed), timed poll for the new term row.

Discussion (2026-10-28): user thinks the "per component" effect is just native cascading (a desirable treaty lifts the whole deal, like gold or a settlement) and only the item value needs tuning. Claude: native gold is one term counted once; our bundle adds V to **every** component, so each extra demand is cheaper by V (a demand cheaper than V becomes a plus) → exploit; fix = V on one component only. **S4.3** (user wants to check by hand with a realistic value): stages +50 (no refresh) → removed → +50/add_remove → removed/add_remove.

**S4.3 result (user + logs `script_log_281026_1913.txt`, `_1923.txt`, vs Bonerattlaz):**
- **add_remove WORKS as a refresh:** peace deal shown −24.1 with +50 applied → script adds NAP and deletes it → number **25.9** (= −24.1 + 50), deal unchanged. User: the added term itself is not noticeable, but **the action button row below is rebuilt completely and that is visible**.
- **Per-component confirmed with +50:** intermediate state peace + NAP: **−26.1 with the bundle vs −126.1 without → +100 = 2 × 50**; peace alone: +50. (The user's impression "it doesn't add another 50" came from manual testing; the logged numbers show the doubling.)
- Bug: after `delete_button:SimulateLClick()` the row is destroyed; `delete_button:CurrentState()` then returns no value → `tostring` error (logged, harmless; fixed in S4.4).

**Decision (user, 2026-10-28): no script clicking of the deal (add_remove rejected: the action row rebuild is visible). Instead "paint" once:** right after we change the bundle, write the corrected number ourselves; the next native recalculation overwrites it with the real value. (Earlier "no redrawing" applied to redrawing everywhere all the time; a one-off paint until the next native recalculation is accepted.)
Claude's note: with the item value on **one component already in the deal**, the action-button badges don't change (other treaties don't get the bonus; the treaty in the deal has no button) → only the deal number + Send need painting.

**S5.1 (2026-10-28, awaiting test):** stages +50/paint → removed/paint → −50/paint → removed/paint. E3c (forced Send) switched off — S5 sets Send. State: `s5_applied` (bundle on the player), `s5_included` (bundle the native number contains), `s5_native_text` (last number the game wrote), `s5_painted_text`. A 33 ms watcher: a label text that is neither ours nor the last native one = native recalculation → `included = applied`. Paint = native + (applied − included), formatted `%.1f`, label state `positive`/`negative` set **before** `SetStateText` (each state has its own text); while painted, Send is forced active/inactive by the sign. Empty deal → no paint (placeholder "10"). Known gap: if a native recalculation writes exactly the painted text, it isn't detected (probe only).
Test: ONE native term (e.g. peace / military access) → stage +50/paint → number +50 at once, colour + Send follow the sign → add/remove a term by hand → native number takes over (log "native number … contains bundle 50") → removed/paint → −50 → … → −50/paint on a positive deal → Send greyed?

User (2026-10-28): the badges above the action buttons are the AI's view of **"current deal + that treaty"** (the scales move with every term), so the item value shifts all of them → paint them too. (Claude's earlier claim "badges don't change" assumed standalone treaty values — withdrawn.)

**S5.2 (awaiting test):**
- **Item value on ONE component in the deal** (like the real design): the custom bundle keeps `items_trading_item_value_all` at 0 and gets `add_effect(<S1 single-component effect>, value)` for the first deal term that is peace (`items_trading_s1_deal_eval_peace`), trade agreement or NAP. No such term → nothing applied (logged).
- Paint = deal number **and every visible badge** (`list_possible_actions > <action> > label_success_chance_for_action`, states `positive`/`negative`, integers) shifted by the same delta; badge natives remembered per action id, cleared on a native recalculation. On a native recalculation the log lists the game's own badges 0.2 s later → compare with what we painted.
- Bundle read-back logs every effect key=value.
Test: deal with **peace, trade agreement or NAP** as the only term → +50/paint: number and all badges +50 at once → change a term by hand → log "native badges" should equal our painted ones (if the item value really counts once in each badge) → removed/paint, −50/paint (Send greyed if negative).

### 7.0.16 Where our deal row lives — test L1 (2026-10-28)

Problem: outside the native `list_box` (0.4.1) our row overlaps native terms from 2 terms on; inside it (0.4.0) removing a native term crashed. Options discussed: (1) back into `list_box`, disguised; (2) fixed slot at the top of the column, native list moved down / shortened, compact fixed-height row (item icons, full numbered list in the tooltip); (3) compact row in the current place (half measure). **User: option 1 first.**
Unknown: does the native code trip over *any* foreign child, or over child ids it looks for (`diplomacy_button`, `delete_button` — our 0.4.0 row had exactly those)?

**L1.1 (debug, awaiting test; S2/S5 switched off meanwhile):** our button = next stage, closing our panel applies it, into `your_offers_list > list_box`:
1. `plain` — `items_trading_list_probe_plain.twui.xml`: one plain component, no children, no callbacks (parchment image, 222×40).
2. `renamed` — `items_trading_list_probe_row.twui.xml` (built with `tools/build_offer_row.ps1 -RenameChildren`): the deal row with children `items_trading_row_button`, `items_trading_row_title`, `items_trading_row_items`, `items_trading_row_delete`.
3. `removed`.
Logs the list children with position/size after each stage, logs when the game removes a probe (list rebuild), logs clicks on the probe row's button / delete.
Test (throwaway save, may crash): after stage 1 **add and remove a native term by hand** → crash? Then stage 2, same. Also: does the probe stay in the list, scroll with it, sit after the native rows?

**L1.1 result (user + log `script_log_281026_1947.txt`) — PROVEN:**
- **Native list rebuild = destroy all children of `list_box` and recreate the term rows.** The plain probe (no children, no callbacks) sat in the list (@450,620, 222×40) and was simply destroyed when the user added a term (log: "is gone … now: diplomatic_option_soft_access"). **No crash.**
- The row with **renamed** children → **crash** on the same rebuild. → Child ids are NOT the cause. Difference to the plain probe: children **with callbacks** (`Button` on the row button; the `delete_button` template instance `round_extra_small_button` with `Button`, `StatePropagatorCallback`, `CallbackAnimTrigger`). HYPOTHESIS: the native rebuild crashes when it destroys a foreign component that has callbacks / template instances.
- Lua gets `ComponentLClickUp` for components **without any callback** (logs show clicks on `root`) → a callback-free row can still be clickable for us.

**L1.2 (awaiting test):** row built **without any callbacks and without template instances** (`tools/build_offer_row.ps1 -NoCallbacks` → `items_trading_list_probe_bare.twui.xml`; delete = plain image component `items_trading_row_delete` with round button + cross images; only text left with "callback" is the layout comment). Debug stages: bare → removed. Test: stage bare with a native term in the deal → add and remove native terms by hand → crash? Does the bare row get destroyed on rebuild (log "is gone"), do clicks on `items_trading_row_button` / `items_trading_row_delete` reach Lua?
If bare survives: the real row is callback-free inside `list_box`, recreated by the watcher after every native rebuild (like our action button). If it crashes: fixed slot outside the list (option 2) or a plain spacer in the list + our row drawn over it.

**L1.2 result (log `script_log_281026_1956.txt`): CRASH** — bare row in the list (@450,620, 250×80), user clicked a treaty action → crash. → Callbacks are not the (only) cause either. What survives: **a single component without children** (L1.1 plain). What crashes: a foreign component **with child components** (with or without callbacks). Rule: **only childless components may live in a native deal `list_box`.**
Remaining options: (a) **spacer + overlay** — a childless, invisible spacer (size of our row) in `list_box` reserves the place and scrolls with the native terms; our real row lives in the column (no crash there, 0.4.1) and is moved onto the spacer's position by the watcher, hidden when the spacer is outside `list_clip`; the spacer is re-added after every native rebuild. (b) fixed slot at the top of the column (option 2).

### 7.0.17 DECISION: Plan B — our own items deal in our panel (user, 2026-10-28)

User: "workaround on workaround, any patch or other mod will break it" → **stop integrating into the native deal.** Our panel becomes a complete deal screen of its own (former option D). Native deal rows, the item-value bundle, painting, Send control, carrier ideas are all **dropped**. Kept: our action button as the entry point, the item lists / selection, the knowledge of accept/reject events, goodwill after a trade.

User wishes / questions:
1. Bigger panel that slides in like the faction selection panel, so more than 3 items fit. (DOC: `faction_panel` in `diplomacy_hud.twui.xml` is 850×475, docked Bottom Center, with `show` / `hide` animations: offset +387 → 0 in 500 ms Cubic Out, back in 500 ms Quadratic In. Our panel is 760×365 like `trade_regions`.)
2. Gold in the exchange, on one screen.
3. A deal chance number bottom right, styled like the payments one (`label_payment_success_chance` in `diplomacy_hud_payments.twui.xml`, `label_deal_success_chance` with states `positive`/`negative` in the offers panel).
4. How the player-to-player transaction works: confirmation? separate screen? how AST does it.

Answers / decisions (user, 2026-10-28):
1. The faction panel does not slide in by itself — **the player drags its edge to enlarge it**. DOC: `faction_panel_top > button_enlarge_br` (21×21, `icon_resize.png`, docked Top Left, offset 12,12) with the **generic** callback `ResizeDragHandle` (area Common in `callback_documentation.html`; user properties `min_scale` 0.7, `max_scale` 2.0, `uniform_scale` 0 = keep aspect or not). Can be copied into our panel; open: which component it resizes and whether our columns/lists stretch with it. **Back up before changing**: done → `backups/diplomacy_hud_trade_magic_items.before_plan_b.twui.xml` and `backups/items_diplomacy_trading.0.4.1.lua`.
2. **Gold: one control** — offer / demand toggle + amount with arrows (like the native payments panel: `buttongroup_offer_demand > pay_offer / pay_demand`, `amount` with `NumericalInput`), since gold only moves one way.
3. Tooltip texts of the chance number will be rewritten to explain our item parameters.
4. Player-to-player confirmation: **postponed**, to be discussed when we get there.

**Cleanup (2026-10-28):** debug file reduced to an empty skeleton (old file in `backups/items_diplomacy_trading_debug.L1.2.lua`); main Lua: deal rows, UI state logger, item list dump, vanilla Trade Settlement logger and `ad_get_subpanel_group` removed; DB effect/bundle tables, their loc lines and all test layouts deleted.

**Plan B step 1 — bigger standalone panel (0.5.0, awaiting test):**
- Finding: our panel had **no background of its own** — the frame was the native `subpanel_group` (760×365, images `panel_back_tile`, `panel_back_border`, `panel_back_top`, `parchment_texture` with 9-slice margins).
- Layout (`tools/build_panel_plan_b.ps1`, input = the pre-Plan-B backup): `trade_magic_items` gets those 4 images itself, size **850×475** (faction panel size); columns +110 px (`offer_demand_parent` / `list_offers` 230→340, `list_clip` / `list_box` 181→291); copy of `button_enlarge_br` (callback `ResizeDragHandle`, top left) as a child of our panel.
- Lua: the panel is created in **`diplomacy_dropdown`** (not `subpanel_group`); open = `offers_panel` hidden + panel visible, close = reverse; `subpanel_group` untouched. Temporary log "Panel size: …" (panel, `offer_demand_parent`, `list_offers`, `list_clip`, `list_box`, `vslider`) whenever the panel size changes — to see what the drag handle does.
- Open questions for the test: position/look of the bigger frame; does the vertical slider fit the taller list; does the handle resize our panel, and do the columns follow (if not → Lua relayout on size change).

**Test of 0.5.0 (user + log `script_log_281026_2052.txt`):** the bigger panel with its own frame works; **the handle resizes the panel** (log: 850×475 → up to ~1093×850, clamped by the screen), but **both width and height**; the button plaque moved/resized with it; **children did not follow** (columns 350×340, `list_clip` 292×291, `vslider` 20×121 unchanged). User: "experiment successful if we can finish it".
**0.5.1 (awaiting test):**
- Layout (build script): panel `allowhorizontalresize="false"` (height only); `both_buttongroup` `allowhorizontalresize`/`allowverticalresize="false"`; handle `min_scale` 0.7 → **1.0** (never smaller than the default). Build bug fixed: the here-string dropped the line break before `</trade_magic_items>`.
- Lua `PANEL HEIGHT` section: on every height change (watcher) the extra height over 475 goes into `offer_demand_parent`, both columns (340 + extra), `list_clip` (291 + extra) and `vslider` (clip − 60, vanilla ratio 181/121) via `SetCanResizeHeight(true)` + `Resize`. The last height is remembered (Lua session only) and restored on the next open. Log "Panel height N" per change.

**Test of 0.5.1 (user, screenshots):** width lock works, but 850 leaves black gaps beside the columns → user wants the old width. When the panel was resized, the list moved up over the column title and behaved oddly. User asked whether the full list could sit in the collapsed panel and simply be revealed — answer: no; the handle only resizes the panel (content docked to the top moves with the top edge); a clipped full-size list would have a scroll range bigger than the visible part, so the lower items couldn't be reached until the panel is expanded. Fallback wish: a bigger default height (≈ 6 items).
**Cause of the shifting list (Claude):** `uicomponent:Resize(w, h)` resizes the children too by default (3rd parameter "resize children"); our explicit sizes for `list_clip` / `vslider` fought with that scaling.
**Test of 0.5.2 (user, screenshots at min and max size):** the list now behaves "many times better". Remaining: the dark backing behind the columns scales wrongly / slides. Wish: smaller minimum, about 4 items.
**0.5.3 (awaiting test):** the panel's state images keep their layout size when the panel is resized — the parchment (4th image, fixed 739×451, docked centre) slid. Lua now reads every state image size at creation (logged as "Panel defaults: … images i=WxH") and on each layout resizes the images ≥ 100 px high by the same height delta (`SetCanResizeCurrentStateImageHeight` + `ResizeCurrentStateImage`, 0-based index); the 55 px top bar keeps its size. Columns may now also shrink (negative delta). Handle `min_scale` **0.78** (555 → 435: `list_clip` 8 + 4 × 60 ≈ 251 = 4 items).
**0.5.4 (user decision, awaiting test):** instead of shrinking below the default, the **default is the smallest size = 4 items**: layout **760×435** (columns 300, `list_clip` 251 = 8 + 4 × 60, parchment 331), handle `min_scale` back to **1.0**, Lua delta clamped at ≥ 0 again. The background-image follow from 0.5.3 stays (needed when growing).
**Test of 0.5.4 (user + log `script_log_281026_2136.txt`):** works; at the default size the top edge of item 5 shows; the user's preferred tallest size = last logged height **788**.
**0.5.5 (awaiting test):** `list_clip` **241** (row 4 ends at 8 + 4×50 + 3×10 = 238, row 5 starts at 248) → layout **760×425**, columns 290, parchment 321; handle `max_scale` **1.854** (788 / 425), `min_scale` 1.0.
**Test of 0.5.5: OK** ("великолепно") — panel size work done.

**Plan B step 2 — treasury + deal chance (0.6.0, awaiting test):**
- Copied from `diplomacy_hud_offers_panel.twui.xml` by the build script: `dy_treasury` (88×34, `icon_banner.png`, callback **`ContextTextLabel` on `PlayersFaction.TreasuryAmount`** → fills and updates itself, tooltip `{{tr:treasury}}`) with child `treasury_icon` (26×26, docked Center Left External); `label_deal_success_chance` (100×26, `dip_total_holder.png`, states `negative`/`positive`, no callbacks).
- Placement: treasury **top right** (`Top Right`, offset −12,14, anchor 1,0; top left has the resize handle); chance in the bottom bar **right of the OK / Cancel buttons** (`Bottom Center`, offset 110,−14, anchor 0,1). Positions are first guesses, to be adjusted from screenshots.
- The native deal tooltip text is generated by the engine (not in the extracted loc) → our own loc keys `items_trading_deal_chance_tooltip`, `_breakdown`, `_items_offered`, `_items_demanded`, `_gold` (English placeholders, user will rewrite).
- Lua `DEAL CHANCE` section: `ad_show_deal_chance(panel, { total, items_offered, items_demanded, gold })` — state first, then `%.1f` text, tooltip = sentence + "Evaluation breakdown:" + lines with green +x / red −x. On open: placeholder `{ total = 0 }`.

**Plan B step 2b — gold controls (0.6.1, awaiting test; built together with 0.6.0, neither tested yet):**
- User: gold switch + amount on the **bronze bar bottom left** (it doesn't scale).
- Copied from `diplomacy_hud_payments.twui.xml` (generic callbacks only, the panel's `DiplomacyPaymentPanel` is not copied): `buttongroup_offer_demand` → id **`items_trading_gold_direction`** (`ButtonGroup`, Single Selection, Allow None Selected 0; background removed, 100×58, Bottom Left 45,−8) with radio buttons `pay_offer` / `pay_demand` (template `radio_button`, stacked at 2,2 / 2,30) and their labels `once_tx` / `repeatedly_tx` (`RadioButtonText`, 70×26, text set by Lua: loc `items_trading_gold_give` "You give" / `items_trading_gold_demand` "You demand"); `amount` → id **`items_trading_gold_amount`** (`NumericalInput`, MinValue 0, **Increment 100**, width 112 → 80, Bottom Left 185,−20) with the big arrows `l_arrow_amount` / `r_arrow_amount` (docked outside left / right).
- Build-script bug fixed: GUID regeneration also replaced `uniqueguid_in_template` references (would have cut the radio buttons from their template) — those are kept now.
- Lua `GOLD` section: on panel creation labels, default "You give" selected, test `amount:SetProperty("MaxValue", treasury)`; the watcher reads direction (`pay_demand` state contains "selected") and amount (digits of the field text); on change logs "Gold: give/demand N" and refreshes the chance tooltip's Gold line (+N give, −N demand; total stays 0 for now).
- Positions are guesses; the space between the corner ornament and the buttons is ~240 px.

**0.6.2 test (user, screenshots):** war block of our button + its tooltip work (PROVEN). Treasury, chance, gold switch and amount show up; chance tooltip has the payments structure. Wishes / problems: treasury too close to the top wings; chance should sit in the middle of the right bronze bar (much further right, a bit lower); gold switch lower (centred on the bronze bar), a bit left, smaller radios, labels "Give Payment" / "Demand Payment"; total must follow the gold; **the amount field grows in height with the window** (PROVEN: the resize handle stretches children that allow vertical resize).

**0.6.3 test (user, screenshot + log):** amount field no longer stretches (PROVEN: `allowverticalresize="false"` on the copied blocks works); treasury and amount positions OK; chance a little too far right. Radios still 26 px (PROVEN: `dimensions` on a `radio_button` template instance does not shrink its images; ui log reports pay_offer size 123×26). Labels still "You give": the pack held the old loc (UTF-16 "You give" found in `artifact_diplomacy_trading.pack`) — the tsv was not re-imported. **`SetProperty("MaxValue", "6753")` on the NumericalInput from Lua is ignored** (PROVEN: typed / arrowed up to 8800 > 6753; demand unlimited too). Vanilla: MaxValue / MinValue / Increment are context expressions (caravans: `MaximumCargo(...)`), probably read when the callback is built.

**0.6.4 (awaiting test):** radios 18×18 via Lua (`ad_shrink_radio`: Resize + every state's images through `ResizeCurrentStateImage`), switch 120×40 at Bottom Left 28,-6, radios at 1,1 / 1,21, labels 95×18 in `body_10`; chance 218,-10. Amount capped in the watcher by the payer's treasury (`ad_gold_limit`: ours when giving, the target's when demanding, ≥0) — the field text is set back to the cap (HYPOTHESIS: the arrows continue from the text, as typing did in the log).

**User (before testing 0.6.4): no polling for the gold cap — react to the arrows / input instead** (worry: timers vs multiplayer). Answer: the watcher only touches local UI (no model change → no desync; the deal will go to the model once, via `UITrigger` on Propose, and be re-checked there), but events are cleaner. Facts: arrow clicks fire `ComponentLClickUp` and the field already shows the new number then (PROVEN, 0.6.3 log); typing fires no Lua event (PROVEN: nothing in the log). DOC (`callback_documentation.html`): `NumericalInput` derives from TextInput, MinValue / MaxValue are context expressions (used without context object), functions GetValue / SetValue; vanilla caravan cargo field (`cp1_cth_bhashiva_caravans.twui.xml`) has user property **`value_changed_event`** + a `ContextCommandEvent` with `event0` = that event.

**0.6.5 (awaiting test; includes 0.6.4):** gold check is event-only, removed from the 33 ms watcher (`ad_follow_gold` → `ad_on_gold_changed(source)`): on panel open; `AD_GoldClicked` (`ComponentLClickUp` on l/r_arrow_amount, pay_offer, pay_demand, only under `trade_magic_items` via `uicomponent_descended_from`); `AD_GoldValueChanged` (`UITrigger` key `items_trading_gold_changed`). Layout: amount gets `value_changed_event = items_trading_gold_value_changed` and `ContextCommandEvent` (event0 = that, `TriggerUIScriptEvent("items_trading_gold_changed")`). HYPOTHESES to check in the log ("Gold (source): …"): the value event fires for typing (and arrows); the radio state is already switched at `ComponentLClickUp`; arrows continue from the capped text.

**0.6.5 test (user, screenshot + log `script_log_281026_2300`):** radios 18 px + body_10 labels "Give / Demand Payment" look good (PROVEN: Lua `ResizeCurrentStateImage` over all states works on template radios) — move a bit lower / right. Problems and log facts:
- **NumericalInput keeps its own value** (PROVEN): after our `SetStateText("6753")` the next arrow click gave 7100, 7200 … (each capped again → text flickers). Text from Lua ≠ the field's value.
- **value event never arrived** (PROVEN: typing up to 7000 → no "Gold (value event)" line) with `value_changed_event` as a *component* user property. Vanilla caravans have it inside the NumericalInput callback's `child_m_user_properties`, consumed by other callbacks via `event0/event1`; buttons send such events with `UiMsg("cargo_changed")`.
- **switch clicks land on the labels** `once_tx` / `repeatedly_tx` (PROVEN: ui log), not on `pay_offer` / `pay_demand` → our listener missed them, chance colour changed only on the next arrow click.
- User: the right arrow must go grey at the cap (like payments).
DOC (`cco_functions.txt`): `CcoComponent.GetProperty / SetProperty / CurrentState / ChildContext / ParentContext`, global `UiMsg(string)` (UI_UPDATE_MSG event); `common.call_context_command(type, id, expression)` used by vanilla battle scripts.

**0.6.6 (awaiting test):** layout — NumericalInput callback gets `child_m_user_properties`: `MaxValue = GetIfElse(self.GetProperty("items_trading_payer") == "them", CurrentNegotiatingFactionContext.TreasuryAmount, PlayersFaction.TreasuryAmount)` and `value_changed_event`; ContextCommandEvent `items_trading_gold_value_changed` → `TriggerUIScriptEvent("items_trading_gold_changed")`; ContextCommandEvent `items_trading_gold_clamp` → `self.SetValue(Clamp(self.GetValue, 0, <same max>))`; switch at 36,-3. Lua — keeps `items_trading_payer` ("us"/"them") on the field; over the cap → `common.call_context_command("CcoCampaignRoot", "", 'UiMsg("items_trading_gold_clamp")')` (no more SetStateText); arrows `inactive` at the limits (right at cap, left at 0); switch clicks also on `once_tx` / `repeatedly_tx`, direction taken from the clicked id. HYPOTHESES: `self` works inside MaxValue; MaxValue is re-evaluated per change; the value event now fires; UiMsg from Lua reaches ContextCommandEvent.

**0.6.6 test (user + log `script_log_281026_2334`):** switch position perfect; label → "Offer Payment" (as in payments).
- **MaxValue expression on the NumericalInput callback: no effect** (PROVEN: arrows went 6753 → 6853, typed 9100).
- **UiMsg from Lua → ContextCommandEvent works, incl. `self`, `self.GetProperty`, `GetIfElse`, `CurrentNegotiatingFactionContext.TreasuryAmount`, `self.SetValue`** (PROVEN: after the clamp the next arrow click starts from 6753 / 25, i.e. the field's own value changed).
- Arrows: Lua `SetState("inactive")` is undone when the clamp's `SetValue` runs afterwards (user: arrow greys only after back + forward; after a direction switch it never greys) — HYPOTHESIS: NumericalInput re-activates arrows on SetValue.
- Typing + Enter above the cap stays until the next arrow click: no "(value event)" line → value_changed_event on the callback also never reached Lua (which link fails is unknown).
- **Native demand cap ≠ partner treasury** (user: Ice Court payments allowed demanding 3000 while our cap was their treasury 5632). No cco function / campaign variable found for it (searched `cco_functions.txt`, `campaign_variables`: only `diplomacy_smallest_payment`).

**0.6.7 (awaiting test):** layout — one ContextCommandEvent ("cap") on `items_trading_gold_clamp`, `items_trading_gold_value_changed`, `TextInputChanged`: `DoIf(value > max, SetValue(max))`, then `r_arrow_amount` / `l_arrow_amount` `SetState` by value (after SetValue); "notify" ContextCommandEvent on value event + `TextInputChanged` → `TriggerUIScriptEvent`. Lua — sends the UiMsg after every gold event (no Lua arrow states any more); logs `Partner money: TreasuryAmount Income TotalArmyUpkeep` on open (probe for the native demand cap). Loc `items_trading_gold_give` = "Offer Payment".

**0.6.7 test (user + logs `script_log_291026_0919` / `_0932`):** arrows grey correctly now (PROVEN: arrow states set inside the layout command after `SetValue` stick). Typed values above the cap are cut on Enter (PROVEN: `TextInputChanged` reaches a ContextCommandEvent on our field), but no "Gold (value event)" line → **`TriggerUIScriptEvent` from the layout never reaches the Lua `UITrigger` listener** (both value event and TextInputChanged tried) → the chance does not refresh after typing until the next click (open).
- The field itself stops at **100000** (PROVEN: rich save, partner treasury 581232, our cap never reached; arrow stayed active).
- **Native demand cap vs partner treasury (user, payments panel):** Karaz-a-Karak 5658 → 3000; Bonerattlaz 25882 → 7500; Wintertooth 581232 (income 14526, army upkeep 1908) → 10000. Not a fixed share of the treasury; looks stepped with a ceiling of 10000 (HYPOTHESIS; income of the first two not logged yet).
- User question: should such large gold deals be allowed at all, or capped by our own limits / formula? → decision pending.
- **The native "balance deal" (scales) button goes far above the manual cap** (PROVEN, user screenshot 2026-10-29: Trade Settlement offered ↔ Payments **147753** demanded from Ungrim's Karaz-a-Karak; our treasury 541808). So 10000 is only the manual payments-panel cap; deals themselves are not limited to it. Further logged partners: Western Provinces treasury 6056 / income 2410 / army upkeep 8463; Ice Court 658541 / 26332 / 23872 (native caps not reported).
- **Decision (user, 2026-10-29): manual cap = the payer's treasury, no 10000 ceiling** (AI evaluation decides fairness; a "balance deal" button can come after the evaluation formula). The 100000 stop is not ours (no such number in Lua / layout; TextInput's default length limit is 50 chars, DOC) — HYPOTHESIS: NumericalInput's default MaxValue.

**0.6.8 (tested):** layout only — `MaxValue = 9999999` (plain number) on the NumericalInput callback and as component user property → **values above 100000 can be entered** (PROVEN, user). So 100000 was the default MaxValue; a plain-number MaxValue works, an expression does not.

**Decision (user, 2026-10-29): no fixed gameplay ceiling** — the cap is the payer's treasury, fairness is the AI evaluation's job (gold weighed against the payer's wealth). Only a **display limit of 999 999** so 7-digit values never break the window.

**2026-10-29 — next block: the real exchange.** User: tooltip names OK ("Belongs to their characters"); now make the exchange work before the evaluation weights — all selected items and the gold move between the factions; start with the small race-lock test (mirror item, variant D) as proposed earlier.
- User asked why **The Vial of Hashut** is not in the list: `ancillaries_tables` has it as `transferrable = false` (uniqueness 95, `anc_set_exclusive_chaos_dwarfs`) → excluded by our filter `AncillaryRecordContext.Transferrable == true` (decision 2025-10-25 §7.0.4: non-transferrable items are not tradeable). Not because of the race lock.
- **M1 (debug, awaiting test):** first drafted with Wristbands of Black Gold going to Hashut; **user switched it: the player receives a Chaos Dwarf item (Furnace Blast Gem)**, so they can equip it and see that it works (cleaner test). Mirror `wh3_dlc23_anc_enchanted_item_furnace_blast_gem_mitd`: rows copied from vanilla `ancillaries_tables` (faction_set `all`, randomly_dropped `false`), `ancillary_info_tables`, `ancillary_to_effects_tables` (walls-damage "scripted" effect, Hell Hammer spell, wallbreaker — neither the item key nor the scripted effect key appears in vanilla campaign Lua, so effect-based scripts work the same), `ancillary_ownership_content_pack_junctions_tables` (`wh3_dlc23_chaos_dwarfs`), loc (same texts). Generator: `docs/tools/build_mirror_test.js`. On OK in our panel: logs the player's set / `can_equip_ancillary` (original vs mirror) checks, `add_ancillary_to_faction(player, mirror)`, copies + holders after 1 s; the user equips it by hand.
- **M1 result (log `script_log_291026_1132`, user screenshot) — MIRROR WORKS (PROVEN):** Neferata (vampire): in `anc_set_exclusive_chaos_dwarfs` false, leader `can_equip` original **false**, mirror **true**; mirror copies 0 → 1 after `add_ancillary_to_faction`; "Enchanted Item Gained" popup with all 3 effects (wall breaches, Hell Hammer, Wallbreaker); user equipped it, seems to work. → `faction_set` is the only blocker; `can_equip_ancillary` predicts the mirror correctly; variant D is viable.
- Name missing: the pack had no `text\items_trading_mirror_test.loc` (checked the pack's file list) — the loc tsv was not imported, not a key problem. Same pack still had main Lua 0.6.7 and the old main loc.
- **Mirror texts need their own loc rows** (DOC/PROVEN: the engine looks up `ancillaries_onscreen_name_<key>` / `_colour_text_` / `_explanation_text_` by the item key; `ancillaries_tables` has no "text key" column). Our loc is one file for all languages and the copied texts are English → mirrors show English names in every language.
- **Decision (user, 2026-10-29):** accepted — languages matter, but mirrors stay English unless translated by other mods. → Keep all mirror texts in **one separate loc file**, so a translation mod can override just that file. Mirror key = original key + `_mitd` (deterministic). User correction: the key *set* follows vanilla updates (CA adds / removes / renames items) — rows of unchanged items keep working, new items need new rows (English until translated), rows of removed items are harmless leftovers. The generator must be re-run after game updates.

**2026-10-29 — full exchange + mirror generator (user spec):**
- Every ticked item of ours goes to them and every ticked item of theirs comes to us; the gold too. Race-locked for the receiver → the mirror; receiver may own the original → the original (also when a mirror goes back). Holders of the giver's duplicates must keep their copies when a free (pooled) copy is traded.
- Renames: mod files to `diplomacy_magic_items_trading` (main Lua, debug Lua, loc, `diplomatic_actions_tables`); UI element names unchanged. Mirror suffix **`_diplomacy_tradeable`**, mirror table / loc file name **`diplomacy_tradeable_magic_items_mirror`**. M1 test files removed.
- **Generator** `docs/tools/build_diplomacy_tradeable_mirrors.js` (user: must be re-runnable after every patch). Filter = our list filter (category not hidden / general / mount, transferrable, uniqueness group not unique / unique_fusable / rune / scrap / scrap_upgraded) + `faction_set != all` → **637 items, 43 faction sets**. Copies `ancillaries_tables` (faction_set all, randomly_dropped false), `ancillary_info` 637, `ancillary_to_effects` 1699, ownership junctions 27, `ancillaries_included_agent_subtypes` 195 (31 items), `ancillary_to_included_agents` 2; loc 1911 rows; Lua map `diplomacy_tradeable_magic_items_mirror` (original → set). Not copied: `ritual_payload_ancillaries` (143 rows — sources), `ancillary_set_ancillary_junctions` (31 items — a mirror gives no item-set bonus; HYPOTHESIS that adding it would be wrong for "complete set" checks). No rows for these items in `ancillaries_required_skills`, `technology_nodes_to_ancillaries`, `character_ancillary_quest_ui_details`.
- **Item sets for mirrors (user asked 2026-10-29: why not copied? collecting them would be cool).** `ancillary_sets_tables` (key, icon), `ancillary_set_ancillary_junctions_tables` (member → set), `ancillary_set_effect_junctions_tables` (set effects); **no "required count" column** → HYPOTHESIS: a set is complete when all members are worn, so adding mirrors as extra members of the original set would make it need originals + mirrors (broken for everybody). Right way: a separate **mirror set** `<set>_diplomacy_tradeable` with the mirror members, copied effects / icon / loc. Numbers (generator data): 97 sets, **17 have mirrored members**, 11 fully tradeable, 6 also contain a magic standard (category `general` → not tradeable, e.g. `wh3_main_anc_magic_standard_bull_standard`) → such a mirror set could never be completed → skip. No item is in more than one set; no set mixes race-locked and `all` items. Set loc (name / description) is **not** in our Vanilla_files extraction → needed from the user. Scripts keyed on a set (`wh3_dlc27_nor_generic.lua`: `has_ancillary_set("wh3_dlc27_ancillary_set_nor_pillaging")`, Norsca curse) will not fire for a mirror set.
- **Decision (user, 2026-10-29): mirror all 17 sets**, also the 6 with a standard — for consistency (the item showed a set before trading, the mirror must too); they show the bonus but cannot be completed. Generator: mirror sets for every set with a mirrored member. First version gave the 6 standards a never-delivered "set-only mirror"; **user (same day): no banner mirrors — keep the original standard in the mirror set and see how the game handles it** → a member without a mirror goes into the mirror set as the **original key**, so those 6 standards are in two sets at once (vanilla never does that — TO TEST: tooltips of both sets, the original set still completing for its own race). Standards also live in `banners_tables`, `banners_permitted_unit_sets`, `ancillary_types`, `effect_bundles…` — reason not to mirror them. Set keys are referenced only by the 3 set tables (grep of db). Output: item tables unchanged (637 / 1699 / 27 / 195 / 2), `ancillary_sets` 17, set junctions 37 (6 with original standards), set effects 31, loc 1945 (+ `ancillary_sets_name_` / `_description_` from user-extracted `text/db/ancillary_sets__.loc`), Lua map 637. HYPOTHESIS (to test): a mirror set completes and gives its bonus when all mirror members are worn.
- **Modders' answer (2026-10-29):** the only script call that goes around the race lock is `cm:reassign_character(cqi, faction_cqi)` — moves a whole character (with worn items) to another faction (vanilla: Nagash's Mortarchs, Archaon subjugation). Possible use: temp character + item → reassign → unequip to pool → remove the character. Against: HYPOTHESIS the receiver's characters still fail `can_equip_ancillary` (E2W), temp character spawn / death events / feed / limits / MP sync, moves characters not single copies. **Decision (user): rejected — too many places to break; mirrors stay.** Possible separate feature later: trading a hero / lord.
- **0.7.0 test 1 — GAME CRASH (log `script_log_291026_1512`):** Neferata offered Wristbands of Black Gold (pooled), demanded Healing Potion (worn by cqi 2333) + Malignant Totem (worn by cqi 1532) from Astragoth. OK → deal string built and sent correctly; the UITrigger handler started (`Trade executing: …` logged, the line is cut mid-text — the `[out]` stream lost its buffer, so later lines may be lost too). Right after, every UI component is invalid (our watcher's cached `diplomacy_dropdown`, then vanilla `wh_campaign_setup` searches from root) for ~1.2 s, then the game died. No op result line is in the log → the crashing op is unknown. **The pack had no `script/campaign/mod/diplomacy_tradeable_magic_items_mirror.lua`** (pack file list) → no mirror table → originals would go to race-locked receivers (E2.7: such adds do nothing, no crash). New since the last working transfers (T1/T2, M1): the generated mirror tables, especially the **mirror sets with 6 original standards in two sets** — HYPOTHESIS: the engine recomputes item sets on every ancillary change and breaks on an item in two sets. **0.7.1:** `ad_execute_trade` logs `op N: …` before each op.
- **0.7.1 test 2 — CRASH again (log `script_log_291026_1544`), single plain item:** demanded Healing Potion (faction_set all, worn by Astragoth's cqi 2333; same move as the working E2 T1). Pack now had the mirror Lua and still the set tables. Log: OK → `Trading` → `panel closed` → `Trade executing: dmit_trade;I,…healing_potion,2333,0,0` (complete line) → **no `op 1` line** (it is logged before any item call) → UI invalid → crash. Either the `[out]` buffer lost the last lines (test 1 showed a cut line) or the crash is not in the item calls. Differences from the working E2: deal goes through `TriggerCampaignScriptEvent` → `UITrigger` (vanilla does model changes there too, e.g. `wh3_dlc23_labour_move.lua` `treasury_mod`), the OK handler sends UiMsg `items_trading_gold_reset` (amount `SetValue(0)` → value_changed / TextInputChanged layout commands) and hides the panel, `force_remove_ancillary(..., false, true)` (E2 passed false as the 4th argument). **0.7.2 + debug X1:** global `dmit_debug_trade_dry_run` (debug file) → trade logs ops but changes nothing. Crash anyway → not the item calls.
- **X1 result (log `script_log_291026_1556`, X1 dry run confirmed loaded) — CRASH WITHOUT ANY ITEM CHANGE (PROVEN: the item / gold calls are not the cause).** User: the crash comes when **leaving the negotiation with that faction** after the deal, not at OK. Log: OK (Helm of Discord, pooled) → `Trade executing` at 183.9 s → from 184.0 s the watcher's cached `diplomacy_dropdown` fails `is_uicomponent` every tick (~3 s, while the negotiation screen is still open; no `PanelClosedCampaign` before it) → crash at exit ~187 s. No tagged line (`[out]`, `[ui]`, `[interventions]`) after 183.9 s at all although the game ran 3 more s → **the tagged log is buffered and its tail is lost on a crash** (SCRIPT ERROR blocks are written at once) — do not read "line missing" as "code not reached". Odd: `is_uicomponent` is only `tostring(v):sub(1,12) == "UIComponent "` and the message shows exactly that text → the engine object behind the cached component changed / died right after the deal. Remaining suspects (all new in 0.7.0 OK): `TriggerCampaignScriptEvent` with our long string while negotiating, UiMsg `items_trading_gold_reset` (amount `SetValue(0)` on the about-to-be-hidden panel). **0.7.3 + debug X2/X3:** X2 `dmit_debug_trade_direct` → no event, `ad_execute_trade` runs in the click; X3 `dmit_debug_skip_gold_reset` → no reset UiMsg. Test A: X1 on, X2 on, X3 off.
- **X2 result (log `script_log_291026_1609`):** no crash, but the user was **stuck in our panel — OK and Cancel did nothing**. Log: `X2: trade executed directly` → `Trade executing: …` (line cut — buffer lost when the game was closed) → from the next tick every UIComponent fails `is_uicomponent` (cached `diplomacy_dropdown` 1640×, and fresh click components in `uicomponent_descended_from`). With the event path the panel had closed before the breakage; with X2 the breakage comes before the panel-close code → **the UI breaks inside `ad_execute_trade`**, which in dry run is pure Lua (`ad_split`, `ad_log`, `pcall`). The only unusual call there: `ad_split` used `string.find(text, sep, start, true)` (start position + plain). Vanilla `string.split` (`lib_lua_extensions.lua`) never passes a start position — it cuts the rest of the string each time. HYPOTHESIS: the game's Lua misbehaves with that call (e.g. ignores the start) → endless loop growing a table → out of memory → the Lua state breaks (string comparisons fail, hence `is_uicomponent` false although `tostring` shows "UIComponent (…)") → later crash. **0.7.4:** `ad_split` rewritten vanilla-style (2-argument `string.find`, cut the rest), loop capped at 500 parts with an error log. Test B: same switches (X1 on, X2 on, X3 off) — panel should close and no errors.
- **0.7.4 test B (log `script_log_291026_1626`) — FIXED (PROVEN):** the deal (helm pooled → them, totem + potion worn → us) split into 3 ops, all logged, `Trade done`, panel closed, 0 SCRIPT ERRORs, clean diplomacy exit, no crash. → **The cause of all 4 crashes / the dead UI was `ad_split` with `string.find(text, sep, start, true)`.** Rule: **in TWW3 Lua never call `string.find` with a start position / plain flag** — cut the rest of the string (vanilla `string.split` style). No other call of that form is in our scripts. Debug X4: X1 / X2 / X3 all off → next test is the real trade through `TriggerCampaignScriptEvent`.
- **0.7.4 real trades (log `script_log_291026_1645`):** (1) Healing Potion alone (worn by cqi 2333) → **arrived, PROVEN: the full event path works** (`force_remove_ancillary(…, false, true)` + `add_ancillary_to_faction`). (2) Wristbands + Helm (ours, pooled) for Malignant Totem (worn) → op 1 wristbands → Astragoth **as mirror** (pool 1 → 0, the other wearer re-equipped), op 2 helm → Astragoth, op 3 → **crash**. Cause (PROVEN): `Trade executing:` line = exactly 319 chars both here and in the first crash → the deal string after the prefix is **exactly 255 chars → `TriggerCampaignScriptEvent` cuts its string to 255**. Op 3 arrived as `I,wh3_dlc23_chd_astragoth,wh3_dlc29_vmp_neferata,wh3_` (no cqi / counts) → `ad_split(nil)` → crash (HYPOTHESIS: the game's string functions crash on nil instead of raising). Note: the vanilla logger opens / writes / closes the file per line (`all_scripted.lua`) → the tagged log is NOT buffered; a line cut mid-text means the string itself was cut. **0.7.5:** one event per op (`dmit_trade;<op>`), factions as command queue index (`cm:model():faction_for_command_queue_index`), one op per worn copy + one op per pooled key (worn ops first), every event checked ≤ 255 before sending (too long → trade cancelled with an error), ops with a wrong field count or unknown faction are skipped with an error, `ad_split` returns `{}` for non-strings. Unselect log shows the key again.
- **0.7.4 more trades (log `script_log_291026_1651`, before 0.7.5) — PROVEN working:** single items both ways; Furnace Blast Gem (worn, CHD) → Neferata **as mirror**; Wristbands (pooled) → Astragoth as mirror; Malignant Totem (worn) → Neferata as mirror; **mirrors given back → arrive as the originals** (totem / gem mirror → Astragoth as the original keys); item for item both ways; another partner (Caravan of Blue Roses). The 2-for-1 deal with Caravan crashed again: deal string after the prefix **exactly 255 chars**, op 3 arrived as `I,wh3_main_vmp_caravan_of_blue_roses,` (a 244-char deal in the same log arrived whole) → second confirmation of the 255 cut, fixed by 0.7.5.
- **0.7.5 tested (logs `script_log_291026_1724`, `_1733`) — EXCHANGE WORKS (PROVEN):** 8 deals of 1, 2, 3, 5, 6 and **19 ops**, 39 ops in all, 0 mod errors, 0 SCRIPT ERRORs, no crash. User: deals of any size go through; the AI equips the received items on its turn; the player equips the new items (mirrors included) and they give their stats. Debug X1–X3 left in the debug file, all switched off.
- **0.9.1 test (logs `script_log_301026_1423`, `_1446`; user) — PROVEN:** saved values survive a full game restart (records and fading), the trade watch finds new ids at once (`Traded copy found` 0.2 s after the deal: a hidden panel's lists do rebuild, the List callback has `refresh_if_not_visible`), mirrors included. User approved: balance button look, treasury layers, deals frequency numbers. The 2 SCRIPT ERRORs in those logs are a vanilla listener warning (`wh3_campaign_character_initiative_unlocks.lua`), not ours.
- **0.10.3 (user, 2026-11-01; tested, user: exactly the wanted sound). The deal with the AI is finished (user).** the result view of 0.10.2 is approved by the user (log `script_log_011126_1328`: 0 errors, 4 confirms), but `UI_GBL_HUD_Generic_Accept_Confirm` only gave the button sound. Sound event names can be read as plain text from the audio packs (scan of `audio_base*.pack`): `UI_CAM_HUD_Diplomacy_Response_Deal_Accepted`, `_Deal_Declined`, `UI_CAMPAIGN_DIPLOMACY_RESPONSE_ACCEPTED`, `_DECLINED`, `_GIFT_GIVEN`. The deal now plays `UI_CAM_HUD_Diplomacy_Response_Deal_Accepted`.
- **0.10.2 result view (user, 2026-11-01; tested), replaces X6 (never run).** The native answer is `offer_response` (frame, `parchment_divider.png`, 648×184) with `dy_text`, whose **states** `they_accepted` / `they_declined` / `you_accepted` / `you_declined` hold the localised texts and font. Both blocks are copied into our layout (`items_trading_deal_result_frame`, `items_trading_deal_result`, default state they_accepted). After OK our screen stays open: lists, rules line, OK, Cancel, balance button, gold and chance hide, frame and `confirm_trade_magic_items` (tick, centre of the plaque) show; confirm restores the view and closes. Sound `UI_GBL_HUD_Generic_Accept_Confirm` via `cm:trigger_2d_ui_sound` (that is a sound category of the native Accept button; HYPOTHESIS that it plays as an event). `they_declined` is ready for an AI refusal.
- **Deal confirmation, X6 (user, 2026-11-01; awaiting test).** No API starts the native accept flow: our deal is not a native negotiation (`CcoCampaignDiplomacyManager` only opens / lists negotiations). The native answer is drawn by plain components: `offer_response` + `dy_text` (parchment in `panel_diplomacy`, 648×184, no callbacks) and `speech_bubble` + `dy_text` (header, with show / hide animations). Debug X6 shows a text in both after a deal's last op and logs visibility now and 3 s later. Flavoured lines exist in `diplomacy_negotiation_string_options_tables` (key `accept`, per faction group; 14556 rows) and `accept_state_gift`; the engine's choice of group is unknown.
- **0.10.1 (user, 2026-11-01; tested, user: everything seems to work):** balance data merged into the deal manager: 3 files, section DEAL TUNING at the top of `..._deal_manager.lua`, 24 names shared (the screen reads `IGNORE_DEAL_CHANCE`, `DEAL_ACCEPT_SCORE`, `GOLD_PER_POINT`, the rest of the numbers are local). Same checks passed.
- **0.10.0 split into 4 files (user, 2026-11-01; awaiting test), logic unchanged.** `..._balance_data.lua` (numbers), `..._deal_manager.lua` (log, deal memory, evaluation, trade), `..._screen.lua` (the window, including the trade watch), `..._diplomacy_option_button.lua` (action row button, watcher, war lock, diplomacy helpers). Old `diplomacy_magic_items_trading.lua` deleted, copy in `backups/diplomacy_magic_items_trading.before_split.lua`. All files start with `items_trading = items_trading or {}`; 39 of 154 top-level names used across files became `items_trading.x` (`ad_x`) or `items_trading.X` (`AD_X`), the rest stayed local to their file. Load order does not matter: nothing reads another file's field while loading. Checked with luaparse (Lua 5.1 syntax, unknown globals, undefined fields, load-time reads) and line by line against the original: 1833 code lines identical apart from the version. Not yet run in game.
- **0.9.12 (user, 2026-11-01; awaiting test).** Tested OK by the user: 0.9.11 list filters (no runes), OK button, numbers, labels; Deals frequency except the reset after 15 turns (left for later). Big deal bonus: rarity points of both sides ≥ `AD_BIG_DEAL_RARITY` (100) → `STATE_GIFT_MEDIUM` instead of `_SMALL`: +20 falloff 20 (`wh3_tomb_kings`: +15, falloff 15). Chosen when the deal is built, sent in op R, both ways.
- **0.9.11 (user, 2026-11-01; awaiting test).** Rarity 6 / 15 / 36 / 50: each step is ×2 + 20% (×2.4) so trading does not beat crafting inside a faction; crafted stands apart on purpose (more of a unique piece than the next rarity). Belongs to their characters 5 / 10 / 15 / 20. Kept for a later raise: 7 / 17 / 40 / 55.
- **0.9.10 (user, 2026-10-31; awaiting test).** OK button: `icon_initiate_diplomacy.png` and the tooltip of native `button_send` (label `ComponentTooltip_5618a997`). Deals frequency is per faction, not per player (MP): `dmit_faction_deals[faction] = { count, turn }`, both sides of a deal count; 0, 10, 20, 40, 80, 160 (`AD_DEAL_FREQUENCY_FIRST` 10, `_GROWTH` 2). The old `dmit_deal_counts` is no longer read. Prospects: ≥200 +20, ≥150 +15, ≥100 +10, ≥50 +5, ≥25 0, middle −8, ≤−25 −20, ≤−50 −35, ≤−100 −45, ≤−150 −60, ≤−200 −100. Plaque: native `button_set1` has `LayoutEngine type="HorizontalList" sizetocontent="true"` and stretches itself; ours (`both_buttongroup`) is fixed 130 wide with buttons at offsets ±30, no layout engine, same stretchable image (tile, margins 50): a third button needs that engine or a wider state. Rarity values: proposal pending.
- **0.9.9 (user, 2026-10-31; awaiting test):** prefix `mitd_` renamed to `items_trading_` in the Lua, loc, layout build and docs (older notes here use the new name too; `backups/` keeps the old one). Internal events and saved values with `dmit_` are unchanged, so existing saves keep their records.
- **Subtype-limited items out (user, 2026-10-31; awaiting test):** the 31 items of `ancillaries_included_agent_subtypes_tables` left the trade: list filter `AncillaryRecordContext.IncludedAgentSubtypesList.Size == 0` (HYPOTHESIS: works on the record list; if the lists come up empty check this and the subcategory filter), generator skips them, its table copy is gone. List 738 → 707, mirrors 622 → 591, ownership rows 27 → 18, loc 1807. Same-race trading after release: `05_same_race_trading_list.md`; Verminlord items never; Glottkin items yes unless only Glottkin himself can wear them (none of the 9).
- **Character runes out (user, 2026-10-31; awaiting test):** dwarf runes need their own slot, so subcategory `character_rune` is removed from the list (filter `AncillaryRecordContext.SubcategoryContext.Subcategory != "character_rune"`, HYPOTHESIS: empty subcategory passes; if the lists come up empty that is the cause) and from the generator (`EXCLUDED_SUBCATEGORIES`). List 753 → 738, mirrors 637 → 622. Possible later: dwarf-to-dwarf trading of runes. Subcategories of the 753 listed items: empty 737, character_rune 15, banner 1 (`wh3_main_anc_tmb_liche_priest_viziers_kanopi`, arcane item, kept); all others (follower 531, banner 212, banner_rune 12, spell_fragment 8, mark 7, gift 7, engineering_rune 5, poison 4) never reach the list. 31 tradeable items are limited to agent subtypes (`ancillaries_included_agent_subtypes`, copied to the mirrors): Skaven warlock engineering parts (8), Mark of Nurgle items (9), Verminlord weapons, Hef Mist Mage / Sea Helm items, Lexicon of Unlearning, Hail of Doom Arrow, Bow of Loren, Skull Wand of Kaloth; sold to another race they are probably unusable.
- **0.9.8 (user, 2026-10-30; awaiting test):** Deals frequency lasts 15 turns (`AD_DEAL_FREQUENCY_TURNS`), Recently traded stays 10. Text "Items recently traded with this faction".
- **0.9.7 (user, 2026-10-30; awaiting test):** Deals frequency softened: 5, 15, 45, 135… (`AD_DEAL_FREQUENCY_FIRST` 5, `AD_DEAL_FREQUENCY_GROWTH` 3). User approved the payment labels after 0.9.6.
- **0.9.6 (user, 2026-10-30; awaiting test):** same font data on both payment labels, but at width 104 "Demand Payment" looked smaller (HYPOTHESIS: the game shrinks text that does not fit). Labels 116 wide, amount group moved to Bottom Left 203 (was 197) so the text keeps clear of the left arrow. Deal note: `(2 deal, 4 turns ago)`, loc `%d deal`.
- **Deal bonus decided (user, 2026-10-30):** plain vanilla `STATE_GIFT_SMALL`, +10 both ways. The options below are closed.
- **Gift value override REJECTED (user, 2026-10-30):** the mod must not change vanilla balance, so `!!diplomacy_magic_items_trading.tsv` was deleted before any test; the bonus is plain `STATE_GIFT_SMALL` (+10) until the user picks a way to +15. Options found: `STATE_GIFT_MEDIUM` +20 (falloff 20), `STATE_GIFT_SMALL` sent twice (+20, HYPOTHESIS: events stack), `apply_dilemma_diplomatic_bonus` steps -6..6 (line "Recent events involving" is a guess, values not in our extraction: measurable by a test), an event vanilla never fires with its value overridden: `DIPLOMATIC_MARRIAGE` (+20, no script uses it, no marriages in the game; tooltip line unknown), `CARAVAN_SCRIPT` +15 (vanilla value, but line "Caravan wealth" and no `wh3_tomb_kings` row).
- **0.9.4 (user, 2026-10-30; awaiting test).** Gift line confirmed better than Historical relations; bonus +15: no vanilla event gives 15 on that line, so `db/cai_personality_diplomatic_event_values_tables/!!diplomacy_magic_items_trading.tsv` overrides `STATE_GIFT_SMALL` to 15 for all 3 personalities (falloff stays 10). Side effect: native small gifts are +15 too; a mod overriding the same rows may conflict. `CARAVAN_SCRIPT` is +15 but lands on another line and misses `wh3_tomb_kings`. Other mods confirm the override and the meaning of falloff: DingoDiplomacy `!!events_and_decay_speed` raises it so the AI cares "for longer". Amount arrows step 500 (the cap stops at the treasury, HYPOTHESIS: 0 stops the left arrow). No more "-0.0" (`ad_score_text`). Offer / Demand Payment labels: font size 11, category body_12, 104 wide. Deals frequency note: `(deal 2, 4 turns ago)`, number = the last concluded deal.
- **0.9.3 (user decision, 2026-10-30; awaiting test):** the deal bonus is `STATE_GIFT_SMALL` (+10, falloff 10), still both ways. To check: which line of the attitude tooltip shows it ("Gifts given to" is a guess) and how fast it fades.
- **0.9.2 (user, 2026-10-30; awaiting test).** Recently traded = rarity / 2 both ways (`AD_RECENT_*_RARITY_SHARE` 0.5), text "Recently traded with this faction". Tooltip: both new modifiers show "(N turns ago)" when not 0 (the latest item's turn for the sum of items). Belongs: 7 / 10 / 15 / 20. Amount reset moved into `ad_close_trade_magic_items_panel`, so Cancel clears it too; debug X3 removed. Our button is gone while their offer is on the table: `button_accept` `VisibleFromRoot()` (button_set2: `button_counteroffer`, `button_accept`). **Gift rule:** with their items in the deal, positive prospects stop at the price of those items (`math.min(points, price)`), so a good attitude can make an item free but cannot be turned into demanded gold; no new line, the prospects line shows the capped number. Our own offered items can still earn gold. **Sorting:** the List callback had `dont_recreate` (keeps rows, new ones at the bottom); the build script removes it, rows are rebuilt in `sort_func` order (category + rarity). **Diplomatic event now both ways** (user saw +10 on one side only). Model `diplomatic_attitude_towards` does not move within a turn (same value 1 s after, in every log) and no log has a turn passing after deals yet; `Attitude:` line now adds `trending_diplomatic_attitude_towards` (HYPOTHESIS: the value it drifts to). **Decay of Historical relations is NOT measured.** The table has falloff 50 for PAST_EVENT_*, 10 / 20 / 40 for STATE_GIFT_SMALL / MEDIUM / LARGE (equal to their value, HYPOTHESIS: turns or decay). Options for attitude: `cai_add_diplomatic_event` with other events, `cm:apply_dilemma_diplomatic_bonus(a, b, -6..6)`, payload `diplomatic_attitude_adjustment` in a dilemma / incident, `CcoCampaignFaction.DevAdjustRelationsWith` ("a tad dodgy").
- **0.9.1 records by item id (user, 2026-10-30; awaiting test).** User: remember the concrete copy; on a transfer the old id is replaced by the new one, mirrors included. Replaces the key-based record of 0.9.0: `dmit_recent_items[player][partner][item id] = turn`. `CcoCampaignAncillary` has no id field for expressions and the model has no ids, ids come only from the row (`GetContextObjectId`). **Trade watch:** on OK the listed ids of both columns + expected delivered keys per column are noted (deal-maker's client only); the last op (R) rebinds the lists of the hidden panel and re-reads rows after 0.2 s; new ids with an expected key are the traded copies; each is sent as op `N,player_cqi,partner_cqi,item_id`, so the record lands on every client. Copies not found stay in the watch until the panel opens for that partner again (HYPOTHESIS to check: does a hidden panel's list rebuild?). The watch is in memory only: a reload before it resolves loses those records. Known limit: taking a pooled copy recreates the key's other copies of the giver (`force_remove_ancillary_from_faction`), they get new ids and lose their own mark. `AD_RECENT_BOUGHT_RARITY_SHARE` = 1 confirmed (user: full rarity).
- **0.9.0 deal memory (user, 2026-10-30; awaiting test).** Saved in the savegame with `cm:set_saved_value`, written only in the deal event handlers, section DEAL MEMORY. **Recently traded** (shown in the offered and demanded groups, `items_trading_deal_chance_recent`): `dmit_recent_moves[from][to][key] = turn`; a move replaces the move of that key the other way, mirrors count as their original. Demanding an item we sold them: − rarity × `AD_RECENT_SOLD_RARITY_SHARE` (1); offering an item we bought from them: − rarity × `AD_RECENT_BOUGHT_RARITY_SHARE` (1; the user said both "loses value by 2" and "minus by rarity" — 1 makes it worth 0 at first, 0.5 halves it; to confirm). Fades evenly over `AD_RECENT_DEAL_TURNS` = 10: turn 0 100%, turn 5 50%, turn 10 0%. Per partner: selling to A does not touch B. Copies of one key share the record (ids change on trade). **Deals frequency** (`items_trading_deal_chance_frequency`): `dmit_deal_counts[player][partner] = { count, turn }`, minus 5^count (deal 2 −5, deal 3 −25, deal 4 −125, deal 5 −625), `AD_DEAL_FREQUENCY_BASE`; counts every executed deal, one per deal not per item; gone at once after `AD_DEAL_FREQUENCY_TURNS` = 10 turns without a deal. Both enter `points_without_gold`, so the balance button pays for them. Turn = `cm:model():turn_number()`. Saving a table across save / load is DOC, not yet seen in game.
- **0.8.7 (user, 2026-10-30; awaiting test).** The event now goes `cai_add_diplomatic_event(player, partner, …)` (docs: originating, target). User requirement: the bonus must apply right after the deal, not next turn; the log gives attitude both ways before and 1 s after. If it does not move at once → `apply_dilemma_diplomatic_bonus`. Belongs to their characters by rarity: common 5, uncommon 8, rare 12, crafted 15 (`AD_BELONGS_TO_CHARACTER_POINTS`). Blue = rare (`wh_main_anc_group_rare`, uniqueness 130–150, Wristbands 130) was already 20. Green = uncommon (80–100).
- **Persistence (DOC, 2026-10-30):** `cm:set_saved_value(name, value)` / `cm:get_saved_value(name)` — bool, number, string or table of those, saved in the savegame automatically (name without `:`), used by vanilla, MP-safe when set in a `UITrigger` handler (all clients). `cm:add_saving_game_callback` + `cm:save_named_value` / `load_named_value` — same with own callbacks. `io.open` works (vanilla logs), but the file is per machine and not tied to a save: not for game state. `core:svr_save_*` lives until the game restarts; `svr_save_registry_*` survives restarts, per machine.
- **Item instance ids (PROVEN from logs, 2026-10-30):** the row's `CcoCampaignAncillary` object id is per copy (two Dragonscale Shields 1532 / 2708) and stable across save / load (Healing Potion 1310, Wristbands 578). It looks like a save-wide counter: new copies got 3834–3838, the same numbers are other items in another save. **A transfer makes a new id**: we remove the copy and add a new one, and the new id is not returned. The id is UI-only: the model has no id API (`has_ancillary(key)`, no instance list). So an id can tag an item only until it is traded; tracking across a trade must use key + faction (or a scripted id written to a saved table by key and receiver, without telling two copies apart).
- **0.8.6 (user, 2026-10-30; awaiting test).** Round balance button looks right, but its hover glow slid off: the template's glow image is 42 with offset 7,7 (magic_flame material), the flat size 46 broke it → all sizes and offsets now scale from 56 (34, 5.75). Treasuries under the title plaque (some cultures' plaque reaches over them): priority 50 (plaque 60) and placed before `title_plaque` in the hierarchy. **Diplomatic event not seen:** log `script_log_301026_1224`: 5 deals, the event call ran without error, attitude identical on reopening (Empire 182.84, Khemri 18.30) — but **no turn passed** in that session after the deals (last `in_end_turn_camera` at 86 s, deals from 329 s). Open: whether `cai_add_diplomatic_event` applies at turn rollover, and its direction. On every open the log now has `Attitude: they to us X, we to them Y`. Fallback if nothing moves: `cm:apply_dilemma_diplomatic_bonus(a, b, -6..6)` ("directly applies"; steps PENALTY_XXXLARGE..BONUS_XXXLARGE, values in the DB not found yet).
- **Balance button look (user screenshot, 2026-10-30):** the place is right, but the `button_ok` copy is square (`button_basic_*`) with a white hover glow (`button_glow` / `button_edge_glow`). Now the block of template `round_medium_button` itself, written out as a plain component (46×46, Bottom Center 122,0, `icon_makeitwork.png`): the same round images as the native button incl. its hover, sizes in the layout apply. No Lua change. Layout-only rebuild.
- **0.8.5 goodwill (user, 2026-10-30; awaiting test).** After every executed deal the partner's opinion of the player gets +10 that fades: `cm:cai_add_diplomatic_event(partner, player, "PAST_EVENT_POSITIVE_MINOR")`, constant `AD_DEAL_DIPLOMATIC_EVENT`. `cai_personality_diplomatic_event_values_tables`: value +10, falloff 50 (`wh3_default`, `wh3_tomb_kings`), 100 (`wh3_holds_grudges`); _MODERATE +25, _MAJOR +50; loc line of the factor "Historical relations" (HYPOTHESIS). The meaning of `falloff` is not documented — measure the decay over a few turns. First argument = the faction whose opinion changes (vanilla `wh3_dlc26_contracts.lua`, HYPOTHESIS until seen). Sent as the last op `R,partner_cqi,player_cqi` through the deal event (MP-safe). Not limited: repeated small deals stack, the attitude can be farmed; a per-turn limit is a decision for the user.
- **0.8.4 balance (user, 2026-10-30; awaiting test).** Diplomatic prospects by attitude: ≤ −150 −50; ≤ −100 −35; ≤ −50 −20; ≤ −25 −10; between −25 and 25 −5; ≥ 25 0; ≥ 50 +5; ≥ 100 +10; ≥ 150 +15. (The user's list had −50(−20) twice — taken as one tier. Negative steps read as "this bad or worse", positive as "this good or better", the only reading that covers below −150.) **Their gold weighs more:** demanded gold ×2 at ≤ −100, ×3 at ≤ −200 (`AD_THEIR_GOLD_MULTIPLIERS`), regardless of prospects; gold we give stays 1 per 1000. The multiplier is computed from the current attitude on every evaluation and never stored, so it falls back on the same steps as relations improve (user asked). Balance button divides the demand by it.
- **0.8.3 (user, 2026-10-30; awaiting test).** Test of 0.8.2 (log `script_log_301026_1048`, 0 errors): numbers work, need balance later; both treasuries look right, but the partner's sometimes showed **0** after switching factions while the real treasury applied (limit 29926 in the field). → the layout `ContextTextLabel` is gone from `dy_treasury_partner`, Lua writes `partner:treasury()` on every deal refresh (`ad_show_partner_treasury`). **Diplomatic prospects count only with at least one of their items in the deal** (user: they accept our items and even pay, they think harder when giving their own). **Balance button** `items_trading_balance_button` between the OK plaque and the chance: built from `button_ok` (38×38, Bottom Center 122,-4) with `icon_makeitwork.png`, because the native `button_makeitwork` is a `round_medium_button` template instance and templates ignore the instance size. Logic `ad_balance_target`: points without gold < 0 → we pay (ceil), > 0 → they pay (floor), capped by the payer's treasury; grey without items or when the gold already equals the target. Setting the field from Lua: user property `items_trading_balance_value` + UiMsg `items_trading_gold_balance` → layout `self.SetValue(ToNumber(self.GetProperty(...)))`; radios by `SetState`, `items_trading_payer` before the value (the cap reads it). HYPOTHESES to check: `ToNumber` into `SetValue`, the icon on the 50 px button look, the position. X5 switched off.
- **0.8.1 test — main mod did not load (log `script_log_301026_1024`):** `Failed to execute loaded mod file … :44: attempt to perform arithmetic on field 'huge'` — **`math.huge` does not exist in the game's Lua** → no button. A load error shows as `Failed to load mod` in the log, not as SCRIPT ERROR. **0.8.2:** lowest tier = constant `AD_ATTITUDE_LOWEST_POINTS`.
- **X5 result (same log, 38 factions, PROVEN):** `attitude → category / name`: −105…−51.2 → 1 Very Unfriendly; −48.0…−18.7 → 2 Unfriendly; −13.6…9.6 → 3 Neutral; 17.1 → 4 Friendly; 101.4 → 5 Very Friendly. So the category boundaries lie at **−50** (between −51.2 and −48.0), **−15** (between −18.7 and −13.6) and between 9.6 and 17.1 (**+15**, matches `diplomacy_negotiation_attitudes_tables` friendly ≥ 15 / hostile ≤ −15). Unproven: Friendly → Very Friendly (between 17.1 and 101.4, 50 by symmetry), category 0 (Hostile, below −105) and 6 (−150 / 150 are guesses from the threat variables). The user's 25 is not a category boundary in this data (it may belong to treaties). `AD_ATTITUDE_TIERS` boundaries now ±15, ±50, ±150; the points are still Claude's proposal.
- **0.8.1 — two treasuries (user, 2026-10-30; awaiting test).** Ours moved to the top left, right of the resize handle (`dy_treasury` Top Left `56,14`; the handle is 21 wide at 12,12, the icon sits outside the label on its left); the partner's new at the former place (`dy_treasury_partner` + `treasury_icon_partner`, Top Right `-6,14`, `CurrentNegotiatingFactionContext.TreasuryAmount` under the same `CcoStaticObject` context, HYPOTHESIS until seen in game). Tooltip: loc `items_trading_their_treasury` "Their Treasury" set from Lua on panel creation. `build_panel_plan_b.ps1`: `Copy-WithNewId` gives a block a second id and fresh GUIDs.
- **0.8.0 — deal evaluation (user spec, 2026-10-30; awaiting test).** All numbers in the `DEAL TUNING` block at the top of the main Lua. `AD_IGNORE_DEAL_CHANCE = false` (true = test mode: chance ignored, any deal incl. gold alone, as 0.7.5). OK needs ≥ 1 item and total ≥ `AD_DEAL_ACCEPT_SCORE` (0). Rarity by uniqueness group: common 5, uncommon 10, rare 20, crafted 35 (+ offered, − demanded); read from the row: `AncillaryRecordContext.UniquenessRecordContext.Key`. Belongs to their characters: −5 per demanded worn item. Gold: 1000 gold = 1 point (+ give, − demand). **Interpretation to confirm with the user:** "влияние казны / 1000" taken as the gold amount in the deal (Economic value line), not the partner's treasury. Attitude: `partner:diplomatic_attitude_towards(player_key)` by tier (`AD_ATTITUDE_TIERS`, provisional): ≥150 +30, ≥50 +20, ≥25 +10, ≥−25 0, ≥−50 −10, ≥−150 −20, else −30.
- **Attitude investigation (2026-10-30):** the deal evaluation's attitude tiers are engine code, no data table holds them. Found: `diplomacy_negotiation_attitudes_tables`: friendly ≥ 15, hostile ≤ −15 (speech lines only, DOC); `cai_personality_variables`: `ai_threat_score_attitude_threshold_max / min` = ±150 (threat multiplier; matches the user's 150); `confederation_cost_modifier_relation_multiplier` 2; vanilla script steps `wh2_dlc13_empire_politics.lua` ±25 / ±50 / ±100 (matches the user's 25); `CcoCampaignFaction.AttitudeCategory` Int, "hostile->friendly", UI states **0–6** (7 categories) on **5 icons** (states 0–1 very negative?, 2 negative, 3 neutral, 4 positive, 5–6 very positive — image guid order, HYPOTHESIS) + `AttitudeTooltip` (localised name). Script API: `faction:diplomatic_attitude_towards(other_key)`. Tier names (DOC, `diplomacy_strings__.loc`, `diplomacy_strings_string_relationship_*`): **hostile, very_unfriendly, unfriendly, neutral, friendly, very_friendly** (6 names for 7 categories — which category each belongs to is not known yet). Boundaries to be measured: debug **X5** logs every faction met at the first diplomacy open: attitude, category, tooltip.
- **Typed gold FIXED (found 2026-10-30):** layout `TriggerUIScriptEvent` reaches Lua as **`ContextUITriggerEvent`** with `context.string` (vanilla `wh3_dlc29_ulric_decrees_req.lua`), layout `TriggerScriptEvent` as `ContextTriggerEvent` (via the command queue, `wh_campaign_scripted_tours.lua`), Lua `CampaignUI.TriggerCampaignScriptEvent` as `UITrigger`. Our listener waited for `UITrigger` since 0.6.5 — the "never reaches Lua" of 0.6.x was the wrong event name. 0.8.0 listens to `ContextUITriggerEvent`; no layout change.
- **0.7.0 (awaiting test), section TRADE:** OK builds a deal string (`dmit_trade;I,giver,receiver,key,cqi:cqi,pooled_taken,pooled_total;G,payer,receiver,amount`) on the clicking machine — pooled counts come from the UI context (no model call lists a faction's pool) — and sends it with `CampaignUI.TriggerCampaignScriptEvent(player_cqi, deal)`; `UITrigger` handler `AD_TradeExecute` changes the model: worn copy → `force_remove_ancillary(holder, key, false, true)`; pooled copies → note holders, `force_remove_ancillary_from_faction`, re-equip holders with `force_add_ancillary(h, key, true, true)`, add back `pooled_total − taken` with `add_ancillary_to_faction(giver, key, true)`; receiver gets `add_ancillary_to_faction(receiver, original or mirror, false)` per copy; gold `cm:treasury_mod` both ways (capped by the payer's treasury at execution). After OK: selection cleared, amount reset by UiMsg `items_trading_gold_reset` (new layout command `self.SetValue(0)`), panel closes. OK is active with items ticked or gold set; the gold is re-read on OK (typed amounts still do not notify Lua).

**0.6.11 (awaiting test):** user reordered the breakdown: "Evaluation breakdown:" directly followed by Diplomatic prospects / Economic value, then (blank) "Magic items you offer:" group, then (blank) "Magic items you demand:" group. Equipped line renamed to **"Belongs to their characters"** (user: the point is *whose* item it is, not just that it is equipped).

**0.6.10 (superseded by 0.6.11):** chance tooltip regrouped (user, 2026-10-29, texts only, no logic yet): "Evaluation breakdown:", then groups with a blank line before each — "Magic items you offer:" / Rarity; "Magic items you demand:" / Rarity, Equipped by their characters (user's idea: negative modifier, an AI won't part with an item a character wears; name proposed by Claude, user unsure about "Items are belong to character"); then Diplomatic prospects, Economic value (gold placeholder goes here). Lua `AD_DEAL_CHANCE_GROUPS`; loc `items_trading_deal_chance_rarity / _equipped / _prospects / _economic`, `items_trading_deal_chance_gold` removed. User also confirmed the balance-deal button for later.

**0.6.9 (tested by the user, screenshot with 5260.1 chance):** `MaxValue = 999999`; the layout "cap" command uses `min(payer's treasury, 999999)` (nested `GetIfElse`), so the right arrow also greys at 999999; Lua `AD_GOLD_FIELD_MAX = 999999` in `ad_gold_limit`.

**0.6.3 (tested above):** layout: treasury dock_offset -6,14; chance Bottom Center 225,-10; switch 125×50 at Bottom Left 28,-2, radios `dimensions` 22×22 (template instance — HYPOTHESIS: the template's 26 px images may not shrink) at 1,1 / 1,27, labels 95×24; amount 70 wide at Bottom Left 197,-9; all copied blocks (treasury, icon, chance, switch, labels, amount, arrows) get `allowhorizontalresize="false"` + `allowverticalresize="false"` (`Set-NoResize` in the build script). Loc: `items_trading_gold_give` "Give Payment", `items_trading_gold_demand` "Demand Payment". Lua: placeholder score 1 point per `AD_GOLD_PER_POINT` = 100 gold (+ give, − demand); total = gold line until the item evaluation exists.

**0.6.2 (tested above):**
- User: the chance tooltip should follow the native **payments** tooltip (screenshot): sentence, blank, "Diplomatic treaty: 0.6", blank, "Evaluation breakdown:" + lines (Baseline evaluation, Relative faction strength, Diplomatic prospects, Economic value, Trustworthiness, Main threat, Distance), positive values green without "+", negative red. Ours now: same structure, loc `items_trading_deal_chance_total` = "Diplomatic treaty", sentence without "or threatening" (no threats in our deal); breakdown lines still ours (items offered / demanded, gold) until the real fields (rarity …) exist.
- User: **our action button must be unavailable until peace is made** (screenshot: at war, Peace Treaty in the deal → payment etc. are offered again). Lua `AT WAR` section: on every new button and every 15 watcher ticks (~0.5 s) `player:at_war_with(target)`; at war → button state `inactive` + tooltip "title||`items_trading_button_needs_peace`"; back to `active` + normal tooltip at peace; clicks ignored while at war. Button tooltip code moved to `ad_set_button_tooltip(button, body_key)`.

**0.5.2 (tested above):** layout **760×555** (row 50 + 10 spacing, list starts 8 down → `list_clip` 371 = 6 items; columns 420); all our `Resize` calls pass `false` (children keep their size); default heights are read from the panel when it is created (no hard-coded numbers in Lua); handle minimum = the default size.

**User (2026-10-27): goodwill after an item gift/trade is wanted** — `cm:apply_dilemma_diplomatic_bonus(a, b, -6…+6)`, payload `diplomatic_attitude_adjustment(_between)`, or `cm:cai_add_diplomatic_event(from, to, "PAST_EVENT_POSITIVE_MINOR/MODERATE/MAJOR")`. Planned for after the MVP.

### 7.1 How human-to-human diplomacy works in MP (user, 2026-10-24)

When player 1 opens diplomacy with player 2, **player 2 is forcibly brought to the diplomacy screen** showing the offers, and waits for player 1 to propose.

Implications:
- Negotiation is live on two clients at once. Our item terms must be **visible on both screens**, not only transferred at the end → UI state itself must be synced (designed in Phase 4, first tested in Phase 5).
- The receiving player's client must be able to show our "Magic Items" row even though they never clicked our button.

**Multiplayer audit, code + vanilla files only, nothing tested (2026-11-01):**
- **Two native flows (DOC):** `CcoCampaignDiplomacyManager.SentNegotiationList` / `PendingNegotiationList` exist "only in mpc sim turns": proposals wait in lists for the other player's review (`diplomacy_hud.twui.xml`: the list button is trashed when `IsSimultaneousTurns == false`). HYPOTHESIS: the forced diplomacy screen above is the turn-by-turn mode only; to be confirmed by the user.
- **No consent yet (code, 0.10.3):** nothing tells a human partner from a bot. In MP the OK button would take a human partner's items and gold at once, judged by the AI numbers.
- **`cm:callback` from UI code (DOC + HYPOTHESIS):** it is a model timer (`game_interface:add_time_trigger`, lib_timer_manager; "as model updates are synchronised ... so too are model timers"). `diplomacy_magic_items_trading_screen.lua` starts it from code that runs on one client: panel open (line 1339), trade watch (1637), checkbox (1826). HYPOTHESIS: a desync risk in MP, and model time may stop while waiting. `cm:real_callback` (milliseconds) is the UI-side tool.
- **Already fit the MP rules (code):** the trade ops run in the `UITrigger` handler from values in the event string; saved values are written only there; `pairs()` only builds event strings.
- **Unknown until tested:** is `CurrentNegotiatingFactionContext` valid on the second player's client, are `CcoCampaignAncillary` ids equal on both clients, does an event sent by the player who is not on turn arrive at once.
- **Events from the player not on turn (DOC):** vanilla `progress_on_mp_query` sends its answer from the queried player's client with no turn check (lib_campaign_manager).
- **Correction (user):** a battle in MP is a shared event, all players load together. No player is ever alone in a battle while another waits.

### 7.1a Player-to-player deal: agreed design (user + Claude, 2026-11-01)

**Scope:** two players. Three or more were never played and are not a goal. Turn-by-turn first; simultaneous turns afterwards, they are less stable.

**On opening our window** the partner is checked (`faction:is_human()`). AI partner: look, logic and behaviour stay exactly as they are. Human partner: the flow below. A faction in `cm:get_human_factions()` whose player has dropped (the list includes idle humans) must not count as AI (Claude's call).

**Flow:**
1. Human mode: balance button and deal chance hidden; new Counteroffer button between Propose and Cancel (`both_buttongroup` grows to the right only).
2. Propose: the proposer's Cancel is blocked, checkboxes and gold controls are locked, "Waiting on player..." shows. The deal can no longer be changed.
3. The other player's window opens with the same deal: all items, gold, who pays. Columns and gold direction are mirrored (own items on the left).
4. The other player can only look and scroll; checkboxes and arrows are locked. Options: Accept (Propose button), Counteroffer, Decline (Cancel).
5. Counteroffer: that button goes inactive, checkboxes and arrows unlock, the player edits and presses Propose, then step 2 with the roles swapped. **Cancel in this mode = declining the whole deal** (user).
6. Accepted: both see `they_accepted`, both leave freely, the deal is done. The accepting client sends the trade ops.
7. Declined: the proposer sees `they_declined` with `UI_CAM_HUD_Diplomacy_Response_Deal_Declined`, then leaves; the decliner's window just closes (Claude's call).

**Bringing the other player in (Claude's call):** no query between clients is needed, the proposal handler runs on the other player's client and it knows its own screen. `diplomacy_dropdown` open: open our window at once. Another blocking or event panel open (`cuim:get_open_blocking_or_event_panel`): wait until it closes, then continue. Nothing open: force diplomacy with the proposer (`OpenDiplomacyWith`, untested from a closed panel; S3.3 tested it only while diplomacy was open, it closed the panel), then open our window. Vanilla `cm:progress_on_blocking_panel_dismissed` is event-driven but ends in `self:callback`, a model timer on one client, so we write our own listener with `cm:real_callback` (same closing events).

**Rejected or left out for now (user):**
- No timeout, no withdraw, no "deal cancelled" message on leaving. A player who dropped ends the session anyway; a player who left the window is not brought back. Test with the colleague and add only if it turns out to be needed.
- No re-check of the deal on accept: with forced diplomacy it cannot go stale. Known small gap (Claude): while we wait for a blocking panel to close, that player can still spend gold; the gold op then pays what is left.
- Crossed proposals: the first event wins, later ones are dropped, because every client sees events in the same order (HYPOTHESIS, Claude's call: the user has no preference).

**Details:**
- Item ids: the proposal carries key + holder + pooled count (the trade ops need them anyway). Ids of the rows are logged on both clients in the first real test; equal ids may simplify this.
- A proposal takes several events (255 char limit), each with the deal number; the window opens after the last one.
- Human deals keep the diplomatic event (+attitude) but write nothing to the deal memory: no frequency, no "recently traded", no trade watch (AI logic).
- UI donors: `button_counter_offer` (`ui/skins/default/icon_counter_offer.png`, tooltip "Counteroffer||Discard the proposed deal and construct a new one."), `label_waiting_on_response` (`reward_flyer.png`, 232x46). `both_buttongroup` in human mode: width 190 instead of 130, centre +30; buttons at -30, +30, +90 of the old centre. The waiting label starts at the balance button's place (from the chance's place it would stick out about 70 px).
- `get_target_faction` reads the UI context; on the second client it may be wrong, so human mode keeps the partner from the deal event.
- `cm:callback` in UI code (lines above) becomes `cm:real_callback`.

**Testing (user):** one solo run with a switch that makes our window treat an AI partner as a human, then always with the real player.

**0.12.3 test (2026-11-01, simultaneous, logs `script_log_011126_1810.txt` and `_2010.txt`):** no desync, 46 trade ops identical. The offers panel no longer shows behind a forced window (PROVEN). **`CampaignUI.ClosePanel("diplomacy_dropdown")` closes the panel but leaves most of the campaign HUD hidden until a restart (PROVEN, user): never use it for diplomacy.**

**0.12.5 test (2026-11-01, simultaneous, logs `script_log_011126_1847.txt` and `_2047.txt`) — PROVEN:** `CloseDiplomacyPanel` closes the forced diplomacy with the HUD back (`diplomacy open=false, HUD visible=true`, 3 of 3), no `DiplomaticOfferRejected`, the other player's diplomacy stays. 31 trade ops and `deal end` identical, no ERROR or WARNING lines. `Row info refreshed` ran once.

**0.12.6 (2026-11-01, not run yet), from that test (user):**
- The offers panel flashed when the forced window closed: our close showed it for the 100 ms before diplomacy closed. `ad_close_trade_magic_items_panel` leaves it hidden in forced diplomacy, and the watcher keeps it hidden until diplomacy is gone.
- The forced player's lord speaks the partner's phrase (user: Khatep said Thorek's phrase; expected: each lord speaks their own). Claude's fix (voice lock + hidden bubble, 0.12.6) was wrong and is removed in 0.12.7 (user: no work on the sound, the phrase must be spoken by the right lord). OPEN. Facts: our force did not change since 0.12.0 except the check for simultaneous turns, and nothing of ours touches the status panels or the speech. The 0.12.2 log already shows the bubble on the forced client in `faction_left_status_panel` (the layout's `player_attitude` tag points to the player's side); it does not show whose text it was. The speech has no callback in the layout, it is set natively. `M2: speech` lines (0.12.7) log each side's faction, bubble and text.
  0.12.7 log (`script_log_011126_1912.txt`, forced client Exiles, partner Thorek) and screenshots: voices are right, sides are swapped (user). Forced: Thorek's line in the LEFT bubble over Khatep (134.3 s), then Khatep's line "Greetings, Dwarf..." in the RIGHT bubble over Thorek (139.0 s): a two-line exchange. The same player opening diplomacy by hand: only Thorek's line, RIGHT bubble (217, 235, 287 s). `OpenDiplomacyWith` takes no arguments (`Void | Void`), only the faction object, and the partner comes out right. HYPOTHESIS: the proposer's live negotiation makes the forced client the recipient, while the UI draws the first speaker on the left. User checked by hand: a player opening diplomacy with a partner already negotiating gets the lines right, so the swap comes with the forced path.
  Ways into a negotiation: `OpenDiplomacyWith` (ours, in no vanilla layout); `DiplomacyManagerContext.OpenNegotiation` (the invited side, vanilla's `button_pending_negotiations`, "if there is one"; S3.2 closed an already open diplomacy in single-player, it was never tried from a closed panel with a live partner); bots go through the engine, no script command (`cm:faction_offers_peace_to_other_faction` is peace only); by hand: open diplomacy, `faction_row_entry_<key>`, `faction_panel_bottom > button_ok`.
  0.12.8 test (logs `script_log_011126_1939/2139.txt` simultaneous, `1945/2145.txt` turn-by-turn; no errors, turn-by-turn 4 deals) — PROVEN: `OpenNegotiation` opens a closed diplomacy at once with no pending proposal, but the lines are the same as with `OpenDiplomacyWith`: the partner's line in the local LEFT bubble, then the local lord's line in the RIGHT one.
  Rule (user, bots): the disturbed side speaks first. The native pull obeys it: turn-by-turn, the pulled Astragoth's own line stands in his LEFT bubble, and the same line in the RIGHT bubble on Arbaal's client. So the forced client's bubbles follow the "disturbed" order while the lines follow "we called them" (HYPOTHESIS: both commands make the local faction the initiator).
  Offers panel on the pulled player (user: seen at once, jerks and slides in again after the dialogue; user is sure the mod causes it). Claude's "before anything of ours ran" was wrong: the 33 ms watcher and the M2 timers start at diplomacy open. Audit of a pull before our window (`script_log_011126_1945.txt`, 126.8-139.6 s), writes to native UI: none (`Item trading NOT available`, so no button is created; `keep_offers_hidden` returns; nothing else runs). Running there: button watcher (33 ms, reads the action list, `button_accept`, deal lists), `follow_panel_height`, M2 snapshots, `m2_watch_native` every 0.5 s (0.12.2) with `M2: speech` reads (0.12.7), an M2 ping through `TriggerCampaignScriptEvent` at diplomacy open from the player not on turn (arrived 2.4 s later). `offers_panel:SetVisible(true)` runs only when our window closes. `Visible` says nothing about the panel's slide animation. 0.12.9 run: `M2_MP_LOGS_ENABLED = false` to separate the M2 timers and ping from the mod's logic; next suspect the button watcher while the pull's dialogue plays.
  **PROVEN NATIVE (user, 2026-11-02, vanilla game without our mods):** the pulled player sees the offers panel at once and it slides in again after the dialogue. Not ours, nothing to fix.
  Swapped lines on simultaneous turns: there from the start (user), not noticed in the first test. User: in vanilla, a sent proposal shows the other player an invite under `button_diplomacy` ("Неоконченные переговоры" / pending negotiation, faction + player name) that leads into the negotiation. That button is `ui/templates/button_pending_negotiations.twui.xml`: shown only with simultaneous turns, its list is `CampaignRoot.DiplomacyManagerContext.PendingNegotiationList` (rows have a faction context) and a row runs `CampaignRoot.DiplomacyManagerContext.OpenNegotiation(this)`: the same command 0.12.8 called. An entry in that list exists only after a real native proposal is sent (Send with native terms); no context or script command creates one (`CcoCampaignDiplomacyManager` has only `OpenNegotiation`, `NegotiationForFaction` and the two lists; `CcoCampaignNegotiation` only `TargetFactionContext`). Without an entry `OpenNegotiation` starts a new negotiation from our side, hence the same swapped lines.

  0.12.9 (not run yet): the force goes in the way a player does, once per proposal: `faction_buttons_docker > button_diplomacy`, `faction_row_entry_<key>`, `faction_panel_bottom > button_ok` (paths from the logs), 0.3 s apart, our window 1 s after the last click, also if the negotiation did not start. Diplomacy closed after 3 s (user): `OpenDiplomacyWith`. Idea if the lines are still wrong: stop before the row: our window needs only the diplomacy panel, so no negotiation, no lines, no offers panel.
  User (2026-11-01): the path by hand shows every screen to the player, not wanted. Claude's earlier "the swap was there in 0.12.2 too" has no proof: that log only shows a left bubble, which the correct native pull also has; the text was not logged before 0.12.7. Open options: carry the text into the right bubble with `OpenDiplomacyWith` (voices stay), leave it, empty diplomacy without lines. First a check: `backups/old_0.12.0_force_test/` = screen and deal manager of 0.12.0 (force identical to 0.12.2) + the current option button without the `keep_offers_hidden` call; packed in place of the three current files for one simultaneous-turns run, to see whether the old code shows the lines right. Its four panel texts stay the layout's English ones (they come from loc only since 0.12.10).
  0.12.11, MP test build instead (user, 2026-11-02): current code, force as in 0.12.0 (`OpenDiplomacyWith`, by-hand path removed; the check for simultaneous turns and `CloseDiplomacyPanel` stay), the offers panel only hidden when our window opens and shown when it closes, always (`keep_offers_hidden` removed, the forced-diplomacy exception on close removed; user: showing it on close is the base mechanic). Not run; superseded by 0.13.0.
  **0.13.0, native invite through a 1-gold carrier (user's idea, 2026-11-02; reverses the 2026-10-27 "no carrier" decision; simultaneous turns only; not run yet):** screen file, section NATIVE INVITE.
  - Proposer, on a fresh Propose (`ad_live_deal == nil`) with simultaneous turns: if the native deal is empty, clicks behind our window `list_possible_actions > diplomatic_option_payment`, then in `diplomacy_hud_payments` `ButtonGroup_offer_demand > pay_offer`, `ButtonGroup > pay_once`, amount `amount_treasury > amount` via `InterfaceFunction("SetValue", 1)` (unknown interface, logged), else one `r_arrow_amount` step (the field's increment, maybe more than 1), then `ok_payments`, then `button_set1 > button_send`; 0.3 s between steps. Our own events go out at once as before.
  - Other player (0.13.1, user): not forced. Polls every 0.25 s up to 5 s for `NegotiationForFaction(proposer)`; found: nothing is opened, the player opens the invite from the notification under the diplomacy button and `AD_HumanDiplomacyOpened` puts our window on top (`ad_invite_pending` -> `ad_invite_opened`, the diplomacy then counts as forced: hidden offers panel, carrier rejected and diplomacy closed at the end); not found (carrier failed): nothing, the fallback `OpenDiplomacyWith` is commented out for the test (user: it works as planned or not at all). No timeout while the player has not opened it. `keep_offers_hidden` is back for forced diplomacy (the offers panel would show the carrier's Accept), and closing our window does not show the offers panel in forced diplomacy.
  - End of the deal on that client: `button_set2 > button_cancel` rejects the carrier, `CloseDiplomacyPanel` 0.5 s later.
  - **0.13.1 run (logs `script_log_021126_1627.txt` Exiles, `_1827.txt` Thorek), user: it works, but oddly.** No errors, all deals done. Facts: (1) first carrier: `button_send = inactive` when clicked, no invite; `amount_treasury > amount` not found (amount is a child of `payment_parent`), the field kept its native suggestion (user: not 1 gold). (2) `NegotiationForFaction(proposer)` was valid at once every time, before any Send (our events arrive ~0.5 s before the native Send): false positive, the first time the player had to open diplomacy by hand. (3) The proposer's offers panel comes up behind our window with each carrier. (4) The receiver's reject closed the proposer's diplomacy 1 s later (382.6 -> 383.3 s); our panel is not destroyed with diplomacy, so the proposer saw the old result view when he came back (438.2 s). (5) A carrier is not rejected when the receiver was already in diplomacy (no invite opened): Thorek 255.1 s.
  - 0.13.2 (not run yet): Send is clicked only when the payment is in the native deal and Send is active, retried every 0.3 s up to 10 times; amount found as `amount` and set by `common.call_context_command("CcoComponent", <its CcoComponent id>, "SetValue(1)")` (unproven, logged); invite = `PendingNegotiationList.Filter(TargetFactionContext.FactionRecordContext.Key == <proposer>).Size > 0`; `keep_offers_hidden` also on the proposer while our window is open after a carrier; diplomacy closed with our window open hides our window and shows the offers panel again (`items_trading.hide_window_after_diplomacy`, diplomacy-closed listener). Open, for the user: the unrejected carrier (5) and the reject closing the other side (4).
  - User: only the invited player can reject a native proposal, the proposer cannot withdraw it with simultaneous turns. Decided (user, 2026-11-02): (4) stays: the invited player rejects when leaving, the proposer's diplomacy may close about 1 s after his result appears. (5): 0.13.3, simultaneous turns only, every client sends `S,0,from,to,1/0` to the other humans when its diplomacy opens / closes; the proposer sends no carrier when the partner's diplomacy is open (that partner gets our window at once). Gap: the partner opens diplomacy in the second the carrier is on its way.
  - **0.13.3 run (logs `script_log_021126_1712.txt` Exiles, `_1912.txt` Thorek), user: better** — PROVEN: no errors; the invite is found (`pending 1`) and opened by the player from the notification; amount 1 (`amount was 1`; the `CcoComponent` id is nil, so `SetValue` did nothing, the field already held 1); Send on the first try; a click on a hidden component works (the hidden Send went through). Still seen (user): the payments panel with the treasury flashes at the proposer while the carrier is built; the proposer's offers panel flashes when our window closes, the reject closes his diplomacy 0.5 s later.
  - 0.13.4 (not run yet): the payments panel is made transparent (`PropagateOpacity(0, true)`) in the same frame as the payment click and again 0.3 s later, back to 255 after Send (opacity, not visibility, so the game's own show / hide is untouched); the proposer who sent a carrier does not get the offers panel back when our window closes and leaves diplomacy with it (`CloseDiplomacyPanel`, like the invited player); `ad_carrier_sent_here` now lasts until diplomacy closes. Which panel flashed is not proven (user asked): the 0.13.3 log shows the payments panel visible ~0.5 s and the offers panel coming up three times (after the payment OK, before and after Send), each hidden only by the 33 ms watcher; 0.13.4 also hides the offers panel in the frame of each of those clicks.
  - **REJECTED (user, 2026-11-02): the 1-gold carrier / hidden native proposal and all of it removed in 0.14.0** (code kept in `backups/*.carrier_0.13.4.lua`). Back to method 1: simultaneous turns, `OpenDiplomacyWith` forces the other player into diplomacy after any open panel is closed (the bring-in waits for blocking panels), `keep_offers_hidden` hides the offers panel while forced, our window on top; at the end the forced player's offers panel is not shown again and `CloseDiplomacyPanel` closes diplomacy; the proposer gets the offers panel back when our window closes. Known and accepted: the forced client's lords' lines are swapped. Kept from that work: `items_trading.hide_window_after_diplomacy` (our window hidden when diplomacy closes under it).
  - **0.14.0 runs (logs `script_log_021126_1753` / `_1953` simultaneous, `_1808` / `_2008` turn-by-turn), user: the flow is good** — PROVEN: no script errors in all four; trade ops identical on both clients (12 simultaneous, 25 turn-by-turn); 3 forced closes with the HUD back. **Released as MVP 1.0.0 (user, 2026-11-02):** temporary logs removed (M2 / M3 debug file, `ad_log_hud`, `ad_log_partner_money`, `ad_log_attitudes`, the `dmit_debug_trade_direct` / `dmit_debug_trade_dry_run` switches), the debug file and `script/enable_console_logging` out of the pack (copies `backups/*.removed_for_release*`, sources before the cleanup `backups/*.before_release.lua`). Known issues accepted by the user: (1) simultaneous turns: a receiver who is in diplomacy at that moment may be stuck on a wrong window after the deal; (2) turn-by-turn: if the caller proposes too fast, the offers panel pops up behind the other player's window (native after-dialogue animation); (3) the forced client's swapped lords' lines.
  - Risks to watch: the native Send may end the proposer's negotiation screen (and our waiting window with it); the reject fired `DiplomaticOfferRejected` before and closed the other side's diplomacy (log 0.12.2), so the proposer's result view may close with it; clicks on hidden native panels may do nothing; a carrier stays pending if the other player was already in diplomacy (not forced, nothing rejects it).

- Items bought by the other player still counted in an open window: after every deal's last op (`items_trading.on_deal_done`, on every client) an open, unlocked window rebuilds its rows 300 ms later, drops ticks of items that are gone and refreshes the chance.

**0.12.5 (2026-11-01), replaces 0.12.4's clicks through native buttons (never run):**
- The forced diplomacy closes with the context command `CloseDiplomacyPanel` ("Closes the diplomacy panel if it's currently open", DOC, not in vanilla Lua), called like `UiMsg` through `CcoCampaignRoot`, 100 ms after the click. 1 s later `IsHUDVisible` is logged, nothing more (user: no `ToggleHUD`). HYPOTHESIS: it restores the HUD and does not touch the other player. A native cancel by the forced player did fire `DiplomaticOfferRejected` and closed the other player's diplomacy at once (log 0.12.2); check that the command does not.
- Native close paths seen in the logs: `button_set1 > button_cancel` leaves the negotiation, `faction_panel_bottom > button_cancel` leaves the faction list, `button_set3 > button_accept` confirms an answer.
- Forcing is bound to simultaneous turns: `common.get_context_value("IsSimultaneousTurns")` (true / false in the logs). Turn by turn the window waits for the native pull.

**0.12.4 kept:**
- Bug found in the 0.12.3 log, not by eye: with the window open, another player's deal with the same AI changes the native list, new rows have no `ad_row_info`, so the item gets key nil, 0 points, and the trade skips it (`selected item without a key skipped: 580`, 14 WARNING lines). A checkbox on an unknown row now rebuilds that column's row info (`ad_refresh_row_info`).

**Simultaneous turns test, 0.12.2 (2026-11-01, Exiles of Nehek + Thorek, logs `script_log_011126_1745.txt` and `_1945.txt`) — PROVEN, user: everything transferred as it should:** `simultaneous=true`, two factions in `whose_turn`. No desync: trade ops and 6 `deal end` lines identical, no ERROR or WARNING lines. `OpenDiplomacyWith` through `common.call_context_command("CcoCampaignFaction", cqi, ...)` opens a closed diplomacy at once (`Bring in: forcing diplomacy`), the window follows 0.3 s later; a native `DiplomaticOfferRejected` shows up on both clients when native negotiations are left (from the game, harmless so far). Not seen in the log: crossed proposals (no `dropped` line), a proposal waiting behind another panel.

**0.12.3 (2026-11-01, not run yet), from that test (user):**
- Forced diplomacy: the native offers panel loads late and came up behind our window 5 and 10 s after it opened. The button watcher now hides it while the forced window is open (`items_trading.keep_offers_hidden`).
- The player whose diplomacy was forced leaves diplomacy with our window at the end of the deal: `CampaignUI.ClosePanel("diplomacy_dropdown")`, 100 ms after the click, only with `ad_forced_diplomacy`. A player who came to diplomacy on their own stays there. Vanilla uses `CampaignUI.ClosePanel` for other panels (`cathay_compass` in `wh3_campaign_great_bastion.lua`, prologue panels), not for diplomacy. HYPOTHESIS: closing diplomacy on one client is fine in MP.

**Second MP test, 0.12.2 (2026-11-01, turn-by-turn, Astragoth + Arbaal, logs `script_log_011126_1726.txt` and `_1926.txt`; `_1741` is only the main menu) — PROVEN, user: everything works, no new problems:**
- No desync: all 19 trade ops and all 12 `deal end` lines identical on both clients; no ERROR or WARNING lines.
- Mirrors without DLC rows reach a player without the DLC: `furnace_blast_gem` and `malignant_totem` to Arbaal, whose item count rose (tester has no Forge of Hashut).
- Recently traded across players: Arbaal sold copy 4444 to Azazel, Astragoth then demanded the same copy and got `demanded -36 recent -18` with no deal of their own on it.
- Native wait: `M2: native` shows the label on the player not on turn stays true after their OK until the on-turn player leaves diplomacy (683.9 s to 685.4 s, closed together). Native behaviour, the user is fine with it after the test.
- `Bring in: diplomacy is open` every time; forcing diplomacy has still never run. Simultaneous turns untested.

**First MP test, 0.12.0 (2026-11-01, turn-by-turn, Astragoth + Arbaal, logs `script_log_011126_1626.txt` and `_1826.txt`) — PROVEN:**
- No desync. `deal end` gold and item counts equal on both clients after all 6 deals (2 AI, 4 player-to-player). The transfer path, deal memory and proposal flow work in MP, including a counteroffer chain.
- `simultaneous=false` through the one-argument call. Events and trade ops from the player not on turn run at once.
- Item ids are the same on all clients: copy 4444 was recorded by Arbaal's trade watch and listed as 4444 on Astragoth's client; 114 id + key pairs match between the logs.
- The player not on turn is pulled into diplomacy some seconds after the other opens it (`Bring in: diplomacy is open` every time, forcing never ran) and its negotiation context is valid.
- `ad_count_copies` through `CcoCampaignFaction` works (`I,5,85,...,,1,2`).

**Bugs from that test, fixed in 0.12.1 (not run yet):**
- **Items lost (cause from data, HYPOTHESIS: the tester lacks the Chaos Dwarfs DLC):** Arbaal's item count shows the mirrors of `wh3_dlc23_anc_talisman_malignant_totem` and `wh3_dlc23_anc_enchanted_item_furnace_blast_gem` never arrived, the giver lost them. Every other item arrived; only these two have a row in `ancillary_ownership_content_pack_junctions_tables` (`wh3_dlc23_chaos_dwarfs`), which the mirrors copied. `add_ancillary_to_faction` fails silently like for a race lock. CONFIRMED by the user: the tester has no Forge of Hashut. Mirrors no longer copy that table (user: for all mirrors). Audit of all 591 mirrors: exactly 18 had a row (16 `wh3_dlc23_chaos_dwarfs`, 2 `wh3_dlc25_thrones_of_decay_nur`), it is the only item table with a content pack link in the vanilla db, and no tradeable `faction_set = all` item has one. Consequence: a player without the DLC can now own these 18 mirrors. Known gap: an original still goes to a receiver of its own race; a Nurgle player without Thrones of Decay would lose those 2 Nurgle originals the same silent way. **Delete `db/ancillary_ownership_content_pack_junctions_tables` from the pack.**
- **After the final decision (user):** the sync ends there; each player has their own result view, OK only closes it, nobody waits for the other, and this does not mean leaving diplomacy. Claude's `CampaignUI.ClosePanel` from 0.12.1 was wrong and is removed in 0.12.2. What the logs show: the player not on turn closed our window at once (Astragoth OK 1059.9 s, Arbaal's OK later, 1061.3 s) and came back to the native offers panel, where the native `label_waiting_on_response` was visible (`Waiting on player...`, the same words as our label). Native diplomacy closes for that player only when the on-turn player leaves diplomacy (second `button_cancel`). All 4 final decisions in the test came from the player not on turn. Our code holds nobody; the native wait is the open point. `M2: native` lines (0.12.2) log when the label and native buttons change.
- **Recently traded (user):** an item a player sold to a bot costs extra for every player who wants it from that bot; an item bought from a bot costs extra only for its buyer selling it back. `ad_recent_sold_share` looks through the records of all players. Works because ids are equal on all clients.

**0.12.0 (2026-11-01, block 2):** the solo fake partner is gone (user), the flow is real.
- Deal manager, HUMAN DEAL EVENTS: `dmit_human;` events change no model, each client updates its own window. Kinds B (start), I (one item), E (complete), A (accepted), D (declined); format in the section's comment. Screen, HUMAN PARTNER: FLOW: `items_trading.on_human_event`.
- A counteroffer is simply a new proposal whose `base` is the deal it answers. `ad_live_deal` (set and cleared only by events, same order on all clients) makes crossed proposals end the same on both clients: the first stands. A human turn start clears it, so a proposal nobody answered does not block the next one (HYPOTHESIS on the order, block 3).
- The accepting client builds the trade from its window with `build_trade(selection, gold, true)` and sends the normal `dmit_trade` ops, then A. Last op `H` instead of `R`: diplomatic event yes, deal memory no, no trade watch.
- Rows of a proposal are matched by key + holder, then any copy of the key (logged as WARNING); ids are not used. Gold goes into the field through the existing `items_trading_gold_balance`.
- Second client: `items_trading.human_partner` overrides `get_target_faction` while the window is open, its negotiation context may be someone else. Because of that: `ad_count_copies` asks `CcoCampaignFaction` by cqi and the layout's gold cap reads the user property `items_trading_partner_treasury` (both change the AI path too, retest). `offers_panel` is optional when opening.
- Bringing in (7.1a): `is_panel_open("diplomacy_dropdown")`, else `get_open_blocking_or_event_panel` + one-shot `PanelClosedCampaign` listener, else `common.call_context_command("CcoCampaignFaction", cqi, "OpenDiplomacyWith")` (from a closed panel: HYPOTHESIS). `AD_HumanDiplomacyOpened` opens the window when diplomacy came up any other way.
- Unknown until the real test: does OpenDiplomacyWith work for the player not on turn, do trade ops sent by that player run at once. If the window does not come up, the proposer waits with no exit but Esc (user's decision, 7.1a).

**0.11.2 (2026-11-01):** user: checkboxes grey again while waiting for the answer (`inactive` / `selected_inactive`), in colour only on a proposal to answer (review). Never clickable in both, `SetInteractive(false)`. x 242 of the waiting label confirmed good by the user.

**0.11.1 run (log `script_log_011126_1519.txt`, screenshot) — PROVEN, solo with the partner faked as human:** both gold arrows stay inactive while waiting and in review (also 0.3 s later) and come back in counter; checkboxes keep their colours with `SetInteractive(false)` (`IsInteractive` reads false) and come back in counter; no errors. The waiting label is centred on its dock x whatever the anchor (left edge 932 at x 248, width 232, window centre 800); user: x 248 too far right, x 236 too far left, now x 242 (layout only). `common.get_context_value("IsSimultaneousTurns")` (one argument) works, it logged `false`; the three-argument form logs nil. Not covered: a plain AI deal with the switch off.

**0.11.1 (2026-11-01), from the 0.11.0 run (log `script_log_011126_1504.txt`, screenshot):**
- PROVEN 0.11.0 (solo, partner faked as human): the whole answer cycle works without errors (waiting, review, counter, accepted, declined, you_accepted, decline); the plaque and buttons move as planned (plate 190x50, image 212, dock x 30 / -60 / 0 / 60); radios stay locked; `cm:real_callback` works for the rows on open; `dmit_probe` events arrive (40-860 ms in single-player).
- Bug found in the log, not by eye: the right gold arrow came back `active` 0.3 s after the lock. A clamp sent by OK arrives after Lua's `SetState`. Fix: user property `items_trading_locked` on the amount field, read by the layout's cap command, so the arrows follow it whatever the order.
- User: "Waiting on player..." over the Cancel button. At dock x 140 the label stood centred on that x, whatever `component_anchor_point` says (HYPOTHESIS: `texthbehaviour="Resize"`). Now x 248, measured from the screenshot: the middle of the bronze bar right of the plaque. `M3:` lines now log screen position and width.
- User: locked checkboxes must keep their colours, grey ticks are hard to see. Now normal states + `SetInteractive(false)`, also while waiting (Claude's call, same code).
- `IsSimultaneousTurns` through `common.get_context_value("CcoStaticObject", "", ...)` logged nil in single-player; M2 now also tries the one-argument form.

**0.11.0 (2026-11-01, block 1):**
- Layout through `tools/build_panel_plan_b.ps1` (checked first: the script reproduced the old file exactly, GUIDs aside): `counter_trade_magic_items` (copy of OK with the native icon and tooltip), `items_trading_waiting` (hidden, Bottom Center 140,-6). Old files in `backups/*.before_human_mode.*`.
- Lua, screen file: sections HUMAN PARTNER: VIEW and HUMAN PARTNER: FLOW. `ad_human_deal.state` = compose / waiting / review / counter. The plaque is resized at runtime (`Resize`, `ResizeCurrentStateImage`, `SetDockOffset`), the AI window never touches it. HYPOTHESIS to check: dock offsets of template buttons, radio and arrow states staying inactive (the `M3:` view log reads them again 0.3 s later).
- The partner counts as human when it is in `cm:get_human_factions()` (the list keeps dropped players).
- The accepting player sees the native `you_accepted` ("You have accepted their offer."), not `they_accepted` (Claude's call). The layout also has `you_declined`, unused: the decliner's window just closes.
- `items_trading.human_reply("counteroffer" / "accepted" / "declined")` is the entry for the other player's answer: the debug file calls it now, deal events in block 2.
- New loc: `items_trading_propose_human_tooltip`, `items_trading_accept_tooltip`, `items_trading_decline_tooltip`.

**M3 solo run (debug file):** `M3_FAKE_HUMAN_ENABLED = true` makes every partner human; the answers come by themselves 4 s after each Propose, in the order counteroffer, accepted, counteroffer, declined. No trade runs.

**M2 logs (debug file, 2026-11-01, not run yet):** read-only, safe in MP, lines start with `M2:`; only the Lua syntax was checked (luaparse). Questions they answer, comparing both clients' logs:
- Partner on each client: `snapshot` lines at diplomacy open, +0.5 s, +2 s and after clicks (`partner`, `partner_IsHuman`, `partner_is_human`).
- Does the second player land in diplomacy, in which order: `panel opened` / `panel closed`, `blocking`, native components (`button_send`, `button_accept`, `label_waiting_on_response`...).
- Turn mode: `session` lines (`simultaneous`, `whose_turn`, human turn starts); `pending` / `sent` list sizes.
- Item ids: `row` lines, 1 s after our button: same `id` for the same item on both clients?
- Events from the player not on turn: `ping` sent / arrived, delay on the sender's client.
- Native diplomacy events on each client: `event` lines.
- Desync check: `deal end` lines, 1 s after a deal's last op: gold and item counts must match on both clients.
- Does `cm:callback` fire with diplomacy open in MP: the main mod's `Selection on open` line must follow the panel open.

### 7.2 Open questions for E3

- Is the native Propose button enabled for a deal that has no native terms (items only)? If not, we may need a dummy native term or our own propose flow.
- Which event tells us a deal was accepted, and does it identify the proposer/recipient so we can execute the matching pending item trade?

### 7.3 Russian translation pack (user + Claude, 2026-11-02)

- Separate mod, folder `Diplomacy_Trade_Magic_Items_ru_packfile/`: only `text/`, the same two loc files under the **same paths** as the main pack (`diplomacy_magic_items_trading.loc`, `diplomacy_tradeable_magic_items_mirror.loc`), so a file of the translation pack replaces the English one whole. It must load with higher priority than the main pack (above it in the launcher / earlier alphabetically). Which file wins: check in game (HYPOTHESIS).
- The user writes the values of `diplomacy_magic_items_trading.loc` (the file starts as a copy with English values).
- Mirror loc: `tools/build_ru_mirror_loc.js` (separate, the main generator is untouched, user): our key minus `_diplomacy_tradeable` → the original key in the Russian vanilla `Vanilla_files/text/localisation__.loc.tsv` (whole `local_ru` loc, ~48 MB) → the Russian text under our key. 2026-11-02: 1807 of 1807 rows found. Re-run after the main generator.
- The main pack's mirror loc is English only, so without the translation pack a Russian game shows the mirrors' names in English while the originals are Russian.
- **Layout texts (DOC, Russian loc):** the engine localises a layout text by its label: loc key `uied_component_texts_localised_string_<textlabel / tooltip label>`, e.g. `..._StateText_3c12906f` = «Ожидание игрока…». Texts we copied from vanilla with their label stay with the engine: Waiting on player, the four accepted / rejected lines, Propose and Counteroffer tooltips, the two payment tooltips, Offer gift, Select Previous / Next, the column tooltips. Our own texts sit on vanilla labels with other meanings (`StateText_ea51c813` = «Чужое поселение») and have `textlocalised="false"`, so they stayed English in every language.
- 0.12.10: those four texts come from our loc, set by script on the panel's first open (`ad_setup_texts`, like the gold labels): `items_trading_panel_title`, `items_trading_rules_hint`, `items_trading_your_items`, `items_trading_their_items`. The layout keeps the English text as fallback. Not tested in game yet.
- Rule: every text of ours goes through a loc key; only texts copied from vanilla with their vanilla label are left to the engine.
- 2026-11-02 in game (user): the Russian pack works; the long Russian hint ran under both treasuries. Hint label `label_trade_magic_items_rules` narrowed 669 → 454 (centre 381; our treasury ends at 144, the partner's icon starts at 649; ~10 gap), also in `build_panel_plan_b.ps1`. About 55 characters per line at this width; the label is 35 high (2 lines) and the columns start at y 61, so a 3rd line would collide: keep the hint at ~110 characters or less.
- Second run (user: the gap may be half): measured on the screenshot (scale ~1.57 px per unit) our treasury box really ends at ~126 (not 144) and the partner's icon starts at ~658; the visible gap was ~28 left / ~50 right. Label 454 → 482, still centred under the title (gap ~14 left / ~36 right). Shifting the centre would even out both sides but moves the hint off the title's axis. **PROVEN in game (user, 2026-11-02): 482 works; the Russian translation pack is done and works (loc texts, mirror names, panel texts from loc).**
- **Rename 2026-11-03 (user, before the Workshop release; not tested in game yet):** `diplomacy_magic_items_trading` → `diplomacy_trade_magic_items` for the three scripts, the `diplomatic_actions_tables` file and the loc file (in **both** packs, so the RU file still sits under the same path as the main one), loc keys `items_trading_*` → `trade_magic_items_*` (27 keys, the same in both loc files; all referenced as string literals in `_screen.lua` and `_diplomacy_option_button.lua`, none in the layouts). The text source id `items_trading_deal_chance` of `SetStateText` (not a loc key) followed for consistency. Backups in `backups/before_rename_2026-11-03/`.
- **Rename step 2 (user, same day: "one common form"; not tested in game yet):** `items_trading` / `items_trading_*` / `dmit_*` → `trade_magic_items` / `trade_magic_items_*` everywhere: Lua global table, layout component ids, user properties, `UiMsg` and UI script events (layout + Lua + `build_panel_plan_b.ps1`), deal events `trade_magic_items_trade` / `trade_magic_items_human`, saved values `trade_magic_items_recent_items` / `trade_magic_items_faction_deals`. Checked: no new name equals an existing one (the mapping is one to one); every Lua name is a loc key, a layout name or a Lua-only id (events, saved values, text source id); layout XML parses. Event length: longest item op ~145 of 255 chars (96-char mirror key). Old saves lose the deal memory (saved value names changed). Still `ad_` / `AD_`: local helpers only (not visible outside the scripts). Mirror files and pack name unchanged. Backups in `before_rename_2026-11-03/step2_identifiers/`. Then (user) loc keys `trade_magic_items_gold_give` / `_gold_demand` / `_propose_human_tooltip` → `trade_magic_items_offer_payment` / `_demand_payment` / `_propose_player_tooltip` (code + both loc files). Public Steam title chosen separately (candidate: "Diplomacy: Trade Magic Items").

### 7.4 Patch 9.0.5 — mirrors regenerated, release 1.0.1 (2026-11-03, not tested in game yet)

- Release version 1.0.0 → **1.0.1** (user): `AD_VERSION` in `_deal_manager.lua`, log prefix `[MAGIC_ITEMS_DIPLOMACY 1.0.1]`. In MP all players need 1.0.1.

- The user extracted the 9.0.5 ancillary db tables, `text/db/ancillaries__.loc`, `ancillary_sets__.loc` and the Russian `localisation__.loc`. Both generators were run (paths fixed after the folder rename, also in the `.ps1` tools). Old mirror files: `backups/mirrors_before_9.0.5/` (`main/`, `ru/`).
- **DOC (vanilla data):** CA removed the `ancillaries_included_agent_subtypes_tables` rows of the 4 High Elf dlc27 items (`annulian_crystal`, `null_stone`, `golden_shield`, `temakadors_gauntlets`, were Mist Mage / Sea Helm only) → tradeable now, mirrors 591 → 595 (`faction_set` `anc_set_exclusive_high_elves`). Our list filter (`IncludedAgentSubtypesList.Size == 0`) reads the record at runtime, so they show up without a code change.
- `whispering_skull`, `gem_of_blood`, `wristbands_of_black_gold` (dlc29): `faction_set` `anc_set_exclusive_vampire_counts` → `anc_set_vampire_counts_nagash` (Lua map only).
- `divining_rod` (dlc24), `crystal_pendant`: the ancillary drop effect scope `character_to_character_own` → `character_to_force_own_unseen`.
- Unchanged: item sets (17), `ancillary_to_included_agents` (2 rows), table columns, texts of the already mirrored items. No mirror removed → old saves keep their mirrors. Loc 1809 → 1821 lines; Russian 1819 of 1819 found.
- To re-import in RPFM: `ancillaries_tables`, `ancillary_info_tables`, `ancillary_to_effects_tables` mirror tables, the mirror Lua, the mirror loc in both packs.
- **Second check after the RPFM schema update (same day):** fresh extraction (same layout: English `text/db/*.loc`, Russian `text/localisation__.loc.tsv`) → all 7 mirror tables, the Lua map and the English mirror loc identical to the pack (columns too); Russian mirror loc 1819 of 1819 identical. Nothing to re-import.

### 7.5 Version 1.1.0, item 1: banners, followers, same-race items (user + Claude, 2026-11-15, built, not run in game yet)

**Rules (user):**
- Banners (apart from the 11 basic WH1 banners with faction set `all`), followers, items for generic agent subtypes (any Warlock Engineer, any Grey Seer…) and non-unique dwarf runes trade only between factions that can both use the original: the item's faction set decides, not the culture. Shared sets count (Empire / Kislev / Bretonnia followers, Beastmen / Norsca / Chaos…). No mirrors for any of these.
- Not tradeable: unique items, race mechanics (Beastmen gifts, Chaos marks, Oxyotl poisons), items only named characters can wear (only one left after the other rules: Shadow Banner, Alith Anar), the two faction-set-`all` followers with no source in the game (Battle-Scarred Ungor Raider, Sacred Plaque Librarian). Familiars (category general, no subcategory) are in no tab.
- Engineering runes (worn by the lord, buff the army's war machines) go with the banners.
- Prices unchanged: most followers are common.
- Banner sets: banners were never mirrored; a mirror set holds the original banner, so other races see the set bonus but can't complete it. Same-race trading delivers the original banner, the original set works: nothing to change.

**UI (user):** one window, one deal. Tabs Magic Items / Banners / Followers over both columns; every open starts on Magic Items; leaving the window drops the ticks (as before); ticks stay on a tab switch; a tab shows the ticked count of both sides; Banners / Followers greyed with a tooltip when neither side has anything there to trade (other race or nothing at all); Magic Items never greyed. Column titles follow the tab. The panel title becomes "Trade Magic Items & Ancillaries" later.

**How it is built:**
- `tools/build_tabs.js` (run once on the 1.0.1 layout, backup `backups/diplomacy_hud_trade_magic_items.before_tabs.twui.xml`): copies the list twice (`banners_list`, `followers_list`, own filters), adds three tab buttons (`square_medium_text_tab_toggle` copied from vanilla `search_panel` without `ButtonGroupButton`, 200×40, docked top centre at y 66), panel 425 → 469 high, columns y 61 → 105, dark parchment grows with the panel.
- All three lists of a column stay bound, the script shows one (`trade_magic_items.show_tab`). Rows of all lists go into `ad_row_info` with their tab, so the trade, the trade watch and human proposals work across tabs unchanged.
- Race check in the filters, no hidden rows: `CcoAncillaryRecord.CanFactionUseAncillary(CcoFactionRecord)` for both sides; the player is `PlayersFaction`, the partner comes from the script: `common.set_context_value("trade_magic_items_partner", key)` before binding, read as `FactionContextFromKey(ScriptObjectContext("trade_magic_items_partner").StringValue)`. All three functions are from `cco_functions.txt`, **none tested yet**.
- The trade code needed no change: an item without a mirror is delivered as the original (`delivery_key`).
- Logs back on (`script/enable_console_logging`), `AD_VERSION` = 1.1.0. Temporary lines marked `TEMP 1.1.0`: the filter check on binding (partner context, partner record, player record), tab position and list size on every tab switch.

**Test 1 (user, 2026-11-15, 5 single-player campaigns: Aislinn, Tiger Warriors, Neferata, Ice Court):** works; tabs look right and follow the panel height; no errors in the logs. **PROVEN:** the race check in the filters works: `ScriptObjectContext` returns the partner key, `FactionContextFromKey(…).FactionRecordContext` and `PlayersFaction.FactionRecordContext` resolve; other race → followers 0 on both sides, only basic banners; same race → followers and race banners listed (e.g. Tiger Warriors ↔ Western Provinces: followers 51 / 16, banners 22 / 0–1; Aislinn ↔ Avelorn: followers 35 / 12, banners 13 / 4). Tab button real size 200×46 (the template keeps its height), at 70 / 280 / 490, y 66.
- User: AI partners have few banners and noticeably fewer followers than the player. Vanilla grants followers to AI factions too (`wh3_campaign_followers.lua`, same listeners, chance × `calculate_ancillary_drop_chance`, no `is_human` check except two mission followers), so it may simply be what the AI owns. TEMP log `Filter steps <faction> followers/banners: all n, transferable n, not unique n, both can use n` + the keys each step drops, written on every open, answers it in test 2.
- User: switching tabs threw the list back to the top. Cause (CA callback doc): the `Listview` resets to the top whenever the list size changes (`dont_reset` user property). Fix in test 2: each tab remembers its scroll per column while the window is open (`ad_tab_scroll`, list_box vs list_clip position); on a switch the script sets a property on `vslider` and sends `UiMsg("trade_magic_items_scroll_restore")`, the slider's new `ContextCommandEvent` calls `self.SetValue(<property>)` (VSlider has `SetValue`, same mechanism as the gold reset). **HYPOTHESIS:** slider value = pixels; TEMP log `Scroll <column> <tab>: wanted n, now n`.
- User: the rules hint must fit in one line above the dark parchment and point to the tabs; the rules per category go into the tab tooltips. Chosen (user): "Choose what to offer or demand. Each tab's tooltip explains its rules." / RU «Выберите, что предложить или потребовать. Правила — на вкладках.» The label is now one line where the first line used to be: 530×20, dock y 26 (was 482×35 at y 32, two lines, the second one on the parchment). The old rules (unique, named characters, dwarf runes and character-type items within the race) moved into the Magic Items tab tooltip; Banners / Followers tooltips also say unique ones are not tradable.
- User: on open the Banners tab flashed (layout state first, grey a moment later): the tabs waited for the rows, which come a few frames after the window shows. Fix: on binding the script counts each tab's items on both sides with the same filters (`AD_TAB_FILTERS` in the screen script, **kept in sync with `tools/build_tabs.js` by hand**) and sets the tab states before the window is drawn; once the rows are read the tabs go by the rows. TEMP: `Tab items on binding: …` and a WARNING if the count and the rows differ.

**Test 2 (user, 2026-11-15: Aislinn, Dwarfs):** tabs no longer flash on open; trades of followers (Dwarfs ↔ Karak Azul) and a basic banner (Dwarfs → Kislev) went through. The only script error in the logs is vanilla (`intervention_state_from_string`, advisor interventions).
- **PROVEN: AI factions simply own few banners and followers.** Filter steps: "all" = what the faction owns, and the steps drop next to nothing (Avelorn: followers 12/12/12/12, banners 5 → 4, only the unique Banner of Avelorn; Karak Azul: 1 follower, 0 banners; Barak Varr: 0 / 0). Against another race the race step drops them all (Dwarfs vs Ice Court: brewmaster, dwarf bride; Kislev's hedge wizard, pit fighter, tollkeeper, Father Niklas' Mantle).
- **PROVEN: the scroll restore works.** VSlider `SetValue` takes pixels (`wanted 788, now 788`, `wanted 443, now 443`…). A few mismatches, probably the player scrolling within the 400 ms. But the jump was visible: the list showed at the top first. Test 3: on a switch both `list_box` get `PropagateOpacity(0, true)`, back to 255 50 ms after the restore (always scheduled, even if the restore fails). Risk: PropagateOpacity(255) sets every row child to full opacity; the layouts have no opacity of their own, row animations might.
- **Replaced before test 3 (user: why one shared scroll at all?):** each tab now has its own list view per column (`view_magic` / `view_banners` / `view_followers`: transparent, the column's size, with the `Listview` callback moved down from `list_offers` and their own `list_clip`, `list_box`, list and `vslider`). A tab switch only shows another view, so each keeps its scroll natively; no saving, no restore, no opacity trick. On every open the sliders get `UiMsg("trade_magic_items_scroll_reset")` → their `ContextCommandEvent` `self.SetValue(0)`. The panel height watcher resizes all views. `tools/build_tabs.js` now always builds from the 1.0.1 backup (rerunnable), including the rules label. **HYPOTHESIS:** the `Listview` finds its clip, box and slider among its own children, so three of them per column work; test 3 shows it.
- User: column titles get the tick counter of the current tab ("Your Banners (2)"), updated on every change, on a tab switch and when a human partner's proposal / counteroffer is shown (`ad_restore_ticks` now calls the tab update).
- User: own balance for ancillaries: `AD_ANCILLARY_RARITY_POINTS` / `AD_ANCILLARY_BELONGS_TO_CHARACTER_POINTS` (deal manager) for items of the Banners / Followers tabs (`info.tab`). User numbers (2026-11-15): rarity common 2 / uncommon 4 / rare 8, belongs 0.5 / 1 / 1.5; crafted copies rare (no tradeable ancillary is crafted). With these an ancillary barely counts towards the "big deal" (rarity ≥ 100) event; dwarf character runes and character-type items stay on the magic item tables.
- User: rules hint lowered to dock y 30 (centred between the title plaque and the parchment). Name of the mod in texts: "Trade Magic Items & Ancillaries" (action button and panel title, English; the project and the packs keep their names; the Workshop title changes with the release).

**Test 3 (user, 2026-11-15, logs `script_log_151126_1849` / `_1910`):** per-tab lists feel right, tab labels fine (text shift −6 → −4: the tab reports 200×46 in game although the layout says 40 high). Only vanilla script errors (interventions). Changes for test 4, all in `tools/build_tabs.js`:
- Tab strip tighter (user): measured on the screenshot, parchment top → tab frame ≈ 16 px, tab frame → columns ≈ 22 px. The lower gap cut by a third: `TAB_STRIP` 44 → 37 (panel 462, columns y 98); the upper gap made the same by moving the parchment's top edge down 2 px (`PARCHMENT_TOP_DOWN`: height 356, dock shift −3 → −2, bottom edge unchanged). Tabs unchanged (y 66).
- Tallest panel = 10 list rows, as in 1.0.1 (user): the resize handle's `max_scale` was still 1.854 (made for 425 high, so 869 with the tabs, 10.4 rows); now computed from 1.0.1's +363 px: **1.7858** (825).
- Reset on leaving, not on opening (user: a reset on open can show as a visible jump; leaving always goes through our code). `ad_reset_window_on_close(panel)` in the screen script: gold (UiMsg gold reset), working selection (`pending` stays), lists to the top (UiMsg scroll reset), Magic Items tab. Called by `ad_close_trade_magic_items_panel` (Cancel, after a trade, result view) and `hide_window_after_diplomacy` (Esc, end of turn), before the panel is hidden, as the gold reset always was. The open only sets the tab again. **HYPOTHESIS:** the sliders take the UiMsg in the frame the panel is hidden (the gold field always did).
- Rules hint ran into the left treasury box (text ≈ 508 px, room between the boxes ≈ 534 px, the boxes grow with the number). Text shortened (user): "Choose what to offer or demand. Hover over tabs for trade rules." (≈ 445 px). User: fits.
- Esc in our window = Cancel (user). `cm:steal_escape_key_with_callback("trade_magic_items_esc", …, true)` when the panel opens, `release_escape_key_with_callback` in `ad_reset_window_on_close` (every way out). Persistent on purpose: CA's non-persistent steal drops the callback after one press but never calls `steal_escape_key(false)`, so Esc would stay stolen. The Cancel listener's body is now `trade_magic_items.cancel_window(source)`, shared by the button and Esc; like the button, Esc does nothing while waiting for the other player's answer. **HYPOTHESIS:** the steal takes Esc before the diplomacy screen does.

**First test, what to look at:** rows per tab in the log (`rows magic=…, banners=…, followers=…`) and in the window; same race (e.g. two Skaven) vs other race; Empire ↔ Kislev followers; tab looks and place; scrolling after a tab switch; a traded banner that a unit carries; a human partner's proposal with a banner in it.

### 7.6 Version 1.1.0, item 4: rebalance (user + Claude, 2026-11-16, built; test 1 OK)

**Test 1 (user, 2026-11-16, log `script_log_161126_1453`):** works as intended, no script errors from the mod; log numbers match (crafted 20, uncommon 6, second deal frequency −10). Change: on a pure sale the prospects line is a plain 0.0 (see the table). Destruction scale checked in game (user): works.

Built from `plans/2026-11-16-rebalance.md`: DEAL TUNING in the deal manager (`AD_RARITY_POINTS`, `AD_WORN_SHARE`, `AD_ATTITUDE_SCALES`, `AD_DESTRUCTION_SUBCULTURES`, frequency first 5, big deal 35, gold multipliers removed); `evaluate_deal` adds `attitude_scale` / `attitude_percent`; the deal window writes the prospects line as "percent (points)"; the balance button no longer divides by a multiplier. Log line: `Deal chance …: attitude n (scale p%) -> prospects`.

**In-game check** (deal window tooltip; frequency 0 unless noted):

| Deal | Attitude / scale | Expected lines |
|---|---|---|
| Demand their unworn rare item | 0, Order | Rarity −14.4, Prospects `+5% (−0.7)`, total −15.1 |
| Demand their worn rare item | 300, Order | Rarity −14.4, Belongs −4.3, Prospects `−25% (4.7)`, total −14.0 |
| Demand their worn rare item | −120, Skaven | Rarity −14.4, Belongs −4.3, Prospects `+10% (−1.9)`, total −20.6 |
| Demand their common item | −300, Order | Rarity −2.5, Prospects `+100% (−2.5)`, total −5.0 |
| Offer our rare, demand 14 400 gold | −200, any | Rarity +14.4, Economic −14.4, total 0.0 (no ×3 any more) |
| Destruction partner, nothing demanded | 350 | Prospects plain `0.0` (user, test 1: on a pure sale the percentage changes nothing, so no percent and no colour; `their_price` = 0) |
| Second deal with the same faction this turn | — | Deals frequency −5.0 |

Complaints (user, from players and own play): selling an item gives too much gold, often the AI's whole treasury, while item prices themselves feel low; attitude weighs so much that factions everybody hates (destruction) can hardly trade; bonuses add up oddly (some items free, some penalties huge). Scale (user): 20 000 gold is about the best income per turn of the richest factions; buildings 2–20 000, main settlement tiers often 6 000 / 15 000; the dearest unit upkeep is about 700 a turn.

**Decided:**
- Rarity points (1 point = 1 000 gold, kept): **2.5 / 6 / 14.4 / 20** (common / uncommon / rare / crafted). Rule kept: each rarity = previous × 2.4 (x2 + 20%); crafted stands apart = rare × 1.39, as before (50 / 36).
- Worn by one of their characters: **+30% of the item's rarity points** (replaces 5 / 10 / 15 / 20).
- Attitude becomes a **percentage on the price of their items** (rarity + worn), up or down; replaces the point tiers. Best attitude: **at most −25%**. Order scale (user, 2026-11-16), first tier that matches: ≥ 300 −25%, ≥ 200 −20%, ≥ 150 −15%, ≥ 100 −10%, ≥ 50 −5%, ≥ 25 0%; between −25 and 25 **+5%**; ≤ −25 +10%, ≤ −50 +20%, ≤ −100 +35%, ≤ −150 +50%, ≤ −200 +70%, ≤ −300 **+100%** (price ×2; bad side smoothed so the steps grow: +10, +15, +15, +20, +30).
- Destruction factions get their own attitude scale: smaller penalties starting at a worse attitude, smaller bonuses. A fixed list race → scale; the partner's race decides which scale is used. Destruction scale (user, 2026-11-16): ≥ 300 −12.5%, ≥ 200 −10%, ≥ 150 −7.5%, ≥ 100 −5%, ≥ 50 −2.5% (half of Order), ≥ 25 0%; between −25 and 25 0%; ≤ −25 0%, ≤ −50 +5%, ≤ −100 +10%, ≤ −150 +20%, ≤ −200 +30%, ≤ −300 +50%. Destruction list (user, 2026-11-16): Warriors of Chaos, Daemons of Chaos (Khorne, Nurgle, Slaanesh, Tzeentch, Daemon Prince), Beastmen, Norsca, Greenskins, Skaven, Chaos Dwarfs, Vampire Counts, Vampire Coast, Ogre Kingdoms, Nagash's Undead Legions (`wh3_dlc29_sc_nag_undead_legions`, found in the db while planning; user: Destruction). Everyone else is Order: Empire, Southern Realms, Bretonnia, Kislev, Grand Cathay, Dwarfs, High Elves, Wood Elves, Lizardmen, Tomb Kings, and Dark Elves (user: they value their trinkets and would not part with them easily). Subculture keys to be taken from the db when building.
- Recently traded stays as it is (50% of rarity, fading over 10 turns, counted on the base price).
- Rejected: different buy and sell prices (user: not an RPG, recently traded already does that).
- Later: the "big deal" threshold (once prices are set); ancillary points 2 / 4 / 8 (with items at 2.5 a common banner is almost a common item).

**Decision after test 1 (user, 2026-11-16):** deals frequency stays — the simpler the better; the draft below is dropped unless something as simple turns up. If emptying the AI's treasury is still a problem in play, the simplest add-on is a hard cap: the AI pays at most a share of its treasury per deal (one number, e.g. 50%). **Spare idea, not built (user: keep it for when more complaints come):** gold the AI pays = min(price, 50% of its treasury); today's cap is 100% (`ad_gold_limit`). A cap below the price still makes the deal good for the AI, so it agrees and the balance button offers the capped sum. With deals frequency it shrinks repeated sales (treasury 30 000, a crafted item each turn: 15 000, then 7 500, then 3 750) and never empties the treasury; rich AIs pay full price.

**Draft, dropped (was: user: still feels complex, back to it later):** replace deals frequency (and the ×2 / ×3 gold multipliers, and a treasury cap) by "treasury strain": the AI's gold is dearer the more of its current treasury it gives. Free zone 30% (paid at full price), reserve 10% (never paid); in between the gold weighs 1 / (1 − depth), depth = how far the deal reaches into the 30–90% band. Memory: gold paid to players goes into a pool (remaining + new, 15 turns from the last payment, fading evenly); the pool counts as already-given gold of the **current** treasury (pool / treasury now). Fallback if dropped: deals frequency starting lower (5 → 10 → 20 or 2.5 → 5 → 10 → 20).

- Attitude does **not** touch the gold the AI pays (user, 2026-11-16: an extra setting for now, back if needed): the ×2 / ×3 multipliers on demanded gold go.

- Deals frequency for the first test (user, 2026-11-16): the simple fallback, **5 → 10 → 20 → 40…** (×2), reset after 15 turns without a deal; see in game whether it is enough at the new prices.
- Deal window (user): the attitude line ("Diplomatic prospects") shows the **percentage**, green for a discount, red for a markup, with the points it saves or adds in brackets, e.g. "−25% (4.7)". The worn line stays a plain number.

- Ancillaries (Banners / Followers tabs) keep **2 / 4 / 8** (crafted copies rare), worn **+30%** like items (was 0.5 / 1 / 1.5).

- Big deal (STATE_GIFT_MEDIUM instead of SMALL): rarity points of both sides together **≥ 35** (was 100; rarity only, no worn, attitude, recent or gold). E.g. two crafted (40) and crafted + rare + common (36.9) make it; two rare + uncommon (34.8) and crafted + rare (34.4) do not.

### 7.7 Version 1.1.0, items 2 + 3: settings window (MCT) and the trade agreement rule (user + Claude, 2026-11-16, built, tested)

**Built** (plan `plans/2026-11-16-mct-settings.md`):
- `script/campaign/mod/diplomacy_trade_magic_items_default_ai_evaluation_values.lua` — the defaults, plain data; `diplomacy_trade_magic_items_mct_fields_and_checks.lua` next to it — the menu's fields in order (section, MCT key, path, kind) with `get` / `set` / `parse`, shared by MCT and the campaign so keys and checks cannot drift apart.
- `script/mct/settings/diplomacy_trade_magic_items.lua` — the MCT page: the first section takes MCT's default one (no empty header), text inputs with `add_validity_test` = `parse`, checkbox for the rule.
- `script/campaign/mod/diplomacy_trade_magic_items_settings.lua` — `trade_magic_items.settings` = copy of the defaults, re-read from MCT on `MctInitialized` / `MctFinalized` (a refused or missing value keeps its default, logged); without MCT a first-tick log line "Settings: defaults (MCT not installed, …)".
- Deal manager: DEAL TUNING constants gone; reads `trade_magic_items.settings`; `trade_magic_items.payment_per_point()` replaces `GOLD_PER_POINT` (also in the screen's balance button); attitude percent capped at −100%. Kept in code: the Destruction subculture list, frequency growth ×2, the deal events.
- Button: the at-war block is now "blocked: war / no_trade_agreement" (`ad_blocked`); war first; new tooltip key `trade_magic_items_button_needs_trade_agreement` (EN draft: "Not available without a trade agreement with this faction. Sign a trade agreement first."; RU pass later — without a RU text the button keeps its normal tooltip). `trade_agreement_with` in a pcall: if it fails, trading is not blocked.
- Loc (EN): 93 `mct_diplomacy_trade_magic_items_*` keys (title, author, description, 8 sections, 41 fields × text + tooltip with the default), in their own file `text/diplomacy_trade_magic_items_mct.loc.tsv` (user, 2026-11-16); the RU pack will need its own `_mct` file for the translation.
- Shared files renamed (user): `diplomacy_trade_magic_items_default_ai_evaluation_values.lua` (was defaults.lua) and `diplomacy_trade_magic_items_mct_fields_and_checks.lua` (was options.lua, then settings_menu_fields.lua / mct_fields_and_checks.lua), now directly in `script/campaign/mod/` with the mod prefix like our other scripts (user, 2026-11-16). **PROVEN (MCT test 1, log `script_log_161126_1703`):** the campaign loader also runs subfolders of `script/campaign/mod` ("Loading mod file [script\campaign\mod\diplomacy_trade_magic_items\…]"), so they run twice (loader + `require`); harmless, they only return data — user: keep them with our scripts anyway.
- **MCT test 1 (user, 2026-11-16):** the page and fields work. Found: (1) **the game's Lua has no `math.huge`** → the nan/inf check crashed every settings read (MCT values never applied); now `value - value ~= 0`; (2) **numbers are single precision in game**: `tostring(14.4)` = "14.39999961853" → `spec.format` (at most 2 decimals) for the field defaults and the log; (3) no texts (raw keys, "No Title Assigned"): the built pack's loc had none of the new keys (searched the .pack: "Items and ancillaries you offer" present, `mct_…` absent) — the TSV with the new rows was not imported; four tooltips had double quotes, removed in case they broke the import.
- **MCT test 2 (user, 2026-11-16):** page, texts, values and the rule work (button greyed with the new tooltip). Changes: MCT splits sections between its two columns by count (`per_column = ceil(n / 2)`), so the attitude scales are split into friendly / neutral / hostile sections (12 sections, 6 + 6): left Rules, Prices, item prices, banner prices, worn, deal memory; right the six attitude sections. "Gold per point" shown as "Payment per point" (key unchanged). Tooltips kept only where not obvious (rule, payment per point, worn, frequency penalty, recent %, big deal — now with the gift values +10 / +20). Button tooltips (EN): war "You cannot trade while you are at war with this faction. Make peace first.", no agreement "You are not trading with this faction. Sign a trade agreement first."
- Layout reworked (user, after test 2): back to 2 attitude sections; worn moved into Prices; 7 sections = 4 left (Rules, Prices = payment per point + worn, item prices, banner prices) + 3 right (Deal memory, Order, Destruction). Fewer texts: same labels share one loc key (field option `label`, set with `set_text`; MCT reads it when the field's own `_text` key is absent): `rarity_common…crafted` for items and banners, `attitude_300…minus_300` for both scales. The MCT loc file has 41 rows (was 62; first version 93).
- **MCT test 3 (user, 2026-11-16, logs `script_log_161126_1805` / `_1811`): PASSED.** Page and layout fine. Log: "Settings from MCT (game loaded): all defaults"; Apply → "Settings from MCT (settings applied): trade_agreement_only=true, frequency_first=50" at once; the button blocked without an agreement ("Item trading blocked (no_trade_agreement)"), so `trade_agreement_with` works. MCT turned off and a save with changed settings loaded → "Settings: defaults (MCT not installed)", the mod on its defaults (user). No script errors. Not tested: MP (host values to the other player).
- **MP test (user, 2026-11-16, logs `script_log_161126_1848` / `_1913`): no problems.** Player-to-player: four proposal / counteroffer rounds, then a 17-item deal accepted (`STATE_GIFT_MEDIUM` = big deal at the new threshold); AI deals in the same campaign (`STATE_GIFT_SMALL`, deals frequency counted). Only script error: vanilla (interventions). Both logs say "Settings: defaults (MCT not installed)": MCT was not active in this MP game, so the host → client MCT values remain untested.
- RU pass 1.1.0 (user, 2026-11-16): "Ancillaries" = "Спутники" as in the game (title "Торговля Магическими Предметами & Спутниками", button "Торговля магическими предметами & спутниками"); "points" = "пункты". All 24 new / changed keys of the main loc translated (incl. `their_items` capital fixed); new RU file `text/diplomacy_trade_magic_items_mct.loc.tsv` (41 rows). Internal key renamed `gold_per_point` → `payment_per_point` everywhere (settings, MCT option, loc, `trade_magic_items.payment_per_point()`); an MCT value saved under the old key is not read any more (only in test saves).
- MCT main page: version 1.1.0, Workshop id 3832894578, image `ui/mct/diplomacy_trade_magic_items.png` (user: the Workshop thumbnail, 256x256, shown at 256); title / author / description from loc keys (user: author "Bazulgar", description as approved 2026-11-16). The missing texts in test 1 were most likely just a pack built without the updated loc (user).
- Review fixes (independent review, 2026-11-16): (1) MP: in a new MP campaign MCT applies the host's values to the other player without `MctFinalized`, so the settings are also re-read (`trade_magic_items.refresh_settings`, quiet unless something changed) before every evaluation, before a deal's frequency is recorded (runs on every machine) and when diplomacy opens; (2) `parse` refuses nan / inf (Lua's `tonumber` takes them); (3) the MCT file adds all 8 sections itself (asking for MCT's "default" section logged an MCT error); (4) a failing `trade_agreement_with` is logged once, not twice a second.

**In-game check:** without MCT: log "Settings: defaults", deals as in §7.6. With MCT: our page, sections in order, fields show the defaults; a refused value (e.g. "1,5", "-3" in a price) gives MCT's popup; Apply → log "Settings from MCT (settings applied): …" and the deal window uses the new numbers at once; reload keeps them. Rule on: no agreement → grey button with the new tooltip; war → the war tooltip; with an agreement → normal. MP: the host's values reach the other player (log on both).

**Why (user):** not everyone likes our balance and no balance suits everyone; against the AI players should be free to tune it. Settings only tweak the mod, never break it. Plus a requested optional rule: item trading only with a trade agreement.

**Approach:** MCT (Mod Configuration Tool, Workshop mod, studied in `Other modders examples/Mod Configuration tool`) instead of our own window. Text input fields, not sliders (user: sliders have limits, we don't know the player's range). Rejected: presets, a single "attitude strength" multiplier (user: every tier value editable instead).

**MCT facts (from its code):** loads first of all mods (`script/_lib/mod/!glib_init.lua`) and reads every `script/mct/settings/*.lua` itself; options: checkbox, slider, dropdown, text_input (with `add_validity_test`), sections (collapsible); texts from loc keys `mct_<mod>_<option>_text` / `_tooltip` or set in code; values via `option:get_finalized_setting()`, events `MctInitialized` (game loaded) and `MctFinalized` (player applied); settings saved per campaign in the save under MCT's own block (`mct_registry`); in MP the host's settings are sent to the other player (`MctMpFinalized`). `require "script.x.y"` works in game (MCT uses it).

**Without MCT:** our defaults, always. We never copy MCT values into our save: with MCT off its block stays in the save unread; turned back on, the player's settings return.

**Settings (41), in this order:**
| Section | Fields | Default |
|---|---|---|
| Rules | trade only with a trade agreement (checkbox) | off |
| Prices | gold per point | 1000 |
| Prices, items | common, uncommon, rare, crafted | 2.5, 6, 14.4, 20 |
| Prices, banners and followers | common, uncommon, rare | 2, 4, 8 |
| Items on characters | worn, % of the price | 30 |
| Attitude, Order, % | 13 tiers (labels are the fixed borders ≥300 … ≤−300) | −25, −20, −15, −10, −5, 0, 5, 10, 20, 35, 50, 70, 100 |
| Attitude, Destruction, % | the same 13 tiers | −12.5, −10, −7.5, −5, −2.5, 0, 0, 0, 5, 10, 20, 30, 50 |
| Deal memory | deals frequency first penalty (0 = off); turns until it resets; recently traded % of rarity; turns until it fades; big deal threshold | 5, 15, 50, 10, 35 |

Fixed in the mod: the tier borders, the race → scale list, frequency growth ×2, the crafted ancillary row (= rare).

**Validation:** numbers only. Prices, gold per point, worn %, recently traded %, frequency penalty, big deal threshold: ≥ 0 (gold per point > 0). Turns: whole numbers ≥ 1. Tier values: any number, no order enforced (user freedom). One guard in the evaluation: the total discount on their items is at most 100% (never cheaper than free).

**Trade agreement rule:** with the option on, the Trade Magic Items button is greyed when there is no trade agreement with the partner, with its own tooltip (text for the user to approve); war keeps priority (its tooltip wins). `faction:trade_agreement_with(other)` (seen in AI_settlement_trading_mod, **HYPOTHESIS** until tested). Mid-deal changes need no handling (user: neither war nor the end of an agreement can happen while our window is open). My call: the rule applies to human partners too (same button).

**Code layout (my call):**
- `script/campaign/mod/diplomacy_trade_magic_items_default_ai_evaluation_values.lua` (new): returns the default values, the only place they are written.
- `script/mct/settings/diplomacy_trade_magic_items.lua` (new): MCT registration (sections, fields, validation, texts) from the defaults; read only by MCT.
- `script/campaign/mod/diplomacy_trade_magic_items_settings.lua` (new): current values = defaults, overlaid by MCT's when MCT is there (on `MctInitialized`, again on `MctFinalized`); what the rest of the mod reads.
- Deal manager: the DEAL TUNING block goes; the evaluation reads the settings. The button script reads the rule.
- Loc: English texts for the 41 fields and their tooltips; Russian in the RU pass.

**To check in game:** the fields' look in MCT; defaults without MCT; a changed value takes effect after Apply without reloading; MP host settings reach the other player; `trade_agreement_with`.

## 8. Files to request from the user

- None at the moment.
