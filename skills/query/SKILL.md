---
name: query
description: >
  針對 Obsidian Vault 的 Wiki（主題知識/）提問，讀取相關主題頁並綜合回答。
  可選擇將答案回填為 Wiki 的 總覽/ 筆記，讓探索成果進入累積迴圈。
  觸發情境：使用者說「查一下」、「wiki 裡有沒有」、「整理一下 X 主題」、
  「問問 wiki」、「從 vault 找 X」、「關於 Y 我之前有歸檔什麼」時使用。
allowed-tools: ["Read", "Glob", "Grep", "Bash", "Agent"]
---

# Query

對 Obsidian Vault 的 Wiki 層（主題知識/）提出問題，讀取相關主題頁並綜合回答。
可選擇將答案回填至 主題知識/總覽/ 作為新的 Wiki 筆記。

## 共用前置

> 以下步驟由主對話執行，不可委派 sub-agent：

1. 讀取 Vault `CLAUDE.md`，提取 `vault_path`、`vault_name`、`plugin_version`
2. 確認 `plugin_version` 與當前版本一致
3. 這些值必須由主對話傳入每個 sub-agent prompt（sub-agent 無法自行讀取）

## 執行

讀取並執行 `commands/ask.md` 中的步驟。

以下 command 中使用 `${CLAUDE_PLUGIN_ROOT}` 引用 plugin 根目錄。
