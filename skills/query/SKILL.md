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

1. 讀取 Vault `CLAUDE.md`，提取 `vault_path`、`vault_name`、`plugin_version`、`cli_write_mode`
   - 缺 `cli_write_mode` → 預設 `cli_first`（v0.9.0 vault 相容）
2. 確認 `plugin_version` 與 `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json` 的 `version` 一致。若不一致：
   - 輸出警告：`⚠️ plugin 版本不一致：Vault 為 [舊版]，plugin 為 [新版]。建議先執行 vault-tool update 更新設定。`
   - **不阻塞執行**，繼續流程
3. 這些值必須由主對話傳入每個 sub-agent prompt（sub-agent 無法自行讀取）

### CLI Write Mode 提醒（v0.9.1）

本 skill 與 commands 中的 `obsidian create / append / eval` 範例**僅適用於 `cli_write_mode: cli_first`**。
若 `cli_write_mode: native_only`，所有寫入命令一律改用 Read/Edit/Write，
對照表見 `${CLAUDE_PLUGIN_ROOT}/references/cli-usage.md` 的「Mode 對照表」段落。
主對話必須將 `cli_write_mode` 傳入 wiki-writer prompt。

## 執行

讀取並執行 `commands/ask.md` 中的步驟。

以下 command 中使用 `${CLAUDE_PLUGIN_ROOT}` 引用 plugin 根目錄。
