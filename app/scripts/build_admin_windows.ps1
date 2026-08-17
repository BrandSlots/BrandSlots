param()

$ErrorActionPreference = "Stop"

if (-not (Test-Path ".\windows")) {
  flutter create --platforms=windows .
}

flutter pub get
flutter build windows --release `
  --target lib/main_admin.dart `
  --dart-define=USE_SUPABASE=true `
  --dart-define=APP_FLAVOR=admin
