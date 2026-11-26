// Klawiatura i mysz dla placu zabaw. Worker z interpreterem liczy program bez przerwy, więc
// wiadomości ze strony nie usłyszy; umie za to zapytać synchronicznie (XMLHttpRequest) o adres
// __ferdek_zdarzenia?s=<sesja>, a ten service worker odpowiada kolejką zdarzeń, które strona
// mu wysłała. Działa bez nagłówków COOP/COEP (SharedArrayBuffer by ich wymagał).
// ponytail: kolejka w pamięci - przeglądarka może uśpić service workera i zgubić zdarzenia
// czekające dłużej niż ~30 s; program, który pyta co klatkę, tego nie zauważy.
const queues = new Map();   // sesja -> [[rodzaj, klawisz, x, y], ...]
const LIMIT = 256;          // nieodebrane zdarzenia na sesję; starsze wypadają

self.addEventListener("install", () => self.skipWaiting());
self.addEventListener("activate", e => e.waitUntil(self.clients.claim()));

self.addEventListener("message", e => {
  const m = e.data || {};
  if (typeof m.s !== "string") return;
  if (m.end) { queues.delete(m.s); return; }
  if (!Array.isArray(m.ev) || m.ev.length !== 4 || !m.ev.every(Number.isInteger)) return;
  if (!queues.has(m.s)) queues.set(m.s, []);
  const q = queues.get(m.s);
  q.push(m.ev);
  if (q.length > LIMIT) q.shift();
});

self.addEventListener("fetch", e => {
  const url = new URL(e.request.url);
  if (!url.pathname.endsWith("/__ferdek_zdarzenia")) return;   // reszta strony idzie normalnie
  const s = url.searchParams.get("s") || "";
  const body = JSON.stringify(queues.get(s) || []);
  queues.delete(s);
  e.respondWith(new Response(body, { headers: { "Content-Type": "application/json", "Cache-Control": "no-store" } }));
});
