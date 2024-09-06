;; -*- no-byte-compile: t; no-native-compile: t; lexical-binding: t -*-
(defun dx-apex-get-all-log ()
  "Get log apex"
  (interactive)

  (dx-make-process-json-async
   :cmd (dx-build-sf-command dx-apex-command-alias "list" "log" "--json")
   (let* ((records-list (dx-get-data-json "result" json-instance))
          (header-columns '("No" "Id" "Browser" "Operation"))
          (data (dx-table--make-data-table-from-vector
                 :header-columns header-columns
                 :data records-list)))

     (pop-to-buffer
      (dx-table--create-table
       :model
       (dx-table--make-table-mode
        :column-header
        (cl-loop for key in header-columns
                 collect `(:align ,'left :title ,key `:max-width ,'50))
        :data data)
       :buffer dx-dedicated-window-right
       :open t)))))

(cl-defun dx-apex-get-log (&key log-id number org post-log-handle)
  "Get log apex"
  (dx-make-process-json-async
   :cmd
   (append
    (dx-build-sf-command
     dx-apex-command-alias "get" "log" "--json")
    ;;(when org `("-o" ,org))
    (unless (string-empty-p log-id) `("--log-id" ,log-id))
    (unless (null number) `("--number" ,number)))

   (setq json-result (gethash "result" json-instance))
   (funcall ,post-log-handle (gethash "log" (aref json-result 0)))))

(cl-defun dx-apex-log-tail (&key (buffer-name "*apex-trace-log*") (org-id nil))
  "Trace log on org."
  (interactive)
  (dx-make-process-json-async
   :cmd (dx-build-sf-command dx-apex-command-alias "get" "tail" "log" "--json")

   (let ((buffer (get-buffer-create buffer-name)))
     (with-current-buffer buffer
       (goto-char (point-max))
       (insert output)))))

(defun dx-execute-apex-code ()
 (interactive)
 (dx-execute-apex (point-min)))

(defun dx-visualforce-generate-page ()
  (interactive)
  (let* ((page-name (read-string "page name: "))
         (page-label (read-string "page label: "))
         (command (dx-build-sf-command dx-visualforce-command-alias "generate" "page" "--json" "--name" page-name "--label" page-label "--output-dir" (sfmm--internal:build-full-path dx-default-vf-path))))

    (dx-make-process-json-async
     :cmd command
     ;; Swtich new page
     (switch-to-buffer (find-file (concat (dx-build-full-path dx-default-vf-path) "/" page-name ".page")))

     (alert (format "Create visualforce page" page-name)
            :title "Salesforce Alert"))))

(defun dx-visualforce-generate-component ()
  (interactive)
  (let* ((page-name (read-string "page name: "))
         (page-label (read-string "page label: "))
         (command (dx-generate-command
                   (list dx-visualforce-command-alias "generate" "component" "--json" "--name" page-name "--label" page-label "--output-dir" (dx-build-full-path dx-default-vf-components-path)))))

    (dx-make-process-json-async
     :cmd command
     (alert (format "Create visualforce page" page-name)
            :title "Salesforce Alert"))))

(defun dx-apex-generate-trigger ()
  "Generate apex class"
  (interactive)
  (let* ((class-name (read-string "class name: "))
         (sobject-name (read-string "sobject name: "))
         (events-name (read-string "event name: "))
         (command (dx-build-sf-command
                   dx-apex-command-alias "generate" "trigger" "--name" class-name "--output-dir" (dx-build-full-path dx-default-apex-trigger-path) "--json"))
         (class-expand ""))

    (dx-make-process-json-async
     :cmd command
     (let ((full-path-file (concat (dx-build-full-path dx-default-apex-trigger-path) "/" class-name ".trigger")))
       (with-current-buffer (find-file full-path-file)
         (when ,sobject-name
           (replace-string "SOBJECT" sobject-name))
         (when ,events-name
           (replace-string "beforce insert" events-name)))))))

(defun dx-apex-generate-class ()
  "Generate apex class"
  (interactive)
  (let* ((class-name (read-string "class name: "))
         (class-extend (read-string "class parent: "))
         (class-implements (read-string "class implements: "))
         (command (dx-build-sf-command
                   dx-apex-command-alias "generate" "class" "--name" class-name "--output-dir" (dx-build-full-path dx-default-apex-class-path) "--json"))
         (class-expand ""))

    (progn
      (unless (string= class-extend "")
        (setq class-expand (concat class-expand "extends" " " class-extend " ")))
      (unless (string= class-implements "")
        (setq class-expand (concat class-expand "implements" " " class-implements " "))))

    (dx-make-process-json-async
     :cmd command
     (cond ((= (plist-get json-instance :status) 0)
            (switch-to-buffer (find-file (dx-build-full-path dx-default-apex-class-path
                                                             (concat class-name ".cls"))))
            (goto-char (- (point-at-eol) 1))
            (insert class-expand))
           (t (funcall #'dx-handle-process-error--json json-instance))))))

(defun dx-apex-generate-test-class ()
  "Generate apex test class"
  (interactive)
  (let* ((class-name (read-string "class name: "))
         (command (dx-build-sf-command dx-apex-command-alias
                                       "generate"
                                       "class"
                                       "--name" class-name
                                       "--output-dir" (dx-build-full-path dx-default-apex-class-path)
                                       "--json")))

    (dx-make-process-json-async
     :cmd command
     (cond ((= (plist-get json-instance :status) 0)
            (switch-to-buffer (find-file (dx-build-full-path dx-default-apex-class-path
                                                             (concat class-name ".cls"))))
            (beginning-of-buffer)
            (insert "@isTest\n")
            (save-buffer)
            (current-buffer))
           (t (funcall #'dx-handle-process-error--json json-instance))))))

(defun dx-apex-generate-test-method ()
  "Generate apex test method"
  (interactive)
  (let ((method-name (read-string "method name: ")))

    (end-of-buffer)
    (forward-line -1)
    (insert (format "\n%s\nprivate static void %s () {\n}"
                    "@isTest"
                    method-name))))

(cl-defun dx-lightning-generate
    (&key type output-dir message-success component-type)
  ""
  (let* ((component-name (read-string "lwc name: "))
         (command (dx-generate-command
                   (list dx-lightning-command-alias "generate" "component" "--output-dir" output-dir "--name" component-name "--json"))))

    (when (string= type "component")
      (setq command
            (append command (list "--type" component-type))))

    (dx-make-process-json-async
     :cmd command
     (alert (format message-success component-name)
            :title "Salesforce Alert"))))

(defun dx-lightning-component-generate-lwc ()
  ""
  (interactive)
  (dx-lightning-generate
   :type "component"
   :output-dir (dx-build-full-path dx-default-lwc-path)
   :message-success "Create %s success"
   :component-type "lwc"))

(defun dx-lightning-component-generate-aura ()
  "Generate Aura Component"
  (interactive)
  (dx-lightning-generate
   :type "component"
   :output-dir (dx-build-full-path dx-default-aura-path)
   :message-success "Create aura component %s success"
   :component-type "aura"))

(defun dx-lightning-app-generate ()
  "Create lightning app"
  (interactive)
  (dx-lightning-generate
   :type "app"
   :output-dir (dx-build-full-path dx-default-aura-path)
   :message-success "Create app %s sucesss"))

(defun dx-lightning-event-generate ()
  "Create lightning event"
  (interactive)
  (dx-lightning-generate
   :type "event"
   :output-dir (dx-build-full-path dx-default-aura-path)))

(defun dx-lightning-interface-generate ()
  "Create lightning interface"
  (interactive)
  (dx-lightning-generate
   :type "interface"
   :output-dir (dx-build-full-path dx-default-aura-path)
   :message-success "Create interface %s success"))

(defun dx-lightning-test-generate ()
  "Create lightning test"
  (interactive)
  (dx-lightning-generate
   :type "test"
   :output-dir (dx-build-full-path dx-default-test-path)
   :message-success "Create test %s sucess"))

(provide 'dx-apex)
