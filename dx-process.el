;; dx-process.el -*- no-byte-compile: t; no-native-compile: t; lexical-binding: t -*-
(require 'dx-config)
(require 'alert)
(require 'cl)
(require 'json)
(require 'async)

(defun dx-make-chain-process (&rest process-list &key params &allow-other-keys)
  "Chain all processes."
  (let ((proc (pop process-list)))
    (dx-make-process
     :cmd (plist-get proc :cmd)
     :type 'async
     :callback (lambda (content)
                 (let ((result-proc (condition-case error
                                        (funcall (plist-get proc :callback) content params)
                                      (error (alert (format "%s" error)
                                                    :title "DX Alert"
                                                    :severity 'urgent)))))
                   (dx-make-chain-process (car process-list) :params result-proc))))))

(cl-defmacro dx-process--make-handle-json (&rest body &key cmd &allow-other-keys)
  "Execute async dx cli command and return json result."
  `(let* ((callback (lambda (json-instance)
                      ,@body))
          (handle-callback (lambda (proc)
                             (funcall callback (dx-parse-buffer-json (process-buffer proc))))))
        (apply #'dx-start-process handle-callback ,cmd)))

(cl-defmacro dx-make-process-json-sync (&key cmd)
  "Execute sync dx cli command and return json result."
  `(condition-case json-instance
       (json-parse-string (dx-make-process :cmd ,cmd :type 'sync) :object-type 'plist)
     (:success json-instance)
     (error (cond ((string-match-p "json-parse-error" (symbol-name (car json-instance)))
                   (alert "something wrong with JSON result."
                          :title "DX Alert"
                          :severity 'urgent))
                  (t (alert json-instance
                            :title "DX Alert"
                            :severity 'urgent))))))

;; Async library
(defun dx-start-process (&optional callback &rest params &allow-other-keys)
  "Start dx process."
  (message "%s" params)
  (apply #'async-start-process "dx-process"
         dx-lib-alias 
         callback
         params))
           

(defun dx-parse-buffer-json (buffer)
  "Parsing json on buffer."
  (condition-case data
      (with-current-buffer buffer
        (beginning-of-buffer)
        (json-parse-buffer :object-type 'plist))
   (:succes data)
   (error (with-current-buffer buffer (buffer-string)))))

(defun dx-process--handle-error-metadata-action (json-instance)
  "Get error messages of metadata action."
  (mapconcat (lambda (component-error)
               (format "Metadata name: %s\nMetadata type: %s\nLine: %s\nError: %s"
                       (plist-get component-error :fileName)
                       (plist-get component-error :componentType)
                       (plist-get component-error :lineNumber)
                       (plist-get component-error :problem)))
             ;; List of error messages
             (dx-core--get-data-json "result.details.componentFailures" json-instance)
             ;; Separator for each failed components
             "\n=======================\n"))
             

(defun dx-process--handle-common-error (json-instance)
  "Get common error message in fail operation."
  (format "Name: %s\nMessage: %s" 
          (plist-get json-instance :name)
          (plist-get json-instance :message)))

(defun dx-handle-process-error--json (json-instance)
  "Handle error response by dx process."
  (let ((show-message (cond 
                       ;; TODO: handle error base on type of action instead of status prop
                       ((not (plist-member json-instance :context)) 
                        (dx-process--handle-error-metadata-action json-instance))
                       (t (dx-process--handle-common-error json-instance)))))

    (alert show-message
           :title "DX Alert"
           :category 'error
           :severity 'urgent)
    show-message))

;; Modify async package to handle signal process
(defun dx--async-when-done (proc &optional _change)
  "Handle signal process return from sf package."
  (when-let ((_ (eq (process-exit-status proc) 1))
             (_ (string= "dx-process" (process-name proc))))
    (condition-case error
        (dx-handle-process-error--json (dx-parse-buffer-json (process-buffer proc))))))

(advice-add 'async-when-done :after #'dx--async-when-done)

(provide 'dx-process)
