# ABOUTME: Excerpt of the nightly snapshot of agent transcripts into a private git repo.
# ABOUTME: [...] marks skipped lines, or skipped text inside a line. See the README.
# Accumulate. NO --delete: the whole point is to KEEP histories that Anthropic prunes
# out of ~/.claude. Files that disappear upstream stay preserved here.
rsync -a "$SRC" "$LIVE/" 2>>"$LOG"
