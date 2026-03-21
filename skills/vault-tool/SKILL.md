---
name: vault-tool
description: >
  必須使用此 skill 來操作 obsidian-vault-tool 的 Vault 架構設定，包括建立新 Vault（init）、
  更新 plugin 設定版本（update）、修復或重置損壞的設定（reset）、清除 plugin 設定或刪除 Vault（delete）。
  不要自行建立資料夾或寫入設定——此 skill 有專屬的互動精靈流程與設定規格，自行操作會產生不相容的結構。
  以下任何情況都必須立即使用此 skill，不要嘗試直接解決：
  使用者想開始使用 Obsidian 或建立知識庫；說 vault 設定壞了或 templates 不見了；
  想更新 plugin 版本或同步 CLAUDE.md；說不想用這個 plugin 了或要清掉設定；
  要刪除整個 vault；說「init」「reset」「update」「delete」且涉及 Obsidian 或 vault。
allowed-tools: ["Read", "Write", "Edit", "Glob", "Grep", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/check-deps.sh:*)", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/check-init-status.sh:*)", "Bash(${CLAUDE_PLUGIN_ROOT}/skills/obsidian-wsl-cli/scripts/obsidian.sh:*)"]
---

# vault-tool 路由器

## 共用前置

1. 讀取 `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json` 取得 `version` 欄位，記錄為 `plugin_version`
2. 偵測 WSL2 環境：若 vault 路徑以 `/mnt/` 開頭，判定為 WSL2 環境

---

## 意圖解析

根據使用者輸入判定 command：

| 使用者意圖 | Command |
|-----------|---------|
| 建立、初始化、設定、新建、create、init | `init` |
| 更新、升級、同步設定、update | `update` |
| 重置、還原、修復、reset | `reset` |
| 刪除、移除、清除、delete、remove | `delete` |

**若無法判定**，列出選單讓使用者選擇：

> 您好！請問您要對知識庫進行哪種操作？
>
> 1. **init**：建立全新知識庫（資料夾結構、模板、CLAUDE.md）
> 2. **update**：更新現有知識庫設定至最新版本（保留自訂內容）
> 3. **reset**：重置知識庫設定（覆蓋所有模板與設定，筆記不動）
> 4. **delete**：刪除知識庫管理設定或整個 Vault

---

## 執行對應 Command

判定 command 後，讀取對應檔案並按其流程執行：

```
${CLAUDE_PLUGIN_ROOT}/skills/vault-tool/commands/[command].md
```

路由器本身不包含操作細節，所有流程定義在各 command 檔案中。
