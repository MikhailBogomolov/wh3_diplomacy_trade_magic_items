# Trade Magic Items — START HERE

Handoff for the next chat. Last updated **2026-11-02** (**MVP released, 1.0.0**: deals with the AI and player-to-player in MP, turn-by-turn and simultaneous; known issues in §7).
Read this file first, then `01_decisions_and_findings.md` (full detail log) and `02_item_api_reference.md` (script API cheat sheet). `04_other_mods_review.md` is optional background (other diplomacy mods, ideas only).

---

## 1. The project in one paragraph

A Total War: WARHAMMER III mod that adds **trading of magic items through diplomacy**. A new action button in the negotiation screen opens our "Trade Magic Items" panel, which lists your items and the other faction's items. You tick the ones to offer or demand. The goal is that the ticked items become part of the **native deal**, with the AI really able to accept or refuse (no robbing NPC factions). When the deal is accepted, the items move. **The MVP must work player-to-player in multiplayer** (the main reason the mod exists); AI valuation can be simple at first.

---

## 2. How we work (agreed rules)

- The user packs files with **RPFM 5.2.0** and tests **everything in game**; Claude never launches the game.
- One testable block at a time; **ask before anything big**; explain trade-offs and let the user decide.
- Experiments live in a **debug file** (`diplomacy_magic_items_trading_debug.lua`, not in the release pack since 1.0.0; the last one is `docs/backups/diplomacy_magic_items_trading_debug.removed_for_release.lua`), never in the main Lua. Each experiment has an `*_ENABLED` switch; finished ones are switched off.
- Experiments that change the campaign need a **throwaway save**. The usual test save: **Neferata (`wh3_dlc29_vmp_neferata`) vs Disciples of Hashut (`wh3_dlc23_chd_astragoth`)**.
- After each test the user sends: screenshots + the script log (`C:\Games\steamapps\common\Total War WARHAMMER III\script_log_<date>_<time>.txt`).
- Log prefixes: main mod `[MAGIC_ITEMS_DIPLOMACY <version>]`, debug file `[MAGIC_ITEMS_E1 <experiment version>]`.
- **Temporary logs (user, 2026-11-01):** every risky place gets logs for what players can't see on screen, so each run collects as much as possible. Tester sessions are expensive. In MP both clients send their logs.
- Every finding goes into `01_decisions_and_findings.md` with PROVEN / DOC / HYPOTHESIS status.
- Vanilla reference files: `D:\Games\Modding\Diplomacy_Trade_Magic_Items_Mod\Vanilla_files\` (folder renamed from `Diplomacy_Magic_Items_Trading_Mod`; the tools' paths follow since 2026-11-03) (db, script, text, ui, **documentation** = CA's own script + UI/context docs; search the flat list `tools/cco_functions.txt` for context objects). The extraction is incomplete — ask the user to extract missing files. `Other modders examples\` (6 diplomacy mods) is **reviewed** in `04_other_mods_review.md` — a list of things we *may* look at (reference code, ideas), **not** decisions or obligations.

---

## 3. Files

### Pack folder `Diplomacy_Magic_Items_Trading_packfile/` (pack name `diplomacy_magic_items_trading.pack`, renamed from `artifact_diplomacy_trading.pack` 2026-10-29)

| File | Purpose | State |
|---|---|---|
| `script/campaign/mod/diplomacy_trade_magic_items_deal_manager.lua` | log, every number of the deal (`DEAL TUNING`), deal memory in the savegame, evaluation, the trade, human deal events: **v1.0.1** (`AD_VERSION` is here; 1.0.0 = 0.14.0 without the temporary logs, the release; 1.0.1 = mirrors regenerated for patch 9.0.5, findings §7.4) | see findings |
| `script/campaign/mod/diplomacy_trade_magic_items_screen.lua` | our window: lists, selection, gold, chance, balance button, OK / Cancel, trade watch | see findings |
| `script/campaign/mod/diplomacy_trade_magic_items_diplomacy_option_button.lua` | action row button, watcher, war lock, diplomacy helpers | see findings |
| `script/campaign/mod/diplomacy_tradeable_magic_items_mirror.lua` | **GENERATED** by `tools/build_diplomacy_tradeable_mirrors.js`: global table original key → faction set of the 595 race-locked tradeable items (last run: patch 9.0.5, 2026-11-03, findings §7.4) | regenerate after game patches |
| `db/<7 tables>/diplomacy_tradeable_magic_items_mirror.tsv`, `text/diplomacy_tradeable_magic_items_mirror.loc.tsv` | **GENERATED** mirror items `<key>_diplomacy_tradeable` (`faction_set = all`, `randomly_dropped = false`, no DLC ownership row since 0.12.1) in `ancillaries_tables`, `ancillary_info_tables`, `ancillary_to_effects_tables`, `ancillary_to_included_agents_tables`; mirror item sets `<set>_diplomacy_tradeable` in `ancillary_sets_tables`, `ancillary_set_ancillary_junctions_tables`, `ancillary_set_effect_junctions_tables`; loc English only | regenerate after game patches |
| `ui/campaign ui/diplomatic_option_trade_magic_items.twui.xml` + `diplomacy_icons/diplomatic_option_trade_magic_items.png` | our square action button | working |
| `ui/campaign ui/diplomacy_hud_trade_magic_items.twui.xml` | our panel: **760×425 (4 items per column = smallest size, up to 788 high), own background, height-only resize handle `button_enlarge_br`, our treasury top left, the partner's top right, deal chance next to the buttons, gold switch + amount bottom left** (built by `tools/build_panel_plan_b.ps1` from the backup), two columns with native item list rows, filter, category sort | working |
| `ui/campaign ui/ad_holder_portrait.twui.xml` | callback-free "equipped by" portrait for rows of other factions | working |
| `db/diplomatic_actions_tables/diplomacy_trade_magic_items.tsv` | our action key (sort_order 210); renamed from `diplomacy_magic_items_trading.tsv` (2026-11-03), before that `items_diplomacy_trading.tsv` | working |
| `text/diplomacy_trade_magic_items.loc.tsv` | loc (renamed from `diplomacy_magic_items_trading.loc.tsv` 2026-11-03, before that `artifact_diplomacy_trading.loc.tsv`; keys prefixed `trade_magic_items_`, were `items_trading_`): button title/tooltip; deal chance tooltip texts `trade_magic_items_deal_chance_*` (placeholders), gold switch labels `trade_magic_items_offer_payment` / `trade_magic_items_demand_payment`, `trade_magic_items_deal_chance_total`, `trade_magic_items_button_needs_peace`; panel title, hint and column titles (0.12.10, set by script) | working |

### Translation pack folder `Diplomacy_Magic_Items_Trading_ru_packfile/` (Russian, findings §7.3)

| File | Purpose |
|---|---|
| `text/diplomacy_trade_magic_items.loc.tsv` | same keys as the main pack, values written by the user |
| `text/diplomacy_tradeable_magic_items_mirror.loc.tsv` | **GENERATED** by `tools/build_ru_mirror_loc.js` from the Russian vanilla loc; regenerate after the main mirror generator |

Every text of ours goes through a loc key; only texts copied from vanilla with their vanilla layout label are left to the engine (findings §7.3).

Renamed 2026-11-03 before the Workshop release (delete the old files from the pack; copies in `docs/backups/before_rename_2026-11-03/`): the three scripts `diplomacy_magic_items_trading_*.lua` → `diplomacy_trade_magic_items_*.lua`, `db/diplomatic_actions_tables/diplomacy_magic_items_trading` → `diplomacy_trade_magic_items`, `text/diplomacy_magic_items_trading.loc` → `diplomacy_trade_magic_items.loc` (main and RU pack), loc keys `items_trading_*` → `trade_magic_items_*`. Step 2 (same day, copies in `before_rename_2026-11-03/step2_identifiers/`): everything else with the old prefixes → `trade_magic_items`: the Lua global table (`trade_magic_items.log`, …), layout component ids, user properties, `UiMsg` / UI script events (`trade_magic_items_gold_clamp`, `_payer`, `_waiting`, …, also in `tools/build_panel_plan_b.ps1`), the deal events `dmit_trade` / `dmit_human` → `trade_magic_items_trade` / `trade_magic_items_human` (longest op still ~145 of 255 chars), saved values `dmit_recent_items` / `dmit_faction_deals` → `trade_magic_items_recent_items` / `trade_magic_items_faction_deals` (**deal memory of older saves is not read any more**; harmless before release). Not renamed: the local `ad_` / `AD_` helpers, the mirror files, the pack name. Script load order unchanged (`diplomacy_trade_` sorts before `diplomacy_tradeable_`). A debug file put back from `backups/` would need the new file name and the new table / event names.

Removed for the 1.0.0 release (delete from the pack; copies in `docs/backups/*.removed_for_release*`, put them back for a debug run): `script/campaign/mod/diplomacy_magic_items_trading_debug.lua`, `script/enable_console_logging`. Removed in 0.12.1: `db/ancillary_ownership_content_pack_junctions_tables` (mirror DLC rows).

Renamed / removed 2026-10-29 (delete from the pack): `script/campaign/mod/items_diplomacy_trading.lua`, `items_diplomacy_trading_debug.lua`, `text/artifact_diplomacy_trading.loc`, `db/diplomatic_actions_tables/items_diplomacy_trading`, all `items_trading_mirror_test` files (M1).

Removed 2026-10-28 (Plan B cleanup, also delete them from the pack): `db/effects_tables`, `db/effect_bundles_tables`, `db/effect_bundles_to_effects_junctions_tables`, `db/effect_bonus_value_cai_deal_component_junctions_tables`, `ui/campaign ui/ad_offer_magic_items.twui.xml`, `items_trading_list_probe_plain.twui.xml`, `items_trading_list_probe_row.twui.xml`, `items_trading_list_probe_bare.twui.xml`, `items_trading_negotiation_broadcaster.twui.xml` (if still in the pack), effect/bundle loc lines.

### Docs folder `Diplomacy_Magic_Items_Trading_docs/`

| File | Content |
|---|---|
| `00_START_HERE.md` | this file |
| `00_handoff_original.md` | the very first handoff (frozen, partly outdated) |
| `01_decisions_and_findings.md` | everything learned, decisions, test results, roadmap (§7) |
| `02_item_api_reference.md` | API cheat sheet for items, context system, MP |
| `03_question_for_modders.md` | short question posted to experienced modders (race-lock workaround) |
| `05_same_race_trading_list.md` | runes and character-limited items for same-race trading after release |
| `04_other_mods_review.md` | review of `Other modders examples/`: what each mod does, reference code and ideas we may use (optional) |
| `06_lessons_for_new_mods.md` | briefing for Claude on the next mods: user preferences, workflow, resource map (absolute paths), engine model, recipes with code locations, MP rules, proven pitfalls, dead ends, debugging playbook, release checklist, bootstrap steps |
| `tools/build_item_list.ps1` | how the native item list was copied into our panel (already applied — reference only, it expects the old placeholder row) |
| `tools/build_holder_portrait.ps1` | rebuilds `ad_holder_portrait.twui.xml` from the vanilla template |
| `tools/build_diplomacy_tradeable_mirrors.js` | **mirror generator** (node): reads `Vanilla_files` db + `text/db/ancillaries__.loc.tsv` + `text/db/ancillary_sets__.loc.tsv`, writes the mirror tables, loc and Lua map into the pack folder; run after every game patch (steps in its header) |
| `tools/build_ru_mirror_loc.js` | Russian mirror loc for the translation pack (node): our mirror keys minus the suffix → Russian vanilla `text/localisation__.loc.tsv` |
| `tools/build_panel_plan_b.ps1` | rebuilds our panel from `backups/diplomacy_hud_trade_magic_items.before_plan_b.twui.xml`: own background, 850×475, taller columns, resize handle |
| `backups/` | panel layout and main Lua before Plan B, the old debug file (E2 = item transfer reference), `build_offer_row.ps1` (deal row builder, obsolete) |
| `tools/cco_dump.js`, `tools/cco_functions.txt` | flat searchable list of all context objects/functions from CA's `documentation.html` |

---

## 4. Where we are

| Phase | Status |
|---|---|
| 1. UI shell (button, panel, open/close like vanilla, no freezes) | ✅ done |
| 2. Experiments E1 (list items) / E2 (move items) | ✅ done |
| 3. Item list UI (native rows, filter, sort, equipped-by portraits incl. AI, selection state / pending trade, no drag) | ✅ done |
| Button availability + survives UI rebuilds (watcher) | ✅ done (v0.3.3) |
| Spike S1 — can we change the AI's native deal score? | ✅ **yes** (see §5) |
| **E3 — carrier term + accept/decline events** | ⏭ in test: **E3c** forced Send + E3b event log (findings §7.0.14) |
| Deal rows "Trade Magic Items" in Your Offers / Your Demands (v0.4.0, visual only) | ⏭ in test (findings §7.0.14) |
| 4. Deal integration (Magic Items row, AI valuation via bundle, carrier payment, execute on accept) | not started |
| Race lock workaround (mirror items, "variant D") | accepted in principle, waiting for modders' replies; not started |
| 5. Multiplayer MVP | **released, 1.0.0 (2026-11-02)** |
| 6. Real AI valuation | after MVP |
| 7. Polish (click sound on item rows, tooltips, localisation, edge cases) | later |

---

## 5. Most important proven facts (cheat sheet)

**UI**
- `find_uicomponent()` returns a UIComponent — never wrap it in `UIComponent()` again (that was the freeze). `UIComponent()` only for raw addresses (`CreateComponent`, `CopyComponent`, `Find(i)`, `Parent()`).
- Our panel open/close = exactly vanilla Trade Settlement: open → `offers_panel` hidden, `subpanel_group` + our panel visible; close → reverse.
- `uic:SetContextObject(cco("CcoCampaignFaction", "<cqi>"))` points a native list at any faction. Our XML must **not** use `ContextInitPlayerFaction` (copied right column filled itself with player items → empty rows).
- **Template callbacks can't be removed or overridden** from an instance in our layout. Work around at runtime, or replace the component with our own callback-free one (`ad_holder_portrait`).
- Row lock: `SetMoveable(false)` blocks drag. (`SetDisabled(true)` also kills the click sound but makes hover sound unreliable → not used.)
- `GetContextObjectId(...)` returns **no value** (not nil) when unset — store it in a local before `tostring()`.
- To read a row's item: `row:GetContextObject("CcoCampaignAncillary"):Call("<expression>")`. `common.get_context_value("CcoCampaignAncillary", id, …)` returns nil. Characters by cqi work: `common.get_context_value("CcoCampaignCharacter", "<cqi>", "Name" / "ImageCardPath")`.
- Native diplomacy rebuilds the action row on every change → a UI real-time watcher (33 ms, `cm:repeat_real_callback`, only while diplomacy is open) re-adds our button. Shown only when Payment or Trade Settlement is possible (not at war without peace, not with confederation).

- **Never put our components into the native deal `list_box`es** (`your_offers_list` / `their_offers_list`): removing a native term then crashes the game (0.4.0). Our deal rows live in the column and are positioned by script.

**Items**
- List items: `CcoCampaignFaction.AncillaryList` (context system). Equipped-by for **AI** characters: model `character:has_ancillary(key)` (context field is empty for AI).
- Rarity key: `AncillaryRecordContext.UniquenessRecordContext.Key` (`wh_main_anc_group_common/uncommon/rare/crafted` tradeable; unique, unique_fusable, rune, scrap hidden). Also hide `Transferrable == false`.
- Move items: `cm:force_remove_ancillary(char, key, false, …)` (one character's copy), `cm:add_ancillary_to_faction(faction, key, …)` (to pool). `force_remove_ancillary_from_faction` removes **all** copies.
- **Race lock:** items only arrive if the receiver is in the item's `ancillaries_tables.faction_set` (637 of 753 tradeable items are race-locked). `force_add_ancillary(..., force_equip=true)` does not bypass it. Pre-check: `faction:is_contained_in_faction_set(set)` / `character:can_equip_ancillary(key)`. **Fix in place (PROVEN 0.7.4–0.7.5): mirror items** `<key>_diplomacy_tradeable` (generated, `faction_set = all`); a mirror given back to a faction that may own the original arrives as the original.

**TWW3 Lua pitfalls (PROVEN 2026-10-29, each crashed the game)**
- Never call `string.find` with a start position / plain flag — it broke the Lua state (every UIComponent then failed `is_uicomponent`, later crash). Split strings vanilla-style (cut the rest, see `ad_split`).
- `math.huge` does not exist (nil): the whole mod fails to load, the log says `Failed to load mod`.
- `CampaignUI.TriggerCampaignScriptEvent` cuts its string to **255 chars** → one short event per op, length checked before sending.
- The vanilla logger writes each line at once (no buffer): a line cut mid-text means the string itself was cut.

**AI deal score (spike S1)**
- DB `effect_bonus_value_cai_deal_component_junctions` (effect → deal component, `evaluation_add`) + an effect bundle **on the proposer's faction** (the player) adds points to the AI's evaluation of that component. Bundle on the AI does nothing.
- It counts only after the **next deal change** (the AI recalculates when terms change). It goes into the total, not into the breakdown tooltip.
- **S2 (2026-10-28): custom bundle `items_trading_item_value` with a script-set value (also negative) works; the model and the AI's decision on Send use it instantly; it is added **once per distinct deal component** (a bilateral treaty counts once; two different treaties = twice — S4.1); only the shown number waits for a native deal change; a broadcast of `CampaignNegotiationChange` does not refresh it.** Remove the bundle when the negotiation with that faction ends.
- Proven components: `TRADE_AGREEMENT`, `NON_AGGRESSION_PACT`, and **`REQUEST_GIFT`** (a lone demanded payment flipped from refused to accepted; the panel shows accepted gift demands as "0.0").
- Native deal facts: Propose is greyed out with an empty deal; minimum payment is 1 gold; deal components are a fixed engine list of 45 (new term types are impossible).
- **Force-enabling Send does not make the AI accept** (E3c): the AI evaluates on receipt and refuses (or counter-offers). Refusal fires `DiplomaticOfferRejected` (`proposer`, `recipient`). We can only block Send, not force acceptance.

---

## 6. Decisions already made (don't re-ask)

- Naming: action `diplomatic_option_trade_magic_items`, panel `trade_magic_items`; pack `diplomacy_magic_items_trading.pack` (was `artifact_diplomacy_trading`, renamed 2026-10-29); new loc keys prefixed `trade_magic_items_` (2026-11-03, were `items_trading_`).
- Tradeable: common, uncommon, rare, crafted. Not shown: unique, unique_fusable, rune, scrap, non-transferrable. Race-locked items are not greyed out.
- Items sorted by category, no sort button.
- Selection: Cancel discards changes since opening; OK keeps the pending selection; reopening restores ticks; another partner or closing diplomacy clears it; no item limit. OK stays active when everything is unticked after a saved selection (pressing it clears it).
- Clicking an item does nothing; it may still play a click sound (accepted for now).
- Button watcher: keep the timer (event-driven alternative was compared and rejected for now).
- AI must have a real chance to refuse. ~~Preferred: native integration~~ — **2026-10-28: native integration abandoned (too many fragile workarounds); our own deal in our panel (Plan B).**
- Race lock: mirror items (variant D) acceptable.
- Carrier term (2026-10-27): **no visible driving of the native Payments panel** (the old E3a plan). A same-frame "invisible" carrier is also rejected as too hacky (findings §7.0.10).

---

## 7. Next steps

**Released 2026-11-02: MVP 1.0.0** (user: the flow is good; logs of two MP campaigns clean: no script errors, trade ops identical on both clients). The temporary logs (M2 / M3, HUD check, partner money, attitudes, the dry-run / direct debug switches), the debug file and `script/enable_console_logging` are out of the pack.

Done:
- **The deal with the AI (2026-11-01).** Exchange, mirrors, evaluation, deal memory in the savegame, balance button, result view with the native text and sound. The AI has no separate answer yet: at total >= 0 the deal goes through.
- **Multiplayer, player to player** (design in `01_decisions_and_findings.md` §7.1a): window for a human partner (hidden balance and chance, Counteroffer, waiting label, locks); proposals, accept, decline, counteroffer, the trade, mirrors without the DLC, recently traded across players; turn-by-turn and simultaneous turns with no desync. Simultaneous turns: `OpenDiplomacyWith` forces the other player in, offers panel hidden while forced and not shown on its close, `CloseDiplomacyPanel` (never `CampaignUI.ClosePanel`). The 1-gold native carrier (0.13.x) was tried and rejected. Don't touch the sound (user).

**Known issues (accepted for the release, user 2026-11-02):**
1. Simultaneous turns: if the receiving player is in diplomacy at that moment, after leaving the deal they may be stuck on a wrong window.
2. Turn-by-turn: if the player who called the other into diplomacy proposes too fast, the second player gets the offers panel popping up behind (the native after-dialogue animation).
3. Simultaneous turns: on the forced client the two lords' lines are swapped (a correct native invite needs a real native proposal).

Native, not ours (user, vanilla test): the pulled player sees the offers panel at once and it slides in again after the dialogue. The native "Waiting on player..." lasts until the other leaves diplomacy.

Open small items: fade of the deal gift over turns, Deals frequency reset after 15 turns, `STATE_GIFT_MEDIUM` line in the tooltip. Later: AI answer with a real chance to refuse, same-race trading (`05_same_race_trading_list.md`).

**Multiplayer rules (keep to these):**
- The model changes only in code that runs on every client: a `UITrigger` handler fed by `CampaignUI.TriggerCampaignScriptEvent`, or model events. Never in a click or other UI listener: those run on one machine.
- Everything the handler needs travels in the event string: UI values (ids, counts, amounts) never get read inside it. Strings are cut at 255 chars.
- `cm:get_local_faction_name(true)` differs per client: only for UI, never to decide a model change. A UI step in a shared handler goes behind that check.
- Random numbers: `cm:random_number` only in shared code, never `math.random`, time or `os.date`.
- `cm:set_saved_value` only in shared handlers, with the same values everywhere; reading it for display is fine.
- Evaluate the deal on the sender's machine, then re-check in the handler only with model data, so two clients cannot disagree.
- `pairs()` order is not guaranteed: its result may build a string on one client, but must not drive model changes directly in shared code.
- Real-time callbacks only for UI. All players need the same mod version.

## 8. What the user can do to help

- **Bring replies** from the modders' post (`03_question_for_modders.md`) — especially anything about bypassing `faction_set` or equip rules.
- **Context Viewer exploration** (very useful for Phase 4):
  - With a deal assembled: left "Context shortcuts" → **Campaign UI Root (CcoCampaignRoot)** → in Queries find `DiplomacyManagerContext` → click → screenshot all its fields/functions (looking for something like a current / active negotiation). Also note anything else on CcoCampaignRoot named *Diplomacy* / *Negotiat* / *Deal*.
  - Events tab of the Context Viewer while adding / removing a term: which events fire.
  - A row of those lists (only exists while an offer is pending) carries `CcoCampaignNegotiation` → screenshot its fields — looking for deal contents (offers/demands), the evaluation, or add / refresh commands.
  - Hover a native term row in Your Offers / Your Demands (e.g. "Payments", "Trade Settlement") and note the **component names** in the tree (we need them for our own "Magic Items" row and for the button rule).
- **Quick check for v0.3.3:** put both a payment and a settlement into the deal as terms — does our button stay? If not, send the log line `Item trading NOT available: ... (terms: ...)`.
- **UX opinions for Phase 4:** should the 1-gold carrier row be visible or hidden behind our "Magic Items" row? Rough values per rarity (common / uncommon / rare / crafted) and how much more the AI should want for an equipped item.
- **Plan an MP session** with the second tester for when Phase 5 starts.
- Keep a throwaway Neferata vs Hashut save ready.
- Extract vanilla files when asked (the vanilla extraction is incomplete).
