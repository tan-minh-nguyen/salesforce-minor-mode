;;; salesforce-consult-omni.el --- integrate with consult-omni package -*- lexical-binding: t -*-

(require 'salesforce-data)
(require 'salesforce-core)
(require 'salesforce-project)
(require 'url-util)

(defun salesforce-consult-omni--process-results (query raw-results)
  "Process search results and return annotated results."
  (mapcar (lambda (item)
            (let* ((source "Records")
                   (id (gethash "Id" item))
                   (title (gethash "Name" item))
                   (url (concat salesforce-project-url "/" id))
                   (decorated (funcall consult-omni-default-format-candidate
                                       :source source
                                       :query query
                                       :url url
                                       :title title)))
              (propertize decorated
                          :source source
                          :title title
                          :url url
                          :query query)))
          raw-results))

(defun salesforce-consult-omni--build-url (&rest args)
  (string-join args ""))

(defun salesforce-consult-omni--build-params (query)
  "Build parameters for the search query."
  `(("q" . ,(url-hexify-string query))))

(cl-defun salesforce-consult-omni--build-sosl (input &key fields objects)
  "Build SOSL clause from FIELDS, OBJECTS and INPUT."
  (format "FIND {%s} IN %s Fields RETURNING %s"
          input
          (if fields
              (string-join fields ",")
            "Name")
          (if objects
              (mapcar (lambda (objects)
                        (concat object "(Id,Name)"))
                      objects)
            "Contact (Id, Name)")))

(defun salesforce-consult-omni--build-headers ()
  "Build headers for the request."
  `(("Authorization" . ,(concat "Bearer " salesforce-project-token))))

;; (defun salesforce-consult-omni--doc-return (cand)
;;   "Return the string of selection CAND with no properties."
;;   (when (stringp cand)
;;     (substring-no-properties (string-trim cand))))

(defun salesforce-consult-omni--doc-callback (cand)
  "Trigger consult-omni on selection CAND."
  (browse-url (get-text-property 0 :url cand)))

(cl-defun salesforce-consult-omni--fetch-records (input &rest args &key callback &allow-other-keys)
  "Search records on current org."
  (pcase-let* ((`(,query . ,opts) (consult-omni--split-command input (seq-difference args (list :callback callback))))
               (opts (car-safe opts))
               (sosl-string (salesforce-consult-omni--build-sosl query (plist-get opts :fields) (plist-get opts :objects)))
               (params (salesforce-consult-omni--build-params sosl-string))
               (endpoint (salesforce-consult-omni--build-url salesforce-project-url
                                                             "/services/data/v" salesforce-api-version "/search"
                                                             "?q=" (assoc-default "q" params))))

    (consult-omni--fetch-url endpoint consult-omni-http-retrieve-backend
                             :encoding 'utf-8
                             :params (salesforce-consult-omni--build-params query)
                             :headers (salesforce-consult-omni--build-headers)
                             :parser #'consult-omni--json-parse-buffer
                             :callback
                             (lambda (attrs)
                               (when-let* ((raw-results (map-nested-elt attrs '("searchRecords")))
                                           (annotated-results (salesforce-consult-omni--process-results query raw-results)))
                                 (funcall callback annotated-results)
                                 annotated-results)))))

(consult-omni-define-source "Records"
                            :narrow-char ?r
                            :type 'dynamic
                            :require-match t
                            :category 'consult-omni-salesforce
                            :face 'consult-omni-engine-title-face
                            :request #'salesforce-consult-omni--fetch-records
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

(provide 'salesforce-consult-omni)
