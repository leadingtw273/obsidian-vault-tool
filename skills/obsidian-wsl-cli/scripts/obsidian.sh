#!/bin/bash
# Obsidian CLI WSL wrapper
# 透過 PowerShell 將指令轉發到 Windows 側的 obsidian CLI
# 用於 WSL 環境中 obsidian CLI 無法直接執行的降階處理

args=()
for arg in "$@"; do
  args+=("'${arg//\'/\'\'}'")
done
exec powershell.exe -Command "obsidian ${args[*]}"
