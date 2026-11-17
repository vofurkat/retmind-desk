# Retmind Desk — наш клиент удалённого подключения (на основе RustDesk)

Решение заказчика 17.11.2026: для удалённого управления кассами берём открытый RustDesk (AGPL-3.0) со своим
сервером и делаем его своим: название «Retmind Desk», наш знак, наши цвета, наш сервер и ключ зашиты в
программу, ссылки ведут на support.retmind.pro, ссылка `retmind-desk://` открывает подключение из Retmind
Support. Имя RustDesk остаётся только в «О программе» — этого требует лицензия.

| Что | Где |
|---|---|
| Сервер (hbbs + hbbr) | `deploy/docker-compose.yml`, инструкция — [deploy/desk/README.md](../deploy/desk/README.md) |
| Знак и иконки | `desk/brand/src/*.svg` → `desk/brand/make_icons.sh` → `desk/brand/icons/` (готовые, лежат в git) |
| Замены в исходниках RustDesk | `desk/brand/apply.sh` |
| Сборка Windows/macOS | `desk/ci/desk-build.yml` (GitHub Actions в нашем форке) |
| Кнопка «Подключиться», журнал сессий | Retmind Support: касса → поле «ID Retmind Desk», `/api/desk/sessions`, страница /desk |
| Ссылки «Скачать» на странице /desk | `DESK_WINDOWS_URL`, `DESK_MACOS_URL`, `DESK_DOWNLOADS_READY=true` в `deploy/.env` (после первой сборки) |

Закреплённые версии (17.11.2026): клиент — тег **1.5.3** (rustdesk/rustdesk, 09.11.2026, сабмодуль
`libs/hbb_common` на `fae47e0`), сервер — **1.1.16** (`rustdesk/rustdesk-server:1.1.16`). Клиент 1.5.x взят,
а не последний 1.4.9: старая ветка исправлений уже не получает, а программа удалённого доступа смотрит в
интернет. Если 1.5.3 в пилоте поведёт себя плохо — тот же apply.sh проверяет каждое место и подскажет, что
поправить для 1.4.9.

## Что нужно от компании

1. **Репозиторий на GitHub** — открытый форк `rustdesk/rustdesk` в аккаунте заказчика: `github.com/vofurkat/retmind-desk`
   (решение 17.11.2026). По AGPL-3.0 тот, кто раздаёт изменённую программу, обязан отдавать её исходники
   получателям; открытый форк + ссылка в «О программе» это закрывает. Сборки бесплатны (публичный репозиторий —
   бесплатные минуты GitHub Actions, в том числе macOS). Доступ сервера к форку — ключ развёртывания
   `/root/.ssh/retmind_desk_github` (только этот репозиторий; в `/root/.ssh/config` — `Host github-retmind-desk`).
2. **Сертификат подписи кода для Windows** на юрлицо (OV или EV). Без него Windows SmartScreen пишет «Windows
   защитила ваш компьютер», а антивирусы чаще ругаются на программу удалённого доступа. Важно: с 2023 года
   ключ сертификата выдают только на защищённом носителе или в облаке (не файлом .pfx). Варианты: облачная
   подпись УЦ (DigiCert KeyLocker, SSL.com eSigner, Certum SimplySign) или Azure Trusted Signing — тогда шаг
   подписи в `desk-build.yml` меняется на их действие GitHub (вместо signtool с .pfx). Срок выпуска — от
   нескольких дней до 2 недель (проверка компании).
3. **Apple Developer Program на организацию** ($99 в год) — сертификат «Developer ID Application» и
   нотаризация. Без этого macOS не даст открыть программу («не удалось проверить разработчика»), а обходить это
   у каждого сотрудника — плохо. Нужен D-U-N-S номер компании (бесплатно, 1–2 недели).
4. **Адрес сервера**: домен `desk.retmind.pro` → IP нашего VPS, открыть порты (см. deploy/desk/README.md).
   **Публичный ключ** сервера — после первого запуска (там же). Ключ и адрес зашиваются в клиент: менять их —
   значит пересобирать и переустанавливать.
5. Список версий Windows на кассах: клиент на Flutter рассчитан на Windows 10/11; Windows 7/8 не
   гарантируется (проверить на пилоте на самой старой кассе).

## Шаги сборки

1. Заказчик: Fork `rustdesk/rustdesk` с именем `retmind-desk` → Settings → Deploy keys → ключ сервера
   (`/root/.ssh/retmind_desk_github.pub`) с «Allow write access» → вкладка Actions → включить workflows.
   Дальше сервер: ветка `retmind` от тега `1.5.3` (`git push github-retmind-desk:vofurkat/retmind-desk.git`).
2. В форк положить из Retmind Support папку `desk/brand/` (целиком, вместе с `icons/`) и
   `desk/ci/desk-build.yml` → `.github/workflows/desk-build.yml`. Лишние официальные workflow можно отключить
   (Actions → Disable), чтобы не тратить минуты.
3. В настройках форка (Settings → Secrets and variables → Actions):
   - переменные — не обязательно: по умолчанию `desk.retmind.pro`, ключ нашего сервера и адрес самого форка;
   - секреты подписи (когда будут): `WINDOWS_PFX_BASE64`, `WINDOWS_PFX_PASSWORD`, `MACOS_P12_BASE64`,
     `MACOS_P12_PASSWORD`, `MACOS_CODESIGN_IDENTITY`, `APPLE_ID`, `APPLE_TEAM_ID`, `APPLE_APP_PASSWORD`.
4. Actions → «Retmind Desk build» → Run workflow (или тег `desk-1.5.3-1`). Сборка сама делает `apply.sh`,
   собирает Windows x64 (`retmind-desk-1.5.3-x86_64.exe` и `.msi`) и macOS x64 и arm64
   (`retmind-desk-1.5.3-x86_64.dmg`, `-aarch64.dmg`), подписывает, если есть секреты, и выкладывает
   артефакты. Без секретов артефакты помечены `-unsigned` — для проверки на своих машинах.
5. Тег `desk-*` после сборки выпускает Release со всеми файлами, в том числе с именами без версии
   (`retmind-desk-x86_64.exe`, `retmind-desk-aarch64.dmg` …) — постоянные ссылки
   `https://github.com/vofurkat/retmind-desk/releases/latest/download/<файл>`. Их или копии на нашем сервере
   вписать в `DESK_WINDOWS_URL` / `DESK_MACOS_URL` и включить `DESK_DOWNLOADS_READY=true`.

Чтобы собрать локально или посмотреть изменения:

```sh
git clone --branch 1.5.3 --recurse-submodules https://github.com/rustdesk/rustdesk rustdesk
RENDEZVOUS_SERVER=desk.retmind.pro RS_PUB_KEY=<ключ> bash desk/brand/apply.sh rustdesk
cd rustdesk && git diff --stat && git -C libs/hbb_common diff
```

Дальше — сборка по их инструкции (Windows: Visual Studio 2022, vcpkg, Flutter 3.24.5, Rust 1.75; macOS: Xcode,
Flutter 3.24.5 / 3.44.9 для arm64, Rust 1.81) — проще в CI.

**Время.** Первая сборка в CI — около 1,5–2 часов (vcpkg собирает ffmpeg и др.; дальше кэш), следующие —
40–60 минут. Работа человека: форк и настройка — полдня; проверка на пилоте — 1–2 недели; подписи — сроки
УЦ и Apple (выше). Обновление на новый тег RustDesk — 1–3 часа, если apply.sh не нашёл какие-то места.

## Что меняет apply.sh (проверено на 1.5.3: 60 замен, повторный запуск ничего не меняет)

| Что | Где в исходниках RustDesk |
|---|---|
| Техническое имя `RetmindDesk` (exe, служба Windows, папки, `RetmindDesk.app`) | `libs/hbb_common/src/config.rs`: `APP_NAME` |
| Сервер и публичный ключ по умолчанию | там же: `RENDEZVOUS_SERVERS`, `RS_PUB_KEY` (в 1.4–1.5 это константы; раньше официальная сборка брала их из `option_env!("RENDEZVOUS_SERVER")`/`RS_PUB_KEY` — те же имена переменных) |
| Скрыть «Основано на RustDesk» на главном экране; автозапись исходящих сессий по умолчанию | там же: `BUILTIN_SETTINGS` (`hide-powered-by-me=Y`), `DEFAULT_LOCAL_SETTINGS` (`allow-auto-record-outgoing=Y`) |
| Отображаемое имя «Retmind Desk» (заголовки окон, трей, тексты) | `src/flutter_ffi.rs` (`main_get_app_name*`), `src/flutter.rs` (`get_rustdesk_app_name` — по нему ищется открытое окно), `src/core_main.rs`, `src/lang.rs` (translate() меняет «RustDesk» в текстах), `src/tray.rs`, `flutter/windows/runner/main.cpp`, `flutter/lib/desktop/widgets/tabbar_widget.dart` |
| URI-схема `retmind-desk://` | `src/common.rs` (`get_uri_prefix`), `src/platform/windows.rs` (ключи HKCR при установке из exe), `res/msi/Package/Components/Regs.wxs` (msi), `flutter/macos/Runner/Info.plist` (`CFBundleURLSchemes`) |
| exe и данные файла Windows | `flutter/windows/CMakeLists.txt` (`BINARY_NAME` → `RetmindDesk.exe`), `flutter/windows/runner/Runner.rc` (продукт, компания, описание), `build.py` |
| macOS: bundle id `pro.retmind.desk`, имя | `flutter/macos/Runner/Configs/AppInfo.xcconfig`, `Runner.xcodeproj/project.pbxproj`, `Info.plist` (`CFBundleDisplayName`), `build.py`, `Cargo.toml` |
| Цвета (акцент #0866FF, светлая #F0F2F5/белая, тёмная #1C1C1D/#252728) | `flutter/lib/common.dart` (`MyTheme`, `ColorThemeExtension`) |
| Ссылки «Сайт», «Конфиденциальность», «Скачать», помощь → support.retmind.pro | `desktop_setting_page.dart` («О программе»), `install_page.dart`, `desktop_home_page.dart`, `connection_page.dart`, `common.dart`, `LINK_DOCS_HOME` |
| «О программе»: «Основано на RustDesk © Purslane Tech, AGPL-3.0, исходный код: <форк>» | `desktop_setting_page.dart` |
| Иконки, трей, логотип | `res/icon.ico`, `res/tray-icon.ico`, `res/*.png`, `res/mac-icon.png`, `res/mac-tray-*-x2.png`, `flutter/windows/runner/resources/app_icon.ico`, `flutter/macos/Runner/AppIcon.icns`, `flutter/assets/icon.svg`, `logo*.png` |

Ссылка из Retmind Support: `retmind-desk://connection/new/<ID кассы>` (разбирает `urlLinkToCmdArgs` в
`flutter/lib/common.dart` → `--connect <ID>`; работает и короткая `retmind-desk://<ID>`). Схема регистрируется
при **установке** (exe → «Установить» или msi; на Mac — при первом запуске из «Программ»); переносной запуск
без установки ссылку не открывает.

**Где не уверен (проверить на первой сборке и пилоте):**
- Отображаемое имя с пробелом: заголовок окна и поиск уже открытого окна на Windows переведены на «Retmind
  Desk» согласованно (4 места). Если ссылка `retmind-desk://` при открытой программе откроет второе окно вместо
  передачи в первое — собрать с `DESK_DISPLAY_NAME=RetmindDesk` (тогда везде без пробела).
- Ярлыки в меню «Пуск» и папка установки по умолчанию строятся из имени: будут «RetmindDesk» / «Retmind Desk».
- macOS: метки служб launchd остаются `com.carriez.RetmindDesk_*` — префикс жёстко прописан в
  `src/platform/macos.rs`; пользователю он почти не виден (в «Объектах входа» показывается имя программы).
- Переводы на другие языки: «RustDesk» в текстах заменяется на «Retmind Desk» автоматически (translate()),
  отдельные строки на мобильных страницах (Android/iOS мы не собираем) не трогали.
- Шрифт Manrope в клиент не встраивали (остаётся системный) — по желанию, это `flutter/pubspec.yaml` + тема.
- msi: preprocess.py получает `--app-name RetmindDesk -m Retmind`; UpgradeCode он считает от имени — значит,
  при смене имени msi не обновит старую установку (для нас это первая версия, не важно).
- Подпись Windows в workflow — через .pfx; при облачном сертификате шаг заменить (см. выше).

## Обновление на новый тег RustDesk

1. Поменять `RUSTDESK_TAG` в `apply.sh` и `RUSTDESK_TAG/VERSION` + версии из их `flutter-build.yml` в
   `desk-build.yml`.
2. `bash desk/brand/apply.sh <исходники>` — если upstream изменил какое-то место, скрипт перечислит
   «НЕ НАЙДЕНО» и выйдет с ошибкой. Поправить замену, проверить `git diff`.
3. Сборка, проверка на 2–3 кассах, раскатка.

## Альтернатива: RustDesk Server Pro с генератором своего клиента (платно)

- Плюсы: свой клиент (имя, иконка, логотип, сервер, настройки) собирается в их веб-консоли за минуты, без
  своего CI и переносов на новые версии; плюс консоль: адресная книга, права доступа, журнал подключений,
  вход через OIDC/LDAP, централизованные настройки, API.
- Минусы: подписка (цена зависит от числа пользователей и устройств — уточнить на rustdesk.com/pricing),
  закрытый сервер с проверкой лицензии, зависимость от поставщика; подпись Windows/Mac нашим сертификатом всё
  равно нужна (кем подписывается результат генератора — не проверял, уточнить у них).
- Вывод: для 15 сотрудников и пилота хватает бесплатного сервера и своей сборки; к Pro вернёмся, если нужна
  будет их консоль прав и журналов.

## Запись сессий для базы знаний

**Что умеет RustDesk (проверено по исходникам 1.5.3):**
- Запись экрана сессии в файл. Настройки: `enable-record-session` (разрешить запись вообще),
  `allow-auto-record-outgoing` — автозапись **исходящих** сессий на компьютере оператора (в нашей сборке
  включена по умолчанию), `allow-auto-record-incoming` — автозапись входящих на стороне кассы (по умолчанию
  выключена; на кассе включать не будем — диск и приватность), кнопка записи в окне сессии вручную.
- Где лежат файлы у оператора: папка `video-save-directory`, по умолчанию «Видео\RetmindDesk» (Windows) и
  `~/Movies/RetmindDesk` (macOS); у установленной службы на кассе — `C:\ProgramData\RetmindDesk\recording`.
- Имя файла: `outgoing_<ID кассы>_<ГГГГММДДччммссммм>_display<N>_<кодек>.webm` (VP8/VP9/AV1) или `.mp4`
  (H.264/H.265). Только видео экрана, без звука и без списка действий; каждый монитор — отдельный файл.
- Чего нет: загрузки записи на сервер (в бесплатной версии), журнала действий (клики, команды), привязки к
  обращению. Журнал подключений (кто/когда) — только в Server Pro.

**Как это попадает к нам сейчас:** оператор жмёт «Подключиться» в обращении → Support создаёт сессию
(`POST /api/desk/sessions`, событие в ленте «Удалённое подключение к Касса 1 (ID …)», журнал) и открывает
`retmind-desk://connection/new/<ID>`; по окончании — «Завершить» с полем «Что сделали» (текст сохраняется в
сессии и событии и идёт в черновики базы знаний).

**Требования к будущей программе Retmind Support для Windows/Mac (в ТЗ, docs/03-desktop-tz.md, D3):**
1. Программа знает, какая сессия идёт: Support при старте отдаёт `session_id`, программа запоминает
   `session_id ↔ ID кассы ↔ время начала`.
2. После завершения сессии программа находит файлы записи в `video-save-directory` по имени
   (`outgoing_<ID кассы>_<время ≥ начала сессии>_*`) и загружает их:
   `POST /api/desk/sessions/{id}/recording` (multipart, файл до N ГБ, докачка при обрыве; ответ —
   `recording_path`). Backend кладёт файл в хранилище файлов и показывает запись в карточке обращения и сессии
   (право просмотра — как у обращения). Пока этого API нет — его добавляет основная линия.
3. Если запись не включена или файла нет — программа сообщает «Запись не найдена», сессия всё равно
   закрывается (запись необязательна).
4. Окно «Что сделали» показывается после закрытия окна Retmind Desk (если оператор не завершил сессию в
   Support): короткий текст + флажок «Предложить как статью базы знаний» → `POST /api/desk/sessions/{id}/end`
   (или как решит основная линия) → черновик статьи БЗ с привязкой к обращению и кассе; AI (когда настроен)
   оформляет черновик по тексту и, позже, по записи.
5. Хранение записей: срок (например 90 дней, настраивается), удаление по сроку, доступ только сотрудникам
   с правом на обращение; клиента предупреждаем о записи (текст в договоре/при подключении).
6. Позже (этап 3): журнал действий в сессии (запуск команд, перезапуск служб) — из нашего агента/команд
   диагностики, а не из RustDesk.
