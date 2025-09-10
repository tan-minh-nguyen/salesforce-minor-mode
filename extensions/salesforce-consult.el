;; salesforce-consult.el --- Make consult for Major mode -*- lexical-binding: t -*-

(require 'consult)

(cl-defmacro salesforce-consult--define-source (prefix &rest args)
  "Define a consult source for Apex tree-sitter."
  (declare (indent defun))
  (let ((var-name (salesforce-consult--source-var-name prefix args)))
    `(defvar ,var-name
       (salesforce-consult--source-list ',args))))

(defun salesforce-consult--source-var-name (prefix args)
  "Generate variable name for consult source."
  (let ((name (plist-get args :name)))
    (intern (format "%s--consult-%s-source" prefix (downcase name)))))

(defun salesforce-consult--source-list (args)
  "Generate source list for consult."
  (list
   :name (capitalize (plist-get args :name))
   :narrow (plist-get args :narrow)
   :category (plist-get args :category)
   :face (plist-get args :face)
   :state #'salesforce-consult--preview
   :annotate #'salesforce-consult--annotate
   :action #'salesforce-consult--action
   :items (plist-get args :items)))

(defun salesforce-consult--annotate (cand)
  "Annotate for consult source."
  (pcase-let ((`(text . marker) cand))
    (propertize (concat "@" (car cand)) 'face 'font-lock-keyword-face)))

(defun salesforce-consult--action (candidate) 
  "Action for consult source."
  (goto-char (cdr candidate)))

(defun salesforce-consult--search-candidates (&rest body)
  "Search candidates with tree-sitter rule in the buffer."
  (pcase-let ((`(,name ,regexp ,icon ,pred ,name-fn) body))
    (when-let* ((tree (treesit-induce-sparse-tree (treesit-buffer-root-node) regexp))
                (candidates (treesit--simple-imenu-1 tree pred name-fn)))
      (salesforce-consult--format-candidates candidates name icon))))

(defun salesforce-consult--org-annotation (candidate)
  "Format CANDIDATE to show on `completing-read'."
  (let* ((hub (when (plist-get candidate :isDevHub)
                (propertize "D" 'face 'font-lock-keyword-face)))
         (status (if (string= (plist-get candidate :connectedStatus) "Connected")
                     (propertize salesforce-mode-line-connect-icon 'face 'success)
                   (propertize salesforce-mode-line-disconnect-icon 'face 'error)))
         (url (propertize (plist-get candidate :instanceUrl)
                          'face 'font-lock-comment-face)))
    `(,hub ,(concat status " " url))))

(defun salesforce-consult--format-candidates (candidates name icon)
  "Format candidates for consult."
  (mapcar (lambda (candidate)
            (let ((display-text (if icon
                                    (propertize (concat (or icon) " " (car candidate)))
                                  (car candidate))))
              `(,display-text . (,name . ,(cdr candidate)))))
          candidates))

(defun salesforce--consult-preview ()
  "Handle imenu preview."
  (let ((preview (consult--jump-preview)))
    (lambda (action cand) 
      (funcall preview action (cdr cand)))))

(defmacro salesforce-consult-make-multi-imenu (language &rest consult-sources)
  "Create a consult Imenu for a major mode specified by LANGUAGE.
CONSULT-SOURCES are the sources to be used in the consult multi command."
  (let ((function-name (intern (format "%s-consult-multi-imenu" language))))
    `(defun ,function-name ()
       (interactive)
       (consult--multi ',consult-sources))))

(defun salesforce-consult-prompt-org ()
  "Prompt for a Salesforce org using `consult--read` with annotations."
  (salesforce-org--fetch-list-org
   :finish-func
   (lambda (org-list)
     (consult--read
      (mapcar (lambda (org)
                (cons (or (plist-get org :alias)
                         (plist-get org :username))
                      org))
              org-list)
      :prompt "Org: "
      :category 'salesforce-org
      :annotate (lambda (cand)
                  (pcase-let ((`(,prefix ,suffix)
                               (salesforce-consult--org-annotation
                                (get-text-property 0 'data cand))))
                    (list cand prefix suffix)))
      :lookup (lambda (cand &rest _) (car cand))
      :sort nil))
   :fields '(:alias :username :instanceUrl :connectedStatus :isDevHub)))

(defalias 'salesforce-org-prompt-org #'salesforce-consult-prompt-org)

(provide 'salesforce-consult)
