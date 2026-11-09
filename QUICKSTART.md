# Quickstart: one box, five tips, about 30 minutes

The README quotes the author's own config, with `[...]` where lines were cut.
This page is the runnable version: complete, minimal files you can paste,
going from one empty Debian 13 server to tip 5.

Every command block on this page was run, in order, by an end-to-end test
against a fresh Debian 13 container, with the laptop played by a second user
in the same container. The blocks marked **Not run by the test** need your
own account (Tailscale, or the agent's login) and were not run. The laptop
steps were tested on Debian only; on macOS they need bash, which `ncs` and
the other functions are written for.

## What you need

- **The box:** a Debian 13 server you can ssh into as `root` with your key.
  A small VPS, an old laptop or a Raspberry Pi all work. It never sleeps.
- **Your laptop:** Linux, macOS or WSL, with `ssh` and `tmux`.
- **An agent account:** Claude Code here; Codex is noted where it differs.

Two names are used throughout. `box` is the ssh alias for the server, and
`dev` is the user the agents run as. `<your-box>` is the server's address;
put yours in where it appears.

## 1. The box: a user for the agents (tip 3)

Coding agents are capable, untrusted software. Give them their own user on a
box that holds only code and narrowly scoped tokens. `dev` gets no `sudo`, so
an agent running there cannot change the system.

On the box, as root:

<!-- run: root -->
```bash
apt-get update
apt-get install -y tmux git cron rsync curl jq ca-certificates openssh-server
useradd -m -s /bin/bash dev
install -d -m 700 -o dev -g dev /home/dev/.ssh
install -m 600 -o dev -g dev /root/.ssh/authorized_keys /home/dev/.ssh/authorized_keys
```

Optional: a private network, so the box needs no public ssh port.

<!-- skip: needs your Tailscale account -->
```bash
curl -fsSL https://tailscale.com/install.sh | sh
tailscale up
```

## 2. Your laptop: an ssh alias that notices a dead link (tip 4)

On your laptop. `ServerAliveInterval` times `ServerAliveCountMax` is how long
a silent dead link goes unnoticed: 30 times 3 turns it into an error in 90 to
120 seconds, which the reconnect loop in step 6 acts on.

<!-- run: laptop -->
```bash
mkdir -p ~/.ssh
cat >> ~/.ssh/config <<'EOF'
Host box
  HostName <your-box>
  User dev
  StrictHostKeyChecking accept-new
  ServerAliveInterval 30
  ServerAliveCountMax 3
EOF
chmod 600 ~/.ssh/config
ssh box true && echo "box: connected"
```

## 3. The box: tmux that follows your screen, and a repo tree (tips 2 and 3)

Run the rest of the box steps as `dev`: `ssh box` from your laptop.

The tmux lines size each window to the screen you are using, so moving from a
big monitor to a laptop does not leave a squashed pane. One folder per group,
one repo per folder: the attach helpers in step 5 are generated from this
tree. The two repos here are examples; clone your own instead.

<!-- run: box -->
```bash
cat > ~/.tmux.conf <<'EOF'
set -g window-size latest
set -g aggressive-resize on
set-hook -g client-attached "resize-window -A"
set-hook -g client-resized "resize-window -A"
EOF
mkdir -p ~/repos/personal ~/repos/work
git init -q ~/repos/personal/notes
git init -q ~/repos/work/api
ls -d ~/repos/*/*
```

## 4. The box: the agent, and one check on what it runs (tip 1)

Install the agent as `dev`:

<!-- run: box -->
```bash
curl -fsSL https://claude.ai/install.sh | bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
~/.local/bin/claude --version
```

**Logging in on a box with no browser.** Run `claude` in a terminal on the
box. It prints a login URL: press `c` to copy it, open it in your laptop's
browser, sign in, and paste the code it shows back into the terminal. The
login is saved in `~/.claude/.credentials.json` on the box, readable only by
`dev`.

For scheduled runs (step 7) you can instead make a long-lived token on your
laptop with `claude setup-token` and set it on the box as
`CLAUDE_CODE_OAUTH_TOKEN`, in a file only `dev` can read. That token can make
model requests but cannot start Remote Control sessions. For Codex, the
headless login is `codex login --device-auth`, after turning on device code
sign-in in your ChatGPT security settings.

<!-- skip: needs your agent account -->
```bash
claude
```

Now one check on what the agent runs. A `PreToolUse` hook with the matcher
`Bash` runs before every shell command the agent issues; exiting 2 blocks the
command and tells the agent why. This one blocks a push to `main`, a force
push and `rm -rf` on the root or home directory. Write the checks your own
repos need; the shape is the same.

<!-- run: box -->
```bash
mkdir -p ~/.claude/hooks
cat > ~/.claude/hooks/guard.sh <<'EOF'
#!/usr/bin/env bash
# Runs before every shell command the agent issues; exit 2 blocks it.
cmd=$(jq -r '.tool_input.command // empty')
case "$cmd" in
  *"git push"*" main"* | *"git push"*"--force"* | *"rm -rf /" | *"rm -rf ~"* | *'rm -rf $HOME'*)
    echo "guard: blocked: $cmd" >&2
    exit 2 ;;
esac
exit 0
EOF
chmod +x ~/.claude/hooks/guard.sh
cat > ~/.claude/settings.json <<'EOF'
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [{ "type": "command", "command": "$HOME/.claude/hooks/guard.sh" }]
      }
    ]
  }
}
EOF
echo '{"tool_input":{"command":"git push origin main"}}' | ~/.claude/hooks/guard.sh || echo "exit $?"
```

The last line should print `guard: blocked: git push origin main` and
`exit 2`. This writes a fresh `~/.claude/settings.json`; on a box that
already has one, add the `hooks` block to it instead.

## 5. Your laptop: one alias per repo, generated (tip 2)

A script lists the box's repo tree and writes one alias per repo, named group
dash repo, into `~/.box-sessions`. Cron reruns it every 30 minutes, so a repo
cloned in the morning has an alias by lunch. A repo with a `.no-terminal` file
in it is left out.

<!-- run: laptop -->
```bash
mkdir -p ~/bin
cat > ~/bin/sync-box-sessions.sh <<'EOF'
#!/usr/bin/env bash
# Writes one alias per repo on the box, named group-repo, into ~/.box-sessions.
set -euo pipefail
out="$HOME/.box-sessions"
repos=$(ssh box 'for d in "$HOME"/repos/*/*/; do [ -e "$d.no-terminal" ] || echo "${d%/}"; done')
tmp=$(mktemp "$out.XXXXXX")
while IFS= read -r path; do
  [ -n "$path" ] || continue
  rel=${path#*/repos/}
  name=$(printf '%s' "$rel" | tr 'A-Z/_.' 'a-z---')
  echo "alias $name='ncs $name $path'"
done <<< "$repos" > "$tmp"
mv "$tmp" "$out"
echo "wrote $(wc -l < "$out") aliases to $out"
EOF
chmod +x ~/bin/sync-box-sessions.sh
~/bin/sync-box-sessions.sh
(crontab -l 2>/dev/null || true; echo '*/30 * * * * $HOME/bin/sync-box-sessions.sh >> $HOME/.box-sessions.log 2>&1') | crontab -
cat ~/.box-sessions
```

## 6. Your laptop: the reconnect loop, and restore (tip 4)

`ncs` attaches to the repo's tmux session on the box, creating it if it does
not exist. `-D` detaches every other screen, so whichever machine you sit down
at wins. It is plain `ssh -t` in a loop that branches on the exit status:

- **0** is a detach: yours, or another machine taking the session over. The
  loop cannot tell them apart, so it waits for Enter and never grabs the
  session back on its own. autossh reads a 0 as done and quits, which is why
  this loop is not autossh.
- **255** is ssh itself failing, a dropped link: retry after 5 seconds.
- **66** means the repo's folder is missing on the box. Without that check,
  tmux would quietly start the session in your home directory.

`box-restore` brings every session back after a laptop reboot: one window per
repo in a local tmux server named `box`, each running `ncs`, then attaches.
The agents never stopped on the box, so each window comes back to its running
session. Inside it, press the tmux prefix twice to reach the box's tmux.

<!-- run: laptop -->
```bash
cat >> ~/.bashrc <<'EOF'
# ncs NAME DIR: attach to tmux session NAME on the box, made in DIR; take it over from any other screen.
ncs() {
  local name=$1 dir=$2 rc
  while true; do
    ssh -t box "cd '$dir' 2>/dev/null || exit 66; tmux new-session -A -D -s '$name' -c '$dir'"
    rc=$?
    case $rc in
      0) echo; echo "[ncs] detached, by you or another screen. Enter to re-attach, Ctrl-C to stop."
         read -r || return 0 ;;
      255) echo "[ncs] connection lost. Reconnecting in 5s (Ctrl-C to stop)."
         sleep 5 ;;
      66) echo "[ncs] $dir does not exist on the box."
         return 66 ;;
      *) echo "[ncs] ssh exited $rc. Enter to retry, Ctrl-C to stop."
         read -r || return "$rc" ;;
    esac
  done
}
# box-restore: one local tmux window per box session, each running ncs, then attach.
box-restore() {
  local name dir first=1
  if ! tmux -L box has-session -t box 2>/dev/null; then
    while read -r name dir; do
      if [ "$first" = 1 ]; then
        tmux -L box new-session -d -s box -n "$name" "bash -ic 'ncs $name $dir'"
        first=0
      else
        tmux -L box new-window -t box -n "$name" "bash -ic 'ncs $name $dir'"
      fi
    done < <(sed -n "s/^alias [^=]*='ncs \([^ ]*\) \(.*\)'\$/\1 \2/p" ~/.box-sessions)
  fi
  if [ -t 1 ]; then tmux -L box attach -t box; fi
}
[ -f ~/.box-sessions ] && . ~/.box-sessions
EOF
```

Open a new terminal and type an alias, `personal-notes` for the example repo.
Start an agent in that session with `claude`, detach with the tmux prefix and
`d`, and type the alias again on any other machine: the agent is where you
left it. After a reboot, `box-restore` reopens them all.

On Windows Terminal with WSL, the README's tip 4 generates one terminal
profile per session and a launcher that opens one window per group.

## 7. The box: cron that keeps working while you're on a plane (tip 5)

The schedule belongs on the box, because cron on a laptop stops when its lid
closes. Two entries, in this order:

- At 4:30 a snapshot copies the agent's transcripts into a private git repo.
  `rsync -a` without `--delete`: the agent prunes its own history, and this
  keeps it. Keep that repo private; the transcripts hold everything the
  agents saw.
- At 5:00 a reaper stops tmux sessions idle for more than four days, after
  the snapshot has archived them. Archive first, then anything that removes.

<!-- run: box -->
```bash
mkdir -p ~/bin ~/agent-archive
git -C ~/agent-archive init -q
cat > ~/bin/snapshot-agent-history.sh <<'EOF'
#!/usr/bin/env bash
# Copies agent transcripts into a private git repo. No --delete: keep what the agent prunes.
set -euo pipefail
archive="$HOME/agent-archive"
mkdir -p "$archive/claude"
if [ -d "$HOME/.claude/projects" ]; then rsync -a "$HOME/.claude/projects/" "$archive/claude/"; fi
cd "$archive"
git add -A
if ! git diff --cached --quiet; then
  git -c user.name=snapshot -c user.email=snapshot@box commit -qm "snapshot $(date -u +%F)"
fi
echo "snapshot: $(git rev-list --count HEAD 2>/dev/null || echo 0) commits"
EOF
cat > ~/bin/reap-idle-sessions.sh <<'EOF'
#!/usr/bin/env bash
# Kills tmux sessions with no activity for DAYS days (default 4). Run it after the snapshot.
days=${1:-4}
cutoff=$(( $(date +%s) - days * 86400 ))
tmux list-sessions -F '#{session_activity} #{session_name}' 2>/dev/null |
  while read -r last name; do
    if [ "$last" -lt "$cutoff" ]; then tmux kill-session -t "$name" && echo "reaped $name"; fi
  done
EOF
chmod +x ~/bin/snapshot-agent-history.sh ~/bin/reap-idle-sessions.sh
(crontab -l 2>/dev/null || true; cat <<'EOF'
30 4 * * * $HOME/bin/snapshot-agent-history.sh >> $HOME/cron.log 2>&1
0 5 * * * $HOME/bin/reap-idle-sessions.sh 4 >> $HOME/cron.log 2>&1
EOF
) | crontab -
crontab -l
```

Once the schedule runs without you, a headless agent run is the first agentic
loop. This line runs the agent once a month in one repo, with a one-hour
timeout and a spending cap. Cron does not read `~/.bashrc`, so the run needs
`CLAUDE_CODE_OAUTH_TOKEN` (step 4) set in the crontab or in a file it sources.

<!-- skip: needs your agent account -->
```bash
(crontab -l; echo '0 6 1 * * cd $HOME/repos/personal/notes && timeout 60m $HOME/.local/bin/claude -p "Update the README from the last month of commits, then commit." --max-budget-usd 5 >> $HOME/cron.log 2>&1') | crontab -
```

`--max-budget-usd` stops the run once the agent's own estimate of its spend
crosses the cap, after the step that crossed it, so treat it as a tripwire and
set a hard spending limit on the account as well. Evaluations, better tests
and a goal for each run come after.
