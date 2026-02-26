# Podman 本地部署

## 前提条件

- Podman 4.0+
- kustomize 5.0+

## 使用

```bash
# 启动服务
./run.sh

# 查看状态
./run.sh status

# 停止服务
./run.sh stop

# 清理
./run.sh clean
```

## 访问

- HTTP: http://localhost:30244

## 生成 YAML 文件

```bash
# 生成 YAML 文件（可用于其他工具）
kustomize build . > openlist-podman.yaml
```
