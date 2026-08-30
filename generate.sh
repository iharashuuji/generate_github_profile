#!/bin/sh
# ============================================================
#  generate.sh
#
#  【シェバン（1行目）が #!/bin/sh である理由】
#    第三回では、このスクリプトを Alpine Linux のコンテナ内で実行します。
#    Alpine には bash が入っていない（sh = ash）ため、#!/bin/bash と書くと
#      exec ./generate.sh: no such file or directory
#    という分かりにくいエラーで起動に失敗します。
#    このスクリプトは bash 固有の構文を使っていないので、
#    どこでも動く #!/bin/sh に統一しています。
#
#  ※ これは「配布済みのコード」です。第二回の講義で解説します。
#     受講者のみなさんがこのファイルを書き換える必要はありません。
#     中身が全部わからなくても、演習は問題なく進められます。
#
#  役割：template.md のプレースホルダを実際の値に置き換えて
#        README.md を生成する。
# ============================================================

# set -e : コマンドが1つでも失敗したら、そこで処理を止める
# set -u : 未定義の変数を使おうとしたらエラーにする
#          → 「気づかないうちに空文字で上書きされる」事故を防ぐ
set -eu

TEMPLATE="template.md"
OUTPUT="README.md"

# --- 1. 値を集める --------------------------------------------------

# GitHub のユーザー名。Actions 上では GITHUB_REPOSITORY_OWNER が自動で入る。
# ローカル（Codespace）で試すときは未設定なので "Guest" を使う。
USER_NAME="${GITHUB_REPOSITORY_OWNER:-Guest}"

# 現在時刻。date コマンドの +"..." で書式を指定する。
BUILD_DATE="$(date +"%Y-%m-%d %H:%M:%S %Z")"

# このスクリプトを実行しているマシンの名前。
# 第三回で Docker 化すると、ここの値が変わる（＝コンテナの中で動いた証拠になる）。
BUILD_HOST="$(uname -s) / $(hostname)"

# GitHub API から公開リポジトリ数を取得する。
#
# 【認証ヘッダを付けていない理由】
#   認証なしの GitHub API は「1時間あたり60リクエスト」の制限があります。
#   この演習は手動実行（workflow_dispatch）が前提で、1日に数回しか叩かないため、
#   制限に達することはありません。よってトークンの準備は不要にしています。
#
#   -s : 進捗表示を出さない（silent）
#   -f : HTTP エラー時に失敗として扱う
PUBLIC_REPOS="$(curl -sf "https://api.github.com/users/${USER_NAME}" \
  | grep '"public_repos"' \
  | head -n 1 \
  | tr -dc '0-9' || echo "N/A")"

# 取得できなかった場合のフォールバック
PUBLIC_REPOS="${PUBLIC_REPOS:-N/A}"

# --- 2. テンプレートを置換して出力する ------------------------------

# sed の s<区切り文字>置換前<区切り文字>置換後<区切り文字>g で文字列を置き換える。
#
# 【区切り文字に / ではなく | を使っている理由】
#   置換したい値そのものに "/" が含まれていると（例：BUILD_HOST の "Linux / codespaces-xxx"）、
#   sed が "s/..." の区切りと勘違いして
#     sed: -e expression #4, char 26: unknown option to `s'
#   というエラーで落ちます。
#   値に出てきにくい "|" を区切り文字にすることで、この問題を回避しています。
sed \
  -e "s|{{USER_NAME}}|${USER_NAME}|g" \
  -e "s|{{BUILD_DATE}}|${BUILD_DATE}|g" \
  -e "s|{{PUBLIC_REPOS}}|${PUBLIC_REPOS}|g" \
  -e "s|{{BUILD_HOST}}|${BUILD_HOST}|g" \
  "${TEMPLATE}" > "${OUTPUT}"

echo "✅ ${OUTPUT} を生成しました（USER_NAME=${USER_NAME}, PUBLIC_REPOS=${PUBLIC_REPOS}）"
