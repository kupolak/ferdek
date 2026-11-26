// Prymitywy, których js_of_ocaml nie ma, a plac zabaw potrzebuje: usypianie i grafika.

//Provides: caml_unix_sleep
function caml_unix_sleep(seconds) {
  // ponytail: czekanie w pętli - worker to osobny wątek, strona się nie zacina.
  // Atomics.wait byłoby grzeczniejsze, ale wymaga SharedArrayBuffer (nagłówki COOP/COEP).
  var end = Date.now() + seconds * 1000;
  while (Date.now() < end) {}
  return 0;
}

// Grafika (OKNO_OTWORZ, PIKSEL_MALUJ, EKRAN_ODSWIEZ...): te same prymitywy co
// src/graphics/graphics_stubs.c, ale bufor ramki siedzi w workerze, a EKRAN_ODSWIEZ wysyła gotową
// klatkę RGBA do strony, która maluje ją na <canvas>.

//Provides: ferdek_gfx
var ferdek_gfx = { w: 0, h: 0, fb: null, pal: null };

//Provides: caml_ferdek_window_open
//Requires: ferdek_gfx, caml_jsstring_of_string
function caml_ferdek_window_open(w, h, title) {
  // ponytail: limit 1024x1024 - większa klatka to megabajty na każde odświeżenie
  if (w <= 0 || h <= 0 || w > 1024 || h > 1024) return 0;
  ferdek_gfx.w = w;
  ferdek_gfx.h = h;
  ferdek_gfx.fb = new Uint8Array(w * h);
  // paleta domyślna: odcienie szarości, jak init_default_palette w graphics_x11.c
  ferdek_gfx.pal = new Uint8Array(768);
  for (var i = 0; i < 768; i++) ferdek_gfx.pal[i] = (i / 3) | 0;
  globalThis.postMessage({ kind: "window", w: w, h: h, title: caml_jsstring_of_string(title) });
  return 1;
}

//Provides: caml_ferdek_window_close
//Requires: ferdek_gfx
function caml_ferdek_window_close(unit) {
  // ostatnia klatka zostaje na stronie - okno, które znika po skończeniu programu, nic by nie pokazało
  ferdek_gfx.fb = null;
  return 0;
}

//Provides: caml_ferdek_palette_set
//Requires: ferdek_gfx, caml_bytes_unsafe_get
function caml_ferdek_palette_set(pal) {
  if (ferdek_gfx.pal) for (var i = 0; i < 768; i++) ferdek_gfx.pal[i] = caml_bytes_unsafe_get(pal, i);
  return 0;
}

//Provides: caml_ferdek_pixel_draw
//Requires: ferdek_gfx
function caml_ferdek_pixel_draw(x, y, color) {
  var g = ferdek_gfx;
  if (g.fb && x >= 0 && x < g.w && y >= 0 && y < g.h) g.fb[y * g.w + x] = color;
  return 0;
}

//Provides: caml_ferdek_screen_clear
//Requires: ferdek_gfx
function caml_ferdek_screen_clear(color) {
  if (ferdek_gfx.fb) ferdek_gfx.fb.fill(color);
  return 0;
}

//Provides: caml_ferdek_framebuffer_get
//Requires: ferdek_gfx
function caml_ferdek_framebuffer_get(x, y) {
  var g = ferdek_gfx;
  return g.fb && x >= 0 && x < g.w && y >= 0 && y < g.h ? g.fb[y * g.w + x] : 0;
}

//Provides: caml_ferdek_screen_refresh
//Requires: ferdek_gfx
function caml_ferdek_screen_refresh(unit) {
  var g = ferdek_gfx;
  if (!g.fb) return 0;
  var rgba = new Uint8ClampedArray(g.w * g.h * 4);
  for (var i = 0, o = 0; i < g.fb.length; i++, o += 4) {
    var p = g.fb[i] * 3;
    rgba[o] = g.pal[p];
    rgba[o + 1] = g.pal[p + 1];
    rgba[o + 2] = g.pal[p + 2];
    rgba[o + 3] = 255;
  }
  globalThis.postMessage({ kind: "frame", w: g.w, h: g.h, data: rgba.buffer }, [rgba.buffer]);
  return 0;
}

// Klawiatura i mysz (ZDARZENIE_CZEKAJ): strona wysyła zdarzenia do service workera (sw.js),
// a my odbieramy je stąd synchronicznym zapytaniem - worker liczy program bez przerwy, więc
// zwykłych wiadomości nie usłyszy. Adres z numerem sesji ustawia ferdek_web.ml przy starcie
// programu (globalThis.ferdek_events_url); pusty = brak service workera, zdarzeń nie ma.

//Provides: ferdek_events
var ferdek_events = { queue: [], last: 0 };

//Provides: caml_ferdek_event_poll
//Requires: ferdek_events
function caml_ferdek_event_poll(unit) {
  var e = ferdek_events, url = globalThis.ferdek_events_url;
  // ponytail: pytamy najwyżej co 5 ms - program w ciasnej pętli nie zasypie przeglądarki zapytaniami
  if (e.queue.length === 0 && url && Date.now() - e.last >= 5) {
    e.last = Date.now();
    try {
      var x = new XMLHttpRequest();
      x.open("GET", url, false);
      x.send();
      var got = x.status === 200 ? JSON.parse(x.responseText) : null;
      if (Array.isArray(got)) e.queue = got;
      else globalThis.ferdek_events_url = "";   // to nie nasz service worker - nie pytamy więcej
    } catch (err) { globalThis.ferdek_events_url = ""; }
  }
  var ev = e.queue.shift();
  // rodzaj: 0 brak, 1 klawisz wciśnięty, 2 puszczony, 3 przycisk myszy (jak w graphics_x11.c)
  return ev ? [0, ev[0] | 0, ev[1] | 0, ev[2] | 0, ev[3] | 0] : [0, 0, 0, 0, 0];
}
