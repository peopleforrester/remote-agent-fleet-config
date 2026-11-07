# ABOUTME: Excerpt of the sync script: one alias per repo under ~/repos/<group>/<repo>, named group-repo.
# ABOUTME: [...] marks skipped lines, or skipped text inside a line. See the README.
    # Alias format: group-reponame [...]
    alias_name="${norm_group}-${norm_leaf}"

    # Session name matches alias name for simplicity
    session_name="${alias_name}"
[...]
    ALIASES+=("alias ${alias_name}='ncs ${session_name} ${repo_path}'")
