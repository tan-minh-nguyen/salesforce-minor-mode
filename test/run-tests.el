;;; run-tests.el --- Test runner for salesforce-minor-mode -*- lexical-binding: t -*-

;; Copyright (C) 2025 Free Software Foundation, Inc.

;;; Commentary:
;;
;; Test runner for salesforce-minor-mode tests.
;; Run from command line:
;;   emacs -batch -l test/run-tests.el
;;
;; Or from Emacs:
;;   M-x load-file RET test/run-tests.el RET
;;   M-x ert RET t RET

;;; Code:

(require 'ert)

;; Add source directories to load path
(add-to-list 'load-path (expand-file-name "."))
(add-to-list 'load-path (expand-file-name "soql-ts-mode"))
(add-to-list 'load-path (expand-file-name "apex-ts-mode"))
(add-to-list 'load-path (expand-file-name "test"))

;; Load test files
(load-file "test/ob-soql-core-test.el")
(load-file "test/ob-soql-vtable-test.el")

;; Run tests
(defun run-all-tests ()
  "Run all tests for salesforce-minor-mode."
  (interactive)
  (ert-run-tests-batch-and-exit t))

;; When running in batch mode, run all tests
(when noninteractive
  (run-all-tests))

(provide 'run-tests)
;;; run-tests.el ends here
