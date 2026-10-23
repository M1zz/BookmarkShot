#!/usr/bin/env python3
"""App Store 원본 스크린샷(언어마다 그 언어 화면)을 시뮬레이터에서 찍는다.

사용법: python3 scripts/capture_screenshots.py <시뮬레이터 UDID> [언어 ...]   (없으면 seed 가 있는 언어 전부)

  데모 서재  scripts/screenshot_seed/<언어>.json   (그 언어 고전의 책 · 문장 · 찍을 페이지)
  찍은 결과  docs/screenshots/raw/<언어>/01-highlight.png … 05-daily.png   (그다음 make_marketing_screenshots.py)

앱은 DEBUG 빌드의 스크린샷 데모 모드(BookmarkShot/Support/ScreenshotMode.swift)로 띄운다 —
메모리 저장소라 시뮬레이터의 실제 데이터 · iCloud 를 건드리지 않는다. 기기 언어는 재부팅 없이
-AppleLanguages / -AppleLocale 실행 인자로 바꾼다. 앱은 먼저 그 시뮬레이터에 설치해 둔다.
"""
import json, os, pathlib, shutil, subprocess, sys, tempfile, time

ROOT = pathlib.Path(__file__).resolve().parent.parent
SEED = ROOT / "scripts" / "screenshot_seed"
RAW = ROOT / "docs" / "screenshots" / "raw"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
BUNDLE = "com.leeo.bookmarkshot"

# 언어 → 기기 지역 (날짜 표기: en-GB 는 23 Oct, en 은 Oct 23)
REGION = {"ko": "ko_KR", "en": "en_US", "en-GB": "en_GB", "zh-Hans": "zh_CN", "zh-Hant": "zh_TW", "ja": "ja_JP",
          "ru": "ru_RU", "es": "es_ES", "de": "de_DE", "fr": "fr_FR", "it": "it_IT", "pt-BR": "pt_BR", "th": "th_TH",
          "vi": "vi_VN", "cs": "cs_CZ", "da": "da_DK", "el": "el_GR", "fi": "fi_FI", "id": "id_ID", "nb": "nb_NO",
          "nl": "nl_NL", "pl": "pl_PL", "sv": "sv_SE", "tr": "tr_TR"}
# 찍는 화면: (파일 이름, 장면, 화면이 다 그려질 때까지 기다리는 초)
SCENES = [("01-highlight.png", "highlight", 9), ("02-region.png", "region", 6),
          ("03-library.png", "library", 5), ("04-quotes.png", "quotes", 5), ("05-daily.png", "daily", 5)]

# 페이지 사진: 어두운 책상 위에 살짝 비스듬히 놓인 책장. 글꼴은 그 언어의 명조/세리프.
SERIF = {"ja": '"Hiragino Mincho ProN"', "zh-Hans": '"Songti SC"', "zh-Hant": '"Songti TC"', "th": '"Thonburi"'}
PAGE_HTML = """<!doctype html><html lang="{lang}"><head><meta charset="utf-8"><style>
* {{ margin:0; padding:0; box-sizing:border-box; }}
html,body {{ width:1500px; height:2000px; overflow:hidden; background:#1d1b19; }}
.page {{ position:absolute; left:110px; top:100px; width:1280px; height:1800px; background:#f8f2e4;
  transform:rotate(-1.6deg); box-shadow: 0 30px 60px rgba(0,0,0,.55), inset 0 0 80px rgba(120,90,40,.10);
  padding:130px 120px 0; font-family:{font}, "Iowan Old Style", Georgia, "Times New Roman", serif; color:#2b2620; }}
.head {{ text-align:center; font-size:30px; letter-spacing:.12em; color:#a39885; margin-bottom:70px; }}
.text {{ font-size:{size}px; line-height:1.78; text-align:justify; hyphens:none; word-break:{wb}; }}
.num {{ position:absolute; left:0; right:0; bottom:60px; text-align:center; font-size:40px; color:#6f6656; }}
</style></head><body><div class="page"><div class="head">{head}</div><div class="text">{text}</div>
<div class="num">{num}</div></div></body></html>"""


def sh(*args, timeout=120, check=True):
    return subprocess.run(["perl", "-e", f"alarm {timeout}; exec @ARGV", *args], capture_output=True, text=True, check=check)


def render_page(lang, seed, out):
    page = seed["page"]
    cjk = lang in ("ja", "zh-Hans", "zh-Hant", "th")
    html = PAGE_HTML.format(lang=lang, font=SERIF.get(lang, '"Iowan Old Style"'), size=50 if cjk else 52,
                            wb="normal" if lang != "th" else "normal", head=page["running_head"],
                            text=page["text"], num=page.get("page", ""))
    with tempfile.TemporaryDirectory() as tmp:
        src = pathlib.Path(tmp) / "page.html"
        src.write_text(html, encoding="utf-8")
        sh("nice", "-n", "19", CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars",
           "--force-device-scale-factor=1", "--window-size=1500,2000", f"--screenshot={out}", src.as_uri(), timeout=90)
    time.sleep(2)


def main():
    udid, langs = sys.argv[1], sys.argv[2:] or sorted(p.stem for p in SEED.glob("*.json"))
    sh("xcrun", "simctl", "status_bar", udid, "override", "--time", "9:41", "--batteryState", "charged",
       "--batteryLevel", "100", "--cellularBars", "4", "--wifiBars", "3", check=False)
    data = pathlib.Path(sh("xcrun", "simctl", "get_app_container", udid, BUNDLE, "data").stdout.strip())
    for lang in langs:
        seed = json.loads((SEED / f"{lang}.json").read_text(encoding="utf-8"))
        box = data / "Documents" / "ScreenshotSeed" / lang
        box.mkdir(parents=True, exist_ok=True)
        (box / "seed.json").write_text(json.dumps(seed, ensure_ascii=False), encoding="utf-8")
        render_page(lang, seed, box / "page_photo.png")
        out = RAW / lang
        out.mkdir(parents=True, exist_ok=True)
        language = lang if lang != "en-GB" else "en-GB"
        only = os.environ.get("SCENES")   # 예: SCENES=highlight,region 이면 그 장면만 다시 찍는다
        for name, scene, wait in SCENES:
            if only and scene not in only.split(","):
                continue
            sh("xcrun", "simctl", "terminate", udid, BUNDLE, check=False)
            time.sleep(1)
            sh("xcrun", "simctl", "launch", udid, BUNDLE, "-AppleLanguages", f"({language})",
               "-AppleLocale", REGION[lang], "-ScreenshotSeed", str(box / "seed.json"), "-ScreenshotScene", scene)
            time.sleep(wait)
            # ⚠️ simctl io screenshot 은 그림을 다 쓰고도 한참 끝나지 않는 일이 있다(맥이 바쁠 때).
            #    그래서 파일이 다 써지면 기다리지 않고 끝낸다. 세 번까지 찍는다.
            target = out / name
            for attempt in range(3):
                target.unlink(missing_ok=True)
                proc = subprocess.Popen(["xcrun", "simctl", "io", udid, "screenshot", "--type=png", str(target)],
                                        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                last, deadline = -1, time.time() + 45
                while time.time() < deadline:
                    if proc.poll() is not None and target.exists():
                        break
                    size = target.stat().st_size if target.exists() else 0
                    if size > 0 and size == last:
                        break
                    last = size
                    time.sleep(1.5)
                if proc.poll() is None:
                    proc.kill()
                if target.exists() and target.stat().st_size > 0:
                    break
                time.sleep(3)
            else:
                print(f"  ❌ {lang}/{name} 를 찍지 못했다", flush=True)
                continue
            print(f"  {lang}/{name}", flush=True)
        sh("xcrun", "simctl", "terminate", udid, BUNDLE, check=False)


if __name__ == "__main__":
    main()
