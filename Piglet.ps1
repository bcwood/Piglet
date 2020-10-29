function Piglet 
{
    [CmdletBinding()]
    param(
        [Parameter(Position=0, Mandatory=$true, ValueFromPipeline=$true)]
        [String]
        $Text,

        $Font = "standard"
    )

    $chars = $Text.ToCharArray()
    $fontInfo = GetFontInfo($Font)
    
    $outputLines = @()

    for ($i = 0; $i -lt $fontInfo.Height; $i++)
    {
        $line = ""

        foreach ($c in $chars)
        {
            $charCode = [int] $c
            $fontChar = $fontInfo.Characters[$charCode]
            
            $line += $fontChar[$i]            
        }

        $outputLines += $line
        Write-Host $line
    }
}

function GetFontInfo($FontName)
{
    $fontFilePath = "$PSScriptRoot/fonts/$Font.flf"
    
    if (!(Test-Path -Path $fontFilePath))
    {
        Write-Host "Font file $Font.flf cannot be found" -ForegroundColor Red
        return
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

    Write-Verbose "Header = $header"
    Write-Verbose "Signature = $($fontInfo.Signature)"
    Write-Verbose "Hard Blank = $($fontInfo.HardBlank)"
    Write-Verbose "Height = $($fontInfo.Height)"
    Write-Verbose "Baseline = $($fontInfo.Baseline)"
    Write-Verbose "Max Length = $($fontInfo.MaxLength)"
    Write-Verbose "Old Layout = $($fontInfo.OldLayout)"
    Write-Verbose "Comment Lines = $($fontInfo.CommentLines)"
    Write-Verbose "Print Direction = $($fontInfo.PrintDirection)"
    Write-Verbose "Full Layout = $($fontInfo.FullLayout)"
    Write-Verbose "Codetag Count = $($fontInfo.CodetagCount)"

    $fontChars = New-Object "System.Collections.Generic.Dictionary[int,string[]]"
    $charCode = 32
    $maxCharCode = 126
    $fileIndex = $fontInfo.CommentLines + 1

    # loop through entire file
    while ($fileIndex -lt $fontContent.Length -and $charCode -le $maxCharCode)
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
        
        $fontChars[$charCode] = $charLines
        $fileIndex += $fontInfo.Height
        $charCode++
    }

    $fontInfo | Add-Member -Name "Characters" -Value $fontChars -MemberType NoteProperty

    #foreach ($key in $fontChars.Keys)
    #{
    #    foreach ($line in $fontChars[$key])
    #    {
    #        Write-Host $line            
    #    }
    #
    #    Write-Host "-----------"
    #}

    return $fontInfo
}

cls

Piglet "Hello, world!" #-Verbose
