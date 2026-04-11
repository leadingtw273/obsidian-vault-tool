# SHA-256 Integrity (Minimal Implementation)

> **status**: v0.9.0-alpha（new spec）
> **scope**: quality — 品質保證
> **authority**: 本檔為 SHA-256 完整性機制的權威定義
> **inspired by**: Karpathy LLM Wiki 教程的 SHA-256 / re-ingest 機制

## Summary

每次 archive 一個 raw 檔時，必須計算該檔的 SHA-256 hash 並寫入對應 source 頁的 frontmatter。**v0.9.0-alpha 階段只做寫入，不做 lint 比對**——這是「最小實作」原則：先讓基準資料就位，比對機制留 v1.0 做。SHA 的目的是讓 agent / 人類稍後能偵測「我引用的來源是否被改過」，是長期 reliability 的基礎欄位。

## Core Concepts

1. **SHA-256**：對 raw 檔的二進位內容計算 SHA-256，得到 64 字元 hex 字串
2. **frontmatter 欄位**：source 頁的 `raw_sha256` 與 `last_verified`
3. **最小實作邊界**：v0.9 只寫入，不主動比對；v1.0 起 curator 加入比對 lint
4. **不可篡改性錨點**：所有後續品質機制（Evolution Log、re-ingest 偵測）都依賴 SHA 作為基準
5. **跨平台一致**：Linux / macOS / Windows 對同一檔案的 SHA-256 結果必須一致（無 BOM、無 line ending 標準化）

## Specification

### 1. Source 頁的 frontmatter 欄位

歷史紀錄下每個 source 頁（`歷史紀錄/{type}/{date}/NN_title.md`）的 frontmatter 必須含：

```yaml
---
title: "RAG 架構簡介"
date: 2026-04-15
source: "https://example.com/rag-article"
category: 來源紀錄
content_type: article
author: "Jane Doe"
raw_file: "raw/articles/rag-article.md"            # v0.9.0-alpha 新增
raw_sha256: "a3f8b2c1d4e5..."                      # v0.9.0-alpha 新增（64 hex）
last_verified: 2026-04-15                           # v0.9.0-alpha 新增
possibly_outdated: false                            # v0.9.0-alpha 新增
---
```

| 欄位 | 類型 | v0.9 必填 | 說明 |
|------|------|---------|------|
| `raw_file` | string | ✅ | 相對於 vault root 的 raw 檔路徑 |
| `raw_sha256` | string (64 hex) | ✅ | raw 檔的 SHA-256 hash |
| `last_verified` | date (YYYY-MM-DD) | ✅ | 最近一次計算 SHA 的日期（v0.9 = ingest 日期）|
| `possibly_outdated` | boolean | 預設 false | 來源發表 > 2 年自動標 true（見 staleness.md）|

### 2. SHA-256 計算規則

<!-- decision-id: sha-integrity-calculation-rules -->

**輸入**：raw 檔的**二進位內容**（不做任何前處理）
- ❌ 不去除 BOM
- ❌ 不標準化 line endings
- ❌ 不 trim trailing whitespace
- ❌ 不 normalize unicode

**理由**：SHA 的價值在於偵測「**任何**改動」，包括看似無害的 whitespace 變化。預處理會降低 SHA 的敏感度。

**輸出格式**：64 字元小寫 hex 字串，無前綴（不加 `sha256:`）。

**實作建議**（給 agent / 人類執行時參考）：

```bash
# Linux / macOS
sha256sum raw/articles/rag-article.md | cut -d ' ' -f 1

# Python
import hashlib
with open('raw/articles/rag-article.md', 'rb') as f:
    print(hashlib.sha256(f.read()).hexdigest())

# Node.js
const crypto = require('crypto');
const fs = require('fs');
const hash = crypto.createHash('sha256');
hash.update(fs.readFileSync('raw/articles/rag-article.md'));
console.log(hash.digest('hex'));
```

obsidian CLI 沒有直接的 SHA 計算命令，因此這一步由 record-writer agent 透過 Bash sub-call 執行。

### 3. archive Step 1 的 SHA 整合

archive 流程的 Step 1（讀取 raw 檔）必須擴展為兩個動作：

```
Step 1.0: 讀取 raw 檔內容（既有，wiki-writer 用）
Step 1.1: 計算 raw 檔 SHA-256（v0.9.0-alpha 新增）
  → 結果暫存於 archive context 的 raw_sha256 變數
  → 後續 record-writer 寫入 source 頁時引用
```

實作見 v0.9.0-beta 的 `agents/record-writer.md` 更新。**v0.9.0-alpha 只定義 spec，不動 agent**。

### 4. 最小實作的範圍邊界（v0.9 vs v1.0）

<!-- decision-id: sha-integrity-scope-v09 -->

| 機制 | v0.9.0-alpha | v0.9.0-beta | v1.0 |
|------|------------|-------------|------|
| 計算 SHA 並寫入 source 頁 | spec only | ✅ 實作 | ✅ |
| record-writer 寫入 raw_file / raw_sha256 / last_verified | spec only | ✅ 實作 | ✅ |
| frontmatter 欄位驗證（curator 確認 v0.9 vault 的 source 頁有 SHA 欄位）| ❌ | ✅ | ✅ |
| **lint 比對**（重算 SHA 比對 frontmatter 值）| ❌ | ❌ | ✅ |
| **SOURCE MODIFIED 警告**（hash 變動時觸發）| ❌ | ❌ | ✅ |
| **re-ingest 自動觸發**（hash 變動時自動重新處理）| ❌ | ❌ | ✅ |

**為什麼 v0.9 不做比對**：

1. **寫入是廉價、比對是昂貴**：寫入只是 archive Step 多一行 `sha256sum`；比對需要 curator 升級、UI 提示流程、re-ingest 連動，是完整 feature。
2. **無基準資料無法比對**：v0.9 之前的 vault 沒有 SHA 欄位，比對機制需要等所有 source 頁都有基準才有意義。
3. **agent reliability 優先**：v0.9 的最大目標是讓 agent 有完整的後續品質機制可依賴。寫入 SHA 是讓 agent「未來能比對」的基礎條件，但 agent 在 v0.9 階段不會真的執行比對。

### 5. 與其他 spec 的整合點

| 整合對象 | 整合內容 |
|---------|---------|
| `governance/confidence-gating.md` | confidence 升級時不需要重新計算 SHA（SHA 只在 ingest 時算一次）|
| `governance/agent-mode.md` | agent 啟動 self-check 不檢查 SHA（成本太高）；但 self-check 必須確認 source 頁有 raw_sha256 欄位（spec 一致性）|
| `quality/staleness.md` | last_verified 是 staleness 計算的基準日期 |
| `workflow/archive-flow.md` | archive Step 1.1 計算 SHA、Step 2 record-writer 寫入 source 頁 |
| 未來 `quality/re-ingest-spec.md`（v1.0）| SHA 不一致時的 re-ingest 流程 |

### 6. 邊界 case 處理

| 情境 | v0.9 處理 |
|------|---------|
| raw 檔不存在（路徑錯誤） | archive Step 1 報錯，整個流程中止 |
| raw 檔是 binary（圖片、PDF）| **正常計算 SHA**，binary 也適用 SHA-256 |
| raw 檔超大（> 100 MB）| 正常計算（SHA 是 streaming，記憶體成本低）|
| 同一 raw 檔被 ingest 兩次 | 第二次計算的 SHA 應與第一次相同；source 頁已存在則跳過或更新 last_verified（行為由 archive-flow.md 定義）|
| raw 檔已移到 archived/ 後計算 | record-writer 應在「移動 raw 之前」寫入 source 頁，避免路徑混淆 |

## Examples

### Example 1：典型 archive 流程

```
1. 使用者：archive raw/articles/rag-paper.md
2. archive Step 1.0: 讀取 raw 檔內容
3. archive Step 1.1: 計算 SHA → "a3f8b2c1d4e5f6789..."（64 hex）
4. archive Step 2: record-writer 寫入 歷史紀錄/文章/2026-04-15/01_RAG架構簡介.md
   frontmatter 含：
     raw_file: "raw/articles/rag-paper.md"
     raw_sha256: "a3f8b2c1d4e5f6789..."
     last_verified: 2026-04-15
5. archive Step 5: 移動 raw/articles/rag-paper.md → raw/archived/rag-paper.md
6. log.md 追加 ingest 條目（含 touched_specs: [sha-integrity]）
```

### Example 2：v1.0 的 SOURCE MODIFIED 偵測（為 v0.9 預留）

```
（v1.0 才實作，此處為設計示意）

1. 使用者：lint
2. curator 掃描 歷史紀錄/ 下所有 source 頁
3. 對每個 source 頁讀 raw_sha256，重算 raw_file 的 SHA
4. 若不一致：
   ⚠ SOURCE MODIFIED: 歷史紀錄/文章/2026-04-15/01_RAG架構簡介.md
     raw_file: raw/archived/rag-paper.md
     stored_sha256: a3f8b2c1...
     current_sha256: 9b7e6d5c...
     last_verified: 2026-04-15 (40 days ago)
   建議：執行 re-ingest 更新 source 頁
5. 寫入 outputs/lint/2026-05-25.md
```

注意：v0.9 不執行步驟 3-5，但 frontmatter 已有所有必要欄位，v1.0 升級不需要回頭補資料。

### Example 3：邊界 case — binary raw

```
1. 使用者：archive raw/pdfs/transformer-paper.pdf
2. archive Step 1.0: 讀取 PDF binary 內容（不解析）
3. archive Step 1.1: 計算 SHA → "f1e2d3c4..."
4. record-writer 寫入 歷史紀錄/文件/2026-04-15/01_Transformer.md
   raw_sha256 與 text 來源用相同欄位
5. wiki-writer 處理時可能無法直接抽 concepts（PDF 需要先轉 text，這是另一個機制）
6. 但 SHA 機制完全相同
```

## Rationale

### 為什麼 v0.9 必須做 SHA 而不是 v1.0 一次做完

Brain Trust v3+v4 三方有過分歧：Codex 主張 SHA 延 v1.0（成本論點），Gemini 與 Claude 主張 v0.9 必做（不可篡改性錨點）。最終仲裁：**v0.9 做最小實作（寫入但不比對）**。

理由：
- **SHA 是「未來能力」的前提**：v1.0 的 lint 比對、re-ingest、Evolution Log 自動判定都依賴 SHA。如果 v0.9 不寫入，這些機制 v1.0 啟用時要回頭補所有 source 頁的 SHA，是極大的回填成本。
- **寫入成本極低**：archive Step 加一個 Bash sub-call `sha256sum` 是 ~5 ms 的事。
- **比對成本不該打包進 v0.9**：完整的「偵測 → 警告 → re-ingest」流程是 ~3 個 session 的工作量，不該擠進 alpha。

### 為什麼不對 raw 內容做預處理

預處理（去 BOM、標準化 line ending、trim）會讓 SHA 對「無害變動」不敏感。但「無害」是主觀判斷——例如：
- 作者把 LF 改 CRLF：對人類無害，但對某些 parser 可能改變語意
- 移除 BOM：對 UTF-8 無害，但改變了二進位內容

SHA 的價值在於「**任何位元變動都會被偵測**」，這個保證才有審計意義。預處理會破壞這個保證。

如果使用者真的想忽略某類無害變動，應該在「比對結果處理」階段做（v1.0 可加 `--ignore-whitespace` 旗標），而不是在 SHA 計算時做。

### 為什麼 SHA 寫在 source 頁而不是獨立索引

替代設計：建立一個 `vault/sha-index.json` 集中存所有 SHA。

不採用的理由：
- **同步問題**：vault 的 source 頁與獨立索引可能不同步（手動編輯、git pull 衝突）
- **可讀性**：source 頁的 frontmatter 是人類可讀的，獨立索引是黑盒
- **單一真相**：source 頁本身就是「這個 raw 檔被處理過」的真相，SHA 應該屬於它的元資料

獨立索引留給 v1.0 的「正式索引層」（為效能而非為可讀性），且必須與 source 頁的 SHA 欄位**保持一致**（透過 checksum-map 機制）。

### 為什麼 last_verified 在 v0.9 等於 ingest 日期

v0.9 不做比對，所以「最近一次驗證」就是「最近一次 ingest」。v1.0 之後 lint 比對通過時也會更新 last_verified 為比對日期。這個欄位的語意是「我們相信 raw_sha256 在這個日期是準確的」。

### 與 Karpathy 教程的差異

Karpathy 教程的 lint.py 第 6 項就是 SHA-256 完整性檢查（會主動比對並警告 SOURCE MODIFIED）。obsidian-vault-tool 的 v0.9 只做寫入不做比對，這是**有意的延後**——不是設計分歧。

v1.0 的 curator 會吸收 Karpathy 的完整檢查，加入 obsidian-vault-tool 的雙樹結構特化（例如比對「歷史紀錄與主題知識的 SHA 一致性」這種 Karpathy 沒有的情境）。

## Cross References

- `references/governance/confidence-gating.md` — confidence 機制（不直接依賴 SHA，但 v1.0 的 Evolution Log 自動判定需要 SHA）
- `references/governance/agent-mode.md` — agent self-check 不檢查 SHA 但檢查 SHA 欄位存在
- `references/quality/staleness.md`（同 commit 新增）— last_verified 是 staleness 的基準
- `references/quality/contradictions.md`（同 commit 新增）— 矛盾偵測時可參考 SHA 變動歷史
- `references/workflow/archive-flow.md`（同 commit 新增）— archive Step 1.1 SHA 計算
- v0.9.0-beta 將更新 `agents/record-writer.md` 加入 SHA 寫入 step
- v1.0 預定新增 `references/quality/re-ingest-spec.md` 描述 SHA 變動觸發的 re-ingest 流程
