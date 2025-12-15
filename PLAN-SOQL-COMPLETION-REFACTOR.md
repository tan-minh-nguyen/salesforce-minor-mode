# PLAN: Refactor soql-company.el for Corfu Support

## Goal
Refactor SOQL completion to be backend-agnostic, supporting both Company and Corfu completion frameworks.

## Current State
- `soql-company.el` is tightly coupled to Company-mode
- No support for Corfu or completion-at-point-functions
- All logic mixed with Company-specific code

## Target Architecture

```
soql-ts-mode/
├── soql-completion.el    # Core logic (NEW)
├── soql-company.el       # Company adapter (REFACTORED)
├── soql-capf.el          # Corfu/CAPF adapter (NEW)
└── soql-ts-mode.el       # Mode setup (UPDATED)
```

## Implementation Steps

### Step 1: Create soql-completion.el (Core)
**File:** `soql-ts-mode/soql-completion.el`

Extract backend-agnostic logic:
- Metadata file access
- Tree-sitter query functions
- Field data extraction
- Candidate generation

**Functions:**
```elisp
soql-completion--sobject-metadata (sobject-name)
soql-completion--match-fields (prefix sobject)
soql-completion--statement-root ()
soql-completion--statement-p ()
soql-completion--current-sobject ()
soql-completion--field-type (field)
soql-completion--field-annotation (field)
soql-completion--picklist-values (field)
soql-completion--candidates (&optional prefix)
soql-completion--get-bounds ()
```

**Data Structure:**
Each candidate returns: `(name . (:type "string" :annotation "S" :meta '(...)))`

### Step 2: Refactor soql-company.el
**File:** `soql-ts-mode/soql-company.el`

Slim down to Company-specific glue:
- Require soql-completion
- Implement company-soql as thin wrapper
- Map soql-completion functions to Company protocol

### Step 3: Create soql-capf.el
**File:** `soql-ts-mode/soql-capf.el`

Implement completion-at-point-functions:
- `soql-capf()` main function
- `soql-capf--annotation()` for annotations
- `soql-capf--exit()` for post-completion actions
- `soql-capf-setup()` to add to capf list

### Step 4: Update soql-ts-mode.el
**File:** `soql-ts-mode/soql-ts-mode.el`

Add smart completion backend detection:
```elisp
(defun soql-ts-mode--setup-completion ()
  "Setup completion backend based on available packages."
  (cond
   ((fboundp 'soql-capf-setup)
    (soql-capf-setup))
   ((fboundp 'company-mode)
    (require 'soql-company)
    (add-to-list 'company-backends 'company-soql))))
```

## Benefits
- Backend-agnostic core
- Works with Company, Corfu, and built-in completion
- Cleaner separation of concerns
- Future-proof for new completion frameworks
- Easier to test and maintain

## Testing Checklist
- [ ] Test with Company-mode
- [ ] Test with Corfu
- [ ] Test with vanilla completion-at-point
- [ ] Verify field completion works
- [ ] Verify annotations display correctly
- [ ] Verify picklist values shown in meta
- [ ] Test in SOQL files
- [ ] Test in Apex embedded SOQL
