;;; soql-company.el -*- lexical-binding: t; -*- SOQL auto completion

;; Code
(require 'treesit)
(require 'salesforce-core)

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

(defvar-local soql-company-workspace nil
  "Use for manually setting manual workspace if not part of project.")

(defconst soql-company-pattern "__([A-Z_]+)"
  "Pattern trigger SOQL complete.")

(defun soql-company--sobject-metadata (sobject-name)
  "Return metadata JSON file path for SOBJECT-NAME, or nil if it does not exist."
  (let* ((file-name   (concat sobject-name ".json"))
         (sobject-dir (if (string-suffix-p "__c" sobject-name)
                          salesforce-custom-objects-dir
                        salesforce-stardard-objects-dir))
         (base-folder (if (salesforce-project-p)
                          (concat (salesforce-core--tools-folder)
                                  "/" salesforce-soql-metadata-dir "/"
                                  sobject-dir)
                        (concat (salesforce-core--tools-folder)
                                "/" salesforce-soql-metadata-dir
                                "/" sobject-dir)))
         (file-path (expand-file-name file-name base-folder)))
    (when (file-exists-p file-path)
      file-path)))

(defun soql-company--picklist-values (field)
  "Get all available options in FIELD."
  (cl-loop for option across (map-elt field "picklistValues")
           collect (map-elt option "value")))

(defmacro soql-company--type-field (type)
  "Convert TYPE field to expected type."
  `(pcase ,type
     ,@soql-company-type-table))

(defun soql-company--annotation-1 (field)
  "Build annotation for auto completion.

FIELD: contains all data about that field."
  (soql-company--type-field (map-elt field "type")))

(defun soql-company--meta-1 (field)
  "Build meta for auto completion.

FIELD: contains all data about that field."
  (soql-company--picklist-values field))

(defun soql-company--match-fields (prefix sobject)
  "Find fields match to PREFIX in SOBJECT."
  (when-let* ((metadata-file (soql-company--sobject-metadata sobject))
              (fields (map-elt (with-current-buffer (find-file-noselect metadata-file)
                                 (beginning-of-buffer)
                                 (json-parse-buffer :object-type 'hash-table))
                               "fields")))
    (cl-loop for field across fields
             as name = (map-elt field "name")
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

;;; Company backed
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
  (soql-company--match-fields prefix (soql-company--current-sobject)))

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
    (candidates (soql-company--candidates arg))
    (annotation (soql-company--annotation arg))
    (meta (soql-company--meta arg))))

(provide 'soql-company)
