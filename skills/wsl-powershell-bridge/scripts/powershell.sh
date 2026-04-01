#!/bin/bash
# WSL → Windows PowerShell 橋接工具
# 透過 PowerShell 將指令轉發到 Windows 側執行
# 用法：bash powershell.sh <windows-command> [args...]
#
# 支援 content_file= 參數：從檔案讀取內容，透過 PowerShell here-string 傳遞
# 解決長文內容的命令列長度限制與特殊字元跳脫問題
# 暫存檔在成功執行後自動清除

CMD="$1"
shift

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
  PS_SCRIPT=$(mktemp /tmp/claude-0/ps_bridge_XXXXXX.ps1)
  {
    printf '\xef\xbb\xbf'
    echo "\$content = @'"
    cat "$CONTENT_FILE"
    echo "'@"
    echo "${CMD} ${ARGS[*]} content=\$content"
  } > "$PS_SCRIPT"
  powershell.exe -ExecutionPolicy Bypass -File "$PS_SCRIPT"
  EXIT_CODE=$?
  rm -f "$PS_SCRIPT" "$CONTENT_FILE"
  exit $EXIT_CODE
else
  exec powershell.exe -ExecutionPolicy Bypass -Command "${CMD} ${ARGS[*]}"
fi
