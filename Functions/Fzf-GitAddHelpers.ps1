function Get-GitStatusPathFromFzfLine {
    <#
    .SYNOPSIS
        Extracts the file path from a `git status --short` line as shown by fzf.
    #>
    param([string]$Line)
    if ([string]::IsNullOrWhiteSpace($Line)) { return $null }

    # `git status --short` lines are "XY path" (2 status chars + space + path)
    $rest = $Line.Substring(3)

    # Renames look like "old -> new"; use the new path
    if ($rest -match '^.+? -> (?<new>.+)$') {
        return $Matches.new.Trim()
    }

    return $rest.Trim()
}
