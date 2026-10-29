// 밑줄 웹 데모: 페이지 위를 문지르면 지나간 단어만 골라 담는다.
// 규칙은 앱과 같다 (HighlightSelectionView): 단어 상자를 10pt 넓혀 판정, 지우개는 빼기,
// 고른 단어는 읽는 순서대로 잇고, 띄어쓰기 없는 글(중국어 · 일본어 · 태국어)은 빈칸 없이 잇는다.
(() => {
  const root = document.getElementById("demo");
  if (!root) return;
  const T = JSON.parse(root.dataset.text);
  const lang = document.documentElement.lang;
  const unspaced = /^(zh|ja|th)/.test(lang);
  const TOLERANCE = 10;

  // 낱말: 띄어 쓰는 글은 빈칸으로, 아니면 Intl.Segmenter 로 나누고 문장부호는 앞 낱말에 붙인다(인식 결과처럼).
  function words(text) {
    if (!unspaced || !window.Intl || !Intl.Segmenter) return text.split(/\s+/).filter(Boolean);
    const out = [];
    for (const s of new Intl.Segmenter(lang, { granularity: "word" }).segment(text)) {
      if (!s.segment.trim()) continue;
      if (!s.isWordLike && out.length) out[out.length - 1] += s.segment; else out.push(s.segment);
    }
    return out;
  }
  // 구절: 키보드 · 화면 읽기에서는 앱의 "줄 하나 두 번 탭" 처럼 구절 하나를 통째로 긋고 지운다.
  // 태국어는 문장부호 대신 빈칸으로 마디를 나누므로 빈칸이 구절의 경계다.
  const thai = lang.startsWith("th");
  const phrases = thai ? T.text.split(/\s+/).filter(Boolean)
    : T.text.match(/[^,.;:!?，。；：！？、]+[,.;:!?，。；：！？、…]*\s*/g) || [T.text];

  root.innerHTML = `
    <div class="ul-left">
      <div class="ul-page" lang="${lang}">
        <div class="ul-head">${T.book}</div>
        <div class="ul-text"></div>
        <div class="ul-num">${T.page}</div>
        <svg class="ul-stroke" aria-hidden="true"><polyline points=""/></svg>
      </div>
      <div class="ul-tools">
        <button type="button" class="ul-tool" data-act="eraser" aria-pressed="false">${T.eraser}</button>
        <span class="ul-space"></span>
        <button type="button" class="ul-tool" data-act="clear">${T.clear}</button>
        <button type="button" class="ul-tool" data-act="all">${T.all}</button>
      </div>
    </div>
    <div class="ul-right">
      <p class="ul-label">${T.result}</p>
      <figure class="ul-card" aria-live="polite">
        <svg class="ul-mark" viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M10 7H6.5A2.5 2.5 0 0 0 4 9.5V13a2 2 0 0 0 2 2h2.2c-.2 1.4-1 2.4-2.6 3l.8 1.8C9.6 18.8 11 16.6 11 13V8a1 1 0 0 0-1-1Zm9 0h-3.5A2.5 2.5 0 0 0 13 9.5V13a2 2 0 0 0 2 2h2.2c-.2 1.4-1 2.4-2.6 3l.8 1.8C18.6 18.8 20 16.6 20 13V8a1 1 0 0 0-1-1Z"/></svg>
        <blockquote class="ul-quote"></blockquote>
        <figcaption><b>${T.book}</b><span>${T.author} <i>${T.pageLabel}</i></span></figcaption>
        <div class="ul-brand">${T.appName}</div>
      </figure>
      <p class="muted small ul-note">${T.note}</p>
    </div>`;

  const $ = s => root.querySelector(s);
  const page = $(".ul-page"), textEl = $(".ul-text"), line = $(".ul-stroke polyline"), quote = $(".ul-quote");
  const eraserBtn = $('[data-act="eraser"]');

  // 구절마다 낱말을 span 으로. 낱말 사이 빈칸은 띄어 쓰는 글에만 둔다.
  const all = [], groups = [];
  phrases.forEach(p => {
    const g = document.createElement("span");
    g.className = "ul-phrase"; g.tabIndex = 0; g.setAttribute("role", "button"); g.setAttribute("aria-pressed", "false");
    const ws = words(p).map(w => {
      const s = document.createElement("span");
      s.className = "ul-word"; s.textContent = w;
      g.append(s, unspaced ? "" : " ");
      all.push(s); return s;
    });
    g.words = ws; groups.push(g); textEl.append(g, thai ? " " : "");
  });

  const picked = new Set();
  let erase = false;

  function render() {
    all.forEach(w => w.classList.toggle("on", picked.has(w)));
    groups.forEach(g => g.setAttribute("aria-pressed", String(g.words.every(w => picked.has(w)))));
    const text = groups.map(g => g.words.filter(w => picked.has(w)).map(w => w.textContent).join(unspaced ? "" : " "))
      .filter(Boolean).join(unspaced && !thai ? "" : " ");
    quote.textContent = text || T.empty;
    quote.classList.toggle("empty", !text);
    root.classList.toggle("used", picked.size > 0);
  }

  // 문지르기: 누른 순간의 단어 상자를 재 두고, 지나간 점(빠르게 그어도 6px 마다)이 상자 안이면 고른다.
  let boxes = null, last = null, pts = [];
  function hit(x, y) {
    for (const [w, r] of boxes)
      if (x >= r.left - TOLERANCE && x <= r.right + TOLERANCE && y >= r.top - TOLERANCE && y <= r.bottom + TOLERANCE)
        erase ? picked.delete(w) : picked.add(w);
  }
  function move(e) {
    if (!boxes) return;
    const p = { x: e.clientX, y: e.clientY };
    const steps = last ? Math.max(1, Math.ceil(Math.hypot(p.x - last.x, p.y - last.y) / 6)) : 1;
    for (let i = 1; i <= steps; i++)
      hit(last ? last.x + (p.x - last.x) * i / steps : p.x, last ? last.y + (p.y - last.y) * i / steps : p.y);
    last = p;
    const o = page.getBoundingClientRect();
    pts.push(`${p.x - o.left},${p.y - o.top}`);
    line.setAttribute("points", pts.join(" "));
    render();
  }
  page.addEventListener("pointerdown", e => {
    if (e.button > 0) return;
    e.preventDefault();
    page.setPointerCapture(e.pointerId);
    boxes = all.map(w => [w, w.getBoundingClientRect()]);
    last = null; pts = [];
    move(e);
  });
  page.addEventListener("pointermove", move);
  const end = () => { boxes = null; pts = []; line.setAttribute("points", ""); };
  page.addEventListener("pointerup", end);
  page.addEventListener("pointercancel", end);

  // 키보드: 구절에서 Enter · Space 로 통째로 긋거나 지운다.
  textEl.addEventListener("keydown", e => {
    const g = e.target.closest(".ul-phrase");
    if (!g || (e.key !== "Enter" && e.key !== " ")) return;
    e.preventDefault();
    const on = g.words.every(w => picked.has(w));
    g.words.forEach(w => on ? picked.delete(w) : picked.add(w));
    render();
  });

  root.addEventListener("click", e => {
    const act = e.target.closest("[data-act]")?.dataset.act;
    if (act === "eraser") {
      erase = !erase;
      eraserBtn.setAttribute("aria-pressed", String(erase));
      eraserBtn.textContent = erase ? T.eraserOn : T.eraser;
      page.classList.toggle("erasing", erase);
    }
    if (act === "clear") picked.clear();
    if (act === "all") all.forEach(w => picked.add(w));
    render();
  });

  render();
})();
