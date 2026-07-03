#!/bin/bash

echo "Compilando IACompanion en modo Debug..."
swift build

APP_NAME="IACompanion.app"
echo "Empaquetando en $APP_NAME..."

mkdir -p "$APP_NAME/Contents/MacOS"
mkdir -p "$APP_NAME/Contents/Resources"

# Copiar el ejecutable
cp .build/debug/IACompanion "$APP_NAME/Contents/MacOS/"

# Crear el Info.plist con LSUIElement=true para que corra 100% en background
cat << 'EOF' > "$APP_NAME/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>IACompanion</string>
    <key>CFBundleIdentifier</key>
    <string>com.iacompanion.mac</string>
    <key>CFBundleName</key>
    <string>IA Companion</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

echo "Empaquetado completado. Puedes arrastrar $APP_NAME a tu carpeta de Aplicaciones."
