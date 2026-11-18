#!/bin/zsh
# Builds Toado.app from Toado.swift
set -e
cd "$(dirname "$0")"

APP=Toado.app
rm -rf $APP
mkdir -p $APP/Contents/MacOS

swiftc -parse-as-library -O Toado.swift -o $APP/Contents/MacOS/Toado

cat > $APP/Contents/Info.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Toado</string>
    <key>CFBundleIdentifier</key><string>local.toado</string>
    <key>CFBundleExecutable</key><string>Toado</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <!-- menu bar only: no Dock icon -->
    <key>LSUIElement</key><true/>
</dict>
</plist>
EOF

codesign --force --sign - $APP
echo "Built $APP"
