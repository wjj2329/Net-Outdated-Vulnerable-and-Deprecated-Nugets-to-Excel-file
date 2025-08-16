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
    Write-Host "  --outdated      Write to excel all outdated nugets for the targeted solution"
    Write-Host "  --deprecated    Write to excel all deprecated nugets for the targeted solution"
    Write-Host "  --vulnerable    Write to excel all vulnerable nugets for the targeted solution"
    Write-Host "  --verbose       Print all settings and raw output to console"
    Write-Host "  --all           Run all (outdated, deprecated, vulnerable)"
    Write-Host "  --solutionPath  Path to the solution to analyze"
}

function Supports-JsonFormat {
    try {
        $test = dotnet list $solutionPath package --format json 
        return $true
    }
    catch {
        return $false
    }
}

function Parse-DotNetListJson {
    param([string]$flag)

    $json = dotnet list $solutionPath package --$flag --format json
    if ($verbose) { $json | Write-Host }
    $data = $json | ConvertFrom-Json
    $entries = @()

    foreach ($proj in $data.projects) {
        foreach ($fw in $proj.frameworks) {
            foreach ($pkg in $fw.topLevelPackages) {
                $entry = [PSCustomObject]@{
                    Project        = $proj.path
                    Framework      = $fw.framework
                    PackageName    = $pkg.id
                    CurrentVersion = $pkg.resolvedVersion
                }
                switch ($flag) {
                    "outdated" {
                        $entry | Add-Member LatestVersion $pkg.latestVersion
                    }
                    "deprecated" {
                        $entry | Add-Member Reason $pkg.reason
                        $entry | Add-Member Alternative $pkg.alternative
                    }
                    "vulnerable" {
                        $entry | Add-Member Severity $pkg.vulnerabilities.severity
                        $entry | Add-Member DocumentationURL $pkg.vulnerabilities.advisoryUrl

                    }
                }
                $entries += $entry
            }
        }
    }
    return $entries
}

function Parse-DotNetListTable {
    param([string]$flag)

    $output = dotnet list $solutionPath package --$flag
    if ($verbose) { $output | Write-Host }
    $entries = @()
    $currentProject = ""

    foreach ($line in $output) {
        if ($line -match '^Project\s+`?([^`]*)`?$') {
            $currentProject = $matches[1]
        }
        elseif ($line -match '^\s*>\s+(\S+)\s+(\S+)(?:\s+(\S+))?(?:\s+(\S+))?') {
            $pkg = $matches[1]
            $ver1 = $matches[2]
            $ver2 = $matches[3]
            $ver3 = $matches[4]

            switch ($flag) {
                "outdated" {
                    $entries += [PSCustomObject]@{
                        Project        = $currentProject
                        PackageName    = $pkg
                        CurrentVersion = $ver1
                        LatestVersion  = $ver2
                    }
                }
                "deprecated" {
                    $entries += [PSCustomObject]@{
                        Project        = $currentProject
                        PackageName    = $pkg
                        CurrentVersion = $ver1
                        Reason         = $ver2
                        Alternative    = $ver3
                    }
                }
                "vulnerable" {
                    $entries += [PSCustomObject]@{
                        Project         = $currentProject
                        PackageName     = $pkg
                        CurrentVersion  = $ver1
                        Severity        = $ver2
                        DocumentationURL = $ver3
                    }
                }
            }
        }
    }
    return $entries
}

# --- Main Logic ---
if ($help) {
    WriteHelp
    return
}

if ($all) {
    $outdated = $true
    $deprecated = $true
    $vulnerable = $true
}

$useJson = Supports-JsonFormat
if ($verbose) { Write-Host "JSON format supported: $useJson" }

if ($outdated) {
    if ($useJson) {
        Parse-DotNetListJson "outdated" | Export-Csv "OutdatedPackages.csv" -NoTypeInformation
    }
    else {
        Parse-DotNetListTable "outdated" | Export-Csv "OutdatedPackages.csv" -NoTypeInformation
    }
}
if ($deprecated) {
    if ($useJson) {
        Parse-DotNetListJson "deprecated" | Export-Csv "DeprecatedPackages.csv" -NoTypeInformation
    }
    else {
        Parse-DotNetListTable "deprecated" | Export-Csv "DeprecatedPackages.csv" -NoTypeInformation
    }
}
if ($vulnerable) {
    if ($useJson) {
        Parse-DotNetListJson "vulnerable" | Export-Csv "VulnerablePackages.csv" -NoTypeInformation
    }
    else {
        Parse-DotNetListTable "vulnerable" | Export-Csv "VulnerablePackages.csv" -NoTypeInformation
    }
}
