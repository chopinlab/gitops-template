#!/bin/bash

# 모니터링 스택 설치 스크립트
# VictoriaMetrics + VictoriaLogs + Tempo + Grafana
# externalIPs 방식 사용

set -e

# 환경변수 확인
if [ -z "$EXTERNAL_IP" ]; then
    log_error "EXTERNAL_IP 환경변수가 설정되지 않았습니다."
    log_info "사용법: EXTERNAL_IP=192.168.1.100 ./install-monitoring.sh"
    exit 1
fi

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 로그 함수
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 스크립트 디렉토리 확인
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELM_DIR="$(dirname "$SCRIPT_DIR")"

log_info "모니터링 스택 설치 시작..."

# Helm 레포지토리 추가
log_info "Helm 레포지토리 추가 중..."
helm repo add vm https://victoriametrics.github.io/helm-charts/
helm repo add grafana https://grafana.github.io/helm-charts/
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts/
helm repo add fluent https://fluent.github.io/helm-charts/
helm repo update

# 네임스페이스 생성
log_info "monitoring 네임스페이스 생성 중..."
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

# values 파일에서 환경변수 치환
log_info "환경변수 설정 중... (EXTERNAL_IP: $EXTERNAL_IP)"

# 1. VictoriaMetrics 설치
log_info "VictoriaMetrics 설치 중..."
envsubst < "$HELM_DIR/charts/victoria-metrics/values-dev.yaml" | \
helm upgrade --install victoria-metrics vm/victoria-metrics-single \
    -f - -n monitoring

# 2. Node Exporter 설치 (시스템 메트릭)
log_info "Node Exporter 설치 중..."
envsubst < "$HELM_DIR/charts/node-exporter/values-dev.yaml" | \
helm upgrade --install node-exporter prometheus-community/prometheus-node-exporter \
    -f - -n monitoring

# 3. Fluent Bit 설치 (로그 수집)
log_info "Fluent Bit 설치 중..."
envsubst < "$HELM_DIR/charts/fluent-bit/values-dev.yaml" | \
helm upgrade --install fluent-bit fluent/fluent-bit \
    -f - -n monitoring

# 4. VictoriaLogs 설치  
log_info "VictoriaLogs 설치 중..."
envsubst < "$HELM_DIR/charts/victoria-logs/values-dev.yaml" | \
helm upgrade --install vlogs vm/victoria-logs-single \
    -f - -n monitoring

# 5. Tempo 설치
log_info "Tempo 설치 중..."
envsubst < "$HELM_DIR/charts/tempo/values-dev.yaml" | \
helm upgrade --install tempo grafana/tempo \
    -f - -n monitoring

# 6. Grafana 설치
log_info "Grafana 설치 중..."
envsubst < "$HELM_DIR/charts/grafana/values-dev.yaml" | \
helm upgrade --install grafana grafana/grafana \
    -f - -n monitoring

# 설치 상태 확인
log_info "설치 상태 확인 중..."
kubectl get pods -n monitoring

log_info "모니터링 스택 설치 완료!"
log_info ""
log_info "서비스 상태 확인:"
log_info "  kubectl get svc -n monitoring"
log_info ""
log_info "접근 방법 (externalIPs):"
log_info "  Grafana: http://$EXTERNAL_IP:80"
log_info "  VictoriaMetrics: http://$EXTERNAL_IP:8428"
log_info "  VictoriaLogs: http://$EXTERNAL_IP:9428"
log_info "  Tempo: http://$EXTERNAL_IP:3100"
log_info ""
log_info "Grafana 로그인: admin / admin123"
log_info ""
log_info "주의사항:"
log_info "  - 방화벽에서 해당 포트들이 열려있는지 확인하세요"
log_info "  - $EXTERNAL_IP 주소로 직접 접근 가능합니다"