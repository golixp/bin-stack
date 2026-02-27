#!/bin/bash
# Openlist PVC 备份与恢复脚本
# 支持 K3s 和 Podman 环境
#
# 使用方法:
#   ./backup-restore.sh backup k3s     <备份目录>    # 备份 K3s 数据
#   ./backup-restore.sh backup podman  <备份目录>    # 备份 Podman 数据
#   ./backup-restore.sh restore k3s    <源目录>      # 恢复到 K3s
#   ./backup-restore.sh restore podman <源目录>      # 恢复到 Podman

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1" >&2; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1" >&2; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

usage() {
    cat << EOF
使用方法:
  $0 <操作> <环境> [路径]

操作:
  backup   备份数据
  restore  恢复数据

环境:
  k3s      K3s 环境
  podman   Podman 环境

示例:
  $0 backup k3s ./backup-20260227       # 备份 K3s 数据到指定目录
  $0 backup podman ./backup-20260227    # 备份 Podman 数据到指定目录
  $0 restore k3s ./backup-20260227      # 从指定目录恢复到 K3s
  $0 restore podman ./backup-20260227   # 从指定目录恢复到 Podman
EOF
    exit 1
}

# 获取 K3s PVC 路径
get_k3s_pvc_path() {
    log_info "正在查找 K3s PVC 路径..."
    
    local pv_name
    pv_name=$(kubectl get pvc openlist-pvc -n default -o jsonpath='{.spec.volumeName}' 2>/dev/null) || {
        log_error "无法获取 PVC 信息，请确认 k3s 集群正常运行"
        exit 1
    }
    
    local pvc_path="/var/lib/rancher/k3s/storage/${pv_name}"
    
    if [ -d "$pvc_path" ]; then
        echo "$pvc_path"
        return 0
    fi
    
    # 尝试查找其他 pvc 目录
    local found_path
    found_path=$(sudo find /var/lib/rancher/k3s/storage -name "pvc-*" -type d 2>/dev/null | head -1)
    if [ -n "$found_path" ]; then
        echo "$found_path"
        return 0
    fi
    
    log_error "未找到 PVC 目录：$pvc_path"
    exit 1
}

# 去除字符串中的换行符和空格
trim() {
    local var="$1"
    var="${var#"${var%%[![:space:]]*}"}"
    var="${var%"${var##*[![:space:]]}"}"
    echo "$var"
}

# 获取 Podman PVC 路径
get_podman_pvc_path() {
    log_info "正在查找 Podman PVC 路径..."
    
    local mountpoint
    mountpoint=$(podman volume inspect openlist-pvc 2>/dev/null | grep -o '"Mountpoint": "[^"]*"' | cut -d'"' -f4)
    
    if [ -n "$mountpoint" ] && [ -d "$mountpoint" ]; then
        echo "$mountpoint"
        return 0
    fi
    
    # 尝试默认路径
    local paths=(
        "$HOME/.local/share/containers/storage/volumes/openlist-pvc/_data"
        "/var/lib/containers/storage/volumes/openlist-pvc/_data"
    )
    
    for path in "${paths[@]}"; do
        if [ -d "$path" ] || sudo [ -d "$path" ] 2>/dev/null; then
            echo "$path"
            return 0
        fi
    done
    
    log_error "未找到 Podman PVC 目录"
    exit 1
}

# 备份数据
do_backup() {
    local env="$1"
    local backup_dir="$2"
    
    if [ -z "$backup_dir" ]; then
        log_error "备份目录不能为空"
        usage
    fi
    
    local pvc_path
    if [ "$env" = "k3s" ]; then
        pvc_path=$(get_k3s_pvc_path)
        pvc_path=$(trim "$pvc_path")
    elif [ "$env" = "podman" ]; then
        pvc_path=$(get_podman_pvc_path)
        pvc_path=$(trim "$pvc_path")
    else
        log_error "未知环境：$env，请使用 k3s 或 podman"
        usage
    fi

    log_info "开始备份数据"
    log_info "源路径：$pvc_path"
    log_info "目标路径：$backup_dir"

    mkdir -p "$backup_dir"

    # 备份 data.db
    if sudo [ -f "$pvc_path/data.db" ]; then
        log_info "备份 data.db..."
        sudo sqlite3 "$pvc_path/data.db" ".backup '$backup_dir/data.db'"
    else
        log_warn "未找到 data.db 文件"
    fi
    
    # 备份 config.json
    if sudo [ -f "$pvc_path/config.json" ]; then
        log_info "备份 config.json..."
        sudo cp "$pvc_path/config.json" "$backup_dir/config.json"
    else
        log_warn "未找到 config.json 文件"
    fi

    # 备份 ssh 目录（如果存在）
    if sudo [ -d "$pvc_path/ssh" ]; then
        log_info "备份 ssh/..."
        sudo cp -r "$pvc_path/ssh" "$backup_dir/"
    fi

    sudo chown -R "$(whoami)":"$(whoami)" "$backup_dir"
    
    log_info "备份完成：$backup_dir"
    ls -la "$backup_dir"
}

# 恢复数据
do_restore() {
    local env="$1"
    local source_dir="$2"
    
    if [ -z "$source_dir" ]; then
        log_error "源目录不能为空"
        usage
    fi
    
    if [ ! -f "$source_dir/data.db" ]; then
        log_error "源目录未找到 data.db: $source_dir"
        exit 1
    fi
    
    if [ ! -f "$source_dir/config.json" ]; then
        log_error "源目录未找到 config.json: $source_dir"
        exit 1
    fi
    
    local pvc_path
    if [ "$env" = "k3s" ]; then
        pvc_path=$(get_k3s_pvc_path)
        pvc_path=$(trim "$pvc_path")
    elif [ "$env" = "podman" ]; then
        pvc_path=$(get_podman_pvc_path)
        pvc_path=$(trim "$pvc_path")
    else
        log_error "未知环境：$env，请使用 k3s 或 podman"
        usage
    fi
    
    log_info "开始恢复数据"
    log_info "源路径：$source_dir"
    log_info "目标路径：$pvc_path"
    
    if [ "$env" = "k3s" ]; then
        # 停止 Deployment
        log_info "暂停 openlist 部署..."
        kubectl scale deployment openlist --replicas=0 2>/dev/null || true
        sleep 2
        
        # 恢复数据
        log_info "恢复 data.db..."
        sudo sqlite3 "$pvc_path/data.db" ".restore '$source_dir/data.db'"
        
        log_info "恢复 config.json..."
        sudo cp "$source_dir/config.json" "$pvc_path/config.json"
        
        # 恢复 ssh 目录（如果存在）
        if [ -d "$source_dir/ssh" ]; then
            log_info "恢复 ssh/..."
            sudo cp -r "$source_dir/ssh" "$pvc_path/"
        fi

        sudo chown -R root:root "$pvc_path"

        # 重启 Deployment
        log_info "重启 openlist 部署..."
        kubectl scale deployment openlist --replicas=1

        log_info "恢复完成"
        log_info "使用 kubectl get pods 检查状态"

    elif [ "$env" = "podman" ]; then
        # 获取容器名称（从 pod 中获取 openlist 容器）
        local container_name
        container_name=$(podman ps -a --filter "pod=openlist-pod" --format "{{.Names}}" | grep -v infra | head -1)

        if [ -z "$container_name" ]; then
            log_error "未找到 openlist 容器"
            exit 1
        fi

        # 停止容器
        log_info "停止 openlist 容器..."
        podman stop "$container_name" 2>/dev/null || true
        sleep 1

        # 恢复数据
        log_info "恢复 data.db..."
        sudo cp "$source_dir/data.db" "$pvc_path/data.db"

        log_info "恢复 config.json..."
        sudo cp "$source_dir/config.json" "$pvc_path/config.json"

        # 恢复 ssh 目录（如果存在）
        if [ -d "$source_dir/ssh" ]; then
            log_info "恢复 ssh/..."
            sudo cp -r "$source_dir/ssh" "$pvc_path/"
        fi

        # 修复权限：容器以 root 运行，但 PVC 目录需要当前用户可访问（Podman rootless）
        log_info "修复 PVC 目录权限..."
        sudo chown -R "$(whoami)":"$(whoami)" "$pvc_path"

        # 重启容器
        log_info "重启 openlist 容器..."
        podman start "$container_name"

        log_info "恢复完成"
        log_info "使用 ./run.sh status 检查状态"
    fi
}

# 主逻辑
if [ $# -lt 2 ]; then
    usage
fi

action="$1"
env="$2"
path="$3"

case "$action" in
    backup)
        do_backup "$env" "$path"
        ;;
    restore)
        do_restore "$env" "$path"
        ;;
    *)
        log_error "未知操作：$action，请使用 backup 或 restore"
        usage
        ;;
esac
