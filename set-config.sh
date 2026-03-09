#!/bin/bash
#
# Менеджер настроек AI Security System
# Быстрое изменение параметров без редактирования конфигов
#

CONFIG_FILE="/home/larson/security-monitor/ai_config.conf"

echo "╔══════════════════════════════════════════════════════════╗"
echo "║         AI SECURITY - МЕНЕДЖЕР НАСТРОЕК                  ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# Проверка существования конфига
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "❌ Конфигурация не найдена!"
    exit 1
fi

# Загрузка текущих настроек
source "$CONFIG_FILE"

# Текущие значения
echo "━━━ ТЕКУЩИЕ НАСТРОЙКИ ━━━"
echo ""
echo "🛡️ Уровень безопасности: ${SECURITY_LEVEL:-2}"
case ${SECURITY_LEVEL:-2} in
    1) echo "   Режим: МЯГКИЙ (только мониторинг)" ;;
    2) echo "   Режим: СТАНДАРТ (баланс)" ;;
    3) echo "   Режим: АГРЕССИВНЫЙ (быстрые блокировки)" ;;
esac
echo ""
echo "📊 Пороги блокировок:"
echo "   TEMP_BAN: ${MIN_ATTACKS_TEMP_BAN:-3} атак"
echo "   LONG_BAN: ${MIN_ATTACKS_LONG_BAN:-5} атак"
echo "   PERMANENT_BAN: ${MIN_ATTACKS_PERMANENT_BAN:-7} атак"
echo ""
echo "⚙️ Автоматические действия:"
echo "   AUTO_BAN: ${AUTO_BAN_ENABLED:-true}"
echo "   SUBNET_BAN: ${AUTO_SUBNET_BAN:-true}"
echo "   PERMANENT_BAN: ${AUTO_PERMANENT_BAN:-true}"
echo ""

# Меню
echo "━━━ МЕНЮ ━━━"
echo ""
echo "1. Изменить уровень безопасности"
echo "2. Изменить порог PERMANENT_BAN"
echo "3. Изменить порог LONG_BAN"
echo "4. Изменить порог TEMP_BAN"
echo "5. Включить/выключить AUTO_BAN"
echo "6. Сбросить настройки по умолчанию"
echo "7. Применить пресет"
echo "8. Выход"
echo ""

read -p "Выберите действие (1-8): " choice

case $choice in
    1)
        echo ""
        echo "Выберите уровень безопасности:"
        echo "1. МЯГКИЙ (только мониторинг)"
        echo "2. СТАНДАРТ (рекомендуется)"
        echo "3. АГРЕССИВНЫЙ (максимальная защита)"
        read -p "Уровень (1-3): " level
        
        case $level in
            1)
                sed -i 's/^SECURITY_LEVEL=.*/SECURITY_LEVEL=1/' "$CONFIG_FILE"
                echo "✅ Установлен МЯГКИЙ режим"
                ;;
            2)
                sed -i 's/^SECURITY_LEVEL=.*/SECURITY_LEVEL=2/' "$CONFIG_FILE"
                echo "✅ Установлен СТАНДАРТНЫЙ режим"
                ;;
            3)
                sed -i 's/^SECURITY_LEVEL=.*/SECURITY_LEVEL=3/' "$CONFIG_FILE"
                echo "✅ Установлен АГРЕССИВНЫЙ режим"
                ;;
            *)
                echo "❌ Неверный выбор"
                ;;
        esac
        ;;
    
    2)
        read -p "Введите минимальное количество атак для PERMANENT_BAN (сейчас: ${MIN_ATTACKS_PERMANENT_BAN:-7}): " new_value
        if [[ "$new_value" =~ ^[0-9]+$ ]]; then
            sed -i "s/^MIN_ATTACKS_PERMANENT_BAN=.*/MIN_ATTACKS_PERMANENT_BAN=$new_value/" "$CONFIG_FILE"
            echo "✅ PERMANENT_BAN установлен на $new_value атак"
        else
            echo "❌ Неверное значение"
        fi
        ;;
    
    3)
        read -p "Введите минимальное количество атак для LONG_BAN (сейчас: ${MIN_ATTACKS_LONG_BAN:-5}): " new_value
        if [[ "$new_value" =~ ^[0-9]+$ ]]; then
            sed -i "s/^MIN_ATTACKS_LONG_BAN=.*/MIN_ATTACKS_LONG_BAN=$new_value/" "$CONFIG_FILE"
            echo "✅ LONG_BAN установлен на $new_value атак"
        else
            echo "❌ Неверное значение"
        fi
        ;;
    
    4)
        read -p "Введите минимальное количество атак для TEMP_BAN (сейчас: ${MIN_ATTACKS_TEMP_BAN:-3}): " new_value
        if [[ "$new_value" =~ ^[0-9]+$ ]]; then
            sed -i "s/^MIN_ATTACKS_TEMP_BAN=.*/MIN_ATTACKS_TEMP_BAN=$new_value/" "$CONFIG_FILE"
            echo "✅ TEMP_BAN установлен на $new_value атак"
        else
            echo "❌ Неверное значение"
        fi
        ;;
    
    5)
        if [[ "${AUTO_BAN_ENABLED:-true}" == "true" ]]; then
            sed -i 's/^AUTO_BAN_ENABLED=.*/AUTO_BAN_ENABLED=false/' "$CONFIG_FILE"
            echo "✅ AUTO_BAN ОТКЛЮЧЕН"
        else
            sed -i 's/^AUTO_BAN_ENABLED=.*/AUTO_BAN_ENABLED=true/' "$CONFIG_FILE"
            echo "✅ AUTO_BAN ВКЛЮЧЕН"
        fi
        ;;
    
    6)
        read -p "Сбросить все настройки по умолчанию? (y/n): " confirm
        if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
            cat > "$CONFIG_FILE" << 'EOF'
#!/bin/bash
#
# Конфигурация AI Security System v3.1
#

BOT_TOKEN=""
CHAT_ID=""

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

MIN_ATTACKS_TEMP_BAN=3
MIN_ATTACKS_LONG_BAN=5
MIN_ATTACKS_PERMANENT_BAN=7

DURATION_TEMP_BAN=600
DURATION_LONG_BAN=86400
DURATION_PERMANENT=0

AUTO_BAN_ENABLED=true
AUTO_SUBNET_BAN=true
AUTO_PERMANENT_BAN=true
AUTO_REPORT_THREATS=true

SECURITY_LEVEL=2

BAN_SSH_ROOT=true
BAN_SSH_BRUTEFORCE=true
BAN_DDOS=true
BAN_PORT_SCAN=true
BAN_WEB_ATTACKS=true

SUBNET_BAN_THRESHOLD=3

MAX_IPTABLES_RULES=1000
MAX_STATE_SIZE_MB=100
CLEANUP_OLD_RULES_HOURS=24

NOTIFY_ON_LOW=false
NOTIFY_ON_MEDIUM=true
NOTIFY_ON_HIGH=true
NOTIFY_ON_CRITICAL=true
NOTIFY_HOURLY=true
NOTIFY_PREDICTION=true
NOTIFY_PERMANENT_BAN=true
EOF
            echo "✅ Настройки сброшены"
        fi
        ;;
    
    7)
        echo ""
        echo "Выберите пресет:"
        echo "1. МЯГКИЙ (только мониторинг)"
        echo "2. СТАНДАРТ (баланс)"
        echo "3. АГРЕССИВНЫЙ (максимальная защита)"
        read -p "Пресет (1-3): " preset
        
        case $preset in
            1)
                sed -i 's/^SECURITY_LEVEL=.*/SECURITY_LEVEL=1/' "$CONFIG_FILE"
                sed -i 's/^MIN_ATTACKS_PERMANENT_BAN=.*/MIN_ATTACKS_PERMANENT_BAN=20/' "$CONFIG_FILE"
                sed -i 's/^AUTO_BAN_ENABLED=.*/AUTO_BAN_ENABLED=false/' "$CONFIG_FILE"
                echo "✅ Применён МЯГКИЙ пресет"
                ;;
            2)
                sed -i 's/^SECURITY_LEVEL=.*/SECURITY_LEVEL=2/' "$CONFIG_FILE"
                sed -i 's/^MIN_ATTACKS_PERMANENT_BAN=.*/MIN_ATTACKS_PERMANENT_BAN=7/' "$CONFIG_FILE"
                sed -i 's/^AUTO_BAN_ENABLED=.*/AUTO_BAN_ENABLED=true/' "$CONFIG_FILE"
                echo "✅ Применён СТАНДАРТНЫЙ пресет"
                ;;
            3)
                sed -i 's/^SECURITY_LEVEL=.*/SECURITY_LEVEL=3/' "$CONFIG_FILE"
                sed -i 's/^MIN_ATTACKS_PERMANENT_BAN=.*/MIN_ATTACKS_PERMANENT_BAN=5/' "$CONFIG_FILE"
                sed -i 's/^AUTO_BAN_ENABLED=.*/AUTO_BAN_ENABLED=true/' "$CONFIG_FILE"
                echo "✅ Применён АГРЕССИВНЫЙ пресет"
                ;;
            *)
                echo "❌ Неверный выбор"
                ;;
        esac
        ;;
    
    8)
        echo "Выход"
        exit 0
        ;;
    
    *)
        echo "❌ Неверный выбор"
        exit 1
        ;;
esac

echo ""
echo "━━━ ПРИМЕНЕНИЕ ИЗМЕНЕНИЙ ━━━"
echo ""

# Перезапуск службы
read -p "Перезапустить AI Security для применения изменений? (y/n): " restart

if [[ "$restart" == "y" || "$restart" == "Y" ]]; then
    echo "Остановка службы..."
    pkill -f "ai_security_v3.sh"
    sleep 2
    
    echo "Запуск службы..."
    nohup /home/larson/security-monitor/ai_security_v3.sh > /dev/null 2>&1 &
    sleep 3
    
    if pgrep -f "ai_security_v3" > /dev/null; then
        echo "✅ Служба перезапущена"
    else
        echo "❌ Ошибка запуска службы"
    fi
else
    echo "⚠️ Изменения применятся после перезапуска службы"
    echo "Для перезапуска: pkill -f ai_security_v3 && nohup ~/security-monitor/ai_security_v3.sh > /dev/null 2>&1 &"
fi

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║                    ГОТОВО!                               ║"
echo "╚══════════════════════════════════════════════════════════╝"
