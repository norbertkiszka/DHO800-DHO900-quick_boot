#!/system/bin/bash

#exec >> /data/logs/tools_log/quick_boot.log 2>&1

function quick_power_off() {
    echo "...... Quick Power Off ...... Start @ $(date '+%Y.%m.%d %H.%M.%S')" 
	appops set com.rigol.launcher RUN_IN_BACKGROUND deny
	pm disable com.rigol.launcher
    kill $(pidof com.rigol.launcher) &> /dev/null
    kill $(pgrep Watchdog) &> /dev/null
    kill $(pidof com.rigol.scope) &> /dev/null
    sleep 1
    touch /data/logs/tools_log/during_power_onoff
    setprop persist.rigol.quick_power_off 0
    sleep 1
    rmmod usbtmc_dev &> /dev/null
    rmmod libcomposite &> /dev/null
    setprop persist.rigol.quick_power_off 30
    rmmod xdma &> /dev/null
    rmmod pcie_rockchip &> /dev/null
    setprop persist.rigol.quick_power_off 70
    echo lspci
    lspci
    #ifconfig eth0 down
    #rmmod /rigol/driver/motorcomm.ko
    setprop persist.rigol.quick_power_off 100
    # sleep 10
    #echo 0 > /sys/devices/platform/backlight/backlight/backlight/brightness
    rmmod fan_gpio_clt &> /dev/null
    rm -rf /data/logs/tools_log/during_power_onoff
    touch /data/logs/tools_log/after_quick_off
    echo "...... Quick Power Off ...... End @ $(date '+%Y.%m.%d %H.%M.%S')"
    echo
}

function quick_power_on() {
    ### Start with the Max CPU Freq
    echo userspace > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
    echo 1416000 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_setspeed
    echo userspace > /sys/devices/system/cpu/cpu4/cpufreq/scaling_governor
    echo 1800000 > /sys/devices/system/cpu/cpu4/cpufreq/scaling_setspeed
    echo "...... Quick Power On ...... Start @ $(date '+%Y.%m.%d %H.%M.%S')"
	rm /data/logs/tools_log/after_quick_off
    touch /data/logs/tools_log/during_power_onoff
    appops set com.rigol.launcher RUN_IN_BACKGROUND allow
    setprop persist.rigol.quick_power_on 0
    setprop persist.rigol.quick_power 1
    # 启动APP
    #am start -n com.rigol.scope/.MainActivity
    # 加载风扇
    if [[ $(lsmod | grep "fan_gpio_clt") == "" ]] ; then
		insmod /rigol/driver/fan_gpio_clt.ko
	fi
    #sleep 1
    kill $(pidof com.rigol.launcher) &> /dev/null
    kill $(pgrep Watchdog) &> /dev/null
    kill $(pidof com.rigol.scope) &> /dev/null
    echo 255 > /sys/devices/platform/backlight/backlight/backlight/brightness

    /rigol/tools/spi2pll_lxm2582
    setprop persist.rigol.quick_power_on 10
    # 获取系统软件版本
    system_ver=$(getprop ro.rigol.system.version)
    echo "$system_ver"
    first_char=${system_ver:0:1}
    second_char=${system_ver:2:1}
    third_char=${system_ver:4:1}
    echo "$first_char"
    echo "$second_char"
    echo "$third_char"

    # 获取golden分区逻辑版本
    golden_ver=$(/rigol/tools/spidev)
    kill $(pidof com.rigol.launcher) &> /dev/null
    kill $(pidof com.rigol.scope) &> /dev/null
    echo "$golden_ver"
    golden_ver_year=${golden_ver:4:4}
    golden_ver_month=${golden_ver:9:2}
    golden_ver_day=${golden_ver:12:2}
    echo "$golden_ver_year"
    echo "$golden_ver_month"
    echo "$golden_ver_day"

    setprop persist.rigol.quick_power_on 20
    echo $(getprop persist.rigol/quick_power_on)

    flag=0
    if [ "$first_char" \> "1" ]; then
        flag=1
        echo "new system version >1"
    elif [ "$first_char" = "1" ]; then
        if [  "$second_char" \> "2" ]; then
            flag=1
            echo "new system version >2"
        elif [ "$second_char" = "2" ]; then
            if [ "$third_char" \> "6" ]; then
                flag=1
                echo "new system version >6"
            elif [ "$third_char" = "6" ]; then
                flag=1
                echo "new system version = 6"
            else
                echo "old system version < 6"
            fi
        else
            echo "old system version < 2"
        fi
    else
        echo "old system version < 1"
    fi

    if [ "$flag" -eq 1 ]; then
        if [ "$golden_ver_year" != "2024" ]; then
           echo "old golden version need sleep 10"
           sleep 10
        else
          echo "new golden version"
        fi
    else
        echo "old golden version need sleep 10"
        sleep 10
    fi

    setprop persist.rigol.quick_power_on 30
    #fpga_boot_addr=$(getprop persist.rigol.fpga.boot.addr)
    fpga_boot_addr=0x400000
    echo /rigol/tools/spi2boot ${fpga_boot_addr}
    /rigol/tools/spi2boot ${fpga_boot_addr}
    sleep 2
    echo $(getprop persist.rigol/quick_power_on)
    #sleep 1
    setprop persist.rigol.quick_power_on 50
    #sleep 5
    setprop persist.rigol.quick_power_on 60

    echo $(getprop persist.rigol/quick_power_on)

    /rigol/shell/load_pcie.sh
    echo $(getprop persist.rigol/quick_power_on)
    setprop persist.rigol.quick_power_on 70
    echo lspci
    lspci
    #am start -n com.rigol.scope/.MainActivity
    #sleep 5
    setprop persist.rigol.quick_power_on 85
    #sleep 5
    setprop persist.rigol.quick_power_on 100
    #insmod /rigol/driver/motorcomm.ko
    #ifconfig eth0 up
    kill $(pidof com.rigol.launcher) &> /dev/null
    kill $(pidof com.rigol.scope) &> /dev/null
    sleep 10
    am start -n com.rigol.scope/.MainActivity
    sleep 1
    pm enable com.rigol.launcher
    rm -rf /data/logs/tools_log/during_power_onoff
    echo "...... Quick Power On ...... End @ $(date '+%Y.%m.%d %H.%M.%S')"
    echo
}

if [[ -e /data/logs/tools_log/during_power_onoff ]]; then
    echo "Still during in power On/Off ..."
    exit 1
fi

action=$1

if [[ "$action" == "on" ]]; then
    quick_power_on
elif [[ "$action" == "off" ]]; then
    quick_power_off
    echo 0 > /sys/devices/platform/backlight/backlight/backlight/brightness
elif [[ "$action" == "letsplay" ]]; then
	if [ ! -e /data/logs/tools_log/after_quick_off ] ; then
		quick_power_off
	fi
	echo 255 > /sys/devices/platform/backlight/backlight/backlight/brightness
	if [[ $(lsmod | grep "fan_gpio_clt") == "" ]] ; then
		insmod /rigol/driver/fan_gpio_clt.ko
	fi
else
    exit 2
fi

