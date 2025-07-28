;;; ob-apex-log.el --- org-babel functions for template evaluation

;; Copyright (C) your name here

;; Author: tan.nguyen@furucrm.com
;; Keywords: literate programming, reproducible research
;; Homepage: https://orgmode.org
;; Version: 0.01

;;; License:

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;;; Commentary:

;; This file is not intended to ever be loaded by org-babel, rather it is a
;; template for use in adding new language support to Org-babel. Good first
;; steps are to copy this file to a file named by the language you are adding,
;; and then use `query-replace' to replace all strings of "template" in this
;; file with the name of your new language.

;; After the `query-replace' step, it is recommended to load the file and
;; register it to org-babel either via the customize menu, or by evaluating the
;; line: (add-to-list 'org-babel-load-languages '(template . t)) where
;; `template' should have been replaced by the name of the language you are
;; implementing (note that this applies to all occurrences of 'template' in this
;; file).

;; After that continue by creating a simple code block that looks like e.g.
;;
;; #+begin_src template

;; test

;; #+end_src

;; Finally you can use `edebug' to instrumentalize
;; `org-babel-expand-body:template' and continue to evaluate the code block. You
;; try to add header keywords and change the body of the code block and
;; reevaluate the code block to observe how things get handled.

;;
;; If you have questions as to any of the portions of the file defined
;; below please look to existing language support for guidance.
;;
;; If you are planning on adding a language to org-babel we would ask
;; that if possible you fill out the FSF copyright assignment form
;; available at https://orgmode.org/request-assign-future.txt as this
;; will make it possible to include your language support in the core
;; of Org-mode, otherwise unassigned language support files can still
;; be included in the contrib/ directory of the Org-mode repository.


;;; Requirements:

;; Use this section to list the requirements of this language.  Most
;; languages will require that at least the language be installed on
;; the user's system, and the Emacs major mode relevant to the
;; language be installed as well.

;;; Code:
(require 'ob)
(require 'ob-ref)
(require 'ob-comint)
(require 'ob-eval)
(require 'salesforce-minor-mode)
;; possibly require modes required for your language

;; optionally define a file extension for this language
(add-to-list 'org-babel-tangle-lang-exts '("log" . "apex-log"))

;; optionally declare default header arguments for this language
(defvar org-babel-default-header-args:apex-log '((:class-test . "")
                                                 (:org . "")
                                                 (:log-id . "")
                                                 (:number . "1")
                                                 (:filter-type . "")
                                                 (:filter-value . "")))

(defvar org-babel-default-inline-header-args:apex-log '((:org . "")
                                                        (:log-id . "")
                                                        (:class-test . "")
                                                        (:number . "1")
                                                        (:filter-type . "")
                                                        (:filter-value . "")))

;; This function expands the body of a source code block by doing things like
;; prepending argument definitions to the body, it should be called by the
;; `org-babel-execute:template' function below. Variables get concatenated in
;; the `mapconcat' form, therefore to change the formatting you can edit the
;; `format' form.
(defun org-babel-expand-body:apex-log (body params &optional processed-params)
  "Expand BODY according to PARAMS, return the expanded body."
  (require 'inf-template nil t)
  (let ((vars (org-babel--get-vars (or processed-params (org-babel-process-params params)))))
    (concat
     (mapconcat ;; define any variables
      (lambda (pair)
        (format "%s=%S"
                (car pair) (org-babel-template-var-to-template (cdr pair))))
      vars "\n")
     "\n" body "\n")))

;; This is the main function which is called to evaluate a code
;; block.
;;
;; This function will evaluate the body of the source code and
;; return the results as emacs-lisp depending on the value of the
;; :results header argument
;; - output means that the output to STDOUT will be captured and
;;   returned
;; - value means that the value of the last statement in the
;;   source code block will be returned
;;
;; The most common first step in this function is the expansion of the
;; PARAMS argument using `org-babel-process-params'.
;;
;; Please feel free to not implement options which aren't appropriate
;; for your language (e.g. not all languages support interactive
;; "session" evaluation).  Also you are free to define any new header
;; arguments which you feel may be useful -- all header arguments
;; specified by the user will be available in the PARAMS variable.
(defun org-babel-execute:apex-log (body params)
  "Execute a block of Template code with org-babel.
This function is called by `org-babel-execute-src-block'"
  (message "executing Template source code block")
  (let* ((processed-params (org-babel-process-params params))
         ;; set the session if the value of the session keyword is not the
         ;; string `none'
         ;; (session (unless (string= value "none")
         ;;           (org-babel-template-initiate-session
         ;;            (cdr (assq :session processed-params)))))
         ;; variables assigned for use in the block
         (vars (org-babel--get-vars processed-params))
         (result-params (assq :result-params processed-params))
         ;; either OUTPUT or VALUE which should behave as described above
         (result-type (assq :result-type processed-params))
         ;; expand the body with `org-babel-expand-body:template'
         (full-body (org-babel-expand-body:apex-log
                     body params processed-params)))

     ;; (if (null (assq :test-class processed-params))
     (ob-apex-log:filter-log processed-params)))
     ;; (ob-apex-log:get-log-test-class processed-params)))
    ;; actually execute the source-code block either in a session or
    ;; possibly by dropping it to a temporary file and evaluating the
    ;; file.
    ;;
    ;; for session based evaluation the functions defined in
    ;; `org-babel-comint' will probably be helpful.
    ;;
    ;; for external evaluation the functions defined in
    ;; `org-babel-eval' will probably be helpful.
    ;;
    ;; when forming a shell command, or a fragment of code in some
    ;; other language, please preprocess any file names involved with
    ;; the function `org-babel-process-file-name'. (See the way that
    ;; function is used in the language files)

(defun ob-apex-log:get-log-test-class (processed-params)
  "Get log from test class executed"
  (let* ((test-class-name (cdr (assq :test-class processed-params)))
         (uuid (org-id-uuid))
         (command (sfmm--helper:generate-command (list sfmm:apex-command-alias "run" "test" "--tests" test-class-name "--test-level" "RunSpecifiedTests" "--json"))))

    (org-babel-remove-result)

    (re-search-forward "#\\+end_src")
    (previous-line)
    (newline)
    (insert uuid)

    (salesforce-
     :command command
     :handle-success-lambda
     `(lambda (process json-instance buffer)

        (sfmm:apex:get-log
         :number "1"
         :post-log-handle
         ,`(lambda (log-content)

             (let ((filter-type ,(cdr (assq :filter-type processed-params))))
               (unless (or (equal filter-type "none")
                          (null filter-type))
                 (let ((debug-keywords '("DEBUG"))
                       (executable-keywords '("VARIABLE_ASSIGNMENT"
                                              "STATEMENT_EXECUTE"
                                              "METHOD_ENTRY"
                                              "CONSTRUCTOR_EXIT"
                                              "CODE_UNIT_STARTED"))
                       (system-keywords '("VARIABLE_SCOPE_BEGIN"
                                          "USER_INFO"
                                          "EXECUTION_STARTED"
                                          "CODE_UNIT_STARTED"
                                          "HEAP_ALLOCATE"
                                          "STATEMENT_EXECUTE"
                                          "METHOD_ENTRY"))
                       (groverment-keywords '("LIMIT_USAGE_FOR_NS"
                                              "Number of"
                                              "Maximum CPU"
                                              "Maximum heap")))

                   (setq log-content
                         (mapconcat (lambda (line)
                                      (cond ((and (equal filter-type "DEBUG")
                                                (string-match (regexp-opt debug-keywords) line))

                                             (concat line "\n"))
                                            ((and (equal filter-type "FILTER")
                                                (search ,(cdr (assq :filter-value processed-params)) line))
                                             (concat line "\n"))
                                            ((and (equal filter-type "EXECUTABLE")
                                                (string-match (regexp-opt executable-keywords) line))
                                             (concat line "\n"))
                                            ((and (equal filter-type "SYSTEM")
                                                (string-match (regexp-opt system-keywords) line))

                                             (concat line "\n"))
                                            ((and (eq filter-type "GOVERNMENT")
                                                (match-string (regexp-opt groverment-keywords) line))
                                             (concat line "\n"))))
                                    (split-string log-content "\n"
                                                  "")))))

               (with-current-buffer (find-file ,(buffer-file-name))
                 (beginning-of-buffer)
                 (re-search-forward ,uuid)
                 (forward-line -1)
                 (newline)
                 (insert (concat "|-------------------LOG--------------------------|"
                                 "\n" log-content))
                 (next-line)
                 (delete-line)

                 (alert "get log success"
                        :title "Salesforce Alert")))))))))

(defun ob-apex-log:filter-log (processed-params)
  "Filter match string in log"
  (let* ((uuid (org-id-uuid))
         (log-id (format "%s" (cdr (assq :log-id processed-params))))
         (org (format "%s" (cdr (assq :org processed-params))))
         (number (format "%s" (cdr (assq :number processed-params))))
         (buffer (current-buffer)))

         ;; (filterd-content (mapconcat
         ;;                   (lambda (line)
         ;;                     (when (string-match-p keyword line)
         ;;                       line))
         ;;                   (split-string log-content "\n")
         ;;                   "\n")))
   (org-babel-remove-result)


   (insert uuid)

   (sfmm:apex:get-log
     :log-id log-id
     :number number
     :org org
     :post-log-handle
     `(lambda (log-content)
        (let* ((filter-type ,(upcase (format "%s" (cdr (assq :filter-type processed-params)))))
               (filter-value ,(format "%s" (cdr (assq :filter-value processed-params))))
               (debug-keywords '("DEBUG"))
               (executable-keywords '("VARIABLE_ASSIGNMENT"
                                      "STATEMENT_EXECUTE"
                                      "METHOD_ENTRY"
                                      "CONSTRUCTOR_EXIT"
                                      "CODE_UNIT_STARTED"))
               (system-keywords '("VARIABLE_SCOPE_BEGIN"
                                  "USER_INFO"
                                  "EXECUTION_STARTED"
                                  "CODE_UNIT_STARTED"
                                  "HEAP_ALLOCATE"
                                  "STATEMENT_EXECUTE"
                                  "METHOD_ENTRY"))
               (groverment-keywords '("LIMIT_USAGE_FOR_NS"
                                      "Number of"
                                      "Maximum CPU"
                                      "Maximum heap"))
               (content (cond ((= filter-type "")
                               log-content)
                              (t
                                (mapconcat (lambda (line)

                                             (cond ((and (string= filter-type "DEBUG")
                                                         (string-match (regexp-opt debug-keywords) line))

                                                    (concat line "\n"))
                                                   ((and (equal filter-type "FILTER")
                                                         (search filter-value line))
                                                    (concat line "\n"))
                                                   ((and (equal filter-type "EXECUTABLE")
                                                        (string-match (regexp-opt executable-keywords) line))
                                                    (concat line "\n"))
                                                   ((and (equal filter-type "SYSTEM")
                                                         (string-match (regexp-opt system-keywords) line))
                                                    (concat line "\n"))
                                                   ((and (eq filter-type "GOVERNMENT")
                                                         (match-string (regexp-opt groverment-keywords) line))
                                                    (concat line "\n"))))
                                           (split-string log-content "\n")
                                           ""))))))

        (with-current-buffer ,buffer
          (beginning-of-buffer)
          (re-search-forward ,uuid)
          (forward-line -1)
          (newline)
          (insert (concat "|-------------------LOG--------------------------|"
                   "\n" log-content))
          (next-line)
          (delete-line)

          (alert "get log success"
                 :title "Salesforce Alert"))))))



;; This function should be used to assign any variables in params in
;; the context of the session environment.
(defun org-babel-prep-session:apex-log (session params)
  "Prepare SESSION according to the header arguments specified in PARAMS.")


(defun org-babel-template-var-to-template (var)
  "Convert an elisp var into a string of template source code
specifying a var of the same value."
  (format "%S" var))

(defun org-babel-template-table-or-string (results)
  "If the results look like a table, then convert them into an
Emacs-lisp table, otherwise return the results as a string.")


(defun org-babel-template-initiate-session (&optional session)
  "If there is not a current inferior-process-buffer in SESSION then create.
Return the initialized session."
  (unless (string= session "none")))


(provide 'ob-apex-log)
;;; ob-template.el ends here
