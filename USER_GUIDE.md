# 📊 AI Security System - Руководство пользователя

## ✅ Система работает!

Ваша система защиты **полностью функциональна**:
- ✅ Обнаружение атак в реальном времени
- ✅ Автоматические блокировки
- ✅ Обучение на основе результатов
- ✅ Telegram уведомления

---

## 📋 Быстрые команды

### 1. Проверить блокировки за сегодня
```bash
~/security-monitor/blocked-today.sh
```

**Показывает:**
- Какие IP заблокированы навсегда
- Какие IP временно заблокированы
- Статистику атак
- Статус обучения

### 2. Полный отчёт за сегодня
```bash
~/security-monitor/check-today.sh
```

**Показывает:**
- Полную статистику блокировок
- Статус обучения системы
- Telegram уведомления
- Активные правила iptables
- Статус процессов

### 3. Посмотреть лог в реальном времени
```bash
tail -f ~/security-monitor/ai_security.log
```

---

## 🎯 Что было заблокировано сегодня

Пример вывода `blocked-today.sh`:

```
🚫 ПОСТОЯННЫЕ БЛОКИРОВКИ:
   🔴 83.150.21.135 (атак: 9, тип: SSH_INVALID_USER)
   🔴 67.205.156.52 (атак: 8, тип: SSH_ROOT)
   🔴 85.231.98.22 (атак: 7, тип: SSH_ROOT)

⏱️ ВРЕМЕННЫЕ БЛОКИРОВКИ:
   🟠 209.38.17.105 (атак: 1)

📊 СТАТИСТИКА:
   Всего событий: 177
   Заблокировано: 22
   Под наблюдением: 72

📚 ОБУЧЕНИЕ:
   ✅ Записей сегодня: 83
```

---

## 🧠 Как работает обучение

Система записывает каждое своё действие в `learning_database.dat`:

```
2026-03-09 16:00:06 | 83.150.21.135 | MONITOR | success
2026-03-09 16:01:15 | 208.95.112.1 | PERMANENT_BAN | success
```

**Формат:** `Время | IP | Действие | Результат`

**Действия:**
- `MONITOR` - наблюдение (низкий уровень угрозы)
- `TEMP_BAN` - временная блокировка на 10 минут
- `LONG_BAN` - длительная блокировка на 24 часа
- `PERMANENT_BAN` - перманентная блокировка

---

## 📱 Telegram уведомления

### Какие уведомления приходят:
1. **Запуск системы** - при старте AI Security
2. **Средняя угроза (🟠)** - TEMP_BAN
3. **Высокая угроза (🔴)** - LONG_BAN
4. **Критическая угроза (🚨)** - PERMANENT_BAN
5. **Часовой отчёт** - статистика за час

### Боты:
- **Security Monitor:** `7000421189:AAEtWMeAORBUS5p8DQbg1BZUkCvWdMR8Tp8`
  - Отправляет уведомления о блокировках
- **PicoClaw Bot:** `8018861488:AAHDu7EakpZAA3qYew1IH7nj0RPOhMcrPvA`
  - Управление сервером через команды

---

## 🔍 Типы обнаруживаемых атак

### SSH атаки:
- `SSH` - неудачные попытки входа (3+ попыток)
- `SSH_ROOT` - попытки входа под root (2+ попыток)
- `SSH_INVALID_USER` - перебор пользователей

### DDoS атаки:
- `DDOS_SYN` - SYN flood
- `DDOS_UDP` - UDP flood
- `DDOS_ICMP` - ICMP flood
- `DDOS_BANDWIDTH` - перегрузка канала

### Web атаки:
- `WEB_SQLI` - SQL injection
- `WEB_XSS` - Cross-site scripting
- `WEB_TRAVERSAL` - Directory traversal

### Другие:
- `PORT_SCAN` - сканирование портов
- `DNS_FLOOD` - DNS flood
- `BRUTE_FORCE` - перебор паролей (FTP, MySQL, SMTP)

---

## ⚙️ Управление системой

### Перезапуск AI Security:
```bash
pkill -f "ai_security_v3.sh"
nohup ~/security-monitor/ai_security_v3.sh > /dev/null 2>&1 &
```

### Проверить статус:
```bash
ps aux | grep ai_security
```

### Посмотреть активные блокировки:
```bash
sudo iptables -L INPUT -n | grep AI_
```

### Очистить все AI правила:
```bash
sudo iptables -D INPUT -m comment --comment "AI_" 2>/dev/null
```

---

## 📊 Файлы системы

| Файл | Описание |
|------|----------|
| `ai_security_v3.sh` | Основной скрипт защиты |
| `attack_monitor.sh` | Скрипт обнаружения атак |
| `threat_database.dat` | База всех угроз |
| `learning_database.dat` | База обучения ИИ |
| `ai_security.log` | Лог файл |
| `blacklist_permanent.txt` | Перманентный чёрный список |
| `ai_config.conf` | Конфигурация ИИ |
| `tg_config.conf` | Telegram конфигурация |

---

## 🎯 Примеры использования

### Узнать, сколько атак было за час:
```bash
grep "$(date '+%Y-%m-%d %H:')" ~/security-monitor/ai_security.log | wc -l
```

### Найти все блокировки конкретного IP:
```bash
grep "192.168.1.1" ~/security-monitor/threat_database.dat
```

### Посмотреть эффективность обучения:
```bash
cat ~/security-monitor/learning_database.dat | cut -d'|' -f3 | sort | uniq -c
```

---

## ❓ Частые вопросы

### Q: Почему не приходят уведомления?
**A:** Проверьте:
1. Запущен ли бот: `ps aux | grep ai_security`
2. Правильный ли Chat ID в `tg_config.conf`
3. Начали ли вы диалог с ботом

### Q: Как узнать, обучается ли система?
**A:** Запустите `~/security-monitor/check-today.sh` - раздел "ОБУЧЕНИЕ" покажет статус.

### Q: Можно ли разблокировать IP?
**A:** Да, вручную через iptables:
```bash
sudo iptables -D INPUT -s 192.168.1.1 -j DROP
```

### Q: Как часто система отправляет уведомления?
**A:** 
- Мгновенно при блокировках (MEDIUM/HIGH/CRITICAL)
- Ежечасно с отчётом
- При запуске системы

---

## 📞 Поддержка

Для проверки системы используйте:
```bash
~/security-monitor/check-today.sh
```

Это покажет полное состояние системы и поможет диагностировать проблемы.
