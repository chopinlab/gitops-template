# 서버 초기 설정 가이드

이 문서는 Ubuntu 서버에서 GitOps 기반 마이크로서비스 환경과 모니터링 스택을 구축하기 위한 초기 설정 가이드를 제공합니다.

## 시스템 업데이트

```bash
sudo apt update
sudo apt upgrade -y
```

## 절전 모드 비활성화

서버 환경에서는 절전 모드를 비활성화하여 항상 실행 상태를 유지합니다.

```bash
# 절전 모드 상태 확인
systemctl status sleep.target suspend.target hibernate.target hybrid-sleep.target

# 절전 모드 비활성화
sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target

# 비활성화 상태 확인
systemctl is-enabled sleep.target suspend.target hibernate.target hybrid-sleep.target
```

## 화면 자동 꺼짐 설정

콘솔 화면이 10분 후 자동으로 꺼지도록 설정합니다.

```bash
# 화면 자동 꺼짐 설정 (10분)
sudo setterm -blank 10 -powerdown 10

# 부팅 시 자동 적용되도록 설정
echo 'setterm -blank 10 -powerdown 10' | sudo tee -a /etc/rc.local
sudo chmod +x /etc/rc.local
```

## Zsh 및 Oh My Zsh 설치

개발 생산성을 위한 향상된 셸 환경을 구축합니다.

```bash
# Zsh 및 폰트 설치
sudo apt install -y zsh fonts-powerline curl git

# 기본 셸을 Zsh로 변경
chsh -s $(which zsh)

# Oh My Zsh 설치
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# Powerlevel10k 테마 설치
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
```

### Zsh 플러그인 설치

구문 강조 및 자동 완성 플러그인을 설치합니다.

```bash
# 구문 강조 플러그인
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

# 자동 완성 플러그인
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
```

### .zshrc 설정

다음 설정을 `.zshrc` 파일에 추가하세요:

```bash
# 테마 설정
ZSH_THEME="powerlevel10k/powerlevel10k"

# 플러그인 설정
plugins=(git zsh-syntax-highlighting zsh-autosuggestions docker kubectl helm)

# 유용한 알리아스
alias k=kubectl
alias kgp="kubectl get pods"
alias kgs="kubectl get svc"
alias kgn="kubectl get nodes"
alias h=helm
alias d=docker
alias dc="docker-compose"
```

## Python 환경 관리 (pyenv)

여러 Python 버전을 관리하기 위한 pyenv를 설치합니다.

```bash
# 필요한 패키지 설치
sudo apt install -y make build-essential libssl-dev zlib1g-dev \
  libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm \
  libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev \
  libffi-dev liblzma-dev

# pyenv 설치
curl https://pyenv.run | bash

# 환경 변수 설정
echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.zshrc
echo 'command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.zshrc
echo 'eval "$(pyenv init -)"' >> ~/.zshrc

# 셸 재시작
exec "$SHELL"

# 설치 확인
pyenv --version
```

## Docker 설치

컨테이너 환경을 위한 Docker를 설치합니다.

```bash
# Docker 및 Docker Compose 설치
sudo apt install -y docker.io docker-compose

# 사용자를 docker 그룹에 추가
sudo usermod -aG docker $USER
newgrp docker

# Docker 서비스 시작 및 자동 시작 설정
sudo systemctl start docker
sudo systemctl enable docker

# 설치 확인
docker --version
docker-compose --version
```

## Kubernetes (K3s) 설치

경량화된 Kubernetes 배포판인 K3s를 설치합니다.

### 기본 설치 (원격 접근 포함)

```bash
# K3s 설치 (TLS SAN 포함하여 원격 접근 가능하도록 설정)
curl -sfL https://get.k3s.io | sh -s - \
  --tls-san 192.168.1.100 \
  --tls-san your-server.example.com \
  --disable traefik

# kubectl 설정
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $USER:$USER ~/.kube/config
chmod 600 ~/.kube/config

# 환경 변수 설정
echo 'export KUBECONFIG=~/.kube/config' >> ~/.zshrc
source ~/.zshrc

# 설치 확인
kubectl cluster-info
kubectl get nodes
```

**중요:** `--tls-san` 옵션에 실제 서버 IP와 도메인을 입력하세요. 이는 원격에서 kubectl 접근 시 인증서 검증을 위해 필요합니다.

### K3s 재설치 (TLS SAN 추가가 필요한 경우)

이미 K3s를 설치했지만 원격 접근을 위해 TLS SAN을 추가해야 하는 경우:

```bash
# K3s 완전 삭제
sudo /usr/local/bin/k3s-uninstall.sh

# 남은 파일들 정리 (필요시)
sudo rm -rf /var/lib/rancher/k3s
sudo rm -rf /etc/rancher/k3s

# TLS SAN 포함하여 재설치
curl -sfL https://get.k3s.io | sh -s - \
  --tls-san 192.168.1.100 \
  --tls-san your-server.example.com \
  --disable traefik

# kubectl 설정
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $USER:$USER ~/.kube/config
chmod 600 ~/.kube/config
```

## Helm 설치

Kubernetes 패키지 관리자인 Helm을 설치합니다.

```bash
# Helm 설치
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# 설치 확인
helm version

# 모니터링 관련 Helm 레포지토리 추가
helm repo add vm https://victoriametrics.github.io/helm-charts/
helm repo add grafana https://grafana.github.io/helm-charts/
helm repo add fluent https://fluent.github.io/helm-charts/
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts/
helm repo update
```

## 모니터링 스택 설치

완전한 관측성 솔루션을 설치합니다.

### 자동 설치 (권장)

```bash
# 환경변수 설정 (실제 서버 IP로 변경)
export EXTERNAL_IP=192.168.1.100

# 모니터링 스택 자동 설치
cd /path/to/gitops-template/infrastructure/helm/install-scripts
./install-monitoring.sh
```

### 수동 설치

```bash
# 네임스페이스 생성
kubectl create namespace monitoring

# VictoriaMetrics (메트릭 저장소)
helm install victoria-metrics vm/victoria-metrics-single \
  -f infrastructure/helm/charts/victoria-metrics/values-dev.yaml \
  -n monitoring

# Node Exporter (시스템 메트릭)
helm install node-exporter prometheus-community/prometheus-node-exporter \
  -f infrastructure/helm/charts/node-exporter/values-dev.yaml \
  -n monitoring

# Fluent Bit (로그 수집)
helm install fluent-bit fluent/fluent-bit \
  -f infrastructure/helm/charts/fluent-bit/values-dev.yaml \
  -n monitoring

# VictoriaLogs (로그 저장소)
helm install vl vm/victoria-logs-single \
  -f infrastructure/helm/charts/victoria-logs/values-dev.yaml \
  -n monitoring

# Grafana (시각화)
helm install grafana grafana/grafana \
  -f infrastructure/helm/charts/grafana/values-dev.yaml \
  -n monitoring
```

### 모니터링 접근

```bash
# 서비스 상태 확인
kubectl get pods -n monitoring
kubectl get svc -n monitoring

# 접근 URL (EXTERNAL_IP는 실제 서버 IP)
echo "Grafana: http://$EXTERNAL_IP:80"
echo "VictoriaMetrics: http://$EXTERNAL_IP:8428"
echo "VictoriaLogs: http://$EXTERNAL_IP:9428"

# Grafana 로그인 정보
echo "Username: admin"
echo "Password: admin123"
```

## 원격 클라이언트 설정 (맥북 등)

### 서버에서

1. kubeconfig 파일 내용 복사:
```bash
cat ~/.kube/config
```

### 클라이언트에서

```bash
# kubectl 설치 (macOS)
brew install kubectl helm

# kubeconfig 디렉토리 생성
mkdir -p ~/.kube

# 서버에서 복사한 내용을 ~/.kube/config에 저장
# server 주소를 localhost에서 실제 서버 주소로 변경
# server: https://127.0.0.1:6443
# ↓
# server: https://192.168.1.100:6443 (또는 도메인)

# 연결 테스트
kubectl cluster-info
kubectl get nodes
kubectl get pods -n monitoring

# Helm 레포지토리 추가 (클라이언트에서도)
helm repo add vm https://victoriametrics.github.io/helm-charts/
helm repo add grafana https://grafana.github.io/helm-charts/
helm repo update
```

## 방화벽 설정 (필요시)

모니터링 서비스에 외부에서 접근하려면 방화벽 포트를 열어야 합니다.

```bash
# UFW 방화벽 설정 (Ubuntu)
sudo ufw allow 80/tcp      # Grafana
sudo ufw allow 8428/tcp    # VictoriaMetrics
sudo ufw allow 9428/tcp    # VictoriaLogs
sudo ufw allow 6443/tcp    # Kubernetes API

# 방화벽 상태 확인
sudo ufw status
```

## 설치 완료 후

모든 설치가 완료된 후 셸을 재시작하거나 시스템을 재부팅하여 모든 설정이 적용되도록 합니다.

```bash
# 셸 재시작
exec "$SHELL"

# 또는 시스템 재부팅
sudo reboot
```

## 확인 및 검증

### 기본 서비스 확인

```bash
# K3s 상태 확인
sudo systemctl status k3s

# Traefik 파드가 없는지 확인 (disable 했으므로)
kubectl get pods -n kube-system | grep traefik

# Docker 상태 확인
docker ps
sudo systemctl status docker
```

### 모니터링 스택 확인

```bash
# 모니터링 네임스페이스 파드 상태
kubectl get pods -n monitoring

# 서비스 상태
kubectl get svc -n monitoring

# Helm 설치 상태
helm list -n monitoring

# 로그 확인 (문제 발생 시)
kubectl logs -n monitoring deployment/grafana
kubectl logs -n monitoring statefulset/victoria-metrics-server
kubectl logs -n monitoring daemonset/fluent-bit
```

### 웹 UI 접근 테스트

```bash
# 브라우저에서 접근 테스트
curl -I http://192.168.1.100:80          # Grafana
curl -I http://192.168.1.100:8428        # VictoriaMetrics
curl -I http://192.168.1.100:9428        # VictoriaLogs
```

## 문제 해결

### 일반적인 문제

1. **K3s 접근 권한 오류**
```bash
sudo chown $USER:$USER ~/.kube/config
chmod 600 ~/.kube/config
```

2. **Docker 권한 오류**
```bash
sudo usermod -aG docker $USER
newgrp docker
```

3. **모니터링 파드 시작 안됨**
```bash
# 리소스 부족 확인
kubectl top nodes
kubectl describe pod -n monitoring <pod-name>
```

4. **원격 kubectl 접근 오류**
- K3s 설치 시 `--tls-san` 옵션이 누락되었을 가능성
- 위의 K3s 재설치 섹션 참고

### 완전 재설치

문제가 지속될 경우 완전 재설치:

```bash
# 모니터링 스택 제거
helm uninstall -n monitoring grafana vl fluent-bit node-exporter victoria-metrics
kubectl delete namespace monitoring

# K3s 제거
sudo /usr/local/bin/k3s-uninstall.sh

# 다시 설치 과정 반복
```

이 가이드를 따라 설치하면 완전한 GitOps 기반 마이크로서비스 환경과 모니터링 시스템이 구축됩니다.