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

## 로봇 데이터 수집 아키텍처 패턴

### 아키텍처 선택 기준

**핵심 원칙**: 복잡성을 최소화하고 실제 요구사항에 맞는 솔루션 선택

| 상황 | 권장 아키텍처 | 이유 |
|------|---------------|------|
| **단일 서버 + 단일 로봇** | 직접 연결 (EventEmitter) | 불필요한 복잡성 제거, 최고 성능 |
| **MSA 환경** | 메시징 시스템 필요 | 서비스간 분리, 독립 배포 |
| **지역간 분산** | 클라우드 메시징 | 네트워크 경계 극복 |

### 1. 최적 아키텍처 (단일 서버 환경) - 권장

```
로봇 (Modbus) ←──→ 서버 ──→ WebSocket ──→ 여러 브라우저
                   ↓                      ├── 관리자 PC
                 DB 저장                  ├── 모니터링 화면
                 메트릭 수집               └── 모바일 앱
```

**구현 예시**:
```javascript
const express = require('express');
const WebSocket = require('ws');
const ModbusRTU = require('modbus-serial');

const app = express();
const wss = new WebSocket.Server({ port: 8080 });
const modbus = new ModbusRTU();

// 로봇과 직접 연결
await modbus.connectTCP('192.168.1.100', {port: 502});

// 100ms마다 Modbus 폴링 (로봇이 Push 불가, 폴링 방식 필수)
setInterval(async () => {
  const data = await modbus.readHoldingRegisters(0, 6);
  const robotData = parseRobotData(data);
  
  // 1. DB 저장 (한 곳에서만)
  await saveToDatabase(robotData);
  
  // 2. 메트릭 업데이트 (한 곳에서만)  
  updateVictoriaMetrics(robotData);
  
  // 3. 모든 WebSocket 클라이언트에게 브로드캐스트
  wss.clients.forEach(client => {
    if (client.readyState === WebSocket.OPEN) {
      client.send(JSON.stringify(robotData));
    }
  });
}, 100);
```

**장점**:
- ✅ **최고 성능**: 지연시간 최소
- ✅ **설정 간단**: 추가 인프라 불필요
- ✅ **장애점 최소**: 단일 실패 지점 없음
- ✅ **개발 빠름**: 복잡한 메시징 시스템 불필요

### 2. MSA 환경 (마이크로서비스 분리 시)

```
로봇 (Modbus) → Gateway → NATS/MQTT → ┌─ 저장 서비스 (Go)
                                     ├─ 모니터링 서비스 (Python) 
                                     └─ WebSocket 서비스 (Node.js)
```

**언제 필요한가**:
- ✅ **팀별 개발**: 각 팀이 다른 언어/기술스택 사용
- ✅ **독립 배포**: 서비스별 배포 주기가 다름
- ✅ **확장성**: 특정 서비스만 스케일링 필요
- ✅ **장애 격리**: 한 서비스 장애가 다른 서비스에 영향 주지 않음

**메시징 시스템 선택**:

| 프로토콜 | 적합한 상황 | 특징 |
|----------|-------------|------|
| **NATS** | 내부 네트워크, 고성능 | 가장 빠름, 경량 |
| **MQTT** | IoT 표준 준수, 원격 센서 | 저전력, QoS 지원 |
| **Redis Pub/Sub** | 이미 Redis 사용 중 | 추가 설치 불필요 |

### 3. 지역간 분산 (다중 공장)

```
서울 공장 ──┐
           ├──→ 클라우드 MQTT 브로커 ──→ 본사 시스템
부산 공장 ──┘    (AWS IoT Core)         (통합 대시보드)
```

**클라우드/퍼블릭 망 사용**:
- **AWS IoT Core**: 글로벌 MQTT 브로커
- **Azure IoT Hub**: 지역간 메시징  
- **Google Cloud IoT**: 전세계 분산

## 산업용 로봇 (Modbus) 연동 패턴

### Modbus 통신 특성
- **폴링 방식 필수**: 로봇이 Push 불가, 서버/게이트웨이에서 주기적 요청
- **동기식 통신**: Master-Slave 구조 (요청-응답 패턴)
- **산업 표준**: 안정성 중시, 실시간 제어와 데이터 수집 분리

### 게이트웨이 필요성

**산업용 로봇팔 (현대로보틱스 등)의 현실**:
- ❌ **로봇 내부 수정 불가**: 펌웨어 접근 제한, 보증 무효화
- ❌ **안전 규격**: 외부 코드 추가 시 인증 문제
- ❌ **실시간 우선순위**: 제어 로직이 최우선, 리소스 제한

**따라서 99% 중간 게이트웨이 필수**:

#### 단일 서버 환경 (권장)
```
로봇팔 ←─ Modbus TCP ─→ 서버 (게이트웨이 불필요)
                        ↓
                      모든 처리
                  (DB, WebSocket, 메트릭)
```

#### MSA 환경
```
로봇팔 ←─ Modbus ─→ Gateway PC ─→ NATS/MQTT ─→ 서비스들
                     ↑                       ├─ 저장 서비스
                 프로토콜 변환                ├─ 모니터링 서비스
                                           └─ WebSocket 서비스
```

### 실제 구현 고려사항

**네트워크 연결**:
- **직접 연결**: 로봇이 이더넷 지원 시 (일반적)
- **게이트웨이 필요**: Modbus RTU(시리얼) 또는 네트워크 격리 시

**데이터 수집 빈도**:
- **일반적**: 100ms~1초 주기
- **고속**: 50ms 가능 (로봇 부하 고려)
- **변화 감지**: 효율성을 위해 임계값 기반 필터링

**메시징 시스템 선택 기준**:

| 환경 | 솔루션 | 이유 |
|------|---------|------|
| **단일 서버 + 로봇 1대** | 직접 연결 | 최고 성능, 최소 복잡성 |
| **MSA + 내부 네트워크** | NATS | 빠름, 경량 |
| **다중 지역 + 클라우드** | MQTT | IoT 표준, 네트워크 불안정 대응 |

## 핵심 정리

### 메트릭의 본질
**"시스템/서비스가 지금 이 순간 정상적으로 작동하는가?"**를 감시하는 조기 경보 시스템

### 아키텍처 선택의 핵심 원칙
**"복잡성을 최소화하고 실제 요구사항에 맞는 솔루션 선택"**

| 상황 | 권장 솔루션 | 핵심 이유 |
|------|-------------|-----------|
| **단일 서버 + 로봇 1대** | 직접 Modbus 연결 | 불필요한 메시징 시스템 제거 |
| **MSA 환경** | NATS/MQTT 필요 | 서비스간 분리, 독립 배포 |
| **지역간 분산** | 클라우드 메시징 | 네트워크 경계 극복 |

### 사용 목적별 데이터 저장소

| 저장소 | 목적 | 사용 시점 |
|--------|------|-----------|
| **Victoria Metrics** | 운영 모니터링/알림 | 지금 문제 있나? |
| **TimescaleDB** | 상세 분석/통계 | 왜 이런 패턴인가? |
| **WebSocket** | 실시간 시각화 | 여러 브라우저에 즉시 표시 |

### 실무 적용 가이드

**DB와 메트릭 수집은 1곳에서만**:
- ✅ DB 저장: 서버 1대에서만 (중복 저장 방지)
- ✅ 메트릭 수집: 서버 1대에서만 (중복 수집 방지)
- ✅ WebSocket: 여러 브라우저/클라이언트에 브로드캐스트

**Modbus 통신**:
- ✅ 폴링 방식 필수 (로봇이 Push 불가)
- ✅ 산업용 로봇은 99% 게이트웨이 필요 (펌웨어 수정 불가)
- ✅ 단일 서버면 직접 연결이 최적

**메시징 시스템**:
- ✅ MQTT: IoT 표준, 지역간 분산 시
- ✅ NATS: 내부 네트워크, 고성능 MSA
- ✅ EventEmitter: 단일 프로세스, 최고 성능

메트릭은 "운영자가 새벽에도 폰으로 알림 받는" 목적의 시스템이며, 아키텍처는 **실제 요구사항에 맞게 단순하게** 구성하는 것이 핵심입니다.

## 데이터 중요도별 처리 전략

### 장애 상황 고려의 필요성

**직접 연결의 치명적 약점**:
```
로봇 → (네트워크 단절/서버 장애) → ❌ 데이터 영영 손실
```

산업 현장에서 데이터 손실은 **사고 원인 분석 불가**, **품질 추적 불가**, **법적 문제** 등 심각한 결과를 초래할 수 있습니다.

### 로봇 데이터 중요도 분류

#### 🔴 Critical Data (절대 손실 금지)
**MQTT QoS 2 사용**
- **안전 관련**: 비상정지, 충돌 감지, 에러 코드
- **품질/추적**: 제품 시리얼, 공정 시작/종료 시간, 품질 검사 결과
- **법적 요구**: 작업자 ID, 배치 번호, 캘리브레이션 날짜

#### 🟡 Important Data (일부 손실 허용)
**MQTT QoS 1 사용**
- **성능 분석**: 사이클 타임, 생산량, 효율성
- **상태 모니터링**: 온도, 진동, 전력 소비

#### 🟢 Real-time Data (손실 OK)
**직접 연결 사용**
- **연속 위치 데이터**: x,y,z 좌표, 관절 각도
- **순간 값**: 속도, 가속도 (다음 데이터로 대체 가능)

### 하이브리드 아키텍처 (권장)

```
로봇 → Gateway → 3갈래 분기
                ↓
   ┌─────────────────┬─────────────────┬─────────────────┐
   ↓                 ↓                 ↓
MQTT QoS 2        MQTT QoS 1      Direct WebSocket  
(Critical)       (Important)      (Real-time)
   ↓                 ↓                 ↓
안전/품질 DB       성능 분석 DB      실시간 UI
(PostgreSQL)     (TimescaleDB)    (브라우저들)
```

### MQTT QoS (Quality of Service) 레벨

#### QoS 0 - At most once (최대 1번)
```
발행자 → 브로커 → 구독자
       (전송)   (전송)
```
- **보장**: 없음 (Fire and forget)
- **성능**: 가장 빠름
- **손실**: 가능함
- **용도**: 실시간 데이터 (센서 값, 위치 정보)

#### QoS 1 - At least once (최소 1번)
```
발행자 → 브로커 → 구독자
       (전송)   (전송)
       ←───── ACK ←──────
       (확인)   (확인)
```
- **보장**: 최소 1번 전달 (중복 가능)
- **성능**: 보통
- **손실**: 없음 (단, 중복 수신 가능)
- **용도**: 중요한 상태 데이터, 알림

#### QoS 2 - Exactly once (정확히 1번)
```
발행자 → 브로커 → 구독자
       (전송)   (전송)
       ←───── ACK ←──────
       (확인)   (확인)
       ────→ COMP ──────→
       (완료)   (완료)
```
- **보장**: 정확히 1번 전달 (중복 없음)
- **성능**: 가장 느림 (4단계 핸드셰이크)
- **손실**: 절대 없음, 중복도 없음
- **용도**: 금융 거래, 안전 시스템, 품질 데이터

### 실무 판단 기준

**"이 데이터가 1시간 손실되면 어떻게 될까?"**

| 결과 | QoS 레벨 | 예시 |
|------|----------|------|
| **회사 망함** | QoS 2 | 안전 데이터, 품질 검사 결과 |
| **분석 어려움** | QoS 1 | 성능 지표, 상태 모니터링 |
| **별로 상관없음** | QoS 0 또는 직접 연결 | 실시간 위치, 순간 속도 |

### Single Point of Failure 해결

#### Gateway 이중화
```
로봇 → Primary Gateway ──┐
       ↓ (heartbeat)     ├→ MQTT Cluster
       Backup Gateway ───┘
```

#### MQTT Broker 클러스터링
```
Gateway → MQTT Broker 1 ──┐
          ↓ (cluster)     ├→ Subscribers
          MQTT Broker 2 ──┘
```

**최종 권장**: 데이터 중요도에 따라 **선별적 보장 전략**을 사용하여 **성능과 안정성의 균형**을 맞추는 것이 현실적입니다.