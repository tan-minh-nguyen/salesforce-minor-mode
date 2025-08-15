;; salesforce-mode.el --- Salesforce client for Emacs -*- lexical-binding: t -*-
;;; Salesforce minor mode -- add sf cli to emacs
;; Author: tan-minh-nguyen <tan.nguyen.w.information@gmail.com>
;; Keywords: salesforce, emacs
;; Homepage: https://github.com/tan-minh-nguyen/salesforce-minor-mode
;; Version: 1.0
;; Package-Requires: ((ctable "0.1.3"))

(require 'salesforce-transient-menu)
(require 'salesforce-ctable)
(require 'salesforce-core)
(require 'salesforce-apex)
(require 'salesforce-org)
(require 'salesforce-project)
;; load core packages
(require 'salesforce-data)
(require 'apex-ts-mode)
(require 'soql-ts-mode)
(require 'ob-soql)

(defcustom salesforce-mode-lighter " DX"
  "Mode line lighter for Salesforce Mode."
  :type 'string
  :group 'salesforce)

(defvar salesforce-org-keymap (let ((map (make-sparse-keymap)))
                                (keymap-set map "TAB" (cons "Switch Org" #'salesforce-org-change-connection))

                                (keymap-set map "r" (cons "Retrieve Metadata" #'salesforce-project-source-retrieve))
                                (keymap-set map "d" (cons "Push Metadata" #'salesforce-project-source-push))

                                (keymap-set map "n" (cons "List All Orgs" #'salesforce-org-display-all-orgs))
                                (keymap-set map "m" (cons "List All Devhubs" #'salesforce-org-display-all-devhubs))
                                (keymap-set map "p" (cons "Diff File" #'salesforce-project-preview-metadata-change))
                                (keymap-set map ";" (cons "Execute Apex Code" #'salesforce-apex-execute-code))
                                (keymap-set map "." (cons "Open Org" #'salesforce-org-open-current))
                                map)
  "Keymap for org features.")

(defvar salesforce-mode-map (let ((map (make-sparse-keymap))
                                  (resource-feature-keymap (make-sparse-keymap)))

                      ;; resource features
                             (keymap-set resource-feature-keymap "SPC" (cons "Create SALESFORCE Resource" #'salesforce-apex--transient:generate-resource))
                             (keymap-set resource-feature-keymap "L" (cons "Clear Log Data" #'salesforce-org-clear-log-data))
                      ;;(keymap-set resource-feature-keymap "t" (cons "Source Tracker" #'salesforce-source-tracker))
                      ;;(keymap-set map "M-m D" (cons "Diff Source Multi Org" #'salesforce-diff3-metadata))

                      ;; leader map
                             (keymap-set map "M-o o" (cons "Org Features" salesforce-org-keymap))
                             (keymap-set map "M-o r" (cons "Resource Features" resource-feature-keymap))
                             (keymap-set map "M-o N" (cons "Notes" #'salesforce-project-open-note))
                             (keymap-set map "M-o A" (cons "Authorize Org" #'salesforce-org-authorize))
                      ;; (keymap-set map "M-c t" (cons "Create Trigger" #'salesforce-apex-generate-trigger))
                      ;; (keymap-set map "M-c c" (cons "Create Apex Class" #'salesforce-apex-generate-class))
                      ;; (keymap-set map "M-c T" (cons "Create Apex Class Test" #'salesforce-apex-generate-test-class))
                      ;; (keymap-set map "M-c F" (cons "Create Method Test" #'salesforce-apex-generate-test-method))
                      ;; project features
                      ;;(keymap-set map "M-q t" (cons "Query Record" #'salesforce-soql-string))
                      ;; (keymap-set map "M-q f" (cons "Ex" #'salesforce-fetch-salesforce-file))

                      ;; visualforce features
                      ;;(keymap-set map "M-c v" (cons "Create Visualforce Page" #'salesforce-visualforce-generate-page))
                      ;;(keymap-set map "M-c C" (cons "Create Visualforce Component" #'salesforce-visualforce-generate-component))

                      
                             map)
  "Keymap for `salesforce-minor-mode'.")

;; TODO: call check connect function to show it as status
(defun salesforce-minor-mode--init ()
  "Initialize mode."
  (setq salesforce-org-name (salesforce-internal-current-org)
        salesforce-project-root-dir (salesforce-core--find-root-dir))
  (salesforce-org--status :org salesforce-org-name
                          :finish-func
                          (lambda (json-instance)
                            (setq salesforce-mode-line-current-org-status
                                  (if (string= (salesforce-core--get-data-json "result.connectedStatus" json-instance)
                                               "Connected")
                                      (propertize salesforce-mode-line-active-connect-icon 'face 'success)
                                    (propertize salesforce-mode-line-disconnect-icon 'face 'error))))))

;;;###autoload
(define-minor-mode salesforce-mode
  "Toggles salesforce minor mode."
  :init-value nil
  :group 'salesforce
  :lighter salesforce-mode-lighter
  :keymap salesforce-mode-map)

(add-hook 'salesforce-minor-mode-hook #'salesforce-minor-mode--init)

(add-to-list 'mode-line-misc-info `(salesforce-mode ("" salesforce-project--mode-line-format " ")))

(put 'salesforce-project--mode-line-format 'risky-local-variable t)


(provide 'salesforce-mode) ;;; salesforce-minor-mode end here.
