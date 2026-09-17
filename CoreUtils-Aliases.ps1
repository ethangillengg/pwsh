$coreutilsCommandDirectory = Join-Path $env:ProgramFiles 'coreutils\cmd'

if (Test-Path -LiteralPath $coreutilsCommandDirectory -PathType Container) {
    Get-ChildItem -LiteralPath $coreutilsCommandDirectory -Filter '*.cmd' -File |
        Where-Object BaseName -ne 'ls' |
        ForEach-Object {
            Set-Alias -Name $_.BaseName -Value $_.FullName -Option AllScope -Scope Global -Force
        }
}
