# Fuzzy git-add widget (ported from a zsh ZLE widget of the same name).
# Bound to Ctrl+f: fuzzy-select changed files from `git status` with a diff
# preview, then insert their (quoted) paths at the cursor -- e.g. type
# `git add ` then press Ctrl+f to fill in the files to add.

. "$PSScriptRoot\Fzf-GitAddHelpers.ps1"

# Preview renders via Git for Windows' bash (not pwsh/WSL): a fresh Git bash
# process starts in ~30-150ms vs. pwsh's ~500ms+ and WSL's multi-second cold
# start, which matters since fzf re-runs the preview on every highlight change.
$script:GitBashPath = "C:\Program Files\Git\bin\bash.exe"

function ConvertTo-PosixPath {
    param([string]$Path)
    $Path = $Path -replace '\\', '/'
    if ($Path -match '^([A-Za-z]):(.*)$') {
        return "/" + $Matches[1].ToLower() + $Matches[2]
    }
    return $Path
}

function Invoke-FzfGitAdd {
    $previewScript = ConvertTo-PosixPath "$PSScriptRoot\git-diff-preview.sh"
    $selected = git -c color.status=always status --short |
        fzf -m --ansi --preview "`"$script:GitBashPath`" `"$previewScript`" {}" --preview-window '65%'

    if (-not $selected) { return }

    $paths = $selected | ForEach-Object { Get-GitStatusPathFromFzfLine $_ } | Where-Object { $_ }
    if (-not $paths) { return }

    $quoted = ($paths | ForEach-Object { '"' + $_ + '"' }) -join ' '
    [Microsoft.PowerShell.PSConsoleReadLine]::Insert(" $quoted")
}

Set-PSReadLineKeyHandler -Chord 'Ctrl+f' -BriefDescription 'FzfGitAdd' `
    -Description 'Fuzzy-select changed git files (with diff preview) and insert quoted paths at the cursor' `
    -ScriptBlock { Invoke-FzfGitAdd }
