# 回歸測試集

最小可回歸測試集，涵蓋 plugin 核心流程的關鍵場景。

## 目錄結構

```
tests/
├── README.md                          # 本檔
├── fixtures/
│   └── test-vault/                    # 固定測試 vault
│       ├── raw/                       # 測試用 raw 檔
│       ├── 歷史紀錄/                  # 初始歷史紀錄
│       ├── 主題知識/                  # 初始知識筆記
│       ├── index.md                   # 初始 index
│       └── log.md                     # 初始 log
├── expected/
│   └── case-*.md                      # 預期結果快照
└── run-tests.sh                       # 執行腳本（Phase 3 完整實作）
```

## 測試案例

| 案例 | Fixture | 預期結果 | 驗證重點 |
|------|---------|---------|---------|
| case-01-simple-article | `raw/case-01-*.md` | 新建 1 個歷史紀錄 + 1-2 個知識筆記 | 基本歸檔流程 |
| case-02-duplicate-topic | `raw/case-02-*.md` | 新建歷史紀錄 + 同名異物另建頁 | 同名異物處理（決策表 E）|
| case-03-parent-child | `raw/case-03-*.md` | 父子關係正確映射到目錄結構 | 層級映射（Step 1.6）|
| case-04-conversation | 對話 raw | Step -1 預處理後走 full-archive | 對話歸檔前置 |
| case-05-path-injection | `raw/case-05-*.md` | record-writer 熔斷 | 路徑安全（P1-P6）|

## 執行方式（v0.8.0 初版為手動驗證）

```bash
# Step 1: 複製 fixture 到臨時 vault
cp -r tests/fixtures/test-vault /tmp/obsidian-test-vault

# Step 2: 在 Claude Code 中以 /tmp/obsidian-test-vault 為目標觸發 archive skill

# Step 3: 比對結果與 expected/ 下的快照

# Step 4: 清理
rm -rf /tmp/obsidian-test-vault
```

## 設計原則

- **固定 vault**：expected snapshot 需要穩定的起始狀態，故採用固定 fixture
- **複製後執行**：不直接修改 fixture 本身，避免測試污染
- **最小覆蓋**：初版 5 個案例聚焦核心風險點，不追求完整覆蓋
- **手動驗證**：由於需要完整 Claude Code + obsidian CLI 環境，初版不自動化

## 後續擴展

- 自動化 `run-tests.sh`（需要 mock LLM 回應或整合 CI）
- 增加案例：版本漂移、崩潰恢復、並行序號競態
- 整合 lint-specs.sh 形成完整 CI pipeline
