# JNetHack SSH サーバー

JNetHack 3.4.3-0.11（UTF-8対応）を `dgamelaunch` 経由で提供する Linux コンテナです。[matsuu/docker-jnethack-server](https://github.com/matsuu/docker-jnethack-server/tree/3c5cf266657cfd277d95e9fc5df47343fef5c51a) の Telnet を OpenSSH に置き換えています。

## ビルドと起動

Linux コンテナを使用できる Docker で、このディレクトリから実行します。以下は PowerShell の例です。

```powershell
docker build -t jnethack-server:ssh .
docker run -d --name jnethack --publish 127.0.0.1:2222:22 `
  --volume jnethack-saves:/opt/nethack/nethack.alt.org/nh343/var `
  --volume jnethack-players:/opt/nethack/nethack.alt.org/dgldir `
  --volume jnethack-ssh-host:/var/lib/jnethack/ssh `
  jnethack-server:ssh
```

```powershell
ssh -p 2222 nethack@localhost
```

プレイヤーによる SSH 鍵登録や SSH パスワード入力は不要です。初回接続時は、次のコマンドで表示されるサーバーのホスト鍵指紋とクライアントの表示を照合してください。

```powershell
docker exec jnethack ssh-keygen -lf /var/lib/jnethack/ssh/ssh_host_ed25519_key.pub
```

- `w` で進行中のゲームを観戦できます。
- 初回は `r` でゲームアカウントを登録します。プレイするときは `l` でログインし、`p` で開始・再開できます。

## 公開とデータ保存

外部から接続できるようにする場合は、`--publish 127.0.0.1:2222:22` を `--publish 2222:22` に変更し、接続先のホスト名を案内します。公開する SSH ポートは TCP 2222 です。コンテナ内の SSH は `nethack` 専用で、対話セッションをゲームメニューに限定し、ポート転送を無効にしています。

`jnethack-saves` にセーブやスコア、`jnethack-players` にゲームアカウントやプレイ記録、`jnethack-ssh-host` にサーバーのホスト鍵を保存します。コンテナを作り直すときは同じボリュームを指定してください。
