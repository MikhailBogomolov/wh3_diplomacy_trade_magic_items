# Plan B, step 1: our Trade Magic Items panel becomes a standalone, bigger
# window (it used to sit on the native subpanel_group background).
#   - own background: the 4 images of diplomacy_hud's subpanel_group
#     (panel_back_tile, panel_back_border, panel_back_top, parchment_texture)
#   - 760x425 (was 760x365): room for 4 items per column
#   - columns 60 px taller (list_offers 230 -> 290, list_clip / list_box
#     181 -> 241, offer_demand_parent 230 -> 290)
#   - a copy of the faction panel's resize handle (button_enlarge_br,
#     generic callback ResizeDragHandle) as a child of the panel
#   - our treasury (dy_treasury + treasury_icon) top left, the partner's
#     (dy_treasury_partner + treasury_icon_partner) top right, and the deal chance
#     (label_deal_success_chance) right of the buttons, copied from the
#     native offers panel
# Input: the backup taken before Plan B (so the script can be re-run).

$ErrorActionPreference = "Stop"

$backupPath = "D:\Games\Modding\Diplomacy_Trade_Magic_Items_Mod\Diplomacy_Trade_Magic_Items_docs\backups\diplomacy_hud_trade_magic_items.before_plan_b.twui.xml"
$donorPath = "D:\Games\Modding\Diplomacy_Trade_Magic_Items_Mod\Vanilla_files\ui\campaign ui\diplomacy_hud.twui.xml"
$outPath = "D:\Games\Modding\Diplomacy_Trade_Magic_Items_Mod\Diplomacy_Trade_Magic_Items_packfile\ui\campaign ui\diplomacy_hud_trade_magic_items.twui.xml"

# user (0.5.1 test): width as before (850 left black gaps); user (0.5.3):
# default = smallest size = 4 visible items. A row is 50 + 10 spacing,
# the list starts 8 down: row 4 ends at 8 + 4 * 50 + 3 * 10 = 238, row 5
# starts at 248 (0.5.4 with 251 showed its top edge) -> list_clip 241
# (181 + 60)
$width = 760
$height = 425
$extraHeight = $height - 365

$text = [System.IO.File]::ReadAllText($backupPath) -replace "`r`n", "`n"
$donor = [System.IO.File]::ReadAllText($donorPath) -replace "`r`n", "`n"

function Get-Block([string]$source, [string]$tag) {
    $m = [regex]::Match($source, "(?s)\t\t<$tag\n\t\t\tthis=`"[^`"]+`"\n\t\t\tid=`"$tag`".*?\n\t\t</$tag>")
    if (-not $m.Success) { throw "block not found: $tag" }
    return $m.Value
}

function Set-Block([string]$tag, [string]$newBlock) {
    $old = Get-Block $script:text $tag
    $script:text = $script:text.Replace($old, $newBlock)
}

# exact replacement that must hit exactly $count times inside one block
function Edit-Block([string]$tag, [string]$from, [string]$to, [int]$count) {
    $block = Get-Block $script:text $tag
    $hits = ([regex]::Matches($block, [regex]::Escape($from))).Count
    if ($hits -ne $count) { throw "$tag : expected $count x [$from], found $hits" }
    Set-Block $tag ($block.Replace($from, $to))
}

# --- background + size of the panel itself ---
$panel = Get-Block $text "trade_magic_items"
$stateGuid = [regex]::Match($panel, 'currentstate="([^"]+)"').Groups[1].Value
$parchmentWidth = $width - 21
$parchmentHeight = $height - 104
$newStates = @"
			<componentimages>
				<component_image
					this="11111111-AAAA-4AAA-8AAA111111111111"
					uniqueguid="11111111-AAAA-4AAA-8AAA111111111111"
					imagepath="ui/skins/default/panel_back_tile.png"/>
				<component_image
					this="22222222-AAAA-4AAA-8AAA222222222222"
					uniqueguid="22222222-AAAA-4AAA-8AAA222222222222"
					imagepath="ui/skins/default/panel_back_border.png"/>
				<component_image
					this="33333333-AAAA-4AAA-8AAA333333333333"
					uniqueguid="33333333-AAAA-4AAA-8AAA333333333333"
					imagepath="ui/skins/default/panel_back_top.png"/>
				<component_image
					this="44444444-AAAA-4AAA-8AAA444444444444"
					uniqueguid="44444444-AAAA-4AAA-8AAA444444444444"
					imagepath="ui/skins/default/parchment_texture.png"/>
			</componentimages>
			<states>
				<newstate
					this="$stateGuid"
					name="NewState"
					width="$width"
					height="$height"
					interactive="true"
					uniqueguid="$stateGuid">
					<imagemetrics>
						<image
							this="55555555-AAAA-4AAA-8AAA555555555555"
							uniqueguid="55555555-AAAA-4AAA-8AAA555555555555"
							componentimage="11111111-AAAA-4AAA-8AAA111111111111"
							width="$width"
							height="$height"
							tile="true"
							dockpoint="Center"
							margin="5.00,5.00,5.00,5.00"/>
						<image
							this="66666666-AAAA-4AAA-8AAA666666666666"
							uniqueguid="66666666-AAAA-4AAA-8AAA666666666666"
							componentimage="22222222-AAAA-4AAA-8AAA222222222222"
							width="$width"
							height="$height"
							tile="true"
							margin="30.00,30.00,30.00,30.00"/>
						<image
							this="77777777-AAAA-4AAA-8AAA777777777777"
							uniqueguid="77777777-AAAA-4AAA-8AAA777777777777"
							componentimage="33333333-AAAA-4AAA-8AAA333333333333"
							width="$width"
							height="55"
							tile="true"
							margin="30.00,40.00,30.00,40.00"/>
						<image
							this="88888888-AAAA-4AAA-8AAA888888888888"
							uniqueguid="88888888-AAAA-4AAA-8AAA888888888888"
							componentimage="44444444-AAAA-4AAA-8AAA444444444444"
							offset="10.00,49.00"
							width="$parchmentWidth"
							height="$parchmentHeight"
							tile="true"
							dockpoint="Center"
							dock_offset="0.00,-3.00"
							margin="50.00,50.00,50.00,50.00"/>
					</imagemetrics>
				</newstate>
			</states>
"@ -replace "`r`n", "`n"
# (a here-string drops its last line break; the replaced text had one)
$panel = [regex]::Replace($panel, '(?s)\t\t\t<states>.*?\t\t\t</states>\n', $newStates + "`n")
Set-Block "trade_magic_items" $panel

# --- taller columns ---
$listHeight = 230 + $extraHeight
$clipHeight = 181 + $extraHeight
Edit-Block "offer_demand_parent" 'height="230"' "height=`"$listHeight`"" 1
Edit-Block "list_offers" 'height="230"' "height=`"$listHeight`"" 2
Edit-Block "list_clip" 'height="181"' "height=`"$clipHeight`"" 1
Edit-Block "list_box" 'height="181"' "height=`"$clipHeight`"" 2

# --- hint under the title: between the two treasuries, ~14 gap ---
# centre 381; measured in game: our treasury ends at ~126, the partner's icon starts at ~658
Edit-Block "label_trade_magic_items_rules" 'width="669"' 'width="482"' 1

# --- what the resize handle may change (test 0.5.0: it changed width,
# height and the button plaque) ---
# panel: height only
Edit-Block "trade_magic_items" "id=`"trade_magic_items`"`n" "id=`"trade_magic_items`"`n`t`t`tallowhorizontalresize=`"false`"`n" 1
# button plaque: fixed size, stays docked to the bottom
Edit-Block "both_buttongroup" "id=`"both_buttongroup`"`n" "id=`"both_buttongroup`"`n`t`t`tallowhorizontalresize=`"false`"`n`t`t`tallowverticalresize=`"false`"`n" 1

# --- resize handle from the faction panel ---
$handle = Get-Block $donor "button_enlarge_br"

# never smaller than the default size (4 items; faction panel: 0.7)
$minScale = "name=`"min_scale`"`n`t`t`t`t`tvalue=`"0.7`""
if ($handle.IndexOf($minScale) -lt 0) { throw "min_scale 0.7 not found in the handle" }
$handle = $handle.Replace($minScale, "name=`"min_scale`"`n`t`t`t`t`tvalue=`"1.0`"")

# tallest size: 788, the height the user found right in 0.5.4 (log
# script_log_281026_2136) -> 788 / 425 (faction panel: 2.0)
$maxScale = "name=`"max_scale`"`n`t`t`t`t`tvalue=`"2.0`""
if ($handle.IndexOf($maxScale) -lt 0) { throw "max_scale 2.0 not found in the handle" }
$handle = $handle.Replace($maxScale, "name=`"max_scale`"`n`t`t`t`t`tvalue=`"1.854`"")
$handleGuid = [regex]::Match($handle, 'this="([^"]+)"').Groups[1].Value
$text = $text.Replace("`t</components>", $handle + "`n`t</components>")

# --- item lists: the List callback rebuilds its rows, in sort order ---
# dont_recreate kept the old rows and put new items at the bottom
# (user, 0.9.1: items received in a trade were not sorted in)
$recreate = [regex]::Matches($text, '\t+<property\n\t+name="dont_recreate"\n\t+value=""/>\n')
if ($recreate.Count -lt 1) { throw "dont_recreate not found" }
foreach ($m in $recreate) { $text = $text.Replace($m.Value, "") }

# character runes need the dwarfs' own rune slot, nobody else can wear them
# (user, 0.9.8). Items for certain character types only are out too: no
# other race could use them (user, 2026-10-31; same-race trading later,
# docs 05). Same exclusions in build_diplomacy_tradeable_mirrors.js
$filterAnchor = 'AncillaryRecordContext.Transferrable == true'
if ($text.IndexOf($filterAnchor) -lt 0) { throw "item list filter not found" }
$text = $text.Replace($filterAnchor, $filterAnchor + ' &amp;&amp; AncillaryRecordContext.SubcategoryContext.Subcategory != &quot;character_rune&quot; &amp;&amp; AncillaryRecordContext.IncludedAgentSubtypesList.Size == 0')

# --- treasury and deal chance from the native offers panel ---
# dy_treasury fills itself (ContextTextLabel PlayersFaction.TreasuryAmount),
# treasury_icon is its icon, label_deal_success_chance (states negative /
# positive, no callbacks) is filled by our Lua.
$offersPath = "D:\Games\Modding\Diplomacy_Trade_Magic_Items_Mod\Vanilla_files\ui\campaign ui\diplomacy_hud_offers_panel.twui.xml"
$offers = [System.IO.File]::ReadAllText($offersPath) -replace "`r`n", "`n"

function Set-Placement([string]$block, [string]$docking, [string]$dockOffset, [string]$anchor) {
    $block = [regex]::Replace($block, '\t\t\tdocking="[^"]*"\n', '')
    $block = [regex]::Replace($block, '\t\t\tdock_offset="[^"]*"\n', '')
    $block = [regex]::Replace($block, '\t\t\tcomponent_anchor_point="[^"]*"\n', '')
    $placement = "`t`t`tdocking=`"$docking`"`n`t`t`tdock_offset=`"$dockOffset`"`n`t`t`tcomponent_anchor_point=`"$anchor`"`n"
    return [regex]::Replace($block, '(\t\t\tid="[^"]+"\n)', "`$1$placement", 1)
}

# a second copy of a block: own id, own GUIDs
function Copy-WithNewId([string]$block, [string]$oldId, [string]$newId) {
    $copy = $block.Replace("<$oldId`n", "<$newId`n").Replace("id=`"$oldId`"", "id=`"$newId`"").Replace("</$oldId>", "</$newId>")
    # references into a template file must stay
    $templateRefs = [regex]::Matches($copy, 'uniqueguid_in_template="([^"]+)"') | ForEach-Object { $_.Groups[1].Value }
    $guids = [regex]::Matches($copy, '\b[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{16}\b') | ForEach-Object { $_.Value } | Select-Object -Unique | Where-Object { $templateRefs -notcontains $_ }
    foreach ($old in $guids) {
        $g = [guid]::NewGuid().ToString().ToUpper()
        $copy = $copy.Replace($old, $g.Substring(0, 23) + $g.Substring(24))
    }
    return $copy
}

# the button that closes the "they accepted" view: the tick OK button,
# in the middle of the plaque; shown by Lua in place of OK and Cancel
$confirm = Copy-WithNewId (Get-Block $text "ok_trade_magic_items") "ok_trade_magic_items" "confirm_trade_magic_items"
if ($confirm.IndexOf('offset="-30.00,-5.00"') -lt 0) { throw "OK offset not found" }
$confirm = $confirm.Replace('offset="-30.00,-5.00"', 'offset="0.00,-5.00"')

# OK ends the deal: the hand-and-scroll icon and the tooltip of the native
# Propose offer button (button_send, user 2026-10-31)
Edit-Block "ok_trade_magic_items" "ui/skins/default/icon_check.png" "ui/skins/default/icon_initiate_diplomacy.png" 2
$okTooltip = "`t`t`t`t<localised_text`n`t`t`t`t`ttooltip_label=`"ComponentTooltip_5618a997`"`n`t`t`t`t`ttooltip_text=`"Propose offer||Propose the above deal. You can only propose an offer if the recipient has a positive opinion about it.`"/>`n"
Edit-Block "ok_trade_magic_items" "`t`t`t`t<localised_text/>`n" $okTooltip 1

# human partner: Counteroffer between Propose and Cancel, a copy of OK with
# the icon and tooltip of the native button_counter_offer. Lua shows it and
# places the buttons, the plaque grows to the right only (0.11.0)
$counter = Copy-WithNewId (Get-Block $text "ok_trade_magic_items") "ok_trade_magic_items" "counter_trade_magic_items"
if ($counter.IndexOf('offset="-30.00,-5.00"') -lt 0) { throw "OK offset not found in the counteroffer copy" }
$counter = $counter.Replace('offset="-30.00,-5.00"', 'offset="0.00,-5.00"')
if (([regex]::Matches($counter, "icon_initiate_diplomacy.png")).Count -ne 2) { throw "OK icon not found in the counteroffer copy" }
$counter = $counter.Replace("ui/skins/default/icon_initiate_diplomacy.png", "ui/skins/default/icon_counter_offer.png")
$counter = $counter.Replace('tooltip_label="ComponentTooltip_5618a997"', 'tooltip_label="ComponentTooltip_d3a2bdae"')
$counter = [regex]::Replace($counter, 'tooltip_text="Propose offer\|\|[^"]*"', 'tooltip_text="Counteroffer||Discard the proposed deal and construct a new one."')
if ($counter.IndexOf('Counteroffer||') -lt 0) { throw "counteroffer tooltip not set" }

# ours top left, right of the resize handle (21 wide at 12,12); the icon
# sits outside the label on its left, so the label starts further right
$treasury = Set-Placement (Get-Block $offers "dy_treasury") "Top Left" "56.00,14.00" "0.00,0.00"
$treasuryIcon = Get-Block $offers "treasury_icon"

# the partner's top right, text and tooltip (trade_magic_items_their_treasury) set by
# Lua: the ContextTextLabel callback showed 0 after switching partner
# (0.8.1, user screenshot) while Lua read the right number
$partnerTreasury = Set-Placement (Copy-WithNewId (Get-Block $offers "dy_treasury") "dy_treasury" "dy_treasury_partner") "Top Right" "-6.00,14.00" "1.00,0.00"
if ($partnerTreasury.IndexOf('callback_id="ContextTextLabel"') -lt 0) { throw "treasury label callback not found" }
$partnerTreasury = [regex]::Replace($partnerTreasury, '(?s)\t\t\t<callbackwithcontextlist>.*?</callbackwithcontextlist>\n', '')
$partnerTreasury = [regex]::Replace($partnerTreasury, '\t\t\tcomponentleveltooltip="[^"]*"\n\t\t\ttooltiplabel="[^"]*"\n', '')
if ($partnerTreasury.IndexOf("componentleveltooltip") -ge 0) { throw "treasury tooltip not removed" }
$partnerTreasuryIcon = Copy-WithNewId $treasuryIcon "treasury_icon" "treasury_icon_partner"

# bottom bar, middle of the bronze part right of the OK / Cancel buttons
# (user, 0.6.2: much further right, a bit lower; 0.6.3: a little left)
$chance = Set-Placement (Get-Block $offers "label_deal_success_chance") "Bottom Center" "218.00,-10.00" "0.00,1.00"

# human partner: "Waiting on player..." from the native offers panel,
# hidden by default. User (0.11.0): in the middle of the bronze bar right of
# the plaque. x = 140 showed the label centred there, over Cancel, whatever
# the anchor says (0.11.1 log: left edge 932 at x 248, width 232, window
# centre 800). User: x 248 too far right, x 236 too far left
$waiting = Set-Placement (Copy-WithNewId (Get-Block $offers "label_waiting_on_response") "label_waiting_on_response" "trade_magic_items_waiting") "Bottom Center" "242.00,-6.00" "0.00,1.00"

# balance button between the OK / Cancel plaque and the chance. The round
# button is the block of template round_medium_button itself (what the
# native button_makeitwork instantiates), written out as a plain
# component: only then the sizes below apply, templates ignore the
# instance size (0.6.3 radios). 0.8.3 used button_ok: square, white glow.
$balanceSize = 46
$roundPath = "D:\Games\Modding\Diplomacy_Trade_Magic_Items_Mod\Vanilla_files\ui\templates\round_medium_button.twui.xml"
$round = [System.IO.File]::ReadAllText($roundPath) -replace "`r`n", "`n"
$balance = Copy-WithNewId (Get-Block $round "round_medium_button") "round_medium_button" "trade_magic_items_balance_button"
$balance = [regex]::Replace($balance, '\t\t\tuniqueguid_in_template="[^"]*"\n', '')
if ($balance.IndexOf("ui/skins/default/icon_medium_tactical_map.png") -lt 0) { throw "template icon not found" }
$balance = $balance.Replace("ui/skins/default/icon_medium_tactical_map.png", "ui/skins/default/icon_makeitwork.png")
# everything scales from the template's 56: the hover glow is smaller
# than the button (42, offset 7,7) and slid off when set to the full size
$balanceScale = $balanceSize / 56
$balance = [regex]::Replace($balance, '(?m)^(\t\t\t\t\t(?:\t\t)?(?:width|height)=")(\d+)"', {
    param($m)
    return $m.Groups[1].Value + [string][math]::Round([int]$m.Groups[2].Value * $balanceScale) + '"'
})
$balance = [regex]::Replace($balance, '(?m)^(\t\t\t\t\t\t\t(?:dock_)?offset=")([\d.]+),([\d.]+)"', {
    param($m)
    $x = ([double]$m.Groups[2].Value * $balanceScale).ToString("0.00", [System.Globalization.CultureInfo]::InvariantCulture)
    $y = ([double]$m.Groups[3].Value * $balanceScale).ToString("0.00", [System.Globalization.CultureInfo]::InvariantCulture)
    return $m.Groups[1].Value + "$x,$y`""
})
$balance = Set-Placement $balance "Bottom Center" "122.00,0.00" "0.00,1.00"

# --- gold: give / demand switch + amount, from the native payments panel ---
# Generic callbacks only (ButtonGroup, radio_button template,
# RadioButtonText, NumericalInput, Button); the panel's own
# DiplomacyPaymentPanel callback is not copied. Squeezed onto the bronze
# bar left of the buttons: the switch without its background, short
# labels (texts set by Lua), a narrower amount field.
$paymentsPath = "D:\Games\Modding\Diplomacy_Trade_Magic_Items_Mod\Vanilla_files\ui\campaign ui\diplomacy_hud_payments.twui.xml"
$payments = [System.IO.File]::ReadAllText($paymentsPath) -replace "`r`n", "`n"

# blocks whose id differs from the tag, or whose tag is used twice
function Get-BlockByGuid([string]$source, [string]$tag, [string]$guid) {
    $m = [regex]::Match($source, "(?s)\t\t<$tag\n\t\t\tthis=`"$guid`".*?\n\t\t</$tag>")
    if (-not $m.Success) { throw "block not found: $tag $guid" }
    return $m.Value
}

function Set-StateSize([string]$block, [int]$width, [int]$height) {
    $block = [regex]::Replace($block, '(?m)^(\t\t\t\t\t(\t\t)?)width="\d+"', "`${1}width=`"$width`"")
    return [regex]::Replace($block, '(?m)^(\t\t\t\t\t(\t\t)?)height="\d+"', "`${1}height=`"$height`"")
}

$goldSwitch = Get-BlockByGuid $payments "buttongroup_offer_demand" "94BF432E-0E87-4256-8B077B87917A4EB1"
$goldSwitch = $goldSwitch.Replace('id="ButtonGroup_offer_demand"', 'id="trade_magic_items_gold_direction"')
$goldSwitch = [regex]::Replace($goldSwitch, '(?s)\t\t\t<componentimages>.*?\t\t\t</componentimages>\n', '')
$goldSwitch = [regex]::Replace($goldSwitch, '(?s)\n\t\t\t\t\t<imagemetrics>.*?\t\t\t\t\t</imagemetrics>', '')
# user (0.6.2): centred on the bronze bar, a bit left, smaller radios;
# (0.6.3): smaller still, inside the bar. Radios 18 px (their images are
# shrunk by Lua: the template ignores the instance dimensions), labels
# in body_10; (0.6.5): a bit lower and right, centred like the rest
$goldSwitch = Set-StateSize $goldSwitch 120 40
$goldSwitch = Set-Placement $goldSwitch "Bottom Left" "36.00,-3.00" "0.00,1.00"

$payOffer = Get-BlockByGuid $payments "pay_offer" "11FA26EE-0DA1-477F-AD8AFECDF7373FB3"
$payOffer = $payOffer.Replace('offset="27.00,37.00"', 'offset="1.00,1.00"').Replace('dimensions="26.00,26.00"', 'dimensions="18.00,18.00"')
$payDemand = Get-BlockByGuid $payments "pay_demand" "38811817-811A-41AD-A9C3225C684EBAE3"
$payDemand = $payDemand.Replace('offset="26.00,78.00"', 'offset="1.00,21.00"').Replace('dimensions="26.00,26.00"', 'dimensions="18.00,18.00"')

# 0.9.4: a point bigger than the 10 of 0.6.3 (user). 0.9.6: 116 wide, at
# 104 the game shrank the longer "Demand Payment" to fit (user: smaller
# than "Offer Payment")
function Set-SmallFont([string]$block) {
    $block = $block.Replace('font_m_size="12"', 'font_m_size="11"')
    if ($block.IndexOf('font_m_size="11"') -lt 0) { throw "Set-SmallFont found no font size" }
    return $block
}
$offerLabel = Set-SmallFont (Set-StateSize (Get-BlockByGuid $payments "once_tx" "78945FEA-A629-431A-B6DC46BB4F5904B5") 116 18)
$demandLabel = Set-SmallFont (Set-StateSize (Get-BlockByGuid $payments "repeatedly_tx" "0F75E8E8-4375-4A55-89BE3E036639B61C") 116 18)

# amount: 70 wide, steps of 500 (the cap stops it at the treasury), arrows (40 wide) docked outside on both sides
$goldAmount = Get-BlockByGuid $payments "amount" "2B10C977-D164-4317-AD3696C355211132"
$goldAmount = $goldAmount.Replace('id="amount"', 'id="trade_magic_items_gold_amount"')
$goldAmount = [regex]::Replace($goldAmount, '(?m)^(\t\t\t\t\t(\t\t)?)width="112"', '${1}width="70"')
$goldAmount = $goldAmount.Replace("`t`t`t<userproperties>`n", "`t`t`t<userproperties>`n`t`t`t`t<property`n`t`t`t`t`tname=`"Increment`"`n`t`t`t`t`tvalue=`"500`"/>`n")
# Like the caravan cargo field (cp1_cth_bhashiva_caravans), properties on
# the NumericalInput callback itself:
#   MaxValue: the payer's-treasury expression had no effect (0.6.6) and
#     the field stopped at 100000 (0.6.7, probably the default max).
#     0.6.8: a plain number on the callback and on the component works
#     (proven); the treasury cap stays in "cap" below.
#     Lua keeps user property trade_magic_items_payer ("us" / "them") on the field in
#     step with the give / demand switch
#   value_changed_event (0.6.5 on the component, 0.6.6 on the callback:
#     nothing reached Lua either way)
# ContextCommandEvent "cap": on UiMsg "trade_magic_items_gold_clamp" (Lua, after every
# gold event; 0.6.6: proven to set the field's own value), on the value
# event and on TextInputChanged (typing; seen in the Context Viewer for
# the payments field): value above the cap -> SetValue(cap), then the
# arrow states (0.6.6: SetValue re-activates the arrows after Lua set
# them, so they are set here, after it).
# ContextCommandEvent "reset": UiMsg "trade_magic_items_gold_reset" (Lua, after a
# trade) -> value 0; the arrows are recoloured by the next "cap".
# ContextCommandEvent "balance": UiMsg "trade_magic_items_gold_balance" (Lua, balance
# button) -> value from user property trade_magic_items_balance_value, set by Lua.
# ContextCommandEvent "notify": value event / TextInputChanged ->
# TriggerUIScriptEvent -> Lua event ContextUITriggerEvent "trade_magic_items_gold_changed".
# cap = payer's treasury, but never above $goldFieldMax: a display limit
# only, so the field never has to show more than 6 digits (user,
# 2026-10-29); the arrow greys at whichever comes first
$goldFieldMax = "999999"
# the partner's treasury comes from Lua (user property
# trade_magic_items_partner_treasury): on the second player's client the
# negotiation context may be another faction or none (0.12.0)
$goldTreasury = "GetIfElse(self.GetProperty(&quot;trade_magic_items_payer&quot;) == &quot;them&quot;, ToNumber(self.GetProperty(&quot;trade_magic_items_partner_treasury&quot;)), PlayersFaction.TreasuryAmount)"
$goldMax = "GetIfElse($goldTreasury &lt; $goldFieldMax, $goldTreasury, $goldFieldMax)"
$goldAmount = $goldAmount.Replace("`t`t`t<userproperties>`n", "`t`t`t<userproperties>`n`t`t`t`t<property`n`t`t`t`t`tname=`"MaxValue`"`n`t`t`t`t`tvalue=`"$goldFieldMax`"/>`n")
function New-ContextCommandEvent([string]$command, [string[]]$events) {
    $properties = ""
    for ($i = 0; $i -lt $events.Count; $i++) {
        $properties += "`t`t`t`t`t`t<property`n`t`t`t`t`t`t`tname=`"event$i`"`n`t`t`t`t`t`t`tvalue=`"$($events[$i])`"/>`n"
    }
    return "`t`t`t`t<callback_with_context`n`t`t`t`t`tcallback_id=`"ContextCommandEvent`"`n" +
        "`t`t`t`t`tcontext_function_id=`"$command`">`n" +
        "`t`t`t`t`t<child_m_user_properties>`n" + $properties +
        "`t`t`t`t`t</child_m_user_properties>`n`t`t`t`t</callback_with_context>`n"
}
# user property trade_magic_items_locked = "true" (Lua, human partner: the deal
# can't be changed) keeps both arrows grey. Lua can't do that itself: a
# clamp already on its way sets the arrows after it (0.11.0 log: the right
# arrow came back active 0.3 s after the lock)
$goldLocked = "self.GetProperty(&quot;trade_magic_items_locked&quot;) == &quot;true&quot;"
$goldCap = "Do(DoIf(self.GetValue &gt; $goldMax, self.SetValue($goldMax)), " +
    "self.ChildContext(&quot;r_arrow_amount&quot;).SetState(GetIfElse($goldLocked, &quot;inactive&quot;, GetIfElse(self.GetValue &lt; $goldMax, &quot;active&quot;, &quot;inactive&quot;))), " +
    "self.ChildContext(&quot;l_arrow_amount&quot;).SetState(GetIfElse($goldLocked, &quot;inactive&quot;, GetIfElse(self.GetValue &gt; 0, &quot;active&quot;, &quot;inactive&quot;))))"
$goldCallbacks = "`t`t`t`t<callback_with_context callback_id=`"NumericalInput`">`n" +
    "`t`t`t`t`t<child_m_user_properties>`n" +
    "`t`t`t`t`t`t<property`n`t`t`t`t`t`t`tname=`"MaxValue`"`n`t`t`t`t`t`t`tvalue=`"$goldFieldMax`"/>`n" +
    "`t`t`t`t`t`t<property`n`t`t`t`t`t`t`tname=`"value_changed_event`"`n`t`t`t`t`t`t`tvalue=`"trade_magic_items_gold_value_changed`"/>`n" +
    "`t`t`t`t`t</child_m_user_properties>`n`t`t`t`t</callback_with_context>`n" +
    (New-ContextCommandEvent $goldCap @("trade_magic_items_gold_clamp", "trade_magic_items_gold_value_changed", "TextInputChanged")) +
    (New-ContextCommandEvent "self.SetValue(0)" @("trade_magic_items_gold_reset")) +
    (New-ContextCommandEvent "self.SetValue(ToNumber(self.GetProperty(&quot;trade_magic_items_balance_value&quot;)))" @("trade_magic_items_gold_balance")) +
    (New-ContextCommandEvent "TriggerUIScriptEvent(&quot;trade_magic_items_gold_changed&quot;)" @("trade_magic_items_gold_value_changed", "TextInputChanged"))
$numericalInput = "`t`t`t`t<callback_with_context callback_id=`"NumericalInput`"/>`n"
if ($goldAmount.IndexOf($numericalInput) -lt 0) { throw "NumericalInput callback not found in the amount" }
$goldAmount = $goldAmount.Replace($numericalInput, $goldCallbacks)
$goldAmount = Set-Placement $goldAmount "Bottom Left" "203.00,-9.00" "0.00,1.00"
$leftArrow = Get-BlockByGuid $payments "l_arrow_amount" "19E6DB3D-3571-4355-B338465E244A4D56"
$rightArrow = Get-BlockByGuid $payments "r_arrow_amount" "0DEEBB44-1BBC-44A8-A480F3C9C44DE25D"

# fixed size: the resize handle stretches children that allow it
# (user, 0.6.2: the amount field grew with the window)
function Set-NoResize([string]$block) {
    $block = [regex]::Replace($block, '^(\t\t<[^\n]+\n\t\t\tthis="[^"]+"\n\t\t\tid="[^"]+"\n)((?:\t\t\t[a-z_]+="[^"]*"\n)*)', {
        param($m)
        $attrs = [regex]::Replace($m.Groups[2].Value, '\t\t\tallow(horizontal|vertical)resize="[^"]*"\n', '')
        return $m.Groups[1].Value + "`t`t`tallowhorizontalresize=`"false`"`n`t`t`tallowverticalresize=`"false`"`n" + $attrs
    })
    if ($block.IndexOf('allowverticalresize="false"') -lt 0) { throw "Set-NoResize failed" }
    return $block
}
# under the title plaque (priority 60): some cultures' plaque reaches over
# the treasuries, it has to stay on top (user, 0.8.5)
function Set-Priority([string]$block, [int]$priority) {
    return [regex]::Replace($block, '(\t\t\tid="[^"]+"\n)', "`$1`t`t`tpriority=`"$priority`"`n", 1)
}
$treasury = Set-Priority $treasury 50
$treasuryIcon = Set-Priority $treasuryIcon 50
$partnerTreasury = Set-Priority $partnerTreasury 50
$partnerTreasuryIcon = Set-Priority $partnerTreasuryIcon 50
# the native answer: offer_response of the offers panel (the framed
# backing) with its dy_text, whose states they_accepted / they_declined
# carry their own localised text and font
$dealFrame = Set-Placement (Copy-WithNewId (Get-Block $offers "offer_response") "offer_response" "trade_magic_items_deal_result_frame") "Center" "0.00,0.00" "0.50,0.50"
$dealFrame = Set-Priority $dealFrame 70
$dealResult = Copy-WithNewId (Get-BlockByGuid $offers "dy_text" "0943A8A2-C784-404E-8F4C77A8B26838DA") "dy_text" "trade_magic_items_deal_result"
$acceptedState = [regex]::Match($dealResult, 'this="([^"]+)"\n\t+name="they_accepted"').Groups[1].Value
if ($acceptedState -eq "") { throw "they_accepted state not found" }
$dealResult = [regex]::Replace($dealResult, 'currentstate="[^"]+"', "currentstate=`"$acceptedState`"")
$dealResult = [regex]::Replace($dealResult, 'defaultstate="[^"]+"', "defaultstate=`"$acceptedState`"")
$dealResult = Set-Placement $dealResult "Center" "0.00,0.00" "0.50,0.50"
$dealResult = Set-Priority $dealResult 70
$treasury = Set-NoResize $treasury
$treasuryIcon = Set-NoResize $treasuryIcon
$partnerTreasury = Set-NoResize $partnerTreasury
$partnerTreasuryIcon = Set-NoResize $partnerTreasuryIcon
$chance = Set-NoResize $chance
$waiting = Set-NoResize $waiting
$goldSwitch = Set-NoResize $goldSwitch
$offerLabel = Set-NoResize $offerLabel
$demandLabel = Set-NoResize $demandLabel
$goldAmount = Set-NoResize $goldAmount
$leftArrow = Set-NoResize $leftArrow
$rightArrow = Set-NoResize $rightArrow

foreach ($block in @($goldSwitch, $payOffer, $payDemand, $offerLabel, $demandLabel, $goldAmount, $leftArrow, $rightArrow)) {
    if ($block -match 'Diplomacy[A-Za-z]*Panel') { throw "native diplomacy panel callback copied" }
}

$copied = $treasury + "`n" + $treasuryIcon + "`n" + $partnerTreasury + "`n" + $partnerTreasuryIcon + "`n" + $chance + "`n" + $waiting + "`n" + $balance + "`n" + $confirm + "`n" + $counter + "`n" + $dealFrame + "`n" + $dealResult + "`n" +
    (@($goldSwitch, $payOffer, $offerLabel, $payDemand, $demandLabel, $goldAmount, $leftArrow, $rightArrow) -join "`n")
$text = $text.Replace("`t</components>", $copied + "`n`t</components>")

$treasuryGuid = [regex]::Match($treasury, 'this="([^"]+)"').Groups[1].Value
$treasuryIconGuid = [regex]::Match($treasuryIcon, 'this="([^"]+)"').Groups[1].Value
$partnerTreasuryGuid = [regex]::Match($partnerTreasury, 'this="([^"]+)"').Groups[1].Value
$partnerTreasuryIconGuid = [regex]::Match($partnerTreasuryIcon, 'this="([^"]+)"').Groups[1].Value
$chanceGuid = [regex]::Match($chance, 'this="([^"]+)"').Groups[1].Value
$waitingGuid = [regex]::Match($waiting, 'this="([^"]+)"').Groups[1].Value
$balanceGuid = [regex]::Match($balance, 'this="([^"]+)"').Groups[1].Value
$confirmGuid = [regex]::Match($confirm, 'this="([^"]+)"').Groups[1].Value
$counterGuid = [regex]::Match($counter, 'this="([^"]+)"').Groups[1].Value
$dealResultGuid = [regex]::Match($dealResult, 'this="([^"]+)"').Groups[1].Value
$dealFrameGuid = [regex]::Match($dealFrame, 'this="([^"]+)"').Groups[1].Value

# hierarchy: last children of trade_magic_items
$hierarchyClose = "`t`t`t</trade_magic_items>"
if ($text.IndexOf($hierarchyClose) -lt 0) { throw "hierarchy end of trade_magic_items not found" }
# the treasuries go before the title plaque: earlier children draw under it
$treasuryChildren = "`t`t`t`t<dy_treasury this=`"$treasuryGuid`">`n`t`t`t`t`t<treasury_icon this=`"$treasuryIconGuid`"/>`n`t`t`t`t</dy_treasury>`n" +
    "`t`t`t`t<dy_treasury_partner this=`"$partnerTreasuryGuid`">`n`t`t`t`t`t<treasury_icon_partner this=`"$partnerTreasuryIconGuid`"/>`n`t`t`t`t</dy_treasury_partner>`n"
$plaqueLine = [regex]::Match($text, '\t\t\t\t<title_plaque this="[^"]+">\n')
if (-not $plaqueLine.Success) { throw "title plaque not found in the hierarchy" }
$text = $text.Replace($plaqueLine.Value, $treasuryChildren + $plaqueLine.Value)
$newChildren = "`t`t`t`t<button_enlarge_br this=`"$handleGuid`"/>`n" +
    "`t`t`t`t<label_deal_success_chance this=`"$chanceGuid`"/>`n" +
    "`t`t`t`t<trade_magic_items_waiting this=`"$waitingGuid`"/>`n" +
    "`t`t`t`t<trade_magic_items_balance_button this=`"$balanceGuid`"/>`n" +
    "`t`t`t`t<trade_magic_items_deal_result_frame this=`"$dealFrameGuid`">`n`t`t`t`t`t<trade_magic_items_deal_result this=`"$dealResultGuid`"/>`n`t`t`t`t</trade_magic_items_deal_result_frame>`n" +
    "`t`t`t`t<buttongroup_offer_demand this=`"94BF432E-0E87-4256-8B077B87917A4EB1`">`n" +
    "`t`t`t`t`t<pay_offer this=`"11FA26EE-0DA1-477F-AD8AFECDF7373FB3`">`n`t`t`t`t`t`t<once_tx this=`"78945FEA-A629-431A-B6DC46BB4F5904B5`"/>`n`t`t`t`t`t</pay_offer>`n" +
    "`t`t`t`t`t<pay_demand this=`"38811817-811A-41AD-A9C3225C684EBAE3`">`n`t`t`t`t`t`t<repeatedly_tx this=`"0F75E8E8-4375-4A55-89BE3E036639B61C`"/>`n`t`t`t`t`t</pay_demand>`n" +
    "`t`t`t`t</buttongroup_offer_demand>`n" +
    "`t`t`t`t<amount this=`"2B10C977-D164-4317-AD3696C355211132`">`n" +
    "`t`t`t`t`t<l_arrow_amount this=`"19E6DB3D-3571-4355-B338465E244A4D56`"/>`n`t`t`t`t`t<r_arrow_amount this=`"0DEEBB44-1BBC-44A8-A480F3C9C44DE25D`"/>`n" +
    "`t`t`t`t</amount>`n"
$text = $text.Replace($hierarchyClose, $newChildren + $hierarchyClose)
$buttonsClose = "`t`t`t`t</both_buttongroup>"
if ($text.IndexOf($buttonsClose) -lt 0) { throw "hierarchy end of both_buttongroup not found" }
$text = $text.Replace($buttonsClose, "`t`t`t`t`t<confirm_trade_magic_items this=`"$confirmGuid`"/>`n`t`t`t`t`t<counter_trade_magic_items this=`"$counterGuid`"/>`n" + $buttonsClose)

# fresh GUIDs for everything we added (placeholders + the donor handle);
# the rest of the file keeps its GUIDs
$map = @{}
$added = @("11111111-AAAA-4AAA-8AAA111111111111", "22222222-AAAA-4AAA-8AAA222222222222", "33333333-AAAA-4AAA-8AAA333333333333",
    "44444444-AAAA-4AAA-8AAA444444444444", "55555555-AAAA-4AAA-8AAA555555555555", "66666666-AAAA-4AAA-8AAA666666666666",
    "77777777-AAAA-4AAA-8AAA777777777777", "88888888-AAAA-4AAA-8AAA888888888888")
# references into template files (uniqueguid_in_template) must stay
$templateRefs = [regex]::Matches($handle + $copied, 'uniqueguid_in_template="([^"]+)"') | ForEach-Object { $_.Groups[1].Value }
$added += [regex]::Matches($handle + $copied, '\b[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{16}\b') | ForEach-Object { $_.Value } | Where-Object { $templateRefs -notcontains $_ }
foreach ($old in ($added | Select-Object -Unique)) {
    $g = [guid]::NewGuid().ToString().ToUpper()
    $map[$old] = $g.Substring(0, 23) + $g.Substring(24)
}
foreach ($old in $map.Keys) { $text = $text.Replace($old, $map[$old]) }

[xml]$check = $text
[System.IO.File]::WriteAllText($outPath, $text, (New-Object System.Text.UTF8Encoding($false)))
Write-Host ("written {0}: {1}x{2}, {3} new GUIDs" -f $outPath, $width, $height, $map.Count)
