# Obsidian Vault — 規格說明

本 Vault 由 obsidian-vault-tool plugin 管理（v{{plugin_version}}）。
所有流程邏輯由 plugin skills 承載，本檔案僅含靜態定義與狀態。

---

## 初始化狀態

```yaml
initialized: true
vault_name: {{vault_name}}
vault_path: {{vault_path}}
{{vault_path_windows_line}}
plugin_version: {{plugin_version}}
obsidian_cli: obsidian
```

---

## 資料夾結構

```
[vault-name]/
├── 歷史紀錄/
│   ├── 對話/               # 來源記錄（conversation），按日期子資料夾
│   ├── YouTube/            # 來源記錄（youtube），動態建立
│   ├── Facebook/           # 來源記錄（fb-post），動態建立
│   ├── 文章/               # 來源記錄（article），動態建立
│   ├── 文件/               # 來源記錄（pdf），動態建立
│   └── 網頁/               # 來源記錄（webpage），動態建立
│       └── YYYY-MM-DD/     # 子資料夾，檔名 [序號]_[概述].md
├── 主題知識/                # 知識筆記，按日期子資料夾
│   └── YYYY-MM-DD/         # 子資料夾，檔名 [標題].md
└── templates/              # 筆記模板
```

> 歷史紀錄子目錄初始化時只建立 `對話/`，其他子目錄由 `archive` / `record-archive` skill 依來源類型動態建立。

---

## Frontmatter Schema

### 來源記錄（6 欄位）

存放路徑：`歷史紀錄/[type]/[YYYY-MM-DD]/[序號]_[概述].md`

| 欄位 | 說明 |
|------|------|
| `title` | 來源標題（文章標題、影片標題、對話概述等） |
| `date` | 歸檔日期，格式 `YYYY-MM-DD` |
| `source` | 原始 URL 或對話識別資訊 |
| `category` | 固定 `來源紀錄` |
| `content_type` | `conversation` / `youtube` / `fb-post` / `article` / `pdf` / `webpage` |
| `author` | 原始作者，不適用則留空 |

### 知識筆記（7 欄位）

存放路徑：`主題知識/[YYYY-MM-DD]/[標題].md`

| 欄位 | 說明 |
|------|------|
| `title` | 筆記標題 |
| `date` | 建立日期，格式 `YYYY-MM-DD` |
| `tags` | 中文層級結構標籤，`tags[0]` 為完整路徑 |
| `source` | `[[來源記錄檔名]]`（由 archive skill 呼叫時）或完整 URL（standalone 時） |
| `category` | 等於 `tags[0]` 第一層（動態） |
| `content_type` | `article` / `youtube` / `pdf` / `fb-post` / `conversation` / `webpage` |
| `author` | 原始作者 |

---

## Tags 規範（三段組合）

1. **層級結構標籤**（1 個）：完整路徑，放 `tags[0]`，如 `技術/AI/LLM`
2. **層級拆解標籤**（2-3 個）：拆開各層，如 `技術`、`AI`、`LLM`
3. **其他描述標籤**（2-5 個）：補充具體主題，如 `提示詞工程`

總數最多 10 個。`tags[0]` 第一層決定 `category`。

---

## 注意事項

- 來源記錄**無 `tags` 欄位**，不執行 tag-review
- 兩種筆記均無 `aliases`、`status`、`related`、`original_url`、`scope`、`archived_to`、`archived_at`
- `.obsidian/` 僅修改 `app.json`、`templates.json`、`core-plugins.json`

<!-- vault-tool:managed-end -->
