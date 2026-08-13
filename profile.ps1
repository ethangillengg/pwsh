# function prompt {
#     Write-Host
#
#     $path = Get-Location
#     Write-Host $path -ForegroundColor Yellow -NoNewline
#
#     $branch = git branch --show-current 2>$null
#     if ($LASTEXITCODE -eq 0 -and $branch) {
#         Write-Host " (" -NoNewline
#         Write-Host $branch -ForegroundColor Magenta -NoNewline
#
#         # Show a red * if there are uncommitted changes
#         $dirty = git status --porcelain 2>$null
#         if ($dirty) {
#             Write-Host "*" -ForegroundColor Red -NoNewline
#         }
#
#         Write-Host ")" -NoNewline
#     }
#
#     return "`n> "
# }


oh-my-posh init pwsh --config ~/.config/omp/ethan.omp.json  | Invoke-Expression
Invoke-Expression (& { (zoxide init powershell | Out-String) })


# Readline Options
Set-PsReadLineOption -EditMode Vi
set-PSReadLineKeyHandler -Chord 'Ctrl+e' -Function ViEditVisually

# IMPORTANT: This has to be after PSReadLineOptions
Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'


# Environment variables
$ENV:EDITOR = "nvim"
$ENV:STARSHIP_CONFIG = "$HOME\.config\starship\starship.toml"
$Env:KOMOREBI_CONFIG_HOME = "$HOME\.config\komorebi"
$ENV:FZF_DEFAULT_OPTS += " --layout=reverse"
$ENV:YAZI_FILE_ONE += "C:\Program Files\Git\usr\bin\file.exe"
$Env:COPILOT_AUTO_UPDATE="false" # For: https://github.com/github/copilot-cli/issues/4439


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
function ps  { handle64 -v @args }



# Custom functions
. "$PSScriptRoot\Functions\Invoke-NvimTemp.ps1"
Set-Alias vs nvim-temp

# $GitPromptSettings.EnableFileStatus = $false
# $GitPromptSettings.DefaultPromptWriteStatusFirst = $true
. "$HOME\Documents\PowerShell\fzf-gitadd-widget.ps1"

# Functions
. "$PSScriptRoot\Functions\Invoke-BuildPipeline.ps1"
Set-Alias -Name 'rcb' -Value 'Invoke-BuildPipelineForCurrentBranch' -Scope Global -Force

. "$PSScriptRoot\Functions\Yazi-Persist-Dir.ps1"
Set-Alias -Name 'fj' -Value 'Yazi-Persist-Dir'
Set-Alias -Name 'jf' -Value 'Yazi-Persist-Dir'
Set-Alias -Name 'f' -Value 'yazi'

. "$PSScriptRoot\Functions\New-GitWorktree.ps1"
Set-Alias -Name 'gwt' -Value 'New-GitWorktree'

. "$PSScriptRoot\Functions\New-GitBranch.ps1"
Set-Alias -Name 'gb' -Value 'New-GitBranch'


. "$PSScriptRoot\Functions\Komorebi-RefreshMonitors.ps1"
Set-Alias -Name 'krf' -Value 'Komorebi-RefreshMonitors'

. "$PSScriptRoot\Functions\Komorebi-Toggle.ps1"
Set-Alias -Name 'kr' -Value 'Komorebi-Toggle'
