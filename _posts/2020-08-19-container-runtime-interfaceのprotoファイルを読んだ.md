---
layout: post
title: Container Runtime InterfaceのProtoファイルを読んだ．
tags: CRI gRPC
date: 2020-08-19 21:54 +0000
---

(この記事は，CRI(Container Runtime Interface)がなにかということについては触れません．)

僕自身 CRI を使って，コード書きたいなあと思っている割には，
CRI でどんなメソッド，構造体が用意されているか，しらなかったので，
[cri-api の proto ファイル](https://github.com/kubernetes/cri-api/blob/master/pkg/apis/runtime/v1alpha2/api.proto)を読んでみました．  
もちろん英語は，Google 先生が居ないと読めないので，読んだ結果を外部記憶としてブログに書き残して置こう
と，思った次第です．(見出しのスタイルが貧弱なおかげで，すごく見づらい．．．)

gRPC についての知識も無いため，用語の使い方が間違っているかもしれません．

CRI には，RuntimeService と ImageService の 2 つが定義されています．

それぞれのサービスに存在する RPC メソッドは，<RPC メソッド名>Request というメッセージを受け取り，<RPC メソッド名>Response というメッセージを返すように定義されています．
各 RPC メソッド，Request,Response をまとめた後，Request と Response それぞれで利用されている定義されているメッセージについて深堀りしてまとめていきます．

## [Service]RuntimeService

ランタイムサービスは，リモートコンテナランタイムのための public APIs です．

### [RPC メソッド]Version

Version は，ランタイムの名前，ランタイムのバージョン，ランタイム API のバージョンを返します．

#### [message]VersionRequest

- string version: kubelet runtime API のバージョン

#### [message]VersonResponse

- string version: kubelet runtime API のバージョン
- string runtime_name: コンテナランタイムの名前
- string runtime_version: コンテナランタイムのバージョン. semver-compatible.
- string runtime_api_version: コンテナランタイムの API バージョン．semver-compatible

### [RPC メソッド]RunPodSandbox

RunPosSandbox は，pod-level sandbox を作成する．この関数が成功したら，ランタイムは、サンドボックスが準備完了状態であることを確認します．(翻訳自身なし)
(※ pod-level sandbox は，いわゆる k8s 上の pod 単位の人まとまり？)

#### [message]RunPodSandboxRequest

- [PodSandboxConfig](#messagepodsandboxconfig) config: PodSandbox を作成するための Configuration
- string runtime_handler: この PodSandbox に使用する名前付きランタイム構成。
  ランタイムハンドラが不明な場合、このリクエストは拒否されます。 空の文字列は、この機能が追加される前の動作と同等のデフォルトハンドラーを選択する必要があります。
  see https://git.k8s.io/enhancements/keps/sig-node/runtime-class.md

#### [message]RunPodSandboxResponse

- string pod_sandbox_id: 実行する PodSandbox の ID

### [RPC メソッド]StopPodSandbox

StopPodSandbox は、サンドボックスの一部である実行中のプロセスを停止し、サンドボックスに割り当てられたネットワークリソース（IP アドレスなど）を再利用します。
サンドボックスに実行中のコンテナがある場合は、強制的に終了する必要があります。
この呼び出しはべき等であり、関連するすべての場合にエラーを返してはなりません。
リソースはすでに再利用されています。 kubelet は、少なくとも 1 回は StopPodSandbox を呼び出してから、RemovePodSandbox を呼び出します。 また、サンドボックスが不要になるとすぐに、リソースを積極的に再利用しようとします。 したがって、複数の StopPodSandbox 呼び出しが予想されます。
(※冪等性)

#### [message]StopPodSandboxRequest

- string pod_sandbox_id: 停止する PodSandbox の ID

#### [message]StopPodSandboxRequest

空

### [RPC メソッド]RemovePodSandbox

RemovePodSandbox は、サンドボックスを削除します。 サンドボックスに実行中のコンテナがある場合は、強制的に終了して削除する必要があります。
この呼び出しはべき等であり、サンドボックスがすでに削除されている場合はエラーを返してはなりません。

#### [message]RemovePodSandboxRequest

- string pod_sandbox_id: 削除する PodSandbox の ID

#### [message]RemovePodSandboxResponse

空

### [RPC メソッド]PodSandboxStatus

PodSandboxStatus は、PodSandbox のステータスを返します。 PodSandbox が存在しない場合は、エラーを返します。

#### [message]PodSandboxStatusRequest

- string pod_sandbox_id: ステータスを取得する PodSandbox の ID
- bool verbose: verbose は, PodSandbox に関する追加情報を返すかどうかを示します。

#### [message]PodSandboxStatusResponse

- PodSandboxStatus status: PodSandbox の Status
- map<string, string> info: 情報は、PodSandbox の追加情報です。
  キーは任意の文字列にすることができ、値は json 形式にする必要があります。
  この情報には、デバッグに役立つすべてのものを含めることができます。
  例えば Linux コンテナーベースのコンテナーランタイムのネットワーク名前空間。
  Verbose が true の場合にのみ、空ではない値が返されます。

### [RPC メソッド]ListPodSandbox

ListPodSandbox は、PodSandbox のリストを返します。

#### [message]ListPodSandboxRequest

- PodSandboxFilter filter: PodSandbox のリストをフィルタリングするフィルター

#### [message]ListPodSandboxResponse

- repeated PodSandbox items: PodSandbox のリスト

### [RPC メソッド]CreateContainer

CreateContainer は指定された PodSandbox に新しいコンテナを作成します

#### [message]CreateContainerRequest

- string pod_sandbox_id: コンテナを作成する PodSandbox の ID
- ContainerConfig config: コンテナの config
- [PodSandboxConfig](#messagepodsandboxconfig) sandbox_config: PodSandbox の Config. これは、PodSandbox を作成するために RunPodSandboxRequest に渡された構成と同じです。 簡単に参照できるように、ここで再度渡されます。 PodSandboxConfig は不変であり、ポッドの存続期間を通じて変わりません。

#### [message]CreateContainerResponse

- string container_id: 作成されたコンテナの ID

### [RPC メソッド]StartContainer

StartContainer は，コンテナをスタートします．

#### [message]StartContainerRequest

- string container_id: スタートするコンテナの ID

#### [message]StartContainerResponse

空

### [RPC メソッド]StopContainer

StopContainer は、実行中のコンテナーを猶予期間（つまり、タイムアウト）で停止します。
この呼び出しはべき等であり、コンテナがすでに停止している場合はエラーを返してはなりません。
TODO：猶予期間に達した後、ランタイムは何をする必要がありますか？

#### [message]StopContainerRequest

- string container_id: 止めるコンテナの ID
- int64 timeout: コンテナーが強制的に終了する前に停止するまでのタイムアウト（秒単位）。
  デフォルト：0（コンテナーを即座に強制終了します）

#### [message]StopContainerResponse

空

### [RPC メソッド]RemoveContainer

RemoveContainer はコンテナを削除します。 コンテナが実行中の場合は、コンテナを強制的に削除する必要があります。
この呼び出しはべき等であり、コンテナーが既に削除されている場合はエラーを返してはなりません。

#### [message]RemoveContainerRequest

- string container_id: 削除するコンテナの ID

#### [message]RemoveContainerResponse

空

### [RPC メソッド]ListContainers

ListContainers は、すべてのコンテナーをフィルターでリストします。

#### [message]ListContainersRequest

- ContainerFilter filter: 特に何も書かれてなかったけど，PodSandboxFilter と似たようなものでしょう．

#### [message]ListContainersResponse

- repeated Container containers: コンテナのリスト

### [RPC メソッド]ContainerStatus

ContainerStatus は、コンテナのステータスを返します。 コンテナが存在しない場合、エラーを返します。

#### [message]ContainerStatusRequest

- string container_id: status を取得するコンテナの ID
- bool verbose: コンテナに関する追加情報を返すかどうかを示します。

#### [message]ContainerStatusResponse

- ContainerStatus status: コンテナの status
- map<string, string> info: info はコンテナの追加情報です。 キーは任意の文字列にすることができ、値は json 形式にする必要があります。 この情報には、デバッグに役立つすべてのものを含めることができます。
  例えば Linux コンテナーベースのコンテナーランタイムの pid。
  Verbose が true の場合にのみ、空ではない値が返されます。

### [RPC メソッド]UpdateContainerResources

UpdateContainerResources は、コンテナの ContainerConfig を更新します。

#### [message]UpdateContainerResourcesRequest

- string container_id: 更新するコンテナの Id
- LinuxContainerResources linux: Linux コンテナーに固有のリソース構成

#### [message]UpdateContainerResourcesResponse

空

### [RPC メソッド]ReopenContainerLog

ReopenContainerLog は、コンテナーの stdout / stderr ログファイルを再度開くようランタイムに要求します。 これは、ログファイルがローテーションされた後に呼び出されることがよくあります。 コンテナーが実行されていない場合、コンテナーランタイムは、新しいログファイルを作成して nil を返すか、エラーを返すかを選択できます。
エラーが返されたら、新しいコンテナログファイルを作成しないでください

#### [message]ReopenContainerLogRequest

- string container_id: log を再度開くコンテナの ID

#### [message]ReopenContainerLogResponse

空

### [RPC メソッド]ExecSync

ExecSync は、コンテナー内のコマンドを同期的に実行します。

#### [message]ExecSyncRequest

- string container_id: コンテナ ID
- repeated string cmd: 実行するコマンド
- int64 timeout: コマンドを停止するタイムアウトの秒数。 デフォルト：0（永久に実行）。

#### [message]ExecSyncResponse

- bytes stdout: キャプチャされたコマンドの標準出力。
- bytes stderr: キャプチャされたコマンドの標準エラー出力
- int32 exit_code: コマンドの終了コードを終了します。 デフォルト：0（成功）

### [RPC メソッド]Exec

Exec は、コンテナでコマンドを実行するためのストリーミングエンドポイントを準備します。

#### [message]ExecRequest

- string container_id: コマンドを実行するコンテナ ID
- repeated string cmd: 実行するコマンド
- bool tty: TTY でコマンドを実行するかどうか
- bool stdin: stdin をストリーミングするかどうか。
  `stdin`、`stdout`、 `stderr`のいずれかが true でなければなりません。
- bool stdout: stdout をストリーミングするかどうか
- bool stderr: stderr をストリーミングするかどうか
  `tty`が true の場合、`stderr`は false でなければなりません。 この場合、多重化はサポートされていません。 stdout と stderr の出力は、単一のストリームに結合されます。

#### [message]ExecResponse

- string url: exec ストリーミングサーバーの完全修飾 URL。

### [RPC メソッド]Attach

アタッチは、実行中のコンテナにアタッチするストリーミングエンドポイントを準備します。

#### [message]AttachRequest

- string container_id: アタッチするコンテナの ID
- bool stdin: stdin をストリーミングするかどうか
  `stdin`，`stdout`,`stderr`のいずれかが true でなければいけない．
- bool tty: 接続されているプロセスが TTY で実行されているかどうか。
  これは、ContainerConfig の TTY 設定と一致する必要があります。
- bool stdout: stdout をストリーミングするかどうか
- bool stderr: stderr をストリーミングするかどうか
  `tty`が true の場合、`stderr`は false でなければなりません。 この場合、多重化はサポートされていません。
  stdout と stderr の出力は、単一のストリームに結合されます。

#### [message]AttachResponse

- string url: attach ストリーミングサーバの完全装飾 URL

### [RPC メソッド]PortForward

PortForward は、PodSandbox からポートを転送するストリーミングエンドポイントを準備します。

#### [message]PortForwardRequest

- string pod_sandbox_id: ポートの転送先のコンテナーの ID。(※コンテナの ID?PodSandbox???)
- repeated int32 port: 転送するポート

#### [message]PortForwardResponse

- string url: port-forward ストリーミングサーバの完全装飾 URL

### [RPC メソッド]ContainerStats

ContainerStats はコンテナの統計を返します。 コンテナが存在しない場合、呼び出しはエラーを返します。

#### [message]ContainerStatsRequest

- string container_id: stats の取得を行うコンテナの ID

#### [message]ContainerStatsResponse

- ContainerStats stats: コンテナのスタッツ

### [RPC メソッド]ListContainerStats

ListContainerStats は、実行中のすべてのコンテナの統計を返します。

#### [message]ListContainerStatsRequest

- ContainerStasFilter filter: コンテナのスタッツのためのフィルター

#### [message]ListContainerStatsResponse

- repeated ContainerStats stats: コンテナのスタッツリスト

### [RPC メソッド]UpdateRuntimeConfig

UpdateRuntimeConfig は、指定されたリクエストに基づいてランタイム構成を更新します。

### [RPC メソッド]Status

ステータスは、ランタイムのステータスを返します。

## [Service]ImageService

ImageService は、Image を管理するためのパブリック API を定義します。

### [RPC メソッド]ListImages

ListImages は既存の Image を一覧表示します。

#### [message]ListImagesRequest

- ImageFilter filter: image のリストのフィルタリング

#### [message]ListImagesResponse

- repeated Image images: image のリスト

### [RPC メソッド]ImageStatus

ImageStatus は、イメージのステータスを返します。 画像が存在しない場合、ImageStatusResponse.Image が nil に設定された応答を返します。

#### [message]ImageStatusRequest

- ImageSpec image: spec of the image
- bool verbose: image に関する追加情報を返すかどうか

#### [message]ImageStatusResponse

- Image image: status of the image
- map<string, string> info: 情報は画像の追加情報です。 キーは任意の文字列にすることができ、値は json 形式にする必要があります。 この情報には、デバッグに役立つすべてのものを含めることができます。
  例えば oci イメージベースのコンテナーランタイムのイメージ構成。
  Verbose が true の場合にのみ、空ではない値が返されます。

### [RPC メソッド]PullImage

PullImage は、認証構成を使用して Image を pull します。

#### [message]PullImageRequest

- ImageSpec image: image の spec
- AuthConfig auth: image を pull するための認証 config
- [PodSandboxConfig](#messagepodsandboxconfig) sandbox_config: PodSandbox の構成．PodSandbox コンテキストで image を pull するために使用される．

#### [message]PullImageResponse

- string image_ref: 使用中の画像への参照．殆どのランタイムでは，これは imageID または，ダイジェストである必要があります．

### [RPC メソッド]RemoveImage

RemoveImage は画像を削除します。
この呼び出しはべき等であり、イメージがすでに削除されている場合はエラーを返してはなりません。

#### [message]RemoveImageRequest

- ImageSpec image: 削除する image の spec

#### [message]RemoveImageResponse

空

### [RPC メソッド]ImageFsInfo

ImageFSInfo は、イメージの保存に使用されるファイルシステムの情報を返します。

#### [message]ImageFsInfoRequest

空

#### [message]ImageFsInfoResponse

- repeated FilesystemUsage image_filesystems: image filesystem の情報

## その他の定義されている message

#### [message]PodSandboxConfig

PodSandboxConfig は、サンドボックスを作成するためのすべての必須フィールドとオプションフィールドを保持します。

- PodSandboxMetadata metadata: サンドボックスのメタデータ。 この情報はサンドボックスを一意に識別し、ランタイムはこれを活用して正しい操作を保証する必要があります。 ランタイムはこの情報を使用して、読み取り可能な名前を作成するなど、UX を改善することもできます。
- string hostname: サンドボックスのホスト名。 ホスト名は、ポッドネットワークの名前空間が NODE の場合のみ空にすることができます。
- string log_directory: コンテナーログファイルが格納されているホスト上のディレクトリへのパス。
  デフォルトでは、LogDirectory に入るコンテナーのログは STDOUT および STDERR にフックされます。 ただし、LogDirectory には、個々のコンテナからの構造化されたログデータを含むバイナリログファイルが含まれる場合があります。 たとえば、ファイルは改行で区切られた JSON 構造化ログ、systemd-journald ジャーナルファイル、gRPC トレースファイルなどです。  
  例

  - PodSandboxConfig.LogDirectory=`/var/log/pods/<podUID>/`
  - ContainerConfig.LogPath=`containerName/Instance#.log`

  WARNING: ログ管理と kubelet がコンテナログとどのように連携するかは、[https://issues.k8s.io/24677](https://issues.k8s.io/24677) で活発に議論されています。 議論の進行に伴い、logging の方向が将来変更される可能性があります。

- DNSConfig dns_config: sandbox の DNS 構成
- repeated PortMapping port_mappings: sandbox の Port mappings 情報
- map<string, string> labels: 個々のリソースのスコープと選択に使用できるキーと値のペア
- map<string, string> annotations: 任意のメタデータを格納および取得するために kubelet によって設定される可能性のある非構造化 Key-Value マップ。 これには、Kubernetes API を介してポッドに設定された注釈が含まれます。  
  アノテーションはランタイムによって変更してはなりません（MUST NOT）。 ここに格納されているアノテーションは、この PodSandboxConfig が作成するポッドに関連付けられた PodSandboxStatus に返される必要があります。  
  一般に、kubelet とコンテナランタイムの間の明確に定義されたインターフェースを維持するために、アノテーションはランタイム動作に影響を与えてはなりません（SHOULD NOT）。  
  アノテーションは、ランタイムの作成者が Kubernetes API（ユーザー向けと CRI の両方）に対して不透明な新機能を試す場合にも役立ちます。 ただし、可能な場合はいつでも、ランタイムの作成者は、代わりに新しい機能に対して新しい型付きフィールドを提案することを検討してください。
- LinuxPodSandboxConfig linux: Linux ホストに固有のオプション構成

# DOING NOW

まだまだ終わらんよ(一旦休憩)
