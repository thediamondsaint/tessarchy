if [[ $(tty 2>/dev/null) == /dev/tty1 ]]; then
    exec /usr/bin/tessarchy-netinstall
fi
