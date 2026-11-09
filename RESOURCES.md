# Resources

Official pages for the tools the talk uses, and for the hosted options a
listener will compare it with. Each link was opened and read on 2026-11-09.

## The tools in the talk

- **tmux**, the terminal multiplexer every agent session runs in: https://github.com/tmux/tmux
- **autossh**, the usual reconnect wrapper for ssh, and why tip 4 does not use it for contested sessions: https://www.harding.motd.ca/autossh/
- **Tailscale**, a private network between your machines, so the box needs no public ssh port: https://tailscale.com/kb/1017/install
- **mosh**, the alternative to the reconnect loop: it keeps a terminal alive across roaming and sleep, over UDP: https://mosh.org/
- **asciinema**, which recorded the talk's terminal clips: https://docs.asciinema.org/
- **Claude Code hooks**, the `PreToolUse` and `Stop` checks in tip 1: https://code.claude.com/docs/en/hooks
- **Claude Code login on a machine without a browser**, `claude setup-token` and `CLAUDE_CODE_OAUTH_TOKEN`: https://code.claude.com/docs/en/authentication
- **Codex CLI login with a device code**, `codex login --device-auth`: https://learn.chatgpt.com/docs/auth

## Hosted options to compare with

These run or reach agents without a box of your own. The talk's setup trades
their convenience for one machine you control, any agent CLI, and sessions
that outlive any single vendor's connection.

- **Claude Code Remote Control**, which continues a local Claude Code session from a phone or browser: https://code.claude.com/docs/en/remote-control
- **Codex cloud**, which runs Codex tasks in OpenAI's cloud environments: https://developers.openai.com/codex/cloud
- **Cursor Cloud Agents**, formerly background agents, each on its own virtual machine: https://cursor.com/docs/cloud-agent
