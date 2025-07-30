# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a GitOps repository template for managing deployments of microservice applications using ArgoCD and Kubernetes. It contains infrastructure configurations, application manifests for a microservices architecture, and a comprehensive monitoring stack.

## Architecture

### Directory Structure
- `infrastructure/argocd/` - ArgoCD application definitions
- `infrastructure/local/` - Docker Compose configurations for local development  
- `infrastructure/helm/` - Helm charts for monitoring stack
- `projects/` - Individual project configurations with Kubernetes manifests
  - Each project follows a consistent structure with `kubernetes/base/` and `kubernetes/overlays/` directories
- `docs/` - Documentation files

### Monitoring Stack
This repository includes a complete observability solution:

**Metrics Collection & Storage:**
- Node Exporter: System metrics collection
- VMAgent: Kubernetes metrics collection (Prometheus Agent alternative)
- VictoriaMetrics: High-performance metrics storage (Prometheus alternative)

**Log Collection & Storage:**
- Fluent Bit: Log collection agent (DaemonSet)
- VictoriaLogs: Lightweight log storage (Loki alternative)

**Visualization:**
- Grafana: Unified dashboards and alerting

**Key Features:**
- Lightweight metrics/log stack (50% less resources than Prometheus + Loki)
- Kubernetes-native design with auto-discovery
- High availability support
- Long-term retention (metrics: 30 days, logs: 7 days)

### GitOps Workflow
- ArgoCD monitors this repository and automatically syncs changes to Kubernetes clusters
- The root application (`infrastructure/argocd/root-application.yaml`) manages all child applications
- Applications are deployed to different environments using Kustomize overlays (dev/prod)

### Key Components
- **Backend**: Core server application with REST API (port 6010) and gRPC services (port 26030)
- **Frontend**: Web application with tablet-specific variant
- **Infrastructure**: PostgreSQL, MongoDB, MinIO object storage, Traefik reverse proxy
- **Monitoring**: Complete observability stack with VictoriaMetrics, VictoriaLogs, and Grafana

## Development Commands

### Monitoring Stack (Primary)
```bash
# Install complete monitoring stack
cd infrastructure/helm/install-scripts
EXTERNAL_IP=192.168.1.100 ./install-monitoring.sh

# Individual component installation
helm install victoria-metrics vm/victoria-metrics-single -f infrastructure/helm/charts/victoria-metrics/values-dev.yaml -n monitoring
helm install fluent-bit fluent/fluent-bit -f infrastructure/helm/charts/fluent-bit/values-dev.yaml -n monitoring
helm install vl vm/victoria-logs-single -f infrastructure/helm/charts/victoria-logs/values-dev.yaml -n monitoring
helm install grafana grafana/grafana -f infrastructure/helm/charts/grafana/values-dev.yaml -n monitoring
```

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

### Helm Charts
- Monitoring charts in `infrastructure/helm/charts/` with separate production (`values.yaml`) and development (`values-dev.yaml`) configurations
- External IP configuration via environment variable substitution: `${EXTERNAL_IP}`
- Resource limits and retention policies optimized for each environment

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

### Monitoring Configuration
- VictoriaMetrics configured for high-performance metrics storage
- Fluent Bit configured to collect all container logs with Kubernetes metadata
- VictoriaLogs configured with Loki API compatibility for Grafana integration
- Grafana pre-configured with datasources for both metrics and logs

## Image Management
- Container images stored in your container registry
- Image tags are typically commit hashes for traceability
- ImagePullSecrets configured for private registry access

## Monitoring Access
- Grafana: `http://{EXTERNAL_IP}:80` (admin/admin123)
- VictoriaMetrics: `http://{EXTERNAL_IP}:8428`
- VictoriaLogs: `http://{EXTERNAL_IP}:9428`

## Git Commit Guidelines
- When creating commits, remove any Anthropic/Claude attribution footers or co-author information
- Keep commit messages clean and focused on the actual changes
- Use conventional commit format with Korean descriptions: "feat: 새로운 기능 추가", "fix: 버그 수정", "docs: 문서 업데이트" etc.
- Follow conventional commit format (feat:, fix:, docs:) with Korean commit messages for better team communication
- Reference the updated README.md for project-specific guidelines and setup instructions

## Important Notes
- The monitoring stack uses VictoriaMetrics/VictoriaLogs instead of Prometheus/Loki for better performance
- Fluent Bit is used instead of Vector or vlagent for more stable log collection
- External IPs are used for development access instead of LoadBalancer services
- Grafana Logs Drilldown feature requires Loki datasource type (VictoriaLogs has partial compatibility)
- Always test monitoring stack installation on development environment first