# Day 3：Docker & コンテナ自動化 — ポータビリティと環境非依存

## 1. この回で学ぶことと演習の意図

### この講座全体の理念

> **学んだ技術を、その場で自分のポートフォリオ（GitHub Profile）に反映して育てる。**

### Day 3 の意図

**環境依存（OS 差分等）を Docker で克服し、
「同じコードが、ローカル（Codespace）でも GitHub Actions（クラウド）上でも、
同じ結果を出す」というポータビリティの価値を体験する。**

### なぜこれを学ぶのか（背景）

第二回で作った `generate.sh` を **Docker コンテナの中で実行するように変え**、
`update-profile.yml` の**生成ステップだけを差し替える**ことで、
CI/CD パイプラインが持つ「**環境の一致**」という性質を、自分の手で確認します。

第二回の終わりに触れた弱点を思い出してください。

> `runs-on: ubuntu-latest` のマシンに入っているコマンドのバージョンが変わったら、
> 生成結果も変わってしまうかもしれない。

現状、`generate.sh` は**2つの別々の環境**で動いています。

```
あなたの Codespace（Ubuntu 24.04）  →  date / sed / curl … このマシンの版
Actions の実行機（ubuntu-latest）   →  date / sed / curl … あのマシンの版
```

この 2 つは似ていますが、同一ではありません。OS のバージョンも、コマンドの実装も、
タイムゾーン設定も違い得ます。だから、実務では有名なあの一言が生まれます。

> **「私の環境では動くんですけどね」**

Docker は、この問題を「**環境ごとコードに書いて、リポジトリに入れてしまう**」という
やり方で解決します。

```
Codespace  ──┐
             ├─→ 同じイメージ（alpine:3.20 + curl + tzdata）─→ 同じ結果
Actions    ──┘
```

下地のマシンが何であれ、コンテナの中身は常に同じ。これが**ポータビリティ**です。

### 実務でこれが効く場面

- 「私の PC では動くのに本番では落ちる」という不毛な調査が無くなる
- 新しいメンバーが参加した初日から、同じ環境で開発を始められる
- 数年後に同じイメージを動かしても、当時と同じ結果が再現できる

### ⚠️ この演習のスコープ（重要）

**この演習で Docker が行うのは「文字列置換」のみです。
画像生成やレンダリングは一切行いません。**

そのため、`Dockerfile` に**日本語フォント関連のパッケージ
（`font-noto-cjk` 等）は含めません。**
必要なのは **`alpine:3.20` + `curl` + `tzdata`** の3つだけです。

（フォントを入れると、イメージが数百 MB 単位で膨らみ、ビルドも遅くなります。
「**必要なものだけを入れる**」のは、コンテナを扱ううえで大切な感覚です。）

### 今日のゴール

> 1. 自分で `Dockerfile` を書き、Codespace で `docker build` / `docker run` して動かす
> 2. `update-profile.yml` の**生成ステップ 1 つだけ**を Docker 版に差し替える
> 3. Actions 上でも、Codespace と**同じ結果**が出ることを確認する

---

## 2. 環境準備

### 2-1. Codespace を起動する

1. 自分のリポジトリ（リポジトリ名 = 自分のユーザー名）を開く
2. **`Code`** → **`Codespaces`** → **`Create codespace on main`**

> ### ⚠️ 無料枠のリマインド
>
> Codespaces の無料枠（月 120 コア時間・15 GB ストレージ）は
> **個人アカウントにのみ適用されます。** 組織アカウント配下では課金対象です。
> **使い終わったら必ず Codespace を削除**してください（手順は末尾の第6章）。

### 2-2. docker コマンドが使えることを確認する

```bash
git switch main
git pull
docker version
```

`Client:` と `Server:` の両方にバージョンが表示されれば準備 OK です。

> **なぜ Codespace で docker が使えるのか**
> このリポジトリの `.devcontainer/devcontainer.json` に
> `ghcr.io/devcontainers/features/docker-in-docker:2` という指定があるからです。
> **開発環境の中身そのものが、リポジトリにコードとして書かれている**——
> これも「環境をコードで管理する」考え方の一例です。

---

## 3. ステップ別手順

### Step 1：作業用ブランチを作る

第一回と同じく、`main` に直接コミットせず、ブランチを切って PR で進めます。

```bash
git switch -c feature/dockerize
```

### Step 2：Dockerfile を実装する

`Dockerfile` を開いてください。**TODO コメントだけが並んだ空のひな形**になっています。
冒頭の解説（なぜ Docker で環境が揃うのか）にも目を通しておくと、
これから書く 5 行の意味がつかみやすくなります。

TODO を上から順に埋めていきます。

#### TODO 1：ベースイメージ

```dockerfile
FROM alpine:3.20
```

`FROM` は「どの土台の上に作るか」の宣言です。
**Alpine Linux** は、非常に小さい（約 8 MB）Linux ディストリビューションで、
コンテナのベースとしてよく使われます。
`3.20` のように**バージョンを固定する**のが重要です。
`alpine:latest` と書くと、実行する時期によって中身が変わってしまい、
せっかくの「いつでも同じ結果」が崩れます。

#### TODO 2：必要なパッケージ

```dockerfile
RUN apk add --no-cache curl tzdata
```

`RUN` は「イメージを作る時に実行するコマンド」です。
`apk` は Alpine のパッケージマネージャ（Ubuntu の `apt` にあたるもの）。

- `curl` … `generate.sh` が GitHub API を叩くために必要
- `tzdata` … 日本時間（JST）を扱うために必要
- `--no-cache` … パッケージの索引をイメージ内に残さない（サイズを小さく保つ）

> **フォントは入れません。**
> この演習でコンテナがするのは文字列置換だけで、画像は作らないためです。

#### TODO 3：タイムゾーン

```dockerfile
ENV TZ=Asia/Tokyo
```

`ENV` は環境変数の設定です。これが無いと `date` が UTC（世界標準時）で表示され、
日本時間と 9 時間ずれます。

#### TODO 4：作業ディレクトリ

```dockerfile
WORKDIR /work
```

コンテナの中の「カレントディレクトリ」を決めます。
後で、この `/work` にリポジトリを繋ぎ込みます。

#### TODO 5：起動時のコマンド

```dockerfile
CMD ["./generate.sh"]
```

`CMD` は「コンテナが起動したら何を実行するか」です。

書き終えたら、全体を確認します。

```bash
cat Dockerfile
```

<details>
<summary>📖 完成形（詰まったらここを開いてください）</summary>

```dockerfile
FROM alpine:3.20

RUN apk add --no-cache curl tzdata

ENV TZ=Asia/Tokyo

WORKDIR /work

CMD ["./generate.sh"]
```

コメント行はそのまま残しておいて構いません。

</details>

### Step 3：イメージをビルドする

```bash
docker build -t profile-generator .
```

- `-t profile-generator` … 作るイメージに `profile-generator` という名前を付ける
- 末尾の `.` … 「今いるフォルダを材料として使う」という意味（**この点を忘れがちです**）

初回は Alpine のダウンロードが走るため 10〜30 秒ほどかかります。
`naming to docker.io/library/profile-generator` のような表示が出れば成功です。

できたイメージは、次のコマンドで一覧できます。

```bash
docker images
```

### Step 4：コンテナを動かしてみる

```bash
docker run --rm -v "$(pwd):/work" profile-generator
```

`✅ README.md を生成しました` と表示されれば成功です。

オプションの意味を押さえておきましょう。

| オプション | 意味 |
|---|---|
| `--rm` | 実行が終わったらコンテナを自動で捨てる（ゴミを残さない） |
| `-v "$(pwd):/work"` | **今いるフォルダを、コンテナ内の `/work` に繋ぐ**（マウント） |

> **`-v`（マウント）が肝です。**
> コンテナは本来、外の世界から隔離されています。
> このままでは `template.md` を読むことも、`README.md` を書き出すこともできません。
> `-v` は「このフォルダだけは共有してよい」という**通用口**を開ける指定です。
> これがあるおかげで、コンテナの中で生成した結果が、外側の Codespace に残ります。

### Step 5：コンテナの中で動いた証拠を見る

```bash
git diff README.md
```

`ビルド環境` の行に注目してください。

```
| ビルド環境 | Linux / 4819ed939a55 |
```

この `4819ed939a55` のような文字列は、**コンテナに割り当てられた ID** です。
Codespace のホスト名ではありません。
**同じ `generate.sh` が、確かにコンテナの中で実行された**ことの証拠です。

確認できたら、いったん変更を戻します（実際の更新は Actions に任せるため）。

```bash
git restore README.md
```

### Step 6：ワークフローの生成ステップを差し替える

いよいよ本題です。`.github/workflows/update-profile.yml` を開いてください。

**差し替えるのは「プロフィールを再生成」ステップだけです。
コミット・push 以降の処理は一切変更しません。**

変更前：

```yaml
      - name: プロフィールを再生成
        run: ./generate.sh
```

変更後：

```yaml
      # 【第三回で変更】直接実行 → Docker コンテナ内での実行に差し替え
      # コミット・push 以降のステップは第二回のまま変更していない。
      - name: プロフィールを再生成（Docker）
        run: |
          docker build -t profile-generator .
          docker run --rm -v "${{ github.workspace }}:/work" profile-generator
```

Codespace で打ったコマンドと**ほぼ同じ 2 行**です。違いは `$(pwd)` の部分が
`${{ github.workspace }}`（Actions がリポジトリを置いた場所を指す変数）になっただけです。

> **なぜ 1 ステップだけの変更で済むのか**
> ここが今日いちばん味わってほしいところです。
>
> ワークフローは「**何をするか**」をステップ単位で分けて書いてあります。
> 「生成する」という役割さえ果たせれば、その中身が直接実行だろうと Docker だろうと、
> **後続のステップには関係ありません。**
>
> 役割ごとに切り分けておくと、**一部だけを安全に差し替えられる**——
> これは CI/CD に限らず、ソフトウェア設計に共通する考え方です。

### Step 7：コミットして PR を出す

```bash
git add Dockerfile .github/workflows/update-profile.yml
git commit -m "feat: 生成ステップを Docker 化"
git push -u origin feature/dockerize
```

GitHub 上で PR を作成し、`Files changed` で差分を確認してからマージしてください。
**「生成ステップ 1 つだけが変わっている」**ことが差分から読み取れるはずです。

### Step 8：Actions で動くことを確認する

マージすると `main` への push が起きるので、ワークフローが自動で走ります。
（手動で動かす場合は `Actions` → `Update Profile` → `Run workflow`）

`Actions` タブでログを開き、`プロフィールを再生成（Docker）` ステップを見てください。

1. `docker build` が走り、Alpine のダウンロードとパッケージ導入が行われる
2. `docker run` が走り、`✅ README.md を生成しました` と出る

そして最後に、**プロフィール画面**を開いてください。

```
| ビルド環境 | Linux / <コンテナID> |
```

**Codespace で見たときと同じ形式**になっています。
`ubuntu-latest` のマシン上で動いているのに、結果は Alpine コンテナのもの——
**下地のマシンが何であれ、コンテナの中身が同じなら結果も同じ。**
これが、今日体験してほしかったポータビリティです。
