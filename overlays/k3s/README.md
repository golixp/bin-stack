# K3s 生产环境部署

## 前提条件

- K3s 集群
- kustomize 5.0+
- cert-manager 已安装
- Traefik Ingress Controller

## 配置

编辑 `../../components/config/config.env` 和 `../../components/secrets/value.env`：

```bash
# config.env
OPENLIST_DOMAIN=ol.yourdomain.com
EMAIL=your@email.com

# value.env
DNS_API_TOKEN=your_cloudflare_dns_token
TUNNEL_TOKEN=your_cloudflare_tunnel_token
```

## 部署

```bash
# 预览配置
kustomize build . | kubectl diff -f -

# 应用配置
kustomize build . | kubectl apply -f -
```

## 验证

```bash
# 检查 Pod 状态
kubectl get pods -A

# 检查证书状态
kubectl get certificate -A

# 检查 Ingress
kubectl get ingress -A
```

## 访问

- HTTPS: https://ol.yourdomain.com
- Cloudflare Tunnel: 自动配置
