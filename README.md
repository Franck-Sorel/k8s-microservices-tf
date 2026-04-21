# k3d Local Kubernetes Platform

A world-class local developer platform for repeatable Kubernetes labs using k3d + Taskfile + Helm.

## Why This Platform

- **Fast iteration** - Helm installs in seconds
- **State-based** - Define your stack in YAML
- **Component registry** - Discoverable addons
- **Smart profiles** - One-command stacks
- **AI-agent ready** - Machine-readable configs

## Quick Start

```bash
# Check environment
task check

# Interactive wizard
task wizard

# Apply profile
task profile PROFILE=auth

# Apply full stack
task apply-full
```

## Commands

### Cluster
```bash
task cluster-create          # Create cluster
task cluster-delete        # Delete cluster
task cluster-list         # List clusters
task cluster-use NAME=dev  # Switch context
```

### Install
```bash
task install              # Install minimal (cert-manager)
task apply              # Core components
task apply-full         # All components
task apply-state        # From platform.yaml
```

### Profiles
```bash
task profile PROFILE=minimal   # cert-manager only
task profile PROFILE=auth     # Keycloak + CNPG
task profile PROFILE=storage   # MinIO
task profile PROFILE=ai       # Full AI stack
```

### Status
```bash
task status                    # Full status
task status-keycloak          # Component status
task status-minio
task status-traefik
```

### Port Forward
```bash
task port-forward COMPONENT=keycloak   # Keycloak :8080
task port-forward COMPONENT=minio      # MinIO :9000
task port-forward COMPONENT=librechat  # LibreChat :3080
```

### Remove
```bash
task remove     # Remove releases
task destroy  # Remove + cluster
```

## Component Registry

| Component | Namespace | Category | Profiles |
|-----------|-----------|---------|----------|
| cert-manager | cert-manager | security | minimal, auth, ai |
| traefik | traefik | networking | ai, full |
| cnpg | cnpg-system | database | auth, ai |
| minio | minio | storage | storage, ai |
| redis | redis | cache | ai, full |
| keycloak | keycloak | identity | auth, ai |
| keycloak-db | keycloak-db | database | auth, ai |
| librechat | librechat | ai | ai, full |

## State-Based Apply

Edit `platform.yaml`:

```yaml
cluster:
  name: dev

components:
  traefik: true
  cert-manager: true
  cnpg: true
  minio: true
  keycloak-db: true
  keycloak: true
  redis: true
```

Then:

```bash
task apply-state
```

## Access Services

```bash
# Keycloak
task port-forward COMPONENT=keycloak
# URL: http://localhost:8080/auth
# User: admin / keycloak123

# MinIO
task port-forward COMPONENT=minio
# URL: http://localhost:9000
# User: minioadmin / minioadmin

# LibreChat
task port-forward COMPONENT=librechat
# URL: http://localhost:3080

# Redis
task port-forward COMPONENT=redis
# Port: localhost:6379
# Password: redis123
```

## Dependency Resolution

- keycloak → keycloak-db (auto-enabled)
- librechat → mongodb + meilisearch (embedded)
- cnpg-backups → minio (manual enable)

## Profiles

### minimal
- cert-manager

### auth
- cert-manager
- keycloak-db (PostgreSQL)
- keycloak

### storage
- minio

### ai / full
- All components

## Keycloak Bootstrap

```bash
task bootstrap-keycloak
```

Creates test realm with:
- `dev` realm
- `test-app` client
- `admin` user (password: admin)
- `testuser` user (password: test123)

## Architecture

```
.
├── platform.yaml           # State descriptor
├── Taskfile.yml          # Commands
├── components/          # Registry
│   ├── keycloak/
│   ├── minio/
│   └── ...
├── values/             # Helm values
├── manifests/          # Manifests
├── scripts/
│   └── wizard.sh
└── .platform/
    └── state/         # State tracking
```

## Stack

- **k3d** - Kubernetes in Docker
- **Task** - Task automation
- **Helm** - Chart delivery
- **kubectl** - Kubernetes CLI

## Current Cluster

Running on `k3d-envoy-observability-gateway` with all core components.