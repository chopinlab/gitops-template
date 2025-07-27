# gitops-template

GitOps 기반 배포 관리 템플릿 저장소입니다. 이 저장소는 다양한 마이크로서비스 프로젝트의 배포 설정을 관리하며, ArgoCD와 Kubernetes를 사용한 배포 방식을 지원합니다.

## 구조

```
gitops-template/
├── projects/                       # 프로젝트별 폴더 (주 구성)
│   ├── app-backend/                # 백엔드 애플리케이션
│   ├── app-frontend/               # 웹 프론트엔드
│   ├── app-frontend-tablet/        # 태블릿용 프론트엔드
│   └── app-common/                 # 공통 서비스
├── infrastructure/                 # 인프라 관련 설정
├── environments/                   # 환경별 통합 설정
└── scripts/                        # 유틸리티 스크립트
```

## 사용 방법

1. 새 프로젝트 추가: `projects/` 디렉토리에 새 프로젝트 폴더 생성
2. 배포 설정 구성: 프로젝트 폴더 내에 필요한 배포 설정 추가
3. 환경 설정: `environments/` 디렉토리에서 환경별 설정 구성
4. 배포: `scripts/deploy-all.sh` 스크립트를 사용하여 배포
