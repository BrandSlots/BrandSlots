param()

$ErrorActionPreference = "Stop"

flutter pub get
flutter build web --release `
  --target lib/main_admin.dart `
  --dart-define=USE_SUPABASE=true `
  --dart-define=APP_FLAVOR=admin
