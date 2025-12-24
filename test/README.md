# Salesforce Minor Mode Tests

This directory contains tests for the salesforce-minor-mode package.

## Test Files

- **`ob-soql-core-test.el`** - Tests for core SOQL functionality
  - SObject extraction from queries
  - CSV parsing and manipulation
  - Metadata building
  - Helper functions and macros

- **`ob-soql-vtable-test.el`** - Tests for vtable actions implementation
  - Action closure creation
  - Action handler functions
  - Change tracking
  - Display updates
  - Integration workflows

## Running Tests

### From Command Line

Run all tests in batch mode:

```bash
emacs -batch -l test/run-tests.el
```

### From Emacs

1. Load the test runner:
   ```
   M-x load-file RET test/run-tests.el RET
   ```

2. Run all tests:
   ```
   M-x ert RET t RET
   ```

3. Run specific test:
   ```
   M-x ert RET test-name RET
   ```

### Run Specific Test File

```elisp
;; Load and run ob-soql-core tests
M-x load-file RET test/ob-soql-core-test.el RET
M-x ert RET "^ob-soql-core-" RET

;; Load and run ob-soql-vtable tests
M-x load-file RET test/ob-soql-vtable-test.el RET
M-x ert RET "^ob-soql-vtable-" RET
```

## Test Coverage

### ob-soql-core-test.el

| Function | Tests | Coverage |
|----------|-------|----------|
| `ob-soql-core--extract-sobject` | 5 | ✅ Simple, custom, multiline, case-insensitive, error cases |
| `ob-soql-core--parse-csv` | 4 | ✅ Simple, empty, header-only, empty values |
| `ob-soql-core--org-url` | 1 | ✅ Basic functionality |
| `ob-soql-core--modify-csv` | 4 | ✅ With ID, case-insensitive, no ID, empty |
| `ob-soql-core--convert-id-to-hyperlink` | 1 | ✅ Basic conversion |
| `ob-soql-core--truncate-string` | 4 | ✅ Short, long, exact, disabled |
| `ob-soql--build-metadata` | 2 | ✅ Full metadata, auto-detect SObject |
| Macros | 3 | ✅ Temp buffer, buffer modifications, cleanup |
| **Total** | **24 tests** | |

### ob-soql-vtable-test.el

| Function | Tests | Coverage |
|----------|-------|----------|
| `ob-soql-vtable--make-action` | 1 | ✅ Closure creation |
| `ob-soql-vtable--create-actions` | 2 | ✅ Editable, read-only |
| `ob-soql-vtable--open-record` | 2 | ✅ With ID, without ID |
| `ob-soql-vtable--track-change` | 3 | ✅ New change, revert, multiple fields |
| `ob-soql-vtable--update-record-in-metadata` | 2 | ✅ Valid update, invalid ID |
| `ob-soql-vtable--get-field-info` | 1 | ✅ All field types |
| `ob-soql-vtable--show-help` | 2 | ✅ Editable, read-only |
| Integration | 1 | ✅ Full edit workflow |
| **Total** | **14 tests** | |

**Grand Total: 38 tests**

## Test Data

Test files use mock data to avoid requiring actual Salesforce connections:

```elisp
;; Sample test metadata
(:query "SELECT Id, Name, Email FROM Account"
 :org "test-org"
 :org-url "https://test.salesforce.com"
 :sobject "Account"
 :fields ("Id" "Name" "Email")
 :records (
   (("Id" . "001xxx") ("Name" . "Acme Corp") ("Email" . "acme@test.com"))
   (("Id" . "001yyy") ("Name" . "Wayne Inc") ("Email" . "wayne@test.com"))
 )
 :editable t)
```

## Writing New Tests

### Test Naming Convention

- Prefix with module name: `ob-soql-core-test-`, `ob-soql-vtable-test-`
- Describe what is tested: `extract-sobject-simple`
- Use descriptive names: `track-change-revert-to-original`

### Example Test

```elisp
(ert-deftest ob-soql-core-test-my-function ()
  "Test my-function does what it should."
  (let ((input "test-input")
        (expected "expected-output"))
    (should (equal (my-function input) expected))))
```

### Testing with Mock Functions

```elisp
(ert-deftest ob-soql-test-with-mock ()
  "Test function that calls external dependencies."
  (let ((mock-called nil))
    ;; Mock external function
    (cl-letf (((symbol-function 'external-function)
               (lambda (arg)
                 (setq mock-called t)
                 "mocked-result")))
      
      (my-function-that-calls-external)
      
      (should mock-called))))
```

## Continuous Integration

Add to your CI configuration:

```yaml
# .github/workflows/test.yml
name: Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: purcell/setup-emacs@master
        with:
          version: 29.1
      - name: Run tests
        run: emacs -batch -l test/run-tests.el
```

## Known Limitations

1. **No Integration Tests** - Tests use mocks, don't test actual Salesforce API calls
2. **No UI Tests** - vtable display rendering not tested (requires interactive Emacs)
3. **No Performance Tests** - No tests for large datasets or bulk operations

## Future Test Additions

- [ ] Tests for tabulated-list display mode
- [ ] Tests for CSV display mode
- [ ] Tests for org-babel integration (`ob-soql.el`)
- [ ] Tests for Salesforce API error handling
- [ ] Tests for bulk update operations
- [ ] Tests for field metadata caching
- [ ] Integration tests with test Salesforce org
- [ ] Performance tests with large datasets

## Contributing

When adding new functionality:

1. Write tests first (TDD approach recommended)
2. Ensure tests pass before committing
3. Update this README with new test coverage
4. Follow existing test naming conventions
5. Add mock data as needed
