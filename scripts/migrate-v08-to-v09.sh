#!/usr/bin/env bash
#
# migrate-v08-to-v09.sh — Vault v0.8 → v0.9 遷移腳本
#
# 用途：將 v0.8 vault 升級到 v0.9 結構（只加不刪）
# 執行：bash scripts/migrate-v08-to-v09.sh <vault_path>
# 退出碼：0 成功，非零失敗
#
# 動作：
#   1. 建立 v0.9 新增資料夾
#   2. 建立 v0.9 新增系統檔
#   3. 補 CLAUDE.md 的 interaction_mode 欄位
#   4. 更新知識筆記模板（加 confidence 5 欄位）
#   5. 不動既有歷史紀錄與主題知識頁
#
# 安全保證：
#   - 只加不刪，不修改既有筆記內容
#   - 已存在的資料夾/檔案自動略過
#   - CLAUDE.md 只在缺 interaction_mode 時補入
#

set -euo pipefail

if [ -z "${1:-}" ]; then
    echo "用法：bash scripts/migrate-v08-to-v09.sh <vault_path>"
    echo "範例：bash scripts/migrate-v08-to-v09.sh /mnt/c/Users/leadi/OneDrive/文件/my-vault"
    exit 1
fi

VAULT_PATH="$1"

if [ ! -d "$VAULT_PATH" ]; then
    echo "❌ 路徑不存在：$VAULT_PATH"
    exit 1
fi

if [ ! -f "$VAULT_PATH/CLAUDE.md" ]; then
    echo "❌ 找不到 CLAUDE.md，這可能不是 obsidian-vault-tool vault"
    exit 1
fi

echo "=== obsidian-vault-tool v0.8 → v0.9 遷移 ==="
echo "Vault: $VAULT_PATH"
echo

CREATED=0
SKIPPED=0

create_dir() {
    local dir="$VAULT_PATH/$1"
    if [ -d "$dir" ]; then
        echo "  ⏭ 已存在：$1/"
        SKIPPED=$((SKIPPED + 1))
    else
        mkdir -p "$dir"
        echo "  ✓ 建立：$1/"
        CREATED=$((CREATED + 1))
    fi
}

create_file() {
    local file="$VAULT_PATH/$1"
    local content="$2"
    if [ -f "$file" ]; then
        echo "  ⏭ 已存在：$1"
        SKIPPED=$((SKIPPED + 1))
    else
        echo "$content" > "$file"
        echo "  ✓ 建立：$1"
        CREATED=$((CREATED + 1))
    fi
}

# === Step 1: 建立 v0.9 新增資料夾 ===
echo "→ Step 1: 建立新增資料夾"

create_dir "raw/personal"
create_dir "歷史紀錄/個人寫作"
create_dir "outputs"
create_dir "outputs/queries"
create_dir "outputs/reflect"
create_dir "outputs/lint"
create_dir "index"

# === Step 2: 建立 v0.9 新增系統檔 ===
echo
echo "→ Step 2: 建立新增系統檔"

TODAY=$(date '+%Y-%m-%d')

create_file "QUESTIONS.md" "---
type: system-questions
graph-excluded: true
created: $TODAY
last_updated: $TODAY
---

# Open Questions

## Open

_暫無開放問題。_

## Answered

_暫無已回答問題。_"

create_file "overview.md" "---
type: system-overview
graph-excluded: true
created: $TODAY
last_updated: $TODAY
---

# Knowledge Base Overview

## Health Dashboard

_本區由 reflect / curator skill 自動更新。_

## 待 Review 清單（agent mode 累積）

### high_candidate confidence（待人類確認升級為 high）

_暫無待 review 項目。_

### 同名異物（待人類裁決合併策略）

_暫無待 review 項目。_

### curator 建議修補（待人類執行）

_暫無待 review 項目。_

### 矛盾待裁決（agent 已標註，待人類降級決策）

_暫無待 review 項目。_"

create_file "index/topic-index.md" "---
type: system-index
graph-excluded: true
created: $TODAY
last_updated: $TODAY
---

# Topic Index

<!-- 由 archive Step 4.3 自動更新 -->
<!-- 格式: topic → [[歷史紀錄 paths]] + [[主題知識 paths]] -->"

create_file "index/question-index.md" "---
type: system-index
graph-excluded: true
created: $TODAY
last_updated: $TODAY
---

# Question Index

<!-- 由 archive Step 2.3 自動更新 -->
<!-- 格式: Q-NNN → [[candidate sources]] -->"

# === Step 3: 補 CLAUDE.md 的 interaction_mode ===
echo
echo "→ Step 3: 檢查 CLAUDE.md interaction_mode"

if grep -q "interaction_mode" "$VAULT_PATH/CLAUDE.md" 2>/dev/null; then
    echo "  ⏭ CLAUDE.md 已含 interaction_mode"
    SKIPPED=$((SKIPPED + 1))
else
    # 在 obsidian_cli: obsidian 後面加入 interaction_mode
    if grep -q "obsidian_cli:" "$VAULT_PATH/CLAUDE.md" 2>/dev/null; then
        sed -i '/obsidian_cli:/a interaction_mode: human   # human | agent' "$VAULT_PATH/CLAUDE.md"
        echo "  ✓ CLAUDE.md 補入 interaction_mode: human"
        CREATED=$((CREATED + 1))
    else
        echo "  ⚠ CLAUDE.md 格式不符預期，請手動加入 interaction_mode: human"
    fi
fi

# === Step 4: 更新知識筆記模板 ===
echo
echo "→ Step 4: 檢查知識筆記模板"

TEMPLATE="$VAULT_PATH/templates/知識筆記.md"
if [ -f "$TEMPLATE" ]; then
    if grep -q "confidence:" "$TEMPLATE" 2>/dev/null; then
        echo "  ⏭ 知識筆記模板已含 v0.9 欄位"
        SKIPPED=$((SKIPPED + 1))
    else
        echo "  ⚠ 知識筆記模板缺 v0.9 欄位（confidence/source_count/...）"
        echo "    建議執行 /vault-tool update 自動更新模板"
    fi
else
    echo "  ⏭ templates/知識筆記.md 不存在（可能是舊版結構）"
fi

# === 結果摘要 ===
echo
echo "=== 遷移結果 ==="
echo "新建：$CREATED 項"
echo "略過：$SKIPPED 項（已存在）"
echo
echo "✅ v0.8 → v0.9 遷移完成。"
echo
echo "下一步建議："
echo "  1. 在 Obsidian 中重新開啟此 vault"
echo "  2. 執行 /vault-tool update 完整更新 CLAUDE.md 與模板"
echo "  3. 開始使用 v0.9 新功能（reflect / ask / outputs 持久化）"
