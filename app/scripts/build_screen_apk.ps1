param(
  [Parameter(Mandatory = $true)]
  [string]$ScreenCode,

  [Parameter(Mandatory = $true)]
  [string]$ScreenPassword,

  [Parameter(Mandatory = $false)]
  [string]$ScreenName = "Screen Player"
)

$ErrorActionPreference = "Stop"

$slug = ($ScreenCode.ToLower() -replace '[^a-z0-9]+', '-').Trim('-')
if ([string]::IsNullOrWhiteSpace($slug)) {
  $slug = "screen"
}

$outputDir = Join-Path $PSScriptRoot "..\\build\\screen-apks"
$outputDir = [System.IO.Path]::GetFullPath($outputDir)
$outputFile = Join-Path $outputDir "$slug.apk"

flutter pub get
flutter build apk --release `
  --target lib/main_screen.dart `
  --dart-define=USE_SUPABASE=true `
  --dart-define=APP_FLAVOR=screen `
  "--dart-define=SCREEN_CODE=$ScreenCode" `
  "--dart-define=SCREEN_PASSWORD=$ScreenPassword" `
  "--dart-define=SCREEN_TITLE=$ScreenName"

New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
Copy-Item ".\build\app\outputs\flutter-apk\app-release.apk" $outputFile -Force
Write-Output "APK ready: $outputFile"
