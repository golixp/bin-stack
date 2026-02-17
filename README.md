
## 二进制文件存储

使用k3s搭建openlist. cloudflare tunnel代理流量.

### openlist部署

应用服务:

``` shell
kubectl apply -f openlist.yaml
```

如果是直接ip访问或者在外部配置nginx等反向代理, 需要将配置文件中的Service改为NodePort模式.

### cloudflare tunnel 部署

应用服务:

``` shell
kubectl apply -f cloudflare-tunnel.yaml
```

添加Token:

``` shell
kubectl create secret generic cf-tunnel --from-literal=TUNNEL_TOKEN=<cloudflare-tunnel-token>
```

查看secret:

``` shell
kubectl get secrets
kubectl get secret cf-tunnel -o yaml
```
