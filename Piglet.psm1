<#
.SYNOPSIS
PowerShell implementation of the popular Figlet command line utility. Transforms
input text into ASCII art representation using a variety of different fonts.

MIT license.

Copyright (c) 2020-present, Brandon Wood.
All rights reserved.

.DESCRIPTION
This script reads characters from the specified font file, and translates the
input text into that ASCII font.

The default set of Figlet fonts are included with Piglet by default. Additional
fonts can be easily installed by copying them into the fonts directory of this
module. Additional fonts can be found here: 
    
    https://github.com/cmatsuoka/figlet-fonts

Example:
PS C:\> Import-Module Piglet
PS C:\> Piglet "Hello, world!"
  _   _          _   _                                           _       _   _ 
 | | | |   ___  | | | |   ___         __      __   ___    _ __  | |   __| | | |
 | |_| |  / _ \ | | | |  / _ \        \ \ /\ / /  / _ \  | '__| | |  / _` | | |
 |  _  | |  __/ | | | | | (_) |  _     \ V  V /  | (_) | | |    | | | (_| | |_|
 |_| |_|  \___| |_| |_|  \___/  ( )     \_/\_/    \___/  |_|    |_|  \__,_| (_)
                                |/                                             

.PARAMETER Text
String to convert to ASCII.

.PARAMETER Font
Optional. Name of font to use for transforming text.
#>

function Piglet 
{
    [CmdletBinding()]
    param(
        [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
        [String]
        $Text,

        [String]
        $Font = "standard"
    )

    function GetFontInfo($FontName)
    {
        $fontFilePath = Join-Path $PSScriptRoot "fonts/$Font.flf"
    
        if (!(Test-Path -Path $fontFilePath))
        {
            throw "Font file $Font.flf cannot be found"
        }
    
        $fontContent = Get-Content $fontFilePath

        # parse header record
        $header = $fontContent[0]    
        $parts = $header.Split(' ')
    
        $fontInfo = New-Object -TypeName PSObject
        $fontInfo | Add-Member -Name "Signature" -Value $parts[0].Substring(0, $parts[0].Length - 1) -MemberType NoteProperty
        $fontInfo | Add-Member -Name "HardBlank" -Value $parts[0].Substring($parts[0].Length - 1) -MemberType NoteProperty
        $fontInfo | Add-Member -Name "Height" -Value ([int]$parts[1]) -MemberType NoteProperty
        $fontInfo | Add-Member -Name "Baseline" -Value ([int]$parts[2]) -MemberType NoteProperty
        $fontInfo | Add-Member -Name "MaxLength" -Value ([int]$parts[3]) -MemberType NoteProperty
        $fontInfo | Add-Member -Name "OldLayout" -Value ([int]$parts[4]) -MemberType NoteProperty
        $fontInfo | Add-Member -Name "CommentLines" -Value ([int]$parts[5]) -MemberType NoteProperty
        $fontInfo | Add-Member -Name "PrintDirection" -Value ([int]$parts[6]) -MemberType NoteProperty
        $fontInfo | Add-Member -Name "FullLayout" -Value ([int]$parts[7]) -MemberType NoteProperty
        $fontInfo | Add-Member -Name "CodetagCount" -Value ([int]$parts[8]) -MemberType NoteProperty

        $fontChars = New-Object "System.Collections.Generic.Dictionary[int,string[]]"
        $fileIndex = $fontInfo.CommentLines + 1
    
        $requiredChars = @(32..126)
        $requiredChars += @(196, 214, 220, 228, 246, 252, 223)
    
        # loop through required chars
        foreach ($char in $requiredChars)
        {
            $firstLine = $fontContent[$fileIndex]
            $terminator = $firstLine.Substring($firstLine.Length - 1)

            $charLines = @()

            # loop through each character
            for ($i = 0; $i -lt $fontInfo.Height; $i++)
            {
                $charIndex = $fileIndex + $i
            
                $charLine = $fontContent[$charIndex]
                $charLine = $charLine.Replace($terminator, "")
                $charLine = $charLine.Replace($fontInfo.HardBlank, " ")
                #Write-Host $charLine
            
                $charLines += $charLine
            }

            #Write-Host "------------------"
        
            $fontChars[$char] = $charLines
            $fileIndex += $fontInfo.Height
        }

        # TODO: read additional chars defined in font file

        $fontInfo | Add-Member -Name "Characters" -Value $fontChars -MemberType NoteProperty

        return $fontInfo
    }

    $chars = $Text.ToCharArray()
    $fontInfo = GetFontInfo($Font)
    
    $outputLines = @()

    for ($i = 0; $i -lt $fontInfo.Height; $i++)
    {
        $line = ""

        foreach ($c in $chars)
        {
            $charCode = [int] $c

            if ($fontInfo.Characters.ContainsKey($charCode))
            {
                $fontChar = $fontInfo.Characters[$charCode]            
                $line += $fontChar[$i]
            }
        }

        $outputLines += $line
        Write-Host $line
    }
}

Export-ModuleMember -Function Piglet
