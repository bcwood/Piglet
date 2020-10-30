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

    $fontInfo | Add-Member -Name "Characters" -Value $fontChars -MemberType NoteProperty

    return $fontInfo
}

cls

Piglet "Hello, world!"
Piglet "ÄäÖöÜüß"
Piglet "ÄäËëÏïÖöÜüŸÿ"
