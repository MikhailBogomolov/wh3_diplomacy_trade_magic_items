# Other Modders' Examples — Review

Review of `Other modders examples/` (6 diplomacy mods), done 2026-10-27.

**This is a list of things we *may* look at, not a plan.** Nothing here is a decision or an obligation. When a topic comes up in our own work, check the matching section here for a possible shortcut or reference code.

Legend (same as `01_decisions_and_findings.md`): **PROVEN** = confirmed in game by us. **DOC** = seen in the mod's code / data or in vanilla, not tested by us. **HYPOTHESIS** = untested guess.

---

## 1. Summary

- **None of the six mods changes the AI's evaluation of one specific deal at runtime.** They either edit static DB tables (global, all game long) or work around native diplomacy entirely (AI Settlement Trading).
- **Nobody uses `effect_bonus_value_cai_deal_component_junctions`.** Our spike S1 mechanism (custom bundle with `evaluation_add` effects on the proposer) is beyond what these mods do.
- Most useful mod for us: **AI_settlement_trading_mod (AST)** — Lua only, MP-tested by its author. It has reference code for multiplayer sync, dilemma-based deals, and reading the native AI score from script.

| Mod | Type | Per-deal lever? | Worth a look for |
|---|---|---|---|
| AI_settlement_trading_mod | Lua + dilemmas | no (own parallel deal system) | MP sync pattern, dilemmas, `cai_evaluate_quick_deal_action`, determinism habits |
| NoGoldLimit | 1 DB table | no | `max_payment_value` (gold cap = 15 points) |
| Open_diplomacy | 2 DB tables | no | trade-partner penalty, threat level bundles |
| AI_Diplomacy_pack | many DB tables | no | full map of deal evaluation / generation tables |
| Diplomacy_overhaui_logic_and_balance (Katsuko) | many DB tables | no | same tables, attitude thresholds |
| DingoDiplomacy | DB tables | no | attitude effects in bundles / traits |

---

## 2. AI_settlement_trading_mod (AST)

### 2.1 How it works (DOC)

- **Does not touch the native deal screen.** Author's own limitation list: the mod can't see offers the player makes, can't add to them, can't react to a refusal.
- **AI-to-AI deals are simulated in Lua.**
  - `AST.evaluate_deal_for(faction, other, deal, turn)` (`_lib/mod/ast_lib_ai.lua`) scores a deal from one side's view as a sum of labelled points (`"province_capital-3"`, `"attitude(25)+1.2"`).
  - `AST.negotiate()`: the proposer must benefit (min score) → the counterparty can veto (score below a threshold) → otherwise accept chance = base % + per-point × score, then race "lore" multipliers, then a roll.
  - `AST.mirror_deal(deal)` flips a deal to the other side's view.
- **Execution:** `cm:transfer_region_to_faction(region, faction_key)` + `cm:treasury_mod(faction_key, amount)`. After each transfer it **verifies the result**: "the call can return without an error and still not move the settlement" (`ast_lib.lua:756`). Settlements move first, gold after, so a failed transfer leaves nobody paying for nothing.
- **Offers to the player use dilemmas** (`campaign/mod/ast_player_offers.lua`): choices accept / decline / haggle / never ask again. The player's gold is a `treasury_adjustment` payload on the FIRST choice (the amount shows on the button and the game moves it); the script moves the AI's gold and the settlement on `DilemmaChoiceMadeEvent` (`context:choice()` 0..3).
- **Settlement price:** about 25 turns of income + buildings + bonuses (port, resource, province capital), then attitude and "really wants it" adjustments (`AST.settlement_worth`, `AST.fair_price`, `ast_lib.lua:836`).

### 2.2 Things we may use

**A. Reading the native AI score from script — `cm:cai_evaluate_quick_deal_action` (DOC)**

```lua
local score, can_offer = cm:cai_evaluate_quick_deal_action(from_faction, to_faction, "diplomatic_option_peace")
```

- Returns the AI's native rating of a one-term deal, plus whether it can be offered at all. AST wraps it in `pcall` and treats a non-number as "no answer" (`ast_peace.lua:40`).
- Also used by **vanilla scripts** with `diplomatic_option_nonaggression_pact` and `diplomatic_option_trade_agreement` → official API.
- Works for the 9 actions in `diplomacy_quick_deal_offers_tables` only: client_state, confederation, defensive_alliance, military_alliance, nonaggression_pact, peace, soft_access, trade_agreement, vassal. **No payments, no settlements.**
- AST also uses it in multiplayer (`PEACE_GAME_RATINGS_IN_MULTIPLAYER = true`) → the author believes it is model-side and deterministic (HYPOTHESIS for us).
- **Possible use:** a debug probe without UI. Rating of trade agreement / NAP with and without our `items_trading_*` bundle on the proposer → measure the bonus, calibrate item values, check whether the bonus counts immediately (no deal change needed). `TRADE_AGREEMENT` and `NON_AGGRESSION_PACT` already reacted to our bundle in S1, so they are good probe components.

**B. Multiplayer pattern: UI-only data → all machines (DOC, author tested it in 2 long co-op sessions)**

`campaign/mod/ast_reliability.lua:250-390`:
1. On a model event (`FactionTurnStart` / `FactionTurnEnd`), only the machine of the human concerned acts: `faction:is_human() and cm:get_local_faction_name(true) == faction:name()`.
2. It reads UI-only data there (`common.get_context_value("CcoCampaignCharacter", cqi, "MilitaryForceContext.…")`).
3. It sends `CampaignUI.TriggerCampaignScriptEvent(human:command_queue_index(), "ast_trespass|<faction>|<payload>")`.
4. A `UITrigger` listener on **all** machines parses `context:trigger()` with `string.match` and only then changes saved values / the model.
5. Comment in the code: the sending part must not change saved state, because it runs on one machine.

This is the same route we planned for Phase 5 (execute the item transfer). Reference code for the string format and the parsing.

**C. Script text inside DB-driven UI text (DOC)**

```lua
common.set_context_value("ast_region_text", "the major settlement of X, in the province of Y")
```
Dilemma text (`db/dilemmas_tables/ast_dilemmas.tsv`):
```text
{{CcoCampaignEventDilemma:ScriptObjectContext("ast_region_text").StringValue}}
```
- The value is per machine: AST sets it only on the machine of the player who will read it.
- Possible use: item names / prices in tooltips or texts. Whether `ScriptObjectContext(...)` also works inside our twui layouts — HYPOTHESIS.

**D. Dilemma as a deal form (DOC)**

`cm:create_dilemma_builder(key)` → `builder:possible_choices()`, `builder:add_choice_payload(choice, payload)` with `cm:create_payload()` + `payload:treasury_adjustment(n)`, `builder:add_target("default", faction)`, `builder:add_target("mission_objective", region)` → `cm:launch_custom_dilemma_from_builder(builder, human_faction)`; answer in `DilemmaChoiceMadeEvent`. DB rows: `dilemmas_tables`, `cdir_events_dilemma_option_junctions_tables`, `cdir_events_dilemma_choice_details_tables`, loc.
A dilemma choice is a model event → MP-safe.
Possible uses: (1) a ready fallback for **option 2** (our own items-only deal) if native integration fails; (2) later, **AI-initiated item offers** ("we'd sell you X for 3000 gold").

**E. Changing attitude from script — `cm:apply_dilemma_diplomatic_bonus(a_key, b_key, amount)` (DOC)**

AST calls it both ways after friendly deals (`ast_lib.lua:1409`). Possible use: optional goodwill after an item gift. It changes relations, not the deal score directly.

**F. Diplomatic events (DOC)**

`PositiveDiplomaticEvent` / `NegativeDiplomaticEvent` with `context:proposer()`, `context:recipient()` and flags (`is_peace_treaty`, `is_war`, `was_military_alliance`, `was_defensive_alliance`). AST detects settlement transfers with **`RegionFactionChangeEvent`**, not with a diplomacy event. → Hint that there may be no "payment deal accepted" event. Our E3b is still needed.

**G. MP determinism habits (DOC)**

- Lists are sorted before iterating (`AST.to_sorted_array(list, key_fn)`); no `pairs()` order for decisions.
- Cached answers (`AST.memo`) are cleared when a job starts and after every transfer, so every machine sees the same state.
- Randomness only through `cm:random_number`.
- Every job runs in `AST.safe_run(name, fn)` (pcall + log), so one failure doesn't stop the others.
- Wrapping a `cm` function to observe other scripts: `cm.force_diplomacy` is replaced by a wrapper that logs and then calls the original (`ast_lib_memory.lua:534`). It can't catch native UI deals (they don't go through Lua), but it may help with compatibility.

**H. Debug-friendly scoring (DOC)**

Score = sum of labelled points, one log line per decision (`AST.describe_negotiation`: `score_p=… [reasons] score_c=… [reasons] accept%=…`). A possible template for our item value formula (Phase 6) and its logs.

---

## 3. DB-only mods

All static, global, same for every deal. No runtime lever.

### 3.1 `cai_personality_deal_evaluation_components_tables` (NoGoldLimit, Open_diplomacy, AI_Diplomacy_pack)

One row per deal personality (~80: `wh3_deal_eval_<race>[_major|_minor|_unfriendly]`, `_default`, …). Columns of interest:

| Column | Vanilla (per mods) | Note |
|---|---|---|
| `max_payment_value` | 15 | **Gold can move a deal by at most 15 points.** NoGoldLimit → 999, AI_Diplomacy → 10. |
| `payment_requested_multiplier`, `payment_offered_multiplier_under/over` | 2 / 5 / 20 | how gold is weighed |
| `min_gdp_for_payment_evaluation` | 1000 | |
| `trade_agreement_modifier_per_exceeded_trade_agreements` | −3 | Open_diplomacy → 0 |
| `nonpenalised_trade_agreement_base`, `additional_nonpenalised_trade_agreements_per_region` | 3 / 0.2 | |
| `recent_treaty_modifier(_turns)`, `recent_treaty_broken_modifier(_turns)`, `original_offer_modifier`, `peace_penalty`, `war_penalty`, `confederation_*` | | |

What it tells us:
- **A payment can't carry an item's value** (capped at 15 points). Our `evaluation_add` effect gave +32320 in S1, no cap seen. An argument for the effect route.
- Rough gold → points ratio from the NoGoldLimit description: **~40–50k gold ≈ 15 points** (example only, depends on the faction). A first reference if we want item values to feel like gold.
- A 1-gold carrier payment adds almost nothing to the score — good for the carrier idea.

### 3.2 `cai_personality_deal_evaluation_deal_component_values_tables` (AI_Diplomacy_pack, Katsuko)

Row per (deal component × personality), 45 components. Columns: values per attitude level (`best_friends_value` … `bitter_enemies_value`), `*_balance_factor` per war state (peace / tension / war / total_war / last_stand), `treachery_value`, `opponent_treachery_modifier`, `opponent_respect_modifier`, `main_threat`, `have_common_threat`, `long_distance_penalty_min/max`, `diplomatic_score_bound_lower/upper`, `same_subculture_modifier`, `war_losses_*`, `existing_treaties_multiplier`, `recent_ultimatum_*`, `vassal_master_strength_multiplier`, `region_hint_*`.
A map of what the native score (and its tooltip breakdown) is made of. `REQUEST_GIFT` / `OFFER_GIFT` weights are small (about 1–5). Reference only.

### 3.3 Other tables seen

| Table | Mod | Content |
|---|---|---|
| `cai_personality_deal_evaluation_deal_component_opponent_context_modifiers_tables` | AI_Diplomacy | modifiers with an `is_player` column (player vs AI opponent) |
| `cai_personality_deal_generation_generator_priorities_tables` | AI_Diplomacy | how the AI builds its own / counter offers: priorities per war state, `min_payment_cap`, `max_payment_cap`, `max_payment_pct`. May matter for the "make it work" button next to our carrier |
| `cai_variables_tables` `CAI_VARIABLE_REGION_TRADING_*` | AI_Diplomacy | native settlement-trade evaluation constants (province break penalty, building value multiplier, recently acquired, victory region) |
| `campaign_variables_tables` `diplomacy_*` | AI_Diplomacy | call-to-arms rules, embargo turns, `diplomacy_can_offer_break_vassal` |
| `faction_strategic_threat_levels_tables` | Open_diplomacy | threat level → effect bundle `wh_main_bundle_faction_imperium_level_N` (vanilla: `wh_main_effect_faction_imperium_diplomacy_penalty`, −5, `faction_to_faction_own_unseen`). Same "effect bundle on a faction → diplomacy" family as ours, but it acts on attitude |
| `*_political_diplomacy_mod_<culture>` effects in bundles / traits | DingoDiplomacy | attitude bonuses, scope `faction_to_faction_own_unseen`. Another possible goodwill lever |
| `campaign_cultural_relations_tables`, `cai_personality_cultural_relations_overrides`, `diplomatic_relations_attitudes_tables`, `diplomacy_negotiation_attitudes_tables` | Dingo, Katsuko, AI_Diplomacy | race relations, attitude thresholds (e.g. friendly ≥ 60, negotiation "friendly" ≥ 15) |

---

## 4. Ideas we may look at later (not decided)

| Idea | Source | When it could matter |
|---|---|---|
| Debug probe: `cai_evaluate_quick_deal_action` for trade agreement / NAP with and without our bundle → measure the bonus, check whether it counts without a deal change | §2.2 A | Phase 4 design, calibration in Phase 6 |
| Use AST's `TriggerCampaignScriptEvent` → `UITrigger` code as a template for the transfer | §2.2 B | Phase 5 |
| Sorting / verify-after-each-step / `safe_run` habits | §2.2 G | Phase 4–5 |
| Dilemma-based items deal as fallback option 2, or AI-initiated item offers | §2.2 D | only if native integration fails, or after MVP |
| `ScriptObjectContext` text for item tooltips / prices | §2.2 C | Phase 7 polish |
| Goodwill after item gifts (`apply_dilemma_diplomatic_bonus` or an attitude bundle) | §2.2 E, §3.3 | after MVP |
| Gold reference for item values (~40–50k ≈ 15 points; `max_payment_value` cap) | §3.1 | Phase 6 |
| Labelled-points scoring + one log line per decision | §2.2 H | Phase 6 |
