function Copilot-ResolveAllowedDirs
{
	$configPath = Join-Path $env:COPILOT_HOME "permissions-config.json"

	if (-not (Test-Path $configPath))
	{
		throw "Copilot permissions config not found: $configPath"
	}

	$config = Get-Content $configPath -Raw | ConvertFrom-Json

	# Determine the repository's main worktree path.
	$gitCommonDir = git rev-parse --git-common-dir 2>$null

	if ($LASTEXITCODE -eq 0 -and $gitCommonDir)
	{
		if (-not [IO.Path]::IsPathRooted($gitCommonDir))
		{
			$gitCommonDir = Join-Path (Get-Location) $gitCommonDir
		}

		$gitCommonDir = [IO.Path]::GetFullPath($gitCommonDir)

		# If this is the main repo, git-common-dir is usually <repo>\.git.
		# For a linked worktree, it points to the main repo's .git directory.
		if ((Split-Path $gitCommonDir -Leaf) -eq ".git")
		{
			$repoRoot = Split-Path $gitCommonDir -Parent
		} else
		{
			$repoRoot = $gitCommonDir
		}
	} else
	{
		$repoRoot = (Get-Location).Path
	}

	# Find the location entry matching the repo root.
	$location = $config.locations.PSObject.Properties |
		Where-Object {
			[IO.Path]::GetFullPath($_.Name).TrimEnd('\') -ieq
			[IO.Path]::GetFullPath($repoRoot).TrimEnd('\')
		} |
		Select-Object -First 1

	$copilotArgs = @()

	if ($location)
	{
		foreach ($dir in $location.Value.allowed_directories)
		{
			$copilotArgs += "--add-dir"
			$copilotArgs += $dir
		}
	}

	& copilot.exe @copilotArgs @args
}
