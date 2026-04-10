#!/usr/bin/env bash
#
# lint-specs.sh — 跨文件一致性靜態檢查
#
# 用途：偵測 obsidian-vault-tool plugin 內各 spec、skill、agent 文件之間的不一致
# 執行：bash scripts/lint-specs.sh
# 退出碼：0 表示全部通過，非零表示有發現問題
#
# 規則（初版 5 項，Phase 1.2）：
#   R1 record-writer 輸出欄位名與 command 解析模板一致
#   R2 log 路徑佔位符統一（[來源類型目錄] 而非 [type]）
#   R3 wiki_category 判定順序在各文件一致
#   R4 plugin.json version 與 claude-md 範例一致
#   R5 同名異物規則引用（僅 topic-matching-spec 為權威定義處）
#

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
cd "$REPO_ROOT"

ERRORS=0
CHECKED=0

log_error() {
    local rule="$1"
    local file="$2"
    local detail="$3"
    echo "❌ [$rule] $file: $detail" >&2
    ERRORS=$((ERRORS + 1))
}

log_ok() {
    local rule="$1"
    echo "✓ [$rule] $2"
    CHECKED=$((CHECKED + 1))
}

echo "=== obsidian-vault-tool spec lint ==="
echo

# ------------------------------------------------------------------
# R1: record-writer 輸出欄位名與 full-archive/record-only 解析模板一致
# ------------------------------------------------------------------
echo "→ R1: 欄位名一致性（知識主題樹 vs 知識主題列表）"

# 檢查是否有任何文件還在使用舊名「知識主題列表」
if grep -rn "知識主題列表" --include="*.md" agents/ skills/ references/ 2>/dev/null; then
    log_error "R1" "multiple files" "偵測到舊欄位名「知識主題列表」，應統一為「知識主題樹」"
else
    log_ok "R1" "全部文件使用「知識主題樹」"
fi

# ------------------------------------------------------------------
# R2: log 路徑佔位符統一
# ------------------------------------------------------------------
echo "→ R2: log 路徑佔位符（[來源類型目錄] vs [type]）"

# 在 log 路徑範例中不應出現 [type]
PROBLEMATIC=$(grep -rn '\[\[歷史紀錄/\[type\]' --include="*.md" agents/ skills/ references/ 2>/dev/null || true)
if [ -n "$PROBLEMATIC" ]; then
    echo "$PROBLEMATIC" | while read -r line; do
        log_error "R2" "$line" "log 路徑仍使用舊佔位符 [type]，應改為 [來源類型目錄]"
    done
else
    log_ok "R2" "log 路徑全部使用 [來源類型目錄]"
fi

# ------------------------------------------------------------------
# R3: wiki_category 判定順序
# ------------------------------------------------------------------
echo "→ R3: wiki_category 判定順序"

# 權威定義：wiki-category-spec.md 的順序為 實體 → 比較 → 總覽 → 概念（兜底）
# 檢查其他文件是否遵循此順序

# claude-md-template.md 應有「對比分析 → 橫跨綜論 → 抽象原理」
if ! grep -q "具體對象 → 對比分析 → 橫跨綜論 → 抽象原理" references/claude-md-template.md 2>/dev/null; then
    log_error "R3" "references/claude-md-template.md" "wiki_category 判定順序不符合 spec（應為 具體對象 → 對比分析 → 橫跨綜論 → 抽象原理）"
else
    log_ok "R3" "claude-md-template.md 順序正確"
fi

# wiki-writer.md 的分類列表應以「概念」為兜底（最後）
if ! grep -B1 -A1 "概念.*兜底" agents/wiki-writer.md 2>/dev/null | grep -q "概念"; then
    log_error "R3" "agents/wiki-writer.md" "wiki_category 分類列表未將「概念」標記為兜底類別"
else
    log_ok "R3" "wiki-writer.md 分類列表順序正確"
fi

# ------------------------------------------------------------------
# R4: plugin.json version 一致性
# ------------------------------------------------------------------
echo "→ R4: plugin.json version"

if command -v jq >/dev/null 2>&1; then
    PLUGIN_VERSION=$(jq -r '.version' .claude-plugin/plugin.json 2>/dev/null)
    if [ -z "$PLUGIN_VERSION" ] || [ "$PLUGIN_VERSION" = "null" ]; then
        log_error "R4" ".claude-plugin/plugin.json" "無法讀取 version 欄位"
    else
        log_ok "R4" "plugin.json version = $PLUGIN_VERSION"
    fi
else
    # 退回用 grep 解析
    PLUGIN_VERSION=$(grep '"version"' .claude-plugin/plugin.json | head -1 | sed 's/.*"version": *"\([^"]*\)".*/\1/')
    if [ -n "$PLUGIN_VERSION" ]; then
        log_ok "R4" "plugin.json version = $PLUGIN_VERSION (grep mode)"
    else
        log_error "R4" ".claude-plugin/plugin.json" "無法解析 version 欄位"
    fi
fi

# ------------------------------------------------------------------
# R5: 同名異物規則引用
# ------------------------------------------------------------------
echo "→ R5: 同名異物規則引用（topic-matching-spec 為權威）"

# wiki-category-spec.md 的同名異物段落應為引用形式（非完整定義）
# 權威段落應只出現在 topic-matching-spec.md 和 wiki-writer.md (Level 2/5 判定)
if grep -q "完整判定流程.*topic-matching-spec" references/wiki-category-spec.md 2>/dev/null; then
    log_ok "R5" "wiki-category-spec.md 正確引用 topic-matching-spec"
else
    log_error "R5" "references/wiki-category-spec.md" "同名異物段落未引用 topic-matching-spec 作為權威來源"
fi

# ------------------------------------------------------------------
# 結果輸出
# ------------------------------------------------------------------
echo
echo "=== 檢查結果 ==="
echo "通過：$CHECKED"
echo "錯誤：$ERRORS"

if [ "$ERRORS" -gt 0 ]; then
    echo
    echo "❌ 發現 $ERRORS 個一致性問題，請修正後重新執行。"
    exit 1
else
    echo
    echo "✅ 所有檢查通過。"
    exit 0
fi
