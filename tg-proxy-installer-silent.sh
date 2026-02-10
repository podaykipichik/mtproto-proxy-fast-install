#!/bin/bash

########################################
#        Telegram MTProto Proxy        #
#         One-click installer          #
#           by podaykirpichik          #
########################################

set -e

# ========= Colors =========
GREEN='\033[0;32m'
BLUE='\033[1;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log()  { echo -e "${BLUE}👉 $1${NC}"; }
ok()   { echo -e "${GREEN}✅ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }

# ========= Root check =========
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}❌ Запусти скрипт через sudo или root${NC}"
  exit 1
fi

# ========= Silent mode =========
SILENT=false

if [[ "$1" == "--silent" ]]; then
  SILENT=true
else
  echo
  read -p "🤫 Включить тихий режим? (y/N): " ANSWER
  [[ "$ANSWER" =~ ^[Yy]$ ]] && SILENT=true
fi

# ========= Run helper =========
run() {
  if [ "$SILENT" = true ]; then
    "$@" > /dev/null 2>&1
  else
    "$@"
  fi
}

clear
echo -e "${GREEN}"
echo "======================================="
echo " 🚀 Telegram MTProto Proxy Installer"
echo "======================================="
echo -e "${NC}"

# ========= Questions =========
read -p "🌍 Введи порт для прокси (по умолчанию 443): " PORT
PORT=${PORT:-443}

# ========= Install Docker =========
log "Устанавливаем Docker..."

run apt update -qq
run apt install -y -qq docker.io openssl ufw

run systemctl enable docker
run systemctl start docker

ok "Docker установлен"

# ========= Firewall =========
log "Открываем порт $PORT"

run ufw allow $PORT/tcp || true

ok "Порт открыт"

# ========= Pull image =========
log "Скачиваем образ Telegram proxy"

run docker pull -q telegrammessenger/proxy

ok "Образ загружен"

# ========= Generate secret =========
log "Генерируем секретный ключ..."

SECRET=$(openssl rand -hex 16)

echo -e "${GREEN}🔑 SECRET: ${YELLOW}$SECRET${NC}"

# ========= Remove old container =========
if [ "$(docker ps -aq -f name=tg-proxy)" ]; then
  warn "Старый контейнер найден. Удаляем..."
  run docker rm -f tg-proxy
fi

# ========= Run container =========
log "Запускаем контейнер..."

run docker run -d \
  --name tg-proxy \
  -p $PORT:443 \
  -e SECRET=$SECRET \
  --restart=always \
  telegrammessenger/proxy

ok "Контейнер запущен"

# ========= Connection info =========
IP=$(curl -s ifconfig.me || echo "YOUR_IP")

echo
echo -e "${GREEN}======================================="
echo " 🎉 Готово!"
echo "======================================="
echo -e "🌍 IP:      ${YELLOW}$IP${NC}"
echo -e "🔌 Port:    ${YELLOW}$PORT${NC}"
echo -e "🔑 Secret:  ${YELLOW}$SECRET${NC}"
echo
echo -e "📱 Ссылка для Telegram:"
echo -e "${BLUE}https://t.me/proxy?server=$IP&port=$PORT&secret=$SECRET${NC}"
echo -e "${GREEN}=======================================${NC}"

# ========= Logs =========
if [ "$SILENT" = false ]; then
echo -e "${BLUE}https://t.me/proxy?server=$IP&port=$PORT&secret=$SECRET${NC}"
fi
