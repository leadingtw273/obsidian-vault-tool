#!/bin/bash
# Obsidian CLI WSL wrapper
# 透過 PowerShell 將指令轉發到 Windows 側的 obsidian CLI
# 用於 WSL 環境中 obsidian CLI 無法直接執行的降階處理
#
# 支援 content_file= 參數：從檔案讀取內容，透過 PowerShell here-string 傳遞
# 解決長文內容的命令列長度限制與特殊字元跳脫問題
# 暫存檔在成功執行後自動清除

CONTENT_FILE=""
ARGS=()

for arg in "$@"; do
  if [[ "$arg" == content_file=* ]]; then
    CONTENT_FILE="${arg#content_file=}"
  else
    ARGS+=("'${arg//\'/\'\'}'")
  fi
done

if [ -n "$CONTENT_FILE" ]; then
  # 建立 .ps1 script，用 here-string 傳入內容（不需跳脫任何字元）
  PS_SCRIPT=$(mktemp /tmp/claude-0/obsidian_XXXXXX.ps1)
  {
    echo "\$content = @'"
    cat "$CONTENT_FILE"
    echo "'@"
    echo "obsidian ${ARGS[*]} content=\$content"
  } > "$PS_SCRIPT"
  powershell.exe -File "$PS_SCRIPT"
  EXIT_CODE=$?
  rm -f "$PS_SCRIPT" "$CONTENT_FILE"
  exit $EXIT_CODE
else
  # 短內容仍走原有 args 傳遞（向下相容）
  exec powershell.exe -Command "obsidian ${ARGS[*]}"
fi
