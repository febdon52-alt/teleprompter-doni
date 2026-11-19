#!/bin/bash
# Membuat proyek Xcode lalu membukanya. Setelah Xcode terbuka:
#  1) Pilih target "BacaKamera" › Signing & Capabilities › Team: Apple ID Anda
#  2) Colokkan iPhone, pilih iPhone sebagai tujuan, tekan Run (▶)
cd "$(dirname "$0")" || exit 1
if ! command -v xcodegen >/dev/null 2>&1; then
  if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew belum terpasang. Pasang dulu dari https://brew.sh lalu jalankan ulang."
    exit 1
  fi
  brew install xcodegen || exit 1
fi
xcodegen generate || exit 1
open BacaKamera.xcodeproj
