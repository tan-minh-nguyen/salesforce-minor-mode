;;; salesforce-consult-omni.el --- integrate with consult-omni package -*- lexical-binding: t -*-

(require 'salesforce-data)
(require 'salesforce-core)
(require 'salesforce-project)
(require 'url-util)

(defgroup salesforce-consult-omni nil
  "Customization options for Salesforce Consult Omni."
  :prefix "salesforce-consult-omni-")

(defcustom salesforce-consult-omni-default-fields '("Name")
  "Default Salesforce fields used when searching for records."
  :type '(repeat string)
  :group 'salesforce-consult-omni)

(defcustom salesforce-consult-omni-default-returning '("Contact (Id, Name)")
  "Default Salesforce sObjects and fields to return when searching for records.
Each entry is expected to follow the format: 
  \"SObject (Field1, Field2, ...)\"."
  :type '(repeat string)
  :group 'salesforce-consult-omni)

(cl-defun salesforce-consult-omni--process-results
    (&key source
          label
          data)
  "Process search results and return annotated results."
  (mapcar (lambda (item)
            (let* ((source source)
                   (id (gethash "Id" item))
                   (title (if label
                              (gethash label item)
                            (gethash "Name" item)))
                   (url (concat salesforce-project-url "/" id))
                   (decorated (funcall consult-omni-default-format-candidate
                                       :source source
                                       :url url
                                       :title title)))
              (propertize decorated
                          :source source
                          :title title
                          :url url)))
          data))

(defun salesforce-consult-omni--build-url (&rest args)
  (string-join args ""))

(cl-defun salesforce-consult-omni--build-sosl (input &key fields objects)
  "Build SOSL clause from FIELDS, OBJECTS and INPUT."
  (format "FIND {%s} IN %s Fields RETURNING %s"
          input
          (string-join (or fields salesforce-consult-omni-default-fields) ",")
          (if objects
              (mapcar (lambda (objects)
                        (concat object "(Id,Name)"))
                      objects)
            (string-join salesforce-consult-omni-default-returning ","))))

(defun salesforce-consult-omni--extract-soql-clause (soql-string)
  "Extract fields, table, where, and limit clauses from SOQL-STRING.
Supports SELECT … FROM … [WHERE …] [LIMIT …]."
  (let ((case-fold-search t)
        fields object where limit)

    ;; SELECT … FROM …
    (when (string-match
           "SELECT[ \t\n]+\\(.+?\\)[ \t\n]+FROM[ \t\n]+\\([a-zA-Z0-9_]+\\)"
           soql-string)
      (setq fields (match-string 1 soql-string)
            object (match-string 2 soql-string)))

    ;; WHERE (non-greedy, stops before LIMIT if present)
    (when (string-match
           "WHERE[ \t\n]+\\(.*?\\)\\(?:[ \t\n]+LIMIT\\|$\\)"
           soql-string)
      (setq where (match-string 1 soql-string)))

    ;; LIMIT N
    (when (string-match "LIMIT[ \t\n]+\\([0-9]+\\)" soql-string)
      (setq limit (match-string 1 soql-string)))

    ;; return as a list
    (list fields object where limit)))

(defun salesforce-consult-omni--build-headers ()
  "Build headers for the request."
  `(("Authorization" . ,(concat "Bearer " salesforce-project-token))))

(defun salesforce-consult-omni--doc-callback (cand)
  "Trigger consult-omni on selection CAND."
  (browse-url (get-text-property 0 :url cand)))

(cl-defun salesforce-consult-omni--search-records (input &rest args &key callback &allow-other-keys)
  "Search records on current org."
  (pcase-let* ((`(,query . ,opts) (consult-omni--split-command input (seq-difference args (list :callback callback))))
               (opts (car-safe opts))
               (sosl-string (salesforce-consult-omni--build-sosl query (plist-get opts :fields) (plist-get opts :objects)))
               (params (salesforce-consult-omni--build-params sosl-string))
               (endpoint (salesforce-consult-omni--build-url salesforce-project-url
                                                             "/services/data/v" salesforce-api-version "/search"
                                                             "?q=" (url-hexify-string sosl-string))))

    (consult-omni--fetch-url endpoint consult-omni-http-retrieve-backend
                             :encoding 'utf-8
                             :headers (salesforce-consult-omni--build-headers)
                             :parser #'consult-omni--json-parse-buffer
                             :callback
                             (lambda (attrs)
                               (when-let* ((raw-results (map-nested-elt attrs '("searchRecords")))
                                           (annotated-results (salesforce-consult-omni--process-results
                                                               :source "Search"
                                                               :label (plist-get opts :label)
                                                               :data raw-results)))
                                 (funcall callback annotated-results)
                                 annotated-results)))))

(consult-omni-define-source "Search"
                            :narrow-char ?r
                            :type 'dynamic
                            :require-match t
                            :category 'consult-omni-salesforce
                            :face 'consult-omni-engine-title-face
                            :request #'salesforce-consult-omni--fetch-records
                            ;; TODO: use org-table or grid-table to show result
                            :on-preview #'ignore
                            ;;:preview-key consult-omni-preview-key
                            :on-callback #'salesforce-consult-omni--doc-callback
                            :search-hist 'consult-omni--search-history
                            :select-hist 'consult-omni--selection-history
                            :group #'consult-omni--group-function
                            :sort t
                            :static 'both)

(cl-defun salesforce-consult-omni--query-metadata (input &rest args &key callback &allow-other-keys)
  "Search metadata on org."
  (pcase-let* ((`(,query . ,opts) (consult-omni--split-command input (seq-difference args (list :callback callback))))
               (opts (car-safe opts))
               (endpoint (salesforce-consult-omni--build-url salesforce-project-url
                                                             "/services/data/v" salesforce-api-version "/query"
                                                             "?q=" (replace-regexp-in-string " " "+" query)))
               (annotated-results))

    (consult-omni--fetch-url endpoint consult-omni-http-retrieve-backend
                             :encoding 'utf-8
                             :headers (salesforce-consult-omni--build-headers)
                             :parser #'consult-omni--json-parse-buffer
                             :callback
                             (lambda (attrs)
                               (when-let* ((raw-results (map-nested-elt attrs '("records")))
                                           (annotated-results (salesforce-consult-omni--process-results
                                                               :source "Query"
                                                               :label (plist-get opts :label)
                                                               :data raw-results)))
                                 (funcall callback annotated-results)
                                 annotated-results)))))

(consult-omni-define-source "Metadata"
                            :narrow-char ?q
                            :type 'dynamic
                            :require-match t
                            :category 'consult-omni-salesforce
                            :face 'consult-omni-engine-title-face
                            :request #'salesforce-consult-omni--query-records
                            ;; TODO: use org-table or grid-table to show result
                            :on-preview #'ignore
                            ;;:preview-key consult-omni-preview-key
                            ;;:on-return #'salesforce-consult-omni--doc-return
                            :on-callback #'salesforce-consult-omni--doc-callback
                            :search-hist 'consult-omni--search-history
                            :select-hist 'consult-omni--selection-history
                            :group #'consult-omni--group-function
                            :sort t
                            :static 'both)

(defun salesforce-consult-omni-search-metadata ()
  "Fetch records from Salesforce Org."
  (interactive)
  (consult-omni-multi nil
                      (concat "[" (propertize salesforce-org-name
                                              'face 'consult-omni-prompt-face)
                              "] Query Records: ")
                      '("Query")))

(defun salesforce-consult-omni-dispatch-search ()
  "Fetch records from Salesforce Org."
  (interactive)
  (consult-omni-multi nil
                      (concat "[" (propertize salesforce-org-name
                                              'face 'consult-omni-prompt-face)
                              "] Search Records: ")
                      '("Search")))

(provide 'salesforce-consult-omni)
