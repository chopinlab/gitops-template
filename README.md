# GitOps 템플릿

GitOps 기반 배포 관리 템플릿 저장소입니다. ArgoCD와 Kubernetes를 사용한 마이크로서비스 배포 환경을 제공합니다.

## 프로젝트 구조

```
gitops-template/
├── infrastructure/                 # 인프라 관련 설정
│   ├── argocd/                     # ArgoCD 애플리케이션 정의
│   ├── common/                     # Docker Compose 로컬 개발환경
│   └── server-setup.md            # 서버 초기 설정 가이드
├── projects/                       # 프로젝트별 Kubernetes 매니페스트
│   ├── app-backend/                # 백엔드 애플리케이션
│   └── app-frontend/               # 웹 프론트엔드
└── environments/                   # 환경별 통합 설정
```

## 시작하기

### 1. 서버 환경 구축

서버 초기 설정을 위해 [서버 설정 가이드](infrastructure/server-setup.md)를 참고하세요.

주요 구성 요소:
- Ubuntu 서버 기본 설정
- Docker & Docker Compose
- Kubernetes (K3s) with TLS SAN 설정
- Zsh & 개발 도구 (pyenv 등)

### 2. 로컬 개발환경 (Docker Compose)

```bash
# 환경변수 파일 설정
cd infrastructure/common
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

### 3. Kubernetes 배포

```bash
# 기본 구성 배포
kubectl apply -k projects/app-backend/kubernetes/base/

# 환경별 배포
kubectl apply -k projects/app-backend/kubernetes/overlays/dev/
kubectl apply -k projects/app-backend/kubernetes/overlays/prod/
```

### 4. 원격 Kubernetes 접근 (맥북 등)

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

## 환경변수 관리

### 필수 환경변수 (.env 파일)

```bash
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

- ✅ **환경변수 기반 설정 관리**
- ✅ **TLS/SSL 인증서 자동 관리** (Traefik)
- ✅ **원격 Kubernetes 클러스터 접근**
- ✅ **Docker 이미지 레지스트리**
- ✅ **VPN 서버 (WireGuard)**
- ✅ **시계열 데이터베이스 (TimescaleDB)**
- ✅ **GitOps 기반 자동 배포**

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
