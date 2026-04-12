---
name: synthesis-writer
description: "v1.0 預留 — 跨多 concept 的深度合成 agent。v0.9 不實作，由 reflect skill 直接產出 gap report。"
skills: []
tools: Read, Glob, Grep, Bash
model: sonnet
color: blue
status: v1.0-reserved
---

# synthesis-writer（v1.0 預留）

> **v0.9.0-rc 不實作本 agent。** 此檔為 v1.0 預留的設計骨架。
>
> Brain Trust RC 檢核結論（2026-04-12，Claude + Codex 2/2 CONVERGE）：
> v0.9 無 Stage 2 觸發場景，gap report 由 reflect skill 直接產出。
> synthesis-writer 推遲到 v1.0。

## v1.0 設計方向

### 職責定義

| Agent | 職責 | 觸發場景 |
|-------|------|---------|
| **wiki-writer** | upsert **單一** concept 頁（1:N 來源 → 1 concept）| archive / knowledge-only |
| **synthesis-writer** | 跨**多個** concept 合成（N concept → 1 synthesis）| reflect Stage 2 |

### 與 wiki-writer 的邊界

wiki-writer 在 merge 時已有「追加補充段落」的能力，但它只修改**被 ingest 的那個 concept 頁**。

synthesis-writer 的不同：
- **讀取多個 concept 頁**的 Definition / Key Points
- **對比多頁之間的關係**（而非只看單一 concept vs 新 source）
- **產出全新的 synthesis 頁**（寫入 `主題知識/總覽/` 或 `outputs/reflect/synthesis-draft-{slug}.md`）

### v1.0 觸發條件

只有 reflect Stage 2（深度合成）會呼叫 synthesis-writer。
query 回填仍走 wiki-writer（wiki_category 強制為總覽）。

### v1.0 輸入

- **候選主題組**：reflect Stage 1 發現的「隱性關聯」配對
- **相關 concept 頁清單**：每個候選的完整頁面路徑
- **interaction_mode**：human / agent
- **Vault 路徑 / 名稱 / 日期**

### v1.0 輸出

```
outputs/reflect/synthesis-draft-{topic-slug}.md
```

草稿形式，需人類確認後才可回填到 `主題知識/總覽/`。

### 為什麼 v0.9 不需要

1. v0.9 的 reflect 只做 Stage 0（反向檢驗）+ Stage 1（輕量模式掃描）+ Stage 3（Gap Analysis）
2. Stage 0 / 1 / 3 的產出都是**報告**（warnings / pattern / gap），不需要「合成」
3. reflect 直接用 Write 工具產出 outputs/reflect/ 檔案即可
4. synthesis-writer 的真正價值在 Stage 2——「把隱性關聯寫成一篇有結論的 synthesis 頁」——但 Stage 2 需要 20+ sources 累積才有意義

### 何時從預留變為實作

當以下條件**全部滿足**時，synthesis-writer 從預留變為實作：
- vault 累積 ≥ 20 個外部 sources
- reflect Stage 1 找到 ≥ 3 個「隱性關聯」候選
- 正式索引層（v1.0 升級）已就位
- leadi 或朋友反饋「query 回填的總覽頁品質不夠，需要更深層的跨概念合成」
