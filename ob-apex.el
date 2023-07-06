;;; ob-template.el --- org-babel functions for template evaluation

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

(require 'ob)
(require 'ob-ref)
(require 'ob-comint)
(require 'ob-eval)
(require 'salesforce-minor-mode)

(add-to-list 'org-babel-tangle-lang-exts '("cls" . "apex"))

;; optionally declare default header arguments for this language
(defvar org-babel-default-header-args:apex '((:results . "none")
                                             (:org . "")
                                             (:log-filter-type . "none")
                                             (:log-filter-value . "none")))


(defvar org-babel-default-inline-header-args:apex '((:results . "none")
                                                    (:org . "")
                                                    (:log-filter-type . "none")
                                                    (:log-filter-value . "none")))

;; This function expands the body of a source code block by doing things like
;; prepending argument definitions to the body, it should be called by the
;; `org-babel-execute:template' function below. Variables get concatenated in
;; the `mapconcat' form, therefore to change the formatting you can edit the
;; `format' form.

(defun org-babel-expand-body:apex (body params &optional processed-params)
  "Expand BODY according to PARAMS, return the expanded body."
  (require 'inf-template nil t)
  (let ((vars
         (org-babel--get-vars
          (or processed-params
              (org-babel-process-params params)))))

    (concat
     (mapconcat #'binding-declare-variable vars "\n")
     "\n" body "\n")))

;; This is the main function which is called to evaluate a code
;; block.

;; This function will evaluate the body of the source code and
;; return the results as emacs-lisp depending on the value of the
;; :results header argument
;; output means that the output to STDOUT will be captured and returned
;; value means that the value of the last statement in the source code block will be returned

;; The most common first step in this function is the expansion of the
;; PARAMS argument using `org-babel-process-params'.

;; Please feel free to not implement options which aren't appropriate
;; for your language (e.g. not all languages support interactive "session" evaluation).  Also you are free to define any new header
;; arguments which you feel may be useful -- all header arguments
;; specified by the user will be available in the PARAMS variable.

(defun org-babel-execute:apex (body params)
  (let* ((processed-params (org-babel-process-params params))
         (filter-type (assq :filter-type processed-params))
         (full-body (org-babel-expand-body:apex
                        body params processed-params)))

    (execute-apex-code processed-params full-body)))

(defun execute-apex-code (processed-params content)
  (let* ((uuid (org-id-uuid))
         (buffer (buffer-file-name))
         (tempfile (make-temp-file "temp-code"))
         (result-eval (format "%s" (cdr (assq :results processed-params))))
         (command
           (sfmm--helper:generate-command (list "apex" "run" "-f" tempfile "--json")))
         process 'nil)

   (write-region content nil tempfile)

   (cond ((not (eq (cdr (assq :org processed-params))
                   ""))
          (setq command (append command
                                (list "-o" (cdr (assq :org processed-params)))))))

   ;; Clear default result
   (org-babel-remove-result)

   (unless (string= result-eval "none")
     (re-search-forward "#\\+end_src")
     ;; Insert new result with uuid
     (insert (format "\n\n#+begin_src apex-log :uuid %s\n %s\n#+end_src\n"
                     uuid
                     uuid)))


   (sfmm--helper:make-async-process
    :command command
    :buffer-name uuid
    :handle-success-lambda
    `(lambda (process json-instance buffer)

       (let ((log-content (sfmm--helper:get-data-hashtable "result.logs" json-instance))
             (log-filter-type ,(format "%s" (cdr (assq :log-filter-type processed-params))))
             (log-filter-value ,(format "%s" (cdr (assq :log-filter-value processed-params)))))

         (unless (or (equal log-filter-type "none")
                     (null log-filter-type))
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
                                 (cond ((and (equal log-filter-type "DEBUG")
                                             (string-match (regexp-opt debug-keywords) line))

                                        (concat line "\n"))
                                       ((and (equal log-filter-type "FILTER")
                                             (search log-filter-value line))
                                        (concat line "\n"))
                                       ((and (equal log-filter-type "EXECUTABLE")
                                             (string-match (regexp-opt executable-keywords) line))
                                        (concat line "\n"))
                                       ((and (equal log-filter-type "SYSTEM")
                                             (string-match (regexp-opt system-keywords) line))

                                        (concat line "\n"))
                                       ((and (eq log-filter-type "GOVERNMENT")
                                             (match-string (regexp-opt groverment-keywords) line))
                                        (concat line "\n"))))
                              (split-string log-content "\n")
                              ""))))

         (unless (equal ,result-eval "none")

           (with-current-buffer (find-file-noselect ,buffer)
             (beginning-of-buffer)
             (re-search-forward ,uuid nil t 2)
             (delete-line)

             (insert log-content)))

         (alert "Run apex code complete"
                :title "Salesforce Alert"))))))

(defun binding-declare-variable (pair)
  (let* ((var
          (split-string
            (format "%s"(car pair)) "\\."))
         (var-type (car var))
         (var-name (car (cdr var)))
         (value
          (org-babel-template-var-to-template
           (cdr pair))))

    (format
     "%s %s = %s;"
     var-type
     var-name
     (if (string= var-type "String")
       (format "'%s'" value)
       value))))

(defun org-babel-prep-session:apex (session params)
  "Prepare SESSION according to the header arguments specified in PARAMS.")


(defun org-babel-template-var-to-template (var)
  "Convert an elisp var into a string of template source code
specifying a var of the same value."
  (format "%s" var))

(defun org-babel-template-table-or-string (results)
  "If the results look like a table, then convert them into an
Emacs-lisp table, otherwise return the results as a string.")


(defun org-babel-template-initiate-session (&optional session)
  "If there is not a current inferior-process-buffer in SESSION then create.
Return the initialized session."
  (unless (string= session "none")))

(provide 'ob-apex)
