# Docker 기반 모니터링 스택 설치 가이드

## 개요

이 문서는 Docker를 사용하여 VictoriaMetrics 생태계 기반의 모니터링 스택을 설치하고 구성하는 방법을 설명합니다.

## 모니터링 스택 구성 요소

### 메트릭 수집 및 저장
- **VictoriaMetrics**: 메트릭 데이터베이스 (Prometheus 호환)
- **vmagent**: 메트릭 수집 에이전트
- **Node Exporter**: 시스템 메트릭 수집

### 로그 수집 및 저장
- **VictoriaLogs**: 로그 데이터베이스 (2024년 GA 출시)
- **Fluent Bit**: 로그 수집기 (경량, C 기반)

### 시각화 및 알람
- **Grafana**: 대시보드 및 시각화
- **Grafana Alerting**: 알람 시스템

## Docker Compose 설정

### 기본 스택 구성

```yaml
version: '3.8'

services:
  # 메트릭 데이터베이스
  victoriametrics:
    image: victoriametrics/victoria-metrics:latest
    container_name: victoriametrics
    ports:
      - "8428:8428"
    volumes:
      - victoriametrics-data:/victoria-metrics-data
    command:
      - '--storageDataPath=/victoria-metrics-data'
      - '--httpListenAddr=:8428'
      - '--retentionPeriod=1y'
    restart: unless-stopped

  # 메트릭 수집 에이전트
  vmagent:
    image: victoriametrics/vmagent:latest
    container_name: vmagent
    ports:
      - "8429:8429"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - /var/run/docker.sock:/var/run/docker.sock:ro
    command:
      - '--promscrape.config=/etc/prometheus/prometheus.yml'
      - '--remoteWrite.url=http://victoriametrics:8428/api/v1/write'
    depends_on:
      - victoriametrics
    restart: unless-stopped

  # 시스템 메트릭 수집
  node-exporter:
    image: quay.io/prometheus/node-exporter:latest
    container_name: node-exporter
    pid: host
    network_mode: host
    volumes:
      - '/:/host:ro,rslave'
    command:
      - '--path.rootfs=/host'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
    restart: unless-stopped

  # 로그 데이터베이스
  victorialogs:
    image: victoriametrics/victoria-logs:latest
    container_name: victorialogs
    ports:
      - "9428:9428"
    volumes:
      - victorialogs-data:/victoria-logs-data
    command:
      - '--storageDataPath=/victoria-logs-data'
      - '--httpListenAddr=:9428'
    restart: unless-stopped

  # 로그 수집기
  fluent-bit:
    image: fluent/fluent-bit:latest
    container_name: fluent-bit
    volumes:
      - ./fluent-bit.conf:/fluent-bit/etc/fluent-bit.conf
      - /var/log:/var/log:ro
      - /var/lib/docker/containers:/var/lib/docker/containers:ro
    depends_on:
      - victorialogs
    restart: unless-stopped

  # 시각화 도구
  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    ports:
      - "3000:3000"
    volumes:
      - grafana-data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_INSTALL_PLUGINS=victoriametrics-metrics-datasource
    depends_on:
      - victoriametrics
      - victorialogs
    restart: unless-stopped

volumes:
  victoriametrics-data:
  victorialogs-data:
  grafana-data:
```

### vmagent 설정 (prometheus.yml)

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  # Node Exporter 메트릭 수집
  - job_name: 'node-exporter'
    static_configs:
      - targets: ['localhost:9100']
    scrape_interval: 15s
    metrics_path: '/metrics'

  # Docker 컨테이너 메트릭 수집
  - job_name: 'docker-containers'
    docker_sd_configs:
      - host: unix:///var/run/docker.sock
    relabel_configs:
      - source_labels: [__meta_docker_container_name]
        target_label: container_name

  # 애플리케이션 메트릭 수집
  - job_name: 'app-backend'
    static_configs:
      - targets: ['app-backend:6010']
    metrics_path: '/metrics'
    scrape_interval: 15s
```

### Fluent Bit 설정 (fluent-bit.conf)

```ini
[SERVICE]
    Flush        1
    Log_Level    info
    Daemon       off
    Parsers_File parsers.conf

[INPUT]
    Name              tail
    Path              /var/log/*.log
    Path_Key          filename
    Parser            json
    Tag               host.*
    Refresh_Interval  5

[INPUT]
    Name              tail
    Path              /var/lib/docker/containers/*/*.log
    Path_Key          filename
    Parser            docker
    Tag               docker.*
    Refresh_Interval  5

[OUTPUT]
    Name        http
    Match       *
    Host        victorialogs
    Port        9428
    URI         /insert/jsonline
    Format      json_lines
    Json_date_key    timestamp
    Json_date_format iso8601
```

## 설치 및 실행

### 1. 디렉토리 구조 생성

```bash
mkdir -p monitoring-stack/{config,grafana/provisioning/datasources}
cd monitoring-stack
```

### 2. 설정 파일 생성

위의 설정 파일들을 각각 생성:
- `docker-compose.yml`
- `config/prometheus.yml`
- `config/fluent-bit.conf`

### 3. Grafana 데이터소스 설정

```yaml
# grafana/provisioning/datasources/datasources.yml
apiVersion: 1

datasources:
  - name: VictoriaMetrics
    type: prometheus
    access: proxy
    url: http://victoriametrics:8428
    isDefault: true

  - name: VictoriaLogs
    type: victorialogs-datasource
    access: proxy
    url: http://victorialogs:9428
```

### 4. 스택 실행

```bash
# 전체 스택 시작
docker-compose up -d

# 로그 확인
docker-compose logs -f

# 상태 확인
docker-compose ps
```

## 접속 정보

- **Grafana**: http://localhost:3000 (admin/admin)
- **VictoriaMetrics**: http://localhost:8428
- **VictoriaLogs**: http://localhost:9428
- **vmagent**: http://localhost:8429

## 성능 최적화

### 리소스 제한 설정

```yaml
# docker-compose.yml에 추가
services:
  vmagent:
    deploy:
      resources:
        limits:
          memory: 512M
          cpus: '0.5'
        reservations:
          memory: 256M
          cpus: '0.25'
  
  fluent-bit:
    deploy:
      resources:
        limits:
          memory: 256M
          cpus: '0.25'
```

### 네트워크 최적화

```yaml
# 전용 네트워크 생성
networks:
  monitoring:
    driver: bridge

services:
  victoriametrics:
    networks:
      - monitoring
  # 다른 서비스들도 동일하게 설정
```

## 대안: Vector 단일 도구 사용

Vector를 사용한 단일 도구 접근 방식:

```yaml
services:
  vector:
    image: timberio/vector:latest
    container_name: vector
    ports:
      - "8686:8686"
    volumes:
      - ./vector.toml:/etc/vector/vector.toml
      - /var/log:/var/log:ro
      - /var/lib/docker/containers:/var/lib/docker/containers:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
    command: ["--config", "/etc/vector/vector.toml"]
    restart: unless-stopped
```

### Vector 설정 예시 (vector.toml)

```toml
[sources.logs]
type = "file"
include = ["/var/log/*.log"]

[sources.docker_logs]
type = "docker_logs"

[sources.host_metrics]
type = "host_metrics"

[sinks.victoriametrics]
type = "prometheus_remote_write"
inputs = ["host_metrics"]
endpoint = "http://victoriametrics:8428/api/v1/write"

[sinks.victorialogs]
type = "http"
inputs = ["logs", "docker_logs"]
uri = "http://victorialogs:9428/insert/jsonline"
```

## 트러블슈팅

### 일반적인 문제들

1. **Docker 소켓 권한 문제**
   ```bash
   sudo chmod 666 /var/run/docker.sock
   ```

2. **메트릭 수집 안됨**
   - vmagent 로그 확인: `docker logs vmagent`
   - 타겟 상태 확인: http://localhost:8429/targets

3. **로그 수집 안됨**
   - Fluent Bit 로그 확인: `docker logs fluent-bit`
   - VictoriaLogs 상태 확인: http://localhost:9428

### 모니터링 명령어

```bash
# 리소스 사용량 확인
docker stats

# 컨테이너 상태 확인
docker-compose ps

# 로그 실시간 확인
docker-compose logs -f [service-name]
```

## 보안 고려사항

1. **기본 패스워드 변경**
2. **네트워크 보안 설정**
3. **볼륨 권한 관리**
4. **방화벽 규칙 설정**

이 가이드를 통해 Docker 기반의 완전한 모니터링 스택을 구축할 수 있습니다.