# ⚙️ AI Security System - Руководство по настройкам

## 📊 Быстрый доступ

### Изменить настройки
```bash
~/security-monitor/set-config.sh
```

### Редактировать конфиг вручную
```bash
nano ~/security-monitor/ai_config.conf
```

### Перезапустить систему
```bash
pkill -f ai_security_v3 && nohup ~/security-monitor/ai_security_v3.sh > /dev/null 2>&1 &
```

---

## 🛡️ Уровни безопасности

### Уровень 1 - МЯГКИЙ (только мониторинг)
```bash
SECURITY_LEVEL=1
AUTO_BAN_ENABLED=false
MIN_ATTACKS_PERMANENT_BAN=20
```
**Для кого:** Серверы с низким трафиком, где важнее не блокировать легитимных пользователей

---

### Уровень 2 - СТАНДАРТ (рекомендуется)
```bash
SECURITY_LEVEL=2
AUTO_BAN_ENABLED=true
MIN_ATTACKS_PERMANENT_BAN=7
```
**Для кого:** Большинство серверов, баланс между защитой и доступностью

---

### Уровень 3 - АГРЕССИВНЫЙ (максимальная защита)
```bash
SECURITY_LEVEL=3
AUTO_BAN_ENABLED=true
MIN_ATTACKS_PERMANENT_BAN=5
```
**Для кого:** Серверы под активными атаками, где приоритет - максимальная защита

---

## 📈 Пороги блокировок

| Параметр | Значение | Описание |
|----------|----------|----------|
| `MIN_ATTACKS_TEMP_BAN` | 3 | Мин. атак для временной блокировки (10 мин) |
| `MIN_ATTACKS_LONG_BAN` | 5 | Мин. атак для длительной блокировки (24 ч) |
| `MIN_ATTACKS_PERMANENT_BAN` | 7 | Мин. атак для перманентной блокировки |

### Рекомендуемые значения

| Режим | TEMP | LONG | PERMANENT |
|-------|------|------|-----------|
| Мягкий | 5 | 10 | 20 |
| Стандарт | 3 | 5 | 7 |
| Агрессивный | 2 | 4 | 5 |

---

## 🎯 Настройки ИИ

### Пороги срабатывания (0-100)

```bash
THRESHOLD_LOW=20        # Низкая угроза
THRESHOLD_MEDIUM=40     # Средняя угроза
THRESHOLD_HIGH=60       # Высокая угроза
THRESHOLD_CRITICAL=70   # Критическая угроза
```

**Чем ниже порог, тем чувствительнее система**

### Веса факторов

```bash
WEIGHT_FAILED_LOGIN=10      # Неудачный логин
WEIGHT_ROOT_ATTEMPT=25      # Попытка входа под root
WEIGHT_BRUTE_FORCE=30       # Перебор паролей
WEIGHT_PORT_SCAN=15         # Сканирование портов
WEIGHT_GEO_RISK=10          # Географический риск
WEIGHT_TIME_ANOMALY=10      # Аномальное время
WEIGHT_RAPID_ATTACK=20      # Быстрая серия атак
```

**Увеличьте вес, чтобы система сильнее реагировала на этот тип атак**

---

## 🌍 Гео-риски

Оценка риска по странам (0-50):

```bash
GEO_RISK_CHINA=30
GEO_RISK_RUSSIA=25
GEO_RISK_NORTH_KOREA=40
GEO_RISK_IRAN=35
GEO_RISK_DEFAULT=10
```

**Увеличьте для стран, откуда не ожидаете легитимный трафик**

---

## ⚙️ Автоматические действия

```bash
AUTO_BAN_ENABLED=true           # Автоматическая блокировка
AUTO_SUBNET_BAN=true            # Блокировка подсети /24
AUTO_PERMANENT_BAN=true         # Перманентная блокировка критических угроз
AUTO_REPORT_THREATS=true        # Отправка отчётов
```

---

## 🔐 Типы блокируемых атак

```bash
BAN_SSH_ROOT=true               # Атаки на root
BAN_SSH_BRUTEFORCE=true         # Перебор SSH
BAN_DDOS=true                   # DDoS атаки
BAN_PORT_SCAN=true              # Сканирование портов
BAN_WEB_ATTACKS=true            # Web-атаки (SQLi, XSS)
```

**Отключите ненужные типы для снижения нагрузки**

---

## 📱 Уведомления

```bash
NOTIFY_ON_LOW=false             # Низкий уровень
NOTIFY_ON_MEDIUM=true           # Средний уровень
NOTIFY_ON_HIGH=true             # Высокий уровень
NOTIFY_ON_CRITICAL=true         # Критический уровень
NOTIFY_HOURLY=true              # Ежечасные отчёты
NOTIFY_PREDICTION=true          # Прогнозы атак
NOTIFY_PERMANENT_BAN=true       # Перманентные блокировки
```

---

## 🎮 Примеры настройки

### Пример 1: Сервер с высоким трафиком
```bash
SECURITY_LEVEL=2
MIN_ATTACKS_TEMP_BAN=5
MIN_ATTACKS_LONG_BAN=10
MIN_ATTACKS_PERMANENT_BAN=15
NOTIFY_ON_LOW=false
NOTIFY_ON_MEDIUM=false
NOTIFY_ON_HIGH=true
```

### Пример 2: Сервер под постоянной атакой
```bash
SECURITY_LEVEL=3
MIN_ATTACKS_PERMANENT_BAN=5
AUTO_SUBNET_BAN=true
BAN_PORT_SCAN=true
BAN_WEB_ATTACKS=true
```

### Пример 3: Тестовый сервер
```bash
SECURITY_LEVEL=1
AUTO_BAN_ENABLED=false
NOTIFY_ON_LOW=true
NOTIFY_ON_MEDIUM=true
NOTIFY_ON_HIGH=true
```

---

## 🔄 Применение изменений

1. Отредактируйте `ai_config.conf`
2. Перезапустите службу:
```bash
pkill -f ai_security_v3
nohup ~/security-monitor/ai_security_v3.sh > /dev/null 2>&1 &
```

3. Проверьте статус:
```bash
ps aux | grep ai_security
```

---

## 📊 Проверка настроек

```bash
# Текущие настройки
~/security-monitor/set-config.sh

# Статистика блокировок
~/security-monitor/check-today.sh

# Статус обучения
~/security-monitor/check-learning.sh
```

---

## ⚠️ Важные замечания

1. **Не ставьте слишком низкие пороги** - могут блокироваться легитимные пользователи
2. **Включите NOTIFY_ON_HIGH** - чтобы знать о серьёзных атаках
3. **Проверяйте логи** - `tail -f ~/security-monitor/ai_security.log`
4. **Тестируйте изменения** - сначала на одном параметре

---

## 🆘 Сброс настроек

Если что-то пошло не так:

```bash
# Сброс к настройкам по умолчанию
~/security-monitor/set-config.sh → опция 6

# Или вручную
cat > ~/security-monitor/ai_config.conf << 'EOF'
SECURITY_LEVEL=2
MIN_ATTACKS_PERMANENT_BAN=7
MIN_ATTACKS_LONG_BAN=5
MIN_ATTACKS_TEMP_BAN=3
AUTO_BAN_ENABLED=true
EOF
```

---

**Версия:** 3.1
**Последнее обновление:** Март 2026
