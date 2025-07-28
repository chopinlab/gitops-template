# ESC 키 관련 문제 해결
set nocompatible
set esckeys
set ttimeout
set ttimeoutlen=10

# 기본 설정
set number              # 줄 번호 표시
set autoindent          # 자동 들여쓰기
set tabstop=4           # 탭 크기
set shiftwidth=4        # 들여쓰기 크기
set expandtab           # 탭을 스페이스로 변환
set hlsearch            # 검색 결과 하이라이트
set incsearch           # 실시간 검색
set ignorecase          # 검색시 대소문자 무시
set smartcase           # 대문자 포함시 대소문자 구분
set showmatch           # 괄호 매칭 표시
set ruler               # 커서 위치 표시
set laststatus=2        # 상태바 항상 표시

# 문법 강조
syntax on

# 파일 인코딩
set encoding=utf-8
set fileencoding=utf-8