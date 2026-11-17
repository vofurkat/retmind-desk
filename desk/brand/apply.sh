#!/usr/bin/env bash
# Retmind Desk: превращает исходники RustDesk (тег RUSTDESK_TAG, с сабмодулем libs/hbb_common)
# в наш клиент: название, иконки, цвета, сервер и ключ по умолчанию, ссылки, URI-схема retmind-desk://.
#
#   git clone --branch 1.5.3 --recurse-submodules https://github.com/rustdesk/rustdesk rustdesk
#   RENDEZVOUS_SERVER=desk.retmind.pro RS_PUB_KEY=<ключ из deploy/desk/README.md> \
#     bash desk/brand/apply.sh rustdesk
#
# Переменные:
#   RENDEZVOUS_SERVER  адрес нашего сервера ID (hbbs), без порта. Обязателен (иначе — только с DESK_DRY=1)
#   RS_PUB_KEY         публичный ключ сервера (id_ed25519.pub). Обязателен так же
#   API_SERVER         необязательно: адрес API (у бесплатного сервера его нет — не задавать)
#   DESK_HELP_URL      «Помощь», «Сайт», «Конфиденциальность»      (по умолчанию https://support.retmind.pro)
#   DESK_DOWNLOAD_URL  «Скачать новую версию»                      (по умолчанию https://support.retmind.pro/desk)
#   DESK_SOURCE_URL    исходники нашего форка — обязательно по AGPL (по умолчанию github.com/retmind/retmind-desk)
#   DESK_DISPLAY_NAME  имя в окнах, трее, текстах                  (по умолчанию «Retmind Desk»)
#   DESK_ALLOW_MISSING=1  не падать, если какое-то место не нашлось (только для пробы на новом теге)
#
# Скрипт идемпотентный: повторный запуск ничего не ломает. Каждая замена проверяется: если исходное место
# не найдено и замены ещё нет — громкое предупреждение и код выхода 1 (значит, upstream изменил файл,
# смотри desk/README.md, раздел «Обновление на новый тег»).
set -euo pipefail

RUSTDESK_TAG=1.5.3
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SRC=${1:?укажите папку с исходниками RustDesk}
SRC=$(cd "$SRC" && pwd)
ICONS=$HERE/icons

[ -f "$SRC/Cargo.toml" ] && [ -d "$SRC/flutter" ] || { echo "Не похоже на исходники RustDesk: $SRC" >&2; exit 2; }
[ -f "$SRC/libs/hbb_common/src/config.rs" ] || {
  echo "Нет libs/hbb_common: клонируйте с --recurse-submodules (git submodule update --init)" >&2; exit 2; }
VER=$(sed -n 's/^version = "\(.*\)"/\1/p' "$SRC/Cargo.toml" | head -1)
[ "$VER" = "$RUSTDESK_TAG" ] || echo "!!! ВНИМАНИЕ: исходники версии $VER, скрипт проверен на $RUSTDESK_TAG" >&2

if [ -z "${RENDEZVOUS_SERVER:-}" ] || [ -z "${RS_PUB_KEY:-}" ]; then
  if [ "${DESK_DRY:-}" = 1 ]; then
    echo "!!! RENDEZVOUS_SERVER/RS_PUB_KEY не заданы: сервер по умолчанию НЕ меняется (DESK_DRY=1)" >&2
  else
    echo "Задайте RENDEZVOUS_SERVER и RS_PUB_KEY (или DESK_DRY=1 для пробы без сервера)" >&2; exit 2
  fi
fi

export SRC ICONS
export DESK_HELP_URL=${DESK_HELP_URL:-https://support.retmind.pro}
export DESK_DOWNLOAD_URL=${DESK_DOWNLOAD_URL:-https://support.retmind.pro/desk}
export DESK_SOURCE_URL=${DESK_SOURCE_URL:-https://github.com/retmind/retmind-desk}
export DESK_DISPLAY_NAME=${DESK_DISPLAY_NAME:-Retmind Desk}
export RENDEZVOUS_SERVER=${RENDEZVOUS_SERVER:-} RS_PUB_KEY=${RS_PUB_KEY:-} API_SERVER=${API_SERVER:-}

python3 -I - <<'PY'
import os, re, sys
from pathlib import Path

SRC = Path(os.environ["SRC"])
HELP = os.environ["DESK_HELP_URL"]
DOWNLOAD = os.environ["DESK_DOWNLOAD_URL"]
SOURCE = os.environ["DESK_SOURCE_URL"]
DISPLAY = os.environ["DESK_DISPLAY_NAME"]
SERVER = os.environ["RENDEZVOUS_SERVER"]
KEY = os.environ["RS_PUB_KEY"]
API = os.environ["API_SERVER"]

APP = "RetmindDesk"          # техническое имя: exe, служба Windows, папки, RetmindDesk.app (без пробелов —
                             # RustDesk подставляет его в команды sc/reg и пути, пробел там ломает установку)
SCHEME = "retmind-desk"      # URI-схема: retmind-desk://connection/new/<ID>
BUNDLE_ID = "pro.retmind.desk"
ACCENT = "0866FF"

missing = []
done = 0

def rep(rel, old, new, count=None, regex=False):
    """Заменить old на new в файле. count — сколько вхождений ждём (None — любое > 0)."""
    global done
    p = SRC / rel
    if not p.exists():
        missing.append(f"{rel}: файла нет")
        return
    s = p.read_text(encoding="utf-8")
    n = len(re.findall(old, s)) if regex else s.count(old)
    already = new in s
    if already and (regex or old in new):
        return  # уже заменено (новый текст содержит старый или совпадает с шаблоном)
    if n == 0:
        if already:
            return  # уже заменено прошлым запуском
        missing.append(f"{rel}: не найдено {old[:90]!r}")
        return
    if count is not None and n != count:
        missing.append(f"{rel}: ждали {count} вхождений {old[:60]!r}, нашли {n}")
        return
    s = re.sub(old, new, s) if regex else s.replace(old, new)
    p.write_text(s, encoding="utf-8")
    done += 1

# ---------- 1. Имя, сервер, ключ (libs/hbb_common/src/config.rs) ----------
cfg = "libs/hbb_common/src/config.rs"
rep(cfg, 'pub static ref APP_NAME: RwLock<String> = RwLock::new("RustDesk".to_owned());',
         f'pub static ref APP_NAME: RwLock<String> = RwLock::new("{APP}".to_owned());', 1)
if SERVER and KEY:
    # Официальная сборка раньше брала их из option_env!("RENDEZVOUS_SERVER"/"RS_PUB_KEY"); в 1.4–1.5
    # это обычные константы, их правят в исходнике (так и написано в FAQ про свою сборку с сервером)
    rep(cfg, r'pub const RENDEZVOUS_SERVERS: &\[&str\] = &\["[^"]*"\];',
        f'pub const RENDEZVOUS_SERVERS: &[&str] = &["{SERVER}"];', regex=True)
    rep(cfg, r'pub const RS_PUB_KEY: &str = "[^"]*";', f'pub const RS_PUB_KEY: &str = "{KEY}";', regex=True)
rep(cfg, 'pub const LINK_DOCS_HOME: &str = "https://rustdesk.com/docs/en/";',
         f'pub const LINK_DOCS_HOME: &str = "{HELP}";', 1)
# Настройки «зашитые» (BUILTIN) и по умолчанию: скрыть «Основано на RustDesk» на главном экране
# (упоминание RustDesk остаётся в «О программе»), включить автозапись исходящих сессий у оператора
builtin = '("hide-powered-by-me".to_owned(), "Y".to_owned())'
rep(cfg, 'pub static ref BUILTIN_SETTINGS: RwLock<HashMap<String, String>> = Default::default();',
         'pub static ref BUILTIN_SETTINGS: RwLock<HashMap<String, String>> = '
         f'RwLock::new(HashMap::from([{builtin}]));', 1)
rep(cfg, 'pub static ref DEFAULT_LOCAL_SETTINGS: RwLock<HashMap<String, String>> = Default::default();',
         'pub static ref DEFAULT_LOCAL_SETTINGS: RwLock<HashMap<String, String>> = '
         'RwLock::new(HashMap::from([("allow-auto-record-outgoing".to_owned(), "Y".to_owned())]));', 1)
if API:
    rep(cfg, 'pub static ref DEFAULT_SETTINGS: RwLock<HashMap<String, String>> = Default::default();',
             'pub static ref DEFAULT_SETTINGS: RwLock<HashMap<String, String>> = '
             f'RwLock::new(HashMap::from([("api-server".to_owned(), "{API}".to_owned())]));', 1)

# ---------- 2. URI-схема retmind-desk:// ----------
rep("src/common.rs", 'format!("{}://", get_app_name().to_lowercase())', f'"{SCHEME}://".to_owned()', 1)
# Windows (установка из exe): ключ HKCR\<схема>; ключ HKCR\.<имя> (файлы .retminddesk) не трогаем
rep("src/platform/windows.rs", r"HKEY_CLASSES_ROOT\\{ext}", rf"HKEY_CLASSES_ROOT\\{SCHEME}", 7)
# Windows (msi)
rep("res/msi/Package/Components/Regs.wxs", 'Key="$(var.ProductLower)"', f'Key="{SCHEME}"', 1)
rep("res/msi/Package/Components/Regs.wxs", 'Key="$(var.ProductLower)\\shell', f'Key="{SCHEME}\\shell', 3)
# macOS
plist = "flutter/macos/Runner/Info.plist"
rep(plist, "<string>com.carriez.rustdesk</string>", f"<string>{BUNDLE_ID}</string>", 1)
rep(plist, "<array>\n\t\t\t\t<string>rustdesk</string>", f"<array>\n\t\t\t\t<string>{SCHEME}</string>", 1)
rep(plist, "\t<key>CFBundleName</key>\n\t<string>$(PRODUCT_NAME)</string>\n",
           "\t<key>CFBundleName</key>\n\t<string>$(PRODUCT_NAME)</string>\n"
           f"\t<key>CFBundleDisplayName</key>\n\t<string>{DISPLAY}</string>\n", 1)

# ---------- 3. Отображаемое имя «Retmind Desk» (окна, трей, тексты) ----------
rep("src/flutter_ffi.rs", "pub fn main_get_app_name() -> String {\n    get_app_name()\n}",
    f'pub fn main_get_app_name() -> String {{\n    "{DISPLAY}".to_owned()\n}}', 1)
rep("src/flutter_ffi.rs", "pub fn main_get_app_name_sync() -> SyncReturn<String> {\n    SyncReturn(get_app_name())\n}",
    f'pub fn main_get_app_name_sync() -> SyncReturn<String> {{\n    SyncReturn("{DISPLAY}".to_owned())\n}}', 1)
# Windows ищет уже открытое окно по заголовку — заголовок теперь отображаемое имя
rep("src/flutter.rs", "let name = crate::platform::wide_string(&crate::get_app_name());",
    f'let name = crate::platform::wide_string("{DISPLAY}");', 1)
rep("src/core_main.rs", "&crate::platform::FLUTTER_RUNNER_WIN32_WINDOW_CLASS,\n            &crate::get_app_name(),",
    f'&crate::platform::FLUTTER_RUNNER_WIN32_WINDOW_CLASS,\n            "{DISPLAY}",', 1)
rep("flutter/windows/runner/main.cpp", 'std::wstring app_name = L"RustDesk";', f'std::wstring app_name = L"{DISPLAY}";', 1)
# Тексты интерфейса: translate() сам меняет «RustDesk» на имя приложения — пусть на отображаемое
rep("src/lang.rs", "let app_name = crate::get_app_name();\n                if !app_name.contains(\"RustDesk\")",
    f'let app_name = "{DISPLAY}".to_owned();\n                if !app_name.contains("RustDesk")', 1)
rep("src/tray.rs", '"{} {}",\n                crate::get_app_name(),', f'"{{}} {{}}",\n                "{DISPLAY}",', 1)
rep("src/tray.rs", '"{} - {}\\n{}",\n                crate::get_app_name(),', f'"{{}} - {{}}\\n{{}}",\n                "{DISPLAY}",', 1)
rep("flutter/lib/desktop/widgets/tabbar_widget.dart", '"RustDesk",\n                              style: TextStyle(fontSize: 13)',
    f'"{DISPLAY}",\n                              style: TextStyle(fontSize: 13)', 1)

# ---------- 4. Windows: exe, ресурсы версии ----------
rep("flutter/windows/CMakeLists.txt", 'set(BINARY_NAME "rustdesk")', f'set(BINARY_NAME "{APP}")', 1)
rc = "flutter/windows/runner/Runner.rc"
rep(rc, 'VALUE "CompanyName", "Purslane Tech Pte. Ltd."', 'VALUE "CompanyName", "Retmind"', 1)
rep(rc, 'VALUE "FileDescription", "RustDesk Remote Desktop"', f'VALUE "FileDescription", "{DISPLAY}"', 1)
rep(rc, 'VALUE "InternalName", "rustdesk"', f'VALUE "InternalName", "{APP}"', 1)
rep(rc, r'VALUE "LegalCopyright", "Copyright © \d{4} Purslane Tech Pte. Ltd. All rights reserved."',
    'VALUE "LegalCopyright", "Retmind. Based on RustDesk (c) Purslane Tech Pte. Ltd., AGPL-3.0"', regex=True)
rep(rc, 'VALUE "OriginalFilename", "rustdesk.exe"', f'VALUE "OriginalFilename", "{APP}.exe"', 1)
rep(rc, 'VALUE "ProductName", "RustDesk"', f'VALUE "ProductName", "{DISPLAY}"', 1)
rep("build.py", "-e ../../{flutter_build_dir_2}/rustdesk.exe", f"-e ../../{{flutter_build_dir_2}}/{APP}.exe", 1)

# ---------- 5. macOS: имя .app, bundle id ----------
xc = "flutter/macos/Runner/Configs/AppInfo.xcconfig"
rep(xc, "PRODUCT_NAME = RustDesk", f"PRODUCT_NAME = {APP}", 1)
rep(xc, "PRODUCT_BUNDLE_IDENTIFIER = com.carriez.flutterHbb", f"PRODUCT_BUNDLE_IDENTIFIER = {BUNDLE_ID}", 1)
rep(xc, r"PRODUCT_COPYRIGHT = .*", "PRODUCT_COPYRIGHT = Retmind. Based on RustDesk (c) Purslane Tech Pte. Ltd., AGPL-3.0",
    regex=True)
rep("flutter/macos/Runner.xcodeproj/project.pbxproj", "PRODUCT_BUNDLE_IDENTIFIER = com.carriez.rustdesk;",
    f"PRODUCT_BUNDLE_IDENTIFIER = {BUNDLE_ID};", 3)
rep("build.py", "./build/macos/Build/Products/Release/RustDesk.app/Contents/MacOS/')",
    f"./build/macos/Build/Products/Release/{APP}.app/Contents/MacOS/')", 1)
rep("Cargo.toml", '[package.metadata.bundle]\nname = "RustDesk"\nidentifier = "com.carriez.rustdesk"',
    f'[package.metadata.bundle]\nname = "{APP}"\nidentifier = "{BUNDLE_ID}"', 1)

# ---------- 6. Цвета (flutter/lib/common.dart, MyTheme) — docs/05-brand.md ----------
cd = "flutter/lib/common.dart"
rep(cd, "static const Color accent = Color(0xFF0071FF);", f"static const Color accent = Color(0xFF{ACCENT});", 1)
rep(cd, "static const Color accent50 = Color(0x770071FF);", f"static const Color accent50 = Color(0x77{ACCENT});", 1)
rep(cd, "static const Color accent80 = Color(0xAA0071FF);", f"static const Color accent80 = Color(0xAA{ACCENT});", 1)
rep(cd, "static const Color button = Color(0xFF2C8CFF);", f"static const Color button = Color(0xFF{ACCENT});", 1)
rep(cd, "static const Color idColor = Color(0xFF00B6F0);", f"static const Color idColor = Color(0xFF{ACCENT});", 1)
rep(cd, "static const Color grayBg = Color(0xFFEFEFF2);", "static const Color grayBg = Color(0xFFF0F2F5);", 1)
rep(cd, "static const Color canvasColor = Color(0xFF212121);", "static const Color canvasColor = Color(0xFF1C1C1D);", 1)
rep(cd, "primary: Colors.blue, secondary: accent, background: grayBg)",
        "primary: accent, secondary: accent, background: grayBg)", 1)
rep(cd, "scaffoldBackgroundColor: Color(0xFF18191E),", "scaffoldBackgroundColor: Color(0xFF1C1C1D),", 1)
rep(cd, "dialogBackgroundColor: Color(0xFF18191E),", "dialogBackgroundColor: Color(0xFF2E3033),", 1)
rep(cd, "Color(0xFF24252B)", "Color(0xFF252728)")            # карточки и поля тёмной темы
rep(cd, "    border: Color(0xFFCCCCCC),\n    border2: Color(0xFFBBBBBB),",
        "    border: Color(0xFFE2E4E8),\n    border2: Color(0xFFBBBBBB),", 1)
rep(cd, "    highlight: Color(0xFFE5E5E5),", "    highlight: Color(0xFFE4E6EB),", 1)
rep(cd, "    border: Color(0xFF555555),", "    border: Color(0xFF3A3B3D),", 1)
rep(cd, "    highlight: Color(0xFF3F3F3F),", "    highlight: Color(0xFF2B2D2F),", 1)
rep(cd, "launchUrl(Uri.parse('https://rustdesk.com'));", f"launchUrl(Uri.parse('{HELP}'));", 1)

# ---------- 7. Ссылки и «О программе» ----------
st = "flutter/lib/desktop/pages/desktop_setting_page.dart"
rep(st, "launchUrlString('https://rustdesk.com/privacy.html');", f"launchUrlString('{HELP}');", 1)
rep(st, "launchUrlString('https://rustdesk.com');", f"launchUrlString('{HELP}');", 1)
rep(st, "decoration: const BoxDecoration(color: Color(0xFF2c8cff)),",
        f"decoration: const BoxDecoration(color: Color(0xFF{ACCENT})),", 1)
# Единственное место с RustDesk: требование AGPL — назвать оригинал, лицензию и дать исходники
rep(st, "'Copyright © ${DateTime.now().toString().substring(0, 4)} Purslane Tech Pte. Ltd.\\n$license',",
    f"'{DISPLAY} — Retmind, {HELP.replace('https://', '')}\\n'\n"
    "                            'Основано на RustDesk © Purslane Tech Pte. Ltd., лицензия AGPL-3.0.\\n'\n"
    f"                            'Исходный код: {SOURCE}\\n$license',", 1)
rep(st, "translate('Slogan_tip'),", f"'{SOURCE}',", 1)
rep("flutter/lib/desktop/pages/install_page.dart", "'https://rustdesk.com/privacy.html'", f"'{HELP}'", 2)
rep("flutter/lib/desktop/pages/desktop_home_page.dart", "Uri.parse('https://rustdesk.com/download')",
    f"Uri.parse('{DOWNLOAD}')", 1)
rep("flutter/lib/desktop/pages/connection_page.dart", 'const url = "https://rustdesk.com/pricing";',
    f'const url = "{HELP}";', 1)

print(f"замен сделано: {done}")
if missing:
    print("\n!!! НЕ НАЙДЕНО (upstream изменил файлы — проверьте вручную):", file=sys.stderr)
    for m in missing:
        print("  - " + m, file=sys.stderr)
    if os.environ.get("DESK_ALLOW_MISSING") != "1":
        sys.exit(1)
PY

# ---------- 8. Иконки и логотип ----------
cp "$ICONS/icon.ico"                        "$SRC/res/icon.ico"
cp "$ICONS/icon.ico"                        "$SRC/flutter/windows/runner/resources/app_icon.ico"
cp "$ICONS/tray-icon.ico"                   "$SRC/res/tray-icon.ico"
cp "$ICONS/png/app-icon-1024.png"           "$SRC/res/icon.png"
cp "$ICONS/png/mac-icon-1024.png"           "$SRC/res/mac-icon.png"
cp "$ICONS/png/app-icon-32.png"             "$SRC/res/32x32.png"
cp "$ICONS/png/app-icon-64.png"             "$SRC/res/64x64.png"
cp "$ICONS/png/app-icon-128.png"            "$SRC/res/128x128.png"
cp "$ICONS/png/app-icon-256.png"            "$SRC/res/128x128@2x.png"
cp "$ICONS/tray/mac-tray-template-36.png"   "$SRC/res/mac-tray-dark-x2.png"   # шаблон: macOS красит сам
cp "$ICONS/tray/mac-tray-template-36.png"   "$SRC/res/mac-tray-light-x2.png"
cp "$ICONS/icon.svg"                        "$SRC/res/scalable.svg"
cp "$ICONS/icon.svg"                        "$SRC/flutter/assets/icon.svg"
cp "$ICONS/png/app-icon-256.png"            "$SRC/flutter/assets/icon.png"
cp "$ICONS/png/logo-light.png"              "$SRC/flutter/assets/logo.png"
cp "$ICONS/png/logo-light.png"              "$SRC/flutter/assets/logo_light.png"
cp "$ICONS/png/logo-dark.png"               "$SRC/flutter/assets/logo_dark.png"
cp "$ICONS/AppIcon.icns"                    "$SRC/flutter/macos/Runner/AppIcon.icns"

# ---------- 9. Что осталось с «RustDesk» в видимых строках (для глаза, не ошибка) ----------
echo "--- осталось \"RustDesk\" в строках интерфейса ПК (кроме комментариев):"
grep -rn "'[^']*RustDesk[^']*'\|\"[^\"]*RustDesk[^\"]*\"" "$SRC/flutter/lib/desktop" "$SRC/flutter/lib/common" 2>/dev/null \
  | grep -v '^\s*//' | grep -v '//.*RustDesk' | sed "s|$SRC/||" | head -20 || true
echo "Retmind Desk: готово ($SRC). Дальше — сборка, см. desk/README.md"
