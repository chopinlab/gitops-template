# 서버 초기 설정 가이드

이 문서는 Ubuntu 서버에서 개발 환경을 구축하기 위한 초기 설정 스크립트를 제공합니다.

## 시스템 업데이트

```bash
sudo apt update
sudo apt upgrade
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
sudo apt install zsh fonts-powerline

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
plugins=(git zsh-syntax-highlighting zsh-autosuggestions)
```

## Python 환경 관리 (pyenv)

여러 Python 버전을 관리하기 위한 pyenv를 설치합니다.

```bash
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
sudo apt install docker.io docker-compose

# 사용자를 docker 그룹에 추가
sudo usermod -aG docker $USER
newgrp docker

# Docker 서비스 시작 및 자동 시작 설정
sudo systemctl start docker
sudo systemctl enable docker
```

## Kubernetes (K3s) 설치

경량화된 Kubernetes 배포판인 K3s를 설치합니다.

```bash
# K3s 설치
curl -sfL https://get.k3s.io | sh -

# kubectl 설정
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $USER:$USER ~/.kube/config
chmod 600 ~/.kube/config

# 환경 변수 설정
echo 'export KUBECONFIG=~/.kube/config' >> ~/.zshrc
source ~/.zshrc
```

## 설치 완료 후

모든 설치가 완료된 후 셸을 재시작하거나 시스템을 재부팅하여 모든 설정이 적용되도록 합니다.

```bash
# 셸 재시작
exec "$SHELL"

# 또는 시스템 재부팅
sudo reboot
```