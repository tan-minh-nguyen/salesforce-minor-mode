;;; salesforce-mode.el --- Salesforce Development Tools for Emacs -*- lexical-binding: t -*-

;; Copyright (C) 2025 Tan Nguyen

;; Author: Tan Nguyen <tan.nguyen.w.information@gmail.com>
;; Maintainer: Tan Nguyen <tan.nguyen.w.information@gmail.com>
;; Version: 1.0.0
;; Package-Requires: ((emacs "27.1") (alert "1.2") (async "1.9") (consult "0.35") (nerd-icons "0.1.0") (transient "0.3.0") (projectile "0.14.0") (org "9.0"))
;; Keywords: salesforce, tools, languages
;; Homepage: https://github.com/tan-minh-nguyen/salesforce-minor-mode

;;; Commentary:
;; Salesforce Development Tools for Emacs provides a comprehensive suite of
;; tools for Salesforce development within Emacs. It integrates Salesforce CLI
;; commands, provides language modes with tree-sitter support, and includes
;; features for org management, metadata operations, and data import/export.
;;
;; Main features:
;; - Full Salesforce CLI integration
;; - Tree-sitter based syntax highlighting for Apex, SOQL, Visualforce, LWC
;; - LSP support with Eglot/LSP-bridge
;; - Org-babel integration for literate programming
;; - Multi-org management and switching
;; - Data import/export with org-mode integration
;; - Consult integration for unified search
;; - Transient menus for complex operations
;;
;;; Code:

(require 'salesforce-menu)
(require 'salesforce-core)
(require 'salesforce-apex)
(require 'salesforce-org)
(require 'salesforce-project)
(require 'salesforce-data)
(require 'apex-ts-mode)
(require 'soql-ts-mode)
(require 'ob-soql)

;;; Customization

(defgroup salesforce nil
  "Salesforce development tools for Emacs."
  :group 'tools
  :prefix "salesforce-")

(defcustom salesforce-mode-line-connect-icon
  (if (require 'nerd-icons nil :noerror)
      (nerd-icons-octicon "nf-oct-dot_fill")
    "✓")
  "Icon displayed on mode-line when current org is connected."
  :type 'string
  :group 'salesforce)

(defcustom salesforce-mode-line-disconnect-icon  (if (require 'nerd-icons nil :noerror)
                                                     (nerd-icons-octicon "nf-oct-dot_fill")
                                                   "⛌")
  "Icon displayed on mode-line when current org is disconnected."
  :type 'string
  :group 'salesforce)

(defcustom salesforce-mode-line-current-org-status nil
  "Current org status icon displayed on mode-line."
  :type '(choice string null)
  :group 'salesforce)

(defcustom salesforce-mode-lighter " DX"
  "Mode line lighter for Salesforce Mode."
  :type 'string
  :group 'salesforce)

(defcustom salesforce-status-check nil
  "Whether to check org connection status on mode initialization."
  :type 'boolean
  :group 'salesforce)

;;; Keymap Initialization

(defun salesforce-mode--initialize-org-keymap ()
  "Initialize the keymap for org features."
  (let ((map (make-sparse-keymap)))
    (keymap-set map "TAB" (cons "Switch org" #'salesforce-org-switch-connect))
    (keymap-set map "r" (cons "Retrieve metadata" #'salesforce-project-source-retrieve))
    (keymap-set map "d" (cons "Push metadata" #'salesforce-project-source-push))
    (keymap-set map "p" (cons "Diff file" #'salesforce-project-preview-metadata-change))
    (keymap-set map "." (cons "Open org" #'salesforce-org-open))
    map))

(defun salesforce-mode--initialize-run-keymap ()
  "Initialize the keymap for run/execute features."
  (let ((map (make-sparse-keymap)))
    (keymap-set map "q" (cons "Execute SOQL" #'salesforce-data-query))
    (keymap-set map "s" (cons "Execute SOSL" #'salesforce-data-search))
    (keymap-set map "a" (cons "Execute Apex code" #'salesforce-apex-execute-code))
    map))

(defun salesforce-mode--initialize-resource-keymap ()
  "Initialize the keymap for resource management features."
  (let ((map (make-sparse-keymap)))
    (keymap-set map "c" (cons "Create resource" #'salesforce-apex--transient:generate-resource))
    (keymap-set map "l" (cons "Delete Log" #'salesforce-org-delete-logs))
    map))

;;; Keymaps

(defvar salesforce-mode-org-keymap (salesforce-mode--initialize-org-keymap)
  "Keymap for org features.")

(defvar salesforce-mode-resource-keymap (salesforce-mode--initialize-resource-keymap)
  "Keymap for resource management features.")

(defvar salesforce-mode-run-keymap (salesforce-mode--initialize-run-keymap)
  "Keymap for code execution features.")

(defvar salesforce-mode-map
  (let ((map (make-sparse-keymap)))
    (keymap-set map "M-o o" (cons "Org management" salesforce-mode-org-keymap))
    (keymap-set map "M-o R" (cons "Resource management" salesforce-mode-resource-keymap))
    (keymap-set map "M-o r" (cons "Execute code" salesforce-mode-run-keymap))
    (keymap-set map "M-o A" (cons "Authorize org" #'salesforce-org-authorize))
    map)
  "Keymap for `salesforce-mode'.")

;;; Mode Line

(defun salesforce-mode--set-mode-line-status (json-instance)
  "Set mode line status from JSON-INSTANCE.
Updates `salesforce-mode-line-current-org-status' with appropriate icon and face."
  (let* ((connected-p (string= (map-nested-elt json-instance '("result" "connectedStatus"))
                               "Connected"))
         (icon (if connected-p
                   salesforce-mode-line-connect-icon
                 salesforce-mode-line-disconnect-icon))
         (face (if connected-p 'success 'error)))
    (setq salesforce-mode-line-current-org-status (propertize icon 'face face))))

;;; Mode Initialization

(defvar salesforce-mode--status-check-timer nil
  "Timer for periodic org connection status checks.")

(defun salesforce-mode--check-org-status ()
  "Check the current org connection status and update mode line."
  (when (and (bound-and-true-p salesforce-mode)
           salesforce-org-name)
    (salesforce-org--check-status
     :org salesforce-org-name
     :then #'salesforce-mode--set-mode-line-status)))

(defun salesforce-mode--start-status-check-timer ()
  "Start a timer to check org connection status every 10 minutes."
  (when salesforce-mode--status-check-timer
    (cancel-timer salesforce-mode--status-check-timer))
  (setq salesforce-mode--status-check-timer
        (run-at-time t 600 #'salesforce-mode--check-org-status)))

(defun salesforce-mode--stop-status-check-timer ()
  "Stop the org connection status check timer."
  (when salesforce-mode--status-check-timer
    (cancel-timer salesforce-mode--status-check-timer)
    (setq salesforce-mode--status-check-timer nil)))

(defun salesforce-mode--initialize ()
  "Initialize Salesforce mode.
Ensures org name is populated and starts status checks."
  (when (bound-and-true-p salesforce-mode)
    ;; Ensure org name is populated from config file
    (salesforce-project--ensure-org-name)
    
    ;; Only proceed with status check if we have org name
    (when (and salesforce-org-name 
               (not (string-empty-p salesforce-org-name)))
      ;; Check status immediately on initialization
      (unless salesforce-status-check
        (salesforce-mode--check-org-status))
      ;; Start periodic status checks
      (salesforce-mode--start-status-check-timer))))

(defun salesforce-mode--cleanup ()
  "Cleanup Salesforce mode resources.
Stops the periodic status check timer."
  (salesforce-mode--stop-status-check-timer))

;;; Minor Mode Definition

;;;###autoload
(define-minor-mode salesforce-mode
  "Minor mode for Salesforce development.

This mode provides integration with Salesforce CLI and various development
tools for working with Salesforce projects.

When enabled:
- Checks org connection status immediately
- Starts a timer to check status every 10 minutes
- Updates mode line with connection status

When disabled:
- Stops the status check timer
- Cleans up resources

Key bindings:
\\{salesforce-mode-map}"
  :init-value nil
  :group 'salesforce
  :lighter salesforce-mode-lighter
  :keymap salesforce-mode-map
  :after-hook (if salesforce-mode
                  (salesforce-mode--initialize)
                (salesforce-mode--cleanup)))

;; Add mode line indicator
(add-to-list 'mode-line-misc-info 
             `(salesforce-mode 
               ("" salesforce-project--mode-line-format " ")))

(put 'salesforce-project--mode-line-format 'risky-local-variable t)

(provide 'salesforce-mode)

;;; salesforce-mode.el ends here
