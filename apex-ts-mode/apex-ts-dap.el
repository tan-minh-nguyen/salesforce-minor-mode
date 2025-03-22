;;; apex-ts-dap.el --- configuration Debug adapter protocol for Apex mode -*- lexical-binding: t -*-

(require 'dape)

(defcustom apex-ts-dap-replay-debugger-server ""
  "Path to replay debugger server for Apex mode."
  :type 'string
  :group 'apex-ts-dap)

(defvar apex-ts-dap-log-file ""
  "Path to log directory for Apex mode.")

;;;###autoload
(defun apex-ts-dap-start-replay-debugger ()
  "Start Replay Debugger for Apex mode."
  (interactive)
  (setq apex-ts-dap-log-file (read-file-name "File:"))
  (call-interactively #'dape))

;; Configuration replay-debugger for Apex mode
(defun apex-ts-dap-initialize ()
  "Initialize Apex Replay Debugger server."
  (add-to-list 'dape-configs `(apex-replay modes (apex-ts-mode)
                                           command "node"
                                           command-args `(,(expand-file-name apex-ts-dap-replay-debugger-server) "--stdout")
                                           :type "apex-replay"
                                           :request "launch"
                                           :logFile apex-ts-dap-log-file
                                           :projectPath "."
                                           :stopOnEntry t
                                           :trace t
                                           :languages ["apex"]
                                           :lineBreakpointInfo [])))

(provide 'apex-ts-dap)
;;; apex-ts-dap.el ends here
