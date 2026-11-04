# ABOUTME: Excerpt of the generator that writes one Windows Terminal profile per session.
# ABOUTME: [...] marks skipped lines, or skipped text inside a line. See the README.
    cmd="wsl.exe -d ${WSL_DISTRO} -- bash -ic 'ncs ${session_name} ${repo_path}'"
