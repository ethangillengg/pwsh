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
