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

// Klawiatura i mysz: ZDARZENIE_CZEKAJ pyta synchronicznie pod adres z wiadomości "run";
// tu odpowiada udawany XMLHttpRequest (w przeglądarce - service worker playground/sw.js)
const pending = [[[1, 65361, 0, 0], [3, 1, 12, 34]], [[2, 65361, 0, 0]]];
const asked = [];
globalThis.XMLHttpRequest = class {
  open(method, url, async) { asked.push([method, url, async]); }
  send() { this.status = 200; this.responseText = JSON.stringify(pending.shift() || []); }
};
const poll = `CO JEST KURDE
KRĘCI CEMENT BETONIARA i OD 1 DO 5
    PANIE SENSACJA REWELACJA W MORDĘ JEŻA ZDARZENIE_CZEKAJ()
    W MORDĘ JEŻA TRZEBA SPAĆ(10)
A ROBIĆ NI MA KOMU
MOJA NOGA JUŻ TUTAJ NIE POSTANIE
`;
msgs.length = 0;
globalThis.onmessage({ data: { cmd: "run", code: poll, input: "\n", events: "http://plac/__ferdek_zdarzenia?s=abc" } });
assert.strictEqual(text("err"), "");
assert.strictEqual(text("out").split("\n").slice(0, 5).join("|"),
  "[1, 65361, 0, 0]|[3, 1, 12, 34]|[2, 65361, 0, 0]|[0, 0, 0, 0]|[0, 0, 0, 0]");
assert.ok(asked.length >= 3 && asked.every(a => a[0] === "GET" && a[1].endsWith("?s=abc") && a[2] === false));
// bez adresu (brak service workera) program działa, tylko zdarzeń nie ma i nikt nie pyta
msgs.length = 0; asked.length = 0;
globalThis.onmessage({ data: { cmd: "run", code: poll, input: "\n" } });
assert.strictEqual(text("err"), "");
assert.ok(text("out").startsWith("[0, 0, 0, 0]\n[0, 0, 0, 0]"));
assert.strictEqual(asked.length, 0);
// service worker: kolejka na sesję, odpowiedź opróżnia kolejkę, obce adresy idą normalnie
const handlers = {};
const sandbox = { self: { addEventListener: (n, f) => { handlers[n] = f; }, skipWaiting() {}, clients: { claim() {} } },
                  URL, Map, JSON, Number, Array, Response: class { constructor(body) { this.body = body; } } };
require("vm").runInNewContext(fs.readFileSync(path.join(root, "playground/sw.js"), "utf8"), sandbox);
const ask = url => { let r = null; handlers.fetch({ request: { url }, respondWith: x => { r = x; } }); return r && r.body; };
handlers.message({ data: { s: "a", ev: [1, 97, 0, 0] } });
handlers.message({ data: { s: "b", ev: [3, 1, 5, 6] } });
handlers.message({ data: { s: "a", ev: ["zle"] } });
assert.strictEqual(ask("http://plac/__ferdek_zdarzenia?s=a"), "[[1,97,0,0]]");
assert.strictEqual(ask("http://plac/__ferdek_zdarzenia?s=a"), "[]");
assert.strictEqual(ask("http://plac/__ferdek_zdarzenia?s=b"), "[[3,1,5,6]]");
assert.strictEqual(ask("http://plac/index.html"), null);
console.log("--- plac zabaw: grafika, usypianie, klawiatura i mysz OK");
