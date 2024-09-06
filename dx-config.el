;; -*- no-byte-compile: t; no-native-compile: t; lexical-binding: t -*-
(require 'alert)
(require 'projectile)
(require 'subr-x)
(require 'cl-lib)

(defcustom dx-tangle-on-save t
  "When t, automatically tangle Org files on save."
  :type 'boolean
  :group 'dx-minor-mode)

(defcustom dx-api-version nil
  "Custom define api version for command."
  :type 'string
  :group 'dx-minor-mode)

(defcustom dx-org-list-header-display
  '("username" "instanceUrl" "orgId" "isDevHub" "instanceApiVersion" "alias" "lastUsed" "connectedStatus")
  "Custom define header display on table non scratch orgs"
  :type 'list
  :group 'dx-minor-mode)

(defcustom dx-lib-alias "sf"
  ""
  :type 'string
  :group 'dx-minor-mode)

(defcustom dx-legacy-alias "force"
  ""
  :type 'string
  :group 'dx-minor-mode)

(defcustom dx-project-command-alias "project"
  ""
  :type 'string
  :group 'dx-minor-mode)

(defcustom dx-data-command-alias "data"
  ""
  :type 'string
  :group 'dx-minor-mode)

(defcustom dx-visualforce-command-alias "visualforce"
  ""
  :type 'string
  :group 'dx-minor-mode)

(defcustom dx-apex-command-alias "apex"
  ""
  :type 'string
  :group 'dx-minor-mode)

(defcustom dx-org-command-alias "org"
  ""
  :type 'string
  :group 'dx-minor-mode)

(defcustom dx-lightning-command-alias "lightning"
  ""
  :type 'string
  :group 'dx-minor-mode)

(defcustom dx-project-deploy-command
  (concat dx-project-command-alias " " "deploy")
  ""
  :type 'string
  :group 'dx-minor-mode)

(defcustom dx-project-retrieve-command
  (concat dx-project-command-alias " " "retrieve")
  ""
  :type 'string
  :group 'dx-minor-mode)

(defcustom dx-default-browser "qutebrowser"
  "Browser use for open url"
  :type 'string
  :group 'dx-minor-mode)

(defvar-local dx-default-apex-trigger-path "force-app/main/default/triggers"
  "Path save apex classes")

(defvar-local dx-default-apex-class-path "force-app/main/default/classes"
  "Path save apex classes")

(defvar-local dx-default-lwc-path "force-app/main/default/lwc"
  "Path save lwc components")

(defvar-local dx-default-aura-path "force-app/main/default/aura"
  "Path save aura components")

(defvar-local dx-default-vf-path "force-app/main/default/pages"
  "Path save visualforce page")

(defvar-local dx-default-vf-components-path "force-app/main/default/components"
  "Path save visualforce page")

(defvar-local dx-default-test-path "force-app/main/default/lightningTests"
  "Path save test components")

(defvar-local dx-package-dir "manifest"
  "Custom define api version for command")

(defcustom dx-org-cache-dir ".cache/"
  "Directory to store cache files."
  :type 'string
  :group 'dx-minor-mode)

(defcustom dx-dedicated-window-right "*List View*"
  "Name of dedicated window buffer on right."
  :type 'string
  :group 'dx-minor-mode)

(defcustom dx-tracking-time-format "%Y-%m-%d %H:%M:%S"
  "format of time show on tracking metadata buffer."
  :type 'string
  :group 'dx-minor-mode)

(defcustom dx-process-buffer "*DX Process*"
  "name of process buffer."
  :type 'string
  :group 'dx-minor-mode)

(defcustom dx-process-success-buffer "DX Success"
  "name of process success buffer."
  :type 'string
  :group 'dx-minor-mode)

(defcustom dx-process-error-buffer "DX Error"
  "name of process error buffer."
  :type 'string
  :group 'dx-minor-mode)

(defcustom dx-project-config '()
  "List of config in project
   Ex: ((:project \"test\" :note-file \"org\" ))"
  :type 'list
  :group 'dx-minor-mode)

(defcustom dx-org-name ""
  "org name showing on mode line."
  :type 'string)

(defcustom dx-prefix-keymap "M"
  "Prefix for salesforce dx commands."
  :type 'string
  :group 'dx-config)

(defvar-local dx-project-root-dir ""
  "Full path project root.")

(defvar dx-mode-line `(:eval (when (bound-and-true-p dx-minor-mode)
                               (propertize (concat dx-mode-line-icon " "
                                                   (cond ((string-blank-p dx-org-name) "")
                                                         (t dx-org-name)))
                                           'face 'dx-mode-line-face)))
  "Salesfoce mode line.")

(defvar dx-mode-line-icon "\xf0c2"
  "`dx-minor-mode' icon.")

(defface dx-mode-line-face
  '((((type praphic) (class color) (background dark))
     :foreground "DodgerBlue1" :slant oblique :weight bold)
    (((type praphic) (class color) (background light))
     :foreground "DodgerBlue4" :slant oblique :weight bold)
    (((type tty) (class color) (background dark))
     :foreground "DodgerBlue1" :slant oblique :weight bold)
    (t (:foreground "DodgerBlue1" :slant oblique :weight bold)))
  "Font lock for salesfoce minor mode on mode line."
  :group 'font-lock-rules)

;; dx-log.el configurations
(defcustom dx-log-dir-path ".sfdx/tools/debug/logs/"
  "Path of directory log."
  :type 'string
  :group 'dx-config)

(provide 'dx-config)
