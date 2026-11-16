#!/bin/bash
# Compila e instala o app Coruja neste Mac.
set -e
cd "$(dirname "$0")"

if ! xcode-select -p >/dev/null 2>&1; then
  echo "Instalando as Ferramentas de Linha de Comando da Apple (só na primeira vez)..."
  xcode-select --install || true
  echo "Quando a instalação terminar, rode este mesmo comando de novo."
  exit 1
fi

rm -rf ./Coruja.app ./Coruja.iconset ./icon_1024.png
mkdir -p ./Coruja.app/Contents/MacOS ./Coruja.app/Contents/Resources

echo "Compilando a coruja..."
swiftc -O -swift-version 5 main.swift -o ./Coruja.app/Contents/MacOS/Coruja -framework AppKit -framework IOKit
cp Info.plist ./Coruja.app/Contents/Info.plist

echo "Desenhando o ícone..."
./Coruja.app/Contents/MacOS/Coruja --export-icon icon_1024.png
mkdir ./Coruja.iconset
for s in 16 32 128 256 512; do
  sips -z $s $s icon_1024.png --out "Coruja.iconset/icon_${s}x${s}.png" >/dev/null
  d=$((s*2))
  sips -z $d $d icon_1024.png --out "Coruja.iconset/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns ./Coruja.iconset -o ./Coruja.app/Contents/Resources/Coruja.icns
rm -rf ./Coruja.iconset ./icon_1024.png

codesign --force --deep -s - ./Coruja.app >/dev/null 2>&1 || true

DEST="/Applications"
[ -w "$DEST" ] || { DEST="$HOME/Applications"; mkdir -p "$DEST"; }
rm -rf "${DEST:?}/Coruja.app"
cp -R ./Coruja.app "$DEST/"
rm -rf ./Coruja.app

echo "Pronto! Coruja instalada em $DEST"
open "$DEST/Coruja.app"
