;;; packages/salesforce-packages/soql-completion/soql-completion.el -*- lexical-binding: t; -*- SOQL auto completion

;; Code
(require 'treesit)
(require 'dx-core)
(require 'cl)

(defcustom soql-company-type-table `(("string" "S")
                                     ("picklist" "P") 
                                     ("date" "D")
                                     ("datetime" "DT")
                                     ("time" "T")
                                     ("reference" "R")
                                     ("textarea" "A")
                                     ("currency" "C")
                                     ("int" "I")
                                     ("url" "L")
                                     ("phone" "P")
                                     ("double" "F")
                                     ("id" "UUID")
                                     ("boolean" "B"))
  "Table mapping type of field to show as annotation."
  :type 'list
  :group 'soql-company)

(defconst soql-company-pattern "__([A-Z_]+)"
  "Pattern trigger SOQL complete.")

(defun soql-company--sobject-metadata (sobject-name)
  "Get metadata file of SOBJECT-NAME."
  (let* ((file-name (concat sobject-name ".json"))
         (search-folder (dx-core--build-path (dx-core--tools-folder)
                                             "/" dx-soql-metadata-dir "/"
                                             (if (string-match-p "__c$" sobject-name)
                                                 dx-custom-objects-dir
                                               dx-stardard-objects-dir)))
         (file-path (expand-file-name file-name search-folder)))
    (and (file-exists-p file-path) file-path)))

(defun soql-company--picklist-values (field)
  "Get all available options in FIELD."
  (cl-loop for option across (dx-core--get-data-json "picklistValues" field)
           collect (dx-core--get-data-json "value" option)))

(defmacro soql-company--type-field (type)
  "Convert TYPE field to expected type."
  `(pcase ,type
     ,@soql-completion-type-table))

(defun soql-company--annotation-1 (field)
  "Build annotation for auto completion.

FIELD: contains all data about that field."
  (soql-company--type-field (dx-core--get-data-json "type" field)))

(defun soql-company--meta-1 (field)
  "Build meta for auto completion.

FIELD: contains all data about that field."
  (soql-company--picklist-values field))

(defun soql-company--match-fields (prefix sobject)
  "Find fields match to PREFIX in SOBJECT."
  (when-let* ((metadata-file (soql-company--sobject-metadata sobject))
              (fields (dx-core--get-data-json "fields" (with-current-buffer (find-file-noselect metadata-file)
                                                         (beginning-of-buffer)
                                                         (json-parse-buffer)))))
    (cl-loop for field across fields
             as name = (dx-core--get-data-json "name" field)
             as options = (soql-company--picklist-values field)
             when (if prefix (string-prefix-p prefix name)
                    (string-match-p ".+" name))
             collect (propertize name 'annotation `,(soql-company--annotation-1 field)
                                 'meta `,(soql-company--meta-1 field)))))

(defun soql-company--current-sobject ()
  "Get sobject in current statement."
  (when-let* ((soql-root (soql-company--statement-root))
              (clauses (treesit-query-capture soql-root '((from_clause) @sobject))))
    (treesit-node-text (treesit-node-child (assoc-default 'sobject clauses) 1) t)))

(defun soql-company--retrieve-sobjects (sobject)
  "Retrieve Sobject in current org."
  (when-let* ((files (soql-completion--find-files sobject)))

    (split-string files)))

;;; Company backed
(defun soql-company--company-setup ()
  "Setup SQOL company backend."
  (let ((groups (car company-backends)))
    (and (cond ((and (listp groups)
                 (member :seperate groups))
              (setcar company-backends
                      `(,(car groups) soql-company ,@(cdr groups))))
             ((and (listp groups)
                 (member :with groups))
              (setcar company-backends
                      `(,(car groups) ,@(cdr groups) soql-company))))
       (add-to-list 'company-transformers #'soql-company-delete-placeholder))))

(defun soql-company--statement-root ()
  "Find SOQL root."
  (treesit-parent-until (treesit-node-at (point))
                        (lambda (node)
                          (string= "soql_query_body" (treesit-node-type node)))))

(defun soql-company--statement-p ()
  "Return true if current point in SOQL statement."
  (not (null (soql-company--statement-root))))

(defun soql-company--candidates (&optional prefix)
  "Get candidates matches PREFIX for current SOQL statement."
  (soql-completion--match-fields prefix (soql-completion--current-sobject)))

(defun soql-company--meta (candidate)
  "Format of annotation of CANDIDATE."
  (format "%s" (get-text-property 0 'meta candidate)))

(defun soql-company--annotation (candidate)
  "Format of annotation of CANDIDATE."
  (format "%s" (get-text-property 0 'annotation candidate)))

(defun soql-company-delete-placeholder (candidates)
  "Delete placeholder values in CANDIDATES."
  (cl-delete-if (lambda (candidate)
                  (string-match-p soql-company-pattern candidate))
                candidates))

(defun company-soql (command &optional arg &rest ignored)
  "Support auto complete fields for SOQL"
  (interactive (list 'interactive))
  (cl-case command
    (interactive (company-begin-backend 'company-soql))
    (prefix (and (soql-company--statement-p)
               (company-grab-symbol)))
    (candidates (company-soql--candidates arg))
    (annotation (company-soql--annotation arg))
    (meta (company-soql--meta arg))))

(provide 'soql-company)
