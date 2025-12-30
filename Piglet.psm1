$ErrorActionPreference = 'Stop'
$script:fontCache = @{}

$fontFilesPath    = Join-Path $PSScriptRoot 'fonts'
$controlFilesPath = Join-Path $PSScriptRoot 'control_files'
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

.PARAMETER ControlFile
Optional. Name(s) or path(s) of one or more control file(s) used to remap characters.
The built-in control files are:

    digits_segmented, outlined, upper

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

        [String[]]
        $ControlFile,

        [ValidateSet('Black', 'Blue', 'Cyan', 'DarkBlue', 'DarkCyan', 'DarkGray', 'DarkGreen', 'DarkMagenta',
                     'DarkRed', 'DarkYellow', 'Gray', 'Green', 'Magenta', 'Rainbow', 'Red', 'White', 'Yellow')]
        [string]
        $ForegroundColor,

        [System.ConsoleColor]
        $BackgroundColor,

        [switch]
        $PassThru
    )

    begin
    {
        $Font | ForEach-Object {
            if ($_.EndsWith('.flf')) {
                # Supplied with a path to a file
                $_
            }
            else
            {
                # Supplied with a name of one of the internal files
                Join-Path $fontFilesPath "$_.flf"
            }
        } | ForEach-Object {
            if (-not $script:fontCache[$_]) {
                $script:fontCache[$_] = Get-FontInfo($_)
            }
            $fontInfo = $script:fontCache[$_]
        }

        [System.Collections.Generic.OrderedDictionary[int, int][]] $transformationStages = @()
        if ($ControlFile) {
            $transformationStages = $ControlFile | ForEach-Object {
                if ($_.EndsWith('.flc')) {
                    # We were supplied with a path to a file
                    $_
                }
                else
                {
                    # We were supplied with a name of one of the internal files
                    Join-Path $controlFilesPath "$_.flc"
                }
            } | Get-ControlInfo
        }
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

                # Apply transformations
                $transformationStages | ForEach-Object {
                    if ($_.ContainsKey($charCode)) {
                        Write-Debug "    Transforming $charCode -> $($_[$charCode])"
                        $charCode = $_[$charCode]
                    }
                }

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

                # While working on the first character of the first line of output, check if we need to trim leading
                # spaces from all lines of the output. We can only do that if all lines of the first character start
                # with a space.
                if ($null -eq $firstCharStartsWithSpace) {
                    $firstCharStartsWithSpace = ($fontChar -match '^ ').Count -eq $fontChar.Count
                    Write-Debug "Line $i, checking for trim. Can be trimmed = $firstCharStartsWithSpace"
                }
            }

            # remove leading space from output
            if ($firstCharStartsWithSpace){
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

    $fontFilePath = Resolve-Path $Font
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

    $fontChars = New-Object "System.Collections.Generic.OrderedDictionary[int,string[]]"

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

function Convert-CharTokenToUint32 {
    param(
        [Parameter(Mandatory=$true)]
        [String]
        $Token
    )
    switch -Regex ($Token) {
        # Hex (base 16) number
        '^\\0x'    {
            # Seen files that have each byte prefixed with '\0x' and figlet does not complain. We need to remove
            # these sequences that are in the middle of the token to be able to parse to int
            [Convert]::ToInt32(($Token.TrimStart('\') -replace '(?<=.)\\0x'), 16)
            break
        }
        '^\\-?\d+' { [Convert]::ToInt32($Token.TrimStart('\'), 10); break }  # Number (base 10), could be negative
        '^\\ '     { 32; break }  # space
        '^\\a'     { 7;  break }  # bell/alert
        '^\\b'     { 8;  break }  # backspace
        '^\\e'     { 27; break }  # ESC character
        '^\\f'     { 12; break }  # form feed
        '^\\n'     { 10; break }  # newline/line feed
        '^\\r'     { 13; break }  # carriage return
        '^\\t'     { 9;  break }  # horizontal tab
        '^\\v'     { 11; break }  # vertical tab
        '^\\\\'    { 92; break }  # a backslash
        default    { [int][char]$Token }  # any other character
    }
}

function  Get-ControlInfo
{
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [ValidateScript({
            if (-not (Test-Path $_ -PathType Leaf)) {
                throw [System.Management.Automation.ItemNotFoundException] "File '${_}' not found"
            }
            $true
        })]
        [String]
        $ControlFile
    )

    begin {
        $decNumber      = '[\-0-9]+'
        $slashDecNumber = "\\$decNumber"

        $hexNumber      = '0x[0-9a-zA-Z\\x]+'
        $slashHexNumber = "\\$hexNumber"

        $charToken      = "$slashHexNumber|$slashDecNumber|\S" # Order is important
        $hexOrDecNumber = "$hexNumber|$decNumber" # These will not have the slash

        $space          = '[\t ]+'  # Be flexible with separators - either tabs or spaces, one or more
        $maybeComment   = "($space#.*)?"
    }

    process {
        Write-Verbose "Loading control file from path $ControlFile"

        $transformationStage = [System.Collections.Generic.OrderedDictionary[int, int]]::new()

        switch -Regex -File $ControlFile {
            '' {
                Write-Debug "[Get-ControlInfo] Line: '$_'"
            }

            '^\s*(#|$)' {
                continue # Ignore comments or empty lines
            }

            '^flc2a' {
                continue # Ignore the optional flc file header, don't even check that it is on the 1st line
            }

            # For line: t inchar outchar
            "^t$space(?<inchar>$charToken)$space(?<outchar>$charToken)$maybeComment" {
                $inchar  = $Matches['inchar']
                $outchar = $Matches['outchar']
                Write-Debug "[Get-ControlInfo]    Single char: $inchar -> $outchar"
                $transformationStage[(Convert-CharTokenToUint32 $inchar)] = Convert-CharTokenToUint32 $outchar
                continue
            }

            # For line: t inchar1-inchar2 outchar1-outchar2
            "^t$space(?<inchar1>$charToken)-(?<inchar2>$charToken)$space(?<outchar1>$charToken)-(?<outchar2>$charToken)$maybeComment" {
                $inchar1  = $Matches['inchar1']
                $inchar2  = $Matches['inchar2']
                $outchar1 = $Matches['outchar1']
                $outchar2 = $Matches['outchar2']

                Write-Debug "[Get-ControlInfo]    Range: $inchar1..$inchar2 -> $outchar1..$outchar2"
                $inRange  = (Convert-CharTokenToUint32 $inchar1)..(Convert-CharTokenToUint32 $inchar2)
                $outRange = (Convert-CharTokenToUint32 $outchar1)..(Convert-CharTokenToUint32 $outchar2)

                if ($inRange.Count -ne $outRange.Count) {
                    throw "Input char range size $($inRange.Count) must match output range size $($outRange.Count). Line '$_'"
                }

                $inRange | ForEach-Object -Begin { $i = 0 } { $transformationStage[$_] = $outRange[($i++)] }
                continue
            }

            # For line: number number
            "^(?<number1>$hexOrDecNumber)$space(?<number2>$hexOrDecNumber)$maybeComment" {
                $number1  = $Matches['number1']
                $number2  = $Matches['number2']
                Write-Debug "[Get-ControlInfo]    Single number: $number1 -> $number2"
                $transformationStage[(Convert-CharTokenToUint32 "\$number1")] = Convert-CharTokenToUint32 "\$number2"
                continue
            }

            '^f' {
                # Return the current transformation stage and start a new one
                Write-Debug "[Get-ControlInfo]    Starting a new transformation stage"
                $transformationStage
                $transformationStage = [System.Collections.Generic.OrderedDictionary[int, int]]::new()
                continue
            }

            # Not implemented commands
            '^h' { Write-Warning "HZ input mode not supported";                        continue }
            '^j' { Write-Warning "Shift-JIS (aka. MS-Kanji) input mode not supported"; continue }
            '^b' { Write-Warning "DBCS input mode not supported";                      continue }
            '^u' { <# Piglet reads UTF-8 input by default #>                           continue }
            '^g' { Write-Warning "ISO 2022 character sets not supported";              continue }

            default { Write-Warning "Unrecognized command line: $_";                   continue }

        }

        $transformationStage
    }
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

$fontOrControlCompleter = {
    param (
        $commandName,
        $parameterName,
        $wordToComplete,
        $commandAst,
        $fakeBoundParameters
    )

    switch ($parameterName) {
        'Font' {
            $fileDir   = $fontFilesPath
            $extension = '.flf'
            break
        }
        'ControlFile' {
            $fileDir   = $controlFilesPath
            $extension = '.flc'
            break
        }

        default {}
    }

    # Seems like it can be surrounded in quotes
    $wordToCompleteTrimmed = $wordToComplete.Trim("'`"")
    (Get-ChildItem $fileDir |
        Where-Object { $_.BaseName -like "*$wordToCompleteTrimmed*" } |
        Where-Object { $_.Name.EndsWith($extension)}).BaseName
}

Register-ArgumentCompleter -CommandName Piglet,Get-FontInfo -ParameterName Font -ScriptBlock $fontOrControlCompleter
Register-ArgumentCompleter -CommandName Piglet,Get-ControlInfo -ParameterName ControlFile -ScriptBlock $fontOrControlCompleter