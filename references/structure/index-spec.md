# Wiki Index 規格（index-spec）

本規格定義 Vault 根目錄 `index.md` 的 append-only 清單結構與維護規則。

---

## 角色與用途

`index.md` 是 Wiki 層的 append-only 目錄清單，供 LLM 在歸檔與查詢時快速定位主題頁。

每次新建或更新主題頁後，由主對話追加一行條目。隨時間積累，同主題可能出現多條記錄。由 curator skill 定期清理。

---

## 維護者與更新時機

- **維護者**：主對話（非 sub-agent，避免並行寫入衝突）
- **更新方式**：`obsidian append vault=[vault_name] path="index.md" content="\n[條目]"`
- **更新時機**：
  - archive 完成後（新建或更新主題頁後）
  - query skill 回填總覽頁後
  - curator 清理後（整檔重建，使用管道 2 Write 工具）

---

## 條目格式

每個條目佔一行：

```
[YYYY-MM-DD] [[主題知識/[類別]/[標題]|[標題]]] — [一行摘要]（sources: N）[new|updated]
```

- `[YYYY-MM-DD]`：本次操作日期
- `[[路徑|顯示名]]`：完整路徑 wikilink
- `一行摘要`：50 字以內
- `sources: N`：該頁 sources 陣列長度
- `[new]`：本次新建的主題頁
- `[updated]`：本次 upsert 更新的既有頁

範例：
```
[2026-04-06] [[主題知識/概念/RAG|RAG]] — 檢索增強生成，結合向量搜尋與 LLM（sources: 1）[new]
[2026-04-06] [[主題知識/實體/Claude Code|Claude Code]] — Anthropic AI 編程 CLI（sources: 2）[updated]
```

---

## curator 清理規則

index.md 隨 append 積累，同主題會出現多條記錄。curator skill 定期清理：

1. 使用 Read 工具讀取整個 index.md
2. 解析所有條目，按主題分組
3. 每個主題只保留**最新日期**的條目（以 `[YYYY-MM-DD]` 排序）
4. 重新按 wiki_category 分組排序
5. 使用 Write 工具整檔重建

> curator 清理使用管道 2（Claude Code Read/Write），不走 obsidian CLI。

---

## 空白範本（init 時寫入）

初始化時若 `index.md` 不存在，使用以下空白範本：

```markdown
# Wiki Index

```

使用 obsidian CLI 寫入：
```bash
obsidian create vault=[vault_name] path="index.md" content="# Wiki Index\n"
```
