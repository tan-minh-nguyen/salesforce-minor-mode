;;; Salesforce minor mode -- add sf cli to emacs
(require 'salesforce-config)
(require 'salesforce-helper)
(require 'salesforce-ctable)
(require 'salesforce-core)

(defvar salesforce-mode-map
  (let ((map (make-sparse-keymap)))
    ;; org features
    (keymap-set map "M-o s" (cons "Authorize Sandbox" #'sfmm:org:authorize-sandbox))
    (keymap-set map "M-o p" (cons "Authorize Production" #'sfmm:org:authorize-production))
    (keymap-set map "M-o c" (cons "Authorize URL" #'sfmm:org:authorize-cusom-url))
    (keymap-set map "M-o c" (cons "Switch Org" #'sfmm:org:change))

    (keymap-set map "M-o r" (cons "Retrieve Metadata" #'sfmm:source:retrieve))
    (keymap-set map "M-o d" (cons "Deploy Metadata" #'sfmm:source:push))

    (keymap-set map "M-o o" (cons "Open Org" #'sfmm:org:default-open))
    (keymap-set map "M-o n" (cons "View All Orgs" #'sfmm:org:display-all-orgs))
    (keymap-set map "M-o m" (cons "View All Devhubs" #'sfmm:org:display-all-devhubs))
    (keymap-set map "M-o N" (cons "Notes" #'sfmm:open-project-note))

    ;; log features
    (keymap-set map "M-o l" (cons "Clear Log" #'sfmm:org:clear-log))

    ;; apex features
    (keymap-set map "M-c t" (cons "Create Trigger" #'sfmm:apex:generate-trigger))
    (keymap-set map "M-c c" (cons "Create Apex Class" #'sfmm:apex:generate-class))
    (keymap-set map "M-c T" (cons "Create Apex Class Test" #'sfmm:apex:generate-test-class))
    (keymap-set map "M-c F" (cons "Create Method Test" #'sfmm:apex:generate-test-method))
    ;; project features
    (keymap-set map "M-q t" (cons "Query Record" #'sfmm:soql:string))
    ;; (keymap-set map "M-q f" (cons "Ex" #'sfmm:fetch-salesforce-file))

    ;; visualforce features
    (keymap-set map "M-c v" (cons "Create Visualforce Page" #'sfmm:visualforce:generate-page))
    (keymap-set map "M-c c" (cons "Create Visualforce Component" #'sfmm:visualforce:generate-component))

    ;; metadata features
    (keymap-set map "M-m t" (cons "Source Tracker" #'sfmm:source-tracker))
    (keymap-set map "M-m d" (cons "Diff Source" #'sfmm:diff-metadata))
    (keymap-set map "M-m D" (cons "Diff Source Multi Org" #'sfmm:diff3-metadata))
    map)
  "Keymap for `salesforce-minor-mode'.")

;;;###autoload
(defun turn-on-salesforce-mode ()
  "turn on salesforce-minor-mode"
  (salesforce-minor-mode 1))

;;;###autoload
(defun turn-off-salesforce-mode ()
  "turn on salesforce-minor-mode"
  (salesforce-minor-mode -1))

;;;###autoload
(defun sfmm--internal:initialize-config (projects)
  "add config to projects."
  (cl-loop for dir in projects
           collect (dir-locals-set-directory-class (expand-file-name dir) 'sfmm:salesforce-project-config)))

;;;###autoload
(defun sfmm--internal-set-mode-line (org-name)
  "set mode line."
  (cond ((stringp global-mode-string)
         (set 'global-mode-string `(,org-name)))
        ((listp global-mode-string)
         (set 'global-mode-string (if (stringp (remove 'global-mode-string sfmm:org-name))
                                    '("")
                                    (remove 'global-mode-string sfmm:org-name)))
         (add-to-list 'global-mode-string org-name))))

(defun salesforce-minor-mode--init ()
 "Initialize mode."
 (setopt sfmm:org-name (sfmm--internal-current-org))
 (setq-local sfmm:project-root-dir (sfmm--internal:find-root-dir)))

;;;###autoload
(define-minor-mode salesforce-minor-mode
  "Toggles global salesforce minor mode."
  nil ; Inital value, nil for disabled
  :global nil
  :group 'salesforce
  :keymap salesforce-mode-map


  (if salesforce-minor-mode
      (add-hook 'salesforce-minor-mode-hook #'salesforce-minor-mode--init)
    (setopt sfmm:org-name "")
    (remove-hook 'salesforce-minor-mode-hook #'salesforce-minor-mode--init)))

(provide 'salesforce-minor-mode) ;;; salesforce-minor-mode end here.
