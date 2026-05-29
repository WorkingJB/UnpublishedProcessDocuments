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
VIC Filenaming Approved Standard.JPG
Test Document.pdf
Employee Handbook.docx
Training Manual
Policy Document
```

You can include file extensions (e.g. `.JPG`, `.pdf`, `.docx`) in the document
names — the script strips recognised extensions automatically before searching,
because the search API does not match names that include the extension. See
[File Extension Handling](#file-extension-handling) for details.

See `SampleDocumentNames.csv` for an example.

## Usage

1. Run the script:
   ```powershell
   .\Search-UnpublishedProcesses.ps1
   ```

2. The script will prompt you for:
   - Full Process Manager Site URL **including your site name** (e.g., `https://au.promapp.com/promapp`). The script automatically splits this into the base URL (`https://au.promapp.com`) and the site name (`promapp`), so you no longer need to enter them separately.
   - Username
   - Password
   - Path to the CSV file containing document names

   > If the URL you enter does not contain a site name segment, the script will fall back to asking for the Site Name separately.

3. The script will:
   - Authenticate to Process Manager (OAuth2)
   - Obtain a search service token
   - Determine the regional search endpoint
   - Strip any recognised file extension from each document name (see [File Extension Handling](#file-extension-handling))
   - Search for each document name (with quotes for exact matching)
   - Display progress in the console
   - Export results to a timestamped CSV file

### Verbose Mode (Highly Recommended for Debugging)

For debugging and detailed output, run the script with the `-Verbose` flag:

```powershell
.\Search-UnpublishedProcesses.ps1 -Verbose
```

This will show extensive debugging information:
- **The exact search URLs** being called (with URL-encoded quotes)
- **Encoded search criteria** (e.g., `%22Action%20Item%22`)
- **Response object types** and structure
- **Response success property** value
- **Results array count** at each step
- **Sample result details** (Name, EntityType, UniqueId)
- **Detailed error messages** with status codes
- **Authentication and token** retrieval details

Example verbose output:
```
  Searching for: "Action Item"
  Search URL: https://dmo-wus-sch.promapp.io/fullsearch?SearchCriteria=%22Action%20Item%22&IncludedTypes=1...
  Encoded criteria: %22Action%20Item%22
  Raw response type: PSCustomObject
  Response.success property: True
  Results array count: 2
  Returning 2 result(s)
  First result Name: Document Review Process
  First result EntityType: UnpublishedProcess
Main loop received 2 result(s) from search function
    Adding process: Document Review Process (ID: abc-123...)
    Adding process: Action Item Workflow (ID: def-456...)
```

**Use this mode first** if you encounter any issues with missing results or fuzzy searches.

## Output

The script generates a CSV file named `UnpublishedProcesses_Results_YYYYMMDD_HHMMSS.csv` in the same directory as your input CSV.

### Output CSV Columns

- **DocumentName**: The original document name from your input CSV (including any extension)
- **SearchTerm**: The term actually sent to the search API (with any recognised file extension stripped)
- **ProcessName**: The name of the unpublished process found
- **ProcessUniqueId**: The unique identifier for the process
- **ItemUrl**: Direct URL to view the process
- **EntityType**: The entity type (typically "UnpublishedProcess")

## Example Output

### Console Output

```
=== Process Manager Unpublished Process Search ===
This script searches for unpublished processes that reference specific documents.

Site URL:  https://au.promapp.com
Site Name: apagroup
Authenticating to Process Manager...
Authentication successful!
Getting search service token...
Search service token obtained successfully!
Using regional search endpoint: https://prd-aus-sch.promapp.io

Reading document names from CSV...
Found 3 document names to search.

[1/3] Processing: Action Item
  Searching for: "Action Item"
  Found 2 unpublished process(es)
[2/3] Processing: VIC Filenaming Approved Standard.JPG
  Stripped file extension; searching for: "VIC Filenaming Approved Standard"
  Searching for: "VIC Filenaming Approved Standard"
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
DocumentName,SearchTerm,ProcessName,ProcessUniqueId,ItemUrl,EntityType
Action Item,Action Item,Process Review Workflow,abc123...,https://au.promapp.com/.../Process/abc123...,UnpublishedProcess
Action Item,Action Item,Document Management,def456...,https://au.promapp.com/.../Process/def456...,UnpublishedProcess
VIC Filenaming Approved Standard.JPG,VIC Filenaming Approved Standard,Creating New Estate Gas Drawings (As-Is),bbe6a31f...,https://au.promapp.com/.../Process/bbe6a31f...,UnpublishedProcess
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

### File Extension Handling

The Process Manager search API does **not** match document names when the file
extension is included in the search term. For example:

- Searching for `"VIC Filenaming Approved Standard.JPG"` returns **0 results**
- Searching for `"VIC Filenaming Approved Standard"` returns the unpublished process that references it

To work around this, the script automatically **strips a recognised file
extension** from each document name before searching. The original name is still
recorded in the `DocumentName` output column, and the term actually searched is
recorded in the `SearchTerm` column.

Extensions are only removed when they match a curated list of common file types
(documents, spreadsheets, presentations, images, diagrams, email, web/markup,
archives, and media — e.g. `.pdf`, `.docx`, `.xlsx`, `.jpg`, `.png`, `.vsdx`,
`.msg`, `.zip`, `.mp4`). Matching against a known list — rather than blindly
removing everything after the last `.` — avoids mangling names that legitimately
contain periods (for example, `Screenshot 2025-11-03 at 10.48.47` is left
untouched because `.47` is not a recognised extension).

If you need to support an extension that isn't in the list, add it to the
`$script:CommonFileExtensions` array near the top of `Search-UnpublishedProcesses.ps1`.

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

1. **Run with Verbose Mode** (MOST IMPORTANT STEP):
   ```powershell
   .\Search-UnpublishedProcesses.ps1 -Verbose
   ```

   Look for these key indicators in the verbose output:
   - **Encoded criteria**: Should show `%22YourSearchTerm%22` (quotes encoded as %22)
   - **Response.success property**: Should be `True`
   - **Results array count**: Should show the number of items returned
   - If count is 0 but you expect results, the issue is with the API/search term
   - If count is > 0 but script says "No unpublished processes found", there's a bug (please report)

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
