function Komorebi-RefreshMonitors {
    $configPath = "$env:KOMOREBI_CONFIG_HOME\komorebi.json"
    $pattern = '("display_index_preferences"\s*:\s*\{[\s\S]*?"0"\s*:\s*)"([^"]*)"'

    $content = Get-Content $configPath -Raw
    $match = [regex]::Match($content, $pattern)

    if (-not $match.Success) {
        throw 'Could not find display_index_preferences index "0"'
    }

    $originalValue = $match.Groups[2].Value

    try {
        # Set to "test"
        $content = [regex]::Replace($content, $pattern, '$1"test"', 1)
        Set-Content $configPath $content -NoNewline

        # Do stuff here while index 0 = "test"
        # komorebic reload-configuration
        # ...
    }
    finally {
        # Restore original value
        $content = Get-Content $configPath -Raw
        $replacement = '$1"' + $originalValue + '"'
        $content = [regex]::Replace($content, $pattern, $replacement, 1)
        Set-Content $configPath $content -NoNewline
    }
}
