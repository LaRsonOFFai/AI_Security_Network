# 🛡️ AI Security System v3.0

Интеллектуальная система защиты сервера с адаптивным реагированием и машинным обучением.

## 🚀 Возможности

### Обнаружение атак в реальном времени
- **SSH атаки**: Brute Force, root attempts, credential stuffing
- **DDoS атаки**: SYN/UDP/ICMP flood, bandwidth overload
- **Web атаки**: SQL Injection, XSS, Directory Traversal
- **Сканирование портов**: Multi-port scanning
- **DNS атаки**: DNS flood, DNS tunneling
- **Системные изменения**: /etc/passwd, cron, iptables

### Автоматические блокировки
- **MONITOR** - наблюдение за подозрительными IP
- **TEMP_BAN** - временная блокировка на 10 минут
- **LONG_BAN** - длительная блокировка на 24 часа
- **PERMANENT_BAN** - перманентная блокировка

### Машинное обучение
- Анализ эффективности блокировок
- Адаптивные пороги срабатывания
- Распознавание паттернов атак
- Прогнозирование следующих целей

### Telegram уведомления
- Мгновенные оповещения о блокировках
- Ежечасные отчёты
- Прогнозы атак
- Статус системы

## 📋 Установка

### Требования
- Ubuntu/Debian сервер
- root доступ
- Telegram Bot Token
- fail2ban (опционально)

### Быстрая установка

```bash
# Клонируйте репозиторий
git clone https://github.com/YOUR_USERNAME/security-monitor.git
cd security-monitor

# Запустите установку
bash install.sh
```

### Настройка Telegram

1. Создайте бота через [@BotFather](https://t.me/BotFather)
2. Получите токен бота
3. Узнайте свой Chat ID через [@userinfobot](https://t.me/userinfobot)
4. Отредактируйте `tg_config.conf`:

```bash
BOT_TOKEN=your_bot_token_here
CHAT_ID=your_chat_id_here
```

## 📊 Использование

### Запуск системы

```bash
# Запустить AI Security
nohup ./ai_security_v3.sh > /dev/null 2>&1 &

# Проверить статус
ps aux | grep ai_security
```

### Просмотр статистики

```bash
# Быстрые блокировки за сегодня
./blocked-today.sh

# Полный отчёт
./check-today.sh

# Лог в реальном времени
tail -f ai_security.log
```

### Команды мониторинга

```bash
# Проверить активные блокировки
sudo iptables -L INPUT -n | grep AI_

# Посмотреть базу угроз
cat threat_database.dat | tail -20

# Проверить обучение
cat learning_database.dat | tail -10
```

## 📁 Структура проекта

```
security-monitor/
├── ai_security_v3.sh      # Основной скрипт защиты
├── attack_monitor.sh      # Мониторинг атак
├── ai_config.conf         # Конфигурация ИИ
├── tg_config.conf         # Telegram настройки
├── check-today.sh         # Диагностика
├── blocked-today.sh       # Быстрые блокировки
├── install.sh             # Установка
├── dashboard.sh           # Web дашборд
├── USER_GUIDE.md          # Руководство пользователя
├── README.md              # Этот файл
└── .gitignore             # Git ignore
```

## 🎯 Типы обнаруживаемых атак

| Тип атаки | Описание | Порог |
|-----------|----------|-------|
| SSH | Неудачные логины | 3+ попытки |
| SSH_ROOT | Вход под root | 2+ попытки |
| SSH_INVALID_USER | Перебор пользователей | 3+ попытки |
| DDOS_SYN | SYN flood | 100+ пакетов |
| DDOS_UDP | UDP flood | 100+ пакетов |
| PORT_SCAN | Сканирование портов | 10+ портов |
| WEB_SQLI | SQL injection | 1+ попытка |
| WEB_XSS | XSS атака | 1+ попытка |

## 🧠 Как работает ИИ

### Расчёт уровня угрозы

Система оценивает каждый IP по множеству факторов:

1. **Репутация IP** (0-100)
2. **История атак** (количество предыдущих атак)
3. **Геолокация** (риск страны)
4. **Время атаки** (ночные атаки подозрительнее)
5. **Частота** (быстрые серии опаснее)
6. **Попытки root** (дополнительный вес)
7. **Множество пользователей** (credential stuffing)

### Адаптивный ответ

На основе уровня угрозы система выбирает ответ:

- **LOW (1)**: Мониторинг без блокировки
- **MEDIUM (2)**: TEMP_BAN (10 минут)
- **HIGH (3)**: LONG_BAN (24 часа)
- **CRITICAL (4)**: PERMANENT_BAN (навсегда)

### Обучение

После каждого действия система записывает результат:

```
Время | IP | Действие | Результат
```

Это позволяет анализировать эффективность и адаптировать пороги.

## 🔧 Конфигурация

### ai_config.conf

```bash
# Пороги срабатывания (0-100)
THRESHOLD_LOW=20
THRESHOLD_MEDIUM=40
THRESHOLD_HIGH=60
THRESHOLD_CRITICAL=80

# Веса факторов
WEIGHT_FAILED_LOGIN=10
WEIGHT_ROOT_ATTEMPT=20
WEIGHT_BRUTE_FORCE=30
WEIGHT_PORT_SCAN=15
WEIGHT_GEO_RISK=10

# Риски стран
GEO_RISK_CHINA=30
GEO_RISK_RUSSIA=25
GEO_RISK_NORTH_KOREA=40

# Автоматические действия
AUTO_BAN_ENABLED=true
AUTO_SUBNET_BAN=true
AUTO_PERMANENT_BAN=true
```

## 📱 Telegram бот

### Уведомления

- 🟡 **LOW** - низкая угроза (мониторинг)
- 🟠 **MEDIUM** - средняя угроза (TEMP_BAN)
- 🔴 **HIGH** - высокая угроза (LONG_BAN)
- 🚨 **CRITICAL** - критическая угроза (PERMANENT_BAN)
- ⏰ **Часовой отчёт** - статистика за час
- 🔮 **Прогноз** - предупреждение о скоординированной атаке

### Примеры уведомлений

```
🔴 Высокая угроза

📍 IP: 83.150.21.135
🔍 Тип: SSH_ROOT
📊 Атак: 8
⏱️ Бан: 24 часа
```

## 🛠️ Управление

### Перезапуск

```bash
pkill -f "ai_security_v3.sh"
nohup ./ai_security_v3.sh > /dev/null 2>&1 &
```

### Остановка

```bash
pkill -f "ai_security_v3.sh"
```

### Очистка правил

```bash
# Удалить все AI правила
sudo iptables -D INPUT -m comment --comment "AI_" 2>/dev/null
```

## 📊 Логи

### ai_security.log

Основной лог файл с информацией о:
- Обнаруженных атаках
- Предпринятых действиях
- Отправленных уведомлениях
- Статусе системы

### threat_database.dat

База данных всех угроз:
```
Время | IP | Уровень | Score | Тип атаки | Описание
```

### learning_database.dat

База обучения ИИ:
```
Время | IP | Действие | Результат
```

## 🎯 Примеры использования

### Узнать количество атак за час

```bash
grep "$(date '+%Y-%m-%d %H:')" ai_security.log | wc -l
```

### Найти блокировки конкретного IP

```bash
grep "192.168.1.1" threat_database.dat
```

### Посмотреть эффективность действий

```bash
cat learning_database.dat | cut -d'|' -f3 | sort | uniq -c
```

### Проверить активные блокировки

```bash
sudo iptables -L INPUT -n | grep -c "AI_"
```

## 🔐 Безопасность

### Что НЕ коммитить в Git

- `tg_config.conf` - содержит токен бота
- `ai_config.conf` - может содержать чувствительные настройки
- `blacklist_permanent.txt` - ваш чёрный список
- `*.dat` - файлы состояния и обучения
- `*.log` - логи атак

Эти файлы добавлены в `.gitignore`.

## 🤝 Вклад

1. Fork репозиторий
2. Создайте feature branch (`git checkout -b feature/amazing-feature`)
3. Commit изменения (`git commit -m 'Add amazing feature'`)
4. Push в branch (`git push origin feature/amazing-feature`)
5. Откройте Pull Request

## 📄 Лицензия

MIT License - см. файл LICENSE

## 👥 Авторы

- **AI Security Team** - Initial work


## 📞 Поддержка

Для вопросов и предложений:
- GitHub Issues
- Telegram: @your_support_bot

---

**Статус**: ✅ Активно поддерживается
**Версия**: 3.0 Comprehensive
**Последнее обновление**: Март 2026
