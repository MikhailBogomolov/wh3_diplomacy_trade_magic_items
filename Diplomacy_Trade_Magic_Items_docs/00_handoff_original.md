# Trade Magic Items Diplomacy Mod — Project Handoff

> Continuation context for another AI / developer.
>
> Game: **Total War: WARHAMMER III**
>
> Goal: add trading of equipment / magic items through diplomacy, eventually with AI in-game bots valuation and multiplayer-safe transaction handling.

## 1. Current Goal

Target flow:

1. Open diplomacy with another faction.
2. Enter negotiation screen.
3. A new square diplomacy action appears next to the normal actions.
4. Clicking it opens a custom panel based on the vanilla **Trade Settlement** panel.
5. The panel will later show the player's and target faction's available magic items.
6. Selected items should eventually become offer/demand terms in the diplomacy deal.
7. Later: transaction logic, AI valuation/counteroffers, multiplayer-safe synchronization.

For now, the focus is the UI shell and interaction flow.

## 2. Current Naming

The naming was changed recently. Use these names from now on:

```text
trade_magic_items
diplomatic_option_trade_magic_items
```

Runtime action button ID:

```text
diplomatic_option_trade_magic_items
```

Custom subpanel runtime ID:

```text
trade_magic_items
```

Custom panel layout:

```text
ui/campaign ui/diplomacy_hud_trade_magic_items.twui.xml
```

Custom action button layout:

```text
ui/campaign ui/diplomatic_option_trade_magic_items.twui.xml
```

Custom icon:

```text
ui/campaign ui/diplomacy_icons/diplomatic_option_trade_magic_items.png
```

Lua:

```text
script/campaign/mod/artifact_diplomacy_trading.lua
```

Pack:

```text
artifact_diplomacy_trading.pack
```

The pack/project still uses the older `artifact_diplomacy_trading` name. That is fine for now.

## 3. Tooling

Used:

- RPFM 5.2.0
- VS Code
- WH3 campaign Lua logging
- Context Viewer

Assembly Kit is not required for the current work.

Lua logging works with `out(...)`.

## 4. Current Pack Structure

Approximate structure:

```text
artifact_diplomacy_trading.pack
├── db
│   ├── diplomacy_strings_tables
│   │   └── artifact_diplomacy_trading
│   └── diplomatic_actions_tables
│       └── artifact_diplomacy_trading
├── script
│   └── campaign
│       └── mod
│           └── artifact_diplomacy_trading.lua
├── text
│   └── db
│       └── artifact_diplomacy_trading.loc
└── ui
    └── campaign ui
        ├── diplomatic_option_trade_magic_items.twui.xml
        ├── diplomacy_hud_trade_magic_items.twui.xml
        └── diplomacy_icons
            └── diplomatic_option_trade_magic_items.png
```

Important localization discovery:

```text
text/db/*.loc
```

is the correct path for custom `.loc` files.

When the `.loc` file was placed in the root of the pack, `common.get_localised_string(...)` returned an empty string. After moving it to `text/db/`, localization started working.

## 5. DB / Pack Behavior

For DB tables, a mod does not need to duplicate the vanilla internal filename.

Important path:

```text
db/<table_name>/<custom_file_name>
```

Example:

```text
db/diplomatic_actions_tables/artifact_diplomacy_trading
db/diplomacy_strings_tables/artifact_diplomacy_trading
```

The game merges rows from files belonging to the same logical DB table at runtime.

Localization is separate. `.loc` files live under:

```text
text/db/*.loc
```

Translation packs can use the same localization keys with different values and override the base mod's text depending on load order.

## 6. Localization

Current localization keys:

```text
diplomacy_strings_string_diplomatic_option_trade_magic_items
diplomacy_strings_string_diplomatic_option_trade_magic_items_tooltip
```

Typical English values:

```text
Trade Magic Items
Allows trading magic items for various benefits
```

Runtime lookup:

```lua
local title_text = common.get_localised_string(
    "diplomacy_strings_string_diplomatic_option_trade_magic_items"
)

local body_text = common.get_localised_string(
    "diplomacy_strings_string_diplomatic_option_trade_magic_items_tooltip"
)
```

Tooltip formatting:

```text
Title||Body
```

Working code:

```lua
button:SetTooltipText(
    title_text .. "||" .. body_text,
    body_key,
    true
)
```

## 7. Vanilla Diplomacy UI

Main diplomacy panel:

```text
diplomacy_dropdown
```

Important negotiation-screen containers:

```text
diplomacy_dropdown
├── offers_panel
└── subpanel_group
```

Action button list:

```text
list_possible_actions
```

Known action IDs:

```text
diplomatic_option_payment
diplomatic_option_trade_regions
...
```

Custom action:

```text
diplomatic_option_trade_magic_items
```

`list_possible_actions` uses `HorizontalList`.

Observed layout:

```text
spacing = -4,0
size-to-content = true
margins = 10,10
padding = 40
```

## 8. Custom Diplomacy Button — Working

The custom square action button is fully working.

Proven:

- `CreateComponent(...)` works for the standalone button.
- Button renders correctly.
- Hover/pressed states work.
- Custom icon works.
- Tooltip works.
- Click listener works.
- Button can be reordered immediately after `diplomatic_option_payment`.

Creation:

```lua
local button_address = action_list:CreateComponent(
    "diplomatic_option_trade_magic_items",
    "ui/campaign ui/diplomatic_option_trade_magic_items.twui.xml"
)
```

Then:

```lua
local button = UIComponent(button_address)
button:SetVisible(true)
```

Click listener:

```lua
core:add_listener(
    "AD_TradeMagicItemsClicked",
    "ComponentLClickUp",
    function(context)
        return context.string == "diplomatic_option_trade_magic_items"
    end,
    function()
        ad_log("TRADE MAGIC ITEMS BUTTON CLICKED")
    end,
    true
)
```

This is our stable entry point into custom diplomacy logic.

## 9. Standalone TWUI Lessons

Earlier attempts tried to transplant vanilla template inheritance directly.

Using these inside a standalone TWUI created via `CreateComponent` caused crashes/hangs:

```xml
part_of_template="true"
uniqueguid_in_template="..."
```

The working button instead uses a fully self-contained definition based on the vanilla button visuals/states.

Do not reintroduce template inheritance into the standalone action button without a specific reason.

## 10. Button Ordering

New children are appended to `list_possible_actions`.

The custom button is successfully moved after payment with:

```lua
action_list:Adopt(
    button:Address(),
    insertion_index
)
```

There is no convenient public `GetIndex()` on the child, so the payment index is found by iterating the parent's children and comparing addresses.

## 11. Known Button Rebuild Bug — Deferred

The native diplomacy UI rebuilds `list_possible_actions` after some actions, e.g. adding treaties or payments.

When that happens, the custom button is destroyed and disappears until re-entering the diplomacy target.

Known but intentionally deferred.

Possible future fix:
- create `ensure_magic_items_button()`;
- watch diplomacy UI rebuilds;
- recreate the button if missing.

Do not focus on this bug right now.

## 12. Vanilla Trade Settlement Panel — Donor

Donor:

```text
diplomacy_hud_trade_regions.twui.xml
```

Hierarchy:

```text
diplomacy_hud_trade_regions
├── offer_demand_parent
│   └── list_offers
│       ├── list_clip
│       │   └── list_box
│       │       └── template_region_list_item
│       │           └── checkbox
│       ├── offers_title
│       └── vslider
├── small_bar
├── title_plaque
│   └── tx_trade_region
├── both_buttongroup
│   ├── ok_trade_regions
│   └── cancel_trade_regions
└── label_trade_region_rules
```

Important vanilla behavior:

The XML physically contains only one list, `list_offers`.

Its comment says it gets duplicated in code to create the demands side.

`offers_title` has two states:

```text
offers
demands
```

with vanilla texts:

```text
Your Settlements
Their Settlements
```

## 13. Vanilla Native Callback

The vanilla trade-regions root contains:

```xml
<callbackwithcontextlist>
    <callback_with_context callback_id="DiplomacyTradeRegionsPanel"/>
</callbackwithcontextlist>
```

This was removed from the custom panel.

Reason:
- it is clearly tied to region-trading native behavior;
- it likely assumes region-specific native state;
- reusing it for magic items could be unsafe.

`lib_campaign_ui.lua` was inspected and does not expose the implementation of `DiplomacyTradeRegionsPanel`.

Current conclusion:

> Some diplomacy UI behavior is implemented in internal/native game code, not in accessible Lua dependencies.

## 14. What “Native UI Code” Means Here

There are at least two relevant layers:

1. Lua/script layer:
   - `ComponentLClickUp`
   - `PanelOpenedCampaign`
   - `UIComponent`
   - `SetVisible`
   - `SetState`
   - `CreateComponent`
   - script listeners

2. Internal/native UI layer:
   - TWUI `callback_id`
   - diplomacy controllers
   - internal UI state transitions not exposed as Lua source

A TWUI callback ID does not necessarily map to a Lua function with the same name.

## 15. Custom Trade Magic Items Panel — Current State

New panel:

```text
ui/campaign ui/diplomacy_hud_trade_magic_items.twui.xml
```

It is heavily based on the vanilla trade-regions panel.

Renamed components include:

```text
trade_magic_items
diplomacy_hud_trade_magic_items
ok_trade_magic_items
cancel_trade_magic_items
tx_trade_magic_items
label_trade_magic_items_rules
template_magic_item_list_item
```

Temporary visible text:

```text
Trade Magic Items
Your Magic Items
Their Magic Items
Select magic items to offer or demand.
```

The panel visually renders correctly.

The current screenshot showed:
- correct large panel frame;
- title `Trade Magic Items`;
- two columns;
- headings `Your Magic Items` and `Their Magic Items`;
- OK and Cancel buttons;
- placeholder item row in each list;
- layout closely matching vanilla Trade Settlement.

## 16. Two-Column Runtime Setup

The custom panel follows the vanilla pattern and creates the second list at runtime.

Concept:

```lua
local demands_address = list_offers:CopyComponent(
    "list_demands"
)

local list_demands = UIComponent(demands_address)
list_demands:SetVisible(true)

local demands_title = find_uicomponent(
    list_demands,
    "offers_title"
)

if demands_title then
    demands_title:SetState("demands")
end
```

This worked.

The panel displayed both columns correctly.

## 17. Current Opening Problem

The panel is successfully created, but the surrounding diplomacy UI does not switch the way vanilla does.

Observed successful log sequence:

```text
TRADE MAGIC ITEMS BUTTON CLICKED
Creating trade magic items panel
Magic items panel two-column layout prepared
Trade magic items panel created successfully
```

Therefore:
- `CreateComponent` succeeds;
- panel is real;
- list duplication succeeds;
- TWUI is valid.

The missing piece is the vanilla subpanel visibility/state transition.

## 18. Vanilla Subpanel Hierarchy

From Context Viewer:

```text
diplomacy_dropdown
└── subpanel_group
    ├── panel_smoke_t
    ├── war_declared
    ├── end_trade
    ├── payments
    ├── request_join_war
    └── trade_regions
        └── diplomacy_hud_trade_regions
```

Vanilla Trade Settlement opens inside:

```text
subpanel_group > trade_regions
```

The normal diplomacy action/offer UI is mainly under:

```text
offers_panel
```

User observation:

- vanilla hides the normal negotiation/action panel;
- shows the relevant subpanel;
- restores the normal panel on Cancel.

Exact transitions still need to be captured.

## 19. Current Freeze / Hang Behavior

There are two current hard-freeze cases.

### A. Clicking custom magic-items button a second time

First click:
- panel is created successfully;
- normal diplomacy UI is not switched away.

Second click:
- game freezes hard.

Likely cause:
- code enters the branch for an already-existing panel;
- panel setup/show logic is being repeated while the parent UI is in an inconsistent state.

For now:

> Create/setup the panel once. Reuse it by only changing visibility later.

### B. Clicking custom Cancel

User reports hard freeze on custom Cancel as well.

Current log did not capture that freeze.

Most likely cause:

> Close logic does not mimic the native diplomacy subpanel transition correctly.

This is the current main blocker.

## 20. Current Hypothesis for Vanilla Open/Close

Not yet proven.

Likely opening:

```text
offers_panel      true -> false
subpanel_group    false/partial -> true
trade_regions     false -> true
```

Possibly also:
- other sibling subpanels hidden;
- smoke overlay toggled;
- state changes;
- input capture / priorities adjusted.

Likely Cancel:

```text
trade_regions     true -> false
offers_panel      false -> true
```

Do not treat this as final until observed.

## 21. Best Next Diagnostic Step

Use Context Viewer and compare vanilla Trade Settlement in three states.

### State A — normal diplomacy negotiation

Inspect:

```text
offers_panel
subpanel_group
trade_regions
diplomacy_hud_trade_regions
list_possible_actions
```

Record:

```text
Visible
State
Parent
Position
```

### State B — after clicking vanilla Trade Settlement

Record the same fields.

### State C — after pressing vanilla Cancel

Record the same fields again.

Goal:

> Determine the exact UI-state diff and reproduce it for `trade_magic_items`.

This is currently more valuable than guessing.

## 22. Useful Runtime State Logger

Potential targets:

```text
diplomacy_dropdown
offers_panel
subpanel_group
trade_regions
diplomacy_hud_trade_regions
```

Potential properties:

```text
Visible()
CurrentState()
Address()
Parent()
```

Treat the native callback as a black box:

```text
before state
    ↓
click vanilla trade regions
    ↓
after state
```

Then mimic it for `trade_magic_items`.

## 23. Current Lua Architecture

Current flow:

```text
Diplomacy target confirmed
        ↓
create custom action button
        ↓
move button after payment
        ↓
apply localization/tooltip
        ↓
click magic-items button
        ↓
create/show trade_magic_items panel
        ↓
setup two columns
        ↓
later: populate real items
```

`button_ok` after faction selection is still used as the working trigger to create the action button:

```lua
core:add_listener(
    "AD_DiplomacyNegotiationStarted",
    "ComponentLClickUp",
    function(context)
        return context.string == "button_ok"
    end,
    function()
        cm:callback(
            function()
                ad_create_trade_magic_items_button()
            end,
            0.1
        )
    end,
    true
)
```

This is working, but may later be replaced with a cleaner diplomacy-state trigger.

## 24. Proven Runtime Facts

Do not re-investigate these unless necessary.

### Proven: standalone custom action button works

```lua
action_list:CreateComponent(
    "diplomatic_option_trade_magic_items",
    "ui/campaign ui/diplomatic_option_trade_magic_items.twui.xml"
)
```

### Proven: click listener works

```text
ComponentLClickUp
context.string == diplomatic_option_trade_magic_items
```

### Proven: localized tooltip works

Using:

```lua
common.get_localised_string(...)
button:SetTooltipText(...)
```

### Proven: button can be moved after payment

Using parent iteration +:

```lua
Adopt(button_address, payment_index + 1)
```

### Proven: custom Trade Magic Items panel can be created

The large custom panel renders correctly.

### Proven: list duplication works

```lua
list_offers:CopyComponent("list_demands")
```

### Proven: copied title can switch to demand state

```lua
demands_title:SetState("demands")
```

## 25. Risky / Incorrect Approaches

Avoid for now:

### Re-running panel setup repeatedly

Do not duplicate `list_offers` every time the action button is clicked.

Create once, then reuse.

### Assuming visible child is enough

The diplomacy parent UI uses native subpanel state management.

The custom panel must mimic that transition.

### Reusing vanilla region callback

Avoid:

```xml
callback_id="DiplomacyTradeRegionsPanel"
```

for the custom panel.

### Blindly reusing region-specific row properties

Vanilla region rows contain things like:

```text
Notify
Region
```

These are irrelevant to magic items.

## 26. Reusable Vanilla Components

Good visual donors:

```text
title_plaque
small_bar
both_buttongroup
offer_demand_parent
list_offers
list_clip
list_box
offers_title
vslider
```

Round OK / Cancel visuals also work.

## 27. Future Item Row Design

Eventually each row may contain:

```text
[item icon] [item name] [rarity/type] [checkbox]
```

Potential state structure:

```lua
{
    ancillary_key = "...",
    owner_faction = "...",
    selected = false
}
```

Current placeholder text is only for UI testing.

## 28. Magic Items Technical Model

WH3 equipment and followers are generally represented through ancillaries.

Priority:

1. magic items / equipment;
2. followers later.

Followers are deferred because they have more compatibility restrictions.

## 29. Future Multiplayer Transaction Architecture

Important rule:

> UI click should not directly mutate campaign model state.

Preferred future flow:

```text
UI selection
    ↓
local pending trade state
    ↓
CampaignUI.TriggerCampaignScriptEvent(...)
    ↓
UITrigger / synchronized campaign-side handler
    ↓
remove item from giver
    ↓
grant item to receiver
```

Exact ancillary transfer API still needs research.

## 30. Future Pending Trade Model

Initial concept:

```lua
pending_trade = {
    offered_item = nil,
    demanded_item = nil
}
```

Can later become arrays for multi-item deals.

## 31. Future AI Valuation

Not implemented.

Possible factors:

```text
base item value
rarity
stat usefulness
faction fit
character need
equipment slot need
duplicate penalty
scarcity
relations modifier
economy / treasury
strategic context
```

AI work should wait until UI + transaction + multiplayer sync are stable.

## 32. Open Questions

1. Exact vanilla visibility/state transition when opening `trade_regions`.
2. Exact transition on `cancel_trade_regions`.
3. Whether smoke/overlay/sibling subpanels also need toggling.
4. Safe way to reopen already-created custom panel.
5. Reliable way to identify selected diplomacy target faction.
6. How to enumerate faction magic items / ancillaries.
7. How to transfer items between factions.
8. Whether faction-level inventory exists independently of character assignment.
9. How to represent the selected item as an actual diplomacy term.
10. Multiplayer synchronization strategy.
11. AI valuation.
12. Whether any native diplomacy extension point exists for custom terms.

## 33. Immediate Next Step

Do not work on:
- inventories;
- disappearing-button rebuild bug;
- AI.

Immediate task:

> Reproduce the vanilla Trade Settlement open/close transition for `trade_magic_items`.

Recommended process:

1. Capture Context Viewer state in normal negotiation.
2. Click vanilla `diplomatic_option_trade_regions`.
3. Capture state again.
4. Press vanilla Cancel.
5. Capture state again.
6. Diff visibility/state/parent/overlay changes.
7. Apply the same changes to `trade_magic_items`.
8. Only after open/close is stable, populate real item lists.

## 34. Useful Vanilla Files

Already examined / useful:

```text
ui/campaign ui/diplomacy_hud_offers_panel.twui.xml
ui/campaign ui/diplomacy_hud_trade_regions.twui.xml
ui/campaign ui/diplomacy_hud_payments.twui.xml
script/_lib/lib_campaign_ui.lua
script/_lib/lib_campaign_manager.lua
```

Most important current donor:

```text
diplomacy_hud_trade_regions.twui.xml
```

## 35. Current Status

### Completed

- custom diplomacy action button exists;
- button visual works;
- icon works;
- tooltip works;
- localization works;
- click is captured;
- button is moved after payment;
- custom `Trade Magic Items` panel exists;
- panel visually matches vanilla Trade Settlement;
- two-column duplication works;
- new naming is active.

### Partially completed

- opening the custom panel;
- closing the custom panel.

The panel itself is valid and created correctly. The blocker is the surrounding diplomacy UI transition.

### Deferred

- action-list rebuild bug;
- target faction retrieval;
- real inventory data;
- item row rendering;
- item selection;
- deal integration;
- transfer logic;
- multiplayer sync;
- AI valuation.

## 36. Short TL;DR

We are building a WH3 diplomacy mod for trading magic items.

Current custom action:

```text
diplomatic_option_trade_magic_items
```

Current custom panel:

```text
trade_magic_items
```

The square diplomacy button is fully working and appears immediately after payment.

The large custom Trade Magic Items panel is also successfully created by cloning the vanilla Trade Settlement panel. It renders correctly with two columns and OK/Cancel.

Current blocker:

> Reproduce the native diplomacy UI transition between the normal `offers_panel` and the `trade_regions`-style subpanel.

The vanilla `DiplomacyTradeRegionsPanel` callback appears to be native/internal rather than accessible Lua.

Next task:

> Observe exact UI visibility/state changes before/after vanilla Trade Settlement open/Cancel, then mimic them for `trade_magic_items`.
