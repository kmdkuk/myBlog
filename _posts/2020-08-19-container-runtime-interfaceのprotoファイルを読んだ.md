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

#### [message]VersionResponse

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
  see [https://git.k8s.io/enhancements/keps/sig-node/runtime-class.md](https://git.k8s.io/enhancements/keps/sig-node/runtime-class.md)

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

- [PodSandboxStatus](#messagepodsandboxstatus) status: PodSandbox の Status
- map<string, string> info: 情報は、PodSandbox の追加情報です。
  キーは任意の文字列にすることができ、値は json 形式にする必要があります。  
  この情報には、デバッグに役立つすべてのものを含めることができます。  
  例えば Linux コンテナーベースのコンテナーランタイムのネットワーク名前空間。  
  Verbose が true の場合にのみ、空ではない値が返されます。

### [RPC メソッド]ListPodSandbox

ListPodSandbox は、PodSandbox のリストを返します。

#### [message]ListPodSandboxRequest

- [PodSandboxFilter](#messagepodsandboxFilter) filter: PodSandbox のリストをフィルタリングするフィルター

#### [message]ListPodSandboxResponse

- repeated [PodSandbox](#messagepodsandbox) items: PodSandbox のリスト

### [RPC メソッド]CreateContainer

CreateContainer は指定された PodSandbox に新しいコンテナを作成します

#### [message]CreateContainerRequest

- string pod_sandbox_id: コンテナを作成する PodSandbox の ID
- [ContainerConfig](#messagecontainerconfig) config: コンテナの config
- [PodSandboxConfig](#messagepodsandboxconfig) sandbox_config: PodSandbox の Config. これは、PodSandbox を作成するために RunPodSandboxRequest に渡された構成と同じです。 簡単に参照できるように、ここで再度渡されます。  
  PodSandboxConfig は不変であり、ポッドの存続期間を通じて変わりません。

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
- int64 timeout: コンテナーが強制的に終了する前に停止するまでのタイムアウト（秒単位）  
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

- [ContainerFilter](#messagecontainerfilter) filter: 特に何も書かれてなかったけど，PodSandboxFilter と似たようなものでしょう．

#### [message]ListContainersResponse

- repeated [Container](#messagecontainer) containers: コンテナのリスト

### [RPC メソッド]ContainerStatus

ContainerStatus は、コンテナのステータスを返します。 コンテナが存在しない場合、エラーを返します。

#### [message]ContainerStatusRequest

- string container_id: status を取得するコンテナの ID
- bool verbose: コンテナに関する追加情報を返すかどうかを示します。

#### [message]ContainerStatusResponse

- [ContainerStatus](#messagecontainerstatus) status: コンテナの status
- map<string, string> info: info はコンテナの追加情報です。 キーは任意の文字列にすることができ、値は json 形式にする必要があります。 この情報には、デバッグに役立つすべてのものを含めることができます。  
  例えば Linux コンテナーベースのコンテナーランタイムの pid。  
  Verbose が true の場合にのみ、空ではない値が返されます。

### [RPC メソッド]UpdateContainerResources

UpdateContainerResources は、コンテナの ContainerConfig を更新します。

#### [message]UpdateContainerResourcesRequest

- string container_id: 更新するコンテナの Id
- [LinuxContainerResources](#messagelinuxcontainerresources) linux: Linux コンテナーに固有のリソース構成

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

- [ContainerStats](#messagecontainerstats) stats: コンテナのスタッツ

### [RPC メソッド]ListContainerStats

ListContainerStats は、実行中のすべてのコンテナの統計を返します。

#### [message]ListContainerStatsRequest

- [ContainerStatsFilter](#messagecontainerstatsfilter) filter: コンテナのスタッツのためのフィルター

#### [message]ListContainerStatsResponse

- repeated [ContainerStats](#messagecontainerstats) stats: コンテナのスタッツリスト

### [RPC メソッド]UpdateRuntimeConfig

UpdateRuntimeConfig は、指定されたリクエストに基づいてランタイム構成を更新します。

#### [message]UpdateRuntimeConfigRequest

- [RuntimeConfig](#messageruntimeconfig) runtime_config

#### [message]UpdateRuntimeConfigResponse

空

### [RPC メソッド]Status

ステータスは、ランタイムのステータスを返します。

#### [message]StatusRequest

- bool verbose: verbose は、ランタイムに関する追加情報を返すかどうかを示します

#### [message]StatusResponse

- [RuntimeStatus](#messageruntimestatus) status: ランタイムの status
- map<string, string> info: info はランタイムの追加情報です。 キーは任意の文字列にすることができ、値は json 形式にする必要があります。 情報には、デバッグに役立つすべてのものを含めることができます。 コンテナランタイムで使用されるプラグイン。  
  Verbose が true の場合にのみ、空ではない値が返されます。

## [Service]ImageService

ImageService は、Image を管理するためのパブリック API を定義します。

### [RPC メソッド]ListImages

ListImages は既存の Image を一覧表示します。

#### [message]ListImagesRequest

- [ImageFilter](#messageimagefilter) filter: image のリストのフィルタリング

#### [message]ListImagesResponse

- repeated [Image](#messageimage) images: image のリスト

### [RPC メソッド]ImageStatus

ImageStatus は、イメージのステータスを返します。 画像が存在しない場合、ImageStatusResponse.Image が nil に設定された応答を返します。

#### [message]ImageStatusRequest

- [ImageSpec](#messageimagespec) image: spec of the image
- bool verbose: image に関する追加情報を返すかどうか

#### [message]ImageStatusResponse

- [Image](#messageimage) image: status of the image
- map<string, string> info: 情報は画像の追加情報です。 キーは任意の文字列にすることができ、値は json 形式にする必要があります。 この情報には、デバッグに役立つすべてのものを含めることができます。  
  例えば oci イメージベースのコンテナーランタイムのイメージ構成。  
  Verbose が true の場合にのみ、空ではない値が返されます。

### [RPC メソッド]PullImage

PullImage は、認証構成を使用して Image を pull します。

#### [message]PullImageRequest

- [ImageSpec](#messageimagespec) image: image の spec
- [AuthConfig](#messageauthconfig) auth: image を pull するための認証 config
- [PodSandboxConfig](#messagepodsandboxconfig) sandbox_config: PodSandbox の構成．PodSandbox コンテキストで image を pull するために使用される．

#### [message]PullImageResponse

- string image_ref: 使用中の画像への参照．殆どのランタイムでは，これは imageID または，ダイジェストである必要があります．

### [RPC メソッド]RemoveImage

RemoveImage は画像を削除します。  
この呼び出しはべき等であり、イメージがすでに削除されている場合はエラーを返してはなりません。

#### [message]RemoveImageRequest

- [ImageSpec](#messageimagespec) image: 削除する image の spec

#### [message]RemoveImageResponse

空

### [RPC メソッド]ImageFsInfo

ImageFSInfo は、イメージの保存に使用されるファイルシステムの情報を返します。

#### [message]ImageFsInfoRequest

空

#### [message]ImageFsInfoResponse

- repeated [FilesystemUsage](#messagefilesystemusage) image_filesystems: image filesystem の情報

## その他の定義されている message

#### [message]PodSandboxConfig

PodSandboxConfig は、サンドボックスを作成するためのすべての必須フィールドとオプションフィールドを保持します。

- [PodSandboxMetadata](#messagepodsandboxmetadata) metadata: サンドボックスのメタデータ。 この情報はサンドボックスを一意に識別し、ランタイムはこれを活用して正しい操作を保証する必要があります。 ランタイムはこの情報を使用して、読み取り可能な名前を作成するなど、UX を改善することもできます。
- string hostname: サンドボックスのホスト名。 ホスト名は、ポッドネットワークの名前空間が NODE の場合のみ空にすることができます。
- string log_directory: コンテナーログファイルが格納されているホスト上のディレクトリへのパス。
  デフォルトでは、LogDirectory に入るコンテナーのログは STDOUT および STDERR にフックされます。 ただし、LogDirectory には、個々のコンテナからの構造化されたログデータを含むバイナリログファイルが含まれる場合があります。 たとえば、ファイルは改行で区切られた JSON 構造化ログ、systemd-journald ジャーナルファイル、gRPC トレースファイルなどです。  
  例

  - PodSandboxConfig.LogDirectory=`/var/log/pods/<podUID>/`
  - ContainerConfig.LogPath=`containerName/Instance#.log`

  WARNING: ログ管理と kubelet がコンテナログとどのように連携するかは、[https://issues.k8s.io/24677](https://issues.k8s.io/24677) で活発に議論されています。 議論の進行に伴い、logging の方向が将来変更される可能性があります。

- [DNSConfig](#messagednsconfig) dns_config: sandbox の DNS 構成
- repeated [PortMapping](#messageportmapping) port_mappings: sandbox の Port mappings 情報
- map<string, string> labels: 個々のリソースのスコープと選択に使用できるキーと値のペア
- map<string, string> annotations: 任意のメタデータを格納および取得するために kubelet によって設定される可能性のある非構造化 Key-Value マップ。 これには、Kubernetes API を介してポッドに設定された注釈が含まれます。  
  アノテーションはランタイムによって変更してはなりません（MUST NOT）。 ここに格納されているアノテーションは、この PodSandboxConfig が作成するポッドに関連付けられた PodSandboxStatus に返される必要があります。  
  一般に、kubelet とコンテナランタイムの間の明確に定義されたインターフェースを維持するために、アノテーションはランタイム動作に影響を与えてはなりません（SHOULD NOT）。  
  アノテーションは、ランタイムの作成者が Kubernetes API（ユーザー向けと CRI の両方）に対して不透明な新機能を試す場合にも役立ちます。 ただし、可能な場合はいつでも、ランタイムの作成者は、代わりに新しい機能に対して新しい型付きフィールドを提案することを検討してください。
- [LinuxPodSandboxConfig](#messagelinuxpodsandboxconfig) linux: Linux ホストに固有のオプション構成

#### [message]PodSandboxMetadata

PodSandboxMetadata は、サンドボックス名を作成するために必要なすべての情報を保持しています。  
コンテナーランタイムは、ユーザーエクスペリエンスを向上させるために、ユーザーインターフェイスで PodSandbox に関連付けられたメタデータを公開することをお勧めします。 たとえば、ランタイムはメタデータに基づいて一意の PodSandboxName を構築できます。

- string name: サンドボックスのポッド名。 Pod ObjectMeta のポッド名と同じ
- string uid: サンドボックスのポッド UID。 Pod ObjectMeta のポッド UID と同じ
- string namespace: サンドボックスのポッド名前空間。 Pod ObjectMeta のポッド名前空間と同じ
- uint32 attempt: サンドボックスの作成試行回数。 デフォルト：0

#### [message]DNSConfig

サンドボックスの DNS サーバと search domain を指定する．

- repeated string servers: クラスタの DNS サーバのリスト
- repeated string searched: クラスタの DNS search domain のリスト
- repeated string options: DNS のオプションリスト．See [https://linux.die.net/man/5/resolv.conf](https://linux.die.net/man/5/resolv.conf)で利用可能なすべてのオプション

#### [message]PortMapping

PortMapping は、サンドボックスのポートマッピング構成を指定します

- [Protocol](#enumprotocol) protocol: ポートマッピングのプロトコル
- int32 container_port: コンテナ内のポート番号。 デフォルト：0（指定なし）
- int32 host_port: ホストのポート番号。 デフォルト：0（指定なし）
- string host_ip

#### [enum]Protocol

- TCP = 0
- UDP = 1
- SCTP = 2

#### [message]LinuxPodSandboxConfig

LinuxPodSandboxConfig は、Linux ホストプラットフォームと Linux ベースのコンテナのプラットフォーム固有の構成を保持します。

- string cgroup_parent: PodSandbox の親 cgroup。  
  cgroupfs スタイルの構文が使用されますが、コンテナランタイムは必要に応じてそれを systemd セマンティクスに変換できます。
- [LinuxSandboxSecurityContext](#messagelinuxsandboxsecuritycontext) security_context: LinuxSandboxSecurityContext は、サンドボックスのセキュリティ属性を保持します。
- map<string, string> sysctls: Sysctls はサンドボックスの Linux sysctls 設定を保持します。

#### [message]LinuxSandboxSecurityContext

LinuxSandboxSecurityContext は、サンドボックスに適用される Linux セキュリティ設定を保持します。
ご了承ください：

1. ポッド内のコンテナには適用されません。
2. 実行中のプロセスを含まない PodSandbox には適用されない場合があります。

- [NamespaceOption](#messagenamespaceoption) namespace_options: サンドボックスの名前空間の構成。
  これは、PodSandbox が分離にネームスペースを使用する場合にのみ使用されます。
- [SELinuxOption](#messageselinuxoption) selinux_options: 適用されるオプションの SELinux コンテキスト
- [Int64Value](#messageint64value) run_as_user: サンドボックスプロセスを実行する UID（該当する場合）。
- [Int64Value](#messageint64value) run_as_group: 該当する場合、サンドボックスプロセスを実行するための GID。 run_as_group は、run_as_user が指定されている場合にのみ指定する必要があります。 そうでない場合、ランタイムはエラーになります。
- bool readonly_rootfs: 設定されている場合、サンドボックスのルートファイルシステムは読み取り専用です
- repeated int64 supplemental_groups: サンドボックスのプライマリ GID に加えて、サンドボックスで実行される最初のプロセスに適用されるグループのリスト
- bool privileged: サンドボックスが特権コンテナの実行を要求されるかどうかを示します。 特権コンテナがその中で実行される場合、これは真でなければなりません。  
  これにより、特権コンテナの実行が予想されない場合に、サンドボックスが追加のセキュリティ対策を講じることができます。
- string seccomp_profile_path: サンドボックスの Seccomp プロファイル。候補値は次のとおりです。

  - `runtime/default`：コンテナーランタイムのデフォルトプロファイル
  - `unconfined`：unconfined プロファイル、つまり、seccomp サンドボックス化なし
  - `localhost/<full-path-to-profile>`：ノードにインストールされているプロファイル。  
    `<full-path-to-profile>`は、プロファイルの完全パスです。

  デフォルト： ""、これは制限のないものと同じです。

#### [message]NamespaceOption

NamespaceOption は Linux 名前空間のオプションを提供します

- [NamespaceMode](#enumnamespacemode) network: このコンテナ/サンドボックスのネットワーク名前空間。  
  注：現在、Kubernetes API で CONTAINER スコープのネットワークを設定する方法はありません。  
  現在 kubelet によって設定されている名前空間：POD、NODE
- [NamespaceMode](#enumnamespacemode) pid: このコンテナ/サンドボックスの PID 名前空間。  
  注：CRI のデフォルトは POD ですが、v1.PodSpec のデフォルトは CONTAINER です。  
  kubelet のランタイムマネージャーは、v1 ポッドに対して明示的に CONTAINER に設定します。  
  現在 kubelet によって設定されている名前空間：POD、CONTAINER、NODE、TARGET
- [NamespaceMode](#enumnamespacemode) ipc: このコンテナ/サンドボックスの IPC 名前空間。  
  注：現在、Kubernetes API で CONTAINER スコープの IPC を設定する方法はありません。  
  現在 kubelet によって設定されている名前空間：POD、NODE
- string target_id: TARGET の NamespaceMode のターゲットコンテナ ID。 このコンテナは、以前に同じポッドで作成されている必要があります。 名前空間ごとに異なるターゲットを指定することはできません。

#### [enum]NamespaceMode

NamespaceMode は、NamespaceOption の各名前空間（Network、PID、IPC）の意図された名前空間構成を記述します。 ランタイムは、ランタイムの基礎となるテクノロジーに応じて、これらのモードをマップする必要があります。

- POD = 0: POD 名前空間は、ポッド内のすべてのコンテナーに共通です。  
  たとえば、POD の PID 名前空間を持つコンテナは、ポッド内のすべてのコンテナ内のすべてのプロセスを表示することを期待しています。
- CONTAINER = 1: CONTAINER 名前空間は単一のコンテナーに制限されています。  
  たとえば、PID 名前空間が CONTAINER のコンテナは、そのコンテナ内のプロセスのみを表示することを想定しています。
- NODE = 2: NODE 名前空間は、Kubernetes ノードの名前空間です。  
  たとえば、NODE の PID 名前空間を持つコンテナは、kubelet を実行しているホスト上のすべてのプロセスを表示することを期待しています。
- TARGE = 3: TARGET は別のコンテナの名前空間をターゲットにします。 これを指定する場合、target_id を NamespaceOption で指定し、NamespaceMode CONTAINER を使用して以前に作成したコンテナーを参照する必要があります。 このコンテナー名前空間は、コンテナー target_id の名前空間と一致するように作成されます。  
  たとえば、PID 名前空間が TARGET のコンテナは、target_id コンテナが表示できるすべてのプロセスを表示することを期待しています。

#### [message]SELinuxOption

SELinuxOption は、コンテナーに適用されるラベルです。

- string user
- string role
- string type
- string level

#### [message]Int64Value

Int64Value は int64 のラッパー

- int64 value

#### [message]PodSandboxStatus

PodSandboxStatus には、PodSandbox のステータスが含まれます

- string id: sandbox の ID
- [PodSandboxMetadata](#messagepodsandboxmetadata) metadata: sandbox の metadata
- [PodSandboxState](#enumpodsandboxstate) state: sandbox の state
- int64 created_at: サンドボックスの作成タイムスタンプ（ナノ秒単位）。 0 より大きい必要があります
- [PodSandboxNetworkStatus](#messagepodsandboxnetworkstatus) network: ネットワークがランタイムによって処理される場合、ネットワークにはネットワークステータスが含まれます
- [LinuxPodSandboxStatus](#messagelinuxpodsandboxstatus) linux: pod sandbox への Linux 固有のステータス
- map<string, string> labels: ラベルは、個々のリソースのスコープと選択に使用できるキーと値のペアです
- map<string, string> annotations: 任意のメタデータを保持する非構造化 Key-Value マップ。  
  アノテーションはランタイムによって変更してはなりません（MUST NOT）。 このフィールドの値は、このステータスが表すポッドサンドボックスのインスタンス化に使用される対応する PodSandboxConfig の値と同じである必要があります。
- string runtime_handler: この PodSandbox に使用されるランタイム構成

#### [enum]PodSandboxState

- SANDBOX_READY = 0
- SANDBOX_NOTREADY = 1

#### [message]PodSandboxNetworkStatus

PodSandboxNetworkStatus は、PodSandbox のネットワークのステータスです

- string ip: PodSandbox の IP アドレス
- repeated [PodIP](#messagepodip) additional_ips: PodSandBoxNetworkStatus の追加の ips（PodSandboxNetworkStatus.Ip を含まない）のリスト

#### [message]PodIP

PodIP はポッドの IP を表します

- string ip: ip は IPv4 または IPv6 の文字列表現

#### [message]LinuxPodSandboxStatus

LinuxSandboxStatus には、Linux サンドボックス固有のステータスが含まれています

- [Namespace](#messagenamespace) namespaces: サンドボックスの名前空間へのパス

#### [message]Namespace

名前空間には名前空間へのパスが含まれています

- [NamespaceOption](#messagenamespaceoption) options: Linux 名前空間の名前空間オプション

#### [message]PodSandboxFilter

PodSandboxFilter は、PodSandboxes のリストをフィルタリングするために使用されます。
これらのフィールドはすべて「AND」で結合されます

- string id: sandbox の ID
- [PodSandboxStateValue](#messagePodSandboxStateValue) state: sandbox の state
- map<string, string> label_selector: 一致を選択するための LabelSelector。  
  現時点では api.MatchLabels のみがサポートされており、要件は AND 演算されます。 MatchExpressions はまだサポートされていません。

#### [message]PodSandboxStateValue

PodSandboxStateValue は PodSandboxState のラッパー

- [PodSandboxState](#enumpodsandboxstate) state: sandbox の state

#### [message]PodSandbox

PodSandbox には、サンドボックスに関する最小限の情報が含まれています

- string id: PodSandbox の ID
- [PodSandboxMetadata](#messagepodsandboxmetadata) metadata: PodSandbox の Metadata
- [PodSandboxState](#enumpodsandboxstate) state: PodSandbox の state
- int64 created_at: ナノ秒単位の PodSandbox の作成タイムスタンプ。 0 より大きい必要があります
- map<string, string> labels: PodSandbox のラベル
- map<string, string> annotations: 任意のメタデータを保持する非構造化 Key-Value マップ。  
  アノテーションはランタイムによって変更してはなりません（MUST NOT）。 このフィールドの値は、この PodSandbox のインスタンス化に使用される対応する PodSandboxConfig の値と同じでなければなりません。
- string runtime_handler: この PodSandbox に使用されるランタイム構成

#### [message]ContainerConfig

ContainerConfig は、コンテナを作成するためのすべての必須フィールドとオプションフィールドを保持します。

- [ContainerMetadata](#messagecontainermetadata) metadata: コンテナのメタデータ。 この情報はコンテナを一意に識別し、ランタイムはこれを活用して正しい操作を保証する必要があります。 ランタイムはこの情報を使用して、読み取り可能な名前を作成するなど、UX を改善することもできます。
- [ImageSpec](#messageimagespec) image: 使ってる image
- repeated string command: 実行するコマンド（Docker のエントリポイント）
- repeated string args: コマンドの引数(Docker のコマンド)
- string working_dir: コマンドの現在の作業ディレクトリ
- repeated [KeyValue](#messagekeyvalue) envs: コンテナにセットする環境変数のリスト
- repeated [Mount](#messagemount) mounts: コンテナのマウント
- repeated [Device](#messagedevice) devices: コンテナのデバイス
- map<string, string> labels: 個々のリソースのスコープと選択に使用できるキーと値のペア。
  ラベルキーの形式は次のとおりです。
  - label-key ::= prefixed-name | name
  - prefixed-name ::= prefix '/' name
  - prefix ::= DNS_SUBDOMAIN
  - name ::= DNS_LABEL
- map<string, string> annotations: 任意のメタデータを格納および取得するために kubelet で使用できる非構造化 Key-Value マップ。  
  アノテーションはランタイムによって変更してはなりません（MUST NOT）。 ここに格納されている注釈は、この ContainerConfig が作成するコンテナに関連付けられている ContainerStatus に返される必要があります。  
  一般に、kubelet とコンテナランタイムの間の明確に定義されたインターフェースを維持するために、アノテーションはランタイム動作に影響を与えてはなりません（SHOULD NOT）。
- string log_path: ホストにログ（STDOUT および STDERR）を格納するコンテナーの PodSandboxConfig.LogDirectory に関連するパス。
  例

  - PodSandboxConfig.LogDirectory = `/var/log/pods/<podUID>/`
  - ContainerConfig.LogPath = `containerName/Instance#.log`

  WARNING：ログ管理と kubelet がコンテナログとどのように連携するかは、[https：//issues.k8s.io/24677](https：//issues.k8s.io/24677) で活発に議論されています。 議論の進行に伴い、logging の方向が将来変更される可能性があります。

- bool stdin: インタラクティブコンテナの変数。これらには非常に特殊なユースケースがあります（デバッグなど）。  
  TODO：Kubernetes の Container Spec の一部であるこれらのフィールドを引き続きサポートする必要があるかどうかを判断します。
- bool stdin_once
- bool tty
- [LinuxContainerConfig](#messagecontainerconfig) linux: Linux コンテナ固有の構成
- [WindowsContainerConfig](#messagewindowscontainerconfig) windows: Windows コンテナ固有の構成

#### [message]ContainerMetadata

ContainerMetadata は、コンテナー名を作成するために必要なすべての情報を保持します。 コンテナーランタイムは、ユーザーエクスペリエンスを向上させるために、ユーザーインターフェイスでメタデータを公開することをお勧めします。 たとえば、ランタイムはメタデータに基づいて一意のコンテナ名を作成できます。 （名前、試行）は、サンドボックスの存続期間全体にわたってサンドボックス内で一意であることに注意してください。

- string name: コンテナの名前。 PodSpec のコンテナー名と同じ
- uint32 attempt: コンテナ作成の試行回数。 デフォルト：0。

#### [message]ImageSpec

ImageSpec は Image の内部表現です

- string name: コンテナの Image フィールド（例：imageID または imageDigest）
- map<string, string> annotations: 任意のメタデータを保持する非構造化 Key-Value マップ。  
  ImageSpec アノテーションを使用すると、ランタイムがマルチアーチイメージ内の特定のイメージをターゲットにするのに役立ちます。

#### [message]KeyValue

- string key
- string value

#### [message]Mount

Mount は、コンテナにマウントするホストボリュームを指定します

- string container_path: コンテナー内のマウントのパス
- string host_path: ホスト上のマウントのパス。 hostPath が存在しない場合、ランタイムはエラーを報告する必要があります。 ホストパスがシンボリックリンクの場合、ランタイムはシンボリックリンクをたどり、実際の宛先をコンテナにマウントする必要があります
- bool readonly: 設定されている場合、マウントは読み取り専用です。
- bool selinux_relabel: 設定されている場合、マウントには SELinux の再ラベル付けが必要です。
- [MountPropagation](#enummountpropagation) propagation: 要求された伝播モード

#### [enum]MountPropagation

- PROPAGATION_PRIVATE = 0; マウント伝播なし（Linux 用語では「プライベート」）
- PROPAGATION_HOST_TO_CONTAINER = 1; マウントはホストからコンテナーに伝播されます（Linux では「rslave」）
- PROPAGATION_BIDIRECTIONAL = 2; マウントはホストからコンテナーへ、およびコンテナーからホストへと伝搬されます（Linux では「rshared」）

#### [message]Device

デバイスは、コンテナーにマウントするホストデバイスを指定します

- string container_path: コンテナー内のデバイスのパス
- string host_path: ホスト上のデバイスのパス
- string permissions: デバイスの cgroups 権限、候補は次のうちの 1 つ以上
  - r-コンテナが指定されたデバイスから読み取ることを許可します。
  - w-コンテナが指定されたデバイスに書き込むことを許可します。
  - m-コンテナがまだ存在しないデバイスファイルを作成できるようにします。

#### [message]LinuxContainerConfig

LinuxContainerConfig には、Linux ベースのコンテナー用のプラットフォーム固有の構成が含まれています。

- [LinuxContainerResources](#messagelinuxcontainerresources) resources: コンテナのリソース仕様
- [LinuxContainerSecurityContext](#messagelinuxcontainersecuritycontext) security_context: コンテナーの LinuxContainerSecurityContext 構成

#### [message]LinuxContainerResources

LinuxContainerResources は、リソースの Linux 固有の構成を指定します。
TODO：`opencontainers/runtime-spec/specs-go` のリソースを直接使用することを検討してください。

- int64 cpu_period: CPU CFS（Completely Fair Scheduler）期間。 デフォルト：0（指定なし）
- int64 cpu_quota: CPU CFS（Completely Fair Scheduler）の割り当て。 デフォルト：0（指定なし）
- int64 cpu_shares: CPU シェア（他のコンテナーに対する相対的な重み）。 デフォルト：0（指定なし）
- int64 memory_limit_in_bytes: バイト単位のメモリ制限。 デフォルト：0（指定なし）
- int64 oom_score_adj: OOMScoreAdj は oom-killer スコアを調整します。 デフォルト：0（指定なし
- string cpuset_cpus: CpusetCpus は、許可される論理 CPU のセットを制約します。 デフォルト： ""（指定なし）
- string cpuset_mems: CpusetMems は、許可されるメモリノードのセットを制限します。 デフォルト： ""（指定なし）
- repeated [HugepageLimit](#messagehugepagelimit) hugepage_limits: ページサイズごとのコンテナーの HugeTLB 使用を制限する HugepageLimits のリスト。 デフォルト：nil（指定なし）

#### [message]HugepageLimit

HugepageLimit は、コンテナーレベルの cgroup のファイル `hugetlb.<hugepagesize>.limit_in_byte`に対応します。
たとえば、「PageSize = 1GB」、「Limit = 1073741824」は、「1073741824」バイトを hugetlb.1GB.limit_in_bytes に設定することを意味します。

- string page_size: PageSize の値の形式は`<size><unit-prefix>B（2MB、1GB）`で、 `hugetlb.<hugepagesize>.limit_in_bytes`にある対応する制御ファイルの`<hugepagesize>`と一致する必要があります。
  `<unit-prefix>`の値は、ベース 1024（ "1KB" = 1024、 "1MB" = 1048576 など）を使用して解析することを目的としています。
- uint64 limit: hugepagesize HugeTLB 使用のバイト単位の制限

#### [message]LinuxContainerSecurityContext

LinuxContainerSecurityContext は、コンテナに適用される Linux セキュリティ構成を保持します

- Capability capabilities: 追加または削除する能力
- bool privileged: 設定されている場合、コンテナーを特権モードで実行します。  
  特権モードは、次のオプションと互換性がありません。 privileged が設定されている場合、次の機能は効果がない場合があります。

  1. capabilities
  2. selinux_options
  3. seccomp
  4. apparmor

  特権モードでは、次の特定のオプションが適用されます。

  1. すべての機能が追加されます。
  2. sysfs 内のカーネルモジュールパスなどの機密パスはマスクされません。
  3. すべての sysfs および procfs マウントは RW でマウントされます。
  4. Apparmor は適用されません。
  5. Seccomp の制限は適用されません。
  6. デバイス cgroup は、デバイスへのアクセスを制限しません。
  7. ホストの `/dev` からのすべてのデバイスがコンテナー内で使用可能です。
  8. SELinux の制限は適用されません（例：label = disabled）

- [NamespaceOption](#messagenamespaceoption) namespace_options: コンテナーの名前空間の構成。  
  コンテナーが分離に名前空間を使用する場合にのみ使用されます。
- [SELinuxOption](#messageselinuxoption) selinux_options: オプションで適用される SELinux コンテキスト。
- [Int64Value](#messageint64value) run_as_user: コンテナープロセスを実行する UID。 一度に指定できるのは、run_as_user および run_as_username のいずれか 1 つだけです。
- [Int64Value](#messageint64value) run_as_group: コンテナープロセスを実行する GID。 run_as_group は、run_as_user または run_as_username が指定されている場合にのみ指定する必要があります。 そうでない場合、ランタイムはエラーになります。
- string run_as_username: コンテナープロセスを実行するユーザー名。 指定する場合、ユーザーはコンテナイメージ（つまり、イメージ内の`/etc/passwd`内）に存在し、ランタイムによってそこで解決される必要があります。 そうでない場合、ランタイムはエラーになります。
- bool readonly_rootfs: 設定されている場合、コンテナのルートファイルシステムは読み取り専用です
- repeated int64 supplemental_groups: コンテナのプライマリ GID に加えて、コンテナで実行される最初のプロセスに適用されるグループのリスト。
- string apparmor_profile: コンテナの AppArmor プロファイル。候補値は次のとおりです。
  - `runtime/default`：プロファイルを指定しないことと同等です。
  - `unconfined`：プロファイルは読み込まれません
  - `localhost/<profile_name>`：ノード（localhost）に名前でロードされたプロファイル。 可能なプロファイル名は[http://wiki.apparmor.net/index.php/AppArmor_Core_Policy_Reference](http://wiki.apparmor.net/index.php/AppArmor_Core_Policy_Reference)で詳しく説明されています
- string seccomp_profile_path: コンテナーの Seccomp プロファイル。候補値は次のとおりです。

  - `runtime/default`：コンテナーランタイムのデフォルトプロファイル
  - `unconfined`：unconfined プロファイル、つまり、seccomp サンドボックス化なし
  - `localhost/<full-path-to-profile>`：ノードにインストールされているプロファイル。 `<full-path-to-profile>`は、プロファイルの完全パスです。

  デフォルト： ""、これは制限のないものと同じです。

- bool no_new_privs: no_new_privs は、no_new_privs のフラグをコンテナーに設定する必要があるかどうかを定義します。
- repeated string masked_paths: masked_paths は、コンテナランタイムによってマスクされるパスのスライスであり、OCI 仕様に直接渡すことができます。
- repeated string readonly_paths: readonly_paths は、コンテナーランタイムによって読み取り専用として設定されるパスのスライスです。これは、OCI 仕様に直接渡すことができます。

#### [message]WindowsContainerConfig

WindowsContainerConfig には、Windows ベースのコンテナーのプラットフォーム固有の構成が含まれています。

- [WindowsContainerResources](#messagewindowscontainerresources) resources: コンテナのリソース仕様
- [WindowsContainerSecurityContext](#messagewindowscontainersecuritycontext) security_context: コンテナーの WindowsContainerSecurityContext 構成

#### [message]WindowsContainerResources

WindowsContainerResources は、リソースの Windows 固有の構成を指定します。

- int64 cpu_shares: CPU シェア（他のコンテナーに対する相対的な重み）。 デフォルト：0（指定なし）
- int64 cpu_count: コンテナーで使用可能な CPU の数。 デフォルト：0（指定なし）
- int64 cpu_maximum: このコンテナーが使用できるプロセッサー・サイクルの割合を、100 倍のパーセンテージとして指定します
- int64 memory_limit_in_bytes: バイト単位のメモリ制限。 デフォルト：0（指定なし）

#### [message]WindowsContainerSecurityContext

WindowsContainerSecurityContext は、コンテナに適用される Windows セキュリティ構成を保持します

- string run_as_username: コンテナープロセスを実行するユーザー名。 指定する場合、ユーザーはコンテナイメージに存在し、ランタイムによって解決される必要があります。
  それ以外の場合、ランタイムはエラーを返す必要があります
- string credential_spec: このコンテナーを実行するために使用する GMSA 資格情報仕様の内容

#### [message]ContainerFilter

ContainerFilter は、コンテナをフィルタリングするために使用されます。
これらのフィールドはすべて「AND」で結合されます

- string id: コンテナの ID
- [ContainerStateValue](#messagecontainerstatevalue) state: コンテナの状態
- string pod_sandbox_id: PodSandbox の ID
- map<string, string> label_selector: 一致を選択するための LabelSelector。
  現時点では api.MatchLabels のみがサポートされており、要件は AND 演算されます。 MatchExpressions はまだサポートされていません。

#### [message]ContainerStateValue

ContainerState のラッパー

- [ContainerState](#enumcontainerstate) state: コンテナの状態

#### [enum]ContainerState

- CONTAINER_CREATED = 0
- CONTAINER_REUNNING = 1
- CONTAINER_EXITED = 2
- CONTAINER_UNKNOWN = 3

#### [message]Container

コンテナは、ID、ハッシュ、コンテナの状態など、コンテナの実行時情報を提供します

- string id: コンテナーを識別するためにコンテナーランタイムによって使用されるコンテナーの ID
- string pod_sandbox_id: このコンテナが属するサンドボックスの ID
- [ContainerMetadata](#messagecontainermetadata) metadata: コンテナのメタデータ
- [ImageSpec](#messageimagespec) image: コンテナのスペック
- string image_ref: 使用中の image への参照。 ほとんどのランタイムでは、これはイメージ ID である必要があります
- [ContainerState](#enumcontainerstate) state: コンテナの状態
- int64 created_at: ナノ秒単位のコンテナーの作成時間
- map<string, string> labels: 個々のリソースのスコープと選択に使用できるキーと値のペア
- map<string, string> annotations: 任意のメタデータを保持する非構造化 Key-Value マップ。
  アノテーションはランタイムによって変更してはなりません（MUST NOT）。 このフィールドの値は、このコンテナのインスタンス化に使用された対応する ContainerConfig の値と同じである必要があります

#### [message]ContainerStatus

ContainerStatus はコンテナのステータスを表します

- string id: コンテナの ID
- [ContainerMetadata](#messagecontainermetadata) metadata: コンテナのメタデータ
- [ContainerState](#enumcontainerstate) state: コンテナの状態
- int64 created_at: ナノ秒単位のコンテナーの作成時間
- int64 started_at: ナノ秒単位のコンテナの開始時間。 デフォルト：0（指定なし）
- int64 finished_at: ナノ秒単位のコンテナーの終了時間。 デフォルト：0（指定なし）
- int32 exit_code: コンテナの終了コード。 finished_at！= 0 の場合にのみ必要 デフォルト：0
- [ImageSpec](#messageimagespec) image: image のスペック
- string image_ref: 使用中の image への参照。 ほとんどのランタイムでは、これはイメージ ID である必要があります
- string reason: コンテナが現在の状態にある理由を説明する簡単なキャメルケース文字列
- string message: コンテナが現在の状態にある理由の詳細を示す、人間が読めるメッセージ
- map<string, string> labels: 個々のリソースのスコープと選択に使用できるキーと値のペア
- map<string, string> annotations: 任意のメタデータを保持する非構造化 Key-Value マップ。
  アノテーションはランタイムによって変更してはなりません（MUST NOT）。 このフィールドの値は、このステータスが表すコンテナのインスタンス化に使用される対応する ContainerConfig の値と同じである必要があります
- repeated [Mount](#messagemount) mounts: コンテナ用のマウント
- string log_path: コンテナのログパス

#### [message]ContainerStatsFilter

ContainerStatsFilter は、コンテナをフィルタリングするために使用されます。
これらのフィールドはすべて「AND」で結合されます

- string id: コンテナの ID
- string pod_sandbox_id: PodSandbox の ID
- map<string, string> label_selector: 一致を選択するための LabelSelector。
  現時点では api.MatchLabels のみがサポートされており、要件は AND 演算されます。 MatchExpressions はまだサポートされていません

#### [message]ContainerStats

ContainerStats はコンテナのリソース使用統計を提供します

- [ContainerAttributes](#messagecontainermetadata) attributes: コンテナの情報
- [CpuUsage](#messagecpuusage) cpu: コンテナから収集された CPU 使用率
- [MemoryUsage](#messagememoryusage) memory: コンテナから収集されたメモリ使用量
- [FilesystemUsage](#messagefilesystemusage) writable_layer: 書き込み可能なレイヤーの使用

#### [message]ContainerAttributes

ContainerAttributes は、コンテナの基本情報を提供します.

- string id: コンテナの ID
- [ContainerMetadata](#messagecontainermetadata) metadata: コンテナのメタデータ
- map<string, string> lables: 個々のリソースのスコープと選択に使用できるキーと値のペア
- map<string, string> annotations: 任意のメタデータを保持する非構造化 Key-Value マップ。
  アノテーションはランタイムによって変更してはなりません（MUST NOT）。 このフィールドの値は、このステータスが表すコンテナのインスタンス化に使用される対応する ContainerConfig の値と同じである必要があります

#### [message]CpuUsage

CpuUsage は CPU 使用率情報を提供します

- int64 timestamp: 情報が収集されたナノ秒単位のタイムスタンプ。 0 より大きい必要があります
- [UInt64Value](#messageuint64value) usage_core_nano_seconds: オブジェクト作成以降の累積 CPU 使用率（すべてのコアの合計）

#### [message]UInt64Value

uint64 のラッパー

- uint64 value

#### [message]MemoryUsage

MemoryUsage provides the memory usage information

- int64 timestamp: 情報が収集されたナノ秒単位のタイムスタンプ。 0 より大きい必要があります
- [UInt64Value](#messageuint64value) working_set_bytes: バイト単位のワーキングセットメモリの量

#### [message]FilesystemUsage

FilesystemUsage は、ファイルシステムの使用情報を提供します

- int64 timestamp: 情報が収集されたナノ秒単位のタイムスタンプ。 0 より大きい必要があります
- FilesystemIdentifier fs_id: ファイルシステムの一意の識別子
- [UInt64Value](#messageuint64value) used_bytes: UsedBytes は、ファイルシステム上の画像に使用されるバイトを表します。
  これは、ファイルシステムで使用される合計バイト数とは異なる場合があり、 `CapacityBytes-AvailableBytes`とは異なる場合があります
- [UInt64](#messageuint64value) inodes_used: InodesUsed は、イメージで使用される i ノードを表します。
  これは「InodesCapacity-InodesAvailable」と等しくない場合があります。これは、基礎となるファイルシステムが image の保存以外の目的にも使用される可能性があるためです。

#### [message]RuntimeConfig

- [NetworkConfig](#messagenetworkconfig) network_config

#### [message]NetworkConfig

- string pod_cidr: ポッド IP アドレスに使用する CIDR。 CIDR が空の場合、ランタイムはそれを省略する必要があります

#### [message]RuntimeStatus

RuntimeStatus は、ランタイムの現在のステータスに関する情報です

- repeated [RuntimeCondition](#messageruntimecondition) conditions: 現在観察されているランタイム条件のリスト

#### [message]RuntimeCondition

RuntimeCondition には、ランタイムの条件情報が含まれています。
実行時条件には次の 2 種類があります。

1. 必要条件：kubelet が正しく機能するための条件が必要です。 必要な条件が満たされていない場合、ノードの準備ができていません。
   必要な条件は次のとおりです。

   - RuntimeReady：RuntimeReady は、ランタイムが稼働中で、基本的なコンテナーを受け入れる準備ができていることを意味します。 コンテナーにはホストネットワークのみが必要です。
   - NetworkReady：NetworkReady は、ランタイムネットワークが稼働中であり、コンテナーネットワークを必要とするコンテナーを受け入れる準備ができていることを意味します。

2. オプションの条件：条件はユーザーに情報を提供しますが、kubelet は依存しません。 条件タイプは任意の文字列であるため、必須ではないすべての条件はオプションです。 これらの条件は、ユーザーがシステムのステータスを理解できるように公開されます。

- string type: ランタイム条件のタイプ
- bool status: 条件のステータス。`true/false` のいずれか。 デフォルト：false
- string reason: 条件の最後の遷移の理由を含む簡単なキャメルケース文字列
- string message: 最後の遷移に関する詳細を示す、人間が読めるメッセージ

#### [message]ImageFilter

- [ImageSpec](#messageimagespec) image: image の spec

#### [message]Image

コンテナ Image の基本的な情報

- string id: image の ID
- repeated string repo_tags: image の他の名前
- repeated string repo_digests: image のダイジェスト
- uint64 size: バイト単位の image のサイズ。 0 より大きい必要があります
- Int64Value uid: コマンドを実行する UID。 これは、コンテナーの作成時にユーザーが指定されていない場合のデフォルトとして使用されます。 UID と次のユーザー名は相互に排他的です
- string username: コマンドを実行するユーザー名。 これは、UID が設定されておらず、コンテナーの作成時にユーザーが指定されていない場合に使用されます
- [ImageSpec](#messageimagespec) spec: annotations を含む image の ImageSpec

#### [message]AuthConfig

AuthConfig には、レジストリに接続するための認証情報が含まれています

- string username
- string password
- string auth
- string server_address
- string identity_token: IdentityToken は、ユーザーを認証し、レジストリのアクセストークンを取得するために使用されます
- string registry_token: RegistryToken は、レジストリに送信されるベアラートークンです
