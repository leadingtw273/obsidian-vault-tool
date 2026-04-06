# Wiki Log 規格（log-spec）

本規格定義 Vault 根目錄 `log.md` 的結構與維護規則。

---

## 角色與用途

`log.md` 是 Wiki 層的**時間軸日誌**，以 append-only 方式記錄所有操作事件。用途包含：

- 追蹤每次 ingest 的來源與影響範圍
- 回溯 query 的問題與結論寫回記錄
- 保存 lint 的健康檢查報告
- 供 LLM 用 grep 快速查看最近活動

---

## 維護者

- **維護者**：主對話（非 sub-agent，避免並行寫入衝突）
- **操作語意**：append-only，只追加不修改既有條目

---

## 條目前綴規格

每個條目以二級標題作為前綴：

```
## [YYYY-MM-DD HH:mm] [type] | [標題]
```

- `YYYY-MM-DD HH:mm`：事件發生的本地時間
- `[type]`：事件類型，固定為 `ingest` / `query` / `lint` 三種
- `[標題]`：簡短描述（來源標題、問題摘要、或 `manual`）

---

## 條目內容格式

### ingest 條目

```markdown
## [YYYY-MM-DD HH:mm] ingest | [來源標題]
- record: [[歷史紀錄/[type]/[YYYY-MM-DD]/[序號]_[概述]]]
- new: [[主題知識/[類別]/主題A]], [[主題知識/[類別]/主題B]]
- updated: [[主題知識/[類別]/主題C]]
```

| 欄位 | 說明 |
|------|------|
| `record:` | 本次 record-writer 寫入的來源記錄 wikilink |
| `new:` | 本次新建的知識頁 wikilink 列表（逗號分隔） |
| `updated:` | 本次 upsert 更新的既有知識頁 wikilink 列表 |

若無新建頁則省略 `new:` 行，若無更新頁則省略 `updated:` 行。

### query 條目

```markdown
## [YYYY-MM-DD HH:mm] query | [問題摘要]
- 讀取頁面：[[主題知識/[類別]/主題A]], [[主題知識/[類別]/主題B]]
- 結論：寫回 [[主題知識/總覽/XXX]]
```

或僅回覆對話時：

```markdown
## [YYYY-MM-DD HH:mm] query | [問題摘要]
- 讀取頁面：[[主題知識/[類別]/主題A]]
- 結論：僅回覆對話，未寫入 Wiki
```

### lint 條目

```markdown
## [YYYY-MM-DD HH:mm] lint | manual
- 矛盾：[[主題知識/[類別]/主題D]] vs [[主題知識/[類別]/主題E]]
- 孤兒頁面：[[主題知識/[類別]/主題F]]
- 缺失交叉引用：[[主題知識/[類別]/主題G]]
```

若某項目無問題則省略該行（例如無矛盾則不寫 `矛盾:` 行）。

---

## Grep 快速查詢

所有條目標題格式統一為 `## [YYYY-MM-DD` 開頭，可用 grep 工具解析：

```bash
# 查看最近 5 筆事件
grep "^## \[" log.md | tail -5

# 查看所有 ingest 事件
grep "^## \[.*\] ingest" log.md

# 查看今日活動
grep "^## \[2026-04-05" log.md
```

---

## 空白範本（init 時寫入）

初始化時若 `log.md` 不存在，寫入以下空白範本：

```markdown
# Wiki Log

<!-- append-only：只追加，不修改既有條目 -->
<!-- 格式：## [YYYY-MM-DD HH:mm] [ingest|query|lint] | [標題] -->

```

> 範本結尾保留一個空行，方便後續 append 操作直接換行追加。

### 寫入命令（init 時）

```bash
obsidian create vault=[vault_name] path="log.md" content="# Wiki Log\n\n<!-- append-only：只追加，不修改既有條目 -->\n<!-- 格式：## [YYYY-MM-DD HH:mm] [ingest|query|lint] | [標題] -->\n"
```

### 追加條目命令（archive / query / lint 後）

```bash
obsidian append vault=[vault_name] path="log.md" content="## [YYYY-MM-DD HH:mm] ingest | [來源標題]\n- record: [[歷史紀錄/...]]\n- new: [[主題知識/...]]\n"
```
