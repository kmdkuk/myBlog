---
layout: post
title: CLIをかんたんに書き始めるためにTemplateRepositoryを作った
tags: Golang Go CLI Cobra GitHubActions
date: 2020-08-17 20:06 +0000
---

タイトルのとおり，CLI を作り始めるための TemplateRepository を作りました．

## TemplateRepository とは，

テンプレートリポジトリとは，既存のリポジトリを元に，  
新規でリポジトリを作成できる GitHub の機能の事です．  
Fork とは，違い，一つのリポジトリから複数の派生を作ることができたり，  
元になったリポジトリのコミット履歴を派生させず，1 からリポジトリを作成することができます．  
参考：[テンプレートからリポジトリを作成する](https://docs.github.com/ja/github/creating-cloning-and-archiving-repositories/creating-a-repository-from-a-template)

## go-cli-template

今回は，Golang で Cobra を利用した CLI を素早く作り始めるためのテンプレートリポジトリを作成しました．  
[go-cli-template](https://github.com/kmdkuk/go-cli-template)

### ファイル構造

このリポジトリは，以下のようなファイル構造になっています．

```
$ tree -va -I '.git|.idea' --dirsfirst
.
├── .github
│   └── workflows
│       ├── release.yml
│       └── test_and_build.yml
├── bin
│   └── go-cli-template
├── cmd
│   ├── root.go
│   └── version.go
├── log
│   └── logger.go
├── version
│   └── version.go
├── .gitignore
├── .goreleaser.yml
├── LICENSE
├── Makefile
├── README.md
├── go.mod
├── go.sum
└── main.go

6 directories, 15 files
```

コマンドラインツールとしてのファイル構造は，cmd 以下に各コマンドが用意する，  
cobra コマンドでの自動生成に準拠したファイル構造にしています．  
それとは別に log のパッケージや，version のパッケージを追加しました．  
実際に，複雑なコマンドラインツールを作っていく際に，このファイル構造は見直して行けると良いなあと思っています．  
それとは別の開発効率のためのツールとして，GithubActions，GoReleaser, Makefile を導入しています．

### version

version.Version, version.Revision, version.BuildDate にビルド時に情報を埋め込むことを行っています．  
これによって，開発環境，リリース時のビルドそれぞれで以下のような出力を行えるよう切り替えています．

#### 開発環境

```
$ go run main.go version
2020/08/18 04:43:54 [DEBUG] main.go:30 [[start command]]
version: DEV-unset ()
2020/08/18 04:43:54 [DEBUG] main.go:32 [[finish command]]
$ make
$ bin/go-cli-template version
version: v0.0.0-f707293 (2020-08-18)
```

#### リリースビルド

後述する GitHubActions で自動生成されるページからダウンロードリンク取得  
[https://github.com/kmdkuk/go-cli-template/releases/tag/v0.0.0](https://github.com/kmdkuk/go-cli-template/releases/tag/v0.0.0)

```
$ wget -O go-cli-template https://github.com/kmdkuk/go-cli-template/releases/download/v0.0.0/go-cli-template_darwin_x86_64
$ chmod +x go-cli-template
$ ./go-cli-template version
version: 0.0.0-f707293 (2020-08-14T00:59:15Z)
```

make でビルドしたものと，release に落ちているものは，ほとんど変わりませんが，  
ビルド環境が無い場合もかんたんなコマンドのインストール方法を提供できます．  
(brew でインストールできるような場所まで作ってあげると良いかもしれませんが，，，)

### log

log は前述した，version の定義によって挙動を変えてあります．  
version.Version=DEV の場合には，Debug レベルまで表示を行い．  
それ以外の場合には，Error レベルから表示を行うようにしています．  
あまり，アプリケーションのロギングには，知見がなく，なんとなくたまたま見つけた，
[github.com/spiegel-im-spiegel/logf](https://github.com/spiegel-im-spiegel/logf)を利用していますが，
もっとロギングのベストプラクティスを探して利用してみたいなあと思っています．

### CI/CD pipeline

GitHubActions も設定しており，
自動で，Lint([golangci-lint](https://github.com/golangci/golangci-lint))チェックと，
test を実行してくれるように設定しています．  
(test については，空っぽです．．)  
lint と test 実行の WorkFlow では，secrets.SLACK_WEBHOOK をリポジトリの secrets に設定することで，
実行結果を Slack に通知する準備も行っています．  
別の WorkFlow では，"v[0-9]+.[0-9]+.[0-9]+"のような，タグがプッシュされたことによってトリガーされ，
Goreleaser の GitHub Actions が発火し，  
[このようなリリースページ](https://github.com/kmdkuk/go-cli-template/releases/tag/v0.0.0)
を自動で公開することができます．

## 最後に，

ちょっとしたコマンドラインツールを作ろうかなあと思ったら  
こんな感じで再利用できる便利そうなものを作るのに  
無限に時間をかけてしまい価値を生み出せてないなあと．  
いつもこんなことばっかり本来作りたかったものの下地をがっちがちに頑張って，  
飽きるという流れに入ってる気もしないでもない．．．  
（このブログを半年ぶりに更新するためにも，ブログ公開プロセスを自動化するなど，寄り道をしてしまいました．そのおかげか，
だいぶ GitHubActions と戦うことができて面白かったです．）  
実際にこれを使って，面白い CLI を作ってみたいなあと思ってる次第です．  
「こういう機能あったらテンプレートとして便利そう」や，「こういう構造のほうが良いのでは？」というようなものがあれば，  
ぜひ [Twitter](https://twitter.com/kmdkuk)や[issue](https://github.com/kmdkuk/go-cli-template/issues) などで教えてもらえると大変助かります．
