#!/bin/bash
#
# Anti-DDoS модуль для AI Security System
# Реальные меры защиты от DDoS атак
#

set -u

# === ЯДРО ЗАЩИТЫ ===

# 1. SYN Flood Protection
enable_syn_protection() {
    echo "🛡️ Включаем SYN Flood Protection..."
    
    # Ядерные параметры
    sudo sysctl -w net.ipv4.tcp_syncookies=1
    sudo sysctl -w net.ipv4.tcp_max_syn_backlog=2048
    sudo sysctl -w net.ipv4.tcp_synack_retries=2
    sudo sysctl -w net.ipv4.tcp_syn_retries=5
    
    # iptables правила
    sudo iptables -A INPUT -p tcp --syn -m limit --limit 1/s --limit-burst 3 -j ACCEPT
    sudo iptables -A INPUT -p tcp --syn -j DROP
    
    echo "✅ SYN Flood Protection активирован"
}

# 2. ICMP Flood Protection
enable_icmp_protection() {
    echo "🛡️ Включаем ICMP Flood Protection..."
    
    # Ограничиваем ICMP
    sudo sysctl -w net.ipv4.icmp_echo_ignore_broadcasts=1
    sudo sysctl -w net.ipv4.icmp_ignore_bogus_error_responses=1
    sudo sysctl -w net.ipv4.icmp_echo_ignore_all=0
    
    # Rate limit для ICMP
    sudo iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 1/s --limit-burst 4 -j ACCEPT
    sudo iptables -A INPUT -p icmp --icmp-type echo-request -j DROP
    
    echo "✅ ICMP Flood Protection активирован"
}

# 3. UDP Flood Protection
enable_udp_protection() {
    echo "🛡️ Включаем UDP Flood Protection..."
    
    # Ограничиваем UDP
    sudo iptables -A INPUT -p udp -m limit --limit 5/s --limit-burst 10 -j ACCEPT
    sudo iptables -A INPUT -p udp -j DROP
    
    # Блокируем ненужные UDP порты
    sudo iptables -A INPUT -p udp --dport 7 -j DROP    # Echo
    sudo iptables -A INPUT -p udp --dport 19 -j DROP   # Chargen
    sudo iptables -A INPUT -p udp --dport 53 -m limit --limit 10/s -j ACCEPT  # DNS
    
    echo "✅ UDP Flood Protection активирован"
}

# 4. HTTP Flood Protection
enable_http_protection() {
    echo "🛡️ Включаем HTTP Flood Protection..."
    
    # Если есть nginx
    if [[ -f /etc/nginx/nginx.conf ]]; then
        # Rate limiting для nginx
        sudo tee /etc/nginx/conf.d/rate_limit.conf > /dev/null << 'EOF'
limit_req_zone $binary_remote_addr zone=one:10m rate=10r/s;
limit_req_zone $binary_remote_addr zone=api:10m rate=5r/s;
EOF
        sudo nginx -t && sudo systemctl reload nginx
    fi
    
    # iptables для HTTP/HTTPS
    sudo iptables -A INPUT -p tcp --dport 80 -m limit --limit 25/s --limit-burst 100 -j ACCEPT
    sudo iptables -A INPUT -p tcp --dport 443 -m limit --limit 25/s --limit-burst 100 -j ACCEPT
    
    echo "✅ HTTP Flood Protection активирован"
}

# 5. Connection Rate Limiting
enable_connection_limit() {
    echo "🛡️ Включаем Connection Rate Limiting..."
    
    # Ограничиваем количество соединений с одного IP
    sudo iptables -A INPUT -p tcp --syn -m connlimit --connlimit-above 20 -j DROP
    
    # Ограничиваем новые соединения
    sudo iptables -A INPUT -p tcp -m state --state NEW -m recent --set
    sudo iptables -A INPUT -p tcp -m state --state NEW -m recent --update --seconds 60 --hitcount 50 -j DROP
    
    echo "✅ Connection Rate Limiting активирован"
}

# 6. Blackhole Routing (для серьёзных атак)
enable_blackhole() {
    local attacker_ip="$1"
    
    echo "⚫ Включаем Blackhole для $attacker_ip..."
    
    # Маршрутизируем трафик в никуда
    sudo ip route add "$attacker_ip" via 127.0.0.1 dev lo
    
    echo "✅ $attacker_ip отправлен в blackhole"
}

# 7. DDoS Detection
detect_ddos() {
    echo "🔍 Сканирование на предмет DDoS атак..."
    
    local alerts=()
    
    # Проверка SYN_RECV
    local syn_recv
    syn_recv=$(netstat -an 2>/dev/null | grep -c SYN_RECV || echo 0)
    if [[ $syn_recv -gt 100 ]]; then
        alerts+=("SYN_FLOOD:$syn_recv")
    fi
    
    # Проверка UDP трафика
    local udp_count
    udp_count=$(netstat -anu 2>/dev/null | wc -l)
    if [[ $udp_count -gt 500 ]]; then
        alerts+=("UDP_FLOOD:$udp_count")
    fi
    
    # Проверка ICMP
    local icmp_count
    icmp_count=$(netstat -anp 2>/dev/null | grep -c icmp || echo 0)
    if [[ $icmp_count -gt 100 ]]; then
        alerts+=("ICMP_FLOOD:$icmp_count")
    fi
    
    # Проверка нагрузки на сеть
    local rx_bytes
    rx_bytes=$(cat /sys/class/net/*/statistics/rx_bytes 2>/dev/null | awk '{sum+=$1}END{print sum}')
    local prev_rx="${PREV_RX_BYTES:-0}"
    
    if [[ $rx_bytes -gt 0 && $prev_rx -gt 0 ]]; then
        local diff=$((rx_bytes - prev_bytes))
        local mbps=$((diff / 1024 / 1024))
        
        if [[ $mbps -gt 100 ]]; then
            alerts+=("BANDWIDTH_SPIKE:${mbps}MB/s")
        fi
    fi
    PREV_RX_BYTES=$rx_bytes
    
    # Проверка количества подключений от одного IP
    local conn_flood
    conn_flood=$(netstat -an 2>/dev/null | awk '{print $5}' | cut -d':' -f1 | sort | uniq -c | sort -rn | head -1 | awk '{print $1}')
    
    if [[ ${conn_flood:-0} -gt 100 ]]; then
        local flood_ip
        flood_ip=$(netstat -an 2>/dev/null | awk '{print $5}' | cut -d':' -f1 | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')
        alerts+=("CONN_FLOOD:$flood_ip:$conn_flood")
    fi
    
    # Вывод результатов
    if [[ ${#alerts[@]} -gt 0 ]]; then
        echo "🚨 ОБНАРУЖЕНЫ DDoS АТАКИ:"
        printf '%s\n' "${alerts[@]}"
        
        # Автоматическая защита
        for alert in "${alerts[@]}"; do
            IFS=':' read -r type value extra <<< "$alert"
            
            case "$type" in
                "CONN_FLOOD")
                    echo "⚡ Блокировка $extra..."
                    sudo iptables -A INPUT -s "$extra" -j DROP -m comment --comment "DDOS_AUTO"
                    ;;
            esac
        done
    else
        echo "✅ DDoS атак не обнаружено"
    fi
}

# 8. Emergency Mode (полная защита)
enable_emergency_mode() {
    echo "🚨 ВКЛЮЧЕНИЕ АВАРИЙНОГО РЕЖИМА ЗАЩИТЫ..."
    
    # Блокируем ВСЁ кроме необходимого
    sudo iptables -F
    sudo iptables -P INPUT DROP
    sudo iptables -P FORWARD DROP
    sudo iptables -P OUTPUT ACCEPT
    
    # Разрешаем loopback
    sudo iptables -A INPUT -i lo -j ACCEPT
    
    # Разрешаем установленные соединения
    sudo iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    
    # Разрешаем SSH (только с ограничением)
    sudo iptables -A INPUT -p tcp --dport 22 -m limit --limit 3/min --limit-burst 3 -j ACCEPT
    
    # Разрешаем HTTP/HTTPS с ограничением
    sudo iptables -A INPUT -p tcp --dport 80 -m limit --limit 10/s -j ACCEPT
    sudo iptables -A INPUT -p tcp --dport 443 -m limit --limit 10/s -j ACCEPT
    
    # Блокируем ICMP полностью
    sudo iptables -A INPUT -p icmp -j DROP
    
    # Блокируем UDP полностью
    sudo iptables -A INPUT -p udp -j DROP
    
    echo "✅ АВАРИЙНЫЙ РЕЖИМ АКТИВИРОВАН"
    echo "⚠️ Внимание: многие сервисы могут быть недоступны"
}

# 9. Disable Emergency Mode
disable_emergency_mode() {
    echo "🟢 ОТКЛЮЧЕНИЕ АВАРИЙНОГО РЕЖИМА..."
    
    sudo iptables -F
    sudo iptables -P INPUT ACCEPT
    sudo iptables -P FORWARD ACCEPT
    sudo iptables -P OUTPUT ACCEPT
    
    echo "✅ Аварийный режим отключён"
}

# 10. Status
show_ddos_status() {
    echo "📊 СТАТУС ANTI-DDOS ЗАЩИТЫ"
    echo "══════════════════════════"
    
    # Ядерные параметры
    echo ""
    echo "🔧 Ядерные параметры:"
    echo "   TCP Syncookies: $(cat /proc/sys/net/ipv4/tcp_syncookies)"
    echo "   TCP Max Syn Backlog: $(cat /proc/sys/net/ipv4/tcp_max_syn_backlog)"
    echo "   ICMP Echo Ignore: $(cat /proc/sys/net/ipv4/icmp_echo_ignore_broadcasts)"
    
    # Статистика подключений
    echo ""
    echo "📈 Статистика подключений:"
    echo "   SYN_RECV: $(netstat -an 2>/dev/null | grep -c SYN_RECV || echo 0)"
    echo "   UDP: $(netstat -anu 2>/dev/null | wc -l)"
    echo "   ICMP: $(netstat -anp 2>/dev/null | grep -c icmp || echo 0)"
    
    # Правила iptables
    echo ""
    echo "🛡️ Правила iptables:"
    sudo iptables -L INPUT -n --line-numbers | head -20
    
    # Топ IP по подключениям
    echo ""
    echo "🎯 Топ IP по подключениям:"
    netstat -an 2>/dev/null | awk '{print $5}' | cut -d':' -f1 | sort | uniq -c | sort -rn | head -10
}

# === MAIN ===
case "${1:-status}" in
    "enable")
        enable_syn_protection
        enable_icmp_protection
        enable_udp_protection
        enable_http_protection
        enable_connection_limit
        echo ""
        echo "✅ ВСЯ ЗАЩИТА АКТИВИРОВАНА"
        ;;
    "emergency")
        enable_emergency_mode
        ;;
    "disable-emergency")
        disable_emergency_mode
        ;;
    "detect")
        detect_ddos
        ;;
    "blackhole")
        if [[ -n "${2:-}" ]]; then
            enable_blackhole "$2"
        else
            echo "Использование: $0 blackhole <IP>"
        fi
        ;;
    "status"|*)
        show_ddos_status
        ;;
esac
