# Ad Master Flutter

This project replaces the old mock React/Electron demo with a Flutter application.

## Features

- Admin account setup and login
- Separate screen login for each display
- Editable organization profile
- Screen registration and credential management
- Media library with screen assignment
- Screen playback for assigned images and videos
- Dedicated admin build for web and desktop
- Dedicated screen APK build with embedded screen credentials
- Per-screen APK download links from the admin profile
- Dual backend modes:
  - Local mode for quick testing
  - Supabase mode for cross-device sync and real media delivery

## Backend modes

The app supports two modes:

- Local mode
  - Default behavior
  - Stores everything with `shared_preferences`
  - Good for demos on a single device

- Supabase mode
  - Uses Supabase Postgres, Realtime, and Storage
  - Supports real syncing between admin and deployed screens
  - Requires valid values in [supabase_options.dart](/c:/Users/Eleven/Downloads/Ad-master/Ad-master/app/lib/supabase_options.dart:1)

## Admin web on Render

Render config is included in [render.yaml](/c:/Users/Eleven/Downloads/Ad-master/Ad-master/render.yaml:1).

1. Push this repo to GitHub.
2. In Render, create a new `Blueprint` or `Static Site`.
3. If you use the included blueprint, Render will:
   - use `app` as the root directory
   - run `./scripts/build_admin_web.sh`
   - publish `app/build/web`
4. Make sure [supabase_options.dart](/c:/Users/Eleven/Downloads/Ad-master/Ad-master/app/lib/supabase_options.dart:1) contains your live Supabase URL and anon key before deploying.
5. The Render build script installs Flutter during the build, because Render's native runtimes do not include Flutter by default.

## Admin desktop app

From the `app/` folder:

```powershell
.\scripts\build_admin_windows.ps1
```

That builds a Windows desktop admin app using [main_admin.dart](/c:/Users/Eleven/Downloads/Ad-master/Ad-master/app/lib/main_admin.dart:1).

## Screen APK with saved credentials

From the `app/` folder:

```powershell
.\scripts\build_screen_apk.ps1 -ScreenCode "screen-01" -ScreenPassword "1234" -ScreenName "Lobby TV"
```

That builds an Android APK using [main_screen.dart](/c:/Users/Eleven/Downloads/Ad-master/Ad-master/app/lib/main_screen.dart:1). The screen app logs in automatically on launch and opens the assigned video/image player directly.

## Download APK per screen

The admin profile can now show a real `Download APK` button for each screen.

Setup:

1. Push the repo to GitHub.
2. Use the workflow in [.github/workflows/build-screen-apk.yml](/c:/Users/Eleven/Downloads/Ad-master/Ad-master/.github/workflows/build-screen-apk.yml:1).
3. In Supabase SQL Editor, run [supabase_apk_setup.sql](/c:/Users/Eleven/Downloads/Ad-master/Ad-master/app/supabase_apk_setup.sql:1).
4. In GitHub, run `Actions -> Build Screen APK -> Run workflow` with:
   - `screen_code`
   - `screen_password`
   - `screen_name`
5. The workflow uploads the APK to the GitHub release tag `screen-apks`.
6. Make sure the GitHub repo is public if you want the APKs to open on any laptop without GitHub sign-in.
7. In the admin profile, set `APK base URL` to:

```text
https://github.com/OWNER/REPO/releases/download/screen-apks
```

8. Save the profile. Each screen will then expose a `Download APK` button using its own generated asset name.
9. Each workflow run also uploads a matching metadata file like `screen-01.json` to the same release so you can inspect the exact URL and build info outside the admin app.

The APK filename for each screen is based on its login code. Example:

- `screen-01` -> `screen-01.apk`
- `Lobby TV` style codes are normalized to lowercase with dashes

Important notes:

- If the GitHub repo is private, the download link will require GitHub access.
- The direct public APK pattern is:

```text
https://github.com/OWNER/REPO/releases/download/screen-apks/<screen-code>.apk
```

- The Render-hosted admin app does not build APKs itself. GitHub Actions builds them, and the admin app provides the per-screen download links.

## Build APK directly from the desktop admin

If you run the admin as a Windows desktop app, you can build a screen APK locally from the `Screens` section.

Setup:

1. Build and open the Windows admin app.
2. In `Clients`, set `Local Flutter project path` to your local `app` folder.
3. In `Screens`, click `Build Local` on any screen card.
4. The app runs [build_screen_apk.ps1](/c:/Users/Eleven/Downloads/Ad-master/Ad-master/app/scripts/build_screen_apk.ps1:1) locally and copies the built APK to:

```text
app/build/screen-apks/<screen-code>.apk
```

This works only on the Windows desktop admin, not on the Render web app.

## Local development

Hybrid mode with the existing landing page:

```powershell
flutter run
```

Admin-only app:

```powershell
flutter run --target lib/main_admin.dart --dart-define=USE_SUPABASE=true --dart-define=APP_FLAVOR=admin
```

Screen-only app with embedded credentials:

```powershell
flutter run --target lib/main_screen.dart --dart-define=USE_SUPABASE=true --dart-define=APP_FLAVOR=screen --dart-define=SCREEN_CODE=screen-01 --dart-define=SCREEN_PASSWORD=1234
```
