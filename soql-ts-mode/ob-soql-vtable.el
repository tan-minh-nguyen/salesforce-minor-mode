;;; ob-soql-vtable.el --- convert data to Emacs vtable -*- lexical-binding: t -*-
;;; Commentary:
;;; Code:

(require 'ob-soql-core)

(defun ob-soql--display-as-vtable (metadata)
  "Display results using vtable widget.
METADATA: Query metadata plist
Returns buffer displaying the vtable."
  (if (not ob-soql-core--has-vtable)
      (progn
        (message "vtable requires Emacs 29+, falling back to tabulated-list")
        (ob-soql--display-as-tabulated-list metadata))
    (require 'vtable)
    (let* ((records (plist-get metadata :records))
           (fields (plist-get metadata :fields))
           (sobject (plist-get metadata :sobject))
           (buffer (generate-new-buffer (format "*SOQL Results: %s*"
                                                (or sobject "Query")))))
      (ob-soql-core-buffer-modifications
       :buffer buffer
       (setq-local ob-soql--query-metadata metadata)

       ;; Create vtable
       (let ((table (make-vtable
                     :columns (mapcar (lambda (field)
                                        `(:name ,field
                                                :width ,(min ob-soql-display-max-column-width
                                                             (max 10 (length field)))))
                                      fields)
                     :objects records
                     :getter (lambda (record column table)
                               (let* ((column-name (vtable-column table column))
                                      (value (assoc-default column-name record #'string= "")))
                                 (ob-soql-core--truncate-string
                                  (or value "")
                                  ob-soql-display-max-column-width)))
                     :actions (ob-soql-vtable--actions metadata)
                     :use-header-line nil)))
         (setq-local vtable-object table))

       (goto-char (point-min))
       (ob-soql-results-mode))

      (pop-to-buffer buffer)
      buffer)))

(defmacro ob-soql-vtable--make-command (fn &rest metadata)
  "Make command function wrap around action."
  `(lambda (arg)
     (interactive)
     (apply ,fn arg ,metadata)))

(defun ob-soql-vtable--open-record (row metadata)
  "Format ID to Salesforce record link."
  (let ((org-url (plist-get metadata :org-url))
        (id (assoc-default "Id" row (lambda (v1 v2)
                                      (string= (downcase v1)
                                               (downcase v2))))))
    (if id
        (ob-soql-core--convert-id-to-hyperlink id org-url)
      (message "Id field not found on record."))))

(defun ob-soql-vtable--actions (metadata)
  "Actions on Salesforce vtable data."
  `("RET" ,(ob-soql-vtable--make-command #'ob-soql-vtable--open-record metadata)))

(provide 'ob-soql-vtable)
