- [bin-stack: 二进制文件存储](#org2fbe068)
  - [k3s](#orgb51ef89)
    - [普通用户权限运行 kubectl](#orge11b139)
  - [openlist](#orge2fb528)
    - [部署](#org0fd0c4d)
    - [初始密码](#org55c4e70)
    - [配置目录](#org3ed8270)
    - [加密目录](#orgc598951)
  - [cloudflare tunnel](#orgd8cfee7)



<a id="org2fbe068"></a>

# bin-stack: 二进制文件存储

使用 k3s 搭建 openlist. cloudflare tunnel 代理流量.


<a id="orgb51ef89"></a>

## k3s

运行命令安装:

```bash
curl -sfL https://get.k3s.io | sh -
```

中国地区服务器安装可以使用以下命令:

```bash
curl -sfL https://rancher-mirror.rancher.cn/k3s/k3s-install.sh | INSTALL_K3S_MIRROR=cn sh -
```


<a id="orge11b139"></a>

### 普通用户权限运行 kubectl

将配置复制到普通用户目录下:

```bash
mkdir -p $HOME/.kube
sudo cp /etc/rancher/k3s/k3s.yaml $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

这样会导致普通用户有权限用户有权限控制整个集群, 谨慎抉择.


<a id="orge2fb528"></a>

## openlist


<a id="org0fd0c4d"></a>

### 部署

应用服务:

```bash
kubectl apply -f openlist.yaml
```

如果是直接 ip 访问或者在外部配置 nginx 等反向代理, 需要将配置文件中的 Service 改为 NodePort 模式.


<a id="org55c4e70"></a>

### 初始密码

初始 admin 密码在日志中, 查看日志:

```bash
kubectl logs -f -l app=openlist
```

其中有 \`Successfully created the admin user and the initial password is: xxxxxxxx\` 类似字样.


<a id="org3ed8270"></a>

### 配置目录

配置目录挂载在 k3s pvc 中, 使用 `kubectl get pvc` 查看 pvc 名称, 物理路径默认在 `/var/lib/rancher/k3s/storage/` 目录存储, 路径名称类似:

```
❯ sudo ls -l /var/lib/rancher/k3s/storage/pvc-b19d4d00-73ab-4896-bb34-878cf7cc7afe_default_openlist-pvc
total 388
-rw-r--r-- 1 user user   2842 Feb 16 19:56 config.json
-rw-r--r-- 1 user user   4096 Feb 16 19:56 data.db
-rw-r--r-- 1 user user  32768 Feb 17 01:29 data.db-shm
-rw-r--r-- 1 user user 346112 Feb 17 01:29 data.db-wal
drwxr--r-- 2 user user   4096 Feb 16 19:56 log
drwxr-xr-x 2 user user   4096 Feb 16 19:56 temp
```


<a id="orgc598951"></a>

### 加密目录

openlist 支持加密配置目录, 内容见: <https://doc.oplist.org/guide/drivers/crypt> , 文档提到了加密后不能修改配置, 实测可以修改除了加密配置项以外的参数, 例如缩略图/排序方式等内容, 不影响加密.

加密目录的配置与 Rclone 完全兼容, 为了防止加密文件丢失, 建议备份密码(password)和盐(salt/password2), 这样就可以在 OpenList 失效的时候, 用 Rclone 随时复原加密文件, Rclone 配置文件路径默认为 `~/.config/rclone/rclone.conf` , 在其中添加以下内容:

```conf
[crypt]
type = crypt
remote = /home/user/crypt
password = <obfuscated_password>
password2 = <obfuscated_password2>
filename_encryption = off
directory_name_encryption = false
```

其中 `filename_encryption` 和 `directory_name_encryption` 标示文件和目录加密方式, 一定要和 OpenList 保持一致, `remote` 是加密文件对应的目录, 也可以是挂载到本地的远程目录, password 和 password2, 对应 OpenList 的密码和盐, 注意不是明文, 是混淆后的密文, Openlist 导出会有带 `___Obfuscated___` 前缀的密文, 可以去掉前缀填写, 但是推荐用备份的明文通过 Rclone 生成, 命令为:

```bash
rclone obscure <password>
```

使用以下命令查看和管理加密目录:

```bash
# 临时挂载加密目录
rclone mount crypt: ~/Downloads/decoded_files --vfs-cache-mode full
# 复制加密文件
rclone copy crypt: ~/Downloads
# 查看加密文件
rclone ls crypt:
```


<a id="orgd8cfee7"></a>

## cloudflare tunnel

应用服务:

```bash
kubectl apply -f cloudflare-tunnel.yaml
```

添加 Token:

```bash
kubectl create secret generic cf-tunnel --from-literal=TUNNEL_TOKEN=<cloudflare-tunnel-token>
```

查看 secret:

```bash
kubectl get secrets
kubectl get secret cf-tunnel -o yaml
```
