# Builds ui/campaign ui/ad_holder_portrait.twui.xml: a callback-free copy of the
# "equipped by" portrait (+ army/agent icon) from the vanilla ancillary_entry
# template. Lua creates it inside item rows whose native portrait can't show
# the holder (other factions' characters) and fills image + tooltips itself.

$ErrorActionPreference = "Stop"

$templatePath = "D:\Games\Modding\Diplomacy_Trade_Magic_Items_Mod\Vanilla_files\ui\templates\ancillary_entry.twui.xml"
$outPath = "D:\Games\Modding\Diplomacy_Trade_Magic_Items_Mod\Diplomacy_Trade_Magic_Items_packfile\ui\campaign ui\ad_holder_portrait.twui.xml"

$text = [System.IO.File]::ReadAllText($templatePath) -replace "`r`n", "`n"

function Get-Block([string]$tag) {
    $m = [regex]::Match($text, "(?s)\t\t<$tag\n\t\t\tthis=`"[^`"]+`"\n\t\t\tid=`"$tag`".*?\t\t</$tag>")
    if (-not $m.Success) { throw "block not found: $tag" }
    return $m.Value
}

function Clean-Block([string]$block) {
    $block = [regex]::Replace($block, '(?s)\t\t\t<callbackwithcontextlist>.*?\t\t\t</callbackwithcontextlist>\n', '')
    $block = [regex]::Replace($block, '(?s)\t\t\t<userproperties>.*?\t\t\t</userproperties>\n', '')
    $block = [regex]::Replace($block, '\t\t\tuniqueguid_in_template="[^"]+"\n', '')
    return $block
}

$portrait = Clean-Block (Get-Block "assigned_char_portrait")
$portrait = $portrait.Replace("<assigned_char_portrait", "<ad_holder_portrait").Replace("</assigned_char_portrait>", "</ad_holder_portrait>").Replace('id="assigned_char_portrait"', 'id="ad_holder_portrait"')

$icon = Clean-Block (Get-Block "forces_icon")
$icon = $icon.Replace("<forces_icon", "<ad_holder_icon").Replace("</forces_icon>", "</ad_holder_icon>").Replace('id="forces_icon"', 'id="ad_holder_icon"')

$portraitGuid = [regex]::Match($portrait, 'this="([^"]+)"').Groups[1].Value
$iconGuid = [regex]::Match($icon, 'this="([^"]+)"').Groups[1].Value
$rootGuid = "46D1CC2D-584E-4B0B-A20E1B86BE2CE87C"
$rootState = "7C87B4F0-CF40-448D-B18163798C555E6E"

$layout = @"
<?xml version="1.0"?>
<layout
	version="142"
	comment="Trade Magic Items: equipped-by portrait without native callbacks; filled by script"
	precache_condition="">
	<hierarchy>
		<root this="$rootGuid">
			<ad_holder_portrait this="$portraitGuid">
				<ad_holder_icon this="$iconGuid"/>
			</ad_holder_portrait>
		</root>
	</hierarchy>
	<components>
$portrait
$icon
		<root
			this="$rootGuid"
			id="root"
			uniqueguid="$rootGuid"
			currentstate="$rootState"
			defaultstate="$rootState">
			<states>
				<default
					this="$rootState"
					name="default"
					width="1600"
					height="900"
					uniqueguid="$rootState"/>
			</states>
		</root>
	</components>
</layout>
"@ -replace "`r`n", "`n"

# fresh GUIDs, consistent within the file
$map = @{}
$layout = [regex]::Replace($layout, '\b[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{16}\b', {
    param($m)
    if (-not $map.ContainsKey($m.Value)) {
        $g = [guid]::NewGuid().ToString().ToUpper()
        $map[$m.Value] = $g.Substring(0, 23) + $g.Substring(24)
    }
    $map[$m.Value]
})

[xml]$check = $layout
[System.IO.File]::WriteAllText($outPath, $layout + "`n", (New-Object System.Text.UTF8Encoding($false)))
Write-Host ("written {0}, {1} GUIDs" -f $outPath, $map.Count)
