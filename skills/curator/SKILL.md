---
name: curator
description: >
  Obsidian Vault Wiki 策展人。掃描 主題知識/ 下所有筆記，執行 14 項健康檢查
  （孤兒頁面、缺失交叉引用、過期條目、未解決矛盾、缺漏的概念頁、index.md 一致性、
  confidence/staleness/contradictions/wikilink 格式/high_candidate/tag 品質）與結構演進
  （偵測並執行主題頁面升級為目錄結構），輸出修補建議報告至 outputs/lint/<date>.md。
  觸發情境：使用者說「lint」、「檢查 wiki」、「wiki 健康度」、「wiki 體檢」、
  「看看 wiki 有什麼問題」、「整理 wiki」、「wiki 結構檢查」、「升級主題」、
  「檢查標籤」、「tag 品質」時使用。
allowed-tools: ["Read", "Write", "Edit", "Glob", "Grep", "Bash", "Agent"]
---

# Curator（策展人）

對 Obsidian Vault 的 Wiki 層執行健康檢查與結構演進。

**職責**：
- **巡檢**（原 lint）：孤兒頁面、缺失交叉引用、過期條目、未解決矛盾、缺漏概念頁、index.md 一致性
- **結構演進**：偵測符合升級條件的主題頁面，報告後由使用者確認執行升級（單頁 → 目錄結構）
- **v0.9 新增（2i-2m）**：confidence 違規 / contradictions pending / staleness / wikilink 格式 / high_candidate 待 review
- **v0.9.0-rc 新增（2n）**：Tag 品質檢查（原 `tag-review` skill 併入 curator，不再是獨立 skill）
- **自動修補**：偵測後報告，使用者確認才執行

## 共用前置

> 以下步驟由主對話執行，不可委派 sub-agent：

1. 讀取 Vault `CLAUDE.md`，提取 `vault_path`、`vault_name`、`plugin_version`
2. 確認 `plugin_version` 與 `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json` 的 `version` 一致。若不一致：
   - 輸出警告：`⚠️ plugin 版本不一致：Vault 為 [舊版]，plugin 為 [新版]。建議先執行 vault-tool update 更新設定。`
   - **不阻塞執行**，繼續流程
3. 這些值必須由主對話傳入每個 sub-agent prompt（sub-agent 無法自行讀取）

## 執行

讀取並執行 `commands/full-curator.md` 中的步驟。

以下 command 中使用 `${CLAUDE_PLUGIN_ROOT}` 引用 plugin 根目錄。
