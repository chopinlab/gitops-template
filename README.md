# GitOps 템플릿

GitOps 기반 배포 관리 템플릿 저장소입니다. ArgoCD와 Kubernetes를 사용한 마이크로서비스 배포 환경과 모니터링 시스템을 제공합니다.

## 프로젝트 구조

```
gitops-template/
├── infrastructure/                 # 인프라 관련 설정
│   ├── argocd/                     # ArgoCD 애플리케이션 정의
│   ├── local/                      # Docker Compose 로컬 개발환경
│   ├── helm/                       # Helm 차트 모니터링 스택
│   └── server-setup.md            # 서버 초기 설정 가이드
├── projects/                       # 프로젝트별 Kubernetes 매니페스트
│   ├── app-backend/                # 백엔드 애플리케이션
│   └── app-frontend/               # 웹 프론트엔드
└── docs/                          # 문서
```

## 모니터링 스택

이 템플릿은 완전한 관측성(Observability) 솔루션을 제공합니다:

### 메트릭 수집 및 저장
- **Node Exporter**: 시스템 메트릭 수집
- **VMAgent**: Kubernetes 메트릭 수집 (Prometheus Agent 대체)
- **VictoriaMetrics**: 메트릭 저장소 (Prometheus 대체, 고성능)

### 로그 수집 및 저장
- **Fluent Bit**: 로그 수집 에이전트 (DaemonSet)
- **VictoriaLogs**: 로그 저장소 (Loki 대체, 경량화)

### 시각화
- **Grafana**: 통합 대시보드 및 알람

### 주요 특징
- ✅ **경량화된 메트릭/로그 스택** (기존 Prometheus + Loki 대비 50% 적은 리소스)
- ✅ **Kubernetes 네이티브** 설계
- ✅ **Auto-Discovery** 기반 메트릭/로그 수집
- ✅ **High Availability** 지원
- ✅ **장기 보존** (메트릭: 30일, 로그: 7일)

## 시작하기

### 1. 서버 환경 구축

서버 초기 설정을 위해 [서버 설정 가이드](infrastructure/server-setup.md)를 참고하세요.

주요 구성 요소:
- Ubuntu 서버 기본 설정
- Docker & Docker Compose
- Kubernetes (K3s) with TLS SAN 설정
- Zsh & 개발 도구 (pyenv 등)

### 2. 모니터링 스택 설치

```bash
# Helm 레포지토리 추가
helm repo add vm https://victoriametrics.github.io/helm-charts/
helm repo add grafana https://grafana.github.io/helm-charts/
helm repo add fluent https://fluent.github.io/helm-charts/
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts/
helm repo update

# 모니터링 네임스페이스 생성
kubectl create namespace monitoring

# 전체 모니터링 스택 설치 (자동화 스크립트)
cd infrastructure/helm/install-scripts
EXTERNAL_IP=192.168.1.100 ./install-monitoring.sh
```

**설치되는 구성요소:**
- VictoriaMetrics (메트릭 저장소)
- Node Exporter (시스템 메트릭)
- Fluent Bit (로그 수집)
- VictoriaLogs (로그 저장소)
- Grafana (시각화)

### 3. 로컬 개발환경 (Docker Compose)

```bash
# 환경변수 파일 설정
cd infrastructure/local
cp .env.example .env
# .env 파일을 실제 값으로 수정

# 전체 인프라 스택 실행
docker-compose up -d
```

**포함된 서비스:**
- **Traefik**: 리버스 프록시 (80, 443 포트)
- **Registry**: Docker 이미지 레지스트리
- **WireGuard**: VPN 서버
- **TimescaleDB**: PostgreSQL + 시계열 데이터베이스

### 4. Kubernetes 애플리케이션 배포

```bash
# 기본 구성 배포
kubectl apply -k projects/app-backend/kubernetes/base/

# 환경별 배포
kubectl apply -k projects/app-backend/kubernetes/overlays/dev/
kubectl apply -k projects/app-backend/kubernetes/overlays/prod/
```

### 5. 원격 Kubernetes 접근 (맥북 등)

1. **서버에서 kubeconfig 복사:**
```bash
cat ~/.kube/config
```

2. **클라이언트에서 kubectl 설정:**
```bash
# kubectl 설치 (macOS)
brew install kubectl

# kubeconfig 설정
mkdir -p ~/.kube
# 서버에서 복사한 내용을 ~/.kube/config에 저장
# server 주소를 실제 서버 IP로 변경: https://your-server-ip:6443

# 연결 테스트
kubectl cluster-info
kubectl get nodes
```

## 모니터링 접근

모니터링 스택 설치 후 다음 URL로 접근 가능합니다:

```bash
# 서비스 확인
kubectl get svc -n monitoring

# 접근 방법 (externalIPs 방식)
Grafana: http://your-server-ip:80
VictoriaMetrics: http://your-server-ip:8428
VictoriaLogs: http://your-server-ip:9428
```

**Grafana 로그인:**
- Username: `admin`
- Password: `admin123`

**데이터소스 설정:**
- VictoriaMetrics: `http://victoria-metrics-server:8428`
- VictoriaLogs: `http://victoria-logs-server:9428` (Loki 타입으로 설정)

## 환경변수 관리

### 필수 환경변수 (.env 파일)

```bash
# 모니터링 서버 IP
EXTERNAL_IP=192.168.1.100

# Docker Registry
REGISTRY_HOST=registry.your-domain.com

# WireGuard VPN
WG_HOST=your-server.duckdns.org
WG_PASSWORD_HASH=your_bcrypt_hash

# TimescaleDB
POSTGRES_DB=your_database
POSTGRES_USER=your_username
POSTGRES_PASSWORD=your_secure_password
```

### 보안 고려사항

- `.env` 파일은 Git에 커밋되지 않습니다
- `.env.example` 파일을 참고하여 실제 값으로 설정하세요
- 민감한 정보는 환경변수로 분리되어 있습니다

## GitOps 워크플로우

1. **코드 변경** → Git Push
2. **ArgoCD 감지** → 자동 동기화
3. **Kubernetes 배포** → 서비스 업데이트

ArgoCD 애플리케이션 설정: `infrastructure/argocd/applications/`

## 주요 기능

### 인프라
- ✅ **환경변수 기반 설정 관리**
- ✅ **TLS/SSL 인증서 자동 관리** (Traefik)
- ✅ **원격 Kubernetes 클러스터 접근**
- ✅ **Docker 이미지 레지스트리**
- ✅ **VPN 서버 (WireGuard)**
- ✅ **시계열 데이터베이스 (TimescaleDB)**
- ✅ **GitOps 기반 자동 배포**

### 모니터링
- ✅ **메트릭 수집**: 시스템, 애플리케이션, Kubernetes
- ✅ **로그 수집**: 모든 컨테이너 로그 자동 수집
- ✅ **시각화**: Grafana 대시보드
- ✅ **알람**: 메트릭/로그 기반 알림
- ✅ **장기 보존**: 효율적인 데이터 저장
- ✅ **고가용성**: 클러스터 환경 지원

## 문제 해결

### K3s Traefik 포트 충돌
K3s는 기본적으로 내장 Traefik을 80, 443 포트에서 실행합니다. Docker Compose Traefik과 충돌 시:

```bash
# K3s 내장 Traefik 비활성화
echo '--disable traefik' | sudo tee -a /etc/rancher/k3s/config.yaml
sudo systemctl restart k3s
```

### 원격 kubectl 접근 오류
인증서 오류 발생 시 K3s 설치 시 `--tls-san` 옵션이 누락되었을 가능성이 높습니다. [서버 설정 가이드](infrastructure/server-setup.md)의 K3s 재설치 섹션을 참고하세요.

### 모니터링 관련 문제

```bash
# 모니터링 스택 상태 확인
kubectl get pods -n monitoring
kubectl get svc -n monitoring

# 로그 확인
kubectl logs -n monitoring deployment/grafana
kubectl logs -n monitoring statefulset/victoria-metrics-server
kubectl logs -n monitoring daemonset/fluent-bit

# 설정 확인
helm list -n monitoring
helm get values grafana -n monitoring
```

## 참고 문서

- [Helm 모니터링 스택 가이드](infrastructure/helm/README.md)
- [서버 초기 설정](infrastructure/server-setup.md)
- [VictoriaMetrics 설정](docs/victoria-metrics.md)
- [VictoriaLogs 설정](docs/victoria-logs.md)