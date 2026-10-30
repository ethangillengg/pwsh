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
    ../<root-dir-name>-8341-remove-invalid-interval-inputs

.EXAMPLE
gwt add fb 8341 remove invalid interval inputs

Uses the gwt command's add subcommand.

.EXAMPLE
gwt add fb 8341 remove invalid interval inputs -BaseBranch origin/develop

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
    # Prefix with the main checkout's directory name, even when run from a linked worktree.
    $commonDir = (git rev-parse --path-format=absolute --git-common-dir).Trim()
    $rootDirName = Split-Path -Leaf (Split-Path -Parent $commonDir)
    $worktreeDirectoryName = "$rootDirName-$TaskId-$slug"
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

function Get-GitWorktreePath {
    git worktree list --porcelain 2>$null |
        Where-Object { $_ -like 'worktree *' } |
        ForEach-Object { ($_ -replace '^worktree ', '') -replace '/', '\' }
}

function Remove-GitWorktreeByName {
    param(
        [Parameter(Mandatory)][string]$Name,
        [switch]$Force
    )

    $paths = @(Get-GitWorktreePath)

    if ($paths.Count -eq 0) {
        throw "The current directory is not inside a Git repository."
    }

    $mainPath = $paths[0]
    $normalized = $Name -replace '/', '\'
    $target = $paths | Select-Object -Skip 1 | Where-Object {
        $_ -eq $normalized -or (Split-Path -Leaf $_) -eq $normalized
    } | Select-Object -First 1

    if (-not $target) {
        throw "No linked worktree matches '$Name'. Run 'git worktree list'."
    }

    # Git cannot remove a worktree while it is the current directory.
    $cwd = (Get-Location).ProviderPath
    if ($cwd -eq $target -or $cwd.StartsWith("$target\")) {
        Set-Location $mainPath
    }

    $gitArgs = @('worktree', 'remove')
    if ($Force) { $gitArgs += '--force' }
    git @gitArgs $target

    if ($LASTEXITCODE -ne 0) {
        throw "git worktree remove failed for '$target'. Use -f to force."
    }

    Write-Host "Removed worktree: $target" -ForegroundColor Green
}

function gwt {
    $subcommand, $rest = $args
    $helpFlags = '-h', '--help'

    if (-not $subcommand -or $subcommand -in $helpFlags) {
        Write-Host @"
Usage: gwt <command> [args]

Commands:
  add    Create a branch and worktree (gwt add -h for details)
  rm     Remove a worktree (gwt rm -h for details)

Options:
  -h, --help    Show help
"@
        return
    }

    switch ($subcommand) {
        'rm' {
            $rmUsage = @"
Usage: gwt rm <worktree> [-f]

Remove a linked worktree by directory name or full path. Tab completes names
from the current repository. The branch is kept.

Options:
  -f, --force    Remove even with uncommitted changes
  -h, --help     Show help

Example:
  gwt rm lite-11714-move-annotations-widget-button
"@
            if ($rest | Where-Object { $_ -in $helpFlags }) {
                Write-Host $rmUsage
                return
            }

            $force = [bool]($rest | Where-Object { $_ -in '-f', '--force' })
            $names = @($rest | Where-Object { $_ -notin '-f', '--force' })

            if ($names.Count -ne 1) {
                Write-Host $rmUsage
                return
            }

            Remove-GitWorktreeByName -Name $names[0] -Force:$force
        }
        'add' {
            $addUsage = @"
Usage: gwt add <project> <task-id> <description...> [-BaseBranch <ref>]

Create branch eg/<project>/<task-id>-<slug>, push it, and add a worktree at
../<root>-<task-id>-<slug>, then cd into it.

Arguments:
  project        Project code, e.g. li
  task-id        Numeric task id, e.g. 11714
  description    Words used for the branch/dir slug

Options:
  -BaseBranch    Base ref (default: origin's default branch)
  -h, --help     Show help

Example:
  gwt add li 11714 move annotations widget button
"@

            if ($rest | Where-Object { $_ -in $helpFlags }) {
                Write-Host $addUsage
                return
            }

            # Positional form needs 3+ tokens once -BaseBranch <ref> is removed.
            $positional = @()
            $namedUsed = $false
            for ($i = 0; $i -lt $rest.Count; $i++) {
                if ($rest[$i] -eq '-BaseBranch') { $i++ }
                elseif ("$($rest[$i])".StartsWith('-')) { $namedUsed = $true }
                else { $positional += $rest[$i] }
            }

            if (-not $namedUsed -and $positional.Count -lt 3) {
                Write-Host $addUsage
                return
            }

            New-GitWorktree @rest
        }
        default { throw "Unknown command '$subcommand'. Run 'gwt -h' for usage." }
    }
}

Register-ArgumentCompleter -CommandName gwt -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)

    $tokens = @($commandAst.CommandElements | Select-Object -Skip 1 | ForEach-Object { $_.ToString() })
    $completed = if ($wordToComplete) { $tokens.Count - 1 } else { $tokens.Count }

    if ($completed -eq 0) {
        'add', 'rm' | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
    }
    elseif ($completed -eq 1 -and $tokens[0] -eq 'rm') {
        Get-GitWorktreePath | Select-Object -Skip 1 | ForEach-Object {
            $leaf = Split-Path -Leaf $_
            if ($leaf -like "$wordToComplete*") {
                [System.Management.Automation.CompletionResult]::new($leaf, $leaf, 'ParameterValue', $_)
            }
        }
    }
}
