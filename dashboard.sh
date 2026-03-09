#!/bin/bash
#
# Dashboard для мониторинга AI Security System
#

SCRIPT_DIR="/home/larson/security-monitor"

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Функция для отображения статуса
show_status() {
    clear
    
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}       🧠 ${PURPLE}AI SECURITY SYSTEM DASHBOARD${NC} ${CYAN}            ║${NC}"
    echo -e "${CYAN}║${NC}          $(date '+%Y-%m-%d %H:%M:%S')                        ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Статус службы
    echo -e "${YELLOW}📊 СТАТУС СЛУЖБЫ:${NC}"
    if sudo systemctl is-active --quiet ai-security-v3; then
        echo -e "   AI Security v3: ${GREEN}● Активна${NC}"
    else
        echo -e "   AI Security v3: ${RED}● Остановлена${NC}"
    fi
    
    if sudo systemctl is-active --quiet fail2ban; then
        echo -e "   Fail2Ban:    ${GREEN}● Активна${NC}"
    else
        echo -e "   Fail2Ban:    ${YELLOW}● Остановлена${NC}"
    fi
    echo ""
    
    # Статистика угроз
    echo -e "${YELLOW}📈 СТАТИСТИКА УГРОЗ:${NC}"
    if [[ -f "$SCRIPT_DIR/threat_database.dat" ]]; then
        total_threats=$(wc -l < "$SCRIPT_DIR/threat_database.dat" 2>/dev/null || echo 0)
        echo -e "   Всего угроз: ${RED}${total_threats}${NC}"
        
        today_threats=$(grep "$(date '+%Y-%m-%d')" "$SCRIPT_DIR/threat_database.dat" 2>/dev/null | wc -l || echo 0)
        echo -e "   За сегодня:  ${RED}${today_threats}${NC}"
        
        # По уровням
        critical=$(grep "|4|" "$SCRIPT_DIR/threat_database.dat" 2>/dev/null | wc -l || echo 0)
        high=$(grep "|3|" "$SCRIPT_DIR/threat_database.dat" 2>/dev/null | wc -l || echo 0)
        medium=$(grep "|2|" "$SCRIPT_DIR/threat_database.dat" 2>/dev/null | wc -l || echo 0)
        low=$(grep "|1|" "$SCRIPT_DIR/threat_database.dat" 2>/dev/null | wc -l || echo 0)
        
        echo ""
        echo -e "   Критические: ${RED}${critical}${NC}"
        echo -e "   Высокие:     ${RED}${high}${NC}"
        echo -e "   Средние:     ${YELLOW}${medium}${NC}"
        echo -e "   Низкие:      ${GREEN}${low}${NC}"
    fi
    echo ""
    
    # Активные блокировки
    echo -e "${YELLOW}🛡️ АКТИВНЫЕ БЛОКИРОВКИ:${NC}"
    total_blocked=$(sudo iptables -L INPUT -n 2>/dev/null | grep -c "AI_" || echo 0)
    echo -e "   Всего: ${RED}${total_blocked}${NC}"
    
    perm_banned=$(sudo iptables -L INPUT -n 2>/dev/null | grep -c "AI_PERM_BAN" || echo 0)
    long_banned=$(sudo iptables -L INPUT -n 2>/dev/null | grep -c "AI_LONG_BAN" || echo 0)
    temp_banned=$(sudo iptables -L INPUT -n 2>/dev/null | grep -c "AI_TEMP_BAN" || echo 0)
    subnet_banned=$(sudo iptables -L INPUT -n 2>/dev/null | grep -c "AI_SUBNET_BAN" || echo 0)
    
    echo -e "   Перманентные: ${RED}${perm_banned}${NC}"
    echo -e "   Длительные:   ${RED}${long_banned}${NC}"
    echo -e "   Временные:    ${YELLOW}${temp_banned}${NC}"
    echo -e "   Подсети:      ${PURPLE}${subnet_banned}${NC}"
    echo ""
    
    # Топ атакующих
    echo -e "${YELLOW}🎯 ТОП АТАКУЮЩИХ (за сегодня):${NC}"
    if [[ -f "$SCRIPT_DIR/threat_database.dat" ]]; then
        grep "$(date '+%Y-%m-%d')" "$SCRIPT_DIR/threat_database.dat" 2>/dev/null | \
            cut -d'|' -f2 | sort | uniq -c | sort -rn | head -5 | \
            while read -r count ip; do
                if [[ -n "$ip" ]]; then
                    printf "   %-20s %s раз\n" "$ip" "$count"
                fi
            done
    fi
    echo ""
    
    # Распознанные паттерны
    echo -e "${YELLOW}🔍 РАСПОЗНАННЫЕ ПАТТЕРНЫ:${NC}"
    if [[ -f "$SCRIPT_DIR/threat_database.dat" ]]; then
        grep "$(date '+%Y-%m-%d')" "$SCRIPT_DIR/threat_database.dat" 2>/dev/null | \
            cut -d'|' -f5 | sort | uniq -c | sort -rn | head -5 | \
            while read -r count pattern; do
                if [[ -n "$pattern" ]]; then
                    printf "   %-25s %s\n" "$pattern" "$count"
                fi
            done
    fi
    echo ""
    
    # Последние события
    echo -e "${YELLOW}📋 ПОСЛЕДНИЕ СОБЫТИЯ:${NC}"
    if [[ -f "$SCRIPT_DIR/ai_security.log" ]]; then
        tail -10 "$SCRIPT_DIR/ai_security.log" | while read -r line; do
            if echo "$line" | grep -q "CRITICAL\|HIGH"; then
                echo -e "   ${RED}${line}${NC}"
            elif echo "$line" | grep -q "MEDIUM"; then
                echo -e "   ${YELLOW}${line}${NC}"
            else
                echo -e "   ${GREEN}${line}${NC}"
            fi
        done
    fi
    echo ""
    
    # Fail2Ban статус
    echo -e "${YELLOW}📊 FAIL2BAN СТАТУС:${NC}"
    sudo fail2ban-client status sshd 2>/dev/null | grep -E "Currently banned|Total banned" | while read -r line; do
        echo -e "   $line"
    done
    echo ""
    
    # Загрузка системы
    echo -e "${YELLOW}💻 ЗАГРУЗКА СИСТЕМЫ:${NC}"
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    mem_usage=$(free -m | awk 'NR==2{printf "%.2f%%", $3*100/$2}')
    echo -e "   CPU: ${cpu_usage}%  Memory: ${mem_usage}%"
    echo ""
    
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}Обновление: каждые 5 секунд (Ctrl+C для выхода)${NC}"
}

# Основной цикл
while true; do
    show_status
    sleep 5
done
