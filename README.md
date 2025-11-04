# Unpublished Process Document Search Script

This PowerShell script searches for unpublished processes in Process Manager that reference specific document names.

## Overview

The script:
1. Authenticates to the Process Manager API using OAuth2
2. Automatically routes search requests to the correct regional endpoint
3. Reads document names from a CSV file
4. Searches for unpublished processes that reference each document
5. Exports the results to a new CSV file with process names, unique IDs, and URLs

## Regional Endpoints

The script automatically detects your Process Manager region and routes search requests to the appropriate search endpoint:

| Region | Base URL | Search Endpoint |
|--------|----------|-----------------|
| Demo | https://demo.promapp.com | https://dmo-wus-sch.promapp.io |
| US | https://us.promapp.com | https://prd-wus-sch.promapp.io |
| Canada | https://ca.promapp.com | https://prd-cac-sch.promapp.io |
| Europe | https://eu.promapp.com | https://prd-neu-sch.promapp.io |
| Australia | https://au.promapp.com | https://prd-aus-sch.promapp.io |

**Note**: Authentication is performed against the base URL, while search requests are routed to the regional search endpoint. This happens automatically based on the site URL you provide.

## Prerequisites

- PowerShell 5.1 or higher
- Network access to your Process Manager instance
- Valid Process Manager credentials
- A CSV file containing document names to search for

## CSV Input Format

Create a CSV file with a column named `DocumentName`:

```csv
DocumentName
Screenshot 2025-11
Test Document
Employee Handbook
Training Manual
Policy Document
```

See `SampleDocumentNames.csv` for an example.

## Usage

1. Run the script:
   ```powershell
   .\Search-UnpublishedProcesses.ps1
   ```

2. The script will prompt you for:
   - Process Manager Site URL (e.g., `https://demo.promapp.com`)
   - Tenant ID (your automation tenant identifier)
   - Username
   - Password
   - Path to the CSV file containing document names

3. The script will:
   - Authenticate to Process Manager (OAuth2)
   - Obtain a search service token
   - Determine the regional search endpoint
   - Search for each document name (with quotes for exact matching)
   - Display progress in the console
   - Export results to a timestamped CSV file

### Verbose Mode

For debugging and detailed output, run the script with the `-Verbose` flag:

```powershell
.\Search-UnpublishedProcesses.ps1 -Verbose
```

This will show:
- The exact search URLs being called
- Response success status and result counts
- Detailed error messages and exception details
- Authentication and token retrieval process details

## Output

The script generates a CSV file named `UnpublishedProcesses_Results_YYYYMMDD_HHMMSS.csv` in the same directory as your input CSV.

### Output CSV Columns

- **DocumentName**: The document name that was searched
- **ProcessName**: The name of the unpublished process found
- **ProcessUniqueId**: The unique identifier for the process
- **ItemUrl**: Direct URL to view the process
- **EntityType**: The entity type (typically "UnpublishedProcess")

## Example Output

### Console Output

```
=== Process Manager Unpublished Process Search ===
This script searches for unpublished processes that reference specific documents.

Authenticating to Process Manager...
Authentication successful!
Getting search service token...
Search service token obtained successfully!
Using regional search endpoint: https://dmo-wus-sch.promapp.io

Reading document names from CSV...
Found 3 document names to search.

[1/3] Processing: Action Item
  Searching for: "Action Item"
  Found 2 unpublished process(es)
[2/3] Processing: Screenshot 2025-11
  Searching for: "Screenshot 2025-11"
  Found 1 unpublished process(es)
[3/3] Processing: Employee Handbook
  Searching for: "Employee Handbook"
  No unpublished processes found

=== Search Complete ===
Total unpublished processes found: 3
Results exported to: UnpublishedProcesses_Results_20251104_143022.csv
```

### CSV Output

```csv
DocumentName,ProcessName,ProcessUniqueId,ItemUrl,EntityType
Action Item,Process Review Workflow,abc123...,https://demo.promapp.com/.../Process/abc123...,UnpublishedProcess
Action Item,Document Management,def456...,https://demo.promapp.com/.../Process/def456...,UnpublishedProcess
Screenshot 2025-11,DeDocument Test,bc18b3a1...,https://demo.promapp.com/.../Process/bc18b3a1...,UnpublishedProcess
```

## API Details

The script uses the following Process Manager APIs in sequence:

### 1. OAuth2 Authentication
- **Base URL**: The main Process Manager site URL (e.g., `https://demo.promapp.com`)
- **Endpoint**: `/{tenantId}/oauth2/token`
- **Method**: POST
- **Body**: `grant_type=password&username={username}&password={password}`
- **Returns**: Bearer token for API authentication

### 2. Get Search Service Token
- **Base URL**: The main Process Manager site URL (e.g., `https://demo.promapp.com`)
- **Endpoint**: `/{tenantId}/search/GetSearchServiceToken`
- **Method**: GET
- **Authentication**: Bearer token from step 1
- **Returns**: JSON with `Status: "Success"` and `Message` containing the search service token

### 3. Search
- **Base URL**: Regional search endpoint (automatically determined, e.g., `https://dmo-wus-sch.promapp.io`)
- **Endpoint**: `/fullsearch`
- **Method**: GET
- **Authentication**: Search service token from step 2
- **Parameters**:
  - `SearchCriteria`: Document name (URL-encoded with quotes)
  - `IncludedTypes`: 1 (UnpublishedProcess)
  - `SearchMatchType`: 0 (default matching)
  - `pageNumber`: 1

### Authentication Flow

```
1. User credentials → OAuth2 Token (Bearer Token)
2. Bearer Token → Search Service Token
3. Search Service Token → Search API calls
```

The script automatically handles all three steps. The search service token is required for authenticating against the regional search endpoints.

## Search Behavior

### Exact Match vs. Fuzzy Search

The script automatically wraps all document names in **double quotes** to perform exact phrase matching. This prevents fuzzy search from returning irrelevant results.

For example:
- Searching for `Action Item` without quotes might return results for "Action", "Item", "Actions", "Items", etc.
- Searching for `"Action Item"` (with quotes) returns only exact matches for "Action Item"

**The script automatically adds quotes for you**, so you don't need to include them in your CSV file.

Example CSV:
```csv
DocumentName
Action Item
Screenshot 2025-11
Employee Handbook
```

The script will search for `"Action Item"`, `"Screenshot 2025-11"`, and `"Employee Handbook"` (with quotes).

### Search Fields

The search looks across multiple fields in unpublished processes:
- Document names and attachments
- Activity names and descriptions
- Process names and objectives
- Notes and background text
- Other searchable content fields

## Troubleshooting

### Authentication Failures
- Verify your username and password are correct
- Ensure the tenant ID is correct
- Check that your account has API access enabled

### Search Service Token Failures
- If you receive a 401 Unauthorized error during searches, the search service token may have failed
- Verify the bearer token is valid and not expired
- Check that your account has search API permissions
- Ensure the tenant ID is correct in the search token endpoint

### No Results Found

If the script reports "No unpublished processes found" but you know results exist:

1. **Run with Verbose Mode**:
   ```powershell
   .\Search-UnpublishedProcesses.ps1 -Verbose
   ```
   This will show:
   - The exact search URL being called
   - The API response status
   - The number of results returned

2. **Check the Search Term**:
   - Verify document names are spelled exactly as they appear in Process Manager
   - The script automatically adds quotes for exact matching
   - Check for extra spaces or special characters in your CSV

3. **Verify Against API Directly**:
   - Copy the search URL from verbose output
   - Test it directly in a browser or API client
   - Compare the response with what the script reports

4. **Common Causes**:
   - Document is referenced in a **published** process (script only searches unpublished)
   - Document name has slight differences (case-sensitive, extra spaces, etc.)
   - Search service token has expired (script will show 401 error)
   - Regional endpoint is incorrect (verify the endpoint shown in verbose output)

5. **Check Process Type**:
   - The script searches only for `IncludedTypes=1` (UnpublishedProcess)
   - If you need published processes, the script would need to be modified

### Network Errors
- Ensure you have network access to the Process Manager instance
- Check if a proxy is required and configure PowerShell accordingly
- Verify the site URL is correct and includes `https://`

## Rate Limiting

The script includes a 500ms delay between API calls to avoid overwhelming the server. Adjust the `Start-Sleep` value in the script if needed.

## Security Notes

- The script prompts for passwords securely using `Read-Host -AsSecureString`
- Credentials are not stored or logged
- Bearer tokens are kept in memory only for the duration of the script execution

## API Documentation

For more information about the Process Manager Search API, see:
- `ExampleSpec.json` - OpenAPI specification
- `ExampleSearchOutput.json` - Sample search response
- `ExampleAuthOutput.json` - Sample authentication response
- `Example.txt` - Additional notes and examples
