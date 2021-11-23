---
layout: post
title: Minecraft Serverをkubernetes上に複数立てる方法
date: 2021-11-23 13:10 +0900
tags:
  - kubernetes
  - minecraft
---
どれほど需要があるかはわかりませんが、複数のサーバを一つのクラスタにデプロイして、  
一つの入り口でアクセスドメインごとに各サーバに振り分ける構築ができたので紹介します。  

使ったものは以下の通り、
- Minecraft サーバ用のイメージ: [itzg/docker-minecraft-server](https://github.com/itzg/docker-minecraft-server)
- ドメインでプロキシするためのイメージ: [itzg/mc-router](https://github.com/itzg/mc-router)
- 良しなに Kubernetes のサービスを外部公開するための何かしら。

構成図はこんな感じです。
![]({{site.baseurl}}/images/mc-router/structure.png)

一体どうやってドメインを見て、通信を振り分けてるかはわからないですが、構成は単純なものです。  
mc-router が Minecraft サーバへのアクセスを受け取って、あとは各 Minecraft サーバへ通信を振り分けてくれます。  

以下、実際のマニフェストです。  
mc-routerのデプロイ（[公式のドキュメント](https://github.com/itzg/mc-router/tree/master/docs)を参考に）  
Service の内容や Deploy する Namespace は各自環境に合わせて。  
```yaml
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: mc-router
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: services-watcher
rules:
- apiGroups: [""]
  resources: ["services"]
  verbs: ["watch","list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: mc-router-services-watcher
subjects:
- kind: ServiceAccount
  name: mc-router
  namespace: mcing-system
roleRef:
  kind: ClusterRole
  name: services-watcher
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: v1
kind: Service
metadata:
  name: mc-router
spec:
  type: LoadBalancer
  ports:
  - targetPort: web
    name: web
    port: 8080
  - targetPort: proxy
    name: proxy
    port: 25565
  selector:
    run: mc-router
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    run: mc-router
  name: mc-router
spec:
  selector:
    matchLabels:
      run: mc-router
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        run: mc-router
    spec:
      serviceAccountName: mc-router
      containers:
      - image: itzg/mc-router:latest
        name: mc-router
        args: ["--api-binding", ":8080", "--in-kube-cluster"]
        ports:
        - name: proxy
          containerPort: 25565
        - name: web
          containerPort: 8080
        resources:
          requests:
            memory: 50Mi
            cpu: "100m"
          limits:
            memory: 100Mi
            cpu: "250m"
```

あとは適当に Minecraft サーバのためのリソースを用意  
Service に `mc-router.itzg.me/externalServerName` annotationを良しなにつけてあげると、  
そのドメイン指定で mc-router にアクセスしようとすると、mc-server1-0 の Pod にたどり着く寸法。  
env や Pod にあてがう PersistentVolume とかは、各自環境に読み替えて。  

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mc-server1
spec:
  replicas: 1
  selector:
    matchLabels:
        app: mc-server1
  template:
    metadata:
      labels:
        app: mc-server1
    spec:
      containers:
      - env:
        - name: TYPE
          value: SPIGOT
        - name: VERSION
          value: 1.16.3
        - name: EULA
          value: "true"
        image: itzg/minecraft-server:java8
        imagePullPolicy: IfNotPresent
        name: minecraft
        ports:
        - containerPort: 25565
          name: server-port
          protocol: TCP
        volumeMounts:
        - mountPath: /data
          name: minecraft-data
  volumeClaimTemplates:
  - apiVersion: v1
    kind: PersistentVolumeClaim
    metadata:
      name: minecraft-data
    spec:
      accessModes:
      - ReadWriteOnce
      resources:
        requests:
          storage: 10Gi
      storageClassName: standard
      volumeMode: Filesystem
---
apiVersion: v1
kind: Service
metadata:
  annotations:
    mc-router.itzg.me/externalServerName: server1.your-domain.example.com
  name: mc-server1
spec:
  ports:
  - name: server-port
    port: 25565
    protocol: TCP
    targetPort: server-port
  selector:
    app: mc-server1
```

複数サーバを用意したかったら同様のものをデプロイして `mc-router.itzg.me/externalServerName` を調整することで、  
一つのホストに複数の Minecraft サーバを同居させることができます。  

内容としてはこれだけ。  

余談ですが、個人的に Minecraft のサーバデプロイを簡易化するための[カスタムコントローラMCing](https://github.com/kmdkuk/MCing)を作成しています。  
この構成＋ MCing のテストとして、以下のドメインで Minecraft サーバを公開しています。  

- test.minecraft.kmdkuk.com ver1.17.1
- kmdkuk-minecraft.minecraft.kmdkuk.com ver1.16.3

特にデータの保障とかなく管理もしていませんがお暇な人はどうぞ。  
今後このあたりを利用したり、機能拡充を行って Minecraft サーバを簡易に作成できるサービスも作れたらいいなと思っています。  
