;;; dap.el   -*- lexical-binding: t -*-

;; Copyright (C) 2021  Jean-Philippe Bernardy
;; Copyright (C) 2020  Omar Antolín Camarena

(require 'dash)
(require 'ffap) ; used it to recognize file and url targets

(defmacro dap-define-keymap (name doc &rest bindings)
  "Define keymap variable NAME.
DOC is the documentation string.
BINDINGS is the list of bindings."
  (declare (indent 1))
  (let* ((parent (if (eq :parent (car bindings)) (cadr bindings)))
         (bindings (if parent (cddr bindings) bindings)))
    `(defvar ,name
       (let ((map (make-sparse-keymap)))
         ,@(mapcar (pcase-lambda (`(,key ,fn))
                     `(define-key map ,key ,(if (symbolp fn) `#',fn fn)))
                   bindings)
         (set-keymap-parent map ,parent)
         map)
       ,doc)))

(defun dap-make-sticky (&rest commands)
  (dolist (cmd commands) (put cmd 'dap-sticky t)))

(dap-define-keymap dap-region-map
  "Actions on the active region."
  ("u" upcase-region)
  ("l" downcase-region)
  ("c" capitalize-region)
  ("|" shell-command-on-region)
  ("e" eval-region)
  ("i" indent-rigidly)
  ((kbd "TAB") indent-region)
  ("f" fill-region)
  ("p" fill-region-as-paragraph)
  ("r" rot13-region)
  ("=" count-words-region)
  ("s" whitespace-cleanup-region)
  ("o" org-table-convert-region)
  (";" comment-or-uncomment-region)
  ("w" write-region)
  ("m" apply-macro-to-region-lines)
  ("N" narrow-to-region))

(defun dap-region-target ()
  (when (use-region-p) (cons dap-region-map 'dap-no-arg)))

(dap-define-keymap dap-xref-identifier-map
  "Actions for xref identifiers"
  ([return] xref-find-definitions)
  ([backspace] xref-find-references))

(defun dap-target-identifier ()
  "Identify Xref identifier"
  (when (derived-mode-p 'prog-mode)
    (when-let* ((backend (xref-find-backend))
                (def (xref-backend-identifier-at-point backend)))
      (cons 'dap-xref-identifier-map def))))

(dap-define-keymap dap-url-map
  "Actions for url"
  ([return] org-open-link-from-string))

(defun dap-target-url ()
  "Target the URL at point."
  (when-let ((url (thing-at-point 'url)))
    (cons 'dap-url-map url)))

(dap-define-keymap dap-org-link-map
  "Keymap for Dap org link actions."
  ([return] org-open-link-from-string))

(defun dap-target-org-link ()
  (when (and (eq major-mode 'org-mode)
             (org-in-regexp org-any-link-re))
    (cons 'dap-org-link-map (match-string-no-properties 0))))

(dap-define-keymap dap-flymake-diagnostics-map
  "Keymap for Dap flymake diagnostics actions."
  ([return] attrap-flymake-diags)
  ("a" flymake-show-diagnostics-buffer))

(defun dap-target-flymake-diagnostics ()
  "Identify flymake diagnostics"
  (when-let* ((diags (flymake-diagnostics (point))))
    (cons 'dap-flymake-diagnostics-map diags)))

(dap-define-keymap dap-symbol-map
  "Actions for symbols"
  ("i" info-lookup-symbol))

(defun dap-target-symbol ()
  "Identify symbol"
  (when (derived-mode-p 'prog-mode)
    (cons 'dap-symbol-map (thing-at-point 'symbol))))

(dap-define-keymap dap-command-map
  "Actions for commands"
  ("k" where-is)
  ("I" Info-goto-emacs-command-node))

(defun dap-target-command ()
  "Identify command"
  (when-let* ((name (thing-at-point 'symbol))
              (sym (intern-soft name)))
    (when (commandp sym)
        (cons 'dap-command-map sym))))

(dap-define-keymap dap-face-map
  "Actions for faces"
  ("f" describe-face)
  ("c" customize-face))

(defun dap-target-face ()
  "Identify a face target"
  (when-let* ((name (thing-at-point 'symbol))
              (sym (intern-soft name)))
    (when (facep sym)
        (cons 'dap-face-map sym))))

(dap-define-keymap dap-function-map
  "Actions for functions"
  ("f" describe-function))

(defun dap-target-function ()
  "Identify a function target"
  (when-let* ((name (thing-at-point 'symbol))
              (sym (intern-soft name)))
    (when (functionp sym)
        (cons 'dap-function-map sym))))

(dap-define-keymap dap-variable-map
  "Actions for variables"
  ("v" describe-variable)
  ("e" symbol-value))

(defun dap-target-variable ()
  "Identify a variable target"
  (when-let* ((name (thing-at-point 'symbol))
              (sym (intern-soft name)))
    (when (boundp sym)
        (cons 'dap-variable-map sym))))

(dap-define-keymap dap-org-timestamp-map
  "Actions for timestamps"
  ([return] org-time-stamp)
  ("+" org-timestamp-up)
  ("=" org-timestamp-up)
  ("-" org-timestamp-down))

(dap-make-sticky 'org-timestamp-down 'org-timestamp-up)

(defun dap-target-org-timestamp ()
  "Identify a timestamp target"
    (when (and (fboundp 'org-at-timestamp-p) (org-at-timestamp-p 'lax))
        (cons 'dap-org-timestamp-map 'dap-no-arg)))

(dap-define-keymap dap-org-table-map
  "Actions for org tables"
  ("c" org-table-insert-column)
  ("C" org-table-delete-column)
  ("r" org-table-insert-row)
  ("R" org-table-kill-row)
  ("h" org-table-insert-hline)
  ([right] org-table-move-column-right)
  ([left] org-table-move-column-left)
  ([up] org-table-move-row-up)
  ([down] org-table-move-row-down))

(dap-make-sticky
 'org-table-move-row-down
 'org-table-move-row-up
 'org-table-move-column-left
 'org-table-move-column-right)

(defun dap-org-table-target ()
  "Identify an org-table target"
    (when (and (fboundp 'org-at-table-p) (org-at-table-p))
        (cons 'dap-org-table-map 'dap-no-arg)))

(dap-define-keymap dap-outline-heading-map
  "Actions for timestamps"
  ([return] org-show-subtree)
  ("<" org-promote-subtree)
  (">" org-demote-subtree)
  ("n" outline-forward-same-level)
  ("p" outline-backward-same-level)
  ([up] org-move-subtree-up)
  ([down] org-move-subtree-down)
  ("x" org-cut-subtree)
  ("c" org-copy-subtree)
  ("N" org-narrow-to-subtree)
  ("t" org-todo))

(defun dap-outline-heading-target ()
  "Identify a timestamp target"
    (when (and (derived-mode-p 'outline)
               (fboundp 'outline-on-heading-p) (outline-on-heading-p))
        (cons 'dap-outline-heading-map 'dap-no-arg)))

(defcustom dap-targets
  '(dap-target-flymake-diagnostics
    dap-target-org-link
    dap-target-url
    dap-target-command
    dap-target-face
    dap-target-function
    dap-target-variable
    dap-target-org-timestamp
    dap-outline-heading-target
    dap-org-table-target
    dap-target-identifier
    dap-region-target)
  "List of functions to determine the target in current context.
Each function should take no argument and return either nil to
indicate it found no target or a cons of the form (map-symbol
. target) where map-symbol is a symbol whose value is a keymap
with relevant actions and target is an argument to pass to
functions bound in map-symbol."
  :type 'hook)


(defun dap-traverse-binding (fct binding)
  (cond ((keymapp binding) (dap-traverse-keymap fct binding))
        ((functionp binding) (funcall fct binding)) ; also accept functions, not just commands
        (t (cons (car binding) (dap-traverse-binding fct (cdr binding))))))

(defun dap-traverse-keymap- (fct map)
  "Apply FCT to every command bound in MAP, which is assumed to be in canonical form."
  (if (symbolp map) (dap-traverse-keymap fct (symbol-value map))
    (cons 'keymap (-map (apply-partially 'dap-traverse-binding fct) (cdr map)))))

(defun dap-traverse-keymap (fct map)
  "Apply FCT to every command bound in MAP"
  (assert (keymapp map))
  (dap-traverse-keymap- fct (keymap-canonicalize map)))

(defun dap-maps ()
  "Invoke all `dap-targets' and return the composed maps.
The result is a cons of a composition of the applicable maps in
the current context, applied to the target, and the same actions
not applied to targets."
  (let* ((type-target-pairs (-non-nil (--map (funcall it) dap-targets)))
         (map-target-pairs
          (-map (pcase-lambda (`(,type . ,target)) (cons (symbol-value type) target))
                type-target-pairs))
         (unapplied-map (make-composed-keymap (-map 'car map-target-pairs)))
         (maps (-map (pcase-lambda (`(,map . ,target))
                       (if (eq target 'dap-no-arg) map
                         (dap-traverse-keymap
                          (lambda (cmd)
                            (lambda () (interactive) (funcall cmd target)))
                          map)))
                     map-target-pairs)))
    (cons (make-composed-keymap maps) unapplied-map)))

(defcustom dap-prompter
  (lambda (map) (which-key--show-keymap "Action?" map nil nil 'no-paging))
  "Keymap prompter.
Function taking one keymap argument, called before prompting for
action. The keymap contains possible actions."
  :group 'dap
  :type 'symbol)

(defcustom dap-prompter-done 'which-key--hide-popup
  "Function to call to close the `dap-prompter'."
  :group 'dap
  :type 'symbol)


(defun dap-keep-pred ()
  "Should the transient map remain active?"
  (and (symbolp this-command) (get this-command 'dap-sticky)))

(defun dap-dap ()
  "Prompt for action on the thing at point.
Use `dap-targets' to configure what can be done and how."
  (interactive)
  (pcase-let ((`(,map . ,prompt) (dap-maps)))
    (funcall dap-prompter prompt)
    (set-transient-map map 'dap-keep-pred dap-prompter-done)))

(defun dap-default ()
  "Act on the thing at point.
Use `dap-targets' to configure what can be done. Like `dap-dap',
but (use [return])."
  (interactive)
  (pcase-let ((`(,map . ,_prompt) (dap-maps)))
    (funcall (lookup-key map [return]))))
