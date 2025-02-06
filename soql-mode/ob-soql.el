;;; ob-soql.el --- org-babel functions for SOQL evaluation -*- lexical-binding: t -*-

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

;;; Requirements:

;; Use this section to list the requirements of this language.  Most
;; languages will require that at least the language be installed on
;; the user's system, and the Emacs major mode relevant to the
;; language be installed as well.

(require 'ob)
(require 'ob-ref)
(require 'ob-comint)
(require 'ob-eval)
(require 'dx-data)

(add-to-list 'org-babel-tangle-lang-exts '("soql" . "soql"))

;; optionally declare default header arguments for this language
(defvar org-babel-default-header-args:soql (list '(:results . "value table")
                                                 '(:org . "")))

(defvar org-babel-default-inline-header-args:soql (list '(:results . "value table")
                                                        '(:org . "")))

;; This function expands the body of a source code block by doing things like
;; prepending argument definitions to the body, it should be called by the
;; `org-babel-execute:template' function below. Variables get concatenated in
;; the `mapconcat' form, therefore to change the formatting you can edit the
;; `format' form.

(defun org-babel-expand-body:soql (body params &optional processed-params)
  "Expand BODY according to PARAMS, return the expanded body."
  (require 'inf-template nil t)
  (let ((vars (org-babel--get-vars (or processed-params
                                       (org-babel-process-params params)))))

    (concat
     ;; (mapconcat #'binding-declare-variable vars "\n")
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

(defun org-babel-execute:soql (body params)
  "Execute SOQL content"
  (let* ((processed-params (org-babel-process-params params))
         (full-body (org-babel-expand-body:soql body params processed-params))
         (file-temp (with-temp-file "soql" (insert full-body))))

    ;; Clear default result
    (org-babel-remove-result)

    (re-search-forward "#\\+end_src")
    ;; Insert new result with uuid
    (insert (format "\n#+RESULTS:\n%s" uuid))

    (dx-data--soql-query `("query" "-f" ,file-temp "-o" ,(ob-soql--get-param "org" processed-params) "--result-format=csv")
                         (lambda (data)
                           (with-current-buffer `(current-buffer)
                             ;; Replace uuid with log content
                             (save-excursion
                               (beginning-of-buffer)
                               (re-search-forward uuid nil t 2)
                               (delete-line)

                               (let ((begin (point)))
                                 (insert data)
                                 (org-table-convert-region begin (point)))))))))

(defun ob-soql--get-param (key param-list)
  "Extract param in list."
  (cdr (assq key param-list)))

(defun org-babel-prep-session:soql (session params)
  "Prepare SESSION according to the header arguments specified in PARAMS.")

(defun org-babel-elisp-var-to-soql (var)
  "Convert an elisp var into a string of template source code
specifying a var of the same value."
  (format "%s" value))

(defun org-babel-soql-table-or-string (results)
  "If the results look like a table, then convert them into an
Emacs-lisp table, otherwise return the results as a string.")


(defun org-babel-template-initiate-session (&optional session)
  "If there is not a current inferior-process-buffer in SESSION then create.
Return the initialized session."
  (unless (string= session "none")))

(provide 'ob-soql)

