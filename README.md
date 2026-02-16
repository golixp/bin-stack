

添加Token:

``` shell
kubectl create secret generic cf-tunnel --from-literal=TUNNEL_TOKEN=<cloudflare-tunnel-token>
```

查看secret:

``` shell
kubectl get secrets
kubectl get secret cf-tunnel -o yaml
```
