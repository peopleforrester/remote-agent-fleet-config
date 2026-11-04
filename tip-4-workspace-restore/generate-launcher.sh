# ABOUTME: Excerpt of the generator that writes restore-workflow.ps1, one window per group.
# ABOUTME: [...] marks skipped lines, or skipped text inside a line. See the README.
        echo "# --- ${display_name} (${#sessions[@]} tabs) ---"

        # Build the argument list: first session is new-tab, rest are ; new-tab
        echo -n 'Start-Process wt.exe -ArgumentList @('
