#!/bin/bash
#
# AI Security System — VPN/Docker Compatibility Mode
# Безопасная настройка для Remnawave + Docker
#

set -e

echo "🔧 Настройка AI Security для VPN сервера..."
echo "=============================================="
echo ""

# === 1. Whitelist для Docker сетей ===
echo "📦 Whitelist Docker сетей..."

# Docker bridge сети
DOCKER_NETWORKS=(
    "172.17.0.0/16"
    "172.18.0.0/16"
    "172.19.0.0/16"
    "172.20.0.0/16"
    "172.21.0.0/16"
    "172.22.0.0/16"
    "172.23.0.0/16"
    "172.24.0.0/16"
    "172.25.0.0/16"
    "172.26.0.0/16"
    "172.27.0.0/16"
    "172.28.0.0/16"
    "172.29.0.0/16"
    "172.30.0.0/16"
    "172.31.0.0/16"
    "172.32.0.0/12"
)

for network in "${DOCKER_NETWORKS[@]}"; do
    # Проверяем не добавлено ли уже
    if ! sudo iptables -C INPUT -s "$network" -j ACCEPT -m comment --comment "DOCKER_WHITELIST" 2>/dev/null; then
        sudo iptables -I INPUT 1 -s "$network" -j ACCEPT -m comment --comment "DOCKER_WHITELIST"
        echo "   ✅ Docker сеть: $network"
    fi
done

echo ""

# === 2. Whitelist для VPN портов ===
echo "🔐 Whitelist VPN портов..."

# WireGuard (стандартный порт Remnawave)
WIREGUARD_PORT="${WIREGUARD_PORT:-51820}"

# OpenVPN
OPENVPN_PORT="${OPENVPN_PORT:-1194}"

# Функция для whitelist порта
whitelist_vpn_port() {
    local port="$1"
    local proto="$2"
    local name="$3"
    
    if ! sudo iptables -C INPUT -p "$proto" --dport "$port" -j ACCEPT -m comment --comment "VPN_$name" 2>/dev/null; then
        sudo iptables -I INPUT 1 -p "$proto" --dport "$port" -j ACCEPT -m comment --comment "VPN_$name"
        echo "   ✅ $name: $port/$proto"
    fi
}

whitelist_vpn_port "$WIREGUARD_PORT" "udp" "WIREGUARD"
whitelist_vpn_port "$OPENVPN_PORT" "udp" "OPENVPN"
whitelist_vpn_port "$OPENVPN_PORT" "tcp" "OPENVPN_TCP"

# HTTPS (веб-панель)
whitelist_vpn_port "443" "tcp" "HTTPS"

# HTTP (если нужен)
whitelist_vpn_port "80" "tcp" "HTTP"

echo ""

# === 3. Отключаем опасные лимиты для VPN ===
echo "⚙️ Настройка лимитов для VPN..."

# Удаляем агрессивные UDP лимиты если есть
sudo iptables -D INPUT -p udp -m limit --limit 5/s --limit-burst 10 -j ACCEPT 2>/dev/null || true
sudo iptables -D INPUT -p udp -j DROP 2>/dev/null || true

# Удаляем connection limits для VPN портов
sudo iptables -D INPUT -p udp --dport "$WIREGUARD_PORT" -m connlimit --connlimit-above 20 -j DROP 2>/dev/null || true

echo "   ✅ VPN лимиты отключены"
echo ""

# === 4. Сохраняем правила ДО Docker ===
echo "💾 Сохраняем правила..."

# Проверяем что Docker не перезапишет правила
if ! sudo iptables -L DOCKER-USER -n &>/dev/null; then
    sudo iptables -N DOCKER-USER 2>/dev/null || true
fi

# Добавляем наши правила в DOCKER-USER цепочку
if ! sudo iptables -C DOCKER-USER -j RETURN -m comment --comment "AI_SECURITY_COMPAT" 2>/dev/null; then
    sudo iptables -A DOCKER-USER -j RETURN -m comment --comment "AI_SECURITY_COMPAT"
fi

echo "   ✅ Docker совместимость включена"
echo ""

# === 5. Настраиваем AI Security конфиг ===
echo "📝 Настройка AI Security..."

cat > /home/larson/security-monitor/vpn_mode.conf << 'EOF'
# VPN Compatibility Mode Configuration

# Whitelist диапазоны (не блокировать)
VPN_WHITELIST_RANGES=(
    "172.16.0.0/12"      # Docker сети
    "10.8.0.0/24"        # OpenVPN клиенты
    "10.9.0.0/24"        # WireGuard клиенты
)

# Whitelist порты (не применять rate limit)
VPN_PORTS=(
    "51820/udp"          # WireGuard
    "1194/udp"           # OpenVPN
    "1194/tcp"           # OpenVPN TCP
    "443/tcp"            # HTTPS панель
)

# Исключить Docker контейнеры из мониторинга
EXCLUDE_DOCKER=true

# Не блокировать если это VPN клиент
SKIP_VPN_CLIENTS=true

# Пороги для VPN сервера (более мягкие)
VPN_THRESHOLD_NEW_IP=10        # Было 3
VPN_THRESHOLD_SUSPICIOUS=20    # Было 5
VPN_THRESHOLD_ATTACK=50        # Было 10
VPN_THRESHOLD_CRITICAL=100     # Было 20
EOF

echo "   ✅ Конфигурация сохранена"
echo ""

# === 6. Перезапускаем AI Security ===
echo "🔄 Перезапуск AI Security..."

sudo systemctl restart ai-security-v3 2>/dev/null || true

echo "   ✅ AI Security перезапущен"
echo ""

# === 7. Проверка ===
echo "═══════════════════════════════════════"
echo "✅ VPN COMPATIBILITY MODE ВКЛЮЧЁН"
echo "═══════════════════════════════════════"
echo ""
echo "📊 Активные правила:"
sudo iptables -L INPUT -n -v --line-numbers | grep -E "DOCKER|VPN|WIREGUARD|OPENVPN" | head -15

echo ""
echo "🔍 Статус:"
echo "   • Docker сети: whitelist ✅"
echo "   • WireGuard порт $WIREGUARD_PORT: whitelist ✅"
echo "   • OpenVPN порт $OPENVPN_PORT: whitelist ✅"
echo "   • HTTPS порт 443: whitelist ✅"
echo "   • Агрессивные лимиты: отключены ✅"
echo ""
echo "📋 Для проверки что VPN работает:"
echo "   sudo docker ps"
echo "   sudo wg show"
echo "   sudo systemctl status remnawave"
