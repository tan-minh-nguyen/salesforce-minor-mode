# PLAN: Implement salesforcedx-sobjects-faux-generator

## Goal
Generate SObject metadata JSON files via Salesforce CLI as external process, mimicking VSCode extension behavior.

## Background
The VSCode extension uses `@salesforce/salesforcedx-sobjects-faux-generator` to:
- Generate SObject metadata from org
- Cache results in `.sfdx/tools/sobjects/`
- Provide "Refresh SObject Definitions" command

**References:**
- https://github.com/forcedotcom/salesforcedx-vscode
- https://marketplace.visualstudio.com/items?itemName=salesforce.salesforcedx-vscode
- https://developer.salesforce.com/docs/atlas.en-us.sfdx_cli_reference.meta/sfdx_cli_reference/cli_reference_force_schema.htm

## Architecture

```
salesforce-sobject.el
├── CLI Commands
│   ├── sf sobject list --json
│   └── sf sobject describe -s <name> --json
├── Cache Management
│   ├── .sfdx/tools/soqlMetadata/customObjects/
│   └── .sfdx/tools/soqlMetadata/standardObjects/
├── Batch Processing
│   ├── Async parallel execution
│   └── Progress reporting
└── Integration
    └── Auto-prompt in soql-completion
```

## CLI Commands

### List All SObjects
```bash
sf sobject list --json
```
Returns: Array of SObject names

### Describe SObject
```bash
sf sobject describe -s Account --json
```
Returns:
```json
{
  "status": 0,
  "result": {
    "name": "Account",
    "label": "Account",
    "fields": [
      {
        "name": "Id",
        "type": "id",
        "label": "Account ID",
        "picklistValues": []
      }
    ]
  }
}
```

## Implementation Steps

### Step 1: Create salesforce-sobject.el
**File:** `salesforce-sobject.el`

Core functionality:
```elisp
;; Configuration
salesforce-sobject-cache-dir
salesforce-sobject-batch-size

;; Core functions
salesforce-sobject--cache-dir ()
salesforce-sobject--list-all ()
salesforce-sobject--describe (sobject-name callback)
salesforce-sobject--save-metadata (sobject-name metadata)

;; Batch processing
salesforce-sobject--generate-batch (sobjects finished-callback)

;; Interactive commands
salesforce-sobject-refresh ()
salesforce-sobject-refresh-single (sobject-name)
salesforce-sobject-clear-cache ()
```

### Step 2: Add Process Macro to salesforce-core.el
**File:** `salesforce-core.el`

Add CLI wrapper:
```elisp
(cl-defmacro salesforce-core--sobject-process (&key args sync then)
  "Execute Salesforce CLI sobject command.")
```

### Step 3: Update soql-completion.el
**File:** `soql-ts-mode/soql-completion.el`

Smart metadata loading:
- Check if metadata file exists
- Prompt to generate if missing
- Call salesforce-sobject-refresh-single

### Step 4: Add Menu Integration
**File:** `salesforce-menu.el`

Add transient menu:
```elisp
(transient-define-prefix salesforce-sobject-menu ()
  ["SObject Metadata"
   [("r" "Refresh all SObjects" salesforce-sobject-refresh)
    ("s" "Refresh single SObject" salesforce-sobject-refresh-single)
    ("c" "Clear cache" salesforce-sobject-clear-cache)]])
```

## File Structure

### Cache Directory Layout
```
.sfdx/tools/soqlMetadata/
├── customObjects/
│   ├── MyCustomObject__c.json
│   └── AnotherObject__c.json
└── standardObjects/
    ├── Account.json
    ├── Contact.json
    └── Opportunity.json
```

### JSON File Format
Each file contains SObject metadata:
```json
{
  "name": "Account",
  "label": "Account",
  "fields": [
    {
      "name": "Name",
      "type": "string",
      "label": "Account Name",
      "picklistValues": []
    }
  ]
}
```

## Features

### Async Processing
- Non-blocking UI
- Progress reporting via modeline/messages
- Batch parallel execution

### Error Handling
- Invalid SObject names
- CLI failures
- Network issues
- Permission errors

### Cache Management
- Clear all cache
- Refresh specific SObjects
- Incremental updates (future)

### Progress Tracking
```elisp
(defvar salesforce-sobject--generation-progress nil
  "Current progress: (current . total)")
```

## Testing Checklist
- [ ] Test sf sobject list command
- [ ] Test sf sobject describe command
- [ ] Test single SObject generation
- [ ] Test batch processing (10 SObjects)
- [ ] Test full org refresh (100+ SObjects)
- [ ] Test error handling (invalid SObject)
- [ ] Test cache directory creation
- [ ] Test JSON file writing
- [ ] Test custom vs standard SObject paths
- [ ] Test integration with soql-completion
- [ ] Test cache clearing
- [ ] Verify progress reporting works

## Benefits
- Automatic metadata like VSCode
- No manual JSON file management
- Always up-to-date with org
- Async non-blocking
- Works with existing completion
- Extensible for future features
