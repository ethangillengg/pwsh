# Custom prompt replicating the ethan.omp.json oh-my-posh theme using posh-git
# for git status instead of shelling out to the oh-my-posh binary.
#
# Layout:
#   Line 1 left:  <cyan>path</> <white>on</> <yellow>[</><magenta>branch</><yellow>]</>[<yellow>[</><red>working</> <green>staging</><yellow>]</>][<yellow>[</><cyan>branchStatus</><yellow>]</>]
#   Line 1 right: <lightblack> exec-time</>  <black> time</>
#   Line 2:       <lightGreen>❯</> (trailing space)

function Get-PromptPath {
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

function Get-GitSegment {
    $status = Get-GitStatus
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

function prompt {
    $cyan = $PSStyle.Foreground.Cyan
    $lightBlack = $PSStyle.Foreground.BrightBlack
    $black = $PSStyle.Foreground.Black
    $lightGreen = $PSStyle.Foreground.BrightGreen
    $reset = $PSStyle.Reset

    # Left side: path + git segment
    $pathSegment = "${cyan}$(Get-PromptPath)${reset} "
    $gitSegment = Get-GitSegment
    $left = $pathSegment + $gitSegment

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
    $leftLen = Get-VisibleLength $left
    $rightLen = Get-VisibleLength $right
    $padding = $width - $leftLen - $rightLen
    if ($padding -lt 1) { $padding = 1 }

    return "$left$(' ' * $padding)$right`n${lightGreen}❯${reset} "
}
