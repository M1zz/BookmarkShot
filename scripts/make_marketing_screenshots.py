#!/usr/bin/env python3
"""App Store 마케팅 스크린샷: 시뮬레이터 원본 캡처 + 헤드라인 → HTML → 헤드리스 Chrome.

사용법: python3 scripts/make_marketing_screenshots.py [언어 ...]   (없으면 전부)

  원본  docs/screenshots/raw/<언어>/NN-….png         (iPhone 6.9" 시뮬레이터 캡처 1320x2868, 올라가지 않는다)
  제출  docs/screenshots/marketing/<스토어 로케일>/NN-….png   (1242x2688, DeployBar 가 그대로 올린다)

파일 이름 순서가 스토어에 보이는 순서다. 다음 릴리즈에는 원본만 다시 찍고 이 스크립트를 다시 돌린다.
"""
import subprocess, sys, pathlib, tempfile, time

ROOT = pathlib.Path(__file__).resolve().parent.parent
RAW = ROOT / "docs" / "screenshots" / "raw"
OUT = ROOT / "docs" / "screenshots" / "marketing"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
W, H = 1242, 2688   # 이 계정의 iPhone 제출 규격

# ── 앱마다 고치는 곳 ──────────────────────────────────────────────
# 앱 언어 → App Store 로케일 (스토어 폴더 이름)
STORE = {"ko": "ko", "en": "en", "en-GB": "en-GB", "zh-Hans": "zh-Hans", "zh-Hant": "zh-Hant", "ja": "ja", "ru": "ru", "es": "es", "de": "de", "fr": "fr", "it": "it", "pt-BR": "pt-BR", "th": "th", "vi": "vi", "cs": "cs", "da": "da", "el": "el", "fi": "fi"}
# 바탕 · 포인트 색 (헤더·검색 결과 그림과 맞춘다)
BG, ACCENT, INK, SUB = "#F4EEE0", "#C8741F", "#1A2942", "#6B6458"
# 언어 → [(원본 파일, 레이아웃, 헤드라인, 서브카피)]
SHOTS = {
    "ko": [
        ("01-highlight.png", "hero-bleed",  "형광펜 긋듯<br>손가락으로 슥", "그은 문장만 글자로 옮겨 담아요"),
        ("02-region.png",    "left-text",   "비스듬히 찍어도<br>반듯하게", "네 모서리만 맞추면 종이처럼 펴 줘요"),
        ("03-library.png",   "text-bottom", "표지 한 장으로 채우는 서재", "제목과 저자는 사진에서 읽어 와요"),
        ("04-quotes.png",    "flat-rotate", "모은 문장을<br>한곳에서", "책 제목과 메모로 바로 찾아요"),
        ("05-daily.png",     "dark",        "매일 다시 만나는<br>오늘의 문장", "위젯으로 늘 곁에, 카드로 공유까지"),
    ],
    "en": [
        ("01-highlight.png", "hero-bleed", "Swipe to highlight,<br>like a marker", "Only the lines you swipe become text"),
        ("02-region.png", "left-text", "Slanted photo?<br>Made flat", "Line up four corners and it’s flattened like paper"),
        ("03-library.png", "text-bottom", "A library built<br>from covers", "Title and author are read from the photo"),
        ("04-quotes.png", "flat-rotate", "Every quote you saved,<br>in one place", "Find them by book title or note"),
        ("05-daily.png", "dark", "A quote to meet<br>each day", "On your Home Screen, and shared as a card"),
    ],
    "en-GB": [
        ("01-highlight.png", "hero-bleed", "Swipe to highlight,<br>like a marker", "Only the lines you swipe become text"),
        ("02-region.png", "left-text", "Slanted photo?<br>Made flat", "Line up four corners and it’s flattened like paper"),
        ("03-library.png", "text-bottom", "A library built<br>from covers", "Title and author are read from the photo"),
        ("04-quotes.png", "flat-rotate", "Every quote you saved,<br>in one place", "Find them by book title or note"),
        ("05-daily.png", "dark", "A quote to meet<br>each day", "On your Home Screen, and shared as a card"),
    ],
    "zh-Hans": [
        ("01-highlight.png", "hero-bleed", "像荧光笔一样<br>指尖一划", "只把划过的句子变成文字"),
        ("02-region.png", "left-text", "斜着拍也能<br>端端正正", "对准四个角，就像纸张一样展平"),
        ("03-library.png", "text-bottom", "拍张封面<br>就有了书架", "书名和作者从照片里自动读取"),
        ("04-quotes.png", "flat-rotate", "收藏的句子<br>集中一处", "按书名或笔记，立刻找到"),
        ("05-daily.png", "dark", "每天重温<br>今日一句", "小组件常伴左右，还能做成卡片分享"),
    ],
    "zh-Hant": [
        ("01-highlight.png", "hero-bleed", "像螢光筆一樣<br>指尖一劃", "只把劃過的句子變成文字"),
        ("02-region.png", "left-text", "斜著拍也能<br>端端正正", "對齊四個角，就像紙張一樣攤平"),
        ("03-library.png", "text-bottom", "拍張封面<br>就有了書櫃", "書名和作者從照片中自動讀取"),
        ("04-quotes.png", "flat-rotate", "收藏的句子<br>集中一處", "依書名或筆記，馬上找到"),
        ("05-daily.png", "dark", "每天重溫<br>今日一句", "小工具常伴左右，還能做成卡片分享"),
    ],
    "ja": [
        ("01-highlight.png", "hero-bleed", "蛍光ペンを引くように<br>指でスッとなぞる", "なぞった文だけが文字になります"),
        ("02-region.png", "left-text", "斜めに撮っても<br>まっすぐに", "四隅を合わせれば紙のように整います"),
        ("03-library.png", "text-bottom", "表紙1枚で<br>広がる本棚", "タイトルと著者は写真から読み取ります"),
        ("04-quotes.png", "flat-rotate", "集めた一文を<br>ひとつの場所に", "本のタイトルやメモですぐ探せます"),
        ("05-daily.png", "dark", "毎日出会う<br>今日の一文", "ウィジェットでそばに、カードで共有も"),
    ],
    "ru": [
        ("01-highlight.png", "hero-bleed", "Проведите пальцем,<br>как маркером", "В текст превратятся только выбранные строки"),
        ("02-region.png", "left-text", "Снимок под углом?<br>Выровняем", "Совместите четыре угла — и страница как лист бумаги"),
        ("03-library.png", "text-bottom", "Библиотека<br>из обложек", "Название и автор считываются с фото"),
        ("04-quotes.png", "flat-rotate", "Все цитаты<br>в одном месте", "Ищите по названию книги или заметке"),
        ("05-daily.png", "dark", "Цитата дня<br>каждый день", "Виджет всегда рядом, а ещё — карточка для друзей"),
    ],
    "es": [
        ("01-highlight.png", "hero-bleed", "Desliza el dedo<br>como un marcador", "Solo las frases que trazas pasan a texto"),
        ("02-region.png", "left-text", "¿Foto torcida?<br>Queda recta", "Ajusta las cuatro esquinas y se endereza como el papel"),
        ("03-library.png", "text-bottom", "Una biblioteca<br>hecha de portadas", "El título y el autor se leen de la foto"),
        ("04-quotes.png", "flat-rotate", "Todas tus citas<br>en un solo lugar", "Búscalas por título del libro o por nota"),
        ("05-daily.png", "dark", "Una cita<br>para cada día", "Un widget siempre a mano y tarjetas para compartir"),
    ],
    "de": [
        ("01-highlight.png", "hero-bleed", "Wische wie mit<br>einem Textmarker", "Nur die markierten Sätze werden zu Text"),
        ("02-region.png", "left-text", "Schräges Foto?<br>Wird gerade", "Vier Ecken ausrichten – und es liegt flach wie Papier"),
        ("03-library.png", "text-bottom", "Eine Bibliothek<br>aus Covern", "Titel und Autor werden aus dem Foto gelesen"),
        ("04-quotes.png", "flat-rotate", "Alle Zitate<br>an einem Ort", "Finde sie über Buchtitel oder Notiz"),
        ("05-daily.png", "dark", "Jeden Tag ein<br>Zitat zum Wiedersehen", "Als Widget immer dabei, als Karte teilbar"),
    ],
    "fr": [
        ("01-highlight.png", "hero-bleed", "Glissez le doigt<br>comme un surligneur", "Seules les phrases tracées deviennent du texte"),
        ("02-region.png", "left-text", "Photo de biais ?<br>On redresse", "Placez les quatre coins : la page est à plat comme du papier"),
        ("03-library.png", "text-bottom", "Une bibliothèque<br>faite de couvertures", "Titre et auteur sont lus depuis la photo"),
        ("04-quotes.png", "flat-rotate", "Toutes vos citations<br>au même endroit", "Retrouvez-les par titre ou par note"),
        ("05-daily.png", "dark", "Une citation<br>chaque jour", "Un widget toujours là, une carte à partager"),
    ],
    "it": [
        ("01-highlight.png", "hero-bleed", "Scorri il dito<br>come un evidenziatore", "Solo le frasi che segni diventano testo"),
        ("02-region.png", "left-text", "Foto storta?<br>Si raddrizza", "Allinea i quattro angoli: la pagina torna piana come la carta"),
        ("03-library.png", "text-bottom", "Una libreria<br>fatta di copertine", "Titolo e autore si leggono dalla foto"),
        ("04-quotes.png", "flat-rotate", "Tutte le citazioni<br>in un solo posto", "Trovale per titolo del libro o per nota"),
        ("05-daily.png", "dark", "Una citazione<br>per ogni giorno", "Un widget sempre a portata, una cartolina da condividere"),
    ],
    "pt-BR": [
        ("01-highlight.png", "hero-bleed", "Deslize o dedo<br>como um marca-texto", "Só as frases riscadas viram texto"),
        ("02-region.png", "left-text", "Foto torta?<br>Fica reta", "Alinhe os quatro cantos e a página fica plana como papel"),
        ("03-library.png", "text-bottom", "Uma biblioteca<br>feita de capas", "Título e autor são lidos da foto"),
        ("04-quotes.png", "flat-rotate", "Todos os trechos<br>num só lugar", "Encontre pelo título do livro ou pela nota"),
        ("05-daily.png", "dark", "Um trecho<br>para cada dia", "Widget sempre à mão e cartão para compartilhar"),
    ],
    "th": [
        ("01-highlight.png", "hero-bleed", "ลากนิ้วเน้นข้อความ<br>เหมือนปากกาไฮไลต์", "เฉพาะประโยคที่ลากเท่านั้นที่กลายเป็นข้อความ"),
        ("02-region.png", "left-text", "ถ่ายเอียงก็ไม่เป็นไร<br>ปรับให้ตรงเอง", "จัดมุมทั้งสี่ให้ตรง หน้ากระดาษก็เรียบเหมือนจริง"),
        ("03-library.png", "text-bottom", "แค่ถ่ายปกเล่มเดียว<br>ก็ได้ชั้นหนังสือ", "ชื่อเรื่องและผู้แต่งอ่านจากรูปให้เอง"),
        ("04-quotes.png", "flat-rotate", "ประโยคที่เก็บไว้<br>รวมอยู่ที่เดียว", "ค้นหาจากชื่อหนังสือหรือบันทึกได้ทันที"),
        ("05-daily.png", "dark", "พบประโยคเด็ด<br>ทุกวัน", "มีวิดเจ็ตติดตัว และแชร์เป็นการ์ดได้"),
    ],
    "vi": [
        ("01-highlight.png", "hero-bleed", "Lướt ngón tay<br>như bút dạ quang", "Chỉ những câu bạn lướt qua mới thành chữ"),
        ("02-region.png", "left-text", "Chụp nghiêng<br>vẫn ngay ngắn", "Căn bốn góc là trang sách phẳng như giấy"),
        ("03-library.png", "text-bottom", "Tủ sách làm từ<br>những tấm bìa", "Tên sách và tác giả được đọc từ ảnh"),
        ("04-quotes.png", "flat-rotate", "Mọi câu đã lưu<br>ở một nơi", "Tìm theo tên sách hoặc ghi chú"),
        ("05-daily.png", "dark", "Mỗi ngày gặp lại<br>một câu hay", "Widget luôn bên cạnh, thẻ để chia sẻ"),
    ],
    "cs": [
        ("01-highlight.png", "hero-bleed", "Přejeďte prstem<br>jako zvýrazňovačem", "Na text se převedou jen označené věty"),
        ("02-region.png", "left-text", "Šikmá fotka?<br>Narovná se", "Srovnejte čtyři rohy a stránka je rovná jako papír"),
        ("03-library.png", "text-bottom", "Knihovna<br>z obálek", "Název a autor se přečtou z fotky"),
        ("04-quotes.png", "flat-rotate", "Všechny citáty<br>na jednom místě", "Najdete je podle názvu knihy nebo poznámky"),
        ("05-daily.png", "dark", "Citát na<br>každý den", "Widget máte po ruce, kartu můžete sdílet"),
    ],
    "da": [
        ("01-highlight.png", "hero-bleed", "Stryg med fingeren<br>som med en tusch", "Kun de sætninger, du stryger, bliver til tekst"),
        ("02-region.png", "left-text", "Skævt billede?<br>Det rettes ud", "Placér de fire hjørner, så ligger siden fladt som papir"),
        ("03-library.png", "text-bottom", "Et bibliotek<br>bygget af omslag", "Titel og forfatter læses fra billedet"),
        ("04-quotes.png", "flat-rotate", "Alle citater<br>ét sted", "Find dem via bogtitel eller note"),
        ("05-daily.png", "dark", "Et citat<br>hver dag", "Widget altid ved hånden og kort til deling"),
    ],
    "el": [
        ("01-highlight.png", "hero-bleed", "Σύρε το δάχτυλο<br>σαν μαρκαδόρο", "Μόνο οι προτάσεις που περνάς γίνονται κείμενο"),
        ("02-region.png", "left-text", "Λοξή φωτογραφία;<br>Ισιώνει", "Ταίριαξε τις τέσσερις γωνίες και η σελίδα γίνεται επίπεδη σαν χαρτί"),
        ("03-library.png", "text-bottom", "Μια βιβλιοθήκη<br>από εξώφυλλα", "Ο τίτλος και ο συγγραφέας διαβάζονται από τη φωτογραφία"),
        ("04-quotes.png", "flat-rotate", "Όλα τα αποσπάσματα<br>σε ένα μέρος", "Βρες τα με τίτλο βιβλίου ή σημείωση"),
        ("05-daily.png", "dark", "Ένα απόσπασμα<br>για κάθε μέρα", "Widget πάντα κοντά σου και κάρτα για κοινοποίηση"),
    ],
    "fi": [
        ("01-highlight.png", "hero-bleed", "Vedä sormella<br>kuin korostuskynällä", "Vain vetämäsi lauseet muuttuvat tekstiksi"),
        ("02-region.png", "left-text", "Vino kuva?<br>Se oikenee", "Sovita neljä kulmaa, ja sivu on tasainen kuin paperi"),
        ("03-library.png", "text-bottom", "Kirjasto<br>kansista koottuna", "Nimi ja kirjailija luetaan kuvasta"),
        ("04-quotes.png", "flat-rotate", "Kaikki lainaukset<br>yhdessä paikassa", "Löydä ne kirjan nimellä tai muistiinpanolla"),
        ("05-daily.png", "dark", "Lainaus<br>joka päivälle", "Widget aina käsillä ja kortti jaettavaksi"),
    ],
}
# ─────────────────────────────────────────────────────────────────

BASE_CSS = f"""
* {{ margin:0; padding:0; box-sizing:border-box; }}
html,body {{ width:{W}px; height:{H}px; overflow:hidden; }}
body {{ background:{BG}; position:relative;
  font-family:-apple-system, "SF Pro Display", "Apple SD Gothic Neo", "Hiragino Sans", "PingFang SC", sans-serif; }}
.headline {{ font-size:96px; font-weight:800; color:{INK}; letter-spacing:-0.03em; line-height:1.18; }}
.sub {{ font-size:48px; font-weight:500; color:{SUB}; letter-spacing:-0.01em; line-height:1.35; }}
:lang(ko) .headline, :lang(ko) .sub {{ word-break:keep-all; }}
.phone {{ background:#17171a; border-radius:112px; border:3px solid #3a3a3e; padding:24px;
  box-shadow: 50px 80px 120px rgba(20,40,90,.25), 16px 26px 46px rgba(0,0,0,.16); }}
.phone img {{ width:100%; display:block; border-radius:90px; }}
.dot {{ display:inline-block; width:22px; height:22px; border-radius:50%; background:{ACCENT}; margin-bottom:46px; }}
"""

LAYOUTS = {
    "hero-bleed": """
.text { text-align:center; padding:250px 80px 0; }
.sub { margin-top:44px; }
.wrap { display:flex; justify-content:center; margin-top:120px; }
.phone { width:960px; }
""",
    "left-text": """
.text { text-align:left; padding:260px 100px 0 110px; }
.sub { margin-top:44px; }
.wrap { perspective:2600px; perspective-origin:30% 30%; position:absolute; left:290px; top:930px; }
.phone { width:820px; transform:rotateY(16deg) rotateX(2deg); }
""",
    "text-bottom": """
.wrap { perspective:2800px; perspective-origin:50% 40%; display:flex; justify-content:center; margin-top:150px; }
.phone { width:840px; transform:rotateY(-10deg) rotateX(2deg); }
.text { text-align:center; padding:100px 80px 0; }
.sub { margin-top:40px; }
""",
    "flat-rotate": """
.text { text-align:center; padding:240px 80px 0; }
.sub { margin-top:44px; }
.wrap { position:absolute; left:120px; top:950px; }
.phone { width:960px; transform:rotate(-6deg); }
""",
    "dark": f"""
body {{ background:#131316; }}
.headline {{ color:#f5f5f7; }} .sub {{ color:#8a8a90; }}
.text {{ text-align:center; padding:250px 80px 0; }}
.sub {{ margin-top:44px; }}
.wrap {{ display:flex; justify-content:center; margin-top:120px; }}
.phone {{ width:900px; border-color:#48484e;
  box-shadow: 0 0 160px rgba(80,140,255,.22), 40px 70px 110px rgba(0,0,0,.55); }}
""",
}

TEXT = '<div class="text"><div class="dot"></div><div class="headline">{headline}</div><div class="sub">{sub}</div></div>'
PHONE = '<div class="wrap"><div class="phone"><img src="{img}"></div></div>'
HTML = '<!doctype html><html lang="{lang}"><head><meta charset="utf-8"><style>{css}</style></head><body>{body}</body></html>'


def chrome_shot(html, png, tmp):
    """헤드리스 Chrome 으로 한 장 그린다.

    ⚠️ Chrome 은 그림을 다 쓰고도 끝나지 않고 멈추는 일이 잦다(여러 개가 동시에 돌 때 특히).
       그래서 끝나기를 기다리지 않고, 파일이 생겨 크기가 멈추면 프로세스를 닫는다.
    """
    png.unlink(missing_ok=True)
    proc = subprocess.Popen([CHROME, "--headless=new", f"--user-data-dir={tmp}/chrome", "--no-first-run",
                             "--disable-component-update", "--no-default-browser-check", "--disable-extensions",
                             f"--screenshot={png}", f"--window-size={W},{H}", "--force-device-scale-factor=1",
                             "--hide-scrollbars", "--allow-file-access-from-files", html.as_uri()],
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    last, deadline = -1, time.time() + 180
    try:
        while time.time() < deadline:
            time.sleep(1)
            size = png.stat().st_size if png.exists() else -1
            if size > 10000 and size == last:
                return True
            last = size
            if proc.poll() is not None and size <= 0:
                return False
        return False
    finally:
        if proc.poll() is None:
            proc.kill()
        proc.wait()
        # 남은 도우미 프로세스도 이 프로필 것만 골라 닫는다
        subprocess.run(["pkill", "-f", f"{tmp}/chrome"], capture_output=True)


def render(lang):
    out_dir = OUT / STORE[lang]
    out_dir.mkdir(parents=True, exist_ok=True)
    for old in out_dir.glob("*.png"):
        old.unlink()
    with tempfile.TemporaryDirectory() as tmp:
        for fname, layout, headline, sub in SHOTS[lang]:
            src = RAW / lang / fname
            assert src.exists(), f"원본이 없다: {src}"
            text = TEXT.format(headline=headline, sub=sub)
            phone = PHONE.format(img=src.as_uri())
            body = phone + text if layout == "text-bottom" else text + phone
            html = pathlib.Path(tmp) / f"{lang}-{fname}.html"
            html.write_text(HTML.format(lang=lang, css=BASE_CSS + LAYOUTS[layout], body=body), encoding="utf-8")
            png = out_dir / fname
            if not any(chrome_shot(html, png, tmp) for _ in range(3)):
                raise SystemExit(f"그리지 못했다: {png}")
            print("rendered", png.relative_to(ROOT))


if __name__ == "__main__":
    for lang in (sys.argv[1:] or list(SHOTS)):
        render(lang)
