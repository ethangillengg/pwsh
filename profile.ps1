# Profiling: set $env:PROFILE_TIMING = "1" before launching pwsh to print a
# breakdown of how long each profile step takes on startup.
if ($env:PROFILE_TIMING) {
    $script:__profileSw = [System.Diagnostics.Stopwatch]::StartNew()
    $script:__profileLast = 0
    function __ProfileMark {
        param([string]$Name)
        $elapsed = $script:__profileSw.ElapsedMilliseconds
        $delta = $elapsed - $script:__profileLast
        $script:__profileLast = $elapsed
        Write-Host ("[profile] {0,-28} {1,5} ms  (total {2,5} ms)" -f $Name, $delta, $elapsed) -ForegroundColor DarkGray
    }
} else {
    function __ProfileMark { param([string]$Name) }
}

__ProfileMark "start"

Import-Module posh-git
__ProfileMark "Import-Module posh-git"

# Custom prompt
. "$PSScriptRoot\prompt\Prompt.ps1"
__ProfileMark "prompt\Prompt.ps1"

# OLD oh-my-posh prompt
# oh-my-posh init pwsh --config ~/.config/omp/ethan.omp.json  | Invoke-Expression

Invoke-Expression (& { (zoxide init powershell | Out-String) })
__ProfileMark "zoxide init"

# Readline Options
Set-PsReadLineOption -EditMode Vi
set-PSReadLineKeyHandler -Chord 'Ctrl+e' -Function ViEditVisually
__ProfileMark "PSReadLine options"

# IMPORTANT: This has to be after PSReadLineOptions
# PSFzf's module import alone costs ~450-500ms (measured), dominating startup.
# Defer it to the first idle moment (i.e. right after the first prompt is
# shown) so the shell feels ready immediately; Ctrl+T/Ctrl+R become live a
# moment later instead of blocking startup.
Register-EngineEvent -SourceIdentifier PowerShell.OnIdle -MaxTriggerCount 1 -Action {
    Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
    Unregister-Event -SourceIdentifier PowerShell.OnIdle -ErrorAction SilentlyContinue
} | Out-Null
__ProfileMark "Set-PsFzfOption (deferred registration)"


# Environment variables
$ENV:EDITOR = "nvim"
$ENV:STARSHIP_CONFIG = "$HOME\.config\starship\starship.toml"
$Env:KOMOREBI_CONFIG_HOME = "$HOME\.config\komorebi"
$ENV:FZF_DEFAULT_OPTS += " --layout=reverse"
$ENV:YAZI_FILE_ONE += "C:\Program Files\Git\usr\bin\file.exe"
$Env:COPILOT_AUTO_UPDATE="false" # For: https://github.com/github/copilot-cli/issues/4439
__ProfileMark "env vars"


# General aliases
Set-Alias -Name 'v' -Value 'nvim'
Set-Alias -Name 'touch' -Value 'New-Item'

function vp { nvim $PROFILE }
function whereis { Get-Command @args}
function ll { lsd -l @args}
function la { lsd -lA @args}
function lt { lsd -l --tree --depth=4 @args}

# Git aliases
del alias:gl -Force
del alias:gp -Force
del alias:gc -Force
del alias:ps -Force
del alias:gi -Force

function gs  { git status @args }
function ga  { git add @args }
function gl  { git log @args }
function gp  { git push @args }
function gc  { git commit @args }
function gd  { git diff @args }
function gr  { git restore . --staged @args }
function gsw  { git switch @args }
function gcA  { git commit --amend @args }
function gca  { git commit --amend -c HEAD @args }
function grp  { git rev-parse HEAD @args }
function gcp  { $commit = git rev-parse HEAD; $commit | Set-Clipboard; echo $commit }
function gi  { gh dash @args }
function ps  { handle64 -v @args }
__ProfileMark "aliases and git functions"



# Custom functions
. "$PSScriptRoot\Functions\Invoke-NvimTemp.ps1"
Set-Alias vs nvim-temp
__ProfileMark "Functions\Invoke-NvimTemp.ps1"

# $GitPromptSettings.EnableFileStatus = $false
# $GitPromptSettings.DefaultPromptWriteStatusFirst = $true

# Functions
. "$PSScriptRoot\Functions\Invoke-BuildPipeline.ps1"
Set-Alias -Name 'rcb' -Value 'Invoke-BuildPipelineForCurrentBranch' -Scope Global -Force
__ProfileMark "Functions\Invoke-BuildPipeline.ps1"

. "$PSScriptRoot\Functions\Yazi-Persist-Dir.ps1"
Set-Alias -Name 'fj' -Value 'Yazi-Persist-Dir'
Set-Alias -Name 'jf' -Value 'Yazi-Persist-Dir'
Set-Alias -Name 'f' -Value 'yazi'
__ProfileMark "Functions\Yazi-Persist-Dir.ps1"

. "$PSScriptRoot\Functions\New-GitWorktree.ps1"
Set-Alias -Name 'gwt' -Value 'New-GitWorktree'
__ProfileMark "Functions\New-GitWorktree.ps1"

. "$PSScriptRoot\Functions\New-GitBranch.ps1"
Set-Alias -Name 'gb' -Value 'New-GitBranch'
__ProfileMark "Functions\New-GitBranch.ps1"


. "$PSScriptRoot\Functions\Komorebi-RefreshMonitors.ps1"
Set-Alias -Name 'krf' -Value 'Komorebi-RefreshMonitors'
__ProfileMark "Functions\Komorebi-RefreshMonitors.ps1"

. "$PSScriptRoot\Functions\Komorebi-Toggle.ps1"
Set-Alias -Name 'kr' -Value 'Komorebi-Toggle'
__ProfileMark "Functions\Komorebi-Toggle.ps1"

. "$PSScriptRoot\Functions\Fzf-GitAddWidget.ps1"
__ProfileMark "fzf-gitadd-widget.ps1"

if ($env:PROFILE_TIMING) {
    Write-Host ("[profile] {0,-28} {1,5} ms  (total {2,5} ms)" -f "TOTAL", $script:__profileSw.ElapsedMilliseconds, $script:__profileSw.ElapsedMilliseconds) -ForegroundColor Yellow
}

