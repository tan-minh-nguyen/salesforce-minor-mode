;; -*- no-byte-compile: t; no-native-compile: t; lexical-binding: t -*-

(require 'ctable)

;;; Customization
(defgroup salesforce-table nil
  "Salesforce data table."
  :group 'salesforce-mode)

(defclass salesforce-table ()
  ((columns :initarg :columns
            :type (repeat plist)
            :documentation "Columns of table")
   (data :initarg :data
         :type (repeat list)
         :documentation "Data of table"))
  :abstract t
  :custom-groups 'salesforce-table
  :documentation "Salesforce table abstract all render action should extended from this.")

(defclass salesforce-ctable (salesforce-table)
  ((show-index
    :initarg :show-index
    :type symbol
    :initform nil
    :documentation "Whether to show the index column in the ctable rendering.")

   (height
    :initarg :height
    :type number
    :documentation "Height of the ctable rendering.")

   (width
    :initarg :width
    :type number
    :documentation "Width of the ctable rendering.")

   (buffer
    :initarg :buffer
    :custom string
    :type string
    :documentation "Internal buffer holding rendered ctable data."))
  :documentation "Class to render Salesforce data using the ctable framework.")

(cl-defmethod salesforce-table-json-to-data-table ((this salesforce-ctable))
  "Convert JSON data to a ctable-based buffer display.

Uses slots:
  - columns: list of plist parameters for make-ctbl:cmodel
  - data: JSON array (vector) where keys correspond to column :title values
  - show-index: boolean, whether to show index column
  - width: ctable width
  - height: ctable height
  - buffer: name of the target buffer"
  (with-slots (columns data show-index width height buffer) this
    (let* ((headers (mapcar (lambda (col) (plist-get col :title)) columns))
           (column-models
            (append
             (when show-index
               (list (make-ctbl:cmodel :title "" :align 'right)))
             (mapcar (lambda (col)
                       (apply #'make-ctbl:cmodel col))
                     columns)))

           (table-data
            (cl-loop for item across data
                     for index from 1
                     for row = (mapcar (lambda (header)
                                       (plist-get item (intern (concat ":" header))))
                                     headers)
                     collect (if show-index
                                 (cons index row)
                               row)))

           (model (make-ctbl:model
                   :column-model column-models
                   :data table-data)))
      
      (pop-to-buffer
       (ctbl:create-table-component-buffer
        :model model
        :width width
        :height height
        :buffer buffer)))))

(provide 'salesforce-table)
