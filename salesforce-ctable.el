;; -*- no-byte-compile: t; no-native-compile: t; lexical-binding: t -*-

(require 'ctable)

(cl-defun salesforce-table--create-table (&key model buffer open)
  "use ctable to build table data"
  (let ((component (ctbl:create-table-component-buffer
                    :model model
                    :buffer (get-buffer-create buffer))))
    (if open
      (ctbl:cp-get-buffer component)
     component)))

(cl-defun salesforce-table--make-table-mode (&key column-header data)
  "use ctable to build table data"
  (let ((column-model
         (mapcar 'salesforce-table--make-header-model column-header))
        (async-model
         (ctbl:async-model-wrapper data)))

   (make-ctbl:model
    :column-model column-model :data async-model)))

(defun salesforce-table--make-header-model (header-config)
  "build header ctable"
  (let* ((title
          (plist-get header-config :title))
         (min-width
          (plist-get header-config :min-width))
         (max-width
          (plist-get header-config :max-width))
         (align
          (plist-get header-config :align)))

    (make-ctbl:cmodel
     :title title
     :sorter 'ctbl:sort-number-lessp
     :min-width min-width
     :max-width max-width
     :align align)))

(cl-defun salesforce-table--make-data-table-from-vector
    (&key header-columns data (enable-count-rows t))
  "build data from input hash table and header-columns"
  (let ((data-table ()))
    (cl-loop for item in data
             for col in header-columns
             collect `())
    (dotimes (i (length data))
      (let ((row (append (list (+ i 1))
                         (mapcar `(lambda (key)
                                    (let ((value (gethash key ,(aref data i))))

                                      (if (hash-table-p value)
                                          (gethash "url" value)
                                        (cond ((eq value ':null)
                                               "")
                                              ((eq value ':false)
                                               "False")
                                              ((eq value 't)
                                               "True")
                                              (t
                                               value)))))

                                 header-columns))))
        (add-to-list 'data-table row 1 '(lambda (v1 v2)
                                             nil))))
    data-table))

(provide 'salesforce-ctable)
