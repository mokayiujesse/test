# Define the path to your YAML files
$yamlDirectory = "C:\Users\mokay\Desktop\LOLRMM-main\yaml"

# Define the path for the output CSV file
$outputCsvPath = "C:\Users\mokay\Desktop\rmm_results.csv"

# Import the necessary module
Import-Module powershell-yaml

# Function to extract relevant information from YAML content
function Extract-RMMInfo {
    param (
        [string]$yamlFilePath
    )

    try {
        # Read the YAML file content
        $yamlContent = Get-Content -Path $yamlFilePath -Raw

        # Convert YAML content to a PowerShell object
        $yamlData = ConvertFrom-Yaml -Yaml $yamlContent

        # Extract the file name without the extension
        $fileName = [System.IO.Path]::GetFileNameWithoutExtension($yamlFilePath)

        # Extract the executable names from InstallationPaths or PEMetadata
        $executables = @()

        if ($yamlData.Details.InstallationPaths) {
            $executables += $yamlData.Details.InstallationPaths |
                Where-Object { $_ -match '\.exe$' -or $_ -match '\.bin$' -or $_ -match '\.sh$' -or $_ -match '\.app$' } |
                ForEach-Object { [System.IO.Path]::GetFileName($_) }
        }

        if ($yamlData.Details.PEMetadata.Filename) {
            $executables += $yamlData.Details.PEMetadata.Filename |
                ForEach-Object { [System.IO.Path]::GetFileName($_) }
        }

        # Default to "UnknownExecutable" if no executables are found
        if (-not $executables) {
            $executables += "UnknownExecutable"
        }

        # Determine the domains associated with the YAML file
        $domains = @()

        if ($yamlData.Artifacts.Network) {
            foreach ($networkArtifact in $yamlData.Artifacts.Network) {
                if ($networkArtifact.Domains) {
                    $domains += $networkArtifact.Domains
                }
            }
        }

        # Remove duplicates and sort domains
        $domains = $domains | Sort-Object -Unique

        # Define OS mapping based on file extensions
        $osLookup = @{
            ".exe"  = "Windows"
            ".bin"  = "Linux/macOS"
            ".sh"   = "Linux"
            ".app"  = "macOS"
            ".msi"  = "Windows"
            ".dmg"  = "macOS"
        }

        # Generate an entry for each executable
        $results = foreach ($executable in $executables) {
            $extension = [System.IO.Path]::GetExtension($executable).ToLower()
            $os = $osLookup[$extension]

            # Handle cases where the OS cannot be determined (e.g., the extension is not listed)
            if (-not $os) {
                $os = "Unknown"
            }

            [PSCustomObject]@{
                FileName        = $fileName
                ExecutableName  = $executable
                OperatingSystem = $os
                Domains         = if ($domains.Count -gt 0) { $domains -join ", " } else { "NoDomains" }
            }
        }

        return $results

    } catch {
        Write-Warning "Failed to process file: $yamlFilePath. Error: $_"
        return $null
    }
}

# Get all YAML files in the directory
$yamlFiles = Get-ChildItem -Path $yamlDirectory -Filter *.yaml

# Process each YAML file and collect the information
$allResults = $yamlFiles | ForEach-Object { Extract-RMMInfo -yamlFilePath $_.FullName }

# Flatten the results and filter out null entries
$flattenedResults = $allResults | Where-Object { $_ -ne $null }

# Export the results to a CSV file
$flattenedResults | Export-Csv -Path $outputCsvPath -NoTypeInformation

# Display a message that the CSV file has been created
Write-Host "Results have been exported to: $outputCsvPath"
