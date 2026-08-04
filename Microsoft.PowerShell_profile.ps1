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


Import-Module posh-git
function Set-PoshGitStatus {
    $global:GitStatus = Get-GitStatus
    $env:POSH_GIT_STRING = Write-GitStatus -Status $global:GitStatus
}

New-Alias -Name 'Set-PoshContext' -Value 'Set-PoshGitStatus' -Scope Global -Force
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


# Custom functions
function nvim-temp {
    <#
    .SYNOPSIS
    Opens a new temporary file in Neovim.

    .DESCRIPTION
    Creates a unique temporary file in the current user's Windows temporary
    directory and opens it in Neovim. An optional file extension can be
    specified to enable syntax highlighting, LSPs, and other filetype-specific
    features.

    .PARAMETER Extension
    The file extension for the temporary file. Defaults to ".txt". The leading
    period is optional.

    .EXAMPLE
    nvim-temp

    Opens a new temporary text file.

    .EXAMPLE
    nvim-temp lua

    Opens a new temporary Lua file.

    .EXAMPLE
    nvim-temp .ps1

    Opens a new temporary PowerShell script.

    .NOTES
    The file is created in the directory returned by
    [System.IO.Path]::GetTempPath().
    #>
    [CmdletBinding()]
    param(
        [string]$Extension = ".txt"
    )

    if ($Extension -notmatch '^\.') {
        $Extension = ".$Extension"
    }

    $tempFile = [System.IO.Path]::ChangeExtension(
        [System.IO.Path]::GetTempFileName(),
        $Extension
    )

    nvim $tempFile
}
Set-Alias vs nvim-temp

# $GitPromptSettings.EnableFileStatus = $false
$GitPromptSettings.DefaultPromptWriteStatusFirst = $true
. "$HOME\Documents\PowerShell\fzf-gitadd-widget.ps1"

# Functions
function Invoke-BuildPipeline {
    param(
        [Parameter(Mandatory)]
        [string]$Branch,

        [string]$Organization = "https://dev.azure.com/abadata",
        [string]$Project = "AbaData",
        [int]$PipelineId = 13
    )

    $expectedOriginUrl = "https://github.com/AbacusDatagraphics/AbaData2.git"
    $actualOriginUrl = git remote get-url origin 2>$null

    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($actualOriginUrl)) {
        throw "Could not read git remote 'origin'. Are you in a git repo?"
    }

    if ($actualOriginUrl.Trim() -ne $expectedOriginUrl) {
        throw "Refusing to run pipeline. Expected origin '$expectedOriginUrl', but found '$actualOriginUrl'."
    }

    $refName = if ($Branch -like "refs/heads/*") {
        $Branch
    } else {
        "refs/heads/$Branch"
    }

    $requestBody = @{
        stagesToSkip = @()
        resources = @{
            repositories = @{
                AbaData2Repo = @{
                    refName = $refName
                    version = ""
                }
                self = @{
                    refName = $refName
                }
            }
        }
        variables = @{
            "generate-release-notes" = @{
                value = "false"
            }
        }
    }

    $tempJsonFile = Join-Path $env:TEMP "az-pipeline-run-$([guid]::NewGuid()).json"

    try {
        $json = $requestBody | ConvertTo-Json -Depth 10

        # Write UTF-8 without BOM.
        [System.IO.File]::WriteAllText(
            $tempJsonFile,
            $json,
            [System.Text.UTF8Encoding]::new($false)
        )

        Write-Host "Invoking Azure DevOps pipeline..."

        $responseJson = az devops invoke `
            --area pipelines `
            --organization $Organization `
            --route-parameters project=$Project pipelineId=$PipelineId `
            --resource runs `
            --api-version 7.2-preview `
            --http-method post `
            --in-file $tempJsonFile 2>&1

        if ($LASTEXITCODE -ne 0) {
            throw "Azure DevOps invoke failed:`n$responseJson"
        }

        Write-Host "Parsing pipeline URL..."

        $response = $responseJson | ConvertFrom-Json
        $pipelineUrl = $response._links.web.href

        if ([string]::IsNullOrWhiteSpace($pipelineUrl)) {
            throw "Pipeline was invoked, but no pipeline URL was found in the response."
        }

        try {
            $pipelineUrl | Set-Clipboard
            Write-Host "Pipeline URL copied to clipboard."
        }
        catch {
            Write-Warning "Pipeline started, but copying to clipboard failed: $_"
        }

        $rocket = [System.Char]::ConvertFromUtf32(0x1F680)
        Write-Host "$rocket Pipeline started: $pipelineUrl"

    }
    finally {
        if (Test-Path $tempJsonFile) {
            Remove-Item $tempJsonFile -Force
        }
    }
}

function Invoke-BuildPipelineForCurrentBranch {
    $branch = git branch --show-current

    if ([string]::IsNullOrWhiteSpace($branch)) {
        throw "Could not determine current git branch. Are you in a git repo?"
    }

    Invoke-BuildPipeline -Branch $branch
}

Set-Alias -Name 'rcb' -Value 'Invoke-BuildPipelineForCurrentBranch' -Scope Global -Force

function Yazi-Persist-Dir {
    $tmp = New-TemporaryFile
    yazi @args --cwd-file="$tmp"

    $cwd = Get-Content -Path $tmp -Encoding UTF8

    if (-not [string]::IsNullOrWhiteSpace($cwd) -and
        $cwd -ne $PWD.Path -and
        (Test-Path -LiteralPath $cwd -PathType Container)) {
        Set-Location -LiteralPath $cwd
    }

    Remove-Item -LiteralPath $tmp -Force
}

Set-Alias -Name 'fj' -Value 'Yazi-Persist-Dir'
Set-Alias -Name 'jf' -Value 'Yazi-Persist-Dir'
Set-Alias -Name 'f' -Value 'yazi'

<#
.SYNOPSIS
Creates a Git worktree and task branch using a standardized naming format.

.DESCRIPTION
Creates a new Git worktree with a branch name in this format:

    eg/<project-code>/<task-id>-<description>

The worktree directory is created one folder above the repository root:

    <repository-parent>/<task-id>-<description>

The description is automatically converted to lowercase kebab-case.

By default, the new branch is created from the branch referenced by
origin/HEAD, such as origin/main or origin/develop.

After creating the branch, the function pushes it to origin and configures
the remote branch with the same name as its upstream.

The command can be run from anywhere inside the Git repository.

.PARAMETER ProjectCode
The project code used in the branch name.

For example:

    fb
    fo
    api

.PARAMETER TaskId
The numeric task or ticket identifier.

For example:

    8341

.PARAMETER Description
A short description of the task.

The description can be entered as separate unquoted words. It is converted
to lowercase kebab-case for the branch and directory names.

.PARAMETER BaseBranch
The branch or commit from which the new branch should be created.

When omitted, the command uses the remote default branch referenced by
origin/HEAD.

.EXAMPLE
New-GitWorktree fb 8341 remove invalid interval inputs

Creates:

    Local branch:
    eg/fb/8341-remove-invalid-interval-inputs

    Upstream branch:
    origin/eg/fb/8341-remove-invalid-interval-inputs

    Worktree:
    ../8341-remove-invalid-interval-inputs

.EXAMPLE
gwt fb 8341 remove invalid interval inputs

Uses the shorter gwt alias.

.EXAMPLE
gwt fb 8341 remove invalid interval inputs -BaseBranch origin/develop

Creates the branch from origin/develop instead of the default origin branch.

.EXAMPLE
Get-Help New-GitWorktree -Full

Displays the complete help documentation.

.NOTES
If Git cannot determine origin/HEAD, run:

    git remote set-head origin --auto

The function pushes the new branch to origin immediately and sets it as the
local branch's upstream.

The function changes the current PowerShell directory to the newly created
worktree after creation succeeds.
#>
function New-GitWorktree {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidatePattern('^[a-zA-Z0-9_-]+$')]
        [string]$ProjectCode,

        [Parameter(Mandatory, Position = 1)]
        [ValidatePattern('^\d+$')]
        [string]$TaskId,

        [Parameter(Mandatory, Position = 2, ValueFromRemainingArguments)]
        [string[]]$Description,

        [string]$BaseBranch
    )

    $initials = "eg"

    # Confirm that the current directory is inside a Git repository.
    $gitRoot = git rev-parse --show-toplevel 2>$null

    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($gitRoot)) {
        throw "The current directory is not inside a Git repository."
    }

    $gitRoot = $gitRoot.Trim()

    # Convert the description into a branch-friendly slug.
    $slug = $Description -join "-"
    $slug = $slug.ToLowerInvariant()
    $slug = $slug -replace "[^a-z0-9]+", "-"
    $slug = $slug.Trim("-")

    if ([string]::IsNullOrWhiteSpace($slug)) {
        throw "The description must contain at least one letter or number."
    }

    $projectCodeSlug = $ProjectCode.ToLowerInvariant()
    $branchName = "$initials/$projectCodeSlug/$TaskId-$slug"

    # Always create the worktree one directory above the Git root.
    $gitRootParent = Split-Path -Parent $gitRoot
    $worktreeDirectoryName = "$TaskId-$slug"
    $worktreePath = Join-Path $gitRootParent $worktreeDirectoryName

    # Use the default origin branch unless explicitly overridden.
    if ([string]::IsNullOrWhiteSpace($BaseBranch)) {
        $originHead = git symbolic-ref `
            --quiet `
            --short `
            refs/remotes/origin/HEAD 2>$null

        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($originHead)) {
            throw @"
Could not determine the default origin branch.

Run:

    git remote set-head origin --auto

Then try again, or provide the base branch explicitly:

    New-GitWorktree $ProjectCode $TaskId $($Description -join " ") -BaseBranch origin/main
"@
        }

        $BaseBranch = $originHead.Trim()
    }

    git show-ref --verify --quiet "refs/heads/$branchName"

    if ($LASTEXITCODE -eq 0) {
        throw "Local branch '$branchName' already exists."
    }

    git show-ref --verify --quiet "refs/remotes/origin/$branchName"

    if ($LASTEXITCODE -eq 0) {
        throw "Remote branch 'origin/$branchName' already exists."
    }

    if (Test-Path -LiteralPath $worktreePath) {
        throw "Worktree path '$worktreePath' already exists."
    }

    Write-Host "Creating worktree..." -ForegroundColor Cyan
    Write-Host "  Base:     $BaseBranch"
    Write-Host "  Branch:   $branchName"
    Write-Host "  Upstream: origin/$branchName"
    Write-Host "  Path:     $worktreePath"

    git worktree add -b $branchName $worktreePath $BaseBranch

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create the Git worktree."
    }

    Set-Location -LiteralPath $worktreePath

    Write-Host
    Write-Host "Pushing branch and setting upstream..." -ForegroundColor Cyan

    git push --set-upstream origin $branchName

    if ($LASTEXITCODE -ne 0) {
        Write-Warning @"
The worktree was created successfully, but the branch could not be pushed.

Worktree: $worktreePath
Branch:   $branchName

After resolving the push issue, run:

    git push --set-upstream origin $branchName
"@

        return
    }

    Write-Host
    Write-Host "Worktree created successfully." -ForegroundColor Green
    Write-Host "  Local:    $branchName"
    Write-Host "  Upstream: origin/$branchName"
    Write-Host "  Path:     $worktreePath"
}

Set-Alias gwt New-GitWorktree
