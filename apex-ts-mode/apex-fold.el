;;; apex-fold.el --- Add fold support for Apex -*- lexical-binding: t -*-

(with-eval-after-load 'treesit-fold
  (add-to-list 'treesit-fold-range-alist  '(apex-ts-mode . ((class_body . treesit-fold-range-seq)
                                                            (array_initializer . treesit-fold-range-seq)
                                                            (map_initializer . treesit-fold-range-seq)
                                                            (soql_query_body . treesit-fold-range-seq)
                                                            (switch_block . treesit-fold-range-seq)
                                                            (argument_list . treesit-fold-range-seq)
                                                            (class_body . treesit-fold-range-seq)
                                                            (block . treesit-fold-range-seq)
                                                            (block_comment . treesit-fold-range-block-comment)
                                                            (line_comment . treesit-fold-range-c-like-comment)))))
                                                         
(provide 'apex-fold)
