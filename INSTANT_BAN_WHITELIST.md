# ⚡ AI Security v3.2 - Мгновенный бан и Белый список

## 🚀 Новые функции

### 1. МГНОВЕННЫЙ БАН (Instant Permanent Ban)

Система теперь **мгновенно блокирует навсегда** IP адреса при обнаружении массовых атак.

#### Пороги срабатывания:

| Тип атаки | Порог | Действие |
|-----------|-------|----------|
| SSH brute force | **15+ попыток** | PERMANENT_BAN |
| SSH root атаки | **10+ попыток** | PERMANENT_BAN |

#### Как это работает:

```
Атака → 15+ попыток → МГНОВЕННЫЙ БАН → Уведомление в Telegram
```

**Пример уведомления:**
```
🚨 МГНОВЕННАЯ БЛОКИРОВКА!

📍 IP: 85.231.98.22
🔍 Тип: SSH_INSTANT_BAN
📊 Атак: 18
🌍 Страна: Russia
♾️ Бан: НАВСЕГДА

Причина: Превышен порог INSTANT_PERMANENT_THRESHOLD
```

#### Настройка:

```bash
# В ai_config.conf:
INSTANT_PERMANENT_THRESHOLD=15  # Порог срабатывания
INSTANT_PERMANENT_ENABLED=true  # Включить функцию
```

#### Отключение:

```bash
INSTANT_PERMANENT_ENABLED=false
```

---

### 2. БЕЛЫЙ СПИСОК (Whitelist)

Система анализирует успешные подключения и **автоматически добавляет доверенные IP** в белый список.

#### Как это работает:

1. **Анализ** успешных подключений за 24 часа
2. **Поиск** IP с 5+ успешными подключениями
3. **Добавление** в whitelist.txt
4. **Защита** от блокировки

#### Пример whitelist.txt:

```
# Whitelist для AI Security System
# Формат: IP # Комментарий

192.168.1.100 # 2026-03-09 16:00:00 Auto: 15 successful connections
10.0.0.50 # 2026-03-09 16:05:00 Manual: Admin server
```

#### Настройки:

```bash
# В ai_config.conf:
WHITELIST_ENABLED=true          # Включить whitelist
WHITELIST_MIN_CONNECTIONS=5     # Мин. подключений для авто-добавления
WHITELIST_CHECK_WINDOW=86400    # Окно анализа: 24 часа
WHITELIST_AUTO_ADD=true         # Авто-добавление
WHITELIST_PROTECT_FROM_BAN=true # Защита от блокировки
MAX_WHITELIST_ENTRIES=500       # Максимум записей
```

---

## 📱 Управление whitelist

### Менеджер whitelist:

```bash
~/security-monitor/whitelist-manager.sh
```

#### Меню:

```
1. Проанализировать успешные подключения
2. Автоматически заполнить whitelist
3. Показать whitelist
4. Добавить IP вручную
5. Удалить IP из whitelist
6. Статистика
7. Выход
```

---

### Примеры использования:

#### 1. Автоматическое заполнение:

```bash
./whitelist-manager.sh
→ Выбрать опцию 2
```

Система проанализирует auth.log и добавит все IP с 5+ успешными подключениями.

#### 2. Ручное добавление:

```bash
./whitelist-manager.sh
→ Выбрать опцию 4
→ Ввести IP: 192.168.1.100
→ Ввести причину: Main admin server
```

#### 3. Просмотр whitelist:

```bash
./whitelist-manager.sh
→ Выбрать опцию 3
```

#### 4. Удаление IP:

```bash
./whitelist-manager.sh
→ Выбрать опцию 5
→ Ввести IP: 192.168.1.100
```

---

## 🎯 Сценарии использования

### Сценарий 1: Сервер с постоянными админами

```bash
# Настройки:
WHITELIST_MIN_CONNECTIONS=3     # Доверять после 3 подключений
WHITELIST_AUTO_ADD=true
WHITELIST_PROTECT_FROM_BAN=true
INSTANT_PERMANENT_THRESHOLD=10  # Агрессивный бан
```

**Результат:** Постоянные админы автоматически добавляются в whitelist и защищены от блокировки.

---

### Сценарий 2: Публичный сервер

```bash
# Настройки:
WHITELIST_MIN_CONNECTIONS=10    # Строгий отбор
WHITELIST_AUTO_ADD=false        # Только вручную
WHITELIST_PROTECT_FROM_BAN=true
INSTANT_PERMANENT_THRESHOLD=20  # Меньше ложных срабатываний
```

**Результат:** Whitelist заполняется только проверенными IP.

---

### Сценарий 3: Максимальная защита

```bash
# Настройки:
WHITELIST_ENABLED=true
WHITELIST_MIN_CONNECTIONS=5
WHITELIST_AUTO_ADD=true
WHITELIST_PROTECT_FROM_BAN=true
INSTANT_PERMANENT_THRESHOLD=5   # Очень агрессивный
```

**Результат:** Быстрая блокировка атак, защита доверенных IP.

---

## 📊 Логи и мониторинг

### Файлы:

| Файл | Описание |
|------|----------|
| `whitelist.txt` | Белый список IP |
| `whitelist_learning.dat` | Лог добавлений в whitelist |
| `blacklist_permanent.txt` | Чёрный список (с reason) |

### Проверка логов:

```bash
# Последние добавления в whitelist
tail -10 ~/security-monitor/whitelist_learning.dat

# Последние блокировки с причинами
tail -10 ~/security-monitor/blacklist_permanent.txt

# Логи системы
tail -f ~/security-monitor/ai_security.log | grep -E "(WHITELIST|INSTANT)"
```

---

## ⚠️ Важные замечания

### 1. Instant Ban

- **Не ставьте слишком низкий порог** (< 10) - возможны ложные срабатывания
- **Проверьте логи** после включения функции
- **Уведомления приходят** в Telegram для каждой блокировки

### 2. Whitelist

- **Регулярно проверяйте** whitelist на наличие неизвестных IP
- **Не добавляйте динамические IP** (могут смениться)
- **Максимум 500 записей** (настраивается)

### 3. Совместная работа

```
IP атакует → Проверка whitelist → Если есть → Пропустить
                                → Если нет → Проверка на Instant Ban
                                           → Если 15+ атак → PERMANENT_BAN
                                           → Иначе → Обычная логика
```

---

## 🔄 Обновление с предыдущих версий

### Изменения в v3.2:

1. **Добавлен Instant Ban** для массовых атак
2. **Добавлен Whitelist** для доверенных IP
3. **Улучшена логика** блокировок
4. **Новые уведомления** в Telegram

### Обратная совместимость:

Все старые настройки работают. Новые функции включены по умолчанию.

---

## 🆘 Troubleshooting

### Whitelist не работает:

```bash
# Проверьте, включена ли функция
grep "WHITELIST_ENABLED" ~/security-monitor/ai_config.conf

# Проверьте файл whitelist.txt
cat ~/security-monitor/whitelist.txt

# Перезапустите систему
pkill -f ai_security_v3 && nohup ~/security-monitor/ai_security_v3.sh > /dev/null 2>&1 &
```

### Instant Ban не срабатывает:

```bash
# Проверьте, включена ли функция
grep "INSTANT_PERMANENT_ENABLED" ~/security-monitor/ai_config.conf

# Проверьте порог
grep "INSTANT_PERMANENT_THRESHOLD" ~/security-monitor/ai_config.conf

# Посмотрите логи
grep "INSTANT" ~/security-monitor/ai_security.log
```

---

**Версия:** 3.2
**Дата:** Март 2026
**Новые функции:** Instant Ban, Whitelist
