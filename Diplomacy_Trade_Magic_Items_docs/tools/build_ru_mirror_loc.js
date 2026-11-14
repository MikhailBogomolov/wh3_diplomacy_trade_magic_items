// Russian loc of the mirror items, for the translation pack.
//
// Takes every key of our generated English mirror loc
// (text/diplomacy_tradeable_magic_items_mirror.loc.tsv in the main pack),
// cuts the _diplomacy_tradeable suffix, looks the original key up in the
// Russian vanilla loc and writes the Russian text under our key into the
// translation pack. The main generator (build_diplomacy_tradeable_mirrors.js)
// is not touched.
//
// Re-run after every game patch, after the main generator:
//   1. extract the Russian vanilla localisation__.loc (local_ru.pack) to
//      Vanilla_files/text/localisation__.loc.tsv
//   2. node build_ru_mirror_loc.js
//   3. re-import the written file into the translation pack (RPFM)
//
// A key without a Russian text keeps the English one and is listed in
// the output.

const fs = require('fs');
const path = require('path');

const ROOT = 'D:/Games/Modding/Diplomacy_Trade_Magic_Items_Mod';
const SOURCE = path.join(ROOT, 'Diplomacy_Trade_Magic_Items_packfile/text/diplomacy_tradeable_magic_items_mirror.loc.tsv');
const RUSSIAN = path.join(ROOT, 'Vanilla_files/text/localisation__.loc.tsv');
const TARGET = path.join(ROOT, 'Diplomacy_Trade_Magic_Items_ru_packfile/text/diplomacy_tradeable_magic_items_mirror.loc.tsv');
const SUFFIX = '_diplomacy_tradeable';

function originalKey(key) {
    // items and sets both end with the suffix
    return key.endsWith(SUFFIX) ? key.slice(0, -SUFFIX.length) : null;
}

function makeDir(dir) {
    if (!fs.existsSync(dir)) {
        makeDir(path.dirname(dir));
        fs.mkdirSync(dir);
    }
}

function main() {
    const sourceLines = fs.readFileSync(SOURCE, 'utf8').split('\n').filter((line) => line !== '');
    const header = sourceLines.slice(0, 2);
    const rows = sourceLines.slice(2).map((line) => line.split('\t'));

    // only the originals we need: the Russian file is ~48 MB
    const wanted = new Map();

    for (const row of rows) {
        const original = originalKey(row[0]);

        if (original) {
            wanted.set(original, null);
        }
    }

    // read at once: line streaming needs a newer node than the one here
    for (const line of fs.readFileSync(RUSSIAN, 'utf8').split('\n')) {
        const tab = line.indexOf('\t');

        if (tab < 0) {
            continue;
        }

        const key = line.slice(0, tab);

        if (wanted.has(key) && wanted.get(key) === null) {
            wanted.set(key, line.slice(tab + 1).split('\t'));
        }
    }

    const missing = [];
    const out = header.slice();

    for (const row of rows) {
        const original = originalKey(row[0]);
        const russian = original ? wanted.get(original) : null;

        if (russian) {
            out.push([row[0], russian[0], russian[1] || row[2]].join('\t'));
        } else {
            missing.push(row[0]);
            out.push(row.join('\t'));
        }
    }

    makeDir(path.dirname(TARGET));
    fs.writeFileSync(TARGET, out.join('\n') + '\n');

    console.log('rows: ' + rows.length + ', Russian: ' + (rows.length - missing.length) + ', kept English: ' + missing.length);

    for (const key of missing) {
        console.log('  no Russian text: ' + key);
    }

    console.log('written: ' + TARGET);
}

main();
