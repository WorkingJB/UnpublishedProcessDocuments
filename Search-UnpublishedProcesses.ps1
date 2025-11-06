<#
.SYNOPSIS
    Search for unpublished processes by document names using the Process Manager Search API.

.DESCRIPTION
    This script prompts for Process Manager site credentials, reads document names from a CSV file,
    and searches for unpublished processes that reference those documents. Results are exported to a CSV file.

.EXAMPLE
    .\Search-UnpublishedProcesses.ps1
#>

[CmdletBinding()]
param()

# Function to write colored output
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

# Function to get the appropriate search endpoint based on region
function Get-SearchEndpoint {
    param(
        [string]$BaseUrl
    )

    # Regional mapping for Process Manager search endpoints
    $regionalMapping = @{
        "demo.promapp.com" = "https://dmo-wus-sch.promapp.io"
        "us.promapp.com"   = "https://prd-wus-sch.promapp.io"
        "ca.promapp.com"   = "https://prd-cac-sch.promapp.io"
        "eu.promapp.com"   = "https://prd-neu-sch.promapp.io"
        "au.promapp.com"   = "https://prd-aus-sch.promapp.io"
    }

    # Extract the domain from the base URL
    $uri = [System.Uri]$BaseUrl
    $domain = $uri.Host

    # Check if we have a mapping for this domain
    if ($regionalMapping.ContainsKey($domain)) {
        $searchEndpoint = $regionalMapping[$domain]
        Write-ColorOutput "Using regional search endpoint: $searchEndpoint" "Gray"
        return $searchEndpoint
    }
    else {
        # If no mapping found, use the base URL (for custom domains)
        Write-ColorOutput "Using base URL for search endpoint (no regional mapping found)" "Yellow"
        return $BaseUrl
    }
}

# Function to authenticate and get bearer token
function Get-AuthToken {
    param(
        [string]$BaseUrl,
        [string]$TenantId,
        [string]$Username,
        [string]$Password
    )

    try {
        $authUrl = "$BaseUrl/$TenantId/oauth2/token"

        $body = @{
            grant_type = "password"
            username = $Username
            password = $Password
        }

        Write-ColorOutput "Authenticating to Process Manager..." "Cyan"

        $response = Invoke-RestMethod -Uri $authUrl -Method Post -Body $body -ContentType "application/x-www-form-urlencoded"

        if ($response.access_token) {
            Write-ColorOutput "Authentication successful!" "Green"
            return $response.access_token
        }
        else {
            throw "Authentication failed: No access token received"
        }
    }
    catch {
        Write-ColorOutput "Authentication failed: $_" "Red"
        throw
    }
}

# Function to get search service token
function Get-SearchServiceToken {
    param(
        [string]$BaseUrl,
        [string]$TenantId,
        [string]$BearerToken
    )

    try {
        $searchTokenUrl = "$BaseUrl/$TenantId/search/GetSearchServiceToken"

        $headers = @{
            Authorization = "Bearer $BearerToken"
        }

        Write-ColorOutput "Getting search service token..." "Cyan"

        $response = Invoke-RestMethod -Uri $searchTokenUrl -Method Get -Headers $headers

        if ($response.Status -eq "Success" -and $response.Message) {
            Write-ColorOutput "Search service token obtained successfully!" "Green"
            return $response.Message
        }
        else {
            throw "Failed to get search service token: Invalid response"
        }
    }
    catch {
        Write-ColorOutput "Failed to get search service token: $_" "Red"
        throw
    }
}

# Function to search for processes by document name
function Search-ProcessesByDocument {
    param(
        [string]$SearchEndpoint,
        [string]$SearchToken,
        [string]$DocumentName
    )

    try {
        # URL encode the search criteria with quotes for exact matching
        # The quotes ensure we search for the exact phrase, not fuzzy match
        # Example: "Action Item" becomes %22Action%20Item%22
        $searchCriteria = [System.Uri]::EscapeDataString("`"$DocumentName`"")

        # Build the search URL
        # IncludedTypes=1 means UnpublishedProcess
        # SearchMatchType=0 is default matching
        $searchUrl = "$SearchEndpoint/fullsearch?SearchCriteria=$searchCriteria&IncludedTypes=1&SearchMatchType=0&pageNumber=1"

        $headers = @{
            Authorization = "Bearer $SearchToken"
            "Content-Type" = "application/json"
        }

        Write-ColorOutput "  Searching for: `"$DocumentName`"" "Gray"
        Write-Verbose "  Search URL: $searchUrl"
        Write-Verbose "  Encoded criteria: $searchCriteria"

        $response = Invoke-RestMethod -Uri $searchUrl -Method Get -Headers $headers

        # Log the full response structure for debugging
        Write-Verbose "  Raw response type: $($response.GetType().Name)"
        Write-Verbose "  Response.success property: $($response.success)"

        if ($null -eq $response) {
            Write-Verbose "  Response is null"
            return @()
        }

        if ($null -eq $response.response) {
            Write-Verbose "  Response.response is null"
            return @()
        }

        # Force response.response to be an array
        $results = @($response.response)

        Write-Verbose "  Results array count: $($results.Count)"

        if ($response.success -eq $true -or $response.success -eq "true") {
            if ($results.Count -gt 0) {
                Write-Verbose "  Returning $($results.Count) result(s)"

                # Log the first result for debugging
                if ($results.Count -gt 0) {
                    Write-Verbose "  First result Name: $($results[0].Name)"
                    Write-Verbose "  First result EntityType: $($results[0].EntityType)"
                }

                return $results
            }
            else {
                Write-Verbose "  Results array is empty"
                return @()
            }
        }
        else {
            Write-ColorOutput "  API returned success=$($response.success)" "Yellow"
            return @()
        }
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-ColorOutput "  Error searching for '$DocumentName': $errorMsg" "Yellow"
        Write-Verbose "  Exception details: $errorMsg"
        Write-Verbose "  Exception type: $($_.Exception.GetType().Name)"

        if ($_.Exception.Response) {
            Write-Verbose "  Status code: $($_.Exception.Response.StatusCode)"
            Write-Verbose "  Status description: $($_.Exception.Response.StatusDescription)"
        }

        # Try to get more details from the error record
        if ($_.ErrorDetails) {
            Write-Verbose "  Error details: $($_.ErrorDetails.Message)"
        }

        return @()
    }
}

# Main script execution
try {
    Write-ColorOutput "`n=== Process Manager Unpublished Process Search ===" "Cyan"
    Write-ColorOutput "This script searches for unpublished processes that reference specific documents.`n" "White"

    if ($VerbosePreference -eq 'SilentlyContinue') {
        Write-ColorOutput "Tip: Run with -Verbose flag for detailed debugging output" "Gray"
    }
    Write-Host ""

    # Get Process Manager Site URL
    $siteUrl = Read-Host "Enter the Process Manager Site URL (e.g., https://demo.promapp.com)"
    $siteUrl = $siteUrl.TrimEnd('/')

    # Get Tenant ID
    $tenantId = Read-Host "Enter the Tenant ID (automation tenant)"

    # Get credentials
    $username = Read-Host "Enter your username"
    $securePassword = Read-Host "Enter your password" -AsSecureString
    $password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
    )

    # Authenticate
    $bearerToken = Get-AuthToken -BaseUrl $siteUrl -TenantId $tenantId -Username $username -Password $password

    # Get search service token
    $searchToken = Get-SearchServiceToken -BaseUrl $siteUrl -TenantId $tenantId -BearerToken $bearerToken

    # Determine the correct search endpoint based on region
    $searchEndpoint = Get-SearchEndpoint -BaseUrl $siteUrl

    # Get CSV file path
    Write-ColorOutput "`nEnter the path to the CSV file containing document names." "Cyan"
    Write-ColorOutput "The CSV should have a column named 'DocumentName'." "Gray"
    $csvPath = Read-Host "CSV file path"

    # Validate CSV file exists
    if (-not (Test-Path $csvPath)) {
        throw "CSV file not found: $csvPath"
    }

    # Read document names from CSV
    Write-ColorOutput "`nReading document names from CSV..." "Cyan"
    $documentData = Import-Csv -Path $csvPath

    # Validate CSV has DocumentName column
    if (-not ($documentData | Get-Member -Name "DocumentName" -MemberType NoteProperty)) {
        throw "CSV file must contain a 'DocumentName' column"
    }

    $documentNames = $documentData | Select-Object -ExpandProperty DocumentName | Where-Object { $_ -and $_.Trim() -ne "" }

    Write-ColorOutput "Found $($documentNames.Count) document names to search.`n" "Green"

    # Search for processes
    $allResults = @()
    $processedCount = 0

    foreach ($docName in $documentNames) {
        $processedCount++
        Write-ColorOutput "[$processedCount/$($documentNames.Count)] Processing: $docName" "Cyan"

        $processes = Search-ProcessesByDocument -SearchEndpoint $searchEndpoint -SearchToken $searchToken -DocumentName $docName

        # Ensure we have an array
        $processArray = @($processes)

        Write-Verbose "Main loop received $($processArray.Count) result(s) from search function"

        if ($processArray.Count -gt 0) {
            Write-ColorOutput "  Found $($processArray.Count) unpublished process(es)" "Green"

            foreach ($process in $processArray) {
                Write-Verbose "    Adding process: $($process.Name) (ID: $($process.ProcessUniqueId))"

                $allResults += [PSCustomObject]@{
                    DocumentName = $docName
                    ProcessName = $process.Name
                    ProcessUniqueId = $process.ProcessUniqueId
                    ItemUrl = $process.ItemUrl
                    EntityType = $process.EntityType
                }
            }
        }
        else {
            Write-ColorOutput "  No unpublished processes found" "Gray"
        }

        # Small delay to avoid overwhelming the API
        Start-Sleep -Milliseconds 500
    }

    # Export results to CSV
    if ($allResults.Count -gt 0) {
        $outputPath = Join-Path (Split-Path $csvPath -Parent) "UnpublishedProcesses_Results_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"

        $allResults | Export-Csv -Path $outputPath -NoTypeInformation -Encoding UTF8

        Write-ColorOutput "`n=== Search Complete ===" "Green"
        Write-ColorOutput "Total unpublished processes found: $($allResults.Count)" "Green"
        Write-ColorOutput "Results exported to: $outputPath" "Cyan"

        # Display summary
        Write-ColorOutput "`nSummary by Document:" "Cyan"
        $allResults | Group-Object DocumentName | ForEach-Object {
            Write-ColorOutput "  $($_.Name): $($_.Count) process(es)" "White"
        }
    }
    else {
        Write-ColorOutput "`n=== Search Complete ===" "Yellow"
        Write-ColorOutput "No unpublished processes found for any of the document names." "Yellow"
    }
}
catch {
    Write-ColorOutput "`nError: $_" "Red"
    exit 1
}
