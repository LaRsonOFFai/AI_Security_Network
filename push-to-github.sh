#!/bin/bash
#
# Скрипт выгрузки AI Security System на GitHub
#

set -e

echo "╔══════════════════════════════════════════════════════════╗"
echo "║     AI Security System - Выгрузка на GitHub              ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Проверка Git
if ! command -v git &> /dev/null; then
    echo -e "${RED}❌ Git не установлен!${NC}"
    echo "Установите: sudo apt install git"
    exit 1
fi
echo -e "${GREEN}✅ Git найден${NC}"

# Шаг 1: Настройка Git
echo ""
echo "━━━ ШАГ 1: Настройка Git ━━━"
echo ""

if [[ -z "$(git config --global user.name)" ]]; then
    read -p "Введите ваше имя для Git: " git_name
    git config --global user.name "$git_name"
fi

if [[ -z "$(git config --global user.email)" ]]; then
    read -p "Введите ваш email для Git: " git_email
    git config --global user.email "$git_email"
fi

echo -e "${GREEN}✅ Git настроен${NC}"
git config --global user.name
git config --global user.email

# Шаг 2: Создание SSH ключа (если нет)
echo ""
echo "━━━ ШАГ 2: SSH ключ для GitHub ━━━"
echo ""

if [[ -f ~/.ssh/id_ed25519.pub ]]; then
    echo -e "${GREEN}✅ SSH ключ уже существует${NC}"
else
    echo -e "${YELLOW}⚠️  SSH ключ не найден${NC}"
    read -p "Создать новый SSH ключ? (y/n): " create_key
    
    if [[ "$create_key" == "y" || "$create_key" == "Y" ]]; then
        ssh-keygen -t ed25519 -C "$(git config --global user.email)" -f ~/.ssh/id_ed25519 -N ""
        echo -e "${GREEN}✅ SSH ключ создан${NC}"
        echo ""
        echo -e "${YELLOW}📋 Добавьте этот ключ в GitHub:${NC}"
        echo ""
        cat ~/.ssh/id_ed25519.pub
        echo ""
        echo "GitHub → Settings → SSH and GPG keys → New SSH Key"
        echo ""
        read -p "Нажмите Enter, когда добавите ключ в GitHub..."
    else
        echo "Пропущено. Убедитесь, что SSH ключ настроен."
    fi
fi

# Шаг 3: Инициализация репозитория
echo ""
echo "━━━ ШАГ 3: Инициализация репозитория ━━━"
echo ""

cd /home/larson/security-monitor

if [[ -d .git ]]; then
    echo -e "${YELLOW}⚠️  Git репозиторий уже инициализирован${NC}"
    read -p "Пересоздать? (y/n): " reinit
    
    if [[ "$reinit" == "y" || "$reinit" == "Y" ]]; then
        rm -rf .git
        git init
        echo -e "${GREEN}✅ Репозиторий пересоздан${NC}"
    fi
else
    git init
    echo -e "${GREEN}✅ Репозиторий инициализирован${NC}"
fi

# Шаг 4: Добавление файлов
echo ""
echo "━━━ ШАГ 4: Добавление файлов ━━━"
echo ""

git add -A
git status --short

read -p "Продолжить commit? (y/n): " confirm_commit
if [[ "$confirm_commit" != "y" && "$confirm_commit" != "Y" ]]; then
    echo "Отменено пользователем"
    exit 0
fi

git commit -m "Initial commit: AI Security System v3.0

- Adaptive AI threat detection
- Real-time attack monitoring (SSH, DDoS, Web, Port Scan)
- Automatic IP blocking with iptables
- Machine learning for threat analysis
- Telegram notifications
- Comprehensive logging and reporting
- User-friendly diagnostic tools"

echo -e "${GREEN}✅ Commit создан${NC}"

# Шаг 5: Создание репозитория на GitHub
echo ""
echo "━━━ ШАГ 5: Создание репозитория на GitHub ━━━"
echo ""

echo "Варианты:"
echo "1. Создать репозиторий через GitHub CLI (gh)"
echo "2. Ввести URL существующего репозитория вручную"
echo "3. Выйти и создать репозиторий вручную на github.com"
echo ""

read -p "Выберите вариант (1/2/3): " choice

case $choice in
    1)
        if command -v gh &> /dev/null; then
            read -p "Название репозитория (security-monitor): " repo_name
            repo_name=${repo_name:-security-monitor}
            
            read -p "Сделать публичным? (y/n): " public
            
            if [[ "$public" == "y" || "$public" == "Y" ]]; then
                gh repo create "$repo_name" --public --source=. --remote=origin --push
            else
                gh repo create "$repo_name" --private --source=. --remote=origin --push
            fi
            
            echo -e "${GREEN}✅ Репозиторий создан и запушен${NC}"
        else
            echo -e "${RED}❌ GitHub CLI (gh) не установлен${NC}"
            echo "Установите: sudo apt install gh"
            echo "Или используйте вариант 2 или 3"
            exit 1
        fi
        ;;
    2)
        read -p "Введите URL репозитория (https://github.com/USERNAME/REPO.git): " repo_url
        
        git remote add origin "$repo_url"
        git branch -M main
        git push -u origin main
        
        echo -e "${GREEN}✅ Репозиторий запушен${NC}"
        ;;
    3)
        echo ""
        echo "1. Создайте репозиторий на https://github.com/new"
        echo "2. Назовите его (например: security-monitor)"
        echo "3. Скопируйте URL репозитория"
        echo ""
        read -p "Введите URL репозитория: " repo_url
        
        git remote add origin "$repo_url"
        git branch -M main
        git push -u origin main
        
        echo -e "${GREEN}✅ Репозиторий запушен${NC}"
        ;;
    *)
        echo "Неверный выбор"
        exit 1
        ;;
esac

# Шаг 6: Проверка
echo ""
echo "━━━ ШАГ 6: Проверка ━━━"
echo ""

git remote -v
echo ""
echo -e "${GREEN}✅ Выгрузка завершена!${NC}"
echo ""

# Итоговая информация
echo "╔══════════════════════════════════════════════════════════╗"
echo "║                    ГОТОВО!                               ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "📁 Ваш проект выгружен на GitHub"
echo ""
echo "📝 Что дальше:"
echo "   1. Проверьте репозиторий на GitHub"
echo "   2. Добавьте описание и README (уже есть)"
echo "   3. Настройте GitHub Actions для CI/CD (опционально)"
echo "   4. Поделитесь ссылкой!"
echo ""
echo "🔐 Не забудьте:"
echo "   - tg_config.conf НЕ загружен (содержит токен)"
echo "   - ai_config.conf НЕ загружен (настройки)"
echo "   - *.dat файлы НЕ загружены (данные)"
echo "   - *.log файлы НЕ загружены (логи)"
echo ""
echo "💡 Для обновления репозитория:"
echo "   cd ~/security-monitor"
echo "   git add ."
echo "   git commit -m 'Update'"
echo "   git push"
echo ""
