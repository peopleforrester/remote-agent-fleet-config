# Cheat sheet: a hundred agent sessions on one box

The five tips as commands. The full, tested setup is in `QUICKSTART.md`.

## 1. Structure your work

```bash
~/repos/<group>/<repo>                 # one tree on the box
~/bin/sync-box-sessions.sh             # one alias per repo, named group-repo
*/30 * * * * $HOME/bin/sync-box-sessions.sh >> $HOME/.box-sessions.log 2>&1
touch ~/repos/<group>/<repo>/.no-terminal   # leave a repo out
```

## 2. Master one workflow

```bash
# A check before every shell command the agent runs: exit 2 blocks it.
~/.claude/settings.json   ->  hooks.PreToolUse  matcher "Bash"  command "$HOME/.claude/hooks/guard.sh"
echo '{"tool_input":{"command":"git push origin main"}}' | ~/.claude/hooks/guard.sh || echo "exit $?"
```

## 3. Move to one box

```bash
useradd -m -s /bin/bash dev            # the agents' own user, no sudo
set -g window-size latest              # ~/.tmux.conf on the box
set -g aggressive-resize on
set-hook -g client-attached "resize-window -A"
set-hook -g client-resized "resize-window -A"
```

## 4. Automate your connections

```bash
ServerAliveInterval 30                 # ~/.ssh/config: a dead link is found in 90 to 120 s
ServerAliveCountMax 3
ssh -t box "tmux new-session -A -D -s <name> -c <dir>"   # attach or create, take over
# ncs loops on that: 0 = detached, wait for Enter; 255 = link dropped, retry in 5 s
box-restore                            # every session back after a reboot
```

## 5. Dispatch the work

```bash
30 4 * * * $HOME/bin/snapshot-agent-history.sh >> $HOME/cron.log 2>&1   # archive first
0 5 * * * $HOME/bin/reap-idle-sessions.sh 4 >> $HOME/cron.log 2>&1      # then remove
claude -p "<task>" --max-budget-usd 5  # a headless run with a cap, from cron
```
