# Magic Items — Script API Reference (TWW3)

Everything we know about reading and moving items (ancillaries) from script.
Source: chadvandy WH3 scripting docs (https://chadvandy.github.io/tw_modding_resources/WH3/), vanilla UI layouts, vanilla DB, and our own in-game experiments.

Status legend:
- **TESTED** — used in our experiments, result known.
- **DOC** — documented, not tested by us.
- **NAME ONLY** — the method exists in the docs index, but no description or parameters are given.

---

## 1. Changing items (campaign model)

All of these change the game state. In multiplayer they must run on every machine at the same moment, e.g. from a `UITrigger` handler (see §5), never directly from a UI click.

### `cm:force_add_ancillary(character, ancillary_key, force_equip, suppress_event_feed)` — TESTED

Grants an item to a character.

| # | Type | Name | Meaning |
|---|---|---|---|
| 1 | character | target_character | character script interface |
| 2 | string | ancillary_key | key from `ancillaries_tables` |
| 3 | boolean | force_equip | "if true the ancillary will be equipped and bypass any cooldowns or pre-conditions" |
| 4 | boolean | suppress_event_feed | true = no event feed message |

Returns nil.
**Our result:** works for items the receiver's faction may own. Even with `force_equip = true` it does **NOT** bypass the race restriction (`faction_set`). The item silently does not arrive (E2W).
Used successfully to re-equip a holder after `force_remove_ancillary_from_faction` (E2 T3).

### `cm:force_remove_ancillary(character, ancillary_key, remove_to_pool, suppress_event_feed)` — TESTED

Removes the item from one character.

| # | Type | Name | Meaning |
|---|---|---|---|
| 1 | character | target_character | |
| 2 | string | ancillary_key | |
| 3 | boolean | remove_to_pool | true = unequip into the faction pool; false = item is deleted |
| 4 | boolean | suppress_event_feed | |

**Our result:** with `remove_to_pool = false` it deletes exactly that character's copy. This works for player and AI characters (E2 T1, T2). `remove_to_pool = true` is not tested yet.

### `cm:add_ancillary_to_faction(faction, ancillary_key, suppress_event_feed)` — TESTED

"Grants the specified ancillary to the specified faction. The ancillary goes into that faction's ancillary pool, from where it may be equipped by a character."

**Our result:** works for `faction_set = all` items (Potion of Healing, Obsidian Blade). For race-restricted items outside the receiver's set it **silently does nothing** (Wristbands → Chaos Dwarfs, E2 T3). Always check before and verify after.

### `cm:force_remove_ancillary_from_faction(faction, ancillary_key)` — TESTED

"Remove all instances of the specified ancillary from every character, and the shared ancillary pool, of the specified faction."

**Warning:** this removes **every** copy, both worn and pooled. There is no documented call to remove exactly one pooled copy.
**Workaround (E2 T3, works):** note the holders, call this, then re-equip each holder with `force_add_ancillary(holder, key, true, true)`.

### `cm:reassign_ancillaries_to_character_of_same_faction(source_character, destination_character)` — DOC

"Reassign all ancillaries from one character to another." Same faction only, all items at once. Not useful for trading.

### `cm:character_details_add_ancillary(character_details, ancillary_key)` — DOC

Adds an item to a `CHARACTER_DETAILS_SCRIPT_INTERFACE` (pre-configuring a character in the recruitment pool). Returns boolean "whether the ancillary was equipped successfully". Not useful for trading.

### `cm:set_non_scripted_ancillaries_disabled(disable)` — DOC

Blocks or allows items added by `common.ancillary`. `force_add_ancillary` still works.

### `common.ancillary(ancillary_key, chance, context)` — DOC

"Potentially adds the supplied ancillary to the character in the supplied context". `chance` is 0–100, and `context` must come from a character event (e.g. `CharacterCompletedBattle`). The docs call it "somewhat archaic". Not useful.

### Payload builder (missions, dilemmas, incidents) — NAME ONLY

Methods on the campaign payload builder: `faction_ancillary_gain`, `character_ancillary_gain`, `ancillary_loss`, `random_ancillary_loss`.
Helpers: `payload.ancillary_mission_payload(faction_key, [category], [rarity])` and `payload.ancillary_mission_payload_specific(faction_key)` build mission reward strings that add an item to the faction pool. `payload.add_ancillary_equivalence_mapping(faction_key, callback)` remaps ancillary rewards per faction.
These would most likely hit the same `faction_set` rule. Untested.

---

## 2. Reading items (campaign model)

### Character (`CHARACTER_SCRIPT_INTERFACE`)

| Method | Status | Notes |
|---|---|---|
| `has_ancillary(key)` | **TESTED** | true if this character wears the item. Works for AI characters (unlike the context field). Per key, not per copy. |
| `can_equip_ancillary(key)` | **TESTED** | false for a race-locked item on a foreign leader (E2W). Good pre-check. |
| `has_ancillary_set(...)` | NAME ONLY | item sets |
| `post_battle_ancillary_chance` | NAME ONLY | |
| `character_subtype_key()`, `command_queue_index()` | TESTED | used in logs |

### Faction (`FACTION_SCRIPT_INTERFACE`)

| Method | Status | Notes |
|---|---|---|
| `character_list()` | TESTED | iterate with `:num_items()` / `:item_at(i)` |
| `faction_leader()` | TESTED | |
| `is_contained_in_faction_set(set_key)` | **TESTED** | returns the expected false for foreign race sets. Pre-check for `faction_set`. |
| `ancillary_exists(key)` | NAME ONLY | |
| `num_ancillaries_owned()` | NAME ONLY | |
| `name()` | TESTED | faction key |

### Model / world

| Method | Status | Notes |
|---|---|---|
| `cm:get_faction(key)` | TESTED | |
| `cm:get_local_faction_name(true)` | TESTED | MP: differs per machine — never use it to decide model changes |
| `characters_owning_ancillary(key)` | NAME ONLY | on the world/model interface |
| `ancillary_exists` | NAME ONLY | also on world |

There is **no** model call that lists all items of a faction. Use the context system (§3).

---

## 3. UI context system

### `common.get_context_value([object_id], function_id)` — TESTED

We call it as `common.get_context_value("CcoCampaignRoot", "", expression)`. Returns Lua strings, numbers or booleans, or nil for an invalid field. About 2 ms per call.

Working expressions (TESTED):

```text
PlayersFaction
CurrentNegotiatingFactionContext              -- faction in the open negotiation
<faction>.Name
<faction>.FactionRecordContext.Key
<faction>.AncillaryList.Size
<faction>.AncillaryList.Filter(<condition>).Size
<faction>.AncillaryList.Filter(<condition>).At(i).<field>      -- i is 0-based
```

Fields on an item (`CcoCampaignAncillary`):

| Field | Status | Value |
|---|---|---|
| `AncillaryRecordContext.Key` | TESTED | DB key |
| `Name` | TESTED | localised; some uniques give `{{tr:...}}` |
| `AncillaryRecordContext.CategoryContext.Category` | TESTED | weapon / armour / talisman / enchanted_item / arcane_item |
| `AncillaryRecordContext.UniquenessRecordContext.Key` | TESTED | `wh_main_anc_group_*` — rarity, language independent |
| `AncillaryRecordContext.UniquenessRecordContext.UiState` | TESTED | `common` / `uncommon` / `rare` / `legendary` / `crafted` = frame state |
| `AncillaryRecordContext.UniquenessRecordContext.Max` | TESTED | rarity number |
| `AncillaryRecordContext.Transferrable` | TESTED | true / false |
| `AncillaryRecordContext.RarityName` | TESTED | localised display text with colour tags — do not use for logic |
| `CharacterEquippedToContext.Name` | TESTED | holder; **nil for AI holders** — use model `has_ancillary` |
| `OnscreenName`, `FrameState`, `IsTransferrable` | TESTED | nil (not on this object) |
| `AncillaryRecordContext.FactionSetContext.Key`, `.FactionSetKey`, `.FactionSet` | TESTED | nil — item's faction set not found yet |

### Reading the object behind a UI component — TESTED

```lua
local id   = uic:GetContextObjectId("CcoCampaignAncillary")   -- "1422"; returns NO value (not nil) when unset
local item = uic:GetContextObject("CcoCampaignAncillary")     -- cco userdata
local key  = item:Call("AncillaryRecordContext.Key")           -- any context expression
uic:SetContextObject(cco("CcoCampaignFaction", "<faction cqi>"))  -- point a native list at a faction
```

`common.get_context_value("CcoCampaignAncillary", "<id>", expr)` returns **nil**: items can't be looked up by id. Use the row's cco instead.
`common.get_context_value("CcoCampaignCharacter", "<cqi>", expr)` **works** (`Name`, `ImageCardPath`).

### `common.call_context_command([object_id], function_id)` — DOC

"Calls a specified function on a specified context object that makes changes to the game."
Commands seen in vanilla layouts on items (untested from script): `EquipToCharacter(character, ancillary)`, `RemoveAncillary`, `SalvageAncillaries(list)`, `DevAddAllAncillaries`. In the offers panel: `RunCLIMultiplayer("cai_force_deal_acceptance true")`.

---

## 3b. Changing the AI's deal evaluation — TESTED (spike S1)

DB link: `effect_bonus_value_cai_deal_component_junctions_tables` (`cai_deal_component`, `effect`, `bonus_value_id = evaluation_add`). An effect in an effect bundle on the **proposer's faction** adds its value to the AI's evaluation of that deal component. A bundle on the AI faction does nothing.

```lua
cm:apply_effect_bundle("<bundle key>", "<faction key>", 0)     -- 0 = no time limit (TESTED)
cm:remove_effect_bundle("<bundle key>", "<faction key>")        -- TESTED
faction:has_effect_bundle("<bundle key>")                       -- TESTED
cm:create_new_custom_effect_bundle("<base bundle key>")          -- DOC: bundle with values set at runtime
cm:apply_custom_effect_bundle_to_faction(custom_bundle, faction) -- DOC
```

- Scopes `faction_to_faction_own` and `faction_to_faction_own_unseen` both work.
- Takes effect at the **next deal change** (the AI recalculates when terms change).
- Shown only in the total, not in the breakdown tooltip.
- Proven components: `TRADE_AGREEMENT`, `NON_AGGRESSION_PACT`, `REQUEST_GIFT` (a lone demanded payment). The 45 components are a fixed engine list.

## 4. Item restrictions (DB)

`ancillaries_tables` (key columns): `transferrable`, `category`, `uniqueness_score`, `faction_set`, `randomly_dropped`, `can_be_stolen`, `can_be_destroyed`.
- `faction_set` — the race lock. 628 of 2874 rows are `all`; the rest are `anc_set_exclusive_<race>` and similar.
- `transferrable = false` — mounts, lord legendaries and a few specials. Exclude these.
- Rarity groups: `ancillary_uniqueness_groupings_tables` (see 01 doc §7.0.3).
- Other item tables: `ancillary_info_tables`, `ancillary_to_effects_tables`, `ancillary_ownership_content_pack_junctions_tables`, loc `text/db/ancillaries__.loc`.

---

## 5. Multiplayer

### `CampaignUI.TriggerCampaignScriptEvent([faction_cqi], [event_id])` — DOC

"Allows the script running on one machine in a multiplayer game to cause a scripted event, UITrigger, to be triggered on all machines in that game."
Listeners read `context:trigger()` (event id string) and `context:faction_cqi()`. Both arguments must be given, or neither.
This is the planned route for executing a trade: UI click → `TriggerCampaignScriptEvent` → a `UITrigger` listener on all machines → model changes from §1.

### `cm:progress_on_all_clients_ui_triggered(...)` — DOC

Waits until all clients have sent the same UI event, then continues.

The docs also warn: UI events are not synchronised with the model, so never change the model directly from a UI callback in multiplayer.

---

## 6. Events

| Event | Status | Notes |
|---|---|---|
| `AncillaryAddedToPool` | seen in vanilla layout | refresh trigger of the character panel list |
| `CampaignAncillaryAssigned` | seen in vanilla layout | refresh trigger of the character panel list |
| `UITrigger` | DOC | multiplayer bridge (§5) |
| `CharacterCompletedBattle`, `CharacterCreated` | DOC | character events usable with `common.ancillary` |
| `PositiveDiplomaticEvent` | DOC | deal accepted: `proposer`, `recipient`, `is_*` treaty flags, `is_state_gift`, `state_gift_amount` |
| `DiplomaticOfferRejected` | DOC | deal rejected: `proposer`, `recipient` |
| `DiplomacyNegotiationStarted` | DOC (name only) | in `events.lua`, context undocumented |

Full engine event list: `Vanilla_files/script/events.lua`. Model hierarchy docs: https://chadvandy.github.io/tw_modding_resources/WH3/scripting_doc.html

**Vanilla docs offline:** `Vanilla_files/documentation/` (script docs, `ui/documentation.html` = every context object, `ui/callback_documentation.html` = every UI callback). Flat searchable list of context functions: `docs/tools/cco_functions.txt`.

**UI → Lua:** context commands `TriggerUIScriptEvent("key")` (local) / `TriggerScriptEvent("key")` (via command queue = all machines) → Lua `UITrigger`, `context:trigger()`. Callback `ContextCommandEvent` with user property `event0 = <UI event>` runs an expression on that event (e.g. `CampaignNegotiationChange`).

**Item value / race lock from the context side (DOC):** `CcoCampaignAncillary.SalvageValue`, `CcoAncillaryRecord.CanFactionUseAncillary(CcoFactionRecord)`, `CcoAncillaryRecord.IncludedSubculturesList`.

`cm:cai_evaluate_quick_deal_action(proposer, recipient, action_key)` — DOC: returns `score, can_propose` for a one-treaty quick deal (9 actions from `diplomacy_quick_deal_offers_tables`); score > 0 = likely accepted.
