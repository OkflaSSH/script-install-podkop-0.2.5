#!/bin/sh

# Легко обновить версию, изменив только эти переменные

PODKOP_VERSION="0.2.5"
PODKOP_PKG_VERSION="0.2.5-1"
REPO_BASE_URL="https://raw.githubusercontent.com/OkflaSSH/script-install-podkop-0.2.5/main/podkop-0.2.5"


IS_SHOULD_RESTART_NETWORK=
DOWNLOAD_DIR="/tmp/podkop"
mkdir -p "$DOWNLOAD_DIR"


fail() {
    echo "Ошибка: $1" >&2
    exit 1
}

main() {
    check_system

    echo "Загрузка пакетов Podkop версии ${PODKOP_VERSION}..."

    # Скачиваем podkop
    wget -q -O "$DOWNLOAD_DIR/podkop_${PODKOP_PKG_VERSION}_all.ipk" "${REPO_BASE_URL}/podkop_${PODKOP_PKG_VERSION}_all.ipk"
    [ $? -ne 0 ] && fail "Не удалось скачать пакет podkop."

    # Скачиваем luci-app-podkop
    wget -q -O "$DOWNLOAD_DIR/luci-app-podkop_${PODKOP_VERSION}_all.ipk" "${REPO_BASE_URL}/luci-app-podkop_${PODKOP_VERSION}_all.ipk"
    [ $? -ne 0 ] && fail "Не удалось скачать пакет luci-app-podkop."

    # Скачиваем русскую локализацию
    wget -q -O "$DOWNLOAD_DIR/luci-i18n-podkop-ru_${PODKOP_VERSION}.ipk" "${REPO_BASE_URL}/luci-i18n-podkop-ru_${PODKOP_VERSION}.ipk"
    [ $? -ne 0 ] && fail "Не удалось скачать пакет luci-i18n-podkop-ru."
    
    echo "Обновление списка пакетов (opkg update)..."
    opkg update

    if opkg list-installed | grep -q dnsmasq-full; then
        echo "dnsmasq-full уже установлен."
    else
        echo "Установка dnsmasq-full..."
        cd /tmp/ && opkg download dnsmasq-full
        opkg remove dnsmasq && opkg install dnsmasq-full --cache /tmp/
        [ $? -ne 0 ] && fail "Не удалось установить dnsmasq-full."

        [ -f /etc/config/dhcp-opkg ] && cp /etc/config/dhcp /etc/config/dhcp-old && mv /etc/config/dhcp-opkg /etc/config/dhcp
    fi

    openwrt_release=$(cat /etc/openwrt_release | grep -Eo '[0-9]{2}\.[0-9]{2}\.[0-9]*' | cut -d '.' -f 1 | tail -n 1)
    if [ "$openwrt_release" -ge 24 ]; then
        if uci get dhcp.@dnsmasq[0].confdir 2>/dev/null | grep -q '/tmp/dnsmasq.d'; then
            echo "Опция confdir уже настроена."
        else
            echo "Настройка опции confdir для OpenWrt 24+..."
            uci set dhcp.@dnsmasq[0].confdir='/tmp/dnsmasq.d'
            uci commit dhcp
        fi
    fi
    
    if [ -f "/etc/init.d/podkop" ]; then
        printf "\033[32;1mPodkop уже установлен. Обновить? (y/n)\033[0m\n"
        printf "\033[32;1my - Только обновить пакеты podkop\033[0m\n"
        printf "\033[32;1mn - Обновить и настроить туннели\033[0m\n"

        while true; do
            read -r -p '' UPDATE
            case $UPDATE in
            y|Y)
                echo "Обновление podkop..."
                break
                ;;
            n|N)
                add_tunnel
                break
                ;;
            *)
                echo "Пожалуйста, введите y или n"
                ;;
            esac
        done
    else
        echo "Установка podkop..."
        add_tunnel
    fi

    echo "Установка основных пакетов..."
    opkg install "$DOWNLOAD_DIR/podkop_"*.ipk
    opkg install "$DOWNLOAD_DIR/luci-app-podkop_"*.ipk

    echo "Установить русский язык интерфейса? y/n (Need a Russian translation?)"
    while true; do
        read -r -p '' RUS
        case $RUS in
        y|Y)
            opkg install "$DOWNLOAD_DIR/luci-i18n-podkop-ru_"*.ipk
            break
            ;;
        n|N)
            break
            ;;
        *)
            echo "Пожалуйста, введите y или n"
            ;;
        esac
    done

    rm -f "$DOWNLOAD_DIR"/*.ipk

    if [ "$IS_SHOULD_RESTART_NETWORK" ]; then
        printf "\033[32;1mПерезапуск сети...\033[0m\n"
        /etc/init.d/network restart
    fi
    
    printf "\033[32;1mУстановка завершена!\033[0m\n"
}

add_tunnel() {
    echo "Какой тип VPN или прокси будет использоваться? Возможна автоматическая настройка Wireguard и AmneziaWG."
    echo "1) VLESS, Shadowsocks (будет установлен sing-box)"
    echo "2) Wireguard"
    echo "3) AmneziaWG"
    echo "4) OpenVPN"
    echo "5) OpenConnect"
    echo "6) Пропустить этот шаг"

    while true; do
        read -r -p 'Ваш выбор: ' TUNNEL
        case $TUNNEL in
        1)
            opkg install sing-box
            break
            ;;
        2)
            opkg install wireguard-tools luci-proto-wireguard luci-app-wireguard
            printf "\033[32;1mХотите настроить интерфейс wireguard сейчас? (y/n): \033[0m"
            read -r IS_SHOULD_CONFIGURE_WG_INTERFACE
            if [ "$IS_SHOULD_CONFIGURE_WG_INTERFACE" = "y" ] || [ "$IS_SHOULD_CONFIGURE_WG_INTERFACE" = "Y" ]; then
                wg_awg_setup Wireguard
            else
                printf "\e[1;32mИспользуйте инструкцию для ручной настройки: https://itdog.info/nastrojka-klienta-wireguard-na-openwrt/\e[0m\n"
            fi
            break
            ;;
        3)
            install_awg_packages
            printf "\033[32;1mХотите настроить интерфейс amneziawg сейчас? (y/n): \033[0m"
            read -r IS_SHOULD_CONFIGURE_WG_INTERFACE
            if [ "$IS_SHOULD_CONFIGURE_WG_INTERFACE" = "y" ] || [ "$IS_SHOULD_CONFIGURE_WG_INTERFACE" = "Y" ]; then
                wg_awg_setup AmneziaWG
            fi
            break
            ;;
        4)
          
            opkg install openvpn-openssl luci-app-openvpn
            printf "\e[1;32mИспользуйте инструкцию для настройки: https://itdog.info/nastrojka-klienta-openvpn-na-openwrt/\e[0m\n"
            break
            ;;
        5)
          
            opkg install openconnect luci-proto-openconnect
            printf "\e[1;32mИспользуйте инструкцию для настройки: https://itdog.info/nastrojka-klienta-openconnect-na-openwrt/\e[0m\n"
            break
            ;;
        6)
            echo "Шаг пропущен."
            break
            ;;
        *)
            echo "Пожалуйста, выберите один из предложенных вариантов."
            ;;
        esac
    done
}

handler_network_restart() {
    IS_SHOULD_RESTART_NETWORK=true
}

install_awg_packages() {
    PKGARCH=$(opkg print-architecture | awk 'BEGIN {max=0} {if ($3 > max) {max = $3; arch = $2}} END {print arch}')
    TARGET=$(ubus call system board | jsonfilter -e '@.release.target' | cut -d '/' -f 1)
    SUBTARGET=$(ubus call system board | jsonfilter -e '@.release.target' | cut -d '/' -f 2)
    VERSION=$(ubus call system board | jsonfilter -e '@.release.version')
    PKGPOSTFIX="_v${VERSION}_${PKGARCH}_${TARGET}_${SUBTARGET}.ipk"
    BASE_URL="https://github.com/Slava-Shchipunov/awg-openwrt/releases/download/"
    AWG_DIR="/tmp/amneziawg"
    mkdir -p "$AWG_DIR"

    # Список пакетов для установки
    packages="kmod-amneziawg amneziawg-tools luci-app-amneziawg"

    for pkg_name in $packages; do
        if opkg list-installed | grep -q "$pkg_name"; then
            echo "$pkg_name уже установлен."
            continue
        fi

        PKG_FILENAME="${pkg_name}${PKGPOSTFIX}"
        DOWNLOAD_URL="${BASE_URL}v${VERSION}/${PKG_FILENAME}"

        echo "Загрузка ${pkg_name}..."
        wget -O "$AWG_DIR/$PKG_FILENAME" "$DOWNLOAD_URL"
        [ $? -ne 0 ] && fail "Не удалось скачать ${pkg_name}. Установите его вручную и запустите скрипт снова."

        echo "Установка ${pkg_name}..."
        opkg install "$AWG_DIR/$PKG_FILENAME"
        [ $? -ne 0 ] && fail "Не удалось установить ${pkg_name}. Установите его вручную и запустите скрипт снова."
        
        echo "${pkg_name} успешно установлен."
    done

    rm -rf "$AWG_DIR"
}

wg_awg_setup() {
 
    PROTOCOL_NAME=$1
    printf "\033[32;1mНастройка ${PROTOCOL_NAME}\033[0m\n"
    if [ "$PROTOCOL_NAME" = 'Wireguard' ]; then
        INTERFACE_NAME="wg0"
        CONFIG_NAME="wireguard_wg0"
        PROTO="wireguard"
        ZONE_NAME="wg"
    fi
    if [ "$PROTOCOL_NAME" = 'AmneziaWG' ]; then
        INTERFACE_NAME="awg0"
        CONFIG_NAME="amneziawg_awg0"
        PROTO="amneziawg"
        ZONE_NAME="awg"
        
        echo "Использовать конфиг AmneziaWG или базовый конфиг Wireguard + авто-обфускация?"
        echo "1) AmneziaWG"
        echo "2) Wireguard + авто-обфускация"
        read -r CONFIG_TYPE
    fi
    read -r -p "Введите приватный ключ (из секции [Interface]):"$'\n' WG_PRIVATE_KEY_INT
    while true; do
        read -r -p "Введите внутренний IP-адрес с маской (например, 192.168.100.5/24):"$'\n' WG_IP
        if echo "$WG_IP" | grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]+$'; then
            break
        else
            echo "Неверный формат IP-адреса. Попробуйте снова."
        fi
    done
    read -r -p "Введите публичный ключ (из секции [Peer]):"$'\n' WG_PUBLIC_KEY_INT
    read -r -p "Введите PresharedKey (из [Peer]), если используется (иначе оставьте пустым):"$'\n' WG_PRESHARED_KEY_INT
    read -r -p "Введите Endpoint хост без порта (домен или IP):"$'\n' WG_ENDPOINT_INT
    read -r -p "Введите порт Endpoint (по умолчанию 51820): " WG_ENDPOINT_PORT_INT
    WG_ENDPOINT_PORT_INT=${WG_ENDPOINT_PORT_INT:-51820}
    echo "Используется порт: $WG_ENDPOINT_PORT_INT"
    if [ "$PROTOCOL_NAME" = 'AmneziaWG' ]; then
        if [ "$CONFIG_TYPE" = '1' ]; then
            read -r -p "Введите Jc: " AWG_JC
            read -r -p "Введите Jmin: " AWG_JMIN
            read -r -p "Введите Jmax: " AWG_JMAX
            read -r -p "Введите S1: " AWG_S1
            read -r -p "Введите S2: " AWG_S2
            read -r -p "Введите H1: " AWG_H1
            read -r -p "Введите H2: " AWG_H2
            read -r -p "Введите H3: " AWG_H3
            read -r -p "Введите H4: " AWG_H4
        elif [ "$CONFIG_TYPE" = '2' ]; then
            AWG_JC=4; AWG_JMIN=40; AWG_JMAX=70; AWG_S1=0; AWG_S2=0; AWG_H1=1; AWG_H2=2; AWG_H3=3; AWG_H4=4
        fi
    fi
    uci set network.${INTERFACE_NAME}=interface
    uci set network.${INTERFACE_NAME}.proto="$PROTO"
    uci set network.${INTERFACE_NAME}.private_key="$WG_PRIVATE_KEY_INT"
    uci set network.${INTERFACE_NAME}.listen_port='51821'
    uci add_list network.${INTERFACE_NAME}.addresses="$WG_IP"
    if [ "$PROTOCOL_NAME" = 'AmneziaWG' ]; then
        uci set network.${INTERFACE_NAME}.awg_jc="$AWG_JC"
        uci set network.${INTERFACE_NAME}.awg_jmin="$AWG_JMIN"
        uci set network.${INTERFACE_NAME}.awg_jmax="$AWG_JMAX"
        uci set network.${INTERFACE_NAME}.awg_s1="$AWG_S1"
        uci set network.${INTERFACE_NAME}.awg_s2="$AWG_S2"
        uci set network.${INTERFACE_NAME}.awg_h1="$AWG_H1"
        uci set network.${INTERFACE_NAME}.awg_h2="$AWG_H2"
        uci set network.${INTERFACE_NAME}.awg_h3="$AWG_H3"
        uci set network.${INTERFACE_NAME}.awg_h4="$AWG_H4"
    fi
    uci add network "$CONFIG_NAME"
    uci set network.@${CONFIG_NAME}[-1].public_key="$WG_PUBLIC_KEY_INT"
    uci set network.@${CONFIG_NAME}[-1].preshared_key="$WG_PRESHARED_KEY_INT"
    uci set network.@${CONFIG_NAME}[-1].endpoint_host="$WG_ENDPOINT_INT"
    uci set network.@${CONFIG_NAME}[-1].endpoint_port="$WG_ENDPOINT_PORT_INT"
    uci set network.@${CONFIG_NAME}[-1].persistent_keepalive='25'
    uci add_list network.@${CONFIG_NAME}[-1].allowed_ips='0.0.0.0/0'
    uci commit network
    if ! uci show firewall | grep -q "@zone.*name='${ZONE_NAME}'"; then
        printf "\033[32;1mСоздание зоны firewall...\033[0m\n"
        uci add firewall zone
        uci set firewall.@zone[-1].name="$ZONE_NAME"
        uci set firewall.@zone[-1].network="$INTERFACE_NAME"
        uci set firewall.@zone[-1].input='REJECT'
        uci set firewall.@zone[-1].output='ACCEPT'
        uci set firewall.@zone[-1].forward='REJECT'
        uci set firewall.@zone[-1].masq='1'
        uci set firewall.@zone[-1].mtu_fix='1'
    fi
    if ! uci show firewall | grep -q "@forwarding.*src='lan'.*dest='${ZONE_NAME}'"; then
        printf "\033[32;1mНастройка перенаправления трафика (forwarding)...\033[0m\n"
        uci add firewall forwarding
        uci set firewall.@forwarding[-1].src='lan'
        uci set firewall.@forwarding[-1].dest="$ZONE_NAME"
    fi
    uci commit firewall
    handler_network_restart
}

check_system() {
    MODEL=$(cat /tmp/sysinfo/model)
    echo "Модель роутера: $MODEL"
    AVAILABLE_SPACE=$(df /tmp | awk 'NR==2 {print $4}')
    REQUIRED_SPACE=1024
    if [ "$AVAILABLE_SPACE" -lt "$REQUIRED_SPACE" ]; then
        fail "Недостаточно места в /tmp. Доступно: $((AVAILABLE_SPACE/1024))MB, Требуется: $((REQUIRED_SPACE/1024))MB"
    fi
}


main
