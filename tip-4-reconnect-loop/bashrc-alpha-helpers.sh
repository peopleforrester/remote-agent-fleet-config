# ABOUTME: Excerpt of the WSL .bashrc helper: restore reopens every tab, attached.
# ABOUTME: [...] marks skipped lines, or skipped text inside a line. See the README.
restore() {
    local ps1="${WIN_SCRIPTS}/restore-workflow.ps1"
[...]
    powershell.exe -ExecutionPolicy Bypass -File "C:\\Users\\${WIN_USER}\\Scripts\\restore-workflow.ps1" -Force
}
