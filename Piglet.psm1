$script:fontCache = @{}

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

.EXAMPLE
PS C:\> Get-Date -Format "MM/dd/yyyy" | Piglet
 _   _      __   ___    ____       __  ____     ___    ____     ___
/ | / |    / /  / _ \  | ___|     / / |___ \   / _ \  |___ \   / _ \
| | | |   / /  | | | | |___ \    / /    __) | | | | |   __) | | | | |
| | | |  / /   | |_| |  ___) |  / /    / __/  | |_| |  / __/  | |_| |
|_| |_| /_/     \___/  |____/  /_/    |_____|  \___/  |_____|  \___/


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
        [AllowEmptyString()]
        [String]
        $Text,

        [String]
        $Font = "standard",

        [System.ConsoleColor]
        $ForegroundColor,

        [System.ConsoleColor]
        $BackgroundColor,

        [switch]
        $PassThru
    )

    begin
    {
        if (-not $script:fontCache[$Font]) {
            $script:fontCache[$Font] = Get-FontInfo($Font)
        }
        $fontInfo = $script:fontCache[$Font]
    }

    process
    {
        # output entire string one horizontal line at a time
        for ($i = 0; $i -lt $fontInfo.Height; $i++)
        {
            $line = ""

            # Input text can be multi byte chars, use proper enumerator
            [System.Globalization.StringInfo]::GetTextElementEnumerator($Text) | ForEach-Object {
                $charCode = [char]::ConvertToUtf32($_, 0)

                if ($fontInfo.Characters.ContainsKey($charCode))
                {
                    $fontChar = $fontInfo.Characters[$charCode]
                    $line += $fontChar[$i]
                }
                elseif ($fontInfo.Characters.ContainsKey(0)) # For unsupported chars print the special replacement char
                {
                    $fontChar = $fontInfo.Characters[0]
                    $line += $fontChar[$i]
                }
            }

            # remove leading space from output
            if ($line[0] -eq " "){
                $line = $line.Substring(1)
            }

            if ($PassThru) {
                $line
            }
            elseif ($ForegroundColor -ieq "Rainbow")
            {
                Write-RainbowText $line -BackgroundColor $BackgroundColor
            }
            else
            {
                $whParams = @{}

                if ($ForegroundColor)
                {
                    $whParams['ForegroundColor'] = $ForegroundColor
                }
                if ($BackgroundColor)
                {
                    $whParams['BackgroundColor'] = $BackgroundColor
                }

                Write-Host $line @whParams
            }
        }
    }
}

function Get-FontInfo
{
    param(
        [Parameter(Mandatory=$true)]
        [Alias('FontName', 'Name')]
        [String]
        $Font
    )

    $fontFilePath = Join-Path $PSScriptRoot "fonts/$Font.flf"
    Write-Verbose "Loading font from path $fontFilePath"

    if (!(Test-Path -Path $fontFilePath))
    {
        throw "Font file $Font.flf cannot be found"
    }

    $fontFileStream = [System.IO.FileStream]::new($fontFilePath, [System.IO.FileMode]::Open)
    $headerBytes = [byte[]]::new(4)
    $fontFileStream.Read($headerBytes, 0, 4) | Out-Null

    $fontFileStream.Seek(0, 0) | Out-Null # reset the stream position before passing it on for decompression

    if ([System.BitConverter]::ToUInt32($headerBytes, 0) -eq 0x04034b50) # ZIP signature aka. "PK♥♦"
    {
        $fontArchive = [System.IO.Compression.ZipArchive]::new($fontFileStream, [System.IO.Compression.ZipArchiveMode]::Read)

        # Font file must be the first one in the archive
        $fontFileReader = [System.IO.StreamReader]::new($fontArchive.Entries[0].Open())
    }
    elseif ([System.BitConverter]::ToUInt32($headerBytes, 0) -eq 0x32666C66) # FIGfont signature aka. "flf2"
    {
        $fontFileReader = [System.IO.StreamReader]::new($fontFileStream)
    }
    else
    {
        throw "Unrecognized file format!"
    }

    # parse header record
    $header = $fontFileReader.ReadLine()
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

    $fontInfo | Add-Member -Name "Comment" -Value ([String[]]::new($fontInfo.CommentLines)) -MemberType NoteProperty

    for ($i = 0; $i -lt $fontInfo.CommentLines; $i++)
    {
        $fontInfo.Comment[$i] = $fontFileReader.ReadLine()
    }

    $fontChars = New-Object "System.Collections.Generic.Dictionary[int,string[]]"

    $requiredChars = @(32..126)
    $requiredChars += @(196, 214, 220, 228, 246, 252, 223)

    # loop through required chars
    foreach ($char in $requiredChars)
    {
        $charLines = Get-NextFontChar $fontFileReader $fontInfo
        $fontChars[$char] = $charLines
    }

    # read additional chars defined in font file
    while (($charDefLine = $fontFileReader.ReadLine()))
    {

        if ($charDefLine[0] -ne "-")
        {
            $charCodeText, $charComment = $charDefLine -split '\s+',2
            $charCode = [int] $charCodeText
            $fontChars[$charCode] = Get-NextFontChar $fontFileReader $fontInfo
        }
        else
        {
            # TODO: handle negative values, this only skips them
            Get-NextFontChar $fontFileReader $fontInfo | Out-Null
        }
    }

    $fontFileReader.Close()
    $fontFileStream.Close()

    $fontInfo | Add-Member -Name "Characters" -Value $fontChars -MemberType NoteProperty

    return $fontInfo
}

function Get-NextFontChar
{
    param(
        [System.IO.StreamReader] $Reader,

        [psobject] $FontInfo
    )
    $charLines = [String[]]::new($FontInfo.Height)

    # loop through each character
    for ($i = 0; $i -lt $FontInfo.Height; $i++)
    {
        $charLine = $Reader.ReadLine()
        $terminator = $charLine[-1]

        $charLines[$i] = $charLine.Substring(0, $charLine.IndexOf($terminator))
        $charLines[$i] = $charLines[$i].Replace($FontInfo.HardBlank, " ")
    }
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

Register-ArgumentCompleter -CommandName Piglet,Get-FontInfo -ParameterName Font -ScriptBlock {
    param (
        $commandName,
        $parameterName,
        $wordToComplete,
        $commandAst,
        $fakeBoundParameters
    )

    # Seems like it can be surrounded in quotes
    $wordToCompleteTrimmed = $wordToComplete.Trim("'`"")
    (Get-ChildItem (Join-Path $PSScriptRoot "fonts") |
        Where-Object { $_.BaseName -like "$wordToCompleteTrimmed*" } |
        Where-Object { $_.Name.EndsWith('.flf')}).BaseName
}