## Шаблон Flutter + Riverpod + Supabase

Этот репозиторий - **готовый шаблон** Flutter-приложения с:

- **Flutter** + Material 3 темы (светлая/темная)
- **Riverpod** для состояния
- **Supabase** как backend (авторизация + профили)
- **go_router** для навигации



Можно делать почти любое приложение с авторизацией и профилем. Примеры категорий:

Магазины и каталоги (e‑commerce, витрины, прайс‑листы)
Блоги и медиа (новости, статьи, журналы)
Спорт и фитнес (тренировки, команды, расписания)
Сервисы и заказы (такси, курьеры, клининг, ремонт)
Образование (курсы, школы, трекеры прогресса)
Сообщества (форумы, клубы, мероприятия)
Бронирование (отели, столики, слоты, очереди)
HR и работа (вакансии, заявки, портфолио)
CRM/учет (клиенты, сделки, задачи)
Здоровье (записи, напоминания, профили)
Финансы (личные бюджеты, счета, аналитика)
B2B порталы (доступы по ролям, кабинеты)



git clone https://github.com/bohatko/FlutterSupaRiverpod my_new_app
cd my_new_app
rm -rf .git
git init
git add .
git commit -m "Initial commit"



## 1. Что делать после клонирования репозитория

1. **Установи Flutter** (если еще нет)
   - Скачай Flutter SDK для своей ОС
   - Добавь `flutter/bin` в `PATH`
   - Проверь:
     ```bash
     flutter --version
     flutter doctor
     ```

2. **Установи зависимости проекта**
   ```bash
   flutter pub get
   ```

3. **Проверь, что проект собирается (без Supabase)**
   ```bash
   flutter analyze
   ```

---

## 2. Настройка Supabase

Инициализация Supabase находится в `lib/supabase/supabase_config.dart` и использует
`AppConfig` (`lib/core/config/app_config.dart`), который берет значения из:

- локального файла `lib/env/env.dart` (по умолчанию)
- либо из `--dart-define=SUPABASE_URL/ANON_KEY` (если они переданы при запуске/сборке)

### 2.1. Где взять значения

1. Зайди в проект Supabase -> **Project Settings -> API**.
2. Скопируй:
   - `Project URL` -> это `SUPABASE_URL`
   - `anon public` key -> это `SUPABASE_ANON_KEY`

### 2.2. Как указать значения (локально)

1. Скопируй `lib/env/env.example.dart` в `lib/env/env.dart` (он добавлен в `.gitignore`).
2. Впиши свои значения:

```dart
const String supabaseUrl = 'https://your-project-id.supabase.co';
const String supabaseAnonKey = 'your_anon_public_key';
```

3. После этого дополнительных флагов не нужно, достаточно обычной команды:

```bash
flutter run
```

Для Web (Chrome):

```bash
flutter run -d chrome
```

### 2.3. Вариант для CI / продакшн (через Dart defines)

Для сборок в CI или когда не хочешь использовать `env.dart`, можно передавать
ключи через `--dart-define` (они имеют приоритет над `env.dart`):

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://your-project-id.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your_anon_public_key \
  --dart-define=APP_ENV=dev
```

Для релизной сборки:

```bash
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://your-project-id.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your_anon_public_key \
  --dart-define=APP_ENV=prod
```

### 2.4. Схема таблицы `public.profiles`

Шаблон ожидает, что в Supabase есть таблица профилей ровно с такой схемой:

```sql
create table public.profiles (
  id uuid not null,
  created_at timestamp with time zone not null default now(),
  first_name text null,
  last_name text null,
  email text null,
  display_name text null,
  avatar_url text null,
  updated_at date null,
  role public.user_role not null default 'user'::user_role,
  soft_delete boolean null default false,
  constraint profiles_pkey primary key (id),
  constraint profiles_id_fkey
    foreign key (id) references auth.users (id)
    on update cascade on delete cascade
);
```
Также enums с ролями user и admin

- Поля `first_name` и `last_name` заполняются с экрана `/profile`.
- `display_name` используется как основное отображаемое имя.
- `role`(enums) читается на экране `/profile` (блок **Account Details**).
- `soft_delete` выставляется в `true` при удалении аккаунта, плюс происходит `signOut()`.

---

## 3. Запуск по платформам

### 3.1. Android

После настройки `lib/env/env.dart`:

```bash
flutter run
```

Требуется:

- Android Studio / Android SDK
- хотя бы один эмулятор или реальное устройство

### 3.2. iOS (на macOS)

```bash
flutter run
```

Или сборка:

```bash
flutter build ios --release \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=...
```

Требуется:

- macOS
- Xcode + настроенный signing

### 3.3. Web

```bash
flutter run -d chrome
```

---

## 4. Архитектура и структура

Проект организован по feature-first и Clean Architecture:

```
lib/
  core/                  # Общие утилиты и UI
  features/              # Фичи
    auth/
      data/              # Репозитории и провайдеры данных
      domain/            # Бизнес-логика и модели
      presentation/      # UI и контроллеры
    home/
      presentation/
        pages/
    search/
      presentation/
        pages/
    settings/
      presentation/
        pages/
    shop/
      presentation/
        pages/
  supabase/              # Конфигурация Supabase
  main.dart              # Точка входа
  nav.dart               # Роутинг
  theme.dart             # Тема
```

### Ключевые компоненты

- **Auth**: `AuthController` управляет входом/регистрацией/выходом/сбросом пароля
- **Профили**: таблица `public.profiles` + soft delete (см. раздел Supabase)
- **Тема**: `ThemeNotifier` сохраняет тему в `shared_preferences`
- **Логи**: `AppLogger` в `lib/core/logging/app_logger.dart`
- **UI Kit**: `AppButton`, `AppTextField`, `AppDialog`, `AppSnackbar`

### Добавление новой фичи (шаблон)

```
lib/features/your_feature/
  data/
    providers/
    repositories/
  domain/
    models/
    repositories/
  presentation/
    controllers/
    models/
    pages/
```

---

## 5. Использование репозитория как шаблона

### 4.1. Клонировать под новый проект

1. Склонируй репозиторий в новую папку:

   ```bash
   git clone <url_этого_репозитория> my_new_app
   cd my_new_app
   ```

2. (Опционально) оборвать связь с исходным Git-репо и создать свое:

   ```bash
   rm -rf .git        # осторожно, удаляет историю!
   git init
   git add .
   git commit -m "Initial commit from app_template"
   ```

3. Установи зависимости:

   ```bash
   flutter pub get
   ```

### 4.2. Переименовать проект под себя

**1. Имя пакета Flutter**

- Открой `pubspec.yaml` и поменяй:

  ```yaml
  name: app_template        # замени на свое (латиница, нижний регистр, подчеркивания)
  description: "..."        # опционально
  ```

**2. Имя приложения внутри Flutter**

- В `lib/main.dart`:

  ```dart
  return MaterialApp.router(
    title: 'App Template', // замени на свое название
    ...
  );
  ```

**3. Название на Android**

- Файл: `android/app/src/main/AndroidManifest.xml`
  ```xml
  <application
      android:label="App Template"
      ...>
  ```
  Поставь нужное название вместо `App Template`.

**4. Название на iOS**

- Файл: `ios/Runner/Info.plist`
  ```xml
  <key>CFBundleDisplayName</key>
  <string>App Template</string>

  <key>CFBundleName</key>
  <string>app_template</string>
  ```

**5. Web-название**

- Файл: `web/index.html`
  ```html
  <meta name="apple-mobile-web-app-title" content="app_template">
  <title>app_template</title>
  ```

- Файл: `web/manifest.json`
  ```json
  "name": "app_template",
  "short_name": "app_template",
  ```

### 4.3. Поменять идентификаторы (bundle id / applicationId)

> Эти шаги нужны, если планируешь публиковать приложение или иметь несколько разных приложений.  

- **Android**: файл `android/app/build.gradle` (или `build.gradle.kts`)
  В `defaultConfig` найди:

  ```groovy
  applicationId "com.example.app_template"
  ```

  Замени на свое, например:

  ```groovy
  applicationId "com.mycompany.mynewapp"
  ```

- **iOS**: через Xcode  
  Открой `ios/Runner` в Xcode -> таргет **Runner** -> вкладка **General** -> поле **Bundle Identifier**.  
  Поставь, например: `com.mycompany.mynewapp`.

После изменения идентификаторов рекомендуется выполнить:

```bash
flutter clean
flutter pub get
```

---

## 6. Иконки приложения

Шаблон настроен на использование генератора иконок `flutter_launcher_icons`:

- В `pubspec.yaml`:

  ```yaml
  flutter_launcher_icons:
    android: true
    ios: true
    image_path: assets/icons/flutter.jpg
    remove_alpha_ios: true
  ```

Шаги:

1. Положи свою иконку по пути `assets/icons/flutter.jpg` (или поменяй путь в `pubspec.yaml`).
2. Запусти:

   ```bash
   flutter pub run flutter_launcher_icons
   ```

---

## 7. Важные директории и что не коммитить

При работе с шаблоном **не нужно копировать/коммитить**:

- `build/`
- `.dart_tool/`
- `.idea/`, `.vscode/`
- `ios/Pods/`

Если проект разрастается, можно периодически чистить сборки:

```bash
flutter clean
flutter pub get
```

---

## 8. Краткий чек-лист после клонирования

1. `flutter pub get`
2. Настроить Supabase (`SUPABASE_URL`, `SUPABASE_ANON_KEY`)
3. Решить:
   - используешь этот репозиторий как есть **или**
   - обнуляешь `.git` и создаешь свой репозиторий
4. Переименовать:
   - `pubspec.yaml -> name`
   - заголовок в `lib/main.dart`
   - названия в Android/iOS/Web (по желанию)
5. Заменить иконку и прогнать `flutter_launcher_icons`
6. Запустить:

   ```bash
   flutter run
   ```
