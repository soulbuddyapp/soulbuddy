#!/usr/bin/env bash
# Build only from a disposable export; never rewrite a developer's or release checkout.
set -euo pipefail
: "${RUNNER_TEMP:?A temporary build directory is required}"
: "${SOURCE_SHA:?The full candidate commit SHA is required}"
[[ "$SOURCE_SHA" =~ ^[0-9a-f]{40}$ && "$(git rev-parse HEAD)" == "$SOURCE_SHA" ]] || {
  echo 'Checkout does not match the requested candidate.' >&2
  exit 1
}
scratch=$(mktemp -d "$RUNNER_TEMP/soulbuddy-audio-qa.XXXXXXXX")
trap 'rm -rf "$scratch"' EXIT
git archive "$SOURCE_SHA" apps/soulbuddy | tar -x -C "$scratch"
cd "$scratch/apps/soulbuddy"

# The Play build requires signing properties during Gradle configuration. Supply
# an entirely new, disposable QA certificate (never a release / Google Play key).
keytool -genkeypair -noprompt -keystore "$scratch/qa.jks" -storetype JKS \
  -keyalg RSA -keysize 2048 -validity 365 -dname 'CN=SoulBuddy Device QA' \
  -alias audioqa -storepass android -keypass android
cat > android/key.properties <<PROPERTIES
storePassword=android
keyPassword=android
keyAlias=audioqa
storeFile=$scratch/qa.jks
PROPERTIES

python3 - <<'PY'
from pathlib import Path
import sqlite3

def replace_once(path, old, new):
    source = path.read_text()
    if source.count(old) != 1:
        raise SystemExit(f'QA build contract changed: {path}: {old!r}')
    path.write_text(source.replace(old, new))

# Keep the Kotlin namespace and component classes, but install into a separate
# Android sandbox. Do not configure production Firebase for this QA application.
gradle = Path('android/app/build.gradle.kts')
replace_once(gradle, 'applicationId = "app.soulbuddy.soulbuddy"',
             'applicationId = "app.soulbuddy.soulbuddy.audioqa"')
replace_once(gradle, '    id("com.google.gms.google-services")\n', '')
Path('android/app/google-services.json').unlink(missing_ok=True)
manifest = Path('android/app/src/main/AndroidManifest.xml')
replace_once(manifest, '<manifest ', '<manifest xmlns:tools="http://schemas.android.com/tools" ')
replace_once(manifest, 'android:name="android.permission.INTERNET" />',
             'android:name="android.permission.INTERNET" tools:node="remove" />')
replace_once(manifest, 'android:label="soulbuddy"', 'android:label="SoulBuddy Audio QA"')
for component in ['MainActivity', 'SacredHourPlaybackService']:
    replace_once(manifest, f'android:name=".{component}"',
                 f'android:name="app.soulbuddy.soulbuddy.{component}"')

# Match the production Android build's removal of its test-only native plugin.
replace_once(Path('pubspec.yaml'), '  integration_test:\n    sdk: flutter\n', '')
db = Path('assets/scripture/rsvce.db')
with sqlite3.connect(f'file:{db}?mode=ro', uri=True) as con:
    for table in ['books', 'chapters', 'verses']:
        if not con.execute(f'SELECT 1 FROM {table} LIMIT 1').fetchone():
            raise SystemExit(f'Bundled Scripture table is empty: {table}')
PY

flutter pub get
flutter build apk --release --no-pub --target-platform android-arm64 \
  --dart-define=SOULBUDDY_API_URL=http://127.0.0.1:9 \
  --dart-define=SOULBUDDY_POWERSYNC_URL=
apk=build/app/outputs/flutter-apk/app-release.apk
sdk_root=${ANDROID_SDK_ROOT:-${ANDROID_HOME:?Android SDK is required}}
build_tools=$(find "$sdk_root/build-tools" -type f -name apksigner -printf '%h\n' | sort -V | tail -1)
"$build_tools/apksigner" verify "$apk"
badging=$("$build_tools/aapt" dump badging "$apk")
grep -Fq "package: name='app.soulbuddy.soulbuddy.audioqa'" <<<"$badging"
grep -Fq "application-label:'SoulBuddy Audio QA'" <<<"$badging"
grep -Fq "launchable-activity: name='app.soulbuddy.soulbuddy.MainActivity'" <<<"$badging"
permissions=$("$build_tools/aapt" dump permissions "$apk")
grep -Fq "name='android.permission.RECORD_AUDIO'" <<<"$permissions"
if grep -Fq "name='android.permission.INTERNET'" <<<"$permissions"; then
  echo 'QA APK unexpectedly has network access.' >&2
  exit 1
fi

python3 - "$apk" <<'PY'
from pathlib import Path
import sys
from zipfile import ZipFile

with ZipFile(sys.argv[1]) as apk:
    if 'lib/arm64-v8a/libapp.so' not in apk.namelist():
        raise SystemExit('ARM64 application library missing')
    for asset in ['assets/scripture/rsvce.db', 'assets/audio/meditation/stillness.mp3',
                  'assets/audio/meditation/flowing_water.mp3']:
        original = Path(asset).read_bytes()
        if not original or apk.read('assets/flutter_assets/' + asset) != original:
            raise SystemExit(f'Missing or altered bundled asset: {asset}')
PY

out="$RUNNER_TEMP/soulbuddy-audio-qa-artifact"
mkdir "$out"
name="SoulBuddy-audio-QA-arm64-${SOURCE_SHA:0:12}.apk"
cp "$apk" "$out/$name"
cd "$out"
sha256sum "$name" > SHA256SUMS
printf '%s\n' "$SOURCE_SHA" > SOURCE_COMMIT
cat > INSTALL.txt <<NOTES
SoulBuddy Audio QA | ARM64 Android
Source commit: $SOURCE_SHA

Extract this ZIP and open $name on an ARM64 Android phone.
Or use: adb install $name
App label: SoulBuddy Audio QA. Package: app.soulbuddy.soulbuddy.audioqa.
Your Play Store SoulBuddy app and its private recordings remain separate.

Use test recordings only: this package is offline and its data is device-local.
This build cannot sign in, sync, or register for remote push. A video link
may open your phone's separate browser or video app. To test the handoff,
play a prayer or memory with Flowing water and start an After prayer take.
Listen to the saved take, move between screens, test with headphones and
speakers, and repeat after a call or app switch. An unheard take must save too.
An APK build verifies packaging; only those phone checks verify actual sound.

Each CI run uses a fresh QA signing key. A newer run cannot overwrite an
earlier QA installation using a different key. Removing that QA installation
erases its test recordings; there is no need to remove the Play Store app.
NOTES
