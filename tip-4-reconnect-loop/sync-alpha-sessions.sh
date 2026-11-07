# ABOUTME: Excerpt of ncs, the attach helper: plain ssh in a loop that branches on the exit code.
# ABOUTME: [...] marks skipped lines, or skipped text inside a line. See the README.
    while true; do
        ssh "${ssh_opts[@]}" -t alpha "[...]tmux new-session -A -D -s ${session} -c \"${repo_path}\""
        local rc=$?
        case $rc in
[...]
            0)
                echo
                echo "[ncs] detached cleanly. Press Enter to re-attach, Ctrl-C to exit."
                read -r
                ;;
[...]
            255)
[...]
                    echo "[ncs] connection lost (network/ssh). Reconnecting in 5s... (Ctrl-C to abort)"
                    sleep 5
