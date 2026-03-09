#!/bin/bash
#
# Расширенный мониторинг атак для AI Security System v3.0
# Отслеживает ВСЕ типы атак: SSH, DNS, DDoS, Port Scan, Web и другие
#

# === МОНИТОРИНГ SSH АТАК ===
monitor_ssh_attacks() {
    local attacks=()
    
    # Неудачные попытки входа
    local failed_logins
    failed_logins=$(sudo grep "Failed password" /var/log/auth.log 2>/dev/null | \
        tail -500 | awk '{for(i=1;i<=NF;i++) if($i=="from") print $(i+1)}' | \
        sort | uniq -c | sort -rn | head -20)
    
    if [[ -n "$failed_logins" ]]; then
        while read -r count ip; do
            if [[ $count -ge 3 && -n "$ip" ]]; then
                attacks+=("SSH|$ip|$count|Failed logins")
            fi
        done <<< "$failed_logins"
    fi
    
    # Попытки входа под root
    local root_attempts
    root_attempts=$(sudo grep "for root" /var/log/auth.log 2>/dev/null | \
        tail -200 | awk '{for(i=1;i<=NF;i++) if($i=="from") print $(i+1)}' | \
        sort | uniq -c | sort -rn | head -10)
    
    if [[ -n "$root_attempts" ]]; then
        while read -r count ip; do
            if [[ $count -ge 2 && -n "$ip" ]]; then
                attacks+=("SSH_ROOT|$ip|$count|Root attempts")
            fi
        done <<< "$root_attempts"
    fi
    
    # Invalid users (перебор пользователей)
    local invalid_users
    invalid_users=$(sudo grep "Invalid user" /var/log/auth.log 2>/dev/null | \
        tail -200 | awk '{for(i=1;i<=NF;i++) if($i=="from") print $(i+1)}' | \
        sort | uniq -c | sort -rn | head -10)
    
    if [[ -n "$invalid_users" ]]; then
        while read -r count ip; do
            if [[ $count -ge 3 && -n "$ip" ]]; then
                attacks+=("SSH_INVALID_USER|$ip|$count|Invalid user attempts")
            fi
        done <<< "$invalid_users"
    fi
    
    # Возвращаем результаты
    printf '%s\n' "${attacks[@]}"
}

# === МОНИТОРИНГ DNS АТАК ===
monitor_dns_attacks() {
    local attacks=()
    
    # Проверяем логи DNS (systemd-resolved, dnsmasq, bind)
    local dns_queries
    dns_queries=$(sudo journalctl -u systemd-resolved --no-pager -n 1000 2>/dev/null | \
        grep -i "query\|failed" | tail -100)
    
    # DNS amplification detection (множество запросов от одного IP)
    local dns_flood
    dns_flood=$(sudo grep -i "dnsmasq\|named" /var/log/syslog 2>/dev/null | \
        tail -500 | awk '{print $5}' | cut -d'#' -f1 | \
        sort | uniq -c | sort -rn | head -10)
    
    if [[ -n "$dns_flood" ]]; then
        while read -r count ip; do
            if [[ $count -ge 50 && -n "$ip" && "$ip" =~ ^[0-9] ]]; then
                attacks+=("DNS_FLOOD|$ip|$count|DNS query flood")
            fi
        done <<< "$dns_flood"
    fi
    
    # DNS tunneling detection (очень длинные доменные имена)
    local long_domains
    long_domains=$(sudo journalctl -u systemd-resolved --no-pager -n 500 2>/dev/null | \
        grep -oP '[a-zA-Z0-9.-]{50,}\.(com|net|org|ru|cn)' | sort -u | head -10)
    
    if [[ -n "$long_domains" ]]; then
        attacks+=("DNS_TUNNEL|multiple|${#long_domains}|Suspicious long domains detected")
    fi
    
    printf '%s\n' "${attacks[@]}"
}

# === МОНИТОРИНГ DDOS АТАК ===
monitor_ddos_attacks() {
    local attacks=()
    
    # SYN flood detection через netstat
    local syn_recv
    syn_recv=$(sudo netstat -an 2>/dev/null | grep -c SYN_RECV || echo 0)
    
    if [[ $syn_recv -ge 100 ]]; then
        attacks+=("DDOS_SYN|$syn_recv|SYN_RECV connections|Possible SYN flood")
    fi
    
    # Проверка на UDP flood
    local udp_count
    udp_count=$(sudo netstat -anu 2>/dev/null | grep -c udp || echo 0)
    
    if [[ $udp_count -ge 500 ]]; then
        attacks+=("DDOS_UDP|$udp_count|UDP packets|Possible UDP flood")
    fi
    
    # ICMP flood
    local icmp_count
    icmp_count=$(sudo netstat -anp 2>/dev/null | grep -c icmp || echo 0)
    
    if [[ $icmp_count -ge 100 ]]; then
        attacks+=("DDOS_ICMP|$icmp_count|ICMP packets|Possible ICMP flood")
    fi
    
    # Connection flood от одного IP
    local conn_flood
    conn_flood=$(sudo netstat -an 2>/dev/null | awk '{print $5}' | \
        cut -d':' -f1 | sort | uniq -c | sort -rn | head -10)
    
    if [[ -n "$conn_flood" ]]; then
        while read -r count ip; do
            if [[ $count -ge 50 && -n "$ip" && "$ip" =~ ^[0-9] ]]; then
                attacks+=("DDOS_CONN|$ip|$count|Connection flood")
            fi
        done <<< "$conn_flood"
    fi
    
    # Проверка нагрузки на сеть
    local rx_bytes
    rx_bytes=$(cat /sys/class/net/*/statistics/rx_bytes 2>/dev/null | awk '{sum+=$1}END{print sum}')
    local prev_rx_bytes="${PREV_RX_BYTES:-0}"
    
    if [[ $rx_bytes -gt 0 && $prev_rx_bytes -gt 0 ]]; then
        local diff=$((rx_bytes - prev_rx_bytes))
        local mbps=$((diff / 1024 / 1024))
        
        if [[ $mbps -ge 100 ]]; then
            attacks+=("DDOS_BANDWIDTH|$mbps|MB/s|High bandwidth usage")
        fi
    fi
    PREV_RX_BYTES=$rx_bytes
    
    printf '%s\n' "${attacks[@]}"
}

# === МОНИТОРИНГ PORT SCAN ===
monitor_port_scan() {
    local attacks=()
    
    # Сканирование портов через iptables
    local port_scans
    port_scans=$(sudo grep -i "port scan\|SCAN" /var/log/syslog 2>/dev/null | \
        tail -50 | grep -oP '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | \
        sort | uniq -c | sort -rn | head -10)
    
    if [[ -n "$port_scans" ]]; then
        while read -r count ip; do
            if [[ $count -ge 1 && -n "$ip" ]]; then
                attacks+=("PORT_SCAN|$ip|$count|Port scan detected")
            fi
        done <<< "$port_scans"
    fi
    
    # Множественные connection attempts к разным портам
    local multi_port
    multi_port=$(sudo netstat -an 2>/dev/null | grep SYN_RECV | \
        awk '{print $5}' | cut -d':' -f1 | sort | uniq -c | sort -rn | head -10)
    
    if [[ -n "$multi_port" ]]; then
        while read -r count ip; do
            if [[ $count -ge 5 && -n "$ip" && "$ip" =~ ^[0-9] ]]; then
                attacks+=("PORT_SCAN_MULTI|$ip|$count|Multiple ports targeted")
            fi
        done <<< "$multi_port"
    fi
    
    printf '%s\n' "${attacks[@]}"
}

# === МОНИТОРИНГ WEB АТАК ===
monitor_web_attacks() {
    local attacks=()
    
    # Проверяем логи веб-серверов
    if [[ -f /var/log/nginx/access.log ]]; then
        # SQL injection attempts
        local sqli
        sqli=$(sudo grep -iE "union|select|insert|drop|delete|update|exec|script" \
            /var/log/nginx/access.log 2>/dev/null | tail -50 | \
            awk '{print $1}' | sort | uniq -c | sort -rn | head -5)
        
        if [[ -n "$sqli" ]]; then
            while read -r count ip; do
                if [[ $count -ge 3 && -n "$ip" ]]; then
                    attacks+=("WEB_SQLI|$ip|$count|SQL injection attempts")
                fi
            done <<< "$sqli"
        fi
        
        # XSS attempts
        local xss
        xss=$(sudo grep -iE "<script|javascript:|onerror|onload" \
            /var/log/nginx/access.log 2>/dev/null | tail -50 | \
            awk '{print $1}' | sort | uniq -c | sort -rn | head -5)
        
        if [[ -n "$xss" ]]; then
            while read -r count ip; do
                if [[ $count -ge 3 && -n "$ip" ]]; then
                    attacks+=("WEB_XSS|$ip|$count|XSS attempts")
                fi
            done <<< "$xss"
        fi
        
        # Directory traversal
        local traversal
        traversal=$(sudo grep -E "\.\./|\.\.%2f" \
            /var/log/nginx/access.log 2>/dev/null | tail -50 | \
            awk '{print $1}' | sort | uniq -c | sort -rn | head -5)
        
        if [[ -n "$traversal" ]]; then
            while read -r count ip; do
                if [[ $count -ge 3 && -n "$ip" ]]; then
                    attacks+=("WEB_TRAVERSAL|$ip|$count|Directory traversal")
                fi
            done <<< "$traversal"
        fi
    fi
    
    # Apache логи
    if [[ -f /var/log/apache2/access.log ]]; then
        local apache_attacks
        apache_attacks=$(sudo grep -iE "union|select|<script|\.\.\/" \
            /var/log/apache2/access.log 2>/dev/null | tail -50 | \
            awk '{print $1}' | sort | uniq -c | sort -rn | head -5)
        
        if [[ -n "$apache_attacks" ]]; then
            while read -r count ip; do
                if [[ $count -ge 3 && -n "$ip" ]]; then
                    attacks+=("WEB_APACHE|$ip|$count|Web attack attempts")
                fi
            done <<< "$apache_attacks"
        fi
    fi
    
    printf '%s\n' "${attacks[@]}"
}

# === МОНИТОРИНГ BRUTE FORCE НА ДРУГИЕ СЕРВИСЫ ===
monitor_bruteforce_services() {
    local attacks=()
    
    # FTP brute force
    if [[ -f /var/log/vsftpd.log ]]; then
        local ftp_failed
        ftp_failed=$(sudo grep -i "fail\|invalid" /var/log/vsftpd.log 2>/dev/null | \
            tail -100 | awk '{print $4}' | cut -d':' -f1 | \
            sort | uniq -c | sort -rn | head -5)
        
        if [[ -n "$ftp_failed" ]]; then
            while read -r count ip; do
                if [[ $count -ge 5 && -n "$ip" ]]; then
                    attacks+=("FTP_BRUTE|$ip|$count|FTP brute force")
                fi
            done <<< "$ftp_failed"
        fi
    fi
    
    # MySQL/PostgreSQL brute force
    local mysql_failed
    mysql_failed=$(sudo grep -i "access denied\|failed login" /var/log/mysql/error.log 2>/dev/null | \
        tail -100 | grep -oP '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | \
        sort | uniq -c | sort -rn | head -5)
    
    if [[ -n "$mysql_failed" ]]; then
        while read -r count ip; do
            if [[ $count -ge 5 && -n "$ip" ]]; then
                attacks+=("MYSQL_BRUTE|$ip|$count|MySQL brute force")
            fi
        done <<< "$mysql_failed"
    fi
    
    # SMTP brute force
    local smtp_failed
    smtp_failed=$(sudo grep -i "auth fail\|sasl" /var/log/mail.log 2>/dev/null | \
        tail -100 | grep -oP '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | \
        sort | uniq -c | sort -rn | head -5)
    
    if [[ -n "$smtp_failed" ]]; then
        while read -r count ip; do
            if [[ $count -ge 5 && -n "$ip" ]]; then
                attacks+=("SMTP_BRUTE|$ip|$count|SMTP brute force")
            fi
        done <<< "$smtp_failed"
    fi
    
    printf '%s\n' "${attacks[@]}"
}

# === МОНИТОРИНГ ВРЕМЕННЫХ АТАК (TIME-BASED) ===
monitor_time_based_attacks() {
    local attacks=()
    local current_hour=$(date +%H)
    local current_day=$(date +%u)  # 1=Monday, 7=Sunday
    
    # Атаки в нерабочее время (ночью)
    if [[ $current_hour -ge 2 && $current_hour -le 5 ]]; then
        local night_attacks
        night_attacks=$(sudo grep "Failed password" /var/log/auth.log 2>/dev/null | \
            tail -100 | awk '{print $1, $2, $3}' | sort | uniq -c | wc -l)
        
        if [[ $night_attacks -ge 10 ]]; then
            attacks+=("TIME_NIGHT|$night_attacks|Night attack wave|Attacks during 2-5 AM")
        fi
    fi
    
    # Weekend attacks
    if [[ $current_day -ge 6 ]]; then
        local weekend_attacks
        weekend_attacks=$(sudo grep "Failed password" /var/log/auth.log 2>/dev/null | \
            tail -200 | wc -l)
        
        if [[ $weekend_attacks -ge 50 ]]; then
            attacks+=("TIME_WEEKEND|$weekend_attacks|Weekend attack wave")
        fi
    fi
    
    # Rapid succession attacks (много атак за короткое время)
    local last_minute_attacks
    last_minute_attacks=$(sudo grep "Failed password" /var/log/auth.log 2>/dev/null | \
        tail -100 | awk '{print $1, $2}' | uniq | wc -l)
    
    if [[ $last_minute_attacks -ge 20 ]]; then
        attacks+=("TIME_RAPID|$last_minute_attacks|Rapid attack succession")
    fi
    
    printf '%s\n' "${attacks[@]}"
}

# === МОНИТОРИНГ КРИТИЧЕСКИХ ИЗМЕНЕНИЙ В СИСТЕМЕ ===
monitor_system_changes() {
    local attacks=()
    
    # Новые SUID файлы
    local new_suid
    new_suid=$(find /usr /bin /sbin -perm -4000 -type f -mtime -1 2>/dev/null)
    
    if [[ -n "$new_suid" && -n "${PREV_SUID_FILES:-}" ]]; then
        if [[ "$new_suid" != "$PREV_SUID_FILES" ]]; then
            attacks+=("SYSTEM_SUID|CRITICAL|New SUID files detected")
        fi
    fi
    PREV_SUID_FILES="$new_suid"
    
    # Изменения в /etc/passwd и /etc/shadow
    local passwd_changes
    passwd_changes=$(find /etc/passwd /etc/shadow -mmin -5 2>/dev/null)
    
    if [[ -n "$passwd_changes" ]]; then
        attacks+=("SYSTEM_PASSWD|CRITICAL|Password files modified")
    fi
    
    # Новые cron jobs
    local new_cron
    new_cron=$(find /etc/cron.* /var/spool/cron -mmin -10 2>/dev/null)
    
    if [[ -n "$new_cron" ]]; then
        attacks+=("SYSTEM_CRON|HIGH|New cron jobs added")
    fi
    
    # Изменения в iptables
    local iptables_changes
    iptables_changes=$(sudo iptables-save 2>/dev/null | md5sum)
    
    if [[ -n "${PREV_IPTABLES_HASH:-}" && "$iptables_changes" != "$PREV_IPTABLES_HASH" ]]; then
        attacks+=("SYSTEM_IPTABLES|MEDIUM|Firewall rules changed")
    fi
    PREV_IPTABLES_HASH="$iptables_changes"
    
    printf '%s\n' "${attacks[@]}"
}

# === ГЛАВНАЯ ФУНКЦИЯ МОНИТОРИНГА ===
monitor_all_attacks() {
    local all_attacks=()
    
    # Запускаем все мониторинги параллельно
    while IFS= read -r line; do
        [[ -n "$line" ]] && all_attacks+=("$line")
    done < <(monitor_ssh_attacks)
    
    while IFS= read -r line; do
        [[ -n "$line" ]] && all_attacks+=("$line")
    done < <(monitor_dns_attacks)
    
    while IFS= read -r line; do
        [[ -n "$line" ]] && all_attacks+=("$line")
    done < <(monitor_ddos_attacks)
    
    while IFS= read -r line; do
        [[ -n "$line" ]] && all_attacks+=("$line")
    done < <(monitor_port_scan)
    
    while IFS= read -r line; do
        [[ -n "$line" ]] && all_attacks+=("$line")
    done < <(monitor_web_attacks)
    
    while IFS= read -r line; do
        [[ -n "$line" ]] && all_attacks+=("$line")
    done < <(monitor_bruteforce_services)
    
    while IFS= read -r line; do
        [[ -n "$line" ]] && all_attacks+=("$line")
    done < <(monitor_time_based_attacks)
    
    while IFS= read -r line; do
        [[ -n "$line" ]] && all_attacks+=("$line")
    done < <(monitor_system_changes)
    
    # Возвращаем все обнаруженные атаки
    printf '%s\n' "${all_attacks[@]}"
}

# === ТЕСТОВЫЙ ЗАПУСК ===
if [[ "${1:-}" == "test" ]]; then
    echo "=== ЗАПУСК МОНИТОРИНГА ВСЕХ АТАК ==="
    echo ""
    monitor_all_attacks | while IFS='|' read -r type ip count desc; do
        echo "🚨 $type | IP: $ip | Count: $count | $desc"
    done
    echo ""
    echo "=== МОНИТОРИНГ ЗАВЕРШЁН ==="
fi

# === ВЫЗОВ ПО УМОЛЧАНИЮ (для ai_security_v3.sh) ===
# Если скрипт вызван без аргументов или с --monitor, запускаем мониторинг
if [[ $# -eq 0 || "${1:-}" == "--monitor" ]]; then
    monitor_all_attacks
fi
