;; -*- no-byte-compile: t; no-native-compile: t; lexical-binding: t -*-
;;; Salesforce minor mode -- add sf cli to emacs
(require 'dx-config)
(require 'dx-ctable)
(require 'dx-core)
(require 'dx-apex)
(require 'dx-org)
(require 'dx-feature)
(require 'dx-project)
(require 'dx-query)
(require 'dx-log)
;; load core packages
(require 'apex-ts-mode)
(require 'ob-apex)
(require 'dx-data)

(defvar dx-mode-map
  (let ((map (make-sparse-keymap)))
    ;; org features
    (keymap-set map "M-o s" (cons "Authorize Org" #'dx-org-authorize))
    (keymap-set map "M-o c" (cons "Switch Org" #'dx-org-change-connection))

    (keymap-set map "M-o r" (cons "Retrieve Metadata" #'dx-project-source-retrieve))
    (keymap-set map "M-o d" (cons "Deploy Metadata" #'dx-project-source-push))

    (keymap-set map "M-o o" (cons "Open Org" #'dx-org-open-current))
    (keymap-set map "M-o n" (cons "View All Orgs" #'dx-org-display-all-orgs))
    (keymap-set map "M-o m" (cons "View All Devhubs" #'dx-org-display-all-devhubs))
    (keymap-set map "M-o N" (cons "Notes" #'dx-open-project-note))

    ;; log features
    (keymap-set map "M-o l" (cons "Clear Log" #'dx-clear-log))

    ;; apex features
    (keymap-set map "M-c" (cons "Create DX Resource" #'dx-apex--transient:generate-resource))
    ;; (keymap-set map "M-c t" (cons "Create Trigger" #'dx-apex-generate-trigger))
    ;; (keymap-set map "M-c c" (cons "Create Apex Class" #'dx-apex-generate-class))
    ;; (keymap-set map "M-c T" (cons "Create Apex Class Test" #'dx-apex-generate-test-class))
    ;; (keymap-set map "M-c F" (cons "Create Method Test" #'dx-apex-generate-test-method))
    ;; project features
    ;;(keymap-set map "M-q t" (cons "Query Record" #'dx-soql-string))
    ;; (keymap-set map "M-q f" (cons "Ex" #'dx-fetch-dx-file))

    ;; visualforce features
    (keymap-set map "M-c v" (cons "Create Visualforce Page" #'dx-visualforce-generate-page))
    (keymap-set map "M-c C" (cons "Create Visualforce Component" #'dx-visualforce-generate-component))

    ;; metadata features
    (keymap-set map "M-m t" (cons "Source Tracker" #'dx-source-tracker))
    (keymap-set map "M-m d" (cons "Diff Source" #'dx-diff-metadata))
    (keymap-set map "M-m D" (cons "Diff Source Multi Org" #'dx-diff3-metadata))
    map)
  "Keymap for `dx-minor-mode'.")

(defun dx-minor-mode--init ()
  "Initialize mode."
  (setq dx-org-name (dx-internal-current-org)
        dx-project-root-dir (dx-find-root-dir)))

;;;###autoload
(easy-mmode-define-minor-mode dx-minor-mode
  "Toggles salesforce minor mode."
  :init-value nil
  :group 'dx
  :keymap dx-mode-map)

(add-hook 'dx-minor-mode-hook #'dx-minor-mode--init)

(provide 'dx-minor-mode) ;;; dx-minor-mode end here.
