;;; salesforce-sobject.el --- SObject metadata generator -*- lexical-binding: t; -*-

;;; Commentary:
;; Generate SObject metadata JSON files via Salesforce CLI.
;; Mimics VSCode extension's sobjects-faux-generator functionality.

;;; Code:

(require 'salesforce-core)
(require 'json)

;;; Configuration

(defcustom salesforce-sobject-cache-dir ".sfdx/tools/soqlMetadata"
  "Directory to cache SObject metadata relative to project root."
  :type 'string
  :group 'salesforce)

(defcustom salesforce-sobject-batch-size 10
  "Number of SObjects to describe in parallel."
  :type 'integer
  :group 'salesforce)

(defvar salesforce-sobject--generation-progress nil
  "Current progress of SObject generation: (current . total).")

(defvar salesforce-sobject--pending-callbacks nil
  "List of pending callbacks waiting for generation to complete.")

;;; Core Functions

(defun salesforce-sobject--cache-dir ()
  "Get the full path to SObject cache directory."
  (expand-file-name 
   salesforce-sobject-cache-dir 
   (salesforce-core--find-root-dir)))

(defun salesforce-sobject--list-all ()
  "List all SObjects in the current org.
Returns list of SObject names, or nil on error."
  (let ((process (salesforce-core--org-process
                  :args '("sobject" "list" "--json")
                  :sync t)))
    (when (and process (eq (process-exit-status process) 0))
      (let* ((json (salesforce-core-parse-buffer-json 
                    (process-buffer process)))
             (result (map-elt json "result")))
        (when result
          (cl-loop for sobject across result
                   collect (map-elt sobject "name")))))))

(defun salesforce-sobject--describe (sobject-name callback)
  "Describe SOBJECT-NAME and call CALLBACK with result.
CALLBACK receives (sobject-name metadata-json error)."
  (salesforce-core--org-process
   :args `("sobject" "describe" "-s" ,sobject-name "--json")
   (let ((status (map-elt json-instance "status"))
         (result (map-elt json-instance "result")))
     (if (and status (= status 0) result)
         ;; Success
         (funcall callback sobject-name result nil)
       ;; Error
       (funcall callback sobject-name nil 
                (or (map-elt json-instance "message")
                    "Unknown error"))))))

(defun salesforce-sobject--save-metadata (sobject-name metadata)
  "Save METADATA for SOBJECT-NAME to cache file.
Returns the file path where metadata was saved."
  (let* ((cache-dir (salesforce-sobject--cache-dir))
         (subdir (if (string-suffix-p "__c" sobject-name)
                     salesforce-custom-objects-dir
                   salesforce-standard-objects-dir))
         (full-dir (expand-file-name subdir cache-dir))
         (file-path (expand-file-name 
                     (concat sobject-name ".json") 
                     full-dir)))
    
    ;; Create directory if needed
    (unless (file-exists-p full-dir)
      (make-directory full-dir t))
    
    ;; Write JSON file
    (with-temp-file file-path
      (insert (json-encode metadata)))
    
    file-path))

;;; Batch Processing

(defun salesforce-sobject--generate-batch (sobjects finished-callback)
  "Generate metadata for list of SOBJECTS.
FINISHED-CALLBACK is called with (success-count error-count errors-list) when done."
  (let ((total (length sobjects))
        (success-count 0)
        (error-count 0)
        (errors-list nil)
        (processed 0))
    
    (dolist (sobject sobjects)
      (salesforce-sobject--describe 
       sobject
       (lambda (name metadata error)
         (if error
             (progn
               (cl-incf error-count)
               (push (cons name error) errors-list)
               (message "Failed to describe %s: %s" name error))
           (progn
             (cl-incf success-count)
             (salesforce-sobject--save-metadata name metadata)
             (message "Generated metadata for %s" name)))
         
         ;; Update progress
         (cl-incf processed)
         (setq salesforce-sobject--generation-progress 
               (cons processed total))
         (message "Generating SObject metadata: %d/%d" processed total)
         
         ;; Call callback when done
         (when (= processed total)
           (setq salesforce-sobject--generation-progress nil)
           (funcall finished-callback success-count error-count errors-list)))))))

;;; Interactive Commands

;;;###autoload
(defun salesforce-sobject-refresh ()
  "Refresh all SObject definitions from current org.
Generates metadata JSON files for code completion."
  (interactive)
  (if-let ((sobjects (salesforce-sobject--list-all)))
      (progn
        (message "Found %d SObjects. Generating metadata..." 
                 (length sobjects))
        (salesforce-sobject--generate-batch 
         sobjects
         (lambda (success error errors-list)
           (if (> error 0)
               (progn
                 (salesforce-core--alert 
                  (format "SObject refresh: %d success, %d errors" success error)
                  :severity 'urgent)
                 (when errors-list
                   (with-current-buffer (get-buffer-create "*SObject Errors*")
                     (erase-buffer)
                     (insert "SObject Generation Errors:\n\n")
                     (dolist (err errors-list)
                       (insert (format "- %s: %s\n" (car err) (cdr err))))
                     (display-buffer (current-buffer)))))
             (salesforce-core--alert 
              (format "SObject refresh complete: %d success" success))))))
    (user-error "Failed to list SObjects. Check org connection")))

;;;###autoload
(defun salesforce-sobject-refresh-single (sobject-name)
  "Refresh metadata for a single SOBJECT-NAME."
  (interactive 
   (list (read-string "SObject name: " 
                      (when-let ((bounds (bounds-of-thing-at-point 'symbol)))
                        (buffer-substring-no-properties 
                         (car bounds) (cdr bounds))))))
  (salesforce-sobject--describe
   sobject-name
   (lambda (name metadata error)
     (if error
         (user-error "Failed to describe %s: %s" name error)
       (let ((file-path (salesforce-sobject--save-metadata name metadata)))
         (salesforce-core--alert (format "Refreshed metadata for %s" name))
         (message "Saved to: %s" file-path))))))

;;;###autoload
(defun salesforce-sobject-clear-cache ()
  "Clear all cached SObject metadata."
  (interactive)
  (when (yes-or-no-p "Clear all SObject metadata cache? ")
    (let ((cache-dir (salesforce-sobject--cache-dir)))
      (when (file-exists-p cache-dir)
        (delete-directory cache-dir t)
        (salesforce-core--alert "SObject cache cleared")))))

;;;###autoload
(defun salesforce-sobject-check-metadata (sobject-name)
  "Check if metadata exists for SOBJECT-NAME.
If not, offer to generate it."
  (let* ((cache-dir (salesforce-sobject--cache-dir))
         (subdir (if (string-suffix-p "__c" sobject-name)
                     salesforce-custom-objects-dir
                   salesforce-standard-objects-dir))
         (file-path (expand-file-name 
                     (concat sobject-name ".json")
                     (expand-file-name subdir cache-dir))))
    (if (file-exists-p file-path)
        file-path
      (when (y-or-n-p 
             (format "SObject %s not cached. Generate metadata? " sobject-name))
        (salesforce-sobject-refresh-single sobject-name)
        (when (file-exists-p file-path)
          file-path)))))

(provide 'salesforce-sobject)

;;; salesforce-sobject.el ends here
