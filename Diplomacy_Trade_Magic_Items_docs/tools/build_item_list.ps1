# Builds the native magic items list into our trade panel layout.
# Copies the row components from the vanilla character panel
# (character_details_panel_details.twui.xml), strips callbacks that
# only make sense in the character panel, regenerates GUIDs, and
# replaces the old placeholder row in our panel.

$ErrorActionPreference = "Stop"

$donorPath = "D:\Games\Modding\Diplomacy_Trade_Magic_Items_Mod\Vanilla_files\ui\campaign ui\character_details_panel_details.twui.xml"
$panelPath = "D:\Games\Modding\Diplomacy_Trade_Magic_Items_Mod\Diplomacy_Trade_Magic_Items_packfile\ui\campaign ui\diplomacy_hud_trade_magic_items.twui.xml"
$backupPath = Join-Path $PSScriptRoot "diplomacy_hud_trade_magic_items.before_item_list.twui.xml"

$donor = [System.IO.File]::ReadAllText($donorPath) -replace "`r`n", "`n"
$donorLines = $donor -split "`n"

# donor component GUIDs (the "this" attribute of each definition)
$parts = [ordered]@{
    magic_items_panel      = "47EAC8C2-0B0A-4C51-8F9CE9FBC0750C69"
    template_item_holder   = "C8F163B9-29AA-48A0-85A7D460962D4957"
    checkbox_toggle        = "AF28F8CD-807A-4DD2-B58F9F6AAD309B05"
    ancillary_entry        = "751944AF-9655-41D1-A789D999D93BCFBA"
    dy_label               = "8A713DB6-E177-4AB5-AA5267C89F52AC8F"
    dy_name                = "5F08593E-6635-4426-9E2FFAA9B81B901E"
    magic_effect           = "6771EDA6-C729-4D7A-985248FE4D53C0AA"
    equipment_items_frame  = "D9A827B4-6B5C-4D3E-B9B2944E1DCC6E27"
    dy_icon                = "7A6D684B-7051-4810-87BFE398A2F9EC08"
    cooldown               = "76B38A91-2592-41CE-BF915A4CBAC58DFA"
    assigned_char_portrait = "6977A98C-4E11-4AC5-ABF4C3F8A6104293"
    forces_icon            = "286A25B9-5091-4815-90BBE902C99CC1C4"
    dy_set_icon            = "D2139E67-92CA-424A-9B6D00DE530FB2DF"
}

function Get-DonorBlock([string]$tag, [string]$guid) {
    for ($i = 1; $i -lt $donorLines.Count; $i++) {
        if ($donorLines[$i].Trim() -eq "this=`"$guid`"" -and $donorLines[$i - 1].Trim() -eq "<$tag") {
            for ($j = $i; $j -lt $donorLines.Count; $j++) {
                if ($donorLines[$j] -eq "`t`t</$tag>") {
                    return $donorLines[($i - 1)..$j]
                }
            }
        }
    }
    throw "donor block not found: $tag $guid"
}

# Removes callback_with_context entries whose callback_id is in $drop.
function Remove-Callbacks([string[]]$lines, [string[]]$drop) {
    $out = New-Object System.Collections.Generic.List[string]
    $i = 0
    while ($i -lt $lines.Count) {
        $line = $lines[$i]
        if ($line.Trim().StartsWith("<callback_with_context")) {
            $item = New-Object System.Collections.Generic.List[string]
            $item.Add($line)
            $openClosed = $line.Trim().EndsWith(">") -and -not $line.Trim().EndsWith("/>")
            $done = $line.Trim().EndsWith("/>")
            while (-not $done) {
                $i++
                $l = $lines[$i]
                $item.Add($l)
                if (-not $openClosed) {
                    if ($l.Trim().EndsWith("/>")) { $done = $true }
                    elseif ($l.Trim().EndsWith(">")) { $openClosed = $true }
                }
                elseif ($l.Trim() -eq "</callback_with_context>") { $done = $true }
            }
            $text = $item -join "`n"
            $id = [regex]::Match($text, 'callback_id="([^"]+)"').Groups[1].Value
            if ($drop -notcontains $id) { $out.AddRange($item) } else { Write-Host "  dropped callback $id" }
        }
        else { $out.Add($line) }
        $i++
    }
    return ,$out.ToArray()
}

$blocks = [ordered]@{}
foreach ($tag in $parts.Keys) { $blocks[$tag] = Get-DonorBlock $tag $parts[$tag] }

# list: rename to magic_items_list (vanilla filter kept for this step)
$blocks["magic_items_panel"] = ($blocks["magic_items_panel"] -join "`n").Replace("<magic_items_panel", "<magic_items_list").Replace("</magic_items_panel>", "</magic_items_list>").Replace('id="magic_items_panel"', 'id="magic_items_list"') -split "`n"

# row holder: its visibility setter points at the character panel's global_pool
Write-Host "template_item_holder:"
$blocks["template_item_holder"] = Remove-Callbacks $blocks["template_item_holder"] @("ContextVisibilitySetter")

# checkbox: plain toggle like our Trade Settlement checkbox, no global_pool selection
Write-Host "checkbox_toggle:"
$cb = $blocks["checkbox_toggle"] -join "`n"
$cb = [regex]::Replace($cb, '(?s)\t\t\t<callbacks_with_context>.*?\t\t\t</callbacks_with_context>', "`t`t`t<callbacks_with_context>`n`t`t`t`t<callback_with_context callback_id=`"Checkbox`"/>`n`t`t`t</callbacks_with_context>")
$blocks["checkbox_toggle"] = $cb -split "`n"

# item entry: no click, drag, mark-as-seen or character-panel inactive state
Write-Host "ancillary_entry:"
$blocks["ancillary_entry"] = Remove-Callbacks $blocks["ancillary_entry"] @("ContextSlotItem", "ContextCommandMouseOn", "ContextInactiveStateSetter", "TopmostWhenDraggingCallback")

$newComponents = ($blocks.Values | ForEach-Object { $_ -join "`n" }) -join "`n"

# hierarchy for the new list (old GUIDs, regenerated below together)
$p = $parts
$hierarchy = @"
								<magic_items_list this="$($p.magic_items_panel)">
									<template_item_holder this="$($p.template_item_holder)">
										<checkbox_toggle this="$($p.checkbox_toggle)"/>
										<ancillary_entry this="$($p.ancillary_entry)">
											<dy_label this="$($p.dy_label)"/>
											<dy_name this="$($p.dy_name)"/>
											<magic_effect this="$($p.magic_effect)"/>
											<equipment_items_frame this="$($p.equipment_items_frame)">
												<dy_icon this="$($p.dy_icon)"/>
											</equipment_items_frame>
											<cooldown this="$($p.cooldown)"/>
											<assigned_char_portrait this="$($p.assigned_char_portrait)">
												<forces_icon this="$($p.forces_icon)"/>
											</assigned_char_portrait>
											<dy_set_icon this="$($p.dy_set_icon)"/>
										</ancillary_entry>
									</template_item_holder>
								</magic_items_list>
"@ -replace "`r`n", "`n"

# regenerate every GUID except references into template files
$guidPattern = '(?<!uniqueguid_in_template=")\b[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{16}\b'
$map = @{}
$regen = {
    param($m)
    $old = $m.Value
    if (-not $map.ContainsKey($old)) {
        $g = [guid]::NewGuid().ToString().ToUpper()
        $map[$old] = $g.Substring(0, 23) + $g.Substring(24)
    }
    return $map[$old]
}
$combined = $hierarchy + "`n@@SPLIT@@`n" + $newComponents
$combined = [regex]::Replace($combined, $guidPattern, $regen)
$split = $combined -split "`n@@SPLIT@@`n"
$hierarchy = $split[0]
$newComponents = $split[1]
Write-Host ("regenerated {0} GUIDs" -f $map.Count)

# --- patch our panel ---
$panel = [System.IO.File]::ReadAllText($panelPath)
[System.IO.File]::WriteAllText($backupPath, $panel)

# hierarchy: replace placeholder row (with its checkbox) by the new list
$oldHierarchy = '(?s)\t*<template_magic_item_list_item this="[^"]+">.*?</template_magic_item_list_item>\n'
if (-not [regex]::IsMatch($panel, $oldHierarchy)) { throw "placeholder row not found in hierarchy" }
$panel = [regex]::Replace($panel, $oldHierarchy, $hierarchy + "`n")

# components: remove placeholder row and its checkbox definitions
foreach ($tag in @("template_magic_item_list_item", "checkbox")) {
    $pattern = "(?s)\t\t<$tag\n\t\t\tthis=`"[^`"]+`"\n\t\t\tid=`"$tag`".*?\t\t</$tag>\n"
    if (-not [regex]::IsMatch($panel, $pattern)) { throw "component not found: $tag" }
    $panel = [regex]::Replace($panel, $pattern, "")
}

# components: add the new list definitions
if ($panel.IndexOf("`t</components>") -lt 0) { throw "</components> not found" }
$panel = $panel.Replace("`t</components>", $newComponents + "`n`t</components>")

[System.IO.File]::WriteAllText($panelPath, $panel, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "panel written, backup at $backupPath"
