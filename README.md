# Running coding agents remotely: the config

The config excerpts from the KubeCon + CloudNativeCon North America 2026
Tip Talk "A Hundred Agent Sessions on One Box: Tips for Running Coding Agents
Remotely", by Michael Rishi Forrester. Each tip has a section here and a
folder of excerpt files.

The setup they come from: coding agents (Claude Code, Codex, Antigravity CLI) run in
tmux on one always-on Linux host, one tmux session per repo. Workstations are
thin clients that attach over ssh from Windows Terminal and WSL. The machines
are labeled as on the slides: **alpha** is the always-on host, **beta** and
**right** are the workstations.

## Reading the excerpts

- These are excerpts, not drop-in scripts. `[...]` marks skipped lines, or
  skipped text inside a line, so what remains is quoted as it runs.
- Each file opens with two comment lines saying what it is. Everything after
  them is the excerpt.
- Paths under `/home/michael` are the author's; put your own home and repo
  tree in their place.

## Tip 1: Get really good at one workflow before you run a hundred

### What it fixes

A hundred agents multiply whatever one agent does, mistakes included. Get one
repo's workflow right first: rules in a file the agent reads, CI on every push,
and hooks that check what the agent does as it does it.

### The excerpt

[`tip-1-one-workflow/settings.json`](tip-1-one-workflow/settings.json)

```json
        "matcher": "Bash",
[...]
            "command": "$HOME/.claude/hooks/check-commit-message.sh"
[...]
    "Stop": [
[...]
            "command": "$HOME/.claude/hooks/auto-test-on-stop.sh"
```

### How to adapt it

- These are Claude Code hooks in `~/.claude/settings.json`. A `PreToolUse`
  hook with the matcher `Bash` runs before every shell command the agent
  issues, and can block it.
- `check-commit-message.sh` refuses a commit message that credits the AI.
  Write the checks your own repos need; the shape is the same.
- A `Stop` hook runs when the agent finishes; running the tests there catches
  a break before you look.
- Where a command-line tool exists, prefer it to an MCP server. Each agent
  session starts its own copy of every stdio MCP server it is configured
  with, so a hundred sessions run a hundred copies.

## Tip 2: Give your work a shape the tools can read

### What it fixes

**Attach helpers generated from the repo tree.** Group repos by what they
belong to: start with two folders, personal and
professional, and let the tree grow. With one tmux session per repo there are a hundred sessions, and nobody
should be typing their names or keeping a list of them by hand. A list kept by
hand is wrong by the next clone.

### The excerpt

[`tip-2-attach-helpers/sync-alpha-sessions.sh`](tip-2-attach-helpers/sync-alpha-sessions.sh)

```bash
    # Alias format: group-reponame [...]
    alias_name="${norm_group}-${norm_leaf}"

    # Session name matches alias name for simplicity
    session_name="${alias_name}"
[...]
    ALIASES+=("alias ${alias_name}='ncs ${session_name} ${repo_path}'")
```

[`tip-2-attach-helpers/alpha-sessions`](tip-2-attach-helpers/alpha-sessions)

```bash
alias portfolio-agentic-covenants='ncs portfolio-agentic-covenants /home/michael/repos/portfolio/agentic-covenants'
```

[`tip-2-attach-helpers/crontab`](tip-2-attach-helpers/crontab)

```cron
*/30 * * * * /home/michael/scripts/sync-alpha-sessions.sh [...]
```

### How to adapt it

- Keep repos in one tree on the host, a group directory and then the repo:
  `~/repos/<group>/<repo>`. The script lists that tree over ssh from the
  client and writes one alias per repo, named group dash repo, into a file
  that `.bashrc` sources.
- Every alias calls the same function, `ncs`, with the session name and the
  repo path (tip 4). The tmux session has the alias's name, so the alias,
  the session and tab completion all read one list.
- Run the script from cron on each client, as the crontab line does every
  30 minutes, so a repo cloned in the morning has an alias by lunch.
- Leave a directory out by dropping a `.no-terminal` file in it.

## Tip 3: Get your agents off your laptop

### What it fixes

**tmux settings that follow whichever screen you're on.** Coding agents are
capable, untrusted software. Give them a box that holds only
the code, not your browser sessions and saved logins: a server, an old
laptop running Debian, or a Raspberry Pi, on a private network such as
Tailscale. It never sleeps, and every screen becomes a thin client.

Moving from a big desktop monitor to a laptop leaves a squashed pane or a
field of dots, because the window keeps the size of the other screen.

### The excerpt

[`tip-3-tmux-follows-screen/tmux.conf`](tip-3-tmux-follows-screen/tmux.conf)

```tmux
set -g window-size latest
set -g aggressive-resize on
[...]
set-hook -g client-attached "resize-window -A"
[...]
set-hook -g client-resized "resize-window -A"
```

### How to adapt it

- These lines go in `~/.tmux.conf` on the host. Reload with
  `tmux source-file ~/.tmux.conf`. They were checked on tmux 3.5a.
- `window-size latest` sizes each window to the client with the most recent
  activity, and `aggressive-resize on` applies that per window instead of per
  session.
- Both hooks run `resize-window -A`, which fits the largest attached client:
  `client-attached` on every attach, `client-resized` when an attached
  client's terminal changes size. Keep both. `resize-window` switches the
  window to a manual size, so with only the attach hook a window stays at the
  size it had on attach.
- Attaching with `-D` (tip 2) leaves one client per session, so the largest
  attached client is the screen in front of you.

## Tip 4: Connection management you never have to think about

### What it fixes

**A reconnect loop that beats autossh, and one-command workspace restore.**
`tmux new-session -A -D -s <name>` attaches the session if it exists and
creates it if it does not, and `-D` detaches every other client, so whichever
machine you sit down at wins. On tmux 3.5a the machine that loses sees its
tmux client exit 0, exactly like a detach you asked for. autossh reads a 0
exit as done and quits, so that machine's tab is gone when you walk back to
it. The one exit worth retrying without you is a dead link.

Reboots happen, and reopening a hundred tabs by hand does not. The agents
never stopped on the host, so every tab should come back attached to its
running session.

### The excerpt

[`tip-4-reconnect-loop/sync-alpha-sessions.sh`](tip-4-reconnect-loop/sync-alpha-sessions.sh)

```bash
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
```

[`tip-4-reconnect-loop/ssh-config`](tip-4-reconnect-loop/ssh-config)

```ssh-config
Host alpha
[...]
  ServerAliveInterval 30
  ServerAliveCountMax 3
```

[`tip-4-reconnect-loop/generate-terminal-profiles.sh`](tip-4-reconnect-loop/generate-terminal-profiles.sh)

```bash
    cmd="wsl.exe -d ${WSL_DISTRO} -- bash -ic 'ncs ${session_name} ${repo_path}'"
```

[`tip-4-reconnect-loop/generate-launcher.sh`](tip-4-reconnect-loop/generate-launcher.sh)

```bash
        echo "# --- ${display_name} (${#sessions[@]} tabs) ---"

        # Build the argument list: first session is new-tab, rest are ; new-tab
        echo -n 'Start-Process wt.exe -ArgumentList @('
```

[`tip-4-reconnect-loop/bashrc-alpha-helpers.sh`](tip-4-reconnect-loop/bashrc-alpha-helpers.sh)

```bash
restore() {
    local ps1="${WIN_SCRIPTS}/restore-workflow.ps1"
[...]
    powershell.exe -ExecutionPolicy Bypass -File "C:\\Users\\${WIN_USER}\\Scripts\\restore-workflow.ps1" -Force
}
```

### How to adapt it

- Use plain `ssh -t` in a loop and branch on its exit status. `alpha` is the
  host's alias in `~/.ssh/config`; use yours.
- 0 is a detach, yours or another machine taking over, and the loop cannot
  tell them apart. It waits for Enter and never grabs the session back on
  its own.
- 255 is ssh itself failing: a dropped link. Retry after 5 seconds.
- The skipped branches wait for Enter on 1 or 130 and on anything
  unexpected. The skipped part of the remote command exits 66 instead of
  creating a session whose directory is missing, because tmux would quietly
  start it in `$HOME`; the loop then stops.
- `ServerAliveInterval` times `ServerAliveCountMax` is how long a silent dead
  link goes unnoticed: 30 times 3 turns it into a 255 in 90 to 120 seconds.
- autossh is still right for a single catch-all session where nothing
  competes for it.
- This is for Windows Terminal with WSL. Each generated profile runs `ncs`
  for its session through `bash -ic`, so `.bashrc`, and with it the aliases
  and `ncs` from tips 2 and 4, is loaded. Set `WSL_DISTRO` to your
  distribution.
- The same tree walk writes `restore-workflow.ps1`: one
  `Start-Process wt.exe` per group, so one window per group, with one
  `new-tab` per repo.
- A startup shortcut runs the script at login. Without `-Force` it skips
  itself when Windows Terminal is already running, so crash recovery does not
  open every window twice. `restore` passes `-Force` to run it on demand.
  `WIN_SCRIPTS` and `WIN_USER` point at the Windows side.
- On another terminal, keep the idea: generate one tab per session from the
  same list, and make each tab run `ncs`.

## Tip 5: Then go further: loops, evals and goals

### What it fixes

**Cron-driven orchestration that keeps working while you're on a plane.**
If the host never sleeps, the schedule belongs on the host, not on a laptop
in an overhead bin. Cron on a workstation stops when its lid closes. Once the schedule runs without you, a headless
agent run with a cost cap is the first agentic loop; evaluations, better
tests and goals for each run come after.

### The excerpt

[`tip-5-cron-on-the-box/crontab`](tip-5-cron-on-the-box/crontab)

```cron
# Daily durable snapshot of ~/.claude/projects (Anthropic prunes it)
30 4 * * * /home/michael/scripts/claude-session-snapshot.sh [...]
[...]
# Stop agent sessions idle >4d. Runs after the 4:30 snapshot so transcripts are archived first.
0 5 * * * [...] ${R1}/scripts/reap-idle-sessions.sh --apply [...]
[...]
# [...] monthly workflow refresh [...]
# claude -p with a $25 cap and 60 min timeout; commits to staging, exits 1 without committing on any failure.
0 6 1 * * [...] uv run wk refresh [...]
```

[`tip-5-cron-on-the-box/claude-session-snapshot.sh`](tip-5-cron-on-the-box/claude-session-snapshot.sh)

```bash
# Accumulate. NO --delete: the whole point is to KEEP histories that Anthropic prunes
# out of ~/.claude. Files that disappear upstream stay preserved here.
rsync -a "$SRC" "$LIVE/" 2>>"$LOG"
```

### How to adapt it

- These lines go in the host's crontab (`crontab -e`). The skipped text is
  environment setup and log redirection.
- At 4:30 the snapshot copies the agent transcripts in `~/.claude/projects`
  into a private git repo with `rsync -a` and no `--delete`, because the tool
  prunes its own history. Keep that repo private: the transcripts hold
  everything the agents saw.
- At 5:00 the reaper stops agent sessions idle for more than four days, after
  the snapshot has archived them. Order your entries the same way: archive
  first, then anything that removes.
- Once a month a headless agent run (`claude -p`) refreshes notes with a cost
  cap and a timeout, and commits to a staging branch or not at all.

## License

MIT. See `LICENSE`.
