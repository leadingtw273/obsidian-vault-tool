# 路徑安全規格

定義 plugin 處理使用者輸入時的路徑清洗與驗證規則，防止路徑穿越（Path Traversal）攻擊與意外檔案損毀。

---

## 威脅模型

Plugin 處理來自以下來源的不受信任輸入：

1. **raw 檔 frontmatter**：`title`、`author`、`source` 等欄位
2. **raw 檔 body**：record-writer 從中萃取的「主題標題」「來源概述」
3. **使用者對話**：對話歸檔預處理時的 title 產生
4. **歷史紀錄回讀**：knowledge-only 模式下從歷史紀錄解析的主題列表

這些輸入最終會成為 Vault 下的檔案路徑或目錄名。若未清洗，攻擊者可：

- 使用 `../` 逃逸 Vault 根目錄，覆蓋系統檔案（如 `~/.ssh/authorized_keys`）
- 使用絕對路徑 `/etc/passwd` 直接指向系統檔案
- 使用 null byte `\0` 繞過部分字串檢查
- 使用控制字元破壞檔名顯示

---

## 不合法路徑模式

以下模式在任何可能成為檔案路徑的欄位中均視為**不合法**：

| # | 模式 | 範例 | 風險 |
|---|------|------|------|
| P1 | 相對父路徑 | `../`、`..\` | 路徑穿越 |
| P2 | 絕對路徑前綴 | `/`、`C:\`、`~/` | 跳脫 Vault 根 |
| P3 | Null byte | `\0` | 繞過字串檢查 |
| P4 | 控制字元 | `\x00`-`\x1f`（除 `\n`、`\t`） | 檔名破壞 |
| P5 | 保留檔名 | `CON`、`PRN`、`AUX`、`NUL`、`COM1`-`9`、`LPT1`-`9`（不分大小寫，含副檔名） | Windows 相容性 |
| P6 | 純點檔名 | `.`、`..`、`...` | 目錄指涉混淆 |
| P7 | 尾端空白/點 | `foo.md `、`foo.` | Windows 檔案系統異常 |

---

## 清洗規則

對於每個不合法模式，採用以下處置之一：

### 拒絕（REJECT）—— 熔斷中止

以下模式一律**拒絕**，不嘗試自動修正：

- **P1 相對父路徑**：`../` 或 `..\` 出現在欄位值的任何位置
- **P2 絕對路徑前綴**：欄位值以 `/`、`~`、`C:\` 等開頭
- **P3 Null byte**：欄位值含 `\0`
- **P6 純點檔名**：欄位值去空白後僅為 `.`、`..`、`...`

**熔斷輸出格式**：

```
⛔ 歸檔中斷：偵測到不安全路徑輸入

失敗步驟：[record-writer Step 5 / wiki-writer Step 5A]
raw 檔：[raw 檔絕對路徑]
欄位：[欄位名稱]（如 title、主題標題）
值：[引用前 100 字元]
違反模式：[P1-P7 編號與名稱]

這可能是路徑穿越攻擊或輸入錯誤。請檢查 raw 檔內容後重新觸發歸檔。
```

### 自動替換（SANITIZE）—— 無感修正

以下模式可**自動替換**，不中斷流程：

- **目錄分隔符**：`/` → `-`、`\` → `-`（既有規則延續）
- **P4 控制字元**：直接移除
- **P5 保留檔名**：在檔名後加 `_note`（如 `CON.md` → `CON_note.md`）
- **P7 尾端空白/點**：strip 右側 `.` 和空白字元

### 驗證（VERIFY）—— 二次確認

清洗後仍需驗證最終路徑落在允許的 Vault 子目錄內：

**允許的寫入根目錄白名單**：
- `[vault_path]/raw/`
- `[vault_path]/raw/archived/`
- `[vault_path]/歷史紀錄/`
- `[vault_path]/主題知識/`
- `[vault_path]/templates/`
- `[vault_path]/index.md`
- `[vault_path]/log.md`
- `[vault_path]/CLAUDE.md`

**驗證方法**：
1. 構建最終絕對路徑 `target_abs = realpath([vault_path] + relative_path)`
2. 構建 vault 根絕對路徑 `vault_abs = realpath([vault_path])`
3. 確認 `target_abs` 以 `vault_abs/` 或白名單中的子路徑為前綴
4. 若不匹配 → 熔斷（視為 P1/P2 攻擊）

---

## 應用位置

以下步驟必須實施路徑安全檢查：

### record-writer Step 2（欄位驗證）

對 raw frontmatter 的 `title`、`source`、`author` 欄位執行 REJECT 檢查：

```
for field in [title, source, author]:
    value = raw_frontmatter[field]
    if matches_any([P1, P2, P3, P6], value):
        reject_and_abort(field, value)
```

### record-writer Step 5（分析與路徑構建）

對萃取出的「主題標題」「來源概述」執行完整清洗：

1. REJECT 檢查（P1/P2/P3/P6）
2. SANITIZE 處理（`/`、`\`、P4、P5、P7）
3. VERIFY 最終路徑在白名單內

### wiki-writer Step 5A（新建路徑決定）

對最終寫入路徑執行 VERIFY：

```
target_path = [由呼叫方提供 或 Step 4 匹配 或 預設]
full_path = [vault_path]/[target_path]
if not verify_in_whitelist(full_path):
    reject_and_abort("target_path", target_path)
```

### full-archive Step -1.4（對話歸檔 frontmatter 產生）

對使用者稱呼、對話摘要等欄位執行 SANITIZE。

---

## 實作提示

### Shell 檢查範例

```bash
# P1 相對父路徑檢查
if echo "$value" | grep -qE '(\.\./|\.\.\\)'; then
    echo "⛔ P1 violation: parent path reference detected"
    exit 1
fi

# P2 絕對路徑前綴檢查
case "$value" in
    /*|~*|[A-Z]:\\*) echo "⛔ P2 violation"; exit 1;;
esac

# P3 Null byte 檢查（需用 od/xxd）
if printf '%s' "$value" | od -c | grep -q '\\0'; then
    echo "⛔ P3 violation"
    exit 1
fi

# VERIFY 路徑白名單
target_abs=$(realpath "$vault_path/$relative_path" 2>/dev/null)
vault_abs=$(realpath "$vault_path")
case "$target_abs" in
    "$vault_abs"/*) : ;;  # OK
    *) echo "⛔ outside vault"; exit 1;;
esac
```

### LLM 自我檢查提示

由於 agents 透過 LLM 而非純 shell 執行，清洗邏輯可在 prompt 中要求 agent 自行檢查：

> 在決定任何檔案路徑前，對輸入欄位執行 path-safety-spec 的 REJECT/SANITIZE/VERIFY 三階段檢查。若發現不合法模式，依規格輸出熔斷訊息後終止。

---

## 測試案例（供後續 Phase 3 回歸測試集使用）

| 案例 | 輸入 | 預期結果 |
|------|------|---------|
| T1 | `title: ../../../etc/passwd` | REJECT（P1） |
| T2 | `title: /etc/shadow` | REJECT（P2） |
| T3 | `title: A/B 測試` | SANITIZE → `A-B 測試` |
| T4 | `title: CON` | SANITIZE → `CON_note` |
| T5 | `title: ../../正常主題` | REJECT（P1） |
| T6 | `title: foo.md ` | SANITIZE → `foo.md` |
| T7 | `title: .` | REJECT（P6） |
| T8 | 正常 `title: RAG 架構` | PASS |
