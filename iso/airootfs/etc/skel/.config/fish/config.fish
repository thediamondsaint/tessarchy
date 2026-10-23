# Start the live session once from an interactive tty1 login.
set -g fish_greeting

if status is-interactive
    if test (tty) = /dev/tty1
        if not set -q DISPLAY; and not set -q WAYLAND_DISPLAY
            printf '\nTessarchy live image — no secure locking, no persistence.\n'
            printf 'Starting Tessa. After exit, run start-tessarchy to start again.\n'
            start-tessarchy
        end
    end
    abbr -a tessarchy 'start-tessarchy'
    abbr -a ll 'ls -lah'
end
