# AGENTS.md - Development Guidelines

This repository contains Kubernetes/Kustomize configurations for deploying OpenList to k3s or Podman environments. It is primarily a configuration project, not a traditional codebase with compiled code.

## Project Structure

```
.
├── components/           # Reusable Kustomize components
│   ├── cert-manager/     # cert-manager CRDs
│   ├── config/           # ConfigMap (non-sensitive)
│   ├── openlist-base/    # Main Deployment + PVC
│   ├── openlist-cf-tunnel/
│   ├── openlist-ingress/ # K8s Ingress
│   ├── openlist-node-port/ # NodePort Service
│   ├── openlist-sftp/
│   └── secrets/          # Secret (sensitive)
├── overlays/             # Environment-specific overlays
│   ├── k3s/             # Production k3s
│   └── podman/          # Local development
└── script/              # Utility scripts
    ├── backup-restore.sh
    └── run.sh
```

## Build Commands

### Kustomize Build (Validate Configurations)

```bash
# Build k3s overlay
kustomize build overlays/k3s

# Build podman overlay
kustomize build overlays/podman

# Build and apply directly (k3s)
kustomize build overlays/k3s | kubectl apply -f -

# Build and apply directly (podman)
kustomize build overlays/podman > openlist-podman.yaml && podman kube play openlist-podman.yaml
```

### Shell Scripts

```bash
# Podman operations
cd overlays/podman && ./run.sh start
cd overlays/podman && ./run.sh stop
cd overlays/podman && ./run.sh restart
cd overlays/podman ./run.sh status
cd overlays/podman ./run.sh clean

# Backup/Restore
./script/backup-restore.sh backup k3s ./backup-dir
./script/backup-restore.sh backup podman ./backup-dir
./script/backup-restore.sh restore k3s ./backup-dir
./script/backup-restore.sh restore podman ./backup-dir
```

## Validation Commands

```bash
# Validate YAML syntax
kustomize build overlays/k3s --enable-alpha-plugins

# Check for missing images or invalid references
kubectl apply --dry-run=server -f <(kustomize build overlays/k3s)

# Lint YAML files (install yamllint first)
yamllint .
```

## Code Style Guidelines

### YAML Conventions

- **Indentation**: Use 2 spaces (no tabs)
- **Line length**: Keep lines under 120 characters when practical
- **Document separators**: Use `---` to separate YAML documents in multi-resource files
- **Comments**: Use `#` for comments; place them on their own line when possible
- **Quotes**: Use double quotes for strings that need escaping; single quotes otherwise

Example:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: openlist
  labels:
    app: openlist
spec:
  replicas: 1
  selector:
    matchLabels:
      app: openlist
```

### Kustomize Conventions

- **kustomization.yaml**: Use `apiVersion: kustomize.config.k8s.io/v1beta1` and `kind: Kustomization`
- **resources**: List component paths relative to the kustomization.yaml
- **components vs overlays**: Use `components/` for reusable pieces, `overlays/` for environment-specific configs
- **replacements**: Use for cross-resource configuration substitution (preferred over patches)
- **namePrefix/nameSuffix**: Use for environment-specific naming when needed

### Naming Conventions

- **Kubernetes resources**: Use lowercase with hyphens (e.g., `openlist-pvc`, `openlist-ingress`)
- **Labels/selectors**: Use lowercase with hyphens (e.g., `app: openlist`)
- **ConfigMap keys**: Use uppercase with underscores (e.g., `OPENLIST_DOMAIN`)
- **Environment variables**: Use uppercase with underscores (e.g., `OPENLIST_DOMAIN`)

### Git Conventions

- **Commits**: Use clear, concise messages describing what changed and why
- **Branches**: Use descriptive names (e.g., `add-cf-tunnel`, `fix-ingress-ssl`)
- **Secrets**: Never commit actual secrets to version control; use `.gitignore` and environment-specific overlays

### Shell Script Conventions

- **Shebang**: Use `#!/bin/bash` for bash scripts
- **Error handling**: Use `set -e` at the top of scripts
- **Functions**: Use `function_name()` syntax; place functions before main logic
- **Logging**: Use colored output functions for INFO/WARN/ERROR
- **Quotes**: Always quote variables (e.g., `"$var"`) to handle spaces

Example:
```bash
#!/bin/bash
set -e

log_info() { echo -e "${GREEN}[INFO]${NC} $1" >&2; }

main() {
    local arg="$1"
    case "$arg" in
        start) start_service ;;
        stop) stop_service ;;
    esac
}

main "$@"
```

### Error Handling

- **YAML**: Validate with `kustomize build` before applying; use `--dry-run=server` to catch errors early
- **Shell scripts**: Use `set -e` for immediate exit on errors; check exit codes for commands that may fail
- **Kubernetes**: Always check pod status after deployment with `kubectl get pods`

### Security Guidelines

- Never commit actual secrets (tokens, passwords) to the repository
- Use `.gitignore` to exclude `value.env` and generated YAML files with secrets
- Prefer `Secret` resources over ConfigMaps for sensitive data
- Use Kubernetes namespaces to isolate environments

## Environment-Specific Configuration

### k3s (Production)
- Full Ingress + TLS with cert-manager
- Cloudflare Tunnel support
- Requires: kubectl, k3s cluster, cert-manager (optional)

### podman (Development)
- NodePort for local access
- Simpler setup, no TLS
- Requires: podman, kustomize

## Common Tasks

### Enable/Disable Components
Edit the `resources` list in `overlays/k3s/kustomization.yaml` or `overlays/podman/kustomization.yaml`. Comment/uncomment lines to toggle components.

### Add New Environment
1. Create new directory under `overlays/`
2. Add `kustomization.yaml` with base resources and environment-specific replacements
3. Add environment-specific config in `components/config/config.env`

### Update OpenList Version
Edit `components/openlist-base/openlist.yaml` and change the image tag:
```yaml
image: openlistteam/openlist:latest  # or specific version like v1.2.3
```
