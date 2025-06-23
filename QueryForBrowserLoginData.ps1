# Set paths
$chromeLoginData = "C:\Users\Administrator\AppData\Local\Google\Chrome\User Data\Default\Login Data"
$tempLoginData = "$env:TEMP\LoginDataTemp.db"
$sqlitePath = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Tools\sqlite3.exe"  # <-- Corrected path to sqlite3.exe
$outputFile = "$env:TEMP\Chrome_Login_Data.txt"  # Output file path

# Initialize output file (clear it if it exists)
if (Test-Path $outputFile) {
    Remove-Item $outputFile -Force
}
New-Item -Path $outputFile -ItemType File

# Copy the database
Copy-Item -Path $chromeLoginData -Destination $tempLoginData -Force

# Query using sqlite3 (hex password_value)
$sqlQuery = "SELECT origin_url, username_value, hex(password_value) FROM logins;"
$rawResults = & $sqlitePath $tempLoginData $sqlQuery

# Check if query returned any data
if ($rawResults -eq "") {
    Write-Host "No results found in the query. The database might be empty."
} else {
    Write-Host "Results found. Processing..."

    # Process each line and write to file
    $lines = $rawResults -split "`n"
    foreach ($line in $lines) {
        $fields = $line -split '\|'
        if ($fields.Length -eq 3) {
            $url = $fields[0].Trim()
            $user = $fields[1].Trim()
            $encHex = $fields[2].Trim()

            # Debugging: check data
            Write-Host "Processing: URL=$url, Username=$user, EncryptedPasswordHex=$encHex"

            # Ensure the hex string is not empty or null
            if (![string]::IsNullOrWhiteSpace($encHex)) {
                # Ensure the hex string is in a valid length (even number of characters)
                if ($encHex.Length % 2 -eq 0) {
                    # Convert hex string to byte array
                    try {
                        $byteArray = for ($i = 0; $i -lt $encHex.Length; $i += 2) {
                            [Convert]::ToByte($encHex.Substring($i, 2), 16)
                        }

                        # Convert byte array to Base64 string
                        $encBase64 = [Convert]::ToBase64String($byteArray)

                        # Create the output object
                        $outputString = "URL: $url`nUsername: $user`nEncryptedPassword (Base64): $encBase64`n"
                        
                        # Append the output to the file
                        Add-Content -Path $outputFile -Value $outputString
                    } catch {
                        Write-Warning "Error converting hex to byte array for $url. Skipping."
                    }
                } else {
                    Write-Warning "Invalid hex string length for $url, skipping."
                }
            } else {
                Write-Warning "Empty or null hex string for $url, skipping."
            }
        }
    }
}

# Cleanup
Remove-Item -Path $tempLoginData -Force

Write-Host "Export completed. Check the file at: $outputFile"
