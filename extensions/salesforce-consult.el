;; salesforce-consult.el --- Make consult for Major mode -*- lexical-binding: t -*-

(require 'consult)

(cl-defmacro salesforce-consult--define-source (prefix &rest args)
  "Define a consult source for Apex tree-sitter."
  (declare (indent defun))
  (let ((var-name (salesforce-consult--source-var-name prefix args)))
    `(defvar ,var-name
       (apply #'salesforce-consult--source ',args))))

(defun salesforce-consult--source-var-name (prefix args)
  "Generate variable name for consult source."
  (let ((name (plist-get args :name)))
    (intern (format "%s--consult-%s-source" prefix (downcase name)))))

(defun salesforce-consult--source (&rest args)
  "Generate source list for consult.

ARGS: arguments apply for `consult--multi'."
  (append
   `(:name ,(capitalize (plist-get args :name))
           :narrow ,(plist-get args :narrow)
           :category ,(plist-get args :category)
           :face ,(plist-get args :face)
           :items ,(plist-get args :items))

   (when (plist-get args :annotate)
     `(:annotate ,(plist-get args :annotate)))
   (when (plist-get args :action)
     `(:action ,(plist-get args :action)))
   (when (plist-get args :state)
     `(:state ,(plist-get args :state)))))

(defun salesforce-consult--imenu-annotate (cand)
  "Annotate for consult source."
  (pcase-let ((`(text . marker) cand))
    (propertize (concat "@" (car cand)) 'face 'font-lock-keyword-face)))

(defun salesforce-consult--imenu-action (candidate) 
  "Action for consult source."
  (goto-char (cdr candidate)))

(defun salesforce-consult--search-candidates (&rest body)
  "Search candidates with tree-sitter rule in the buffer."
  (pcase-let ((`(,name ,regexp ,icon ,pred ,name-fn) body))
    (when-let* ((tree (treesit-induce-sparse-tree (treesit-buffer-root-node) regexp))
                (candidates (treesit--simple-imenu-1 tree pred name-fn)))
      (salesforce-consult--format-candidates candidates name icon))))

(defun salesforce-consult--format-candidates (candidates name &optional icon)
  "Format candidates for consult."
  (mapcar (lambda (candidate)
            (let ((display-text (if icon
                                    (propertize (concat (or icon) " " (car candidate)))
                                  (car candidate))))
              `(,display-text . (,name . ,(cdr candidate)))))
          candidates))

(defun salesforce-consult--imenu-state ()
  "Handle imenu state."
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

(provide 'salesforce-consult)
