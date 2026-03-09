#!/bin/bash
#
# Защита от марсианских пакетов (Martian Packets Protection)
# Блокирует пакеты с поддельными/некорректными IP-адресами
#

set -e

echo "🛡️ Защита от марсианских пакетов"
echo "=================================="
echo ""

# === 1. Включаем защиту ядра от спуфинга ===
echo "📋 Включаем reverse path filtering..."

# Проверяем и включаем rp_filter для всех интерфейсов
for interface in /proc/sys/net/ipv4/conf/*/rp_filter; do
    echo 1 | sudo tee "$interface" > /dev/null 2>&1
done

# Включаем строгую проверку
sudo sysctl -w net.ipv4.conf.all.rp_filter=1 2>/dev/null || true
sudo sysctl -w net.ipv4.conf.default.rp_filter=1 2>/dev/null || true

# Игнорируем ICMP редиректы
sudo sysctl -w net.ipv4.conf.all.accept_redirects=0 2>/dev/null || true
sudo sysctl -w net.ipv4.conf.default.accept_redirects=0 2>/dev/null || true
sudo sysctl -w net.ipv4.secure_redirects=0 2>/dev/null || true

# Не принимаем source routing
sudo sysctl -w net.ipv4.conf.all.accept_source_route=0 2>/dev/null || true
sudo sysctl -w net.ipv4.conf.default.accept_source_route=0 2>/dev/null || true

# Логгируем марсианские пакеты
sudo sysctl -w net.ipv4.conf.all.log_martians=1 2>/dev/null || true
sudo sysctl -w net.ipv4.conf.default.log_martians=1 2>/dev/null || true

echo "✅ Reverse path filtering включён"
echo ""

# === 2. Блокируем марсианские диапазоны через iptables ===
echo "🚫 Блокируем марсианские IP-диапазоны..."

# Функция для добавления правила
block_martian() {
    local range="$1"
    local comment="$2"
    
    # Проверяем не добавлено ли уже
    if ! sudo iptables -C INPUT -s "$range" -j DROP -m comment --comment "MARTIAN_$comment" 2>/dev/null; then
        sudo iptables -A INPUT -s "$range" -j DROP -m comment --comment "MARTIAN_$comment"
        echo "   ✅ Заблокировано: $range ($comment)"
    fi
}

# Частные диапазоны (RFC 1918)
block_martian "10.0.0.0/8" "RFC1918_10"
block_martian "172.16.0.0/12" "RFC1918_172"
block_martian "192.168.0.0/16" "RFC1918_192"

# Loopback
block_martian "127.0.0.0/8" "LOOPBACK"

# Link-local (APIPA)
block_martian "169.254.0.0/16" "LINK_LOCAL"

# Зарезервированные IETF
block_martian "0.0.0.0/8" "ZERO"
block_martian "100.64.0.0/10" "CGN"
block_martian "192.0.0.0/24" "IETF"
block_martian "192.0.2.0/24" "TEST_NET_1"
block_martian "198.18.0.0/15" "BENCHMARK"
block_martian "198.51.100.0/24" "TEST_NET_2"
block_martian "203.0.113.0/24" "TEST_NET_3"

# Зарезервированные (Class E)
block_martian "240.0.0.0/4" "RESERVED"

# Вещательные
block_martian "255.255.255.255/32" "BROADCAST"

# IPv6 марсианские (если включен IPv6)
if sudo ip6tables -L INPUT &>/dev/null; then
    block_martian "::1/128" "IPV6_LOOPBACK"
    block_martian "fe80::/10" "IPV6_LINK_LOCAL"
    block_martian "ff00::/8" "IPV6_MULTICAST"
fi

echo ""
echo "✅ Все марсианские диапазоны заблокированы"
echo ""

# === 3. Блокируем пакеты с некорректными флагами ===
echo "🚫 Блокируем пакеты с некорректными TCP флагами..."

# NULL scan (нет флагов)
if ! sudo iptables -C INPUT -p tcp --tcp-flags ALL NONE -j DROP -m comment --comment "MARTIAN_NULL" 2>/dev/null; then
    sudo iptables -A INPUT -p tcp --tcp-flags ALL NONE -j DROP -m comment --comment "MARTIAN_NULL"
    echo "   ✅ NULL scan заблокирован"
fi

# XMAS scan (все флаги)
if ! sudo iptables -C INPUT -p tcp --tcp-flags ALL ALL -j DROP -m comment --comment "MARTIAN_XMAS" 2>/dev/null; then
    sudo iptables -A INPUT -p tcp --tcp-flags ALL ALL -j DROP -m comment --comment "MARTIAN_XMAS"
    echo "   ✅ XMAS scan заблокирован"
fi

# FIN без ACK
if ! sudo iptables -C INPUT -p tcp --tcp-flags ALL FIN -j DROP -m comment --comment "MARTIAN_FIN" 2>/dev/null; then
    sudo iptables -A INPUT -p tcp --tcp-flags ALL FIN -j DROP -m comment --comment "MARTIAN_FIN"
    echo "   ✅ FIN scan заблокирован"
fi

# SYN+FIN (некорректно)
if ! sudo iptables -C INPUT -p tcp --tcp-flags SYN,FIN SYN,FIN -j DROP -m comment --comment "MARTIAN_SYNFIN" 2>/dev/null; then
    sudo iptables -A INPUT -p tcp --tcp-flags SYN,FIN SYN,FIN -j DROP -m comment --comment "MARTIAN_SYNFIN"
    echo "   ✅ SYN+FIN заблокирован"
fi

# SYN+RST (некорректно)
if ! sudo iptables -C INPUT -p tcp --tcp-flags SYN,RST SYN,RST -j DROP -m comment --comment "MARTIAN_SYNRST" 2>/dev/null; then
    sudo iptables -A INPUT -p tcp --tcp-flags SYN,RST SYN,RST -j DROP -m comment --comment "MARTIAN_SYNRST"
    echo "   ✅ SYN+RST заблокирован"
fi

echo ""
echo "✅ Некорректные TCP пакеты заблокированы"
echo ""

# === 4. Сохраняем правила ===
echo "💾 Сохраняем правила..."

if command -v iptables-save &>/dev/null; then
    sudo iptables-save | sudo tee /etc/iptables/rules.v4 > /dev/null 2>&1 || true
    echo "✅ Правила сохранены"
fi

echo ""
echo "═══════════════════════════════════════"
echo "✅ ЗАЩИТА ОТ МАРСИАНСКИХ ПАКЕТОВ ВКЛЮЧЕНА"
echo "═══════════════════════════════════════"
echo ""

# === 5. Показываем статистику ===
echo "📊 Статистика блокировок:"
echo ""
sudo iptables -L INPUT -n -v --line-numbers | grep -E "MARTIAN|DROP" | head -20

echo ""
echo "📋 Для просмотра логов марсианских пакетов:"
echo "   sudo dmesg | grep -i martian"
echo "   sudo journalctl -k | grep -i martian"
