param(

    [string]$solutionPath,

    [switch]$outdated,

    [switch]$deprecated,

    [switch]$vulnerable,

    [switch]$verbose,

    [switch]$all,

    [switch]$help

)

function WriteHelp {

    Write-Host "Options:"

    Write-Host "  --outdated `t`t`t Write to excel all outdated nugets for the targeted solution"

    Write-Host "  --deprecated `t`t`t Write to excel all deprecated nugets for the targeted solution"

    Write-Host "  --vulnerable `t`t`t Write to excel all vulnerable nugets for the targed solution"

    Write-Host "  --verbose `t`t`t Print to the console all settings that have been selected IE deprecated vulnerable outdated"

    Write-Host "  --all `t`t`t Write to excel all outdated deprecated and vulnerable nugets for the targeted solution"

    Write-Host "  --solutionPath `t`t The path to the solution we want to analyze"

}

# Initialize an empty array to hold package information

if($all){

    $outdated = $true

    $deprecated = $true

    $vulnerable = $true

}

if($help){

    WriteHelp

    return

}

# Initialize a variable to keep track of the current project name

if($outdated){

    $outdatedNugetsExcelFile = @()

    Write-Host "Analyzing Outdated Nugets please wait: "

    $outdatedLibs = dotnet list $solutionPath package --outdated

    $currentProject = ""

    foreach ($line in $outdatedLibs) {

        if($verbose){

            Write-Host $line

        }

        # Use regular expression to match content within single quotes

        if($line.Contains("Project")){

            if ($line -match '`([^`]*)`') {

                # The matched word is captured in the first capture group

                $word = $matches[1]

                $currentProject = $word

            }

        }

        elseif($line.Contains(">")){

            $words = $line -split '\s+'

            $packageInfo = [PSCustomObject]@{

                Project        = $currentProject

                PackageName    = $words[2]

                CurrentVersion = $words[4]

                LatestVersion  = $words[5]

            }

            $outdatedNugetsExcelFile += $packageInfo

        }

    }

    $outdatedNugetsExcelFile | Export-Csv -Path "OutdatedPackages.csv" -NoTypeInformation

}

if($deprecated){

    $deprecatedNugetsExcelFile = @()

    Write-Host "Analyzing Deprecated Nugets please wait: "

    # Run the command and capture the output

    $deprecatedLibs = dotnet list $solutionPath package --deprecated

    foreach($line in $deprecatedLibs){

        if($verbose){

            Write-Host $line

        }

        if($line.Contains("Project")){

            if ($line -match '`([^`]*)`') {

                # The matched word is captured in the first capture group

                $word = $matches[1]

                $currentProject = $word

            }

        }

        elseif($line.Contains(">")){

            $words = $line -split '\s+'

            $packageInfo = [PSCustomObject]@{

                Project        = $currentProject

                PackageName    = $words[2]

                CurrentVersion = $words[4]

                Reason  = $words[5]

                Alternative = $words[6]

            }

            $packages += $packageInfo

        }

    }

    $deprecatedNugetsExcelFile | Export-Csv -Path "DeprecatedPackages.csv" -NoTypeInformation

}

 

if($vulnerable){

    $vulnerableNugetsExcelFile = @()

    Write-Host "Analyzing Vulnerable Nugets please wait: "

    # Run the command and capture the output

    $vulnerableLibs = dotnet list $solutionPath package --vulnerable

    foreach($line in $vulnerableLibs){

        if($verbose){

            Write-Host $line

        }

         if($line.Contains("Project")){

            if ($line -match '`([^`]*)`') {

                # The matched word is captured in the first capture group

                $word = $matches[1]

                $currentProject = $word

            }

        }

        elseif($line.Contains(">")){

            $words = $line -split '\s+'

            $packageInfo = [PSCustomObject]@{

                Project        = $currentProject

                PackageName    = $words[2]

                CurrentVersion = $words[4]

                Severity  = $words[5]

                DocumentationURL = $words[6]

            }

            $packages += $packageInfo

        }

    }

    $vulnerableNugetsExcelFile | Export-Csv -Path "VulnerablePackages.csv" -NoTypeInformation

}