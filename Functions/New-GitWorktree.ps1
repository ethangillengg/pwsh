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
