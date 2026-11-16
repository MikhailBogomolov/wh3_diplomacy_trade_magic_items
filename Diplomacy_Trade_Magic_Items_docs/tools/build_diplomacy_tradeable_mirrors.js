// Mirror item generator (variant D, findings §7.0.4-7.0.5 and M1).
//
// A race-locked item (faction_set != all) cannot reach a faction outside
// its set. For every tradeable race-locked item this builds a mirror:
// the same item under the key <original>_diplomacy_tradeable with
// faction_set = all and randomly_dropped = false. A trade delivers the
// original when the receiver may own it, otherwise the mirror.
//
// Re-run after every game patch (CA may add / remove items or change
// their effects):
//   1. extract the vanilla db, text/db/ancillaries__.loc and
//      text/db/ancillary_sets__.loc to Vanilla_files (same layout as
//      now: db/<table>/data__.tsv)
//   2. node build_diplomacy_tradeable_mirrors.js
//   3. re-import the written files into the pack (RPFM), replacing the
//      old ones
//
// Tradeable = the filter of our item list (diplomacy_hud_trade_magic_
// items.twui.xml): category not hidden, not general / mount,
// transferrable, uniqueness group not unique / unique_fusable / rune /
// scrap / scrap_upgraded, subcategory not character_rune (the dwarfs'
// own rune slot), no row in ancillaries_included_agent_subtypes_tables
// (only certain character types can wear it, nobody else could use it).
//
// Copied per item: ancillaries_tables, ancillary_info_tables,
// ancillary_to_effects_tables, ancillary_to_included_agents_tables
// (who may equip it),
// the 3 loc texts (English only: one loc file for every language).
// Not copied: ritual / reward sources (mirrors only come from trades);
// ancillary_ownership_content_pack_junctions_tables (DLC ownership): a
// receiver without that DLC silently got nothing and the giver lost the
// item (MP test 0.12.0: Chaos Dwarf items to Arbaal).
//
// Item sets: a set has no "items needed" column, so it completes with
// all its members worn. Mirrors therefore never join the original set
// (it would need originals and mirrors together). Every set with a
// mirrored member gets its own mirror set <set>_diplomacy_tradeable
// (ancillary_sets_tables, ancillary_set_ancillary_junctions_tables,
// ancillary_set_effect_junctions_tables, name / description loc) made
// of the members' mirrors. A member without a mirror (magic standards,
// category general, not traded) stays in the mirror set as the
// original item, so it is in two sets at once (user, 2026-10-29: test
// how the game handles that rather than mirror banners too). Only the
// original's own faction can wear it, so for anybody else such a set
// shows its bonus but cannot be completed.
//
// Written:
//   db/<table>/diplomacy_tradeable_magic_items_mirror.tsv
//   text/diplomacy_tradeable_magic_items_mirror.loc.tsv
//   script/campaign/mod/diplomacy_tradeable_magic_items_mirror.lua
//     (original key -> faction set, read by the trade script)

const fs = require('fs');
const path = require('path');

// project root = two folders up from this script (Diplomacy_Trade_Magic_Items_docs/tools)
const ROOT = path.resolve(__dirname, '..', '..');
const VANILLA = path.join(ROOT, 'Vanilla_files');
const PACK = path.join(ROOT, 'Diplomacy_Trade_Magic_Items_packfile');
const SUFFIX = '_diplomacy_tradeable';
const FILE = 'diplomacy_tradeable_magic_items_mirror';
const LUA_TABLE = 'diplomacy_tradeable_magic_items_mirror';

const EXCLUDED_GROUPS = [
    'wh_main_anc_group_unique',
    'wh_main_anc_group_unique_fusable',
    'wh2_dlc17_anc_group_rune',
    'wh_main_anc_group_scrap',
    'wh_main_anc_group_scrap_upgraded'
];

const EXCLUDED_SUBCATEGORIES = ['character_rune'];

// table -> column holding the ancillary key
const COPIED_TABLES = {
    ancillary_info_tables: 'ancillary',
    ancillary_to_effects_tables: 'ancillary',
    ancillary_to_included_agents_tables: 'ancillary'
};

const LOC_PREFIXES = [
    'ancillaries_onscreen_name_',
    'ancillaries_colour_text_',
    'ancillaries_explanation_text_'
];

const SET_LOC_PREFIXES = [
    'ancillary_sets_name_',
    'ancillary_sets_description_'
];


function readTsv(file) {
    const lines = fs.readFileSync(file, 'utf8').replace(/\r\n/g, '\n').split('\n');
    const columns = lines[0].split('\t');

    return {
        columns: columns,
        rows: lines.slice(2).filter(line => line.length > 0).map(line => line.split('\t'))
    };
}

function readTable(table) {
    return readTsv(path.join(VANILLA, 'db', table, 'data__.tsv'));
}

function column(table, name) {
    const index = table.columns.indexOf(name);

    if (index < 0) {
        throw new Error('column not found: ' + name);
    }

    return index;
}

function writeTsv(file, columns, meta, rows) {
    const dir = path.dirname(file);

    if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir);
    }

    const lines = [columns.join('\t'), meta + '\t'.repeat(columns.length - 1)]
        .concat(rows.map(row => row.join('\t')));

    fs.writeFileSync(file, lines.join('\n') + '\n');
}

function writeDbTable(table, rows) {
    const columns = readTable(table).columns;
    const meta = '#' + table + ';0;db/' + table + '/' + FILE;

    writeTsv(path.join(PACK, 'db', table, FILE + '.tsv'), columns, meta, rows);
    console.log(table + ': ' + rows.length + ' rows');
}


// --- which items need a mirror ---

const categories = readTable('ancillaries_categories_tables');
const hiddenCategory = {};

categories.rows.forEach(row => {
    hiddenCategory[row[column(categories, 'category')]] = row[column(categories, 'hidden')] === 'true';
});

const groups = readTable('ancillary_uniqueness_groupings_tables');

function uniquenessGroups(score) {
    return groups.rows
        .filter(row => +score >= +row[column(groups, 'uniqueness_min')] && +score <= +row[column(groups, 'uniqueness_max')])
        .map(row => row[column(groups, 'group_key')]);
}

const ancillaries = readTable('ancillaries_tables');
const KEY = column(ancillaries, 'key');
const CATEGORY = column(ancillaries, 'category');
const TRANSFERRABLE = column(ancillaries, 'transferrable');
const UNIQUENESS = column(ancillaries, 'uniqueness_score');
const FACTION_SET = column(ancillaries, 'faction_set');
const RANDOMLY_DROPPED = column(ancillaries, 'randomly_dropped');
const SUBCATEGORY = column(ancillaries, 'subcategory');

const subtypeLimits = readTable('ancillaries_included_agent_subtypes_tables');
const subtypeLimited = {};

subtypeLimits.rows.forEach(row => {
    subtypeLimited[row[column(subtypeLimits, 'ancillary')]] = true;
});

const mirrored = ancillaries.rows.filter(row => {
    const category = row[CATEGORY];
    const itemGroups = uniquenessGroups(row[UNIQUENESS]);

    return hiddenCategory[category] === false
        && category !== 'general'
        && category !== 'mount'
        && row[TRANSFERRABLE] === 'true'
        && !EXCLUDED_SUBCATEGORIES.includes(row[SUBCATEGORY])
        && !subtypeLimited[row[KEY]]
        && itemGroups.length > 0
        && !itemGroups.some(group => EXCLUDED_GROUPS.includes(group))
        && row[FACTION_SET] !== 'all'
        && !row[KEY].endsWith(SUFFIX);
});

const factionSetOf = {};

mirrored.forEach(row => {
    factionSetOf[row[KEY]] = row[FACTION_SET];
});

console.log('items to mirror: ' + mirrored.length);


// --- which item sets need a mirror ---

const setJunctions = readTable('ancillary_set_ancillary_junctions_tables');
const JUNCTION_ITEM = column(setJunctions, 'ancillary_key');
const JUNCTION_SET = column(setJunctions, 'set_key');
const setMembers = {};

setJunctions.rows.forEach(row => {
    (setMembers[row[JUNCTION_SET]] = setMembers[row[JUNCTION_SET]] || []).push(row[JUNCTION_ITEM]);
});

const mirroredSets = {};
const originalMembers = [];

Object.keys(setMembers).forEach(set => {
    const members = setMembers[set];

    if (!members.some(key => factionSetOf[key] !== undefined)) {
        return;
    }

    mirroredSets[set] = true;
    members.forEach(key => {
        if (factionSetOf[key] === undefined) {
            originalMembers.push(key);
        }
    });
});

console.log('item sets to mirror: ' + Object.keys(mirroredSets).length
    + ', members kept as originals (also in the original set): ' + originalMembers.join(' '));


// --- db tables ---

writeDbTable('ancillaries_tables', mirrored.map(row => {
    const copy = row.slice();

    copy[KEY] = row[KEY] + SUFFIX;
    copy[FACTION_SET] = 'all';
    copy[RANDOMLY_DROPPED] = 'false';

    return copy;
}));

Object.keys(COPIED_TABLES).forEach(table => {
    const data = readTable(table);
    const keyColumn = column(data, COPIED_TABLES[table]);

    writeDbTable(table, data.rows
        .filter(row => factionSetOf[row[keyColumn]] !== undefined)
        .map(row => {
            const copy = row.slice();

            copy[keyColumn] = row[keyColumn] + SUFFIX;

            return copy;
        }));
});

const sets = readTable('ancillary_sets_tables');
const SET_KEY = column(sets, 'key');

writeDbTable('ancillary_sets_tables', sets.rows
    .filter(row => mirroredSets[row[SET_KEY]])
    .map(row => {
        const copy = row.slice();

        copy[SET_KEY] = row[SET_KEY] + SUFFIX;

        return copy;
    }));

writeDbTable('ancillary_set_ancillary_junctions_tables', setJunctions.rows
    .filter(row => mirroredSets[row[JUNCTION_SET]])
    .map(row => {
        const copy = row.slice();

        if (factionSetOf[row[JUNCTION_ITEM]] !== undefined) {
            copy[JUNCTION_ITEM] = row[JUNCTION_ITEM] + SUFFIX;
        }
        copy[JUNCTION_SET] = row[JUNCTION_SET] + SUFFIX;

        return copy;
    }));

const setEffects = readTable('ancillary_set_effect_junctions_tables');
const EFFECT_SET = column(setEffects, 'set_key');

writeDbTable('ancillary_set_effect_junctions_tables', setEffects.rows
    .filter(row => mirroredSets[row[EFFECT_SET]])
    .map(row => {
        const copy = row.slice();

        copy[EFFECT_SET] = row[EFFECT_SET] + SUFFIX;

        return copy;
    }));


// --- loc ---

const locRows = [];
let missingNames = 0;

function copyLoc(loc, keys, prefixes, namePrefix) {
    keys.forEach(key => {
        prefixes.forEach(prefix => {
            const original = loc.rows.find(locRow => locRow[0] === prefix + key);

            if (original) {
                const copy = original.slice();

                copy[0] = prefix + key + SUFFIX;
                locRows.push(copy);
            } else if (prefix === namePrefix) {
                missingNames++;
            }
        });
    });
}

const loc = readTsv(path.join(VANILLA, 'text', 'db', 'ancillaries__.loc.tsv'));

copyLoc(loc, mirrored.map(row => row[KEY]), LOC_PREFIXES, 'ancillaries_onscreen_name_');
copyLoc(
    readTsv(path.join(VANILLA, 'text', 'db', 'ancillary_sets__.loc.tsv')),
    Object.keys(mirroredSets),
    SET_LOC_PREFIXES,
    'ancillary_sets_name_'
);

writeTsv(
    path.join(PACK, 'text', FILE + '.loc.tsv'),
    loc.columns,
    '#Loc;1;text/' + FILE + '.loc',
    locRows
);
console.log('loc: ' + locRows.length + ' rows' + (missingNames > 0 ? ', ' + missingNames + ' items / sets without a name' : ''));


// --- lua: original key -> faction set ---

const luaLines = [
    '------------------------------------------------------------',
    '-- GENERATED by Diplomacy_Trade_Magic_Items_docs/tools/',
    '-- build_diplomacy_tradeable_mirrors.js - do not edit by hand.',
    '--',
    '-- Race-locked tradeable items that have a mirror',
    '-- (<key>' + SUFFIX + ', faction_set = all): original key ->',
    '-- faction set of the original. The trade gives the original when',
    '-- the receiver is in the set, otherwise the mirror.',
    '------------------------------------------------------------',
    '',
    LUA_TABLE + ' = {'
];

Object.keys(factionSetOf).sort().forEach(key => {
    luaLines.push('    ["' + key + '"] = "' + factionSetOf[key] + '",');
});

luaLines.push('}', '');

fs.writeFileSync(path.join(PACK, 'script', 'campaign', 'mod', FILE + '.lua'), luaLines.join('\n'));
console.log('lua: ' + Object.keys(factionSetOf).length + ' entries');
