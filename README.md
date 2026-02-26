- [目录结构](#org051227a)
- [前置操作](#orgaf34533)
  - [k3s](#org8a48c96)
    - [普通用户权限运行 kubectl](#orge34074f)
  - [helm](#org64774cd)
  - [cert-manager](#org0623200)
- [部署服务](#org3c37ad6)
  - [组件说明](#org5aed187)
  - [配置说明](#orgb88ec65)
    - [非敏感配置 (\`components/config/config.env\`)](#org431df86)
    - [敏感配置 (\`components/secrets/value.env\`)](#org14b6a2e)
  - [k3s 部署](#orgcaeed35)
  - [podman 部署](#org9402930)
  - [初始密码](#orgaa40dfe)
  - [配置目录](#orgeaeac9f)
  - [加密目录](#org8505524)



<a id="org051227a"></a>

# 目录结构

```
.
├── components/           # 基础组件配置
│   ├── cert-manager/     # cert-manager 配置 (ClusterIssuer, Certificate)
│   ├── config/           # 非敏感配置 (ConfigMap)
│   ├── openlist-base/    # OpenList 基础配置 (Deployment, PVC)
│   ├── openlist-cf-tunnel/  # Cloudflare Tunnel
│   ├── openlist-ingress/    # K8s Ingress (k3s 用)
│   ├── openlist-node-port/  # NodePort Service (podman 用)
│   ├── openlist-sftp/       # SFTP Service (可选)
│   └── secrets/             # 敏感配置 (Secret)
└── overlays/           # 环境特定配置
    ├── k3s/            # K3s 生产环境
    └── podman/         # Podman 本地环境
```

| 环境   | 说明                   | 部署方式                                                |
|------ |---------------------- |------------------------------------------------------- |
| k3s    | 生产环境，带 Ingress 和 HTTPS | `kustomize build overlays/k3s \vert kubectl apply -f -` |
| podman | 本地开发，NodePort 访问 | `cd overlays/podman && ./run.sh`                        |


<a id="orgaf34533"></a>

# 前置操作


<a id="org8a48c96"></a>

## k3s

运行命令安装:

```bash
curl -sfL https://get.k3s.io | sh -
```

中国地区服务器安装可以使用以下命令:

```bash
curl -sfL https://rancher-mirror.rancher.cn/k3s/k3s-install.sh | INSTALL_K3S_MIRROR=cn sh -
```


<a id="orge34074f"></a>

### 普通用户权限运行 kubectl

将配置复制到普通用户目录下:

```bash
mkdir -p $HOME/.kube
sudo cp /etc/rancher/k3s/k3s.yaml $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

这样会导致普通用户有权限用户有权限控制整个集群, 谨慎抉择.


<a id="org64774cd"></a>

## helm

命令安装 helm:

```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

参考官方安装指南: <https://helm.sh/zh/docs/intro/install>


<a id="org0623200"></a>

## cert-manager

个人测试在 2c2g 机器的 k3s 上安装 cert-manager, 会有严重的 io 卡顿, 不建议在低配机器使用.

cert-manager 是自动管理和申请证书的插件, 使用 helm 安装:

```bash
helm install \
  cert-manager oci://quay.io/jetstack/charts/cert-manager \
  --version v1.19.2 \
  --namespace cert-manager \
  --create-namespace \
  --set crds.enabled=true
```

kubectl 安装:

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.19.2/cert-manager.yaml
```

参考官方安装指南: <https://cert-manager.io/docs/installation>


<a id="org3c37ad6"></a>

# 部署服务


<a id="org5aed187"></a>

## 组件说明

```yaml
resources:
  - components/openlist-base # 主服务
  - components/config        # 存储配置键值
  - components/secrets       # 存储密钥
  - components/openlist-cf-tunnel # Cloudflare Tunnel 配置
  - components/openlist-sftp      # OpenList SFTP 服务
  - components/openlist-node-port # 开启服务器 IP 访问服务
  - components/cert-manager       # 证书服务
  - components/openlist-ingress   # traefik 反向代理服务
```

| 组件               | 说明          | k3s | podman |
|------------------ |------------- |--- |------ |
| openlist-base      | OpenList 核心服务 | ✅  | ✅     |
| cert-manager       | 自动 TLS 证书 | ✅  | ❌     |
| openlist-ingress   | Ingress 暴露  | ✅  | ❌     |
| openlist-node-port | NodePort 暴露 | 可选 | ✅     |
| openlist-cf-tunnel | Cloudflare 隧道 | ✅  | ❌     |
| openlist-sftp      | SFTP 服务     | 可选 | 可选   |


<a id="orgb88ec65"></a>

## 配置说明


<a id="org431df86"></a>

### 非敏感配置 (\`components/config/config.env\`)

```bash
OPENLIST_DOMAIN=ol.example.com    # 访问域名
EMAIL=admin@example.com           # 证书通知邮箱
```


<a id="org14b6a2e"></a>

### 敏感配置 (\`components/secrets/value.env\`)

```bash
DNS_API_TOKEN=xxx    # Cloudflare DNS API Token
TUNNEL_TOKEN=xxx     # Cloudflare Tunnel Token
```


<a id="orgcaeed35"></a>

## k3s 部署

修改主目录 `kustomization.yaml` 中的 `resources` 配置, 启用功能.

接下来参考 `components/secrets/value.env.example` 和 `components/config/config.env.example` 中的配置, 其中 `config` 的邮箱和域名和 `secrets` 的 DNS API Token 都是自动申请和续签域名证书用的, 不需要可以不填, Tunnel Token 是使用 Cloudflare Tunnel 需要的, 不需要也可以不填.

之后使用 `kustomize build` 命令查看最终生成的配置文件, 使用命令 `kustomize build . | ssh user@1.2.3.4 "cat > ~/openlist-k3s.yaml"` 可以将配置发送到服务器, 在服务器执行命令安装:

```bash
kubectl apply -f openlist-k3s.yaml
```


<a id="org9402930"></a>

## podman 部署

```bash
cd overlays/podman
./run.sh
```


<a id="orgaa40dfe"></a>

## 初始密码

初始 admin 密码在日志中, 查看日志:

```bash
kubectl logs -f -l app=openlist
```

其中有 \`Successfully created the admin user and the initial password is: xxxxxxxx\` 类似字样.


<a id="orgeaeac9f"></a>

## 配置目录

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


<a id="org8505524"></a>

## 加密目录

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
