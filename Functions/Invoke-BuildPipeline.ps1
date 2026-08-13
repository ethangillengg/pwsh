function Invoke-BuildPipeline {
    param(
        [Parameter(Mandatory)]
        [string]$Branch,

        [string]$Organization = "https://dev.azure.com/abadata",
        [string]$Project = "AbaData",
        [int]$PipelineId = 13
    )

    $expectedOriginUrl = "git@github.com:AbacusDatagraphics/AbaData2"
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
