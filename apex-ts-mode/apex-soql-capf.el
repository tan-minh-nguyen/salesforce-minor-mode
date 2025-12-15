;;; apex-soql-capf.el --- SOQL completion in Apex via CAPF -*- lexical-binding: t; -*-

;;; Commentary:
;; Provides SOQL/SOSL completion within Apex code.
;; Works with Eglot by being added to completion-at-point-functions BEFORE Eglot.
;; When in SOQL context, delegates to soql-capf.
;; When in Apex context, returns nil to let Eglot handle completion.

;;; Code:

(require 'apex-completion-context)
(require 'soql-completion nil t)

(defun apex-soql-capf ()
  "Completion-at-point function for SOQL/SOSL within Apex.
Returns nil when not in SOQL context, allowing Eglot to handle Apex completion."
  (let ((context (apex-completion--current-context)))
    (pcase context
      ((or 'soql 'sosl)
       ;; In SOQL/SOSL context - delegate to soql-capf
       (when (and (require 'soql-capf nil t)
                  (fboundp 'soql-capf))
         (soql-capf)))
      
      ('apex
       ;; In Apex context - return nil to let Eglot handle it
       nil))))

(defun apex-soql-capf-setup ()
  "Setup SOQL completion in Apex mode.
Adds apex-soql-capf BEFORE eglot-completion-at-point in the hook list."
  ;; Add at the beginning with negative depth so it runs before Eglot
  (add-hook 'completion-at-point-functions #'apex-soql-capf -10 t))

(provide 'apex-soql-capf)

;;; apex-soql-capf.el ends here
