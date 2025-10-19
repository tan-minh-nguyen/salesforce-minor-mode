;; salesforce-mode.el --- Salesforce client for Emacs -*- lexical-binding: t -*-
;;; Salesforce minor mode -- add sf cli to emacs
;; Author: tan-minh-nguyen <tan.nguyen.w.information@gmail.com>
;; Keywords: salesforce, emacs
;; Homepage: https://github.com/tan-minh-nguyen/salesforce-minor-mode
;; Version: 1.0
;; Package-Requires: ((request "0.1.3") (ctable "0.1.3") (nerd-icons "0.1.0") (nerd-icons "0.1.0") (consult "2.8"))

(require 'salesforce-transient-menu)
;; (require 'salesforce-table)
(require 'salesforce-core)
(require 'salesforce-apex)
(require 'salesforce-org)
(require 'salesforce-project)
;; load core packages
(require 'salesforce-data)
(require 'apex-ts-mode)
(require 'soql-ts-mode)
(require 'ob-soql)

(defcustom salesforce-mode-line-connect-icon (nerd-icons-octicon "nf-oct-dot_fill")
  "Icon display on mode-line when current org is active.")

(defcustom salesforce-mode-line-disconnect-icon (nerd-icons-octicon "nf-oct-dot_fill")
  "Icon display on mode-line when current org is disconnect.")

(defcustom salesforce-mode-line-current-org-status nil
  "Icon display on mode-line when current org is active.")

(defcustom salesforce-mode-lighter " DX"
  "Mode line lighter for Salesforce Mode."
  :type 'string
  :group 'salesforce)

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
  "Initialize the keymap for run features."
  (let ((map (make-sparse-keymap)))
    (keymap-set map "q" (cons "Execute SOQL" #'salesforce-data-query))
    (keymap-set map "s" (cons "Execute SOQL" #'salesforce-data-search))
    (keymap-set map "a" (cons "Execute Apex code" #'salesforce-apex-execute-code))

    map))

(defun salesforce-mode--initialize-resource-keymap ()
  "Initialize the keymap for resource features."
  (let ((map (make-sparse-keymap)))
    (keymap-set map "c" (cons "create salesforce resource" #'salesforce-apex--transient:generate-resource))
    (keymap-set map "l" (cons "clear log data" #'salesforce-org-delete-logs))
    ;;(keymap-set map "t" (cons "Source Tracker" #'salesforce-source-tracker))
    map))

(defvar salesforce-mode-org-keymap (salesforce-mode--initialize-org-keymap)
  "Keymap for org features.")

(defvar salesforce-mode-resource-keymap (salesforce-mode--initialize-resource-keymap)
  "Keymap for resource features.")

(defvar salesforce-mode-run-keymap (salesforce-mode--initialize-run-keymap)
  "Keymap for resource features.")

(defvar salesforce-mode-map
  (let ((map (make-sparse-keymap)))

    ;; leader map
    (keymap-set map "M-o o" (cons "org" salesforce-mode-org-keymap))
    (keymap-set map "M-o R" (cons "resource" salesforce-mode-resource-keymap))
    (keymap-set map "M-o r" (cons "execute" salesforce-mode-run-keymap))
    (keymap-set map "M-o A" (cons "authorize org" #'salesforce-org-authorize))
    
    map)
  "Keymap for `salesforce-minor-mode'.")

(defun salesforce-mode--set-mode-line-status (json-instance)
  "Set the mode line status based on JSON-INSTANCE."
  (setq salesforce-mode-line-current-org-status
        (if (string= (salesforce-core--get-data-json "result.connectedStatus" json-instance)
                     "Connected")
            (propertize salesforce-mode-line-connect-icon 'face 'success)
          (propertize salesforce-mode-line-disconnect-icon 'face 'error))
        salesforce-project-token (salesforce-core--get-data-json "result.accessToken" json-instance)
        salesforce-project-url (salesforce-core--get-data-json "result.instanceUrl" json-instance)))

(defun salesforce-mode--initialize ()
  "Initialize Salesforce mode."
  (when (and (bound-and-true-p salesforce-mode)
           salesforce-org-name
           (null salesforce-mode-line-current-org-status))

    (salesforce-org-status :org salesforce-org-name
                           :finish-func #'salesforce-mode--set-mode-line-status)))

;;;###autoload
(define-minor-mode salesforce-mode
  "Toggles salesforce minor mode."
  :init-value nil
  :group 'salesforce
  :lighter salesforce-mode-lighter
  :keymap salesforce-mode-map
  :after-hook (salesforce-mode--initialize))

(add-to-list 'mode-line-misc-info `(salesforce-mode ("" salesforce-project--mode-line-format " ")))

(put 'salesforce-project--mode-line-format 'risky-local-variable t)


(provide 'salesforce-mode) ;;; salesforce-minor-mode end here.
