# Makefile for salesforce-minor-mode

EMACS ?= emacs
BATCH = $(EMACS) -batch -Q -L . -L soql-ts-mode -L apex-ts-mode

.PHONY: test clean help

help:
	@echo "Salesforce Minor Mode - Makefile"
	@echo ""
	@echo "Available targets:"
	@echo "  test       - Run all tests"
	@echo "  test-core  - Run ob-soql-core tests only"
	@echo "  test-vtable - Run ob-soql-vtable tests only"
	@echo "  clean      - Remove compiled files"
	@echo "  compile    - Byte-compile all source files"
	@echo "  help       - Show this help message"

test:
	@echo "Running all tests..."
	$(BATCH) -l test/run-tests.el

test-core:
	@echo "Running ob-soql-core tests..."
	$(BATCH) -l test/ob-soql-core-test.el -f ert-run-tests-batch-and-exit

test-vtable:
	@echo "Running ob-soql-vtable tests..."
	$(BATCH) -l test/ob-soql-vtable-test.el -f ert-run-tests-batch-and-exit

compile:
	@echo "Byte-compiling source files..."
	$(BATCH) -f batch-byte-compile soql-ts-mode/*.el apex-ts-mode/*.el *.el

clean:
	@echo "Cleaning compiled files..."
	find . -name "*.elc" -delete
	@echo "Done."

.DEFAULT_GOAL := help
