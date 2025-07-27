;;; apex-fold.el --- Add fold support for Apex -*- lexical-binding: t -*-

(when (featurep 'treesit-fold)
  (add-to-list 'treesit-fold-range-alist  '(apex-ts-mode (block . ts-fold-range-seq)
                                                         ;;(switch_block . ts-fold-range-seq)
                                                         (interface_body . ts-fold-range-seq)
                                                         (class_body . ts-fold-range-seq)
                                                         (constructor_body . ts-fold-range-seq)
                                                         (map_initializer . ts-fold-range-seq)
                                                         (line_comment . ts-fold-range-seq)
                                                         (block_comment . ts-fold-range-seq)
                                                         (array_creation_expression . ts-fold-range-seq))))

(provide 'apex-fold)
