#!/usr/bin/env bash
set -euo pipefail

FLUTTER_ROOT="${HOME}/flutter"

if [ ! -x "${FLUTTER_ROOT}/bin/flutter" ]; then
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 "${FLUTTER_ROOT}"
fi

export PATH="${FLUTTER_ROOT}/bin:${PATH}"

flutter config --enable-web
flutter pub get
flutter build web --release \
  --target lib/main_admin.dart \
  --dart-define=USE_SUPABASE=true \
  --dart-define=APP_FLAVOR=admin
