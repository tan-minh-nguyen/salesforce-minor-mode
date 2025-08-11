;;; apex-consult --- integrate apex to consult -*- lexical-binding: t -*-

(require 'consult)

(defvar apex--consult-source-annotate-fn
  (lambda (cand)
    (let* (;; Return type display
           (type-text (propertize (or (plist-get cand :type)
                                      "Void")
                                  'face 'font-lock-type-face)))
      type-text))
  "Annotate for consult source.")
             
(defvar apex--consult-source-action-fn
  (lambda (cand) 
    (goto-char (plist-get cand :marker)))
  "Action for consult source.")

(defmacro apex--consult-define-source (name narrow category face)
  "Macro to define a consult source."
  `(defvar ,(intern (format "apex--consult-source-%s" (downcase name)))
     (list :name ,(capitalize name)
        :narrow ,narrow
        :category ,category
        :face ,face
        :state #'apex--consult-preview
        :annotate apex--consult-source-annotate-fn
        :action apex--consult-source-action-fn
        :items #'(lambda ()
                   (apex--consult-search-candidates (assoc-default ,(capitalize name) treesit-simple-imenu-settings))))))

(apex--consult-define-source "Field" ?f 'Field 'font-lock-variable-name-face)

(apex--consult-define-source "Method" ?m 'Method 'font-lock-function-name-face)

(apex--consult-define-source "Class" ?c 'Class 'font-lock-type-face)

(apex--consult-define-source "Local Variable" ?v 'Variable 'font-lock-variable-name-face)

(apex--consult-define-source "Sobject" ?s 'SObject 'font-lock-type-face)

(apex--consult-define-source "Enum" ?e 'Enum 'font-lock-type-face)

(defcustom apex--consult-sources '(apex--consult-source-field
                                   apex--consult-source-method
                                   apex--consult-source-class
                                   apex--consult-source-local-variable
                                   apex--consult-source-sobject
                                   apex--consult-source-enum)
  "Imenu sources for `apex-ts-mode'"
  :group 'apex-consult
  :type 'list
  :safe 'listp)

(defun apex--consult-search-candidates (setting)
  "Search candidates with tree-sitter rule in the buffer.
Use SETTING of tree-sitter simple Imenu."
  (pcase-let ((`(,category ,regexp ,pred ,name-fn)
                setting))
            (when-let* ((tree (treesit-induce-sparse-tree
                                (treesit-buffer-root-node) regexp)))
                      (index (treesit--simple-imenu-1)
                          tree pred name-fn)
              (if category
                   (list (cons category index))
               index))))

(defun apex--consult-preview ()
  "Handle imenu preview."
  (let ((preview (consult--jump-preview)))
    (lambda (action cand) 
      (funcall preview action
               (and (markerp (plist-get cand :marker))
                  (plist-get cand :marker))))))

(provide 'apex-consult)
