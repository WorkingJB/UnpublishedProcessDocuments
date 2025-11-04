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
   - Search for each document name
   - Display progress in the console
   - Export results to a timestamped CSV file

## Output

The script generates a CSV file named `UnpublishedProcesses_Results_YYYYMMDD_HHMMSS.csv` in the same directory as your input CSV.

### Output CSV Columns

- **DocumentName**: The document name that was searched
- **ProcessName**: The name of the unpublished process found
- **ProcessUniqueId**: The unique identifier for the process
- **ItemUrl**: Direct URL to view the process
- **EntityType**: The entity type (typically "UnpublishedProcess")

## Example Output

```csv
DocumentName,ProcessName,ProcessUniqueId,ItemUrl,EntityType
Screenshot 2025-11,DeDocument Test,bc18b3a1-2c5d-4109-b379-0f0c890c2d86,https://demo.promapp.com/.../Process/bc18b3a1...,UnpublishedProcess
Test Document,Test Process,6b78b5ae-d7e5-480e-b385-ff1323c322e1,https://demo.promapp.com/.../Process/6b78b5ae...,UnpublishedProcess
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
- Verify document names are spelled correctly in the CSV
- Check that the documents are actually referenced in unpublished processes
- Try searching with partial document names

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
