# gitops-template

GitOps 기반 배포 관리 템플릿 저장소입니다. 이 저장소는 다양한 마이크로서비스 프로젝트의 배포 설정을 관리하며, ArgoCD와 Kubernetes를 사용한 배포 방식을 지원합니다.

## 구조

```
gitops-template/
├── projects/                       # 프로젝트별 폴더 (주 구성)
│   ├── app-backend/                # 백엔드 애플리케이션
│   └── app-frontend/               # 웹 프론트엔드
├── infrastructure/                 # 인프라 관련 설정
│   ├── argocd/                     # ArgoCD 애플리케이션 정의
│   └── local/                      # Docker Compose 로컬 개발환경
├── environments/                   # 환경별 통합 설정
└── scripts/                        # 유틸리티 스크립트
```

## 사용 방법

### 로컬 개발환경
```bash
# 전체 스택 실행 (권장)
cd infrastructure/local
docker-compose up -d

# 개별 서비스 실행
cd projects/app-backend/docker
docker-compose up -d
```

### Kubernetes 배포
```bash
# 기본 구성 배포
kubectl apply -k projects/app-backend/kubernetes/base/

# 환경별 배포
kubectl apply -k projects/app-backend/kubernetes/overlays/dev/
kubectl apply -k projects/app-backend/kubernetes/overlays/prod/
```

### GitOps 배포 (ArgoCD)
1. ArgoCD에 애플리케이션 등록: `infrastructure/argocd/applications/`
2. 자동 동기화로 배포 관리
