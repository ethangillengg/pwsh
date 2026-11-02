$script:AdlScriptsDir = Join-Path $PSScriptRoot '..\Scripts\adl'

# Subcommand name -> script. Names and aliases are matched case-insensitively.
$script:AdlCommands = [ordered]@{
    'get-access-token'  = @{ Aliases = @('gat'); Script = 'Get-AccessToken.ps1' }
    'reset-license-key' = @{ Aliases = @('rlk'); Script = 'Reset-LicenseKey.ps1' }
    'sign-challenge'    = @{ Aliases = @('sc'); Script = 'Sign-Challenge.ps1' }
    'release'           = @{
        Aliases  = @('rel', 'r')
        Products = [ordered]@{
            'lite'     = @{ Aliases = @('li'); Script = 'Create-LiteRelease.ps1' }
            'fieldops' = @{ Aliases = @('fo'); Script = 'Create-FieldOpsRelease.ps1' }
        }
    }
}

function Resolve-AdlEntry
{
    param($Table, [string]$Name)

    foreach ($key in $Table.Keys)
    {
        if ($key -eq $Name -or $Table[$key].Aliases -contains $Name)
        {
            return $Table[$key]
        }
    }
}

function Show-AdlScriptHelp
{
    param([string]$Label, $Entry)

    $command = Get-Command (Join-Path $script:AdlScriptsDir $Entry.Script)
    Write-Host "Usage: adl $Label [parameters]   ($($Entry.Script))"
    foreach ($p in $command.Parameters.Values)
    {
        if ([System.Management.Automation.Cmdlet]::CommonParameters -contains $p.Name) { continue }
        $text = "  -$($p.Name)"
        if ($p.Aliases) { $text += " (-$($p.Aliases -join ', -'))" }
        if ($p.ParameterType -ne [switch]) { $text += " <$($p.ParameterType.Name)>" }
        $values = ($p.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }).ValidValues
        if ($values) { $text += " [$($values -join '|')]" }
        if ($p.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] -and $_.Mandatory }) { $text += ' (required)' }
        Write-Host $text
    }
}

function adl
{
    $isHelp = { param($a) $a -is [string] -and $a -in '-h', '--help', '-help', '-?' }
    $name = if ($args.Count) { [string]$args[0] } else { '' }
    $rest = @($args | Select-Object -Skip 1)
    $entry = Resolve-AdlEntry $script:AdlCommands $name
    if (-not $entry -or (& $isHelp $name))
    {
        $list = ($script:AdlCommands.Keys | ForEach-Object { "$_ ($($script:AdlCommands[$_].Aliases -join ', '))" }) -join "`n  "
        Write-Host "Usage: adl <command> [args]   (adl <command> -h for details)`n  $list"
        return
    }

    $wantsHelp = [bool]($rest | Where-Object { & $isHelp $_ })

    if ($entry.Products)
    {
        $product = if ($rest.Count) { Resolve-AdlEntry $entry.Products ([string]$rest[0]) }
        if (-not $product)
        {
            if ($wantsHelp)
            {
                foreach ($key in $entry.Products.Keys) { Show-AdlScriptHelp "$name $key" $entry.Products[$key] }
            } else
            {
                Write-Host "Usage: adl $name <lite|li|fieldops|fo> [args]   (adl $name <product> -h for details)"
            }
            return
        }
        $name = "$name $($rest[0])"
        $entry = $product
        $rest = @($rest | Select-Object -Skip 1)
    }

    if ($wantsHelp)
    {
        Show-AdlScriptHelp $name.Trim() $entry
        return
    }

    # Re-slicing $args loses named-parameter binding, so rebuild it as a hashtable.
    $named = @{}
    $positional = @()
    for ($i = 0; $i -lt $rest.Count; $i++)
    {
        if ($rest[$i] -is [string] -and $rest[$i] -match '^-([A-Za-z]\w*):?$')
        {
            $key = $Matches[1]
            if ($i + 1 -lt $rest.Count -and -not ($rest[$i + 1] -is [string] -and $rest[$i + 1] -match '^-[A-Za-z]'))
            {
                $named[$key] = $rest[++$i]
            } else
            {
                $named[$key] = $true
            }
        } else
        {
            $positional += $rest[$i]
        }
    }

    & (Join-Path $script:AdlScriptsDir $entry.Script) @positional @named
}

Register-ArgumentCompleter -CommandName adl -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)

    $words = @($commandAst.CommandElements | Select-Object -Skip 1 | ForEach-Object { $_.ToString() })
    if ($wordToComplete) { $words = @($words | Select-Object -SkipLast 1) }
    $names = if ($words.Count -eq 0)
    {
        $script:AdlCommands.Keys
    } elseif ($words.Count -eq 1 -and (Resolve-AdlEntry $script:AdlCommands $words[0]).Products)
    {
        $script:AdlCommands['release'].Products.Keys
    }
    $names | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}
