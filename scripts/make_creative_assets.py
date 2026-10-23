#!/usr/bin/env python3
"""App Store 크리에이티브 자산(제품 페이지 헤더 · 검색 결과) 생성: HTML → 헤드리스 Chrome.

사용법: python3 scripts/make_creative_assets.py [언어 ...]     (없으면 전부)

자리
  docs/screenshots/creative/<스토어 로케일>/header.png   3840x1646  제품 페이지 맨 위
  docs/screenshots/creative/<스토어 로케일>/search.png   3840x2560  검색 결과 (없으면 스크린샷이 대신 보인다)

⚠️ 안전 영역 밖은 기기에 따라 잘린다. 글은 **반드시** 안전 영역 안에 둔다(배경 · 기기 그림은 넘쳐도 된다).
   수치는 Apple 공식 PSD 템플릿에서 잰 값이다(https://developer.apple.com/app-store/asset-best-practices/).
   아이폰에서 헤더는 가운데만 남고, 검색 결과는 약 385pt 폭으로 줄어 보인다. 그래서 글이 크다.

⚠️ 가격 · 할인 · 주소(URL) · 수상 · 다른 플랫폼 이름은 넣지 않는다(Apple 가이드).
"""
import shutil, subprocess, sys, pathlib, tempfile, time

ROOT = pathlib.Path(__file__).resolve().parent.parent
RAW = ROOT / "docs" / "screenshots" / "raw"   # 스크린샷 원본을 그대로 쓴다 (raw/<언어>/03-library.png …)
OUT = ROOT / "docs" / "screenshots" / "creative"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

# 앱 언어 → App Store 로케일 (폴더 이름이 같다)
STORE = {}

# (가로, 세로, 안전 영역 left, top, right, bottom)
SPEC = {
    "header": (3840, 1646, (1097, 493, 2743, 1154)),
    "search": (3840, 2560, (836, 765, 3004, 1795)),
}

# 검색 결과: 눈썹글(그 나라 사람이 치는 검색어) · 헤드라인 · 보조 한 줄.
# 기기 화면은 '문장' 탭 - 밑줄 그어 모은 문장들이 책 제목·쪽수와 함께 쌓여 있다.
# <mark> 는 형광펜 밑줄(앱 아이콘의 주황 획)이다.
SEARCH = {
    "ko": ("독서 기록", "밑줄 그은 문장<br><mark>한곳에</mark> 모아요", "책 제목과 쪽수까지 함께 남아요"),
    "en": ("Reading journal", "Underlined lines,<br><mark>all in one place</mark>", "Book titles and page numbers stay with them"),
    "en-GB": ("Reading journal", "Underlined lines,<br><mark>all in one place</mark>", "Book titles and page numbers stay with them"),
    "zh-Hans": ("书摘", "划过线的句子<br><mark>收在一处</mark>", "书名和页码也一并保存下来"),
    "zh-Hant": ("書摘", "劃過線的句子<br><mark>收在一處</mark>", "書名和頁碼也一併保存下來"),
    "ja": ("読書記録", "線を引いた一文を<br><mark>ひとつの場所に</mark>", "本のタイトルもページ数もいっしょに残ります"),
    "ru": ("Дневник чтения", "Ваши цитаты<br><mark>в одном месте</mark>", "С названием книги и страницей"),
    "es": ("Diario de lectura", "Tus subrayados,<br><mark>en un solo lugar</mark>", "Con el libro y la página"),
    "de": ("Lesetagebuch", "Markierte Sätze,<br><mark>alle an einem Ort</mark>", "Buchtitel und Seitenzahl bleiben immer dabei"),
    "fr": ("Journal de lecture", "Vos passages<br><mark>au même endroit</mark>", "Avec le titre et la page"),
    "it": ("Diario di lettura", "Le frasi del cuore,<br><mark>tutte in un posto</mark>", "Con il titolo del libro e il numero di pagina"),
    "pt-BR": ("Diário de leitura", "Frases grifadas,<br><mark>num só lugar</mark>", "O título do livro e a página ficam junto"),
    "th": ("บันทึกการอ่าน", "ประโยคที่ขีดเส้นใต้<br><mark>รวมไว้ที่เดียว</mark>", "ชื่อหนังสือและเลขหน้าเก็บไว้ให้ด้วย"),
    "vi": ("Nhật ký đọc sách", "Câu gạch chân<br><mark>về một nơi</mark>", "Kèm tên sách và số trang"),
    "cs": ("Čtenářský deník", "Podtržené věty<br><mark>na jednom místě</mark>", "Název knihy i číslo strany zůstanou u nich"),
    "da": ("Læsedagbog", "Dine citater,<br><mark>samlet ét sted</mark>", "Med bogtitel og sidetal"),
    "el": ("Ημερολόγιο ανάγνωσης", "Υπογραμμίσεις<br><mark>σε ένα μέρος</mark>", "Με τίτλο βιβλίου και σελίδα"),
    "fi": ("Lukupäiväkirja", "Alleviivatut lauseet<br><mark>yhdessä paikassa</mark>", "Kirjan nimi ja sivunumero kulkevat mukana"),
    "id": ("Jurnal baca", "Kalimat favorit<br><mark>di satu tempat</mark>", "Lengkap dengan judul dan halaman"),
    "nb": ("Lesedagbok", "Favorittsetningene,<br><mark>samlet på ett sted</mark>", "Boktittel og sidetall følger med"),
    "nl": ("Leesdagboek", "Mooie zinnen,<br><mark>allemaal bij elkaar</mark>", "Met boektitel en paginanummer erbij"),
    "pl": ("Dziennik czytelniczy", "Podkreślone zdania<br><mark>w jednym miejscu</mark>", "Razem z tytułem książki i numerem strony"),
    "sv": ("Läsdagbok", "Dina bästa meningar,<br><mark>samlade på ett ställe</mark>", "Boktitel och sidnummer följer med"),
    "tr": ("Okuma günlüğü", "Altı çizili cümleler<br><mark>tek bir yerde</mark>", "Kitap adı ve sayfa numarasıyla birlikte saklanır"),
}

# 헤더: 처음 온 사람에게 한 가지 약속. 종이책에 긋던 밑줄을 사진 한 장으로 남긴다.
HEADER = {
    "ko": ("책 속 문장 스크랩", "종이책 밑줄,<br><mark>사진 한 장</mark>으로 평생"),
    "en": ("Book quote scrapbook", "Paper-book underlines,<br>kept with <mark>one photo</mark>"),
    "en-GB": ("Book quote scrapbook", "Paper-book underlines,<br>kept with <mark>one photo</mark>"),
    "zh-Hans": ("读书笔记", "纸书上划的线，<br><mark>一张照片</mark>就留住"),
    "zh-Hant": ("讀書筆記", "紙本書上劃的線，<br><mark>一張照片</mark>就留住"),
    "ja": ("読書メモ", "紙の本に引いた線を、<br><mark>写真1枚</mark>でずっと"),
    "ru": ("Цитаты из книг", "Любимые строки<br>из книг — <mark>одним фото</mark>"),
    "es": ("Citas de libros", "Tus subrayados,<br>guardados con <mark>una foto</mark>"),
    "de": ("Buchzitate sammeln", "Unterstrichene Sätze,<br>mit <mark>einem Foto</mark> bewahrt"),
    "fr": ("Citations de livres", "Vos phrases soulignées,<br>gardées en <mark>une photo</mark>"),
    "it": ("Citazioni dai libri", "Le frasi sottolineate,<br>salvate con <mark>una foto</mark>"),
    "pt-BR": ("Citações de livros", "Seus grifos no papel,<br>salvos com <mark>uma foto</mark>"),
    "th": ("คำคมจากหนังสือ", "ประโยคในหนังสือ<br>เก็บด้วย<mark>รูปเดียว</mark>"),
    "vi": ("Trích dẫn sách", "Câu hay trong sách,<br>lưu bằng <mark>một tấm ảnh</mark>"),
    "cs": ("Citáty z knih", "Věty z papírových knih<br>uložené <mark>jednou fotkou</mark>"),
    "da": ("Bogcitater", "Dine understregninger,<br>gemt med <mark>ét billede</mark>"),
    "el": ("Αποσπάσματα βιβλίων", "Υπογραμμίσεις βιβλίων<br>με <mark>μία φωτογραφία</mark>"),
    "fi": ("Kirjalainaukset", "Paperikirjan lauseet<br>talteen <mark>yhdellä kuvalla</mark>"),
    "id": ("Kutipan buku", "Kalimat dari buku,<br>cukup <mark>sekali jepret</mark>"),
    "nb": ("Boksitater", "Understrekingene dine,<br>lagret med <mark>ett bilde</mark>"),
    "nl": ("Boekcitaten", "Je onderstrepingen,<br>bewaard met <mark>één foto</mark>"),
    "pl": ("Cytaty z książek", "Ulubione zdania<br><mark>jednym zdjęciem</mark>"),
    "sv": ("Bokcitat", "Dina understrykningar,<br>sparade med <mark>ett foto</mark>"),
    "tr": ("Kitap alıntıları", "Altı çizili satırlar<br><mark>tek fotoğrafla</mark> sakla"),
}

# 기기 화면(시뮬레이터 캡처, 공개 저작물 문장으로 채운 서재)
SHOT_LIBRARY = "03-library.png"
SHOT_QUOTES = "04-quotes.png"
SHOT_DAILY = "05-daily.png"

# 바탕 · 글자색은 앱 아이콘과 같다: 미색 종이, 남색 잉크(Theme.ink), 주황 형광펜(AccentColor).
BASE_CSS = """
* { margin:0; padding:0; box-sizing:border-box; }
html,body { width:%(W)dpx; height:%(H)dpx; overflow:hidden; }
body { background:#f4eee0; position:relative;
  font-family:-apple-system, "SF Pro Display", "Apple SD Gothic Neo", sans-serif; }
.paper { position:absolute; inset:0;
  background: radial-gradient(ellipse at 50%% 45%%, #fbf7ee 0%%, #f4eee0 55%%, #ebe2cf 100%%); }
.glow { position:absolute; border-radius:50%%; filter:blur(160px); pointer-events:none; }
.text { position:absolute; display:flex; flex-direction:column; justify-content:center; }
.eyebrow { font-weight:700; color:#c8741f; letter-spacing:-0.01em; line-height:1.15; }
.headline { font-weight:800; color:#1a2942; letter-spacing:-0.03em; line-height:1.18; text-wrap:balance; }
.headline mark { color:inherit; background:linear-gradient(transparent 58%%, rgba(242,163,74,.75) 58%%, rgba(242,163,74,.75) 92%%, transparent 92%%);
  padding:0 .06em; -webkit-box-decoration-break:clone; }
.sub { font-weight:500; color:#6b6458; letter-spacing:-0.01em; line-height:1.35; text-wrap:balance; }
/* 한국어는 낱말 중간에서 끊지 않는다. */
:lang(ko) .headline, :lang(ko) .sub, :lang(ko) .eyebrow { word-break:keep-all; }
.phone { position:absolute; background:#1c1c1f; border:6px solid #2e2e33; padding:40px; border-radius:190px;
  box-shadow: 0 60px 140px rgba(60,40,10,.28), 0 0 0 2px #3a3a40 inset; }
.phone img { width:100%%; display:block; border-radius:152px; }
.stroke { position:absolute; height:70px; border-radius:40px; background:rgba(242,163,74,.30); }
"""

# 글이 상자를 넘지 않을 때까지 줄인다. 잘리는 글은 없다 - 끝까지 안 맞으면 표시하고 멈춘다.
FIT_JS = """
<script>
// 문구에 적은 줄(<br>)보다 더 쪼개지면 "Rispondi / con un / tocco" 처럼 읽기가 끊긴다.
// 적은 줄 수를 지킬 때까지 줄인다.
function lines(el) {
  return Math.round(el.getBoundingClientRect().height / parseFloat(getComputedStyle(el).lineHeight));
}
function fit(box, el, max, min) {
  const want = el.querySelectorAll('br').length + 1;
  let size = max;
  el.style.fontSize = size + 'px';
  while (size > min && (box.scrollHeight > box.clientHeight + 1 || box.scrollWidth > box.clientWidth + 1 ||
         lines(el) > want)) {
    size -= 4; el.style.fontSize = size + 'px';
  }
  if (box.scrollHeight > box.clientHeight + 1 || box.scrollWidth > box.clientWidth + 1 || lines(el) > want)
    document.body.dataset.overflow = '1';
}
document.fonts.ready.then(() => {
  const box = document.querySelector('.text');
  const h = document.querySelector('.headline');
  fit(box, h, +h.dataset.max, +h.dataset.min);
  document.body.dataset.done = '1';
});
</script>
"""


def phone(img, left, top, width, rotate=0):
    return (f'<div class="phone" style="left:{left}px;top:{top}px;width:{width}px;'
            f'transform:rotate({rotate}deg)"><img src="{img}"></div>')


def shot(lang, name):
    path = RAW / lang / name
    if not path.exists():
        raise SystemExit(f"기기 화면이 없다: {path}")
    return path.as_uri()


def search_html(lang):
    W, H, (l, t, r, b) = SPEC["search"]
    eyebrow, headline, sub = SEARCH[lang]
    sw, sh = r - l, b - t
    col = int(sw * 0.56)
    ph_w = 1040
    ph_left = l + col + int(sw * 0.04)
    return f"""
<div class="paper"></div>
<div class="glow" style="left:{ph_left - 300}px;top:600px;width:1700px;height:1600px;background:rgba(242,163,74,.22)"></div>
<div class="stroke" style="left:-120px;top:300px;width:900px;transform:rotate(-8deg)"></div>
<div class="stroke" style="left:3200px;top:2280px;width:800px;transform:rotate(-8deg)"></div>
{phone(shot(lang, SHOT_QUOTES), ph_left, t - 360, ph_w, 0)}
<div class="text" style="left:{l}px;top:{t}px;width:{col}px;height:{sh}px">
  <div class="eyebrow" style="font-size:96px">{eyebrow}</div>
  <div class="headline" data-max="230" data-min="130" style="margin-top:36px">{headline}</div>
  <div class="sub" style="font-size:84px;margin-top:52px">{sub}</div>
</div>"""


def header_html(lang):
    W, H, (l, t, r, b) = SPEC["header"]
    eyebrow, headline = HEADER[lang]
    sw, sh = r - l, b - t
    # 형광펜 획을 안전 영역 바깥에 흩는다(아이폰에서는 잘려도 되는 장식).
    strokes = [(-60, 120, 620, -9), (3260, 1380, 700, -9), (3350, 140, 520, -9), (120, 1420, 560, -9)]
    strokes_html = "".join(f'<div class="stroke" style="left:{x}px;top:{y}px;width:{w}px;'
                           f'transform:rotate({rot}deg)"></div>' for x, y, w, rot in strokes)
    return f"""
<div class="paper"></div>
<div class="glow" style="left:{l - 200}px;top:{t - 400}px;width:{sw + 400}px;height:{sh + 800}px;background:rgba(242,163,74,.16)"></div>
{strokes_html}
{phone(shot(lang, SHOT_LIBRARY), 300, 360, 640, -9)}
{phone(shot(lang, SHOT_DAILY), 2900, 360, 640, 9)}
<div class="text" style="left:{l}px;top:{t}px;width:{sw}px;height:{sh}px;align-items:center;text-align:center">
  <div class="eyebrow" style="font-size:76px">{eyebrow}</div>
  <div class="headline" data-max="200" data-min="110" style="margin-top:22px">{headline}</div>
</div>"""


def html_lang(lang):
    return {"zh-Hans": "zh-Hans", "zh-Hant": "zh-Hant"}.get(lang, lang)


def render(lang, kind):
    W, H, _ = SPEC[kind]
    body = search_html(lang) if kind == "search" else header_html(lang)
    page = (f'<!doctype html><html lang="{html_lang(lang)}"><head><meta charset="utf-8"><style>'
            f'{BASE_CSS % {"W": W, "H": H}}</style></head><body>{body}{FIT_JS}</body></html>')
    html_path = pathlib.Path(tempfile.gettempdir()) / f"underline-creative-{lang}-{kind}.html"
    html_path.write_text(page, encoding="utf-8")
    # 글이 끝까지 안 맞으면 그림을 만들지 않는다(잘린 글이 스토어에 올라가는 것보다 낫다).
    dom = subprocess.run(["nice", "-n", "19", CHROME, "--headless=new", "--dump-dom", f"--window-size={W},{H}",
                          "--force-device-scale-factor=1", "--disable-gpu", "--virtual-time-budget=3000",
                          html_path.as_uri()], capture_output=True, text=True, timeout=90).stdout
    if 'data-done="1"' not in dom:
        raise SystemExit(f"글 맞추기가 끝나지 않았다: {lang} {kind}")
    if 'data-overflow="1"' in dom:
        raise SystemExit(f"글이 안전 영역을 넘는다: {lang} {kind} - 문구를 줄일 것")
    out_dir = OUT / STORE.get(lang, lang)
    out_dir.mkdir(parents=True, exist_ok=True)
    out_png = out_dir / f"{kind}.png"
    # ⚠️ Chrome 은 가끔 아무것도 안 그리고 끝나거나 멈춘다. 세 번까지 한다.
    # ⚠️ 그리고 나서 끝내다가 멈춰 0 이 아닌 코드로 죽는 일도 있다(Teardown watchdog).
    #    그래서 끝 코드가 아니라 '새로 쓴 그림이 있는가' 로 판단한다.
    out_png.unlink(missing_ok=True)
    for _ in range(3):
        try:
            r = subprocess.run(["nice", "-n", "19", CHROME, "--headless=new", f"--screenshot={out_png}",
                                f"--window-size={W},{H}", "--force-device-scale-factor=1",
                                "--hide-scrollbars", "--disable-gpu", "--virtual-time-budget=3000",
                                "--allow-file-access-from-files", html_path.as_uri()],
                               capture_output=True, timeout=90)
        except subprocess.TimeoutExpired:
            if out_png.exists() and out_png.stat().st_size > 0:
                break
            continue
        if out_png.exists() and out_png.stat().st_size > 0:
            break
    else:
        raise SystemExit(f"Chrome 이 그리지 못했다: {out_png}")
    print(f"rendered {out_png}")
    time.sleep(2)   # 다른 일과 함께 도는 맥이라 Chrome 을 연달아 띄우지 않는다


if __name__ == "__main__":
    langs = sys.argv[1:] or list(SEARCH)
    for lang in langs:
        if lang not in SEARCH:
            raise SystemExit(f"모르는 언어: {lang} (아는 것: {', '.join(SEARCH)})")
        for kind in ("header", "search"):
            render(lang, kind)
