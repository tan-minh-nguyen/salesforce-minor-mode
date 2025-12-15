# PLAN: Integrate SOQL Completions into Apex-TS-Mode with Eglot

## Goal
Enable SOQL/SOSL field completion within Apex code when cursor is inside embedded SOQL/SOSL queries, working seamlessly with Eglot LSP.

## Background

### Current Setup
- **Eglot LSP:** Already configured for apex-ts-mode
- **LSP Server:** `apex-jorje-lsp.jar` with `:enableEmbeddedSoqlCompletion t`
- **Completion:** Eglot uses `completion-at-point-functions` (CAPF)
- **SOQL Completion:** Already implemented as `soql-capf` and `soql-completion` core

### Tree-Sitter Apex Grammar
The Apex tree-sitter grammar includes embedded SOQL/SOSL parsers:
- SOQL queries are embedded in Apex code within `[SELECT ... FROM ...]` brackets
- SOSL queries are embedded with `[FIND ... IN ...]` syntax
- The grammar creates distinct node types for these embedded languages

**References:**
- [tree-sitter-sfapex - Apex, SOQL, SOSL Grammar](https://github.com/aheber/tree-sitter-sfapex)
- [web-tree-sitter-sfapex npm package](https://www.npmjs.com/package/web-tree-sitter-sfapex)
- [Tree-sitter Query Syntax](https://tree-sitter.github.io/tree-sitter/using-parsers/queries/1-syntax.html)

### Eglot CAPF Integration
Eglot adds its completion function to `completion-at-point-functions`:
```elisp
completion-at-point-functions = (eglot-completion-at-point ...)
```

Our strategy: Add SOQL completion BEFORE Eglot, so it takes precedence in SOQL context.

## Architecture

### Completion Chain with Eglot

```
completion-at-point-functions (ordered list)
    ↓
1. apex-soql-capf           ← NEW: Check if in SOQL
    ↓                           ↓
   No (in Apex)            Yes (in SOQL)
    ↓                           ↓
   :exclusive 'no          soql-capf()
    ↓                      returns completion
   Continue to next
    ↓
2. eglot-completion-at-point ← Eglot LSP completion
    ↓
3. Other CAPF functions
```

### Detection Strategy
Use tree-sitter to detect if point is within SOQL/SOSL context:

```elisp
point in buffer
    ↓
treesit-node-at(point)
    ↓
treesit-parent-until → find parent node
    ↓
check node-type:
    - soql_query_body  → Return SOQL completion
    - sosl_query_body  → Return SOQL completion  
    - else             → Return nil (let Eglot handle)
```

## Implementation Steps

### Step 1: Create apex-completion-context.el
**File:** `apex-ts-mode/apex-completion-context.el`

Detect completion context within Apex:

```elisp
;;; apex-completion-context.el --- Detect SOQL/SOSL context in Apex -*- lexical-binding: t; -*-

;;; Commentary:
;; Uses tree-sitter to detect if point is inside embedded SOQL/SOSL query.

;;; Code:

(require 'treesit)

(defun apex-completion--in-soql-p ()
  "Return non-nil if point is inside SOQL query."
  (when-let ((node (treesit-node-at (point))))
    (treesit-parent-until 
     node
     (lambda (n)
       (member (treesit-node-type n)
               '("soql_query_body" 
                 "query_expression"
                 "soql_literal"))))))

(defun apex-completion--in-sosl-p ()
  "Return non-nil if point is inside SOSL query."
  (when-let ((node (treesit-node-at (point))))
    (treesit-parent-until 
     node
     (lambda (n)
       (member (treesit-node-type n)
               '("sosl_query_body" 
                 "find_expression"
                 "sosl_literal"))))))

(defun apex-completion--current-context ()
  "Determine current completion context.
Returns 'soql, 'sosl, or 'apex."
  (cond
   ((apex-completion--in-soql-p) 'soql)
   ((apex-completion--in-sosl-p) 'sosl)
   (t 'apex)))

(provide 'apex-completion-context)

;;; apex-completion-context.el ends here
```

### Step 2: Create apex-soql-capf.el
**File:** `apex-ts-mode/apex-soql-capf.el`

CAPF wrapper that delegates to SOQL completion when appropriate:

```elisp
;;; apex-soql-capf.el --- SOQL completion in Apex via CAPF -*- lexical-binding: t; -*-

;;; Commentary:
;; Provides SOQL/SOSL completion within Apex code.
;; Works with Eglot by being added to completion-at-point-functions BEFORE Eglot.

;;; Code:

(require 'apex-completion-context)
(require 'soql-completion nil t)

(defun apex-soql-capf ()
  "Completion-at-point function for SOQL/SOSL within Apex.
Returns nil when not in SOQL context, allowing Eglot to handle Apex completion."
  (let ((context (apex-completion--current-context)))
    (pcase context
      ((or 'soql 'sosl)
       ;; In SOQL/SOSL context - delegate to soql-capf
       (when (and (require 'soql-capf nil t)
                  (fboundp 'soql-capf))
         (soql-capf)))
      
      ('apex
       ;; In Apex context - return nil to let Eglot handle it
       nil))))

(defun apex-soql-capf-setup ()
  "Setup SOQL completion in Apex mode.
Adds apex-soql-capf BEFORE eglot-completion-at-point in the hook list."
  ;; Add at the beginning so it runs before Eglot
  (add-hook 'completion-at-point-functions #'apex-soql-capf -10 t))

(provide 'apex-soql-capf)

;;; apex-soql-capf.el ends here
```

### Step 3: Update apex-ts-mode--soql-embeded
**File:** `apex-ts-mode/apex-ts-mode.el` (line 379)

Replace empty function with proper setup:

```elisp
(defun apex-ts-mode--soql-embeded ()
  "Setup completion for embedded SOQL/SOSL statements.
Works with Eglot by adding SOQL completion before Eglot's CAPF."
  (when (require 'apex-soql-capf nil t)
    (apex-soql-capf-setup)))
```

### Step 4: Ensure dependencies are loaded
**File:** `apex-ts-mode/apex-ts-mode.el` (requires section at top)

Add after existing requires:
```elisp
(require 'apex-completion-context nil t)
(require 'soql-completion nil t)
```

### Step 5: Optional - Company Mode Support
**File:** `apex-ts-mode/apex-company.el` (if Company is used)

For users who prefer Company over CAPF:

```elisp
;;; apex-company.el --- Company backend for Apex with SOQL support -*- lexical-binding: t; -*-

;;; Commentary:
;; Company backend that provides SOQL completion in embedded queries.

;;; Code:

(require 'apex-completion-context)
(require 'soql-company)
(require 'company)

(defun company-apex (command &optional arg &rest ignored)
  "Company backend for Apex with SOQL/SOSL support.
Delegates to company-soql when in SOQL context."
  (interactive (list 'interactive))
  
  (let ((context (apex-completion--current-context)))
    (cl-case command
      (interactive 
       (company-begin-backend 'company-apex))
      
      (prefix
       (pcase context
         ((or 'soql 'sosl)
          ;; Delegate to company-soql
          (when (fboundp 'company-soql)
            (company-soql 'prefix arg)))
         ('apex
          ;; Standard Apex completion prefix
          (company-grab-symbol))))
      
      (candidates
       (pcase context
         ((or 'soql 'sosl)
          (when (fboundp 'company-soql)
            (company-soql 'candidates arg)))
         ('apex
          nil))) ; Let other backends handle Apex
      
      (annotation
       (when (memq context '(soql sosl))
         (when (fboundp 'company-soql)
           (company-soql 'annotation arg))))
      
      (meta
       (when (memq context '(soql sosl))
         (when (fboundp 'company-soql)
           (company-soql 'meta arg))))
      
      (doc-buffer
       (when (memq context '(soql sosl))
         (when (fboundp 'company-soql)
           (company-soql 'doc-buffer arg)))))))

(defun apex-company-setup ()
  "Setup Company backend for Apex with SOQL support."
  (add-to-list 'company-backends 'company-apex))

(provide 'apex-company)

;;; apex-company.el ends here
```

## File Structure After Integration

```
apex-ts-mode/
├── apex-completion-context.el  # NEW - Context detection
├── apex-soql-capf.el           # NEW - CAPF integration (Eglot compatible)
├── apex-company.el             # NEW - Company integration (optional)
├── apex-ts-mode.el             # UPDATED - Enable in hook
└── extensions/
    └── apex-language-server.el # EXISTS - Eglot config

soql-ts-mode/
├── soql-completion.el          # EXISTS - Core logic
├── soql-capf.el                # EXISTS - CAPF support
└── soql-company.el             # EXISTS - Company support
```

## How It Works with Eglot

### CAPF Priority System

Eglot adds `eglot-completion-at-point` to `completion-at-point-functions`. Our strategy:

1. **Add apex-soql-capf with priority -10** (runs early)
2. **apex-soql-capf checks context:**
   - In SOQL → Return completion, `:exclusive 'no` allows fallback
   - In Apex → Return `nil`, next function (Eglot) runs
3. **Eglot runs for Apex completion**

### Key: Using `:exclusive` properly

```elisp
;; In soql-capf (already implemented)
(list start end candidates
      :exclusive 'no  ; Allow other completions if SOQL fails
      ...)
```

This ensures:
- SOQL completion works in queries
- Eglot still works in Apex code
- Graceful fallback if SOQL completion fails

## Testing Strategy

### Test Cases

1. **SOQL in variable assignment:**
   ```apex
   List<Account> accs = [SELECT Id, Na| FROM Account];
   //                             ^ cursor
   ```
   **Expected:** Show Account fields from soql-completion

2. **Apex method call:**
   ```apex
   Account acc = new Account();
   acc.get|
   //     ^ cursor
   ```
   **Expected:** Show Apex methods from Eglot LSP

3. **SOQL WHERE clause:**
   ```apex
   [SELECT Name FROM Lead WHERE Status = 'New' AND Indu|]
   //                                              ^ cursor  
   ```
   **Expected:** Show Lead fields from soql-completion

4. **Apex variable:**
   ```apex
   String myNa| = 'test';
   //        ^ cursor
   ```
   **Expected:** Show Apex completions from Eglot

5. **SOSL query:**
   ```apex
   [FIND 'test' IN ALL FIELDS RETURNING Account(Na|)]
   //                                       ^ cursor
   ```
   **Expected:** Show Account fields from soql-completion

6. **Nested SOQL:**
   ```apex
   [SELECT Id, (SELECT FirstN| FROM Contacts) FROM Account]
   //                     ^ cursor
   ```
   **Expected:** Show Contact fields from soql-completion

### Verify Eglot Integration

```elisp
;; Check completion-at-point-functions order
M-x eval-expression completion-at-point-functions

;; Should show:
;; (apex-soql-capf eglot-completion-at-point ...)

;; Test in SOQL context
M-x eval-expression (apex-completion--current-context)
;; Should return: soql

;; Test in Apex context
M-x eval-expression (apex-completion--current-context)
;; Should return: apex
```

### Debug Commands

```elisp
;; Check current context
(apex-completion--current-context)

;; Inspect node at point
(treesit-node-type (treesit-node-at (point)))

;; Check parent nodes
(let ((node (treesit-node-at (point))))
  (while node
    (message "Node: %s" (treesit-node-type node))
    (setq node (treesit-node-parent node))))

;; Test SOQL detection
(apex-completion--in-soql-p)
```

## Benefits

✅ **Seamless Eglot integration** - No conflicts with LSP
✅ **SOQL completion in Apex** - Automatic field completion
✅ **No manual switching** - Context detected via tree-sitter
✅ **Fallback to Eglot** - Apex code uses LSP completion
✅ **SOSL support** - Works with FIND queries
✅ **Works with Corfu** - CAPF compatible
✅ **Optional Company** - Alternative backend available

## Potential Issues & Solutions

### Issue 1: Node Type Names May Vary
**Solution:** Add debug helper to inspect actual node types:
```elisp
(defun apex-debug-node-at-point ()
  "Show tree-sitter node hierarchy at point."
  (interactive)
  (let ((node (treesit-node-at (point)))
        (nodes '()))
    (while node
      (push (treesit-node-type node) nodes)
      (setq node (treesit-node-parent node)))
    (message "Node hierarchy: %s" nodes)))
```

### Issue 2: Eglot Takes Priority
**Solution:** Use negative priority (-10) when adding to hook:
```elisp
(add-hook 'completion-at-point-functions #'apex-soql-capf -10 t)
```

### Issue 3: SOQL Completion Returns Empty
**Solution:** Ensure SObject metadata is generated:
```elisp
M-x salesforce-sobject-refresh
```

### Issue 4: Both SOQL and Eglot Complete
**Solution:** Ensure SOQL capf returns `:exclusive 'no` (already implemented)

## Implementation Priority

1. ✅ **Phase 1:** Context detection (`apex-completion-context.el`)
2. ✅ **Phase 2:** CAPF integration (`apex-soql-capf.el`)
3. ✅ **Phase 3:** Update `apex-ts-mode--soql-embeded()`
4. ⏳ **Phase 4:** Test with Eglot + Corfu
5. 📋 **Phase 5:** Optional Company support
6. 🧪 **Phase 6:** Comprehensive testing

## Success Criteria

- [ ] SOQL completion works in Apex files with Eglot enabled
- [ ] Completion shows correct SObject fields
- [ ] Eglot completion still works for Apex code
- [ ] No conflicts between SOQL and Eglot completion
- [ ] Works with Corfu (CAPF-based)
- [ ] Optional Company backend available
- [ ] No performance degradation
- [ ] Handles nested SOQL queries
- [ ] SOSL queries supported
- [ ] Context detection accurate via tree-sitter

## Alternative: LSP-Based Approach

If tree-sitter detection proves difficult, leverage LSP's embedded completion:

```elisp
;; The LSP already has :enableEmbeddedSoqlCompletion t
;; We could enhance it instead of bypassing it

;; However, our approach is better because:
;; 1. More control over completion candidates
;; 2. Uses local SObject metadata (faster)
;; 3. Works offline
;; 4. Consistent with soql-ts-mode completion
```

## Notes on Eglot Behavior

- Eglot adds itself to `completion-at-point-functions`
- It respects `:exclusive` property from other CAPF functions
- Multiple CAPF functions can coexist in the list
- Order matters: earlier functions take priority
- Returning `nil` passes control to next function

This design ensures SOQL completion integrates naturally with Eglot!
