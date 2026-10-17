#!/usr/bin/env bash
# Applies TerraPlot's Android settings on top of the files `flutter create`
# generates in CI: app name, permissions and launcher icons.
set -euo pipefail

MANIFEST=android/app/src/main/AndroidManifest.xml

if ! grep -q "ACCESS_FINE_LOCATION" "$MANIFEST"; then
  sed -i 's#<application#<uses-permission android:name="android.permission.INTERNET"/>\n    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>\n    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>\n    <uses-permission android:name="android.permission.VIBRATE"/>\n    <application#' "$MANIFEST"
fi

# App name shown under the icon
sed -i 's#android:label="[^"]*"#android:label="TerraPlot LR"#' "$MANIFEST"

# Launcher icons
cp -r android_overrides/res/. android/app/src/main/res/

echo "Patched manifest:"
cat "$MANIFEST"
