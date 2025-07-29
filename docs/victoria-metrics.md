# Victoria Metrics 가이드

## 개요

Victoria Metrics는 Prometheus를 대체하는 고성능 시계열 데이터베이스입니다. Prometheus 대비 10배 이상의 압축률과 더 적은 메모리 사용량을 제공하며, 더 긴 데이터 보존 기간을 지원합니다.

## 메트릭의 목적과 용도

### 메트릭 시스템의 핵심 목적: "관찰가능성(Observability)"

메트릭은 **"지금 당장 시스템이 이상한가?"**를 감지하는 조기 경보 시스템입니다.

#### ✅ 메트릭으로 적합한 데이터

**시스템 운영 관점:**
- API 호출 횟수/성공률/응답시간
- 에러 발생 횟수/타입  
- 큐 길이, 처리량
- 캐시 히트율
- DB 연결 수, 쿼리 시간

**비즈니스 운영 관점:**
- 주문 생성 횟수 (시간당)
- 결제 성공/실패 비율
- 사용자 로그인 횟수
- 기능별 사용 빈도

#### ❌ 메트릭으로 부적합한 데이터

**실제 비즈니스 데이터:**
- 개별 주문 내역 (주문번호, 상품명, 가격)
- 사용자 개인정보
- 채팅 메시지 내용
- 날씨 실제 온도값 (25.3도, 습도 67%)

### 메트릭 vs 분석용 데이터 구분 기준

#### 메트릭으로 사용하는 경우:
- **실시간 알림**이 필요한가? (급증/급감 감지)
- **대시보드**에서 실시간 모니터링하는가?
- **임계값** 기반 자동화가 필요한가?
- **간단한 집계**만 필요한가? (합계, 평균, 비율)

#### 일반 DB가 더 적합한 경우:
- **상세 분석**이 필요한가? (사용자별, 시간대별, 조건별)
- **복잡한 조인**이 필요한가?
- **과거 데이터 상세 조회**가 필요한가?
- **비즈니스 인텔리전스** 도구에서 사용하는가?

## 모니터링 스택 구성요소

### 핵심 컴포넌트 역할

| 컴포넌트 | 역할 | 설명 |
|----------|------|------|
| **Victoria Metrics** | 메트릭 저장/조회 | Prometheus 대체, 시계열 데이터베이스 |
| **VMAgent** | 메트릭 수집/전송 | Prometheus Agent 대체, 스크래핑 담당 |
| **Node Exporter** | 시스템 메트릭 생성 | CPU, 메모리, 디스크 등 하드웨어 메트릭 노출 |
| **Grafana** | 시각화 대시보드 | 메트릭 데이터 시각화 및 알림 |

### 데이터 수집 흐름

```
Node Exporter (9100) → VMAgent → Victoria Metrics (8428)
    ↑ 메트릭 노출      ↑ 수집/전송    ↑ 저장/조회

App Pod (/metrics) → VMAgent → Victoria Metrics
    ↑ 메트릭 노출      ↑ 수집/전송    ↑ 저장/조회
```

## Node Exporter vs VMAgent 역할 구분

### Node Exporter (메트릭 생산자)
- **역할**: 시스템 메트릭을 **생성/노출**
- **동작 방식**: `/metrics` 경로로 HTTP REST API 제공 (9100번 포트)
- **데이터 수집**: Linux `/proc`, `/sys` 파일시스템에서 실시간 수집
- **수집 범위**: 
  - CPU: 사용률, 코어별 통계, idle/user/system 시간
  - 메모리: 사용량, 버퍼, 캐시, swap
  - 디스크: I/O 통계, 사용량, inode
  - 네트워크: 인터페이스별 송수신 바이트/패킷
  - 파일시스템: 마운트포인트별 사용량

### VMAgent (메트릭 수집기)
- **역할**: 메트릭을 **수집/전송**
- **수집 대상**:
  - Node Exporter가 노출한 메트릭
  - Kubernetes API 메트릭
  - Pod/Service 메트릭 (어노테이션 기반)
  - 기타 모든 `/metrics` 엔드포인트
- **동작 방식**: 설정된 간격마다 타겟들을 스크래핑해서 Victoria Metrics로 전송

## 애플리케이션 메트릭 설정

### 자동 수집되는 메트릭
- ✅ 시스템 메트릭 (CPU, 메모리, 디스크) - Node Exporter
- ✅ kubelet 메트릭 (Pod/Container 기본 리소스) - Kubernetes 기본
- ✅ Kubernetes API 메트릭 - VMAgent 자동 수집

### 수동 설정이 필요한 메트릭
- ❌ **애플리케이션 메트릭** (비즈니스 로직, 커스텀 메트릭)

### 애플리케이션 메트릭 노출 방법

Pod에 어노테이션 추가:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  template:
    metadata:
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "3000"
        prometheus.io/path: "/metrics"
    spec:
      containers:
      - name: app
        image: my-app:latest
        ports:
        - containerPort: 3000
```

### 애플리케이션 메트릭 구현 예시

```javascript
// Express.js + prom-client 예시
const express = require('express');
const promClient = require('prom-client');

const app = express();

// 커스텀 메트릭 정의
const httpRequests = new promClient.Counter({
  name: 'http_requests_total',
  help: 'Total HTTP requests',
  labelNames: ['method', 'route', 'status']
});

const dbQueries = new promClient.Histogram({
  name: 'database_query_duration_seconds',
  help: 'Database query duration'
});

// 미들웨어로 자동 수집
app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    httpRequests.inc({
      method: req.method,
      route: req.route?.path || req.path,
      status: res.statusCode
    });
  });
  next();
});

// /metrics 엔드포인트
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', promClient.register.contentType);
  res.end(await promClient.register.metrics());
});
```

## 메트릭 vs kubelet 메트릭 구분

### kubelet 메트릭 (자동 수집)
**수집 대상**: Pod/Container의 **리소스 사용량**만
```
container_cpu_usage_seconds_total
container_memory_usage_bytes  
container_memory_limit_bytes
container_fs_usage_bytes
container_network_receive_bytes_total
```

**특징**: 
- 인프라 관점의 메트릭 (얼마나 CPU/메모리 쓰는지)
- 비즈니스 로직과 무관
- Kubernetes가 자동 제공

### 애플리케이션 `/metrics` (수동 구현)
**수집 대상**: **비즈니스/애플리케이션 로직** 메트릭
```
http_requests_total{method="GET", status="200"}     # API 호출 수
database_connections_active                         # DB 연결 수  
user_login_attempts_total                          # 로그인 시도
order_processing_duration_seconds                  # 주문 처리 시간
cache_hit_ratio                                    # 캐시 히트율
```

## 데이터 보존 정책

### Victoria Metrics 보존 설정

```yaml
# values-dev.yaml 설정 예시
server:
  retentionPeriod: "30d"    # 30일 보존
  # 또는
  retentionPeriod: "90d"    # 90일 보존 
  # 또는
  retentionPeriod: "1y"     # 1년 보존
```

### 권장 보존 기간

```bash
# 소규모 환경
retentionPeriod: "30d"     # 1개월

# 중규모 환경  
retentionPeriod: "90d"     # 3개월

# 충분한 스토리지가 있다면
retentionPeriod: "1y"      # 1년
```

## Victoria Metrics vs 범용 TSDB

### Victoria Metrics/Prometheus (모니터링 전용)
- **목적**: "지금 당장 시스템이 문제 있나?" 실시간 감시
- **특화**: 집계/통계 연산, 실시간 모니터링/알림
- **쿼리**: PromQL (집계 특화)
- **보존**: 자동 다운샘플링

### 범용 TSDB (TimescaleDB, InfluxDB)
- **목적**: 비즈니스 데이터 상세 분석
- **특화**: 개별 레코드 조회, 복잡한 관계형 쿼리
- **쿼리**: SQL (범용)
- **보존**: 원본 데이터 장기 보관

## 실제 사용 사례별 저장소 선택

### 로봇 시스템 예시

**실시간 모니터링 (Victoria Metrics)**:
```javascript
robot_position_x_meters{robot_id="robot_01"}     // 현재 X 위치
robot_battery_level{robot_id="robot_01"}         // 배터리 잔량  
robot_error_count{robot_id="robot_01"}           // 에러 발생 횟수
navigation_success_rate{robot_id="robot_01"}     // 내비게이션 성공률
```

**상세 분석 (TimescaleDB)**:
```sql
-- 상세 분석용 (경로 최적화, 성능 분석)
CREATE TABLE robot_poses (
  timestamp TIMESTAMPTZ NOT NULL,
  robot_id TEXT,
  pos_x FLOAT, pos_y FLOAT, pos_z FLOAT,
  roll FLOAT, pitch FLOAT, yaw FLOAT,
  velocity FLOAT, battery_level FLOAT
);
```

**실시간 스트리밍 (WebSocket/Redis)**:
```javascript
// 실시간 제어/시각화용
{
  robot_id: "robot_01",
  timestamp: "2024-01-15T10:30:15.123Z",
  pose: {
    position: {x: 1.23, y: 2.45, z: 0.0},
    orientation: {roll: 0.1, pitch: 0.0, yaw: 1.57}
  }
}
```
