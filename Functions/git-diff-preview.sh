#!/usr/bin/env bash
# Fast preview for the PowerShell fzf-gitadd-widget: renders a diff (via
# delta) for the file referenced by a `git status --short` line, or the
# whole file highlighted green if it's untracked/has no diff.
#
# Run via Git for Windows' bash (not pwsh) so fzf's per-highlight preview
# re-render doesn't pay PowerShell's ~500ms+ process startup cost each time.

FILE_PATH=$(echo "$1" | cut -c4- | sed 's/.* -> //')

DIFF=$(git diff HEAD --color=always -- "$FILE_PATH")
if [[ $DIFF ]]; then
    echo "$FILE_PATH"
    echo "$DIFF" | delta --paging=never
else
    RESET="\033[0m"
    GREEN="\033[32m"
    echo "$FILE_PATH"
    while IFS= read -r line; do
        echo -e "$GREEN$line$RESET"
    done < "$FILE_PATH"
fi
