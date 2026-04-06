---
name: lint
description: >
  Obsidian Vault Wiki 健康檢查。掃描 主題知識/ 下所有筆記，檢測孤兒頁面、
  缺失交叉引用、過期條目、未解決矛盾、缺漏的概念頁、index.md 一致性等問題，
  輸出修補建議報告。
  觸發情境：使用者說「lint」、「檢查 wiki」、「wiki 健康度」、「wiki 體檢」、
  「看看 wiki 有什麼問題」時使用。
allowed-tools: ["Read", "Glob", "Grep", "Bash", "Agent"]
---

# Lint

對 Obsidian Vault 的 Wiki 層執行健康檢查，偵測結構與內容層面的問題，輸出修補建議。

## 共用前置

> 以下步驟由主對話執行，不可委派 sub-agent：

1. 讀取 Vault `CLAUDE.md`，提取 `vault_path`、`vault_name`、`plugin_version`
2. 確認 `plugin_version` 與當前版本一致
3. 這些值必須由主對話傳入每個 sub-agent prompt（sub-agent 無法自行讀取）

## 執行

讀取並執行 `commands/full-lint.md` 中的步驟。

PLUGIN_ROOT 為此 SKILL.md 所在目錄：${CLAUDE_PLUGIN_ROOT}/skills/lint
