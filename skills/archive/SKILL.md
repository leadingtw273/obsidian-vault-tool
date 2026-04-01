---
name: archive
description: >
  將任何來源歸檔至 Obsidian Vault。預設同時產生來源記錄與知識筆記。
  支援模式：完整歸檔（預設）、只記錄來源（record-only）、只寫知識（knowledge-only）。
  觸發情境：使用者說「歸檔」、「存起來」、「整理」、「記錄」、「只要知識」、「只記錄來源」，
  或貼入 URL 要求整理時使用。
allowed-tools: ["Read", "Glob", "Grep", "Agent"]
---

# Archive

透過 record-writer agent（建立來源記錄）與 knowledge-writer agent × N（撰寫知識筆記）完成歸檔。

## 共用前置

> 以下步驟由主對話執行，不可委派 sub-agent：

1. 讀取 Vault `CLAUDE.md`，提取 `vault_path`、`vault_name`、`plugin_version`
2. 確認 `plugin_version` 與當前版本一致
3. 這些值必須由主對話傳入每個 sub-agent prompt（sub-agent 無法自行讀取）

---

## 路由邏輯

根據使用者意圖，讀取並執行對應的命令檔案：

| 使用者意圖 | 執行檔案 |
|-----------|---------|
| 歸檔、存起來、整理（預設） | `commands/full-archive.md` |
| 只記錄來源、存個紀錄 | `commands/record-only.md` |
| 只要知識、不需要來源記錄 | `commands/knowledge-only.md` |

## 執行方式

判斷使用者意圖後，讀取對應的 `commands/*.md` 檔案，並嚴格按照其中的步驟執行。

```
PLUGIN_ROOT 為此 SKILL.md 所在目錄：${CLAUDE_PLUGIN_ROOT}/skills/archive
```
