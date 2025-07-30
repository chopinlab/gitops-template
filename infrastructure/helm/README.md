# Helm 차트 관리

이 디렉토리는 Kubernetes 모니터링 스택의 Helm 차트 values 파일을 관리합니다.

## 디렉토리 구조

```
helm/
├── charts/                         # Helm 차트별 values 파일
│   ├── victoria-metrics/           # 메트릭 저장 (Prometheus 대체)
│   ├── victoria-logs/              # 로그 저장 (Loki 대체)  
│   ├── tempo/                      # 분산 트레이싱
│   ├── grafana/                    # 대시보드
│   └── sops/                       # 시크릿 관리
├── install-scripts/                # 설치 스크립트
└── README.md
```

## 모니터링 스택

| 컴포넌트 | 차트 | 용도 | 리소스 |
|----------|------|------|--------|
| VictoriaMetrics | vm/victoria-metrics-single | 메트릭 저장 (Prometheus 대체) | ~100MB |
| VMAgent | vm/victoria-metrics-agent | 메트릭 수집 (Prometheus Agent 대체) | ~50MB |
| Node Exporter | prometheus-community/prometheus-node-exporter | 시스템 메트릭 수집 | ~30MB |
| VictoriaLogs | vm/victoria-logs-single | 로그 저장 (Loki 대체) | ~100MB |
| Tempo | grafana/tempo | 분산 트레이싱 | ~100MB |
| Grafana | grafana/grafana | 통합 대시보드 | ~200MB |

## 설치 방법

### 자동 설치 (권장)
```bash
# 환경변수 설정 후 전체 모니터링 스택 설치
EXTERNAL_IP=192.168.1.100 ./infrastructure/helm/install-scripts/install-monitoring.sh
```

### 수동 설치
```bash
# 1. Helm 레포지토리 추가
helm repo add vm https://victoriametrics.github.io/helm-charts/
helm repo add grafana https://grafana.github.io/helm-charts/
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts/
helm repo update

# 2. 네임스페이스 생성
kubectl create namespace monitoring

# 3. 환경변수 설정
export EXTERNAL_IP=192.168.1.100  # 실제 서버 IP로 변경

# 4. values.yaml 파일 뽑아서 포멧 확인하기
## victoria-metrics 파일 뽑아서 포멧 확인하기
helm show values vm/victoria-metrics-single > values.yaml

## victoria-logs 파일 뽑아서 포멧 확인하기
helm show values vm/victoria-logs-single > values.yaml

## Grafana 차트의 기본 values 파일로 저장  
helm show values grafana/grafana > grafana-values.yaml




# 5. 개별 설치 (환경변수 치환)
# Victoria Metrics (메트릭 저장소)
envsubst < infrastructure/helm/charts/victoria-metrics/values-dev.yaml | \
helm install victoria-metrics vm/victoria-metrics-single -f - -n monitoring

envsubst < infrastructure/helm/charts/victoria-metrics/values-dev.yaml | \
helm install vm vm/victoria-metrics-single -f - -n monitoring

# Node Exporter (시스템 메트릭)
envsubst < infrastructure/helm/charts/node-exporter/values-dev.yaml | \
helm install node-exporter prometheus-community/prometheus-node-exporter -f - -n monitoring

# VMAgent (메트릭 수집)
envsubst < infrastructure/helm/charts/vmagent/values-dev.yaml | \
helm install vmagent vm/victoria-metrics-agent -f - -n monitoring

# Victoria Logs (로그 저장소)
envsubst < infrastructure/helm/charts/victoria-logs/values-dev.yaml | \
helm install vl vm/victoria-logs-single -f - -n monitoring

# Tempo (분산 트레이싱)
envsubst < infrastructure/helm/charts/tempo/values-dev.yaml | \
helm install tempo grafana/tempo -f - -n monitoring

# Grafana (대시보드)
envsubst < infrastructure/helm/charts/grafana/values-dev.yaml | \
helm install grafana grafana/grafana -f - -n monitoring
```

## 접근 방법

### externalIPs를 통한 직접 접근 (권장)

1. **서비스 상태 확인:**
```bash
kubectl get svc -n monitoring
```

2. **브라우저에서 접속:**
- **Grafana**: `http://your-server-ip:80` (admin/admin123)
- **VictoriaMetrics**: `http://your-server-ip:8428`
- **VictoriaLogs**: `http://your-server-ip:9428`  
- **Tempo**: `http://your-server-ip:3100`

### 장점
- ✅ **깔끔한 포트 번호** (원래 포트 그대로 사용)
- ✅ **하나의 IP로 통일** (서버 IP만 기억하면 됨)
- ✅ **설정 간단** (추가 컴포넌트 불필요)
- ✅ **싱글 노드에 최적화**

### 포트 포워딩 (개발용)
```bash
# Grafana
kubectl port-forward -n monitoring svc/grafana 3000:80

# VictoriaMetrics  
kubectl port-forward -n monitoring svc/victoria-metrics-single 8428:8428
```

### 주의사항
- 방화벽에서 해당 포트들(80, 8428, 9428, 3100)이 열려있는지 확인
- `values-dev.yaml` 파일의 `${EXTERNAL_IP}`를 실제 서버 IP로 설정

## 시크릿 관리 (SOPS)

민감한 정보는 SOPS로 암호화하여 관리:

```bash
# SOPS 설치
brew install sops

# 시크릿 파일 암호화
sops -e -i secrets/database-secrets.yaml

# 복호화하여 kubectl 적용
sops -d secrets/database-secrets.yaml | kubectl apply -f -
```

## 환경별 설정

- `values-dev.yaml`: 개발 환경용 설정
- `values-prod.yaml`: 프로덕션 환경용 설정 (향후 추가)

## 업그레이드

```bash
# 차트 업그레이드
helm upgrade victoria-metrics vm/victoria-metrics-single \
  -f infrastructure/helm/charts/victoria-metrics/values-dev.yaml \
  -n monitoring
```

## 삭제

```bash
# 전체 삭제
helm uninstall -n monitoring victoria-metrics vlogs tempo grafana
kubectl delete namespace monitoring
```