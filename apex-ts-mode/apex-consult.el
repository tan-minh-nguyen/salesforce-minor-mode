;;; apex-consult --- integrate apex to consult -*- lexical-binding: t -*-

(require 'salesforce-consult)

(defcustom apex--consult-icon-field ""
  "Nerd icon for field consult source."
  :group 'apex-consult
  :type 'string)

(defcustom apex--consult-icon-method ""
  "Nerd icon for method consult source."
  :group 'apex-consult
  :type 'string)

(defcustom apex--consult-icon-class ""
  "Nerd icon for class consult source."
  :group 'apex-consult
  :type 'string)

(defcustom apex--consult-icon-sobject ""
  "Nerd icon for sobject consult source."
  :group 'apex-consult
  :type 'string)

(salesforce-consult--define-source "apex" :name "Field"
                                   :narrow ?p
                                   :category 'Field
                                   :face 'font-lock-variable-name-face
                                   :items (lambda ()
                                            (salesforce-consult--search-candidates "p" "\\`field_declaration\\'" apex--consult-icon-field nil #'apex-ts-mode--variable-name)))

(salesforce-consult--define-source "apex" :name "Method"
                                   :narrow ?f
                                   :category 'Method
                                   :face 'font-lock-function-name-face
                                   :items (lambda ()
                                            (salesforce-consult--search-candidates "f" "\\`method_declaration\\'" apex--consult-icon-method)))

(salesforce-consult--define-source "apex" :name "Class"
                                   :narrow ?c
                                   :category 'Class
                                   :face 'font-lock-type-face
                                   :items (lambda ()
                                            (salesforce-consult--search-candidates "c" "\\`class_declaration\\'" apex--consult-icon-class nil #'apex-ts-mode--declaration-name)))

(salesforce-consult--define-source "apex" :name "Sobject"
                                   :narrow ?s
                                   :category 'o
                                   :face 'font-lock-type-face
                                   :items (lambda ()
                                            (salesforce-consult--search-candidates "o" "\\`storage_identifier\\'" apex--consult-icon-sobject nil #'(lambda (NODE)
                                                                                                                                                     (treesit-node-text NODE)))))
;; (apex--consult-define-source :name "Enum"
;;                              :narrow ?e
;;                              :category 'v
;;                              :face 'font-lock-constant-face
;;                              :items (lambda ()
;;                                       (apex--consult-search-candidates '("c" "\\`enum_declaration\\'" nil apex-ts-mode--declaration-name))))

(salesforce-consult-make-multi-imenu "apex"
                                     apex--consult-field-source
                                     apex--consult-method-source
                                     apex--consult-class-source
                                     apex--consult-sobject-source)

(provide 'apex-consult)
