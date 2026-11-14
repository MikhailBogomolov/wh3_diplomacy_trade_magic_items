// Flatten the CA context-object documentation (documentation.html) into
// one line per function: Object.Function | return | args | description | tags | events
const fs = require("fs");
const [src, dst] = process.argv.slice(2);
const text = fs.readFileSync(src, "utf8");

const unescape = s => s
    .replace(/<[^>]+>/g, "")
    .replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'").replace(/&amp;/g, "&")
    .replace(/\s+/g, " ").trim();

const out = [];
for (const block of text.split(/<a id ="(?=Cc[ou])/).slice(1)) {
    const m = block.match(/^([A-Za-z0-9_]+)"><h3>/);
    if (!m) continue;
    const obj = m[1];
    const desc = block.match(/<\/h3>([\s\S]*?)<h4>/);
    out.push("## " + obj + " -- " + (desc ? unescape(desc[1]) : ""));
    const rowRe = /<tr><td>([\s\S]*?)<\/tr>/g;
    let row;
    while ((row = rowRe.exec(block))) {
        const cellRe = /<td>([\s\S]*?)<\/td>/g;
        const rowText = "<td>" + row[1];
        const cells = [];
        let cell;
        while ((cell = cellRe.exec(rowText))) cells.push(unescape(cell[1]));
        out.push(obj + "." + cells.join(" | "));
    }
}
fs.writeFileSync(dst, out.join("\n"));
console.log(out.length + " lines");
