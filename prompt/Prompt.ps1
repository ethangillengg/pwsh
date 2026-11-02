# Custom prompt replicating the ethan.omp.json oh-my-posh theme using posh-git
# for git status instead of shelling out to the oh-my-posh binary.
#
# Layout:
#   Line 1 left:  <cyan>path</> <white>on</> <yellow>[</><magenta>branch</><yellow>]</>[<yellow>[</><red>working</> <green>staging</><yellow>]</>][<yellow>[</><cyan>branchStatus</><yellow>]</>]
#   Line 1 right: <lightblack> exec-time</>  <black> time</>
#   Line 2:       <lightGreen|red>❯</> (trailing space)

function Get-ShortPromptPath {
    $path = $PWD.ProviderPath
    $homeDir = $HOME.TrimEnd('\')
    if ($path -eq $homeDir) { return '~' }
    if ($path.StartsWith($homeDir + '\')) { $path = '~' + $path.Substring($homeDir.Length) }

    $parts = $path -split '\\'
    if ($parts.Count -le 3) { return ($parts -join '\') }

    # "mixed" style: keep first and last segment full, abbreviate the rest to their first character
    $middle = $parts[1..($parts.Count - 2)] | ForEach-Object { $_.Substring(0, 1) }
    return (@($parts[0]) + $middle + @($parts[-1])) -join '\'
}

function Format-LocalChanges {
    param($Changes)
    $parts = @()
    if ($Changes.Added.Count -gt 0) { $parts += "+$($Changes.Added.Count)" }
    if ($Changes.Modified.Count -gt 0) { $parts += "~$($Changes.Modified.Count)" }
    if ($Changes.Deleted.Count -gt 0) { $parts += "-$($Changes.Deleted.Count)" }
    if ($Changes.Unmerged.Count -gt 0) { $parts += "!$($Changes.Unmerged.Count)" }
    return ($parts -join ' ')
}

function Format-BranchStatus {
    param($Status)
    if ($Status.AheadBy -gt 0 -and $Status.BehindBy -gt 0) { return "↑$($Status.AheadBy) ↓$($Status.BehindBy)" }
    if ($Status.AheadBy -gt 0) { return "↑$($Status.AheadBy)" }
    if ($Status.BehindBy -gt 0) { return "↓$($Status.BehindBy)" }
    return ''
}

function Find-DotGit {
    $dir = $PWD.ProviderPath
    while ($dir) {
        $g = [System.IO.Path]::Combine($dir, '.git')
        if ([System.IO.Directory]::Exists($g) -or [System.IO.File]::Exists($g)) { return $g }
        $dir = [System.IO.Path]::GetDirectoryName($dir)
    }
}

# Reads the branch straight from HEAD (no git process); handles worktrees where .git is a file.
function Get-GitBranchFromHead {
    param([string]$DotGit)
    if ([System.IO.File]::Exists($DotGit)) {
        $gitdir = ([System.IO.File]::ReadAllText($DotGit)).Trim()
        if (-not $gitdir.StartsWith('gitdir: ')) { return }
        $DotGit = [System.IO.Path]::GetFullPath($gitdir.Substring(8), [System.IO.Path]::GetDirectoryName($DotGit))
    }
    $headFile = [System.IO.Path]::Combine($DotGit, 'HEAD')
    if (-not [System.IO.File]::Exists($headFile)) { return }
    $head = ([System.IO.File]::ReadAllText($headFile)).Trim()
    if ($head.StartsWith('ref: refs/heads/')) { return $head.Substring(16) }
    if ($head.Length -ge 7) { return $head.Substring(0, 7) }
}

function ConvertFrom-GitStatusLines {
    param([string[]]$lines)
    if (-not $lines) { return $null }

    $s = @{ Branch = ''; AheadBy = 0; BehindBy = 0
        Working = @{ Added = @(); Modified = @(); Deleted = @(); Unmerged = @() }
        Index = @{ Added = @(); Modified = @(); Deleted = @(); Unmerged = @() } }
    $oid = ''
    foreach ($l in $lines) {
        switch -CaseSensitive ($l[0]) {
            '#' {
                if ($l.StartsWith('# branch.head ')) { $s.Branch = $l.Substring(14) }
                elseif ($l.StartsWith('# branch.oid ')) { $oid = $l.Substring(13, 7) }
                elseif ($l -match '^# branch\.ab \+(\d+) -(\d+)') { $s.AheadBy = [int]$Matches[1]; $s.BehindBy = [int]$Matches[2] }
            }
            '?' { $s.Working.Added += 1 }
            'u' { $s.Working.Unmerged += 1 }
            { $_ -in '1', '2' } {
                switch -CaseSensitive ($l[2]) { 'A' { $s.Index.Added += 1 } 'D' { $s.Index.Deleted += 1 } '.' {} default { $s.Index.Modified += 1 } }
                switch -CaseSensitive ($l[3]) { 'D' { $s.Working.Deleted += 1 } '.' {} default { $s.Working.Modified += 1 } }
            }
        }
    }
    if ($s.Branch -eq '(detached)') { $s.Branch = $oid }
    $s.HasWorking = [bool]($s.Working.Values | Where-Object Count)
    $s.HasIndex = [bool]($s.Index.Values | Where-Object Count)
    return [pscustomobject]$s
}

function Get-GitSegment {
    param([string[]]$Lines, [string]$Branch)
    $status = if ($Lines) { ConvertFrom-GitStatusLines $Lines } elseif ($Branch) { [pscustomobject]@{ Branch = $Branch; HasWorking = $false; HasIndex = $false; AheadBy = 0; BehindBy = 0 } }
    if (-not $status) { return '' }

    $magenta = $PSStyle.Foreground.Magenta
    $white = $PSStyle.Foreground.White
    $yellow = $PSStyle.Foreground.Yellow
    $red = $PSStyle.Foreground.Red
    $green = $PSStyle.Foreground.Green
    $cyan = $PSStyle.Foreground.Cyan
    $reset = $PSStyle.Reset

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.Append("${white}on${reset} ${yellow}[${reset}${magenta}$($status.Branch)${reset}${yellow}]${reset}")

    $workingChanged = $status.HasWorking
    $stagingChanged = $status.HasIndex
    if ($workingChanged -or $stagingChanged) {
        $workingStr = Format-LocalChanges $status.Working
        $stagingStr = Format-LocalChanges $status.Index
        [void]$sb.Append("${yellow}[${reset}${red}${workingStr}${reset}")
        if ($workingChanged -and $stagingChanged) { [void]$sb.Append(' ') }
        [void]$sb.Append("${green}${stagingStr}${reset}${yellow}]${reset}")
    }

    $branchStatus = Format-BranchStatus $status
    if ($branchStatus) {
        [void]$sb.Append("${yellow}[${reset}${cyan}${branchStatus}${reset}${yellow}]${reset}")
    }

    return $sb.ToString()
}

function Get-VisibleLength {
    param([string]$Text)
    return ([regex]::Replace($Text, "`e\[[0-9;]*m", '')).Length
}

function Format-PromptLine1 {
    param([string]$Left, [string]$Right, [int]$Width)
    $padding = $Width - (Get-VisibleLength $Left) - (Get-VisibleLength $Right)
    if ($padding -lt 1) { $padding = 1 }
    return "$Left$(' ' * $padding)$Right"
}

# Rows between the first prompt line and the cursor, accounting for typed text that wraps or has newlines.
function Get-RowsAbovePromptLine1 {
    param([int]$Width)
    $buf = $null; $cur = 0
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$buf, [ref]$cur)
    $row = 1; $col = 2
    for ($i = 0; $i -lt $cur; $i++) {
        if ($buf[$i] -eq "`n") { $row++; $col = 0; continue }
        if (++$col -ge $Width) { $row++; $col = 0 }
    }
    return $row
}

# Runs git status in the background; when it finishes (and the prompt is still the current one)
# the first prompt line is redrawn in place with the git segment.
function Update-PromptGitSegment {
    param($d)
    try {
        $d.Proc.WaitForExit()
        if ($global:__promptId -eq $d.Id -and $d.Proc.ExitCode -eq 0) {
            $segment = Get-GitSegment ($d.Task.Result -split "`n")
            if ($segment) {
                $width = $Host.UI.RawUI.WindowSize.Width
                $line = Format-PromptLine1 ($d.PathSegment + $segment) $d.Right $width
                $up = Get-RowsAbovePromptLine1 $width
                [Console]::Write("`e7`e[${up}A`r$line`e8")
            }
        }
    } finally {
        $d.Proc.Dispose()
    }
}

function Start-AsyncGitStatus {
    param([int]$Id, [string]$PathSegment, [string]$Right)
    $psi = [System.Diagnostics.ProcessStartInfo]::new('C:\Program Files\Git\mingw64\bin\git.exe')
    foreach ($a in 'status', '--porcelain=v2', '--branch') { $psi.ArgumentList.Add($a) }
    $psi.WorkingDirectory = $PWD.ProviderPath
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $proc = [System.Diagnostics.Process]::new()
    $proc.StartInfo = $psi
    $proc.EnableRaisingEvents = $true
    $data = @{ Id = $Id; PathSegment = $PathSegment; Right = $Right; Proc = $proc; Clock = [System.Diagnostics.Stopwatch]::StartNew() }
    $null = Register-ObjectEvent -InputObject $proc -EventName Exited -MessageData $data -Action {
        $d = $Event.MessageData
        try {
            # Events can be processed before the prompt is on screen (e.g. at startup); defer so the redraw doesn't land on an empty screen
            $remaining = 150 - $d.Clock.ElapsedMilliseconds
            if ($remaining -gt 0) {
                $timer = [System.Timers.Timer]::new($remaining)
                $timer.AutoReset = $false
                $null = Register-ObjectEvent -InputObject $timer -EventName Elapsed -MessageData $d -Action {
                    try { Update-PromptGitSegment $Event.MessageData }
                    finally {
                        $Sender.Dispose()
                        Unregister-Event -SubscriptionId $EventSubscriber.SubscriptionId
                        Remove-Job -Id $EventSubscriber.Action.Id -Force
                    }
                }
                $timer.Start()
            } else {
                Update-PromptGitSegment $d
            }
        } finally {
            Unregister-Event -SubscriptionId $EventSubscriber.SubscriptionId
            Remove-Job -Id $EventSubscriber.Action.Id -Force
        }
    }
    [void]$proc.Start()
    $data.Task = $proc.StandardOutput.ReadToEndAsync()
    $null = $proc.StandardError.ReadToEndAsync()
}

function prompt {
    $previousCommandFailed = -not $?
    $cyan = $PSStyle.Foreground.Cyan
    $lightBlack = $PSStyle.Foreground.BrightBlack
    $black = $PSStyle.Foreground.Black
    $lightGreen = $PSStyle.Foreground.BrightGreen
    $red = $PSStyle.Foreground.Red
    $reset = $PSStyle.Reset

    # Left side: path now, git segment is filled in asynchronously
    $left = "${cyan}$(Get-ShortPromptPath)${reset} "

    # Right side: last command execution time (if over 10ms) + current time
    $right = ''
    $lastCmd = Get-History -Count 1
    if ($lastCmd) {
        $ms = ($lastCmd.EndExecutionTime - $lastCmd.StartExecutionTime).TotalMilliseconds
        if ($ms -gt 10) {
            $formattedMs = if ($ms -ge 1000) { "{0:N1}s" -f ($ms / 1000) } else { "{0:N0}ms" -f $ms }
            $right += "${lightBlack} $([char]0xf252) ${formattedMs} ${reset}"
        }
    }
    $timeStr = Get-Date -Format "h:mm:ss tt"
    $right += "${black} ${timeStr} $([char]0xf017) ${reset}"

    $width = $Host.UI.RawUI.WindowSize.Width
    $global:__promptId++
    $dotGit = Find-DotGit
    $line1Left = $left
    if ($dotGit) {
        Start-AsyncGitStatus $global:__promptId $left $right
        $line1Left += Get-GitSegment -Branch (Get-GitBranchFromHead $dotGit)
    }

    $arrowColor = if ($previousCommandFailed) { $red } else { $lightGreen }
    $null = Get-Variable -Name PSVersionTable
    return "$(Format-PromptLine1 $line1Left $right $width)`n${arrowColor}❯${reset} "
}
