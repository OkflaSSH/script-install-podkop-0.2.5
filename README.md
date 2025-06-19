Если у вас установлен Getdomains, то его следует удалить.

# Удаление GetDomains скриптом
```
sh <(wget -O - https://raw.githubusercontent.com/itdoginfo/domain-routing-openwrt/refs/heads/master/getdomains-uninstall.sh)
```

Оставляет туннели, зоны, forwarding. А также stubby и dnscrypt. Они не помешают. Конфиг sing-box будет перезаписан в podkop.

# Установка Podkop
Пакет работает на всех архитектурах.
Будет точно работать только на OpenWrt 23.05.

Нужен dnsmasq-full. В автоматическом режиме ставится сам. 

## Автоматическая
```
sh <(wget -O - https://raw.githubusercontent.com/OkflaSSH/script-install-podkop-0.2.5/refs/heads/main/install.sh)
```

Скрипт также предложит выбрать, какой туннель будет использоваться. Для выбранного туннеля будут установлены нужные пакеты, а для Wireguard и AmneziaWG также будет предложена автоматическая настройка - прямо в консоли скрипт запросит данные конфига. Для AmneziaWG можно также выбрать вариант с использованием конфига обычного Wireguard и автоматической обфускацией до AmneziaWG.

Для AmneziaWG скрипт проверяет наличие пакетов под вашу платформу в [стороннем репозитории](https://github.com/Slava-Shchipunov/awg-openwrt/releases), так как в официальном репозитории OpenWRT они отсутствуют, и автоматически их устанавливает.
