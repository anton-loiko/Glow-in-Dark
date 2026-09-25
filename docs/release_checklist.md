# Релиз V1: чек-лист

task_8 §7. Отмечается по мере готовности. Что ждёт аккаунтов или решений владельца — в `tasks/BACKLOG.md`.

## 1. Сборки

| Пункт | Android | iOS |
|---|---|---|
| Идентификатор | `com.forwardmobile.lightinthedark` ✅ | `com.forwardmobile.lightinthedark` ✅ |
| Версия / билд | 1.0.0 / 1 ✅ | 1.0.0 / 1 ✅ |
| Минимальная ОС | Android 8.0 (API 26) — требование Appodeal ✅ | iOS 17 (D16) ✅ |
| Сборка | Gradle build (плагины) ✅ — debug APK собирается локально и в CI | Xcode-проект из экспорта — ⬜ (нужны подпись и профиль) |
| Иконки | 192 + adaptive (fg / bg / mono) из `src/assets/brand` ✅ | 1024 App Store ✅ |
| Сплэш | boot splash (знак на `ink.900`) ✅; тема Android 12+ `windowSplashScreenBackground` ✅ | boot splash ✅ |
| Подпись релиза | keystore вне репозитория — ⬜ | сертификат + provisioning — ⬜ |
| Game Center entitlement | — | включён в пресете ✅ |
| Проверено на эмуляторе | ✅ S01 → S03 → S02 → забег (Android 16, эмулятор, GL-режим) | ⬜ |

`.gitignore` исключает `*.apk`, `*.aab`, `*.ipa`, `*.keystore`, `*.jks`, `*.p12`, `*.mobileprovision`, `build/`, `/android/`.

## 2. Приватность: что собираем

Сбор аналитики выключен до согласия (Consent Mode v2, `Telemetry.set_consent`). Форму согласия показывает Appodeal SDK (UMP/GDPR) при инициализации; на iOS до неё — ATT.

| Данные | Кто | Цель | Связь с пользователем | Трекинг |
|---|---|---|---|---|
| Идентификатор устройства / рекламный ID | Appodeal и сети медиации | Реклама, атрибуция | Нет | Да (после согласия / ATT) |
| События игры (`docs/analytics_events.md`), user properties | Firebase Analytics | Аналитика продукта | Нет (анонимный ID) | Нет |
| Краш-логи | Firebase Crashlytics | Стабильность | Нет | Нет |
| Анонимный UID, ID игрока Game Center / Play Games | Firebase Auth | Облачное сохранение, вход | Да | Нет |
| Профиль игры (прогресс, кошелёк) | Firestore `users/{uid}` | Облачное сохранение | Да | Нет |
| История покупок (transaction ID) | Профиль игры, стор | Выдача покупок, восстановление | Да | Нет |

Персональных данных (имя, email, контакты, геолокация, фото) не собираем. Удаление данных: запрос в поддержку → удаление `users/{uid}` и аккаунта Auth (процедура — ⬜ до релиза).

**App Store — App Privacy:** Identifiers (Device ID — Third-Party Advertising, Tracking), Usage Data (Product Interaction — Analytics), Diagnostics (Crash Data — App Functionality), Purchases (Purchase History — App Functionality), User ID (App Functionality). `NSUserTrackingUsageDescription` — ⬜ текст RU/EN.

**Google Play — Data safety:** Device or other IDs (реклама, аналитика), App activity (аналитика), Crash logs, Purchase history. Шифрование при передаче — да (HTTPS). Удаление данных по запросу — да.

## 3. Требования сторов

- ✅ Шансы лутбоксов видны до покупки (S10 «i»).
- ✅ Цены — локализованные строки стора, без хардкода.
- ✅ «Восстановить покупки» (S13).
- ✅ Кнопки рекламы помечены ▶, реклама только по нажатию; интерстишалов нет (D15).
- ⬜ Политика конфиденциальности (URL в сторах и в S13).
- ⬜ Возрастной рейтинг (анкеты IARC / App Store).
- ⬜ Скриншоты сторов: «1 против 1000», «Маяк: до/после» (Art Direction §01).

## 4. Качество перед отправкой

- ✅ CI: строгая проверка скриптов, юнит-тесты, RunBot 10:00 и стресс-режим, сборка Android APK (`.github/workflows/ci.yml`).
- ⬜ 60 FPS (p1 ≥ 55) на Redmi 9 и iPhone XR в стресс-сценарии — ручной замер с `PerfOverlay` (F10 / три пальца).
- ⬜ TestFlight и Google Play Internal Testing с sandbox-покупками и тестовой рекламой Appodeal.
- ✅ Фича-флаги V1 — `configs/features.json` (Плакальщик, эволюции, доска заданий, лидерборды выключены).
