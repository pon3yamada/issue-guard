# issue-guard

**ゴール（成功の定義）が書かれていない Issue を、起票の入口によらず検出する GitHub Action。**

Issue が作られた／編集されたときに本文を検査し、必要な節が無い・空のときは `needs-goal`
ラベルとコメントで差し戻す。

## なぜあるか

ゴールを言葉で書けない仕事は、AI に丸投げしても「終わったかどうか」を機械で判定できない。
だから起票の時点で門番を置く。

同じ検査をエディタ側のスキルからも呼んでいるが、**そちらを通らない入口が増えていく** ——
Web の Issue 画面、スマートフォン、チャット連携、外部のタスク管理ツールからの同期。
入口を制限する代わりに、**どの入口から入っても必ず通る場所（GitHub 側）に門番を移す**ためのもの。

判定ロジックの実体はこのリポジトリに 1 本だけ置く。各リポジトリにコピーを配ると、
直すときに全部を直すことになり、しかもズレても誰も気づかない。

## 何を検査するか

`scripts/validate-issue.sh` が、Issue 本文について次を見る。合否は**終了コードだけ**で決める。

1. `## ゴール` `### 課題` `### 成功の定義` の 3 つの節が存在すること
2. `### 課題` と `### 成功の定義` に**実内容**があること
   （HTML コメント `<!-- -->` と空行を除いて 1 行以上残ること）

テンプレートのコメントを消し忘れただけの「空の節」を通さないのが要点。

## 使い方

```yaml
name: Issue Guard

on:
  issues:
    types: [opened, edited, reopened]

permissions:
  issues: write   # ラベルの付け外しとコメント投稿のため

jobs:
  guard:
    runs-on: ubuntu-latest
    steps:
      - id: guard
        uses: pon3yamada/issue-guard@v1
        with:
          issue-number: ${{ github.event.issue.number }}
          repository: ${{ github.repository }}
          github-token: ${{ secrets.GITHUB_TOKEN }}

      - name: 結果を Issue に反映
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          GH_REPO: ${{ github.repository }}
          NUM: ${{ github.event.issue.number }}
          OK: ${{ steps.guard.outputs.ok }}
          DETAIL: ${{ steps.guard.outputs.detail }}
        run: |
          if [ "$OK" = "true" ]; then
            gh issue edit "$NUM" --remove-label needs-goal || true
          else
            gh issue edit "$NUM" --add-label needs-goal
            printf '%s\n' "$DETAIL" | gh issue comment "$NUM" --body-file -
          fi
```

`needs-goal` ラベルは、無ければ事前に作っておく。

## 入力

| 名前 | 必須 | 内容 |
|---|---|---|
| `issue-number` | ✅ | 検査する Issue の番号 |
| `repository` | ✅ | `owner/repo` |
| `github-token` | ✅ | Issue を読むためのトークン |

## 出力

| 名前 | 内容 |
|---|---|
| `ok` | 合格なら `true`、不合格なら `false` |
| `detail` | 検査スクリプトの出力そのまま（不合格の理由が 1 行 1 件で並ぶ） |

**このアクションはジョブを失敗させない。** 合否は出力で返すので、
ラベルを付けるのか、コメントするのか、ジョブごと落とすのかは呼び出し側が決める。

## 設計上の注意

- **Issue 本文を `${{ }}` で展開していない。** 本文は誰でも書ける信頼できない入力なので、
  シェルスクリプトに埋め込むと任意のコマンドを実行させられる。
  アクションは `gh` で本文をファイルに落とし、スクリプトにはパスだけを渡す
- **Actions は「作らせない」ことはできない。** Issue が作られた後に発火するので、
  できるのは差し戻し（ラベルとコメント）まで。作る前に止めたい場合は、
  エディタ側やスクリプト側から `scripts/validate-issue.sh` を直接呼ぶ
- 依存は `bash` / `grep` / `awk` / `perl` と `gh` だけ。`ubuntu-latest` でそのまま動く
