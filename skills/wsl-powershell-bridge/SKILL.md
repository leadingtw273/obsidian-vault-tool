---
name: wsl-powershell-bridge
description: >
  在 WSL2 環境中，提供透過 PowerShell 橋接執行 Windows 原生程式的通用機制。
  當其他 skill（如 archive）需要在 WSL 環境執行 Windows 原生程式時，查閱此 skill。
---

# WSL → Windows PowerShell 橋接工具

在 WSL2 環境中，Windows 原生程式無法直接在 Linux bash 環境執行。
此 skill 透過 PowerShell wrapper 從 WSL bash 橋接執行 Windows 端程式。

## 腳本路徑

```
${CLAUDE_PLUGIN_ROOT}/skills/wsl-powershell-bridge/scripts/powershell.sh
```

## 標準呼叫方式

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/wsl-powershell-bridge/scripts/powershell.sh" <windows-command> [args...]
```

## content_file 參數（長文內容）

解決命令列長度限制與特殊字元跳脫問題，使用 PowerShell here-string 傳遞內容。
暫存檔在執行後自動清除。

```bash
# Step 1：將內容寫入暫存檔
cat > /tmp/claude-0/content.md << 'ENDOFFILE'
[內容]
ENDOFFILE

# Step 2：傳入 content_file 參數
bash "${CLAUDE_PLUGIN_ROOT}/skills/wsl-powershell-bridge/scripts/powershell.sh" <windows-command> [其他參數] \
  content_file="/tmp/claude-0/content.md"
```

## 確認 PowerShell 可用

```bash
which powershell.exe
# 預期輸出：/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe
```

## 禁止執行前偵錯測試

直接執行正式任務，失敗再根據錯誤訊息調整。
