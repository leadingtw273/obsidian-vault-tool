# 一致性邊界規格

定義 plugin 各操作的一致性保證層級，明確區分「必須同步成功」與「可延後補齊」的操作邊界，
以及崩潰後的恢復策略。

---

## 設計原則

由於 plugin 執行在純 Markdown + obsidian CLI 環境下，無法實現真正的事務（transaction）。
因此採用「**弱一致性 + 可偵測 + 可修復**」策略：

1. **強一致操作（MUST-SYNC）**：同批次內必須全部成功，否則標記為失敗，raw 檔保留
2. **弱一致操作（MAY-DEFER）**：失敗不阻塞主流程，由 curator 事後偵測並補齊
3. **崩潰恢復（RECOVERY）**：下一次歸檔或 curator 巡檢時，可偵測半成品狀態並引導修復

---

## 強一致操作（MUST-SYNC）

以下操作在同一個 archive 流程內**必須全部成功**，任一失敗則：

- raw 檔**不移動**至 raw/archived/
- 該 raw 檔標記為失敗，寫入完成通知
- 主對話繼續處理其他 raw 檔（不阻塞整批次）
- 已部分寫入的檔案**保留**，等待下次重試或使用者手動清理

<!-- consistency-id: must-sync-operations -->

| ID | 操作 | 所在步驟 | 失敗影響 |
|----|------|---------|---------|
| MS1 | 寫入歷史紀錄檔（含 frontmatter + 總結 + 反向連結） | record-writer Step 6 | raw 檔標記失敗，不繼續 wiki-writer |
| MS2 | 首次建立的知識筆記寫入（frontmatter + 正文） | wiki-writer Step 5A | 該主題記為失敗，其他主題繼續 |
| MS3 | Merge 模式的 frontmatter 更新（sources、updated） | wiki-writer Step 5B | 頁面可能 frontmatter 損壞，curator 需偵測 |
| MS4 | 同批次父子主題的層級關係建立 | full-archive Step 1.6 + wiki-writer | 父先寫、子後寫，父失敗則子不執行 |

### MS1-MS2 的原子性保證

- record-writer 的 Step 6 寫入失敗 → 熔斷，不進入 wiki-writer
- wiki-writer 的 Step 5A 新建失敗 → 熔斷並回報，主對話決定是否重試
- 由於 obsidian CLI 的 `create` 指令本身是原子操作（要麼整檔寫入成功，要麼失敗），
  單檔層級的原子性由 CLI 保證

### MS3 的特殊處理（merge 模式）

merge 模式涉及多次 `eval + processFrontMatter` 呼叫，無法保證整體原子性。緩解策略：

1. **失敗即停**：任一 eval 失敗立即中止後續 eval
2. **記錄已完成的欄位**：在 wiki-writer 執行紀錄中標註哪些欄位已更新
3. **curator 偵測**：curator 2d（未解決矛盾）與 2c（過期 updated）可間接偵測半成品

---

## 弱一致操作（MAY-DEFER）

以下操作失敗時**不阻塞**主流程，由 curator 事後補齊：

<!-- consistency-id: may-defer-operations -->

| ID | 操作 | 所在步驟 | 補救機制 |
|----|------|---------|---------|
| MD1 | index.md 條目追加 | full-archive Step 4 | curator 2f（index.md 對照）偵測並補齊 |
| MD2 | log.md 條目追加 | full-archive Step 5 | append-only 天生容錯；最壞只少一條記錄 |
| MD3 | 交叉連結 wikilink 置換 | wiki-writer Step 6 | curator 2b（缺失交叉引用）偵測並補齊 |
| MD4 | tags 更新（merge 模式） | wiki-writer Step 5B-6 | tag-review skill 可獨立觸發補齊 |
| MD5 | aliases 累積 | wiki-writer Step 5B-5 | curator 2b 間接偵測（若漏 alias 導致孤兒頁） |

### 設計理由

- **index.md / log.md 為 append-only**：單行失敗不影響檔案完整性，curator 可重建
- **交叉連結與 tags**：這些是「連結品質」而非「核心資料」，延遲補齊不影響 Vault 可用性
- **curator 已涵蓋全部偵測**：8 項檢查對應到每種半成品狀態

---

## 崩潰恢復（RECOVERY）

下一次歸檔或 curator 巡檢時，可依以下規則偵測半成品狀態：

<!-- consistency-id: recovery-rules -->

### R1：raw 檔未移動 + 歷史紀錄已建立

**症狀**：`raw/xxx.md` 仍存在，但 `歷史紀錄/[type]/[date]/[seq]_[概述].md` 已寫入

**可能原因**：Step 1 完成但 Step 6（移動 raw）前崩潰

**恢復動作**：
1. 下次 archive 掃描 raw/ 時會重複處理該檔
2. record-writer Step 4 重複檢查會發現 source 已歸檔，觸發「來源重複」友善終止
3. 主對話將該 raw 檔移至 raw/archived/（視為已存在）

### R2：歷史紀錄存在 + 對應知識筆記不存在

**症狀**：歷史紀錄的 `sources:` 引用了某知識筆記，但該知識筆記檔案不存在

**可能原因**：record-writer 成功但 wiki-writer 中途崩潰

**恢復動作**：
1. curator 2f（index.md 對照）會偵測到 index 遺漏
2. 使用者可觸發 knowledge-only 模式，從歷史紀錄重新生成知識筆記

### R3：知識筆記 frontmatter 半成品

**症狀**：頁面 frontmatter 缺少必要欄位或值為異常狀態（如 `sources: null`）

**可能原因**：merge 模式下 eval 更新中途失敗

**恢復動作**：
1. curator 在 Step 1 讀取頁面時偵測 frontmatter 結構
2. 若發現 schema 異常，記入新類別 `broken_frontmatter[]`
3. 輸出報告時提示使用者手動修復或觸發 tag-review 重建

### R4：父目錄已建立 + 子主題未寫入

**症狀**：`主題知識/[cat]/[parent]/` 目錄存在，但該目錄下除 `parent.md` 外無其他檔案

**可能原因**：Step 1.6 層級映射完成、父主題寫入成功，但子主題 wiki-writer 失敗

**恢復動作**：
1. curator 2g（結構升級偵測）會偵測到「目錄型主題但無子項」
2. 提示使用者該結構可能為半成品

---

## 與既有機制的對應

| 一致性邊界規則 | 由哪個檢查機制偵測 |
|--------------|------------------|
| MS1 失敗 | record-writer 熔斷輸出 |
| MS2 失敗 | wiki-writer 內部驗證（Step 9） |
| MS3 失敗 | curator 2d（矛盾）/ 2c（過期） |
| MD1 漏條目 | curator 2f（index.md 對照）|
| MD3 漏連結 | curator 2b（缺失交叉引用）|
| MD4 tag 異常 | tag-review skill |
| R1-R4 半成品 | curator Step 1 + 新增 `broken_frontmatter[]` |

---

## curator 整合（補充項目）

curator Step 1 掃描頁面時，應額外偵測以下半成品狀態：

<!-- consistency-id: curator-halfstate-detection -->

1. **R3 偵測**：讀取每個頁面的 frontmatter 後，驗證必要欄位是否完整（至少 `title`、`date`、`wiki_category`）
2. **R4 偵測**：對每個 `type: topic-hub` 目錄，檢查其下是否有至少一個子頁面
3. **R1/R2 偵測**：交叉比對 `歷史紀錄/` 與 `主題知識/` 的 sources 引用關係

這些檢查可加入 curator 既有的 8 項檢查中，或作為 Step 1 的延伸。
實作細節見 curator skill 後續更新（Phase 2.1 之後的任務）。
