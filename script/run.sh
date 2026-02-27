#!/bin/bash
# Podman 本地运行脚本
# 使用方法: ./run.sh 或 ./run.sh clean

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

STACK_NAME="openlist"
YAML_FILE="openlist-podman.yaml"

# 生成 podman 兼容的 YAML
generate_yaml() {
	echo "生成 Podman 配置..."
	kustomize build "$PROJECT_ROOT/overlays/podman" >"$YAML_FILE"
	echo "配置已生成：$YAML_FILE"
}

# 启动服务
start() {
	generate_yaml
	echo "启动 Podman 服务..."
	podman kube play "$YAML_FILE"
	echo "服务已启动"
	echo "访问地址：http://localhost:30244"
}

# 停止服务
stop() {
	echo "停止 Podman 服务..."
	podman kube down "$YAML_FILE" 2>/dev/null || true
	# 如果 kube down 不可用，手动清理
	podman pod rm -f "$STACK_NAME" 2>/dev/null || true
	echo "服务已停止"
}

# 清理
clean() {
	stop
	rm -f "$YAML_FILE"
	echo "配置已清理"
}

# 查看状态
status() {
	echo "=== Pod 状态 ==="
	podman pod ps --filter "name=$STACK_NAME" || true
	echo ""
	echo "=== 容器状态 ==="
	podman ps -a --filter "pod=$STACK_NAME" || true
	echo ""
	echo "=== 端口映射 ==="
	podman port "$STACK_NAME" 2>/dev/null || echo "未找到端口映射"
	echo ""
	echo "=== PVC 宿主机目录 ==="
	podman volume inspect openlist-pvc 2>/dev/null | grep -o '"Mountpoint": "[^"]*"' | cut -d'"' -f4 || echo "未找到 PVC 卷"
}

case "${1:-start}" in
start) start ;;
stop) stop ;;
restart) stop && start ;;
clean) clean ;;
status) status ;;
generate) generate_yaml ;;
*)
	echo "用法：$0 {start|stop|restart|clean|status|generate}"
	exit 1
	;;
esac
