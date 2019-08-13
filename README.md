# myblog
jekyllを自前hostして公開してます．
https://blog.kmdkuk.com/

## 自分用
jekyll post "<記事タイトル>"
で新しい記事

Dockerで走らせた際に，baseurlが0.0.0.0:4000になって記事のリンクなどがビルドされてしまうため
ローカルで`jekyll build`してから
`docker-compose build`でbuildした\_siteをDockerImageに埋め込んで
サーブを開始する形をとっています．．．
