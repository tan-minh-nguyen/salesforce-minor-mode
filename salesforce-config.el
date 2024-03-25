;; -*- no-byte-compile: t; no-native-compile: t -*-
(require 'alert)
(require 'projectile)
(require 'subr-x)
(require 'cl-lib)

(defcustom sfmm:tangle-on-save t
  "When t, automatically tangle Org files on save."
  :type 'boolean
  :group 'salesforce-minor-mode)

(defcustom sfmm:api-version nil
  "Custom define api version for command."
  :type 'string
  :group 'salesforce-minor-mode)

(defcustom sfmm:org:list-header-display
  '("username" "instanceUrl" "orgId" "isDevHub" "instanceApiVersion" "alias" "lastUsed" "connectedStatus")
  "Custom define header display on table non scratch orgs"
  :type 'list
  :group 'salesforce-minor-mode)

(defcustom sfmm:sfdx-lib-alias "sf"
  ""
  :type 'string
  :group 'salesforce-minor-mode)

(defcustom sfmm:sfdx-legacy-alias "force"
  ""
  :type 'string
  :group 'salesforce-minor-mode)

(defcustom sfmm:project-command-alias "project"
  ""
  :type 'string
  :group 'salesforce-minor-mode)

(defcustom sfmm:data-command-alias "data"
  ""
  :type 'string
  :group 'salesforce-minor-mode)

(defcustom sfmm:visualforce-command-alias "visualforce"
  ""
  :type 'string
  :group 'salesforce-minor-mode)

(defcustom sfmm:apex-command-alias "apex"
  ""
  :type 'string
  :group 'salesforce-minor-mode)

(defcustom sfmm:org-command-alias "org"
  ""
  :type 'string
  :group 'salesforce-minor-mode)

(defcustom sfmm:lightning-command-alias "lightning"
  ""
  :type 'string
  :group 'salesforce-minor-mode)

(defcustom sfmm:project-deploy-command
  (concat sfmm:project-command-alias " " "deploy")
  ""
  :type 'string
  :group 'salesforce-minor-mode)

(defcustom sfmm:project-retrieve-command
  (concat sfmm:project-command-alias " " "retrieve")
  ""
  :type 'string
  :group 'salesforce-minor-mode)

(defcustom sfmm:default-browser "qutebrowser"
  "Browser use for open url"
  :type 'string
  :group 'salesforce-minor-mode)

(defvar-local sfmm:default-apex-trigger-path "force-app/main/default/triggers"
  "Path save apex classes")

(defvar-local sfmm:default-apex-class-path "force-app/main/default/classes"
  "Path save apex classes")

(defvar-local sfmm:default-lwc-path "force-app/main/default/lwc"
  "Path save lwc components")

(defvar-local sfmm:default-aura-path "force-app/main/default/aura"
  "Path save aura components")

(defvar-local sfmm:default-vf-path "force-app/main/default/pages"
  "Path save visualforce page")

(defvar-local sfmm:default-vf-components-path "force-app/main/default/components"
  "Path save visualforce page")

(defvar-local sfmm:default-test-path "force-app/main/default/lightningTests"
  "Path save test components")

(defvar-local sfmm:package-dir "manifest"
  "Custom define api version for command")

(defcustom sfmm:org:cache-dir ".cache/"
  "Directory to store cache files."
  :type 'string
  :group 'salesforce-minor-mode)

(defcustom sfmm:dedicated-window-right "*List View*"
  "Name of dedicated window buffer on right."
  :type 'string
  :group 'salesforce-minor-mode)

(defcustom sfmm:tracking-time-format "%Y-%m-%d %H:%M:%S"
  "format of time show on tracking metadata buffer."
  :type 'string
  :group 'salesforce-minor-mode)

(defcustom sfmm:process-buffer "*Salesforce Process*"
  "name of process buffer."
  :type 'string
  :group 'salesforce-minor-mode)

(defcustom sfmm:process-success-buffer "*Salesforce Success*"
  "name of process success buffer."
  :type 'string
  :group 'salesforce-minor-mode)

(defcustom sfmm:process-error-buffer "*Salesforce Error*"
  "name of process error buffer."
  :type 'string
  :group 'salesforce-minor-mode)

(defcustom sfmm:project-config '()
  "List of config in project
   Ex: ((:project \"test\" :note-file \"org\" ))"
  :type 'list
  :group 'salesforce-minor-mode)

(defcustom sfmm:org-name ""
  "org name showing on mode line."
  :type 'string)

(defvar-local sfmm:project-root-dir ""
  "Full path project root.")

(defvar sfmm:mode-line `(if (string-blank-p sfmm:org-name) "salesforce" sfmm:org-name)
  "Salesfoce mode line.")

(dir-locals-set-class-variables 'sfmm:salesforce-project-config
                                '((nil . ((salesforce-minor-mode . 1)))))

(provide 'salesforce-config)
