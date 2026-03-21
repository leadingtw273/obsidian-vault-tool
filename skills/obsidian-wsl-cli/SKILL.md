---
name: obsidian-wsl-cli
description: >
  執行任何 obsidian CLI 指令前（obsidian open、obsidian search、obsidian new 等），
  只要 vault 路徑含有 /mnt/（WSL2 掛載點）、CLAUDE.md 有 vault_path_windows、
  或使用者提到 wsl/wsl2 環境，就必須查閱此 skill。
  obsidian 是 Windows 原生程式，在 WSL bash 直接執行必定出現 command not found，
  需透過此 skill 的 PowerShell wrapper 橋接才能正確執行。
  即使使用者沒說 WSL2，看到 /mnt/c/ 路徑就應套用。
---

# Obsidian CLI WSL2 包裝器

在 WSL2 環境中，`obsidian` 是 Windows 原生程式，無法直接在 Linux bash 環境執行。
此 skill 透過 PowerShell wrapper 將指令橋接到 Windows 端，讓所有 obsidian CLI 操作正常運作。

## 環境偵測

以下任一條件成立，即確認為 WSL2 環境：

- 當前 vault 的 `vault_path` 以 `/mnt/` 開頭
- `~/.claude/CLAUDE.md` 或 vault 的 `CLAUDE.md` 中記錄了 `vault_path_windows`
- 執行 `uname -r` 輸出包含 `microsoft` 或 `WSL`

## 執行方式

`obsidian.sh` wrapper 隨此 skill 一起打包，位於 `scripts/obsidian.sh`（與此 SKILL.md 同層）。

**WSL2 環境**：使用此 skill 內建的 wrapper 執行：

```bash
bash "{此 SKILL.md 所在目錄}/scripts/obsidian.sh" [原始 obsidian 參數]
```

範例對照：

| 原始指令 | WSL2 包裝後 |
|----------|-------------|
| `obsidian open "my-note"` | `bash ".../obsidian-wsl-cli/scripts/obsidian.sh" open "my-note"` |
| `obsidian search "keyword"` | `bash ".../obsidian-wsl-cli/scripts/obsidian.sh" search "keyword"` |
| `obsidian new "Note Title"` | `bash ".../obsidian-wsl-cli/scripts/obsidian.sh" new "Note Title"` |

**非 WSL2 環境**：直接執行原本的 obsidian CLI 指令，無需包裝。

## 注意

- `obsidian.sh` 內部透過 `powershell.exe -Command "obsidian $*"` 轉發，需確認 PowerShell 可在 WSL2 中執行
