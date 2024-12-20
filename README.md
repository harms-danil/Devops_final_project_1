Документация к репозиторию Devops_final_project_1

Автор: harms-danil

Описание проекта

Репозиторий содержит набор Shell-скриптов для автоматизации следующих процессов:
 • Настройка VPN-сервера (OpenVPN).
 • Настройка системы мониторинга (Prometheus и экспортеры).
 • Реализация системы резервного копирования.
 • Центр сертификации.

Скрипты предназначены для использования в DevOps-среде и предоставляют готовые решения для управления инфраструктурой.

Содержание репозитория

1. Настройка OpenVPN
 
 • openvpn.sh:
Установка и настройка OpenVPN-сервера.
Как использовать:

bash openvpn.sh

2. Система мониторинга
 • prometheus.sh:
Установка и настройка Prometheus.
Как использовать:

bash prometheus.sh

 • prometheus.yml:
Основной файл конфигурации Prometheus. Перед запуском убедитесь, что файл адаптирован под вашу инфраструктуру.
 • rules.yml:
Файл с правилами и настройками алертов.

 • exporters.sh:
Установка и настройка экспортеров для сбора метрик (например, Node Exporter).
Как использовать:

bash exporters.sh

3. Система резервного копирования
• backup_server.sh:
Скрипт для настройки сервера резервного копирования.
Как использовать:

bash backup_server.sh

 • backup_client.sh:
Скрипт для настройки клиента резервного копирования.
Как использовать:

bash backup_client.sh

4. Центр сертификации
• ca-crt-key.sh:
Генерация ключей и сертификатов для центра сертификации (CA).
Как использовать:

bash ca-crt-key.sh

 • easy-rsa.sh:
Автоматизация процессов управления сертификатами через Easy-RSA.
Как использовать:

bash easy-rsa.sh

 • make-config.sh:
Создание конфигурационных файлов для клиентов OpenVPN.
Как использовать:

bash make-config.sh <client_name>

Управление виртуальными машинами (первоначальная настройка)
 • vm-start.sh:
Автоматизация запуска виртуальных машин.
Как использовать:

bash vm-start.sh

Установка и настройка

1. Подготовка окружения

Перед использованием скриптов убедитесь, что на вашем сервере:
 • Установлена ОС на базе Linux (например, Ubuntu).
 • Установлены необходимые пакеты, такие как bash, curl, wget, openssl.
 • У вас есть права администратора (root).

2. Клонирование репозитория

Клонируйте репозиторий в рабочую директорию:

git clone https://github.com/harms-danil/Devops_final_project_1.git
cd Devops_final_project_1

3. Настройка переменных окружения

Некоторые скрипты могут использовать переменные окружения. Ознакомьтесь с их содержимым и настройте переменные перед запуском.

Рекомендации
 1. Проверяйте скрипты перед выполнением.
Убедитесь, что скрипты соответствуют вашим требованиям и не содержат нежелательных действий.
 2. Тестируйте на тестовой среде.
Перед применением скриптов на продакшен-системах протестируйте их в изолированной среде.
 3. Создавайте резервные копии.
Перед внесением изменений в инфраструктуру создавайте резервные копии критически важных данных.

Лицензия

Этот проект распространяется под свободной лицензией. Автор не несет ответственности за возможные проблемы, возникшие в результате использования скриптов.

Обратная связь

Если вы нашли ошибку или хотите предложить улучшение, создайте issue в репозитории.

Эта документация дает общее представление о проекте и инструкции по его использованию. Если у вас есть дополнительные вопросы, пишите!
