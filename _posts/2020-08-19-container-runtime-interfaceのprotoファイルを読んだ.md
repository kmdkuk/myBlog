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

- [PodSandboxMetadata](#messagepodsandboxmetadata) metadata: サンドボックスのメタデータ。 この情報はサンドボックスを一意に識別し、ランタイムはこれを活用して正しい操作を保証する必要があります。 ランタイムはこの情報を使用して、読み取り可能な名前を作成するなど、UX を改善することもできます。
- string hostname: サンドボックスのホスト名。 ホスト名は、ポッドネットワークの名前空間が NODE の場合のみ空にすることができます。
- string log_directory: コンテナーログファイルが格納されているホスト上のディレクトリへのパス。
  デフォルトでは、LogDirectory に入るコンテナーのログは STDOUT および STDERR にフックされます。 ただし、LogDirectory には、個々のコンテナからの構造化されたログデータを含むバイナリログファイルが含まれる場合があります。 たとえば、ファイルは改行で区切られた JSON 構造化ログ、systemd-journald ジャーナルファイル、gRPC トレースファイルなどです。  
  例

  - PodSandboxConfig.LogDirectory=`/var/log/pods/<podUID>/`
  - ContainerConfig.LogPath=`containerName/Instance#.log`

  WARNING: ログ管理と kubelet がコンテナログとどのように連携するかは、[https://issues.k8s.io/24677](https://issues.k8s.io/24677) で活発に議論されています。 議論の進行に伴い、logging の方向が将来変更される可能性があります。

- [DNSConfig](#messagednsconfig) dns_config: sandbox の DNS 構成
- repeated PortMapping port_mappings: sandbox の Port mappings 情報
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

#### [message]LinuxPodSandboxConfig

LinuxPodSandboxConfig は、Linux ホストプラットフォームと Linux ベースのコンテナのプラットフォーム固有の構成を保持します。

- string cgroup_parent: PodSandbox の親 cgroup。
  cgroupfs スタイルの構文が使用されますが、コンテナランタイムは必要に応じてそれを systemd セマンティクスに変換できます。
- [LinuxSandboxSecurityContext](#messagelinuxsandboxsecuritycontext) security_context: LinuxSandboxSecurityContext は、サンドボックスのセキュリティ属性を保持します。
- map<string, string> sysctls: Sysctls はサンドボックスの Linux sysctls 設定を保持します。

#### [message]LinuxSandboxSecurityContext

LinuxSandboxSecurityContext は、サンドボックスに適用される Linux セキュリティ設定を保持します。
ご了承ください：
1）ポッド内のコンテナには適用されません。
2）実行中のプロセスを含まない PodSandbox には適用されない場合があります。

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

- ContainerMetadata metadata: コンテナのメタデータ。 この情報はコンテナを一意に識別し、ランタイムはこれを活用して正しい操作を保証する必要があります。 ランタイムはこの情報を使用して、読み取り可能な名前を作成するなど、UX を改善することもできます。
- ImageSpec image: 使ってる image
- repeated string command: 実行するコマンド（Docker のエントリポイント）
- repeated string args: コマンドの引数(Docker のコマンド)
- string working_dir: コマンドの現在の作業ディレクトリ
- repeated KeyValue envs: コンテナにセットする環境変数のリスト
- repeated Mount mounts: コンテナのマウント
- repeated Device devices: コンテナのデバイス
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
- LinuxContainerConfig linux: Linux コンテナ固有の構成
- WindowsContainerConfig windows: Windows コンテナ固有の構成

# DOING NOW

まだまだ終わらんよ(一旦休憩)
