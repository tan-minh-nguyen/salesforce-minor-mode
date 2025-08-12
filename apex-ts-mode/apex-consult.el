;;; apex-consult --- integrate apex to consult -*- lexical-binding: t -*-

(require 'consult)

(defcustom apex--consult-icon-field ""
  "Nerd icon for field consult source."
  :group 'apex-consult
  :type 'string)

(defcustom apex--consult-icon-method ""
  "Nerd icon for method consult source."
  :group 'apex-consult
  :type 'string)

(defcustom apex--consult-icon-class ""
  "Nerd icon for class consult source."
  :group 'apex-consult
  :type 'string)

(defcustom apex--consult-icon-sobject ""
  "Nerd icon for sobject consult source."
  :group 'apex-consult
  :type 'string)

(cl-defmacro apex--consult-define-source (&rest args)
  "Define a consult source for Apex tree-sitter.
ARGS is a plist: :name, :narrow, :category, :face, :items.

:name - Name of the source as a string, used for narrowing,
group titles and annotations.
:narrow - Narrowing character or (character . string) pair.
:face - Face used for highlighting the candidates.
:items - List of strings to select from or function returning
  list of strings"
  (declare (indent defun))
  (let* ((name (plist-get args :name))
         ;; Changed naming scheme here:
         (var-name (intern (format "apex--consult-%s-source" (downcase name)))))
    `(defvar ,var-name
       (list
        :name ,(capitalize name)
        :narrow ,(plist-get args :narrow)
        :category ,(plist-get args :category)
        :face ,(plist-get args :face)
        :state #'apex--consult-preview
        :annotate #'apex--consult-annotate
        :action #'apex--consult-action
        :items ,(plist-get args :items)))))

(apex--consult-define-source :name "Field"
                             :narrow ?p
                             :category 'Field
                             :face 'font-lock-variable-name-face
                             :items (lambda ()
                                      (apex--consult-search-candidates "p" "\\`field_declaration\\'" apex--consult-icon-field nil #'apex-ts-mode--variable-name)))

(apex--consult-define-source :name "Method"
                             :narrow ?f
                             :category 'Method
                             :face 'font-lock-function-name-face
                             :items (lambda ()
                                      (apex--consult-search-candidates "f" "\\`method_declaration\\'" apex--consult-icon-method)))

(apex--consult-define-source :name "Class"
                             :narrow ?c
                             :category 'Class
                             :face 'font-lock-type-face
                             :items (lambda ()
                                      (apex--consult-search-candidates "c" "\\`class_declaration\\'" apex--consult-icon-class nil #'apex-ts-mode--declaration-name)))

(apex--consult-define-source :name "Sobject"
                             :narrow ?s
                             :category 'o
                             :face 'font-lock-type-face
                             :items (lambda ()
                                      (apex--consult-search-candidates "o" "\\`storage_identifier\\'" apex--consult-icon-sobject nil #'(lambda (NODE)
                                                                                                                                         (treesit-node-text NODE)))))
;; (apex--consult-define-source :name "Enum"
;;                              :narrow ?e
;;                              :category 'v
;;                              :face 'font-lock-constant-face
;;                              :items (lambda ()
;;                                       (apex--consult-search-candidates '("c" "\\`enum_declaration\\'" nil apex-ts-mode--declaration-name))))

(defcustom apex--consult-sources '(apex--consult-field-source
                                   apex--consult-method-source
                                   apex--consult-class-source
                                   apex--consult-sobject-source)
                                   ;;apex--consult-enum-source)
  "Imenu sources for `apex-ts-mode'"
  :group 'apex-consult
  :type 'list
  :safe 'listp)

(defun apex--consult-annotate (cand)
  "Annotate for consult source."
  (pcase-let ((`(text . marker) cand))
    (propertize (concat "@" (car cand)) 'face 'font-lock-keyword-face)))

(defun apex--consult-action (candidate) 
  "Action for consult source."
  (goto-char (cdr candidate)))

(defun apex--consult-search-candidates (&rest body)
  "Search candidates with tree-sitter rule in the buffer.
Use SETTING of tree-sitter simple Imenu."
  (pcase-let ((`(,name ,regexp ,icon ,pred ,name-fn)
                body))
    (when-let* ((tree (treesit-induce-sparse-tree (treesit-buffer-root-node) regexp))
                (candidates (treesit--simple-imenu-1 tree pred name-fn)))
      (mapcar (lambda (candidate)
                (let ((display-text (if icon
                                        (propertize (concat (or icon) " " (car candidate)))
                                      (car candidate))))
                  `(,display-text . (,name . ,(cdr candidate)))))
             candidates))))

(defun apex--consult-preview ()
  "Handle imenu preview."
  (let ((preview (consult--jump-preview)))
    (lambda (action cand) 
      (funcall preview action (cdr cand)))))

(defun apex-consult-multi-imenu ()
  "Consult Imenu for `apex-ts-mode'."
  (interactive)
  (consult--multi apex--consult-sources))

(provide 'apex-consult)
