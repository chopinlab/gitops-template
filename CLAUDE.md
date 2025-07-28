# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a GitOps repository template for managing deployments of microservice applications using ArgoCD and Kubernetes. It contains infrastructure configurations and application manifests for a microservices architecture.

## Architecture

### Directory Structure
- `infrastructure/argocd/` - ArgoCD application definitions
- `infrastructure/local/` - Docker Compose configurations for local development
- `projects/` - Individual project configurations with Kubernetes manifests
  - Each project follows a consistent structure with `kubernetes/base/` and `kubernetes/overlays/` directories

### GitOps Workflow
- ArgoCD monitors this repository and automatically syncs changes to Kubernetes clusters
- The root application (`infrastructure/argocd/root-application.yaml`) manages all child applications
- Applications are deployed to different environments using Kustomize overlays (dev/prod)

### Key Components
- **Backend**: Core server application with REST API (port 6010) and gRPC services (port 26030)
- **Frontend**: Web application with tablet-specific variant
- **Infrastructure**: PostgreSQL, MongoDB, MinIO object storage, Traefik reverse proxy

## Development Commands

### Docker Compose (Local Development)
```bash
# Start full application stack (recommended for development)
cd infrastructure/local
docker-compose up -d

# Start individual backend service
cd projects/app-backend/docker
docker-compose up -d
```

### Kubernetes Deployment
```bash
# Apply base configurations
kubectl apply -k projects/app-backend/kubernetes/base/

# Apply environment-specific overlays
kubectl apply -k projects/app-backend/kubernetes/overlays/dev/
kubectl apply -k projects/app-backend/kubernetes/overlays/prod/
```

## Configuration Patterns

### Kustomize Structure
- Base configurations in `kubernetes/base/` with `deployment.yaml`, `service.yaml`, `kustomization.yaml`
- Environment overlays in `kubernetes/overlays/{env}/` with patches and environment-specific configurations
- Common labels applied via Kustomize for service discovery

### ArgoCD Applications
- All applications reference this repository with `targetRevision: main`
- Automated sync with prune and self-heal enabled
- Applications use SSH or HTTPS repository URLs

### Service Mesh (Istio)
- VirtualService configurations route traffic based on URL prefixes
- API traffic routed to `/api/v1` and WebSocket traffic to `/ws`
- Frontend static assets served with specific path routing

## Image Management
- Container images stored in your container registry
- Image tags are typically commit hashes for traceability
- ImagePullSecrets configured for private registry access

## Git Commit Guidelines
- When creating commits, remove any Anthropic/Claude attribution footers or co-author information
- Keep commit messages clean and focused on the actual changes
- Use conventional commit format with Korean descriptions: "feat: 새로운 기능 추가", "fix: 버그 수정", "docs: 문서 업데이트" etc.
- Follow conventional commit format (feat:, fix:, docs:) with Korean commit messages for better team communication
- Reference the updated README.md for project-specific guidelines and setup instructions