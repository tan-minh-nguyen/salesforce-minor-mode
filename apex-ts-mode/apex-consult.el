;;; apex-consult.el --- Integrate apex to consult -*- lexical-binding: t -*-

;; Copyright (C) 2025 Tan Nguyen

;; Author: Tan Nguyen <tan.nguyen.w.information@gmail.com>
;; Version: 0.1
;; Package-Requires: ((emacs "27.1"))
;; Keywords: salesforce, apex, consult
;; URL: https://github.com/your/repo

;;; Commentary:
;; This package provides consult integration for Apex mode,
;; enabling quick navigation through Apex code structures.

;;; Code:

(require 'salesforce-core)

(defcustom apex--consult-icon-field (nerd-icons-codicon "nf-cod-symbol_variable")
  "Nerd icon for field consult source."
  :group 'apex-consult
  :type 'string)

(defcustom apex--consult-icon-method (nerd-icons-codicon "nf-cod-symbol_method")
  "Nerd icon for method consult source."
  :group 'apex-consult
  :type 'string)

(defcustom apex--consult-icon-class (nerd-icons-codicon "nf-cod-symbol_method")
  "Nerd icon for class consult source."
  :group 'apex-consult
  :type 'string)

(defcustom apex--consult-icon-sobject (nerd-icons-codicon "nf-cod-symbol_field")
  "Nerd icon for sobject consult source."
  :group 'apex-consult
  :type 'string)

(defcustom apex--consult-icon-enum (nerd-icons-codicon "nf-cod-symbol_enum")
  "Nerd icon for enum consult source."
  :group 'apex-consult
  :type 'string)

(salesforce-consult--define-source "apex" :name "Field"
  :narrow ?p
  :category 'Field
  :face 'font-lock-variable-name-face
  :action salesforce-consult--imenu-action
  :state salesforce-consult--imenu-state
  :annotate salesforce-consult--imenu-annotate
  :items
  (lambda ()
    (salesforce-consult--search-candidates "p" "\\`field_declaration\\'" apex--consult-icon-field nil #'apex-ts-mode--variable-name)))

(salesforce-consult--define-source "apex" :name "Method"
  :narrow ?f
  :category 'Method
  :face 'font-lock-function-name-face
  :action salesforce-consult--imenu-action
  :state salesforce-consult--imenu-state
  :annotate salesforce-consult--imenu-annotate
  :items
  (lambda ()
    (salesforce-consult--search-candidates "f" "\\`method_declaration\\'" apex--consult-icon-method nil #'apex-ts-mode--method-name)))

(salesforce-consult--define-source "apex" :name "Class"
  :narrow ?c
  :category 'Class
  :face 'font-lock-type-face
  :action salesforce-consult--imenu-action
  :state salesforce-consult--imenu-state
  :annotate salesforce-consult--imenu-annotate
  :items
  (lambda ()
    (salesforce-consult--search-candidates "c" "\\`class_declaration\\'" apex--consult-icon-class nil #'apex-ts-mode--declaration-name)))

(salesforce-consult--define-source "apex" :name "Sobject"
  :narrow ?s
  :category 'SObject
  :face 'font-lock-type-face
  :action salesforce-consult--imenu-action
  :state salesforce-consult--imenu-state
  :annotate salesforce-consult--imenu-annotate
  :items
  (lambda ()
    (salesforce-consult--search-candidates "o" "\\`storage_identifier\\'" apex--consult-icon-sobject nil #'(lambda (NODE)
                                                                                                             (treesit-node-text NODE)))))
(salesforce-consult--define-source "apex" :name "Enum"
  :narrow ?e
  :category 'Enum
  :face 'font-lock-constant-face
  :action salesforce-consult--imenu-action
  :state salesforce-consult--imenu-state
  :annotate salesforce-consult--imenu-annotate
  :items
  (lambda ()
    (salesforce-consult--search-candidates "c" "\\`enum_declaration\\'" apex--consult-icon-field nil #'apex-ts-mode--enum-name)))

(salesforce-consult-make-multi-imenu "apex"
                                     apex--consult-field-source
                                     apex--consult-method-source
                                     apex--consult-class-source
                                     apex--consult-sobject-source
                                     apex--consult-enum-source)

(provide 'apex-consult)

;;; apex-consult.el ends here
