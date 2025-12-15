;;; soql-capf.el --- SOQL completion-at-point support -*- lexical-binding: t; -*-

;;; Commentary:
;; Provides completion-at-point-functions support for SOQL.
;; Compatible with Corfu, Company-capf, and built-in completion.

;;; Code:

(require 'soql-completion)

;;; Completion-at-point Function

(defun soql-capf ()
  "Completion-at-point function for SOQL fields.
Compatible with Corfu, Company-capf, and built-in completion."
  (when (soql-completion--statement-p)
    (let* ((bounds (soql-completion--get-bounds))
           (start (car bounds))
           (end (cdr bounds))
           (prefix (buffer-substring-no-properties start end)))
      
      (list start end
            (completion-table-dynamic
             (lambda (str)
               (mapcar (lambda (cand)
                         (let ((name (car cand))
                               (props (cdr cand)))
                           (propertize name
                                       'soql-completion-data props)))
                       (soql-completion--candidates str))))
            :exclusive 'no
            :company-docsig #'soql-capf--annotation
            :annotation-function #'soql-capf--annotation
            :exit-function #'soql-capf--exit
            :company-doc-buffer #'soql-capf--doc-buffer))))

;;; Helper Functions

(defun soql-capf--annotation (candidate)
  "Get annotation for CANDIDATE."
  (when-let ((data (get-text-property 0 'soql-completion-data candidate)))
    (when-let ((annotation (plist-get data :annotation)))
      (concat " " annotation))))

(defun soql-capf--exit (candidate status)
  "Handle completion exit for CANDIDATE with STATUS."
  (when (eq status 'finished)
    (when-let* ((data (get-text-property 0 'soql-completion-data candidate))
                (meta (plist-get data :meta))
                ((not (null meta))))
      (message "Picklist values: %s" (string-join meta ", ")))))

(defun soql-capf--doc-buffer (candidate)
  "Return documentation buffer for CANDIDATE."
  (when-let* ((data (get-text-property 0 'soql-completion-data candidate))
              (field (plist-get data :field)))
    (let ((buf (get-buffer-create "*soql-completion-doc*")))
      (with-current-buffer buf
        (erase-buffer)
        (insert (format "Field: %s\n" (map-elt field "name")))
        (insert (format "Type: %s\n" (map-elt field "type")))
        (insert (format "Label: %s\n" (map-elt field "label")))
        (when-let ((picklist-values (plist-get data :meta)))
          (insert "\nPicklist Values:\n")
          (dolist (value picklist-values)
            (insert (format "  - %s\n" value))))
        (special-mode))
      buf)))

;;; Setup Function

(defun soql-capf-setup ()
  "Setup SOQL completion-at-point."
  (add-hook 'completion-at-point-functions #'soql-capf nil t))

(provide 'soql-capf)

;;; soql-capf.el ends here
