// Tabs for our trade panel (1.1.0): Magic Items / Banners / Followers.
//
// Builds diplomacy_hud_trade_magic_items.twui.xml from the 1.0.1 layout
// (backups/diplomacy_hud_trade_magic_items.before_tabs.twui.xml), so it can
// be run again after any change here:  node build_tabs.js
//
//   1. each column (list_offers) gets three list views, one per tab:
//      view_magic / view_banners / view_followers. A view is a transparent
//      component of the column's size with the native Listview callback
//      (moved down from list_offers) and its own list_clip, list_box, list
//      and slider, so every tab scrolls on its own (user, test 2). The
//      lists are magic_items_list / banners_list / followers_list with their
//      own filters. All views stay bound, the script shows one: ticks and
//      scroll survive a tab switch. Each slider goes back to the top on the
//      UiMsg trade_magic_items_scroll_reset (sent when the window opens).
//   2. three tab buttons (square_medium_text_tab_toggle, copied from the
//      vanilla search_panel without its ButtonGroupButton callback: the
//      script sets the states) docked at the top of the panel.
//   3. the panel grows by TAB_STRIP px: the columns move down by the same,
//      the dark parchment grows with the panel, so the tabs sit on it
//      between the rules text and the columns. The rules text is one line,
//      centred between the title plaque and the parchment. The resize
//      handle's max_scale keeps the tallest panel at 10 list rows.
// list_demands is copied from list_offers by the script at runtime, so
// only list_offers is changed here.
//
// Race rule in the filters (user, 2026-11-15): banners, followers, dwarf
// runes and items for generic agent subtypes go only to a faction that can
// use the original: CanFactionUseAncillary for both sides. The partner's
// key comes from the script (common.set_context_value, script object
// trade_magic_items_partner) before the lists are bound.

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

// project root = two folders up from this script (Diplomacy_Trade_Magic_Items_docs/tools)
const ROOT = path.resolve(__dirname, '..', '..');
const PANEL = path.join(ROOT, 'Diplomacy_Trade_Magic_Items_packfile', 'ui', 'campaign ui', 'diplomacy_hud_trade_magic_items.twui.xml');
const DONOR = path.join(ROOT, 'Vanilla_files', 'ui', 'campaign ui', 'search_panel.twui.xml');
const SOURCE = path.join(ROOT, 'backups', 'diplomacy_hud_trade_magic_items.before_tabs.twui.xml');

// extra panel height for the tab strip. Test 2 (user): the gap from the
// tabs down to the columns (~22 px) cut by a third (44 -> 37), and the gap
// from the parchment's top edge down to the tabs (~16 px) made the same by
// moving that edge down (PARCHMENT_TOP_DOWN); the tabs stay where they are
const TAB_STRIP = 37;
const PARCHMENT_TOP_DOWN = 2;

const PANEL_HEIGHT = 425;
const PARCHMENT_HEIGHT = 321;
// the parchment is docked at the panel centre with this shift
const PARCHMENT_DOCK_Y = -3;
const COLUMNS_Y = 61;

// tallest panel (the resize handle's max_scale): 10 list rows, as in 1.0.1
// (788 of 425: list_clip 604, row 10 ends at 598)
const MAX_EXTRA_HEIGHT = 363;
const MAX_SCALE_1_0_1 = '1.854';

// rules text: one line between the title plaque and the parchment
const RULES_Y = 30;
const RULES_WIDTH = 530;
const RULES_HEIGHT = 20;

// tab buttons: size, x offsets from the panel's top centre, y from its top
const TAB_WIDTH = 200;
const TAB_HEIGHT = 40;
const TAB_Y = 66;
// label shift from the button centre: vanilla -6 is for 46 px high tabs,
// ours are 40, so -6 left the text a bit high (user, test 2)
const TAB_TEXT_Y = -4;

const TABS = [
    { id: 'tab_magic_items', x: -210, text: 'Magic Items' },
    { id: 'tab_banners', x: 0, text: 'Banners' },
    { id: 'tab_followers', x: 210, text: 'Followers' }
];

// list views of a column, in tab order: view id, list id
const VIEWS = [
    { view: 'view_magic', list: 'magic_items_list' },
    { view: 'view_banners', list: 'banners_list' },
    { view: 'view_followers', list: 'followers_list' }
];

// donor tab button in search_panel: the button and its two children
const DONOR_TAB = [
    { tag: 'button_landmarks', guid: '3D1F4640-7947-455B-8AA8A2D860E572F8' },
    { tag: 'button_flame', guid: '66402418-DFDD-40B4-A18FBFA0C13BCE16' },
    { tag: 'button_txt', guid: 'A32F1C55-D7C4-4A41-B0EC953F64E0F485' }
];

// --- filters ---
// The banners / followers filters are repeated in the screen script
// (AD_TAB_FILTERS, to grey the tabs before the lists fill): keep both in sync.

const R = 'AncillaryRecordContext.';

function not(field, values) {
    return values.map(value => R + field + ' != "' + value + '"').join(' && ');
}

// shared by all tabs: transferable, not unique / crafted rune / scrap
const BASE = R + 'Transferrable == true && ' + not('UniquenessRecordContext.Key', [
    'wh_main_anc_group_unique',
    'wh_main_anc_group_unique_fusable',
    'wh2_dlc17_anc_group_rune',
    'wh_main_anc_group_scrap',
    'wh_main_anc_group_scrap_upgraded'
]);

// both sides can use the original (race lock, faction set)
const SAME_RACE = R + 'CanFactionUseAncillary(PlayersFaction.FactionRecordContext) && '
    + R + 'CanFactionUseAncillary(FactionContextFromKey(ScriptObjectContext("trade_magic_items_partner").StringValue).FactionRecordContext)';

const FILTERS = {
    // as in 1.0.x (mirrors carry them across races), plus dwarf character
    // runes and items for generic agent subtypes within the race
    magic_items_list: R + 'CategoryContext.IsHidden == false'
        + ' && ' + not('CategoryContext.Category', ['general', 'mount'])
        + ' && ' + BASE
        + ' && ((' + R + 'SubcategoryContext.Subcategory != "character_rune" && ' + R + 'IncludedAgentSubtypesList.Size == 0)'
        + ' || (' + SAME_RACE + '))',

    // banners, banner runes, engineering runes; the 11 basic banners have
    // faction set all, so they pass SAME_RACE for anybody.
    // Shadow Banner: Alith Anar only (named character)
    banners_list: R + 'CategoryContext.Category == "general"'
        + ' && (' + R + 'SubcategoryContext.Subcategory == "banner" || ' + R + 'SubcategoryContext.Subcategory == "banner_rune" || '
        + R + 'SubcategoryContext.Subcategory == "engineering_rune")'
        + ' && ' + BASE
        + ' && ' + SAME_RACE
        + ' && ' + not('Key', ['wh3_dlc29_anc_standard_hef_shadow_banner']),

    // followers; two faction-set-all followers with no source in the game
    // stay out (user, 2026-11-15)
    followers_list: R + 'CategoryContext.Category == "general"'
        + ' && ' + R + 'SubcategoryContext.Subcategory == "follower"'
        + ' && ' + BASE
        + ' && ' + SAME_RACE
        + ' && ' + not('Key', [
            'wh2_dlc17_bst_anc_follower_battle_scarred_ungor_raider',
            'wh2_main_anc_follower_lzd_librarian'
        ])
};

function xmlEscape(text) {
    return text.replace(/&/g, '&amp;').replace(/"/g, '&quot;');
}

function filterAttribute(list) {
    return 'context_function_id="AncillaryList.Filter(' + xmlEscape(FILTERS[list]) + ')"';
}

// --- helpers ---

function fail(message) {
    console.error('ERROR: ' + message);
    process.exit(1);
}

function newGuid() {
    const hex = crypto.randomBytes(16).toString('hex').toUpperCase();

    // CA layout format: 8-4-4-16
    return hex.slice(0, 8) + '-' + hex.slice(8, 12) + '-' + hex.slice(12, 16) + '-' + hex.slice(16);
}

// new GUIDs for everything except references into template files
function regenerate(text) {
    const map = {};

    return text.replace(/(uniqueguid_in_template=")?\b([0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{16})\b/g, (match, inTemplate, guid) => {
        if (inTemplate) {
            return match;
        }

        map[guid] = map[guid] || newGuid();
        return map[guid];
    });
}

// component definition: "\t\t<tag" + "\t\t\tthis=guid" ... "\t\t</tag>"
function findBlock(lines, tag, guid) {
    for (let i = 1; i < lines.length; i++) {
        if (lines[i].trim() === 'this="' + guid + '"' && lines[i - 1].trim() === '<' + tag) {
            for (let j = i; j < lines.length; j++) {
                if (lines[j] === '\t\t</' + tag + '>') {
                    return { start: i - 1, end: j };
                }
            }
        }
    }

    fail('component not found: ' + tag + ' ' + guid);
}

function blockText(lines, tag, guid) {
    const block = findBlock(lines, tag, guid);

    return lines.slice(block.start, block.end + 1).join('\n');
}

function replaceOnce(text, from, to, what) {
    const at = text.indexOf(from);

    if (at < 0 || text.indexOf(from, at + 1) >= 0) {
        fail((at < 0 ? 'not found: ' : 'not unique: ') + what);
    }

    return text.slice(0, at) + to + text.slice(at + from.length);
}

// hierarchy lines from "<tag this=" to its closing line (or the
// self-closing line), as one text
function hierarchySubtree(lines, tag) {
    const start = lines.findIndex(line => new RegExp('^\\t+<' + tag + ' this="').test(line));

    if (start < 0) {
        fail(tag + ' not found in the hierarchy');
    }

    if (/\/>$/.test(lines[start])) {
        return lines[start];
    }

    const indent = lines[start].match(/^\t*/)[0];
    const end = lines.findIndex((line, i) => i > start && line === indent + '</' + tag + '>');

    if (end < 0) {
        fail(tag + ' has no end in the hierarchy');
    }

    return lines.slice(start, end + 1).join('\n');
}

// (tag, guid) of every component in a hierarchy text
function partsOf(hierarchy) {
    const parts = [];

    hierarchy.replace(/<([a-z_]+) this="([0-9A-F-]+)"/g, (match, tag, guid) => {
        parts.push({ tag: tag, guid: guid });
    });

    return parts;
}

function indentLines(text, tabs) {
    return text.split('\n').map(line => tabs + line).join('\n');
}

// --- main ---

if (!fs.existsSync(SOURCE)) {
    fail('source layout missing: ' + SOURCE);
}

let panel = fs.readFileSync(SOURCE, 'utf8');
let lines = panel.split('\n');

// 1. list views

const columnStart = lines.findIndex(line => /^\t+<list_offers this="/.test(line));
const columnGuid = lines[columnStart].match(/this="([^"]+)"/)[1];
const columnHierarchy = hierarchySubtree(lines, 'list_offers');
const clipHierarchy = hierarchySubtree(lines, 'list_clip');
const sliderHierarchy = hierarchySubtree(lines, 'vslider');
const titleHierarchy = hierarchySubtree(lines, 'offers_title');

// a view holds what the column held, minus the title
const viewParts = partsOf(clipHierarchy + '\n' + sliderHierarchy);
const viewBlocks = viewParts.map(part => blockText(lines, part.tag, part.guid)).join('\n');
const viewInside = clipHierarchy + '\n' + sliderHierarchy;

const filterPattern = /context_function_id="AncillaryList\.Filter\([^"]*\)"/;
const sliderCallback = '\t\t\t\t<callback_with_context callback_id="VSlider"/>\n';
const sliderReset = sliderCallback
    + '\t\t\t\t<callback_with_context\n'
    + '\t\t\t\t\tcallback_id="ContextCommandEvent"\n'
    + '\t\t\t\t\tcontext_function_id="self.SetValue(0)">\n'
    + '\t\t\t\t\t<child_m_user_properties>\n'
    + '\t\t\t\t\t\t<property\n'
    + '\t\t\t\t\t\t\tname="event0"\n'
    + '\t\t\t\t\t\t\tvalue="trade_magic_items_scroll_reset"/>\n'
    + '\t\t\t\t\t</child_m_user_properties>\n'
    + '\t\t\t\t</callback_with_context>\n';

// the column's size: the views take it
const columnBlock = blockText(lines, 'list_offers', columnGuid);
const columnWidth = columnBlock.match(/\twidth="(\d+)"/)[1];
const columnHeight = columnBlock.match(/\theight="(\d+)"/)[1];

const listviewCallback = '\t\t\t<callbackwithcontextlist>\n\t\t\t\t<callback_with_context callback_id="Listview"/>\n\t\t\t</callbackwithcontextlist>\n';

let viewsHierarchy = '';
let newBlocks = '';

VIEWS.forEach((entry, index) => {
    // the first view keeps the original components, the others are copies
    let inside = viewInside;
    let blocks = viewBlocks;

    if (index > 0) {
        const copy = regenerate(viewInside + '\n@@SPLIT@@\n' + viewBlocks).split('\n@@SPLIT@@\n');

        inside = copy[0];
        blocks = copy[1];
        inside = inside.replace('<magic_items_list this=', '<' + entry.list + ' this=').replace('</magic_items_list>', '</' + entry.list + '>');
        blocks = replaceOnce(blocks, '\t\t<magic_items_list\n', '\t\t<' + entry.list + '\n', entry.list + ' tag');
        blocks = replaceOnce(blocks, 'id="magic_items_list"', 'id="' + entry.list + '"', entry.list + ' id');
        blocks = replaceOnce(blocks, '\t\t</magic_items_list>', '\t\t</' + entry.list + '>', entry.list + ' end tag');
    }

    blocks = blocks.replace(filterPattern, filterAttribute(entry.list));
    blocks = replaceOnce(blocks, sliderCallback, sliderReset, entry.view + ' slider callback');

    const viewGuid = newGuid();
    const stateGuid = newGuid();
    const viewBlock = [
        '\t\t<' + entry.view,
        '\t\t\tthis="' + viewGuid + '"',
        '\t\t\tid="' + entry.view + '"',
        '\t\t\tdocking="Top Left"',
        '\t\t\ttooltipslocalised="true"',
        '\t\t\tuniqueguid="' + viewGuid + '"',
        '\t\t\tcurrentstate="' + stateGuid + '">',
        listviewCallback.replace(/\n$/, ''),
        '\t\t\t<states>',
        '\t\t\t\t<newstate',
        '\t\t\t\t\tthis="' + stateGuid + '"',
        '\t\t\t\t\tname="NewState"',
        '\t\t\t\t\twidth="' + columnWidth + '"',
        '\t\t\t\t\theight="' + columnHeight + '"',
        '\t\t\t\t\tinteractive="true"',
        '\t\t\t\t\tuniqueguid="' + stateGuid + '"/>',
        '\t\t\t</states>',
        '\t\t</' + entry.view + '>'
    ].join('\n');

    const columnIndent = lines[columnStart].match(/^\t*/)[0];

    viewsHierarchy += '\n' + columnIndent + '\t<' + entry.view + ' this="' + viewGuid + '">\n'
        + indentLines(inside, '\t') + '\n'
        + columnIndent + '\t</' + entry.view + '>';

    newBlocks += '\n' + viewBlock + '\n' + blocks;
});

// the column: frame and title, then the views
const columnIndent = lines[columnStart].match(/^\t*/)[0];
const newColumnHierarchy = lines[columnStart] + '\n' + titleHierarchy + viewsHierarchy + '\n' + columnIndent + '</list_offers>';

// definitions of the original view parts go, they come back inside newBlocks
viewParts.forEach(part => {
    panel = replaceOnce(panel, blockText(lines, part.tag, part.guid) + '\n', '', part.tag + ' definition');
});

panel = replaceOnce(panel, columnHierarchy, newColumnHierarchy, 'column hierarchy');
panel = replaceOnce(panel, columnBlock, columnBlock.replace(listviewCallback, ''), 'column Listview callback');

// 2. tab buttons

const donorLines = fs.readFileSync(DONOR, 'utf8').replace(/\r\n/g, '\n').split('\n');
const donorBlocks = DONOR_TAB.map(part => blockText(donorLines, part.tag, part.guid)).join('\n');
const donorHierarchy = '\t\t\t\t<button_landmarks this="' + DONOR_TAB[0].guid + '">\n'
    + '\t\t\t\t\t<button_flame this="' + DONOR_TAB[1].guid + '"/>\n'
    + '\t\t\t\t\t<button_txt this="' + DONOR_TAB[2].guid + '"/>\n'
    + '\t\t\t\t</button_landmarks>';

let tabHierarchy = '';
let tabBlocks = '';

TABS.forEach(tab => {
    const copy = regenerate(donorHierarchy + '\n@@SPLIT@@\n' + donorBlocks).split('\n@@SPLIT@@\n');
    let hierarchy = copy[0];
    let blocks = copy[1];

    hierarchy = hierarchy.replace('<button_landmarks this=', '<' + tab.id + ' this=').replace('</button_landmarks>', '</' + tab.id + '>');

    blocks = replaceOnce(blocks, '\t\t<button_landmarks\n', '\t\t<' + tab.id + '\n', tab.id + ' tag');
    blocks = replaceOnce(blocks, 'id="button_landmarks"', 'id="' + tab.id + '"', tab.id + ' id');
    blocks = replaceOnce(blocks, '\t\t</button_landmarks>', '\t\t</' + tab.id + '>', tab.id + ' end tag');

    // the script sets the states: no button group
    blocks = blocks.replace(/\t+<callback_with_context callback_id="ButtonGroupButton">[\s\S]*?<\/callback_with_context>\n/, '');

    if (blocks.indexOf('ButtonGroupButton') >= 0) {
        fail('ButtonGroupButton left in ' + tab.id);
    }

    // size and place: anchored like the dock point (top centre)
    blocks = replaceOnce(
        blocks,
        '\t\t\tdimensions="187.00,46.00"',
        '\t\t\tdimensions="' + TAB_WIDTH + '.00,' + TAB_HEIGHT + '.00"\n'
            + '\t\t\tdock_point="Top Center"\n'
            + '\t\t\toffset="' + tab.x + '.00,' + TAB_Y + '.00"\n'
            + '\t\t\tpriority="60"',
        tab.id + ' dimensions'
    );

    // English default; the script sets the localised text
    blocks = replaceOnce(blocks, 'text="Landmarks"', 'text="' + tab.text + '"', tab.id + ' text');
    blocks = replaceOnce(blocks, 'textlocalised="true"\n\t\t\t\t\t\ttextlabel="StateText_f2661fd0"', 'textlocalised="false"', tab.id + ' text label');
    blocks = replaceOnce(blocks, 'dock_offset="0.00,-6.00"', 'dock_offset="0.00,' + TAB_TEXT_Y + '.00"', tab.id + ' text offset');

    tabHierarchy += '\n' + hierarchy;
    tabBlocks += '\n' + blocks;
});

const parentEnd = '\t\t\t\t</offer_demand_parent>';

panel = replaceOnce(panel, parentEnd, parentEnd + tabHierarchy, 'offer_demand_parent end');

// 3. layout: taller panel, columns lower, one-line rules text

lines = panel.split('\n');

const panelBlock = blockText(lines, 'trade_magic_items', '78F178AA-B7EA-F145-BEE9739F87DD241E');
const newPanelHeight = PANEL_HEIGHT + TAB_STRIP;
let grown = panelBlock
    .split('height="' + PANEL_HEIGHT + '"').join('height="' + newPanelHeight + '"')
    .split('height="' + PARCHMENT_HEIGHT + '"').join('height="' + (PARCHMENT_HEIGHT + TAB_STRIP - PARCHMENT_TOP_DOWN) + '"');

// state + tile + border
if (grown.split('height="' + newPanelHeight + '"').length - 1 !== 3) {
    fail('panel heights not as expected');
}

// centre-docked: top = (panel - parchment) / 2 + shift. Shorter by
// PARCHMENT_TOP_DOWN and shifted by half of it: the top edge moves down,
// the bottom edge stays
grown = replaceOnce(
    grown,
    'dock_offset="0.00,' + PARCHMENT_DOCK_Y + '.00"',
    'dock_offset="0.00,' + (PARCHMENT_DOCK_Y + PARCHMENT_TOP_DOWN / 2).toFixed(2) + '"',
    'parchment dock offset'
);
// the plain offset only mirrors where docking puts it
grown = replaceOnce(grown, 'offset="10.00,49.00"', 'offset="10.00,' + (49 + PARCHMENT_TOP_DOWN) + '.00"', 'parchment offset');

panel = replaceOnce(panel, panelBlock, grown, 'panel block');

// resize handle: max height stays at 10 list rows
const maxScale = (Math.ceil((newPanelHeight + MAX_EXTRA_HEIGHT) / newPanelHeight * 10000) / 10000).toFixed(4);

panel = replaceOnce(panel, 'name="max_scale"\n\t\t\t\t\tvalue="' + MAX_SCALE_1_0_1 + '"', 'name="max_scale"\n\t\t\t\t\tvalue="' + maxScale + '"', 'max_scale');

const columnsBlock = blockText(lines, 'offer_demand_parent', '8479F232-E5DC-9649-231F0482A7DECEC2');
let moved = replaceOnce(columnsBlock, 'offset="205.00,' + COLUMNS_Y + '.00"', 'offset="205.00,' + (COLUMNS_Y + TAB_STRIP) + '.00"', 'columns offset');

moved = replaceOnce(moved, 'dock_offset="0.00,' + COLUMNS_Y + '.00"', 'dock_offset="0.00,' + (COLUMNS_Y + TAB_STRIP) + '.00"', 'columns dock offset');
panel = replaceOnce(panel, columnsBlock, moved, 'columns block');

const rulesBlock = blockText(lines, 'label_trade_magic_items_rules', '8C63E36C-99D2-877B-0C5AB44EDF7648F7');
let rules = replaceOnce(rulesBlock, 'offset="46.00,32.00"', 'offset="46.00,' + RULES_Y + '.00"', 'rules offset');

rules = replaceOnce(rules, 'dock_offset="1.00,32.00"', 'dock_offset="1.00,' + RULES_Y + '.00"', 'rules dock offset');
rules = replaceOnce(rules, 'width="482"\n\t\t\t\t\theight="35"', 'width="' + RULES_WIDTH + '"\n\t\t\t\t\theight="' + RULES_HEIGHT + '"', 'rules size');
panel = replaceOnce(panel, rulesBlock, rules, 'rules block');

// definitions

panel = replaceOnce(panel, '\t</components>', newBlocks.slice(1) + '\n' + tabBlocks.slice(1) + '\n\t</components>', 'components end');

fs.writeFileSync(PANEL, panel);

console.log('column: ' + VIEWS.map(entry => entry.view + ' (' + entry.list + ')').join(', ') + ', each ' + columnWidth + 'x' + columnHeight + ' with its own slider');
console.log('tabs: ' + TABS.map(tab => tab.id).join(', '));
console.log('panel ' + PANEL_HEIGHT + ' -> ' + newPanelHeight + ' (max_scale ' + maxScale + ' = ' + (newPanelHeight * maxScale).toFixed(1) + ')'
    + ', parchment ' + PARCHMENT_HEIGHT + ' -> ' + (PARCHMENT_HEIGHT + TAB_STRIP - PARCHMENT_TOP_DOWN)
    + ', columns y ' + COLUMNS_Y + ' -> ' + (COLUMNS_Y + TAB_STRIP) + ', rules text y ' + RULES_Y);
console.log('written: ' + PANEL);
