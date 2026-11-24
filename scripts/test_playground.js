// Plac zabaw bez przeglądarki: worker (ferdek_web.js) odpalony w node z udawanym postMessage.
// Sprawdza grafikę (okno, klatki, paleta, odczyt bufora) i TRZEBA SPAĆ.
//   node scripts/test_playground.js [_build/playground/ferdek_web.js]
const assert = require("assert");
const fs = require("fs");
const path = require("path");
const root = path.resolve(__dirname, "..");
const bundle = path.resolve(process.argv[2] || path.join(root, "_build/playground/ferdek_web.js"));

const msgs = [];
globalThis.postMessage = m => msgs.push(m);
globalThis.onmessage = null;   // js_of_ocaml sprawdza, czy to wątek roboczy
require(bundle);

const started = Date.now();
globalThis.onmessage({ data: { cmd: "run", code: fs.readFileSync(path.join(root, "playground/przyklady/telewizor.ferdek"), "utf8"), input: "\n" } });
const of = kind => msgs.filter(m => m.kind === kind);
const text = kind => of(kind).map(m => m.text).join("");

assert.strictEqual(text("err"), "");
assert.deepStrictEqual(of("done").map(m => m.code), [0]);
assert.deepStrictEqual(of("window").map(m => [m.w, m.h, m.title]), [[160, 100, "Telewizor Ferdka"]]);
const frames = of("frame");
assert.strictEqual(frames.length, 24);
assert.ok(Date.now() - started >= 24 * 40, "TRZEBA SPAĆ(40) po każdej klatce");
const first = new Uint8ClampedArray(frames[0].data), last = new Uint8ClampedArray(frames[23].data);
assert.strictEqual(first.length, 160 * 100 * 4);
assert.ok(first.some((v, i) => v !== last[i]), "klatki się różnią");
// Piksel ze środka ostatniej klatki: program wypisuje jego numer w palecie [i, i*i/255, 96 - i/3]
const i = Number(/kolor (\d+)/.exec(text("out"))[1]);
const o = (50 * 160 + 80) * 4;
assert.deepStrictEqual(Array.from(last.slice(o, o + 4)), [i, Math.floor(i * i / 255), 96 - Math.floor(i / 3), 255]);
console.log("--- plac zabaw: grafika i usypianie OK");
