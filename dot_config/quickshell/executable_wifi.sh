echo "hello"
iw event | while read -r event; do
    iwctl station wlan0 show | grep -w 'RSSI' | awk '{print $2}' > /tmp/wifi_rssi
done
