# 知識庫建立精靈（init）

這是一個兩階段互動精靈，協助使用者從零建立完整的 Obsidian Vault 環境，
包含資料夾結構、模板、CLAUDE.md 與 .obsidian 設定。

---

## 階段 1：歡迎說明

向使用者說明將要建立的內容（不需等待確認，直接呈現後進入階段 2）：

> 我將透過此精靈協助您建立完整的 Obsidian 知識庫，包含：
> - 標準資料夾結構（raw/、歷史紀錄/對話/、主題知識/實體|概念|比較|總覽/、templates/）
> - 3 種筆記模板（raw、來源記錄、知識筆記）
> - index.md 與 log.md 空白範本（Wiki 目錄索引與時間軸日誌）
> - CLAUDE.md 設定檔（讓 Claude 了解此 Vault 的操作規範）

---

## 階段 2：收集資訊

若使用者已在訊息中提供了 vault 名稱或路徑，直接沿用，不需重複詢問。
只針對**尚未提供**的資訊提問：

1. **知識庫名稱**：請問您想為知識庫取什麼名稱？（例如 `my-vault`、`personal-notes`）
2. **存放路徑**：請問知識庫要建在哪個目錄？（例如 `/mnt/c/Users/xxx/Documents/my-vault`）

收到所有必要資訊後，**在開始建立前**向使用者確認：

> 請確認以下設定：
> - **知識庫名稱**：`[vault_name]`
> - **存放路徑**：`[vault_path]`（WSL2 環境時同時顯示 Windows 路徑）
>
> 確認後開始建立？(y/n)

等待使用者確認後才繼續階段 3。

收到答案後：

- 記錄 `vault_name` 與 `vault_path`
- 偵測作業系統環境：
  - 若 `vault_path` 以 `/mnt/` 開頭，判定為 WSL2 環境
  - WSL2 路徑轉換規則：`/mnt/c/Users/...` → `C:\Users\...`
  - 記錄 `vault_path_windows`（WSL2 環境才有）
- 沿用路由器（SKILL.md）共用前置讀取的 `plugin_version`；若未傳入，讀取 `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json` 取得 `version` 欄位

確認路徑不存在衝突：執行 `${CLAUDE_PLUGIN_ROOT}/scripts/check-init-status.sh [vault_path]`

- 若輸出 `ALREADY_INITIALIZED`：詢問使用者是否要重新初始化（覆蓋現有 CLAUDE.md）。
  同時告知也可考慮：
  - 執行「更新知識庫」（update）：保留自訂內容，更新 plugin 設定
  - 執行「重置知識庫」（reset）：完全重新生成所有設定
- 若輸出 `NOT_INITIALIZED` 或路徑不存在：直接繼續

---

## 階段 3：檢查依賴

執行依賴檢查腳本：

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/check-deps.sh
```

解讀結果：

- 輸出 `INSTALLED`：繼續執行
- 輸出 `NOT_INSTALLED`：告知使用者並等待安裝：
  > 需要先安裝 `obsidian-skills` plugin 才能使用完整功能：
  > ```
  > /plugin marketplace add kepano/obsidian-skills
  > /plugin install obsidian@obsidian-skills
  > ```
  > 安裝完成後請告訴我，我們繼續建立流程。
- 輸出 `NOT_FOUND`：告知使用者可能是全新環境，引導安裝上述 plugins。

---

## 階段 4A：建立環境（資料夾結構 + Obsidian 開啟）

此階段的目標：讓 vault 資料夾存在且已在 Obsidian 中開啟，使 obsidian CLI 可用。

### 步驟 4A-1：建立資料夾結構

讀取 `${CLAUDE_PLUGIN_ROOT}/references/structure/folder-structure.md` 了解完整規格。

嘗試在 Vault 根目錄建立以下資料夾（使用 `mkdir -p`，v0.9.0-beta 起含新增資料夾）：

```
raw/
raw/archived/
raw/personal/                  # v0.9.0-beta 新增：個人寫作
歷史紀錄/對話/
歷史紀錄/個人寫作/              # v0.9.0-beta 新增：對應 raw/personal/
主題知識/實體/
主題知識/概念/
主題知識/比較/
主題知識/總覽/
templates/
outputs/                       # v0.9.0-beta 新增：產出層
outputs/queries/               # v0.9.0-beta 新增：query 答案
outputs/reflect/               # v0.9.0-beta 新增：reflect 報告
outputs/lint/                  # v0.9.0-beta 新增：curator 報告
index/                         # v0.9.0-beta 新增：極簡索引層
```

詳細目錄結構說明見 `${CLAUDE_PLUGIN_ROOT}/references/structure/folder-structure.md` 與 `${CLAUDE_PLUGIN_ROOT}/references/structure/outputs-layer.md`。

- 若建立**成功**：繼續下一步
- 若建立**失敗**（例如唯讀檔案系統），切換為引導模式：

  > 無法自動建立資料夾（可能是檔案系統權限限制）。
  > 請手動建立資料夾結構，您可以在終端機中執行以下命令：
  >
  > **Windows PowerShell：**
  > ```powershell
  > New-Item -ItemType Directory -Force -Path "[vault_path_windows]\raw\archived","[vault_path_windows]\歷史紀錄\對話","[vault_path_windows]\主題知識\實體","[vault_path_windows]\主題知識\概念","[vault_path_windows]\主題知識\比較","[vault_path_windows]\主題知識\總覽","[vault_path_windows]\templates"
  > ```
  >
  > **macOS / Linux：**
  > ```bash
  > mkdir -p "[vault_path]"/{raw/archived,"歷史紀錄/對話","主題知識"/{實體,概念,比較,總覽},templates}
  > ```
  >
  > 完成後請告訴我。

  等待使用者確認後，驗證資料夾確實存在再繼續。

### 步驟 4A-2：驗證 Obsidian 已就緒

執行 `obsidian vaults` 確認 vault 已列出。

- 若 vault **已列出**：直接繼續階段 4B
- 若 vault **未列出**：引導使用者開啟 Vault：

  > 需要先在 Obsidian 中開啟此 Vault，obsidian CLI 才能正常寫入檔案。
  >
  > 若尚未安裝 Obsidian，請先至 https://obsidian.md 下載安裝。
  >
  > 請在 Obsidian 中執行以下操作：
  > 1. 開啟 Obsidian 應用程式
  > 2. 選擇「開啟資料夾作為 Vault」（Open folder as vault）
  > 3. 選取路徑：`[vault_path]`（Windows 環境選取 `[vault_path_windows]`）
  >
  > 完成後請告訴我。

  等待使用者確認後，重新執行 `obsidian vaults` 驗證：
  - 若仍未列出，再次引導並提示確認 Obsidian 是否正在執行
  - 若已列出，繼續階段 4B

---

## 階段 4B：寫入內容（透過 obsidian CLI）

此階段的所有檔案寫入都透過 obsidian CLI，確保跨平台相容。

> ⚠️ 防呆：在執行任何 create 命令前，先執行 `obsidian vaults` 確認 vault 仍在清單中。若未列出，中止並引導使用者重新開啟 Vault（回到步驟 4A-2）。

> ⚠️ **`vault=` 必須放在 `content=` 之前。** 建議格式：`obsidian [command] vault=X path=... content=...`。若命令靜默失敗，優先檢查 `vault=` 是否在 `content=` 之後。

### 步驟 4B-1：建立模板檔案

讀取 `${CLAUDE_PLUGIN_ROOT}/references/structure/templates-spec.md` 了解完整規格。

在 `templates/` 目錄建立以下 3 個模板（不存在則建立，已存在略過）：

**`raw.md`**：
```bash
obsidian create vault=[vault_name] path="templates/raw.md" content="---\ntitle:\ndate: \"{{date}}\"\nauthor:\nsource:\ncontent_type:\n---\n\n<!-- 在此貼入原始內容 -->"
```

**`來源記錄.md`**（v0.9.0-beta：含 SHA-256 完整性 4 欄位）：
```bash
obsidian create vault=[vault_name] path="templates/來源記錄.md" content="---\ntitle:\ndate: \"{{date}}\"\nsource:\ncategory: 來源紀錄\ncontent_type:\nauthor:\nraw_file:\nraw_sha256:\nlast_verified: \"{{date}}\"\npossibly_outdated: false\n---"
```

**`知識筆記.md`**（v0.9.0-beta：含 confidence 5 欄位 + Contradictions/Evolution Log 強制段落）：
```bash
obsidian create vault=[vault_name] path="templates/知識筆記.md" content="---\ntitle:\ndate: \"{{date}}\"\nupdated: \"{{date}}\"\ntags:\n  -\naliases: []\nsources:\n  -\ncategory:\nwiki_category:\ncontent_type:\nauthor:\nconfidence: low\nsource_count: 0\ndomain_volatility: medium\nlast_reviewed: \"{{date}}\"\nhigh_candidate: false\n---\n\n## Contradictions\n\n_暫無已知矛盾。_\n\n## Evolution Log\n"
```

### 步驟 4B-2：建立 index.md / log.md / QUESTIONS.md / overview.md / index/* 系統檔

在 Vault 根目錄建立以下檔案（不存在則建立，已存在則略過）。v0.9.0-beta 起新增 4 個系統檔（QUESTIONS.md、overview.md、index/topic-index.md、index/question-index.md）。

**`index.md`**（Wiki 目錄索引空白範本）：
```bash
obsidian create vault=[vault_name] path="index.md" content="# Wiki Index\n"
```

**`log.md`**（時間軸日誌空白範本，v0.9.0-beta 條目格式更新）：
```bash
obsidian create vault=[vault_name] path="log.md" content="# Wiki Log\n\n<!-- append-only：只追加，不修改既有條目 -->\n<!-- v0.9.0-beta 格式：## [YYYY-MM-DD HH:mm] [ingest|query|curator|reflect|ask] [agent]? | [標題] -->\n<!-- 條目欄位: mode, interaction_mode, touched_specs, fail_reason, manual_fix -->\n"
```

**`QUESTIONS.md`**（v0.9.0-beta 新增，依 `references/workflow/ask-flow.md`）：
```bash
obsidian create vault=[vault_name] path="QUESTIONS.md" content="---\ntype: system-questions\ngraph-excluded: true\ncreated: \"{{date}}\"\nlast_updated: \"{{date}}\"\n---\n\n# Open Questions\n\n## Open\n\n_暫無開放問題。_\n\n## Answered\n\n_暫無已回答問題。_\n"
```

**`overview.md`**（v0.9.0-beta 新增，含待 review 清單骨架，依 `references/governance/agent-mode.md` Section 5）：
```bash
obsidian create vault=[vault_name] path="overview.md" content="---\ntype: system-overview\ngraph-excluded: true\ncreated: \"{{date}}\"\nlast_updated: \"{{date}}\"\n---\n\n# Knowledge Base Overview\n\n## Health Dashboard\n\n_本區由 reflect / curator skill 自動更新。_\n\n## 待 Review 清單（agent mode 累積）\n\n### high_candidate confidence（待人類確認升級為 high）\n\n_暫無待 review 項目。_\n\n### 同名異物（待人類裁決合併策略）\n\n_暫無待 review 項目。_\n\n### curator 建議修補（待人類執行）\n\n_暫無待 review 項目。_\n\n### 矛盾待裁決（agent 已標註，待人類降級決策）\n\n_暫無待 review 項目。_\n"
```

**`index/topic-index.md`**（v0.9.0-beta 新增，極簡索引層）：
```bash
obsidian create vault=[vault_name] path="index/topic-index.md" content="---\ntype: system-index\ngraph-excluded: true\ncreated: \"{{date}}\"\nlast_updated: \"{{date}}\"\n---\n\n# Topic Index\n\n<!-- 由 archive Step 2.8 自動更新 -->\n<!-- 格式: topic → [[歷史紀錄 paths]] + [[主題知識 paths]] -->\n"
```

**`index/question-index.md`**（v0.9.0-beta 新增）：
```bash
obsidian create vault=[vault_name] path="index/question-index.md" content="---\ntype: system-index\ngraph-excluded: true\ncreated: \"{{date}}\"\nlast_updated: \"{{date}}\"\n---\n\n# Question Index\n\n<!-- 由 archive Step 2.3 自動更新 -->\n<!-- 格式: Q-NNN → [[candidate sources]] -->\n"
```

### 步驟 4B-3：生成 CLAUDE.md

讀取 `${CLAUDE_PLUGIN_ROOT}/references/claude-md-template.md` 模板，
將以下佔位符替換為實際值：

- `{{vault_name}}` → vault 資料夾名稱
- `{{vault_path}}` → 主要存取路徑（Linux/macOS 絕對路徑）
- `{{vault_path_windows_line}}` → 若有 Windows 路徑則替換為 `vault_path_windows: C:\...`；否則移除此整行
- `{{plugin_version}}` → 從 plugin.json 讀取的版本號

替換完成後，使用 obsidian CLI 寫入：

```bash
obsidian create vault=[vault_name] path="CLAUDE.md" content="[替換後的完整內容]"
```

> ⚠️ CLAUDE.md 模板內容較長，注意 content= 的 16KB 上限。若超長，先 `create` 寫入前段，再分段 `append` 剩餘部分。

**注意**：若 Vault 根目錄已有 `CLAUDE.md`，先確認使用者是否要覆蓋，確認後在命令中加上 `overwrite` 參數：

```bash
obsidian create vault=[vault_name] path="CLAUDE.md" content="[替換後的完整內容]" overwrite
```

### 步驟 4B-4：對齊 .obsidian 設定

> 注意：obsidian CLI 不支援 `.obsidian/` 設定檔的讀寫，此步驟嘗試直接操作 JSON 檔案。

使用 `test -d [vault_path]/.obsidian` 或 `ls [vault_path]/.obsidian/` 檢查 `.obsidian/` 資料夾是否存在。若檢查命令本身失敗（例如路徑不可存取），視同「不存在」直接略過。

若 `.obsidian/` **存在**，對以下三個檔案執行對齊。每個檔案先嘗試用 Edit/Write tool 寫入，若失敗則切換為引導模式。

**a. `templates.json`**（確保 templates 插件指向正確資料夾）：
```json
{
  "folder": "templates",
  "dateFormat": "YYYY-MM-DDTHH:mm",
  "timeFormat": "HH:mm"
}
```
- 若不存在：直接寫入
- 若已存在：僅更新 `folder`、`dateFormat`、`timeFormat`，保留其餘欄位

**b. `app.json`**（新筆記預設落在主題知識）：
需確保包含：
```json
{
  "newFileLocation": "folder",
  "newFileFolderPath": "主題知識"
}
```
- 若不存在：寫入含上述欄位的新檔
- 若已存在：僅更新這兩個欄位，保留其餘欄位

**c. `core-plugins.json`**（確保 templates 插件啟用）：
確保 `"templates": true`。

**若任一檔案寫入失敗**，提供引導：

> 無法自動修改 `.obsidian/` 設定檔。請手動確認以下設定：
>
> 1. 在 Obsidian 設定 → 核心插件 → 啟用「Templates」插件
> 2. 在 Obsidian 設定 → Templates → 模板資料夾位置設為 `templates`
> 3. 在 Obsidian 設定 → 檔案與連結 → 新建筆記存放位置設為「指定資料夾」，資料夾設為 `主題知識`
>
> 完成後請告訴我。

若 `.obsidian/` **不存在**：略過此步驟，並在完成摘要中說明。

---

## 階段 5：完成通知與全域設定

### 告知建立結果

告知使用者知識庫已建立在指定路徑。

### 詢問全域設定

詢問使用者：

> 是否要將此知識庫（`[vault_name]`）記錄到全域提示詞（`~/.claude/CLAUDE.md`）？
>
> 這樣 Claude 在所有專案中都能知道此知識庫的存在與路徑。

若使用者確認，讀取 `~/.claude/CLAUDE.md`，檢查是否已有 `## Vault: [vault_name]` 區塊：

- 若**已存在**：告知已記錄，略過
- 若**不存在**：附加以下內容至 `~/.claude/CLAUDE.md` 尾端（不覆蓋既有內容）：

```markdown
## Vault: [vault_name]

vault_path: [vault_path]
```

若 WSL2 環境，額外加上：
```markdown
vault_path_windows: [vault_path_windows]
```

---

## 階段 6：完成摘要

列出所有已建立的項目：

```
✓ 資料夾結構建立完成（raw/{archived,personal}/、歷史紀錄/{對話,個人寫作}/、主題知識/{實體|概念|比較|總覽}/、templates/、outputs/{queries,reflect,lint}/、index/）
✓ 模板檔案建立完成（templates/ 下 3 個模板：raw、來源記錄、知識筆記，含 v0.9 SHA-256/confidence 欄位）
✓ index.md / log.md / QUESTIONS.md / overview.md 系統檔已建立
✓ index/{topic-index,question-index}.md 極簡索引已建立
✓ CLAUDE.md 已生成（plugin v[version]，含 interaction_mode: human 預設）
✓ .obsidian 設定已對齊（或：.obsidian 尚未建立，Obsidian 首次開啟後可重新執行；或：因路徑限制無法自動修改，已提供手動引導）
✓ 全域 CLAUDE.md 已記錄此 Vault

Vault 已就緒（v0.9.0-beta）。可用的 skills：
- archive：將 raw/ 中的待歸檔檔案寫入歷史紀錄並更新主題知識 Wiki（含 SHA-256 / confidence gate / 自動 QUESTIONS 匹配）
- record-only：只寫來源記錄至歷史紀錄，不進行知識萃取
- knowledge-only：從指定歷史紀錄重新推知識主題，跳過 record-writer
- query：對 Wiki 提問，讀取相關頁面產出回答，可選擇寫回 outputs/queries/
- curator：Wiki 策展人，健康檢查（含 confidence/staleness/contradictions）+ 主題結構升級偵測與執行
- tag-review：審查、補充、修正知識筆記的 tags，確保分類一致性
- reflect（v0.9.0-rc 啟用）：二階認知活動 — 反向檢驗、模式掃描、Gap Analysis、深度合成
- ask（v0.9.0-rc 啟用）：管理 QUESTIONS.md 開放問題隊列

若要切換為 agent mode，編輯 vault/CLAUDE.md 將 `interaction_mode` 改為 `agent`。
詳見 `references/governance/agent-mode.md`。
```
