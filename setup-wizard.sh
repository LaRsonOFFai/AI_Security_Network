#!/bin/bash
#
# AI Security Setup Wizard
# Интерактивный мастер настройки безопасности
#

set -e

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
CONFIG_FILE="${SCRIPT_DIR}/ai_config.conf"
WHITELIST_FILE="${SCRIPT_DIR}/whitelist.txt"

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Функции для вывода
print_header() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║  $1"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_step() {
    echo -e "${BLUE}━━━ $1 ━━━${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Заголовок
print_header "AI SECURITY SETUP WIZARD v1.0"
echo "Этот мастер поможет настроить оптимальную безопасность"
echo "вашего сервера на основе анализа и ваших потребностей."
echo ""

read -p "Продолжить? (y/n): " continue_setup
if [[ "$continue_setup" != "y" && "$continue_setup" != "Y" ]]; then
    echo "Установка отменена"
    exit 0
fi

# === ШАГ 1: АНАЛИЗ СИСТЕМЫ ===
print_header "ШАГ 1: АНАЛИЗ СИСТЕМЫ"

print_step "Сканирование открытых портов..."

# Получаем открытые порты
open_ports=$(sudo ss -tuln 2>/dev/null | grep LISTEN | awk '{print $5}' | grep -oE '[0-9]+$' | sort -n | uniq)

echo ""
echo "Открытые порты:"
echo "$open_ports" | while read port; do
    if [[ -n "$port" ]]; then
        # Определяем службу
        case $port in
            22) service="SSH" ;;
            80) service="HTTP" ;;
            443) service="HTTPS" ;;
            3306) service="MySQL" ;;
            5432) service="PostgreSQL" ;;
            6379) service="Redis" ;;
            8080) service="HTTP-ALT" ;;
            *) service="Unknown" ;;
        esac
        echo "   • Порт $port ($service)"
    fi
done

# Считаем количество портов
port_count=$(echo "$open_ports" | grep -c "[0-9]" || echo 0)
echo ""
echo "Всего открытых портов: $port_count"

# Проверка SSH
if echo "$open_ports" | grep -q "^22$"; then
    print_success "SSH активен (порт 22)"
else
    print_warning "SSH не найден или работает на нестандартном порту"
fi

# Проверка веб-сервера
if echo "$open_ports" | grep -qE "^(80|443|8080)$"; then
    print_success "Веб-сервер обнаружен"
fi

echo ""
read -p "Нажмите Enter для продолжения..."

# === ШАГ 2: ТИП СЕРВЕРА ===
print_header "ШАГ 2: ТИП СЕРВЕРА"

echo "Выберите тип вашего сервера:"
echo ""
echo "1. 🌐 Веб-сервер (сайт, блог, интернет-магазин)"
echo "2. 🔧 Сервер приложений (Node.js, Python, Java)"
echo "3. 💾 База данных (MySQL, PostgreSQL, MongoDB)"
echo "4. 📁 Файловый сервер (FTP, SFTP, Nextcloud)"
echo "5. 🎮 Игровой сервер (Minecraft, CS:GO, др.)"
echo "6. 📧 Почтовый сервер (SMTP, IMAP, POP3)"
echo "7. 🔬 Разработка/Тестирование"
echo "8. ⚙️ Другое"
echo ""

read -p "Выберите тип сервера (1-8): " server_type

case $server_type in
    1)
        server_type_name="WEB_SERVER"
        print_warning "Веб-сервер требует открытия портов 80, 443"
        ;;
    2)
        server_type_name="APP_SERVER"
        print_warning "Сервер приложений может требовать дополнительные порты"
        ;;
    3)
        server_type_name="DATABASE_SERVER"
        print_warning "Базы данных должны быть защищены от внешнего доступа!"
        ;;
    4)
        server_type_name="FILE_SERVER"
        ;;
    5)
        server_type_name="GAME_SERVER"
        print_warning "Игровые серверы часто подвергаются DDoS-атакам"
        ;;
    6)
        server_type_name="MAIL_SERVER"
        print_warning "Почтовые серверы требуют особой настройки"
        ;;
    7)
        server_type_name="DEV_SERVER"
        print_warning "Режим разработки - более мягкие настройки"
        ;;
    8)
        server_type_name="OTHER"
        ;;
    *)
        server_type_name="UNKNOWN"
        ;;
esac

echo ""

# === ШАГ 3: КРИТИЧНОСТЬ ДАННЫХ ===
print_header "ШАГ 3: УРОВЕНЬ БЕЗОПАСНОСТИ"

echo "Выберите желаемый уровень безопасности:"
echo ""
echo "1. 🟢 МЯГКИЙ"
echo "   - Минимум блокировок"
echo "   - Подходит для разработки"
echo "   - Может пропустить некоторые атаки"
echo ""
echo "2. 🟡 СТАНДАРТНЫЙ (рекомендуется)"
echo "   - Баланс между защитой и доступностью"
echo "   - Подходит для большинства серверов"
echo "   - Оптимальные настройки"
echo ""
echo "3. 🔴 АГРЕССИВНЫЙ"
echo "   - Максимальная защита"
echo "   - Быстрые блокировки"
echo "   - Возможны ложные срабатывания"
echo ""

read -p "Выберите уровень (1-3): " security_level

case $security_level in
    1)
        security_level_num=1
        security_level_name="МЯГКИЙ"
        ;;
    2)
        security_level_num=2
        security_level_name="СТАНДАРТНЫЙ"
        ;;
    3)
        security_level_num=3
        security_level_name="АГРЕССИВНЫЙ"
        ;;
    *)
        security_level_num=2
        security_level_name="СТАНДАРТНЫЙ"
        ;;
esac

print_success "Выбран уровень: $security_level_name"
echo ""

# === ШАГ 4: ДОСТУПНЫЕ ПОРТА ===
print_header "ШАГ 4: КАКИЕ ПОРТЫ ОТКРЫТЬ?"

echo ""
echo "Текущие открытые порты: $port_count"
echo ""
echo "Рекомендуемые порты для вашего типа сервера:"

case $server_type_name in
    WEB_SERVER)
        echo "   • 22 (SSH) - управление"
        echo "   • 80 (HTTP) - веб-трафик"
        echo "   • 443 (HTTPS) - защищённый веб-трафик"
        recommended_ports="22,80,443"
        ;;
    APP_SERVER)
        echo "   • 22 (SSH) - управление"
        echo "   • 8080 (HTTP-ALT) - приложение"
        echo "   • 443 (HTTPS) - если есть SSL"
        recommended_ports="22,8080,443"
        ;;
    DATABASE_SERVER)
        echo "   • 22 (SSH) - управление"
        echo "   • 3306/5432 (БД) - ТОЛЬКО изнутри!"
        recommended_ports="22"
        print_warning "Порт БД не должен быть открыт наружу!"
        ;;
    GAME_SERVER)
        echo "   • 22 (SSH) - управление"
        echo "   • 25565 (Minecraft) или другой порт игры"
        recommended_ports="22,25565"
        ;;
    *)
        echo "   • 22 (SSH) - управление"
        recommended_ports="22"
        ;;
esac

echo ""
read -p "Нужно ли открыть дополнительные порты? (y/n): " open_more_ports

if [[ "$open_more_ports" == "y" || "$open_more_ports" == "Y" ]]; then
    read -p "Введите номера портов через запятую: " custom_ports
    recommended_ports="$recommended_ports,$custom_ports"
fi

echo ""

# === ШАГ 5: БЕЛЫЙ СПИСОК ===
print_header "ШАГ 5: БЕЛЫЙ СПИСОК IP"

echo ""
echo "Хотите настроить белый список доверенных IP?"
echo "Это защитит ваши постоянные адреса от случайной блокировки."
echo ""

read -p "Настроить whitelist? (y/n): " setup_whitelist

whitelist_ips=""

if [[ "$setup_whitelist" == "y" || "$setup_whitelist" == "Y" ]]; then
    echo ""
    echo "Введите IP адреса для белого списка (по одному):"
    echo "Нажмите Enter без ввода для завершения"
    echo ""
    
    ip_count=0
    while true; do
        read -p "IP #$((ip_count + 1)): " ip
        
        if [[ -z "$ip" ]]; then
            break
        fi
        
        # Проверка формата IP
        if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            whitelist_ips="$whitelist_ips$ip,"
            ip_count=$((ip_count + 1))
            print_success "Добавлен: $ip"
        else
            print_error "Неверный формат IP"
        fi
    done
    
    print_success "Добавлено IP в whitelist: $ip_count"
else
    print_warning "Whitelist отключён"
fi

echo ""

# === ШАГ 6: МГНОВЕННЫЙ БАН ===
print_header "ШАГ 6: МГНОВЕННЫЙ БАН"

echo ""
echo "Мгновенная блокировка при массовых атаках:"
echo ""
echo "Рекомендуемые настройки для вашего уровня:"

case $security_level_num in
    1)
        instant_threshold=20
        echo "   • МЯГКИЙ: бан при 20+ попыток"
        ;;
    2)
        instant_threshold=15
        echo "   • СТАНДАРТНЫЙ: бан при 15+ попыток"
        ;;
    3)
        instant_threshold=10
        echo "   • АГРЕССИВНЫЙ: бан при 10+ попыток"
        ;;
esac

echo ""
read -p "Порог мгновенного бана ([$instant_threshold]): " custom_threshold
if [[ -n "$custom_threshold" && "$custom_threshold" =~ ^[0-9]+$ ]]; then
    instant_threshold=$custom_threshold
fi

read -p "Включить мгновенный бан? (y/n): " enable_instant
if [[ "$enable_instant" == "y" || "$enable_instant" == "Y" ]]; then
    instant_enabled="true"
else
    instant_enabled="false"
fi

print_success "Мгновенный бан: $instant_enabled (порог: $instant_threshold)"
echo ""

# === ШАГ 7: УВЕДОМЛЕНИЯ ===
print_header "ШАГ 7: TELEGRAM УВЕДОМЛЕНИЯ"

echo ""
echo "Хотите получать уведомления в Telegram?"
echo ""

read -p "Включить уведомления? (y/n): " enable_notifications

if [[ "$enable_notifications" == "y" || "$enable_notifications" == "Y" ]]; then
    echo ""
    echo "Выберите типы уведомлений:"
    read -p "• Средний уровень угрозы? (y/n): " notify_medium
    read -p "• Высокий уровень угрозы? (y/n): " notify_high
    read -p "• Критический уровень? (y/n): " notify_critical
    read -p "• Ежечасные отчёты? (y/n): " notify_hourly
    
    notify_medium_val=$([[ "$notify_medium" == "y" ]] && echo "true" || echo "false")
    notify_high_val=$([[ "$notify_high" == "y" ]] && echo "true" || echo "false")
    notify_critical_val=$([[ "$notify_critical" == "y" ]] && echo "true" || echo "false")
    notify_hourly_val=$([[ "$notify_hourly" == "y" ]] && echo "true" || echo "false")
else
    notify_medium_val="false"
    notify_high_val="true"
    notify_critical_val="true"
    notify_hourly_val="false"
fi

echo ""

# === ШАГ 8: ПРИМЕНЕНИЕ НАСТРОЕК ===
print_header "ШАГ 8: ПРИМЕНЕНИЕ НАСТРОЕК"

echo ""
echo "📊 ИТОГОВАЯ КОНФИГУРАЦИЯ:"
echo ""
echo "Тип сервера: $server_type_name"
echo "Уровень безопасности: $security_level_name ($security_level_num)"
echo "Мгновенный бан: $instant_enabled (порог: $instant_threshold)"
echo "Whitelist IP: ${whitelist_ips:-Нет}"
echo "Уведомления: ${enable_notifications:-Нет}"
echo ""

read -p "Применить настройки? (y/n): " apply_config

if [[ "$apply_config" == "y" || "$apply_config" == "Y" ]]; then
    print_step "Сохранение конфигурации..."
    
    # Создаём резервную копию
    if [[ -f "$CONFIG_FILE" ]]; then
        cp "$CONFIG_FILE" "${CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
        print_success "Резервная копия сохранена"
    fi
    
    # Обновляем конфиг
    cat > "$CONFIG_FILE" << EOF
#!/bin/bash
#
# AI Security System v3.2
# Конфигурация от $(date '+%Y-%m-%d %H:%M:%S')
# Тип сервера: $server_type_name
#

# Telegram конфигурация
BOT_TOKEN=""
CHAT_ID=""

# === НАСТРОЙКИ ИИ ===
THRESHOLD_LOW=20
THRESHOLD_MEDIUM=40
THRESHOLD_HIGH=60
THRESHOLD_CRITICAL=70

WEIGHT_FAILED_LOGIN=10
WEIGHT_ROOT_ATTEMPT=25
WEIGHT_BRUTE_FORCE=30
WEIGHT_PORT_SCAN=15
WEIGHT_GEO_RISK=10
WEIGHT_TIME_ANOMALY=10
WEIGHT_RAPID_ATTACK=20

GEO_RISK_CHINA=30
GEO_RISK_RUSSIA=25
GEO_RISK_NORTH_KOREA=40
GEO_RISK_IRAN=35
GEO_RISK_DEFAULT=10

WINDOW_ANALYSIS=10
WINDOW_SAVE=600
WINDOW_REPORT=3600

# === НАСТРОЙКИ БЛОКИРОВОК ===
MIN_ATTACKS_TEMP_BAN=3
MIN_ATTACKS_LONG_BAN=5
MIN_ATTACKS_PERMANENT_BAN=7

INSTANT_PERMANENT_THRESHOLD=$instant_threshold
INSTANT_PERMANENT_ENABLED=$instant_enabled

DURATION_TEMP_BAN=600
DURATION_LONG_BAN=86400
DURATION_PERMANENT=0

# === БЕЛЫЙ СПИСОК ===
WHITELIST_ENABLED=true
WHITELIST_MIN_CONNECTIONS=5
WHITELIST_CHECK_WINDOW=86400
WHITELIST_AUTO_ADD=true
WHITELIST_PROTECT_FROM_BAN=true
WHITELIST_FILE="\${SCRIPT_DIR}/whitelist.txt"
WHITELIST_LEARN_FILE="\${SCRIPT_DIR}/whitelist_learning.dat"
MAX_WHITELIST_ENTRIES=500

# === АВТОМАТИЧЕСКИЕ ДЕЙСТВИЯ ===
AUTO_BAN_ENABLED=true
AUTO_SUBNET_BAN=true
AUTO_PERMANENT_BAN=true
AUTO_REPORT_THREATS=true

# === ПРОДВИНУТЫЕ НАСТРОЙКИ ===
SECURITY_LEVEL=$security_level_num

BAN_SSH_ROOT=true
BAN_SSH_BRUTEFORCE=true
BAN_DDOS=true
BAN_PORT_SCAN=true
BAN_WEB_ATTACKS=true

SUBNET_BAN_THRESHOLD=3

MAX_IPTABLES_RULES=1000
MAX_STATE_SIZE_MB=100
CLEANUP_OLD_RULES_HOURS=24

# === УВЕДОМЛЕНИЯ ===
NOTIFY_ON_LOW=false
NOTIFY_ON_MEDIUM=$notify_medium_val
NOTIFY_ON_HIGH=$notify_high_val
NOTIFY_ON_CRITICAL=$notify_critical_val
NOTIFY_HOURLY=$notify_hourly_val
NOTIFY_PREDICTION=true
NOTIFY_PERMANENT_BAN=true
EOF

    print_success "Конфигурация сохранена"
    
    # Добавляем IP в whitelist
    if [[ -n "$whitelist_ips" ]]; then
        print_step "Настройка whitelist..."
        
        touch "$WHITELIST_FILE"
        
        IFS=',' read -ra IPS <<< "$whitelist_ips"
        for ip in "${IPS[@]}"; do
            if [[ -n "$ip" && ! grep -q "^$ip" "$WHITELIST_FILE" ]]; then
                echo "$ip # $(date '+%Y-%m-%d %H:%M:%S') Added by Setup Wizard" >> "$WHITELIST_FILE"
            fi
        done
        
        print_success "Whitelist настроен"
    fi
    
    # Перезапуск службы
    print_step "Перезапуск службы..."
    
    pkill -f "ai_security_v3.sh" 2>/dev/null || true
    sleep 2
    
    nohup "$SCRIPT_DIR/ai_security_v3.sh" > /dev/null 2>&1 &
    sleep 3
    
    if pgrep -f "ai_security_v3" > /dev/null; then
        print_success "Служба перезапущена"
    else
        print_error "Ошибка запуска службы"
    fi
    
    echo ""
    print_header "НАСТРОЙКА ЗАВЕРШЕНА!"
    
    echo ""
    echo "✅ Конфигурация применена"
    echo "✅ Служба перезапущена"
    echo "✅ Whitelist настроен"
    echo ""
    echo "📁 Файлы:"
    echo "   • Конфигурация: $CONFIG_FILE"
    echo "   • Whitelist: $WHITELIST_FILE"
    echo "   • Логи: $SCRIPT_DIR/ai_security.log"
    echo ""
    echo "📊 Проверка статуса:"
    echo "   $SCRIPT_DIR/check-today.sh"
    echo ""
    echo "🔧 Изменить настройки:"
    echo "   $SCRIPT_DIR/set-config.sh"
    echo ""
    
else
    print_warning "Настройки не применены"
    echo "Вы можете запустить мастер позже:"
    echo "   $SCRIPT_DIR/setup-wizard.sh"
fi

echo ""
echo "Спасибо за использование AI Security Setup Wizard!"
echo ""
