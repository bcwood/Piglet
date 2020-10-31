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
module.

.EXAMPLE
PS C:\> Piglet "Hello, world!"
  _   _          _   _                                           _       _   _ 
 | | | |   ___  | | | |   ___         __      __   ___    _ __  | |   __| | | |
 | |_| |  / _ \ | | | |  / _ \        \ \ /\ / /  / _ \  | '__| | |  / _` | | |
 |  _  | |  __/ | | | | | (_) |  _     \ V  V /  | (_) | | |    | | | (_| | |_|
 |_| |_|  \___| |_| |_|  \___/  ( )     \_/\_/    \___/  |_|    |_|  \__,_| (_)
                                |/                                             

.EXAMPLE
PS C:\> Piglet "Hello, world!" -Font "script"
  ,            _    _                                    _           
 /|   |       | |  | |                                  | |     |   |
  |___|   _   | |  | |   __                 __    ,_    | |   __|   |
  |   |\ |/   |/   |/   /  \_     |  |  |_ /  \_ /  |   |/   /  |   |
  |   |/ |__/ |__/ |__/ \__/  o    \/ \/   \__/     |_/ |__/ \_/|_/ o
                              /                                      
                                                                     
.PARAMETER Text
String to convert to ASCII.

.PARAMETER Font
Optional. Name of font to use for transforming text.
The default set of fonts are:

    banner, big, block, bubble, digital, ivrit, lean, mini, script, shadow, slant,
    small, smscript, smshadow, smslant, standard, term

.PARAMETER ForegroundColor
Optional. Foreground color of the output text.
Available color choices are:

    Black, Blue, Cyan, DarkBlue, DarkCyan, DarkGray, DarkGreen, DarkMagenta, 
    DarkRed, DarkYellow, Gray, Green, Magenta, Rainbow, Red, White, Yellow

.PARAMETER BackgroundColor
Optional. Background color of the output text.
Available color choices are:

    Black, Blue, Cyan, DarkBlue, DarkCyan, DarkGray, DarkGreen, DarkMagenta, 
    DarkRed, DarkYellow, Gray, Green, Magenta, Red, White, Yellow

.LINK
Additional fonts can be found here: https://github.com/cmatsuoka/figlet-fonts

.LINK
FIGfont file format: http://www.jave.de/figlet/figfont.html
#>

function Piglet 
{
    [CmdletBinding()]
    param(
        [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
        [String]
        $Text,

        [String]
        $Font = "standard",

        [ValidateSet("Black", "Blue", "Cyan", "DarkBlue", "DarkCyan", "DarkGray", 
                     "DarkGreen", "DarkMagenta", "DarkRed", "DarkYellow", "Gray", 
                     "Green", "Magenta", "Rainbow", "Red", "White", "Yellow")]
        [String] $ForegroundColor = "Default",

        [ValidateSet("Black", "Blue", "Cyan", "DarkBlue", "DarkCyan", "DarkGray",
                     "DarkGreen", "DarkMagenta", "DarkRed", "DarkYellow", "Gray", 
                     "Green", "Magenta", "Red", "White", "Yellow")]
        [String] $BackgroundColor = "Default"
    )

    function Get-FontInfo
    {
        param(
            [String] $FontName
        )

        $fontFilePath = Join-Path $PSScriptRoot "fonts/$Font.flf"
        Write-Verbose "Loading font from path $fontFilePath"
    
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
            $charLines = Get-NextFontChar($fileIndex)
            $fontChars[$char] = $charLines
            $fileIndex += $fontInfo.Height
        }

        # read additional chars defined in font file
        while ($fileIndex -lt $fontContent.Length)
        {
            $charDefLine = $fontContent[$fileIndex]
            $parts = $charDefLine.Split(' ')
            # TODO: handle hex/octal character codes
            $char = $parts[0]
            $fileIndex++

            $charLines = Get-NextFontChar($fileIndex)
            $fontChars[$char] = $charLines
            $fileIndex += $fontInfo.Height
        }

        $fontInfo | Add-Member -Name "Characters" -Value $fontChars -MemberType NoteProperty

        return $fontInfo
    }

    function Get-NextFontChar
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

        return $charLines
    }

    function Write-RainbowText
    {
        param(
            [String] $Line,
            [String] $BackgroundColor
        )

        # as close to Roy G. Biv as we can get with the available colors ;)
        $colors = @("Red", "DarkYellow", "Yellow", "Green", "Blue", "Magenta", "DarkMagenta")
        $colorIndex = 0

        foreach ($char in $Line.ToCharArray())
        {
            $color = $colors[$colorIndex % $colors.Length]

            if ($BackgroundColor -ieq "Default")
            {
                Write-Host $char -ForegroundColor $color -NoNewline
            }
            else
            {
                Write-Host $char -ForegroundColor $color -BackgroundColor $BackgroundColor -NoNewline
            }

            $colorIndex++
        }

        Write-Host ""
    }

    function Write-Text
    {
        param(
            [String] $Line,
            [String] $ForegroundColor,
            [String] $BackgroundColor
        )

        if ($ForegroundColor -ieq "Default" -and $BackgroundColor -ieq "Default")
        {
            Write-Host $Line
        }
        elseif ($ForegroundColor -ine "Default" -and $BackgroundColor -ieq "Default")
        {
            Write-Host $Line -ForegroundColor $ForegroundColor
        }
        elseif ($ForegroundColor -ieq "Default" -and $BackgroundColor -ine "Default")
        {
            Write-Host $Line -BackgroundColor $BackgroundColor
        }
        else
        {
            Write-Host $Line -ForegroundColor $ForegroundColor -BackgroundColor $BackgroundColor
        }
    }

    $chars = $Text.ToCharArray()
    $fontInfo = Get-FontInfo($Font)
    
    # output entire string one horizontal line at a time
    for ($i = 0; $i -lt $fontInfo.Height; $i++)
    {
        $line = ""

        # build text line from the corresponding line of each character
        foreach ($c in $chars)
        {
            $charCode = [int] $c

            if ($fontInfo.Characters.ContainsKey($charCode))
            {
                $fontChar = $fontInfo.Characters[$charCode]            
                $line += $fontChar[$i]
            }
            # TODO: how to better handle unsupported chars?
        }

        # remove leading space from output
        $line = $line.Substring(1)

        if ($ForegroundColor -ieq "Rainbow")
        {
            Write-RainbowText $line -BackgroundColor $BackgroundColor
        }
        else
        {
            Write-Text -Line $line -ForegroundColor $ForegroundColor -BackgroundColor $BackgroundColor
        }
    }
}

Export-ModuleMember -Function Piglet
