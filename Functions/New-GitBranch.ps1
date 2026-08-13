<#
.SYNOPSIS
Creates and checks out a Git branch using a standardized naming format.

.DESCRIPTION
Creates a new Git branch with a branch name in this format:

    eg/<project-code>/<task-id>-<description>

The branch is created from, and checks out on top of, whatever branch is
currently checked out. This is simply a convenience wrapper around:

    git checkout -b <branch-name>

The description is automatically converted to lowercase kebab-case.

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
to lowercase kebab-case for the branch name.

.EXAMPLE
New-GitBranch fb 8341 remove invalid interval inputs

Runs:

    git checkout -b eg/fb/8341-remove-invalid-interval-inputs

.EXAMPLE
gb fb 8341 remove invalid interval inputs

Uses the shorter gb alias.

.EXAMPLE
Get-Help New-GitBranch -Full

Displays the complete help documentation.
#>
function New-GitBranch {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidatePattern('^[a-zA-Z0-9_-]{2}$')]
        [string]$ProjectCode,

        [Parameter(Mandatory, Position = 1)]
        [ValidatePattern('^(\d+)|(TEST)|(CHORE)$')]
        [string]$TaskId,

        [Parameter(Mandatory, Position = 2, ValueFromRemainingArguments)]
        [string[]]$Description
    )

    $initials = "eg"

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

    git checkout -b $branchName
}
