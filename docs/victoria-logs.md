# VictoriaLogs 완전 가이드

## 개요

VictoriaLogs는 VictoriaMetrics에서 개발한 고성능 로그 데이터베이스입니다. 2024년 11월 GA(General Availability) 출시로 프로덕션 환경에서 사용할 준비가 완료되었습니다.

## VictoriaLogs 특징

### 성능 우위
- **Elasticsearch 대비**: 30배 적은 RAM, 15배 적은 디스크 사용
- **Grafana Loki 대비**: 1000배 빠른 풀텍스트 검색 성능
- **검색 속도**: 일반적인 쿼리에서 극도로 빠른 응답 시간

### 주요 기능
- **LogsQL**: 강력한 로그 쿼리 언어
- **다양한 로그 수집기 지원**: OpenTelemetry, Vector, Fluentd, Logstash 등
- **JSON/Syslog 지원**: 다양한 로그 형식 처리
- **스키마리스**: 동적 필드 추가 가능

## 지원하는 로그 수집기

### 권장 수집기들

| 수집기 | 언어 | 특징 | 추천 용도 |
|--------|------|------|-----------|
| **Vector** ⭐ | Rust | 고성능, 범용 데이터 파이프라인 | 복잡한 변환, 단일 도구 |
| **Fluent Bit** | C | 경량, 메모리 효율적 | 리소스 제약 환경 |
| **Fluentd** | Ruby | 플러그인 생태계 풍부 | 복잡한 로그 처리 |
| **Promtail** | Go | Loki용이지만 VL 지원 | 기존 Loki 사용자 |
| **OpenTelemetry Collector** | Go | 표준 준수 | 멀티 벤더 환경 |

### 각 수집기별 성능 비교

```
처리량 (로그/초):
Vector      > 100,000 LPS
Fluent Bit  > 50,000 LPS  
Fluentd     > 20,000 LPS
Promtail    > 30,000 LPS
```

## 설치 및 구성

### Docker로 VictoriaLogs 실행

```bash
# 단독 실행
docker run -it --rm \
  -v victorialogs-data:/victoria-logs-data \
  -p 9428:9428 \
  victoriametrics/victoria-logs:latest \
  -storageDataPath=/victoria-logs-data \
  -httpListenAddr=:9428
```
```

### 주요 설정 옵션

```bash
# 데이터 저장 경로
-storageDataPath=/victoria-logs-data

# HTTP 리스닝 주소
-httpListenAddr=:9428

# 데이터 보존 기간
-retentionPeriod=30d

# 최대 디스크 사용량
-storage.maxDiskUsageBytes=10GB

# 로그 레벨
-loggerLevel=INFO
```

## 로그 수집기별 설정

### 1. Vector 설정

```toml
# vector.toml
[sources.app_logs]
type = "file"
include = ["/var/log/app/*.log"]
encoding = "json"

[sources.docker_logs]
type = "docker_logs"

[transforms.parse_logs]
type = "remap"
inputs = ["app_logs", "docker_logs"]
source = '''
  .timestamp = parse_timestamp!(.timestamp, "%Y-%m-%d %H:%M:%S")
  .level = upcase(.level)
'''

[sinks.victorialogs]
type = "http"
inputs = ["parse_logs"]
uri = "http://victorialogs:9428/insert/jsonline"
method = "post"
encoding.codec = "json"

[sinks.victorialogs.request.headers]
"Content-Type" = "application/stream+json"
```

### 2. Fluent Bit 설정

```ini
# fluent-bit.conf
[SERVICE]
    Flush        1
    Log_Level    info
    Daemon       off

[INPUT]
    Name              tail
    Path              /var/log/app/*.log
    Path_Key          filename
    Parser            json
    Tag               app.*
    Refresh_Interval  5

[INPUT]
    Name              tail
    Path              /var/lib/docker/containers/*/*.log
    Path_Key          filename
    Parser            docker
    Tag               docker.*
    Refresh_Interval  5

[FILTER]
    Name modify
    Match *
    Add service_name ${HOSTNAME}
    Add environment production

[OUTPUT]
    Name        http
    Match       *
    Host        victorialogs
    Port        9428
    URI         /insert/jsonline
    Format      json_lines
    Json_date_key    timestamp
    Json_date_format iso8601
    Header      Content-Type application/stream+json
```

### 3. Fluentd 설정

```ruby
# fluentd.conf
<source>
  @type tail
  path /var/log/app/*.log
  pos_file /var/log/fluentd/app.log.pos
  tag app.*
  format json
  time_key timestamp
  time_format %Y-%m-%d %H:%M:%S
</source>

<source>
  @type docker_logs
  path /var/lib/docker/containers/*/*.log
  tag docker.*
</source>

<filter **>
  @type record_transformer
  <record>
    hostname ${hostname}
    service_name app
  </record>
</filter>

<match **>
  @type http
  endpoint http://victorialogs:9428/insert/jsonline
  headers {"Content-Type":"application/stream+json"}
  format json
  <buffer>
    flush_interval 5s
  </buffer>
</match>
```

### 4. OpenTelemetry Collector 설정

```yaml
# otel-collector.yaml
receivers:
  filelog:
    include: ["/var/log/app/*.log"]
    operators:
      - type: json_parser
        timestamp:
          parse_from: attributes.timestamp
          layout: '%Y-%m-%d %H:%M:%S'

processors:
  batch:
    timeout: 5s
    send_batch_size: 1000
  
  resource:
    attributes:
      - key: service.name
        value: "my-app"
        action: upsert

exporters:
  logging:
    loglevel: debug
  
  victorialogs:
    endpoint: http://victorialogs:9428/insert/jsonline
    headers:
      Content-Type: "application/stream+json"

service:
  pipelines:
    logs:
      receivers: [filelog]
      processors: [batch, resource]
      exporters: [victorialogs]
```

## LogsQL 쿼리 언어

### 기본 문법

```sql
-- 기본 검색
level:ERROR

-- 시간 범위 검색
level:ERROR AND _time:[now-1h, now]

-- 필드 필터링
service_name:app AND level:ERROR

-- 와일드카드 검색
message:*database*

-- 정규식 검색
message:~"error.*connection"

-- 집계
level:ERROR | stats count() by service_name

-- 상위 N개
level:ERROR | top 10 by _time
```

### 고급 쿼리 예시

```sql
-- 에러 로그 통계
level:ERROR 
| stats count() as error_count by service_name, level
| sort error_count desc

-- 시간대별 로그 분포
_time:[now-24h, now] 
| stats count() as log_count by bin(_time, 1h)
| sort _time

-- 특정 사용자 활동 추적
user_id:12345 AND action:* 
| fields _time, action, ip_address, user_agent
| sort _time desc

-- 성능 이슈 탐지
response_time:>1000 
| stats avg(response_time) as avg_response, count() as slow_requests by endpoint
| where slow_requests > 10

-- 로그 레벨별 트렌드
_time:[now-7d, now] 
| stats count() as log_count by level, bin(_time, 1d)
| sort _time, level
```

## Grafana 통합

### 데이터소스 설정

```yaml
# grafana/provisioning/datasources/victorialogs.yml
apiVersion: 1

datasources:
  - name: VictoriaLogs
    type: victorialogs-datasource
    access: proxy
    url: http://victorialogs:9428
    jsonData:
      maxLines: 1000
      timeout: 60s
```

### 대시보드 패널 예시

```json
{
  "title": "Error Logs",
  "type": "logs",
  "targets": [
    {
      "expr": "level:ERROR | sort _time desc",
      "refId": "A"
    }
  ],
  "options": {
    "showTime": true,
    "showLabels": true,
    "sortOrder": "Descending"
  }
}
```

## 성능 최적화

### 인덱싱 최적화

```bash
# 자주 검색하는 필드 인덱싱
-search.cacheTimestampOffset=1h
-search.maxConcurrentRequests=8
-search.maxMemoryPerQuery=100MB
```

### 메모리 설정

```bash
# 메모리 제한
-memory.allowedPercent=80
-memory.allowedBytes=4GB

# 캐시 설정
-search.cacheTimestampOffset=5m
-search.maxSeries=1000000
```

### 디스크 최적화

```bash
# 압축 설정
-compression.level=1

# 데이터 플러시 간격
-flushTimeout=5s

# 백그라운드 머지
-smallMergeConcurrency=2
-bigMergeConcurrency=1
```

## 모니터링 및 알람

### VictoriaLogs 메트릭

```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'victorialogs'
    static_configs:
      - targets: ['victorialogs:9428']
    metrics_path: '/metrics'
```

### 주요 메트릭들

```promql
# 로그 수집 속도
rate(vl_log_entries_ingested_total[5m])

# 쿼리 성능
histogram_quantile(0.95, rate(vl_http_request_duration_seconds_bucket[5m]))

# 디스크 사용량
vl_data_size_bytes

# 메모리 사용량
process_resident_memory_bytes{job="victorialogs"}
```

### Grafana 알람 설정

```yaml
# 높은 에러율 알람
- alert: HighErrorRate
  expr: |
    (
      rate(victorialogs_log_entries{level="ERROR"}[5m]) /
      rate(victorialogs_log_entries[5m])
    ) > 0.1
  for: 2m
  labels:
    severity: warning
  annotations:
    summary: "High error rate detected"
    description: "Error rate is {{ $value | humanizePercentage }}"
```

## 백업 및 복구

### 데이터 백업

```bash
# vmbackup을 사용한 백업
docker run --rm \
  -v victorialogs-data:/victoria-logs-data:ro \
  -v /backup:/backup \
  victoriametrics/vmbackup:latest \
  -storageDataPath=/victoria-logs-data \
  -dst=fs:///backup/victorialogs-$(date +%Y%m%d)
```

### 복구

```bash
# vmrestore를 사용한 복구
docker run --rm \
  -v victorialogs-data:/victoria-logs-data \
  -v /backup:/backup \
  victoriametrics/vmrestore:latest \
  -src=fs:///backup/victorialogs-20241201 \
  -storageDataPath=/victoria-logs-data
```

## 트러블슈팅

### 일반적인 문제들

1. **로그 수집 안됨**
   ```bash
   # 수집기 상태 확인
   curl http://victorialogs:9428/metrics | grep ingested
   
   # 로그 레벨 확인
   tail -f /var/log/victorialogs/victorialogs.log
   ```

2. **쿼리 성능 저하**
   ```bash
   # 인덱스 상태 확인
   curl http://victorialogs:9428/debug/vars
   
   # 메모리 사용량 확인
   curl http://victorialogs:9428/metrics | grep memory
   ```

3. **디스크 공간 부족**
   ```bash
   # 데이터 크기 확인
   du -sh /victoria-logs-data/
   
   # 보존 기간 조정
   -retentionPeriod=7d
   ```

### 성능 진단

```bash
# 로그 수집 통계
curl -s http://victorialogs:9428/metrics | grep vl_log_entries

# 쿼리 통계  
curl -s http://victorialogs:9428/metrics | grep vl_http_requests

# 메모리 사용량
curl -s http://victorialogs:9428/metrics | grep process_resident_memory_bytes
```

## 마이그레이션 가이드

### Elasticsearch에서 VictoriaLogs로

1. **데이터 내보내기**
   ```bash
   # elasticdump 사용
   elasticdump \
     --input=http://elasticsearch:9200/logs-* \
     --output=/tmp/logs.json \
     --type=data
   ```

2. **VictoriaLogs로 가져오기**
   ```bash
   # 변환 후 삽입
   cat /tmp/logs.json | \
   jq -c '._source' | \
   curl -X POST http://victorialogs:9428/insert/jsonline \
     -H "Content-Type: application/stream+json" \
     --data-binary @-
   ```

### Grafana Loki에서 VictoriaLogs로

1. **LogQL을 LogsQL로 변환**
   ```bash
   # Loki LogQL
   {service="app"} |= "error"
   
   # VictoriaLogs LogsQL
   service:app AND message:*error*
   ```

2. **Promtail 설정 수정**
   ```yaml
   clients:
     - url: http://victorialogs:9428/insert/loki/api/v1/push
   ```

## 프로덕션 배포 고려사항

### 고가용성 구성

```yaml
# 클러스터 구성 (2025년 예정)
version: '3.8'
services:
  victorialogs-1:
    image: victoriametrics/victoria-logs:cluster
    environment:
      - VL_CLUSTER_NODE_ID=1
  
  victorialogs-2:
    image: victoriametrics/victoria-logs:cluster
    environment:
      - VL_CLUSTER_NODE_ID=2
```

### 보안 설정

```bash
# 인증 활성화
-httpAuth.username=admin
-httpAuth.password=secure_password

# TLS 설정
-tls
-tlsCertFile=/path/to/cert.pem
-tlsKeyFile=/path/to/key.pem
```

### 용량 계획

```bash
# 일일 로그량 예측
# 1GB/day × 30일 보존 = 30GB 필요
# 압축률 고려: 30GB × 0.1 = 3GB 실제 사용량

# 리소스 권장사항
# RAM: 로그량의 1-2%
# CPU: 2-4 코어
# 디스크: SSD 권장, RAID 1 이상
```

이 가이드를 통해 VictoriaLogs를 효과적으로 활용할 수 있습니다.