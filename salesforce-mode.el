;; -*- no-byte-compile: t; no-native-compile: t; lexical-binding: t -*-
;;; Salesforce minor mode -- add sf cli to emacs

(require 'dx-ctable)
(require 'dx-core)
(require 'dx-apex)
(require 'dx-org)
(require 'salesforce-project)
;; load core packages
(require 'dx-data)
(require 'apex-ts-mode)
(require 'soql-ts-mode)
(require 'ob-apex)
(require 'ob-soql)

(defvar dx-org-keymap (let ((map (make-sparse-keymap)))
                        (keymap-set map "TAB" (cons "Switch Org" #'dx-org-change-connection))

                        (keymap-set map "r" (cons "Retrieve Metadata" #'salesforce-project-source-retrieve))
                        (keymap-set map "d" (cons "Push Metadata" #'salesforce-project-source-push))

                        (keymap-set map "n" (cons "List All Orgs" #'dx-org-display-all-orgs))
                        (keymap-set map "m" (cons "List All Devhubs" #'dx-org-display-all-devhubs))
                        (keymap-set map "p" (cons "Diff File" #'salesforce-project-preview-metadata-change))
                        (keymap-set map ";" (cons "Execute Apex Code" #'dx-apex-execute-code))
                        (keymap-set map "." (cons "Open Org" #'dx-org-open-current))
                        map)
  "Keymap for org features.")

(defvar dx-mode-map (let ((map (make-sparse-keymap))
                          (resource-feature-keymap (make-sparse-keymap)))

                      ;; resource features
                      (keymap-set resource-feature-keymap "SPC" (cons "Create DX Resource" #'dx-apex--transient:generate-resource))
                      (keymap-set resource-feature-keymap "L" (cons "Clear Log Data" #'dx-org-clear-log-data))
                      ;;(keymap-set resource-feature-keymap "t" (cons "Source Tracker" #'dx-source-tracker))
                      ;;(keymap-set map "M-m D" (cons "Diff Source Multi Org" #'dx-diff3-metadata))

                      ;; leader map
                      (keymap-set map "M-o o" (cons "Org Features" dx-org-keymap))
                      (keymap-set map "M-o r" (cons "Resource Features" resource-feature-keymap))
                      (keymap-set map "M-o N" (cons "Notes" #'salesforce-project-open-note))
                      (keymap-set map "M-o A" (cons "Authorize Org" #'dx-org-authorize))
                      ;; (keymap-set map "M-c t" (cons "Create Trigger" #'dx-apex-generate-trigger))
                      ;; (keymap-set map "M-c c" (cons "Create Apex Class" #'dx-apex-generate-class))
                      ;; (keymap-set map "M-c T" (cons "Create Apex Class Test" #'dx-apex-generate-test-class))
                      ;; (keymap-set map "M-c F" (cons "Create Method Test" #'dx-apex-generate-test-method))
                      ;; project features
                      ;;(keymap-set map "M-q t" (cons "Query Record" #'dx-soql-string))
                      ;; (keymap-set map "M-q f" (cons "Ex" #'dx-fetch-dx-file))

                      ;; visualforce features
                      ;;(keymap-set map "M-c v" (cons "Create Visualforce Page" #'dx-visualforce-generate-page))
                      ;;(keymap-set map "M-c C" (cons "Create Visualforce Component" #'dx-visualforce-generate-component))

                      
                      map)
  "Keymap for `dx-minor-mode'.")

;; TODO: call check connect function to show it as status
(defun dx-minor-mode--init ()
  "Initialize mode."
  (setq dx-org-name (dx-internal-current-org)
        dx-project-root-dir (dx-core--find-root-dir))
  (dx-org--status :org dx-org-name
                  :finish-func
                  (lambda (json-instance)
                    (setq dx-mode-line-current-org-status
                          (if (string= (dx-core--get-data-json "result.connectedStatus" json-instance)
                                       "Connected")
                              (propertize dx-mode-line-active-connect-icon 'face 'success)
                            (propertize dx-mode-line-disconnect-icon 'face 'error))))))

;;;###autoload
(easy-mmode-define-minor-mode salesforce-mode
  "Toggles salesforce minor mode."
  :init-value nil
  :group 'dx
  :keymap dx-mode-map)

(add-hook 'dx-minor-mode-hook #'dx-minor-mode--init)

(provide 'salesforce-mode) ;;; dx-minor-mode end here.
