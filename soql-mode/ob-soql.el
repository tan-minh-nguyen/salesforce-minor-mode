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

;; FIXME: export data from csv to other format

(require 'ob)
(require 'ob-ref)
(require 'ob-comint)
(require 'ob-eval)
(require 'dx-data)

(add-to-list 'org-babel-tangle-lang-exts '("soql" . "soql"))

;; optionally declare default header arguments for this language
(defvar org-babel-default-header-args:soql `((:results . "output raw table replace")
                                             (:org . "")
                                             (:limit . "2000")))

(defvar org-babel-default-inline-header-args:soql `((:results . "output raw table replace")
                                                    (:org . "")
                                                    (:limit . "2000")))

;; This function expands the body of a source code block by doing things like
;; prepending argument definitions to the body, it should be called by the
;; `org-babel-execute:template' function below. Variables get concatenated in
;; the `mapconcat' form, therefore to change the formatting you can edit the
;; `format' form.

(defun org-babel-expand-body:soql (body params &optional processed-params)
  "Expand BODY according to PARAMS, return the expanded body."
  (require 'inf-template nil t)
  (let ((vars (org-babel--get-vars (or processed-params
                                      (org-babel-process-params params))))
        (soql (if (string-match-p "LIMIT" body) body
                (format "%s LIMIT %s" body (ob-soql--get-param :limit processed-params)))))

    (concat "\n" (ob-soql--binding-declare-variable soql vars) "\n")))

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
         (file-temp (make-temp-file "soql"))
         (async-debug t)
         (process (progn (write-region full-body nil file-temp)
                         (async-get (dx-data--execute-query `("query" "-f" ,file-temp
                                                              "-o" ,(ob-soql--get-param :org processed-params)
                                                              "--result-format=csv")
                                                            :sync t))))
         (result (with-current-buffer (process-buffer process)
                   (unless (string-blank-p (buffer-string))
                     (org-table-convert-region (point-min) (point-max))
                     (buffer-string)))))

    (concat result)))

(defun ob-soql--get-param (key param-list)
  "Extract param in list."
  (cdr (assq key param-list)))

(defun ob-soql--binding-declare-variable (soql pair)
  "Handle binding value of variable to execute content."
  (cl-loop for (key . value) in pair
           do (setq soql (string-replace (format ":%s" key) (format "%s" value) soql))
           finally return soql))

(defun org-babel-prep-session:soql (session params)
  "Prepare SESSION according to the header arguments specified in PARAMS.")

(defun org-babel-elisp-var-to-soql (var)
  "Convert an elisp var into a string of template source code
specifying a var of the same value."
  (format "%s" value))

(defun org-babel-template-initiate-session (&optional session)
  "If there is not a current inferior-process-buffer in SESSION then create.
Return the initialized session."
  (unless (string= session "none")))

(provide 'ob-soql)
