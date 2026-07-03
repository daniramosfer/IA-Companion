#!/bin/bash
echo "Instalando IA Companion Universal Watcher..."

cp ia_companion_watcher.py ~/.ia_companion_watcher.py
chmod +x ~/.ia_companion_watcher.py

mkdir -p ~/Library/LaunchAgents

sed "s|USER_HOME_PLACEHOLDER|$HOME|g" com.iacompanion.watcher.plist > ~/Library/LaunchAgents/com.iacompanion.watcher.plist

launchctl unload ~/Library/LaunchAgents/com.iacompanion.watcher.plist 2>/dev/null
launchctl load ~/Library/LaunchAgents/com.iacompanion.watcher.plist

echo "¡Instalado! El vigilante ya se está ejecutando en segundo plano y se iniciará con tu Mac."
