#!/bin/bash
# ============================================================
# Issue 本文の機械バリデーション（create-issue スキルの門番）
#
# 目的: 「成功の定義」が書かれていない Issue を作れなくする。
#   ゴールが言葉で書けない仕事はループに載せない（判断基準 2）。
#   合否は終了コードだけで決める: 0 = 合格 / 1 = 不合格
#
# 型: ~/ai-workbench/work/loop-engineering/templates/issue.md
# 使い方: validate-issue.sh <Issue本文ファイル>
# ============================================================
set -u

FILE=${1:?使い方: validate-issue.sh <Issue本文ファイル>}
[ -f "$FILE" ] || { echo "不合格: ファイルがありません: $FILE" >&2; exit 1; }

ERRORS=()

# --- 1. 必須節の存在 ---
for sec in "## ゴール" "### 課題" "### 成功の定義"; do
  grep -q "^${sec}" "$FILE" || ERRORS+=("節「${sec}」がありません")
done

# --- 2. 節の実内容（HTML コメントと空行を除いて 1 行以上あるか）---
section_content() {
  # 見出し行の次から、次の見出し（# で始まる行）までを抜き出し、
  # <!-- --> コメント（複数行含む）と空行を落とす
  awk -v h="$1" 'index($0, h) == 1 {f=1; next} f && /^#/ {f=0} f {print}' "$FILE" \
    | perl -0pe 's/<!--.*?-->//gs' \
    | grep -v '^[[:space:]]*$' || true
}

for sec in "### 課題" "### 成功の定義"; do
  if grep -q "^${sec}" "$FILE" && [ -z "$(section_content "$sec")" ]; then
    ERRORS+=("節「${sec}」が空です（コメントを除いて実内容がありません）")
  fi
done

# --- 判定 ---
NG=${ERRORS[@]+${#ERRORS[@]}}; NG=${NG:-0}
if [ "$NG" -gt 0 ]; then
  echo "不合格: この本文では Issue を作れません" >&2
  for e in ${ERRORS[@]+"${ERRORS[@]}"}; do echo "  - $e" >&2; done
  exit 1
fi

echo "合格: 必須節（ゴール・課題・成功の定義）と実内容を確認しました"
exit 0
