;; -*- no-byte-compile: t; no-native-compile: t; lexical-binding: t -*-
(require 'dx-config)
(require 'alert)
(require 'cl)
(require 'json)
(require 'async)



(defun dx--process-parse-json (content)
  "Parse `content' to json."
  (condition-case json-instance
      (json-parse-string content :object-type 'plist)
    (:sucess json-instance)
    (error (cond ((string-match-p "json-parse-error" (symbol-name (car json-instance)))
                  (alert "something wrong with JSON result."
                         :title "DX Alert"
                         :severity 'urgent))
                 (t (alert (message json-instance)
                           :title "DX Alert"
                           :severity 'urgent))))))

(defun dx-make-handle-error-process (&optional buffer)
  "Handle errors for process."
  (let ((output-buffer (or buffer (generate-new-buffer dx-process-error-buffer))))
    (make-pipe-process
     :name dx-process-error-buffer
     :buffer output-buffer
     :noquery nil
     :sentinel
     (lambda (process event) 
       (with-current-buffer output-buffer
         (beginning-of-buffer)

         (condition-case json-instance
             (json-parse-buffer)
           (error (cond ((= (buffer-size) 0)
                         nil)
                        (t
                         (alert (replace-regexp-in-string "" "" (buffer-string))
                                :title "Salesforce Alert"
                                :severity 'urgent))))))))))

(cl-defun dx-make-process (&key cmd type callback)
  "Use to make process for all dx command on dx cli.

     `cmd': command want to run use list type.
     `type': type of process, accept value is async or sync.
     OPTION `body': function call after process complete, use for async type and use process result as parameter."
  (unless (member type '(async sync))
    (error "Invalid type of process"))

  (with-environment-variables (("NODE_NO_WARNINGS" "1"))
    (let* ((output-result-buffer (generate-new-buffer dx-process-success-buffer))
           (output-error-buffer (generate-new-buffer dx-process-error-buffer))
           (dx-process
            (make-process
             :name "dx"
             :command cmd
             :buffer (get-buffer-create dx-process-buffer)
             :filter
             (lambda (process output)
               (with-current-buffer output-result-buffer
                 (insert output)))
             :stderr (dx-make-handle-error-process output-error-buffer))))

      (pcase type
        ('async
         (set-process-sentinel dx-process
                               (lambda (process event)
                                 (message "Execute %s success" (string-join cmd " "))

                                 (funcall callback
                                          (dx-process-get-content output-result-buffer))

                                 (dx-process-reset (list output-result-buffer output-error-buffer)))))
        ('sync
         (when (accept-process-output dx-process))
         (message "Execute %s success" (string-join cmd " "))

         (prog1 (dx-process-get-content output-result-buffer)
           (dx-process-reset (list output-result-buffer output-error-buffer))))))))

(defmacro dx-process-get-content (buffer)
  "Get content of process."
  `(with-current-buffer (get-buffer ,buffer)
     (buffer-string)))

(defun dx--execute-asynchronous-process (process-list &optional params)
  "Execute asynchronous action."
  (async-let ((proc (pop process-list)))
    (async-start (lambda ()
                   (cond ((fboundp proc)
                          (funcall proc))
                         (t
                          (funcall-interactively proc))))
                 (lambda (result)
                   (message "%s" result)))))

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

(cl-defmacro dx-make-process-json-async (&rest body &key cmd &allow-other-keys)
  "Execute async dx cli command and return json result."
  `(let ((cb (lambda (content)
               (let ((json-instance (json-parse-string content :object-type 'plist)))
                 ,@body))))
     (condition-case json-instance
         (dx-make-process :cmd ,cmd
                          :type 'async 
                          :callback cb)
       (error (cond ((string-match-p "json-parse-error" (symbol-name (car json-instance)))
                     (alert "something wrong with JSON result."
                            :title "DX Alert"
                            :severity 'urgent))
                    (t (alert (message json-instance)
                              :title "DX Alert"
                              :severity 'urgent)))))))

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

(defun dx-process-reset (buffers)
  (mapc (lambda (buffer)
          (when buffer
            (with-current-buffer buffer
              (let ((set-buffer-modified-p nil))
                (ignore-errors
                  (kill-process)
                  (kill-this-buffer))))))
        buffers))

(provide 'dx-process)
