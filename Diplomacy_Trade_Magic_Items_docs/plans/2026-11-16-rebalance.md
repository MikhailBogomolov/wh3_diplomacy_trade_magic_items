# 1.1.0 Rebalance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Put the agreed 1.1.0 balance into the deal evaluation: new rarity points, worn as +30%, attitude as a percentage on the price of their items with an Order and a Destruction scale, no attitude on their gold, softer deals frequency, big deal at 35.

**Architecture:** All numbers stay in the DEAL TUNING block of the deal manager; `trade_magic_items.evaluate_deal()` keeps its breakdown fields (the screen reads them by name), with two new ones for the percentage. The screen only changes how the prospects line is written, the balance button's gold sum and the log line.

**Tech Stack:** Lua 5.1 campaign scripts (Total War: WARHAMMER III). No Lua runtime outside the game: checks are the Lua check tool plus the in-game numbers below.

**Spec:** `Diplomacy_Trade_Magic_Items_docs/01_decisions_and_findings.md` §7.6

## Global Constraints

- 1 point = 1 000 gold (`GOLD_PER_POINT` stays 1000). Totals ≥ `DEAL_ACCEPT_SCORE` (0) are accepted.
- Item rarity points: common 2.5, uncommon 6, rare 14.4, crafted 20. Ancillary (Banners / Followers tabs) points: 2, 4, 8, crafted 8.
- Worn by one of their characters: +30% of the item's rarity points, items and ancillaries alike.
- Attitude: percentage on (rarity + worn) of the items they give. Order: ≥300 −25, ≥200 −20, ≥150 −15, ≥100 −10, ≥50 −5, ≥25 0, between −25 and 25 +5, ≤−25 +10, ≤−50 +20, ≤−100 +35, ≤−150 +50, ≤−200 +70, ≤−300 +100. Destruction: ≥300 −12.5, ≥200 −10, ≥150 −7.5, ≥100 −5, ≥50 −2.5, ≥25 0, between −25 and 25 0, ≤−25 0, ≤−50 +5, ≤−100 +10, ≤−150 +20, ≤−200 +30, ≤−300 +50. Minus = cheaper for the player.
- The partner's subculture picks the scale. Destruction: `wh_main_sc_chs_chaos`, `wh3_main_sc_dae_daemons`, `wh3_main_sc_kho_khorne`, `wh3_main_sc_nur_nurgle`, `wh3_main_sc_sla_slaanesh`, `wh3_main_sc_tze_tzeentch`, `wh_dlc03_sc_bst_beastmen`, `wh_dlc08_sc_nor_norsca`, `wh_main_sc_grn_greenskins`, `wh_main_sc_grn_savage_orcs`, `wh2_main_sc_skv_skaven`, `wh3_dlc23_sc_chd_chaos_dwarfs`, `wh_main_sc_vmp_vampire_counts`, `wh2_dlc11_sc_cst_vampire_coast`, `wh3_main_sc_ogr_ogre_kingdoms`, `wh3_dlc29_sc_nag_undead_legions` (Nagash, user 2026-11-16). Every other subculture uses Order.
- Attitude never touches gold: the ×2 / ×3 multipliers go, demanded gold is −amount / 1000.
- Deals frequency: first 5, ×2 per further deal, gone after 15 turns. Recently traded unchanged (½ of rarity points, 10 turns). Big deal: rarity points of both sides ≥ 35.
- Deal window: the prospects line shows the percentage, green for a discount, red for a markup, then the points in brackets, e.g. `Diplomatic prospects: −25% (4.7)`. Worn stays a plain number.
- Commit only when the user asks.

## Review Focus

- A partner whose subculture is in neither list (rebels, a new DLC race): Order scale, no error. Pinned in Task 1's check.
- Attitude exactly on a border (25, −25, 300, −300): the tier tables use `>=` on the good side and `<=` on the bad side, as today; −25 and 25 themselves fall in the good/bad tiers (≥25 → 0%, ≤−25 → +10%), the middle is strictly between. Pinned in Task 3's in-game table.
- Nothing demanded yet (only our items or gold): the prospects line still shows the partner's current percentage with `(0.0)`, so the player sees the attitude before choosing. Task 2.
- Fractional percentages (Destruction −12.5%, −7.5%, −2.5%) print with one decimal, whole ones without: `−12.5%`, `−10%`. Task 2.
- The balance button when we demand gold: the sum equals the points × 1000 with no multiplier left anywhere (`their_gold_multiplier` must not be read after Task 1). Task 2's grep.

---

### Task 1: Tuning and evaluation (deal manager)

**Files:**
- Modify: `Diplomacy_Trade_Magic_Items_packfile/script/campaign/mod/diplomacy_trade_magic_items_deal_manager.lua` (DEAL TUNING block lines 15–126, DEAL EVALUATION lines 238–385)

**Interfaces:**
- Produces, on the table returned by `trade_magic_items.evaluate_deal()`:
  - `attitude_percent` (number, signed: +35 = 35% dearer, −25 = 25% cheaper; 0 without a partner)
  - `attitude_scale` ("order" / "destruction", nil without a partner)
  - `diplomatic_prospects` (points, + for the player: `−attitude_percent / 100 × price of their items`)
  - unchanged names: `economic_value`, `deals_frequency` (+ `_turns`, `_number`), `offered_rarity`, `offered_recent`, `demanded_rarity`, `demanded_equipped`, `demanded_recent`, `points_without_gold`, `total`, `attitude`
  - removed: `their_gold_multiplier`

- [ ] **Step 1: Replace the tuning values**
  - `AD_RARITY_POINTS` → 2.5 / 6 / 14.4 / 20; comment: ×2.4 per step, crafted = rare × 1.39.
  - `AD_ANCILLARY_RARITY_POINTS` stays 2 / 4 / 8 / 8.
  - Both BELONGS tables → one `AD_WORN_SHARE = 0.3` (share of the item's rarity points).
  - `AD_THEIR_GOLD_MULTIPLIERS`, `AD_ATTITUDE_GOOD_TIERS`, `AD_ATTITUDE_BAD_TIERS`, `AD_ATTITUDE_MIDDLE_POINTS` → `AD_ATTITUDE_SCALES = { order = { good = {…}, middle = 5, bad = {…} }, destruction = { … } }` with the Global Constraints values (`good` tiers `{ min_attitude =, percent = }`, `bad` tiers `{ max_attitude =, percent = }`, first match wins, ordered as listed).
  - `AD_DESTRUCTION_SUBCULTURES` = set of the Global Constraints keys.
  - `AD_DEAL_FREQUENCY_FIRST = 5`; `AD_BIG_DEAL_RARITY = 35`.

- [ ] **Step 2: Rewrite the attitude helpers**
  - `local function ad_attitude_scale(faction) -> "order" | "destruction"` from `faction:subculture()`.
  - `local function ad_attitude_percent(scale, attitude) -> number` walking the scale's tiers like today's `ad_attitude_points`.
  - Delete `ad_attitude_points`, `ad_their_gold_multiplier`, `ad_belongs_points`, and the two BELONGS tables.

- [ ] **Step 3: Change `trade_magic_items.evaluate_deal()`**
  - With a partner: set `attitude_scale` and `attitude_percent` always (also with nothing demanded).
  - Demanded gold: `economic_value = −amount / GOLD_PER_POINT` (no multiplier).
  - Worn: `demanded_equipped -= ad_rarity_points(info) × AD_WORN_SHARE` for items with `holder_cqi`.
  - Prospects: `price = −(demanded_rarity + demanded_equipped)`; `diplomatic_prospects = −price × attitude_percent / 100`. Recently traded is not part of `price` (spec: counted on the base price). The old `math.min(…, price)` cap goes.

- [ ] **Step 4: Run the Lua check**

  Run: `node D:/Games/Modding/tools/luacheck/check.js Diplomacy_Trade_Magic_Items_packfile/script/campaign/mod/*.lua`
  Expected: `4 files, 0 with syntax errors, 0 unknown globals`

- [ ] **Step 5: Check nothing still uses the removed names**

  Run: `grep -n "their_gold_multiplier\|ad_attitude_points\|BELONGS_TO_CHARACTER\|ad_belongs_points" Diplomacy_Trade_Magic_Items_packfile/script/campaign/mod/diplomacy_trade_magic_items_deal_manager.lua`
  Expected: no output (the screen is fixed in Task 2).

### Task 2: Deal window and balance button (screen)

**Files:**
- Modify: `Diplomacy_Trade_Magic_Items_packfile/script/campaign/mod/diplomacy_trade_magic_items_screen.lua` (DEAL CHANCE lines 1340–1510, `ad_balance_target` lines 1575–1590)

**Interfaces:**
- Consumes: `attitude_percent`, `attitude_scale`, `diplomatic_prospects` from Task 1.

- [ ] **Step 1: Prospects line with the percentage**
  - `local function ad_format_percent(percent) -> string`: one decimal only when not whole; sign always shown except for 0 (`−25%`, `+70%`, `−12.5%`, `0%`), `−` is the ASCII minus like the other numbers.
  - In `ad_show_deal_chance`, the line whose value key is `diplomatic_prospects` reads `name .. ": " .. <percent> .. " (" .. ad_score_text(points) .. ")"`, the whole value part wrapped in `[[col:green]]` when `attitude_percent < 0`, `[[col:red]]` when `> 0`, uncoloured at 0. Mark that line in `AD_DEAL_CHANCE_GROUPS` with a fifth field `"percent"` instead of special-casing its key.

- [ ] **Step 2: Balance button without the multiplier**
  - `ad_balance_target`: the demand branch becomes `math.floor(amount)`.

- [ ] **Step 3: Log line**
  - `ad_refresh_deal_chance` logs `attitude <n> (<scale> <percent>%) -> <prospects>` instead of `their gold x…`.

- [ ] **Step 4: Run the Lua check and the leftover grep**

  Run: `node D:/Games/Modding/tools/luacheck/check.js Diplomacy_Trade_Magic_Items_packfile/script/campaign/mod/*.lua`
  Expected: `4 files, 0 with syntax errors, 0 unknown globals`

  Run: `grep -n "their_gold_multiplier" Diplomacy_Trade_Magic_Items_packfile/script/campaign/mod/*.lua`
  Expected: no output.

### Task 3: Docs and the in-game check list

**Files:**
- Modify: `Diplomacy_Trade_Magic_Items_docs/01_decisions_and_findings.md` §7.6 (status → built, awaiting test; the check table below)
- Modify: `Diplomacy_Trade_Magic_Items_docs/00_START_HERE.md` (1.1.0 status line)

- [ ] **Step 1: Write the expected numbers into §7.6** (the user checks them in the deal window tooltip):

| Deal | Attitude / scale | Expected lines |
|---|---|---|
| Demand their unworn rare item | 0, Order | Rarity −14.4, Prospects `+5% (−0.7)`, total −15.1 |
| Demand their worn rare item | 300, Order | Rarity −14.4, Belongs −4.3, Prospects `−25% (4.7)`, total −14.0 |
| Demand their worn rare item | −120, Skaven | Rarity −14.4, Belongs −4.3, Prospects `+10% (−1.9)`, total −20.6 |
| Demand their common item | −300, Order | Rarity −2.5, Prospects `+100% (−2.5)`, total −5.0 |
| Offer our rare, demand 14 400 gold | −200, any | Rarity +14.4, Economic −14.4, total 0.0 (no ×3 any more) |
| Destruction partner, nothing demanded | 350 | Prospects `−12.5% (0.0)` |
| Second deal with the same faction this turn | — | Deals frequency −5.0 |

- [ ] **Step 2: Update the 1.1.0 line in 00_START_HERE.md** (rebalance built, awaiting test; MCT window after it).
