param(
    [Parameter(Mandatory = $true)]
    [string]$solutionPath,
    [switch]$outdated,
    [switch]$deprecated,
    [switch]$vulnerable,
    [switch]$verbose,
    [switch]$all,
    [switch]$help
)

function WriteHelp {
    $options = @(
        @{ Name = "-solutionPath"; Desc = "Path to the solution (.sln) to analyze" },
        @{ Name = "-outdated";     Desc = "Export all outdated NuGets to CSV" },
        @{ Name = "-deprecated";   Desc = "Export all deprecated NuGets to CSV" },
        @{ Name = "-vulnerable";   Desc = "Export all vulnerable NuGets to CSV" },
        @{ Name = "-all";          Desc = "Run all checks (outdated, deprecated, vulnerable)" },
        @{ Name = "-help";         Desc = "Show this help message" }
    )

    $maxNameLen = ($options | ForEach-Object { $_.Name.Length } | Measure-Object -Maximum).Maximum

    Write-Host "`nOptions:`n"
    foreach ($opt in $options) {
        $padded = $opt.Name.PadRight($maxNameLen + 2)
        Write-Host ("  {0}{1}" -f $padded, $opt.Desc)
    }

    Write-Host "`nExamples:`n"
    Write-Host "  .\NugetAudit.ps1 -solutionPath MyApp.sln -outdated"
    Write-Host "  .\NugetAudit.ps1 -solutionPath MyApp.sln -all`n"
}

function Parse-DotNetListJson {
    param(
        [string]$flag,
        [string]$solutionPath
    )

    try {
        Write-Verbose "Running: dotnet list $solutionPath package --$flag --format json"
        $json = dotnet list $solutionPath package --$flag --format json 2>&1
        $data = $json | ConvertFrom-Json
    }
    catch {
        Write-Error "Failed to run 'dotnet list package --$flag'. Details: $_"
        return @()
    }

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
                        $entry | Add-Member Reason (($pkg.deprecationReasons -join "; "))
                        $alt = if ($pkg.alternativePackage) {
                            $pkg.alternativePackage.id + $(if ($pkg.alternativePackage.versionRange) { " " + $pkg.alternativePackage.versionRange })
                        } else { "None found" }
                        $entry | Add-Member Alternative $alt
                    }
                    "vulnerable" {
                        $entry | Add-Member Severity ($pkg.vulnerabilities.severity -join "; ")
                        $entry | Add-Member DocumentationURL ($pkg.vulnerabilities.advisoryurl -join "; ")
                    }
                }
                $entries += $entry
            }
        }
    }
    return $entries
}
function Test-SdkStyleProjects {
    param(
        [Parameter(Mandatory = $true)]
        [string]$solutionPath
    )

    # Ensure the solution file exists
    if (-not (Test-Path $solutionPath -PathType Leaf)) {
        Write-Error "Solution path '$solutionPath' does not exist."
        return $false
    }

    $solutionDir = Split-Path $solutionPath

    # Find all .csproj files
    $csprojFiles = Get-ChildItem -Path $solutionDir -Recurse -Filter "*.csproj" -ErrorAction SilentlyContinue

    if ($csprojFiles.Count -eq 0) {
        Write-Error "No .csproj files found in solution directory."
        return $false
    }
    # Filter for SDK-style projects
    $sdkProjects = @()
    foreach ($proj in $csprojFiles) {
        try {
            [xml]$xml = Get-Content $proj.FullName
            if ($xml.Project.Sdk) {
                Write-Verbose "found $($proj) "
                $sdkProjects += $proj
            }else{
                Write-Verbose "found non sdk project $($proj)"
            }
        }
        catch {
            Write-Warning "Failed to parse $($proj.FullName) as XML."
            return $false
        }
    }

    if ($sdkProjects.Count -ne $csprojFiles.Count) {
        Write-Error "Non SDK-style .csproj files found. This script only works on SDK-style projects."
        return $false
    }

    Write-Verbose "Found $($sdkProjects.Count) SDK-style project(s)."
    return $true
}

function Export-Results {
    param(
        [string]$flag,
        [array]$data
    )

    if ($data.Count -eq 0) {
        Write-Host "No $flag packages found."
        return
    }

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $file = "${flag}Packages_$timestamp.csv"
    $data | Export-Csv $file -NoTypeInformation -Encoding UTF8
    Write-Host "✅ Exported $flag results to $file"
}

# --- Main Logic ---
if ($help -or (-not $solutionPath)) {
    WriteHelp
    return
}

if (-not (Test-Path $solutionPath)) {
    Write-Error "Solution path '$solutionPath' not found."
    return
}


if(-not $outdated -and -not $deprecated -and -not $vulnerable -and -not $all){
    $outdated = $true
}
if ($all) {
    $outdated = $true
    $deprecated = $true
    $vulnerable = $true
}
if (-not (Test-SdkStyleProjects -solutionPath $solutionPath)) {
    return
}


if ($outdated)   { Export-Results "Outdated"   (Parse-DotNetListJson "outdated"   $solutionPath) }
if ($deprecated) { Export-Results "Deprecated" (Parse-DotNetListJson "deprecated" $solutionPath) }
if ($vulnerable) { Export-Results "Vulnerable" (Parse-DotNetListJson "vulnerable" $solutionPath) }

