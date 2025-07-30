# Helm 모니터링 스택

VictoriaMetrics 및 VictoriaLogs 기반 경량화 모니터링 솔루션입니다.

## 디렉토리 구조

```
helm/
├── charts/                         # Helm 차트별 values 파일
│   ├── victoria-metrics/           # 메트릭 저장 (Prometheus 대체)
│   ├── victoria-logs/              # 로그 저장 (Loki 대체)  
│   ├── fluent-bit/                 # 로그 수집 (Fluent Bit)
│   ├── node-exporter/              # 시스템 메트릭 수집
│   ├── grafana/                    # 대시보드
│   ├── tempo/                      # 분산 트레이싱 (사용 안함)
│   └── sops/                       # 시크릿 관리 (사용 안함)
├── install-scripts/                # 설치 스크립트
├── Chart.yaml                      # 통합 차트 정의
├── values.yaml                     # 통합 설정
└── README.md
```

## 모니터링 스택 구성

### 실제 사용 중인 컴포넌트

| 컴포넌트 | 차트 | 용도 | 리소스 |
|----------|------|------|--------|
| **VictoriaMetrics** | vm/victoria-metrics-single | 메트릭 저장소 (Prometheus 대체) | ~100MB |
| **Node Exporter** | prometheus-community/prometheus-node-exporter | 시스템 메트릭 수집 | ~30MB |
| **VictoriaLogs** | vm/victoria-logs-single | 로그 저장소 (Loki 대체) | ~200MB |
| **Fluent Bit** | fluent/fluent-bit | 로그 수집 에이전트 (DaemonSet) | ~64MB |
| **Grafana** | grafana/grafana | 통합 대시보드 및 시각화 | ~200MB |

### 포함되었지만 사용하지 않는 컴포넌트

| 컴포넌트 | 용도 | 비고 |
|----------|------|------|
| **Tempo** | 분산 트레이싱 | 현재 프로젝트에서 사용하지 않음 |
| **SOPS** | 시크릿 관리 | 현재 프로젝트에서 사용하지 않음 |

### 주요 특징

- ✅ **경량화**: 기존 Prometheus + Loki 대비 50% 적은 리소스 사용
- ✅ **고성능**: VictoriaMetrics의 뛰어난 압축률과 쿼리 성능
- ✅ **Auto-Discovery**: Kubernetes 환경에서 자동 서비스 발견
- ✅ **장기 보존**: 효율적인 데이터 압축으로 장기 보존 가능 (메트릭: 30일, 로그: 7일)
- ✅ **Grafana 호환**: 기존 Grafana 대시보드와 호환
- ✅ **로그 통합**: VictoriaLogs의 Loki API 호환으로 Grafana에서 로그 조회 가능

## 설치 방법

### 1. 자동 설치 (권장)

```bash
# 환경변수 설정 후 전체 모니터링 스택 설치
cd infrastructure/helm/install-scripts
EXTERNAL_IP=192.168.1.100 ./install-monitoring.sh
```

**설치되는 컴포넌트:**
- VictoriaMetrics (메트릭 저장소)
- Node Exporter (시스템 메트릭)
- Fluent Bit (로그 수집)
- VictoriaLogs (로그 저장소)
- Grafana (시각화)

### 2. 수동 설치

```bash
# Helm 레포지토리 추가
helm repo add vm https://victoriametrics.github.io/helm-charts/
helm repo add grafana https://grafana.github.io/helm-charts/
helm repo add fluent https://fluent.github.io/helm-charts/
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts/
helm repo update

# 네임스페이스 생성
kubectl create namespace monitoring

# 환경변수 설정 (실제 서버 IP로 변경)
export EXTERNAL_IP=192.168.1.100

# 개별 설치 (환경변수 치환)
# VictoriaMetrics (메트릭 저장소)
envsubst < charts/victoria-metrics/values-dev.yaml | \
helm install victoria-metrics vm/victoria-metrics-single -f - -n monitoring

# Node Exporter (시스템 메트릭)
envsubst < charts/node-exporter/values-dev.yaml | \
helm install node-exporter prometheus-community/prometheus-node-exporter -f - -n monitoring

# Fluent Bit (로그 수집)
envsubst < charts/fluent-bit/values-dev.yaml | \
helm install fluent-bit fluent/fluent-bit -f - -n monitoring

# VictoriaLogs (로그 저장소)
envsubst < charts/victoria-logs/values-dev.yaml | \
helm install vl vm/victoria-logs-single -f - -n monitoring

# Grafana (대시보드)
envsubst < charts/grafana/values-dev.yaml | \
helm install grafana grafana/grafana -f - -n monitoring
```

### 3. 설치 확인

```bash
# 파드 상태 확인
kubectl get pods -n monitoring

# 서비스 상태 확인  
kubectl get svc -n monitoring

# Helm 릴리스 확인
helm list -n monitoring

# 모든 리소스 확인
kubectl get all -n monitoring
```

## 접근 방법

### externalIPs를 통한 직접 접근 (권장)

1. **서비스 상태 확인:**
```bash
kubectl get svc -n monitoring
```

2. **브라우저에서 접속:**
- **Grafana**: `http://192.168.1.100:80` (admin/admin123)
- **VictoriaMetrics**: `http://192.168.1.100:8428`
- **VictoriaLogs**: `http://192.168.1.100:9428`  

### Grafana 데이터소스 설정

Grafana 접속 후 다음 데이터소스를 추가하세요:

1. **VictoriaMetrics (메트릭)**
   - Type: Prometheus
   - URL: `http://victoria-metrics-server:8428`

2. **VictoriaLogs (로그)**
   - Type: Loki
   - URL: `http://victoria-logs-server:9428`

### 포트 포워딩 (개발용)

```bash
# Grafana
kubectl port-forward -n monitoring svc/grafana 3000:80

# VictoriaMetrics  
kubectl port-forward -n monitoring svc/victoria-metrics-server 8428:8428

# VictoriaLogs
kubectl port-forward -n monitoring svc/victoria-logs-server 9428:9428
```

### 장점

- ✅ **깔끔한 포트 번호** (원래 포트 그대로 사용)
- ✅ **하나의 IP로 통일** (서버 IP만 기억하면 됨)
- ✅ **설정 간단** (추가 컴포넌트 불필요)
- ✅ **싱글 노드에 최적화**

## 모니터링 데이터 흐름

### 메트릭 수집 흐름
```
Kubernetes Cluster → Node Exporter → VictoriaMetrics → Grafana
                 ↗ (시스템 메트릭)  ↗ (저장)      ↗ (시각화)
Application Pods → (자동 발견)
```

### 로그 수집 흐름
```
Container Logs → Fluent Bit → VictoriaLogs → Grafana
              ↗ (DaemonSet) ↗ (저장)     ↗ (시각화)
System Logs   ↗
```

## 환경별 설정

- **`values-dev.yaml`**: 개발 환경용 설정
  - 낮은 리소스 제한
  - 짧은 보존 기간 (7일)
  - externalIPs 사용

- **`values.yaml`**: 프로덕션 환경용 설정
  - 높은 리소스 제한
  - 긴 보존 기간 (30일)
  - LoadBalancer/Ingress 사용

## 문제 해결

### 로그 확인

```bash
# Grafana 로그
kubectl logs -n monitoring deployment/grafana

# VictoriaMetrics 로그
kubectl logs -n monitoring statefulset/victoria-metrics-server

# VictoriaLogs 로그
kubectl logs -n monitoring statefulset/victoria-logs-server

# Fluent Bit 로그 (특정 노드)
kubectl logs -n monitoring daemonset/fluent-bit

# Node Exporter 로그
kubectl logs -n monitoring daemonset/node-exporter
```

### 일반적인 문제

1. **파드가 시작되지 않음**
```bash
kubectl describe pod -n monitoring <pod-name>
kubectl get events -n monitoring --sort-by='.lastTimestamp'
```

2. **Grafana에서 데이터가 보이지 않음**
- 데이터소스 URL 확인 (`http://service-name:port`)
- VictoriaMetrics/VictoriaLogs 상태 확인

3. **로그가 수집되지 않음**
- Fluent Bit 파드 상태 확인
- VictoriaLogs에서 `_msg` 필드 오류 확인

### 업그레이드

```bash
# 개별 차트 업그레이드
helm upgrade victoria-metrics vm/victoria-metrics-single \
  -f charts/victoria-metrics/values-dev.yaml \
  -n monitoring

# 전체 스택 재설치
EXTERNAL_IP=192.168.1.100 ./install-scripts/install-monitoring.sh
```

### 완전 삭제

```bash
# 모든 Helm 릴리스 삭제
helm uninstall -n monitoring victoria-metrics node-exporter fluent-bit vl grafana

# 네임스페이스 삭제 (PVC도 함께 삭제됨)
kubectl delete namespace monitoring
```

## 주의사항

- 방화벽에서 해당 포트들(80, 8428, 9428)이 열려있는지 확인
- `values-dev.yaml` 파일의 `${EXTERNAL_IP}`를 실제 서버 IP로 설정
- VictoriaLogs의 Grafana Logs Drilldown 기능은 부분적으로만 지원됨
- 시스템 리소스가 부족한 경우 리소스 제한을 조정하세요