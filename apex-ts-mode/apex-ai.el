;;; apex-ai.el --- integration apex-ts-mode to AI -*- lexical-binding: t -*-

(defcustom apex-ai-comment-instruction '(
                                         :instruction "instruction for class:
 /*
*********************************************************
* Apex Class Name    : {class name}.cls
* Created Date       : {replace with today}
* @description       : {short description}
* @author            : {author name}
* @group             : 
* @group-content	   : 
* Modification Log:
* Ver   Date         Author                               Modification
*********************************************************
*/
\n\n
instruction for method:
/*
*********************************************************
* @Method Name    : {method name}
* @author         : {author name}
* @description    : {short description}
* @param          : {all parameters of method}
* @return         : {return value}
********************************************************
*/
instruction for indentation: following indentation property in prompt to apply indent for each comment
\n\n
output JSON format follow below contructs: [{\"name\": \"{replace as class name or method name}\", \"comment\": \"{replace as comment context}\", \"position\": {replace with position in prompt}}] 
\n\n"
                                         :queries ((class . apex-ai-query-class)
                                                   (method . apex-ai-query-method)))
  "Comment Instruction for apex."
  :type '(or listp functionp)
  :group 'apex-ai)

(defun apex-ai-query-method ()
  "Build prompt for methods want to comment."
  (let* ((nodes (treesit-query-capture (treesit-buffer-root-node)
                                       '((method_declaration) @method)))
         (prompt (cl-loop for (_ . node) in nodes
                          concat (format
                                  "Name: %s\nType: %s\nParameters: %s\nPosition: %s\nIndentation: %s\n\n"
                                  (treesit-node-text (treesit-node-child-by-field-name node "name") t)
                                  (treesit-node-text (treesit-node-child-by-field-name node "type") t)
                                  (apex-ai-remove-break-lines
                                   (treesit-node-text
                                    (treesit-node-child-by-field-name node "parameters") t))
                                  (treesit-node-start node)
                                  (save-excursion (goto-char (treesit-node-start node))
                                                  (current-column))))))
    `(:prompt ,prompt)))

(defun apex-ai-query-class ()
  "Build prompt for classes want to comment."
  (let* ((nodes (treesit-query-capture (treesit-buffer-root-node)
                                       '((class_declaration) @class)))
         (prompt (cl-loop for (_ . node) in nodes
                          concat (format
                                  "Name: %s\nPosition: %s\nIndentation: %s\n\n"
                                  (treesit-node-text (treesit-node-child-by-field-name node "name") t)
                                  (treesit-node-start node)
                                  (save-excursion (goto-char (treesit-node-start node))
                                                  (current-column))))))
    `(:prompt ,prompt)))

(defun apex-ai-remove-break-lines (text)
  "Remove break lines in text."
  (s-replace-regexp "\n" "" text))

(provide 'apex-ai)
