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
