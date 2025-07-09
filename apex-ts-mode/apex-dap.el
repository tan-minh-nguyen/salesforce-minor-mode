;;; apex-dap.el --- configuration Debug adapter protocol for Apex mode -*- lexical-binding: t -*-

(require 'dape)

(defcustom apex-dap-replay-debugger-server ""
  "Path to replay debugger server for Apex mode."
  :type 'string
  :group 'apex-dap)

(defvar-local apex-dap-log-file nil
  "Path to log file.")

(defvar-local apex-dap-workspace nil
  "Path to workspace directory for replay debug.")

;;;###autoload
(defun apex-dap-start-replay-debugger ()
  "Start Replay Debugger for Apex mode."
  (interactive)
  (setq-local apex-dap-log-file (read-file-name "File:")
              apex-dap-workspace (projectile-project-root))
  (call-interactively #'dape))

;; Configuration replay-debugger for Apex mode
(defun apex-dap-initialize ()
  "Initialize Apex Replay Debugger server."
  (add-to-list 'dape-configs `(apex-replay modes (apex-ts-mode)
                                           command "node"
                                           command-args `(,(expand-file-name apex-ts-dap-replay-debugger-server) "--stdout")
                                           :type "apex-replay"
                                           :request "launch"
                                           :logFile apex-dap-log-file
                                           :projectPath apex-dap-workspace
                                           :stopOnEntry t
                                           :trace t
                                           :languages ["apex"]
                                           :lineBreakpointInfo [])))

(with-eval-after-load 'dape
  (apex-dap-initialize)
  (define-key sflog-ts-mode-map "M-d" #'apex-dap-start-replay-debugger))

(provide 'apex-dap)
;;; apex-dap.el ends here
