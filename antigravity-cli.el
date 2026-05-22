;;; antigravity-cli.el --- Antigravity CLI Emacs integration -*- lexical-binding: t; -*-

;; Author: Lin Chen<lc1990linux@gmail.com>
;; Version: 0.2.0
;; Package-Requires: ((emacs "30.0") (transient "0.9.3"))

;; URL: https://github.com/linchen2chris/antigravity-cli.el

;;; Commentary:
;; An Emacs interface to Antigravity CLI.  This package provides convenient
;; ways to interact with Antigravity from within Emacs, including sending
;; commands, toggling the Antigravity window, and accessing slash commands.

;;; Code:

(require 'transient)
(require 'project)
(require 'cl-lib)
(require 'popup)
(require 'projectile)

;;;; Customization options
(defgroup antigravity-cli nil
  "Antigravity AI interface for Emacs."
  :group 'tools)

(defgroup antigravity-cli-eat nil
  "Eat terminal backend specific settings for Antigravity CLI."
  :group 'antigravity-cli)

(defgroup antigravity-cli-vterm nil
  "Vterm terminal backend specific settings for Antigravity CLI."
  :group 'antigravity-cli)

(defgroup antigravity-cli-window nil
  "Window management settings for Antigravity CLI."
  :group 'antigravity-cli)

(defface antigravity-cli-repl-face
  nil
  "Face for Antigravity REPL."
  :group 'antigravity-cli)

(defcustom antigravity-cli-term-name "xterm-256color"
  "Terminal type to use for Antigravity REPL."
  :type 'string
  :group 'antigravity-cli)

(defcustom antigravity-cli-start-hook nil
  "Hook run after Antigravity is started."
  :type 'hook
  :group 'antigravity-cli)

(defcustom antigravity-cli-slash-commands
  '(
    "/about"
    "/auth"
    "/bug"
    ("/chat" "/chat list" "/chat save" "/chat resume")
    "/clear"
    "/compress"
    "/copy"
    "/docs"
    ("/directory" "/directory add" "/directory show")
    "/editor"
    "/extensions"
    "/help"
    "/ide"
    "/init"
    ("/mcp" "/mcp list" "/mcp auth" "/mcp refresh")
    ("/memory" "/memory show""/memory add" "/memory refresh")
    "/privacy"
    "/quit"
    ("/stats" "/stats model" "/stats tools")
    "/theme"
    "/tools"
    "/settings"
    "/vim"
    "/setup-github"
    "/terminal-setup")
  "List of slash commands available in Antigravity."
:type '(repeat (choice string (repeat string)))
:group 'antigravity-cli)

(defcustom antigravity-cli-startup-delay 0.1
  "Delay in seconds after starting Antigravity before displaying buffer.

This helps fix terminal layout issues that can occur if the buffer
is displayed before Antigravity is fully initialized."
  :type 'number
  :group 'antigravity-cli)

(defcustom antigravity-cli-large-buffer-threshold 100000
  "Size threshold in characters above which buffers are considered \"large\".

When sending a buffer to Antigravity with `antigravity-cli-send-region` and no
region is active, prompt for confirmation if buffer size exceeds this value."
  :type 'integer
  :group 'antigravity-cli)

(defcustom antigravity-cli-program "agy"
  "Program to run when starting Antigravity.
This is passed as the PROGRAM parameter to `eat-make`."
  :type 'string
  :group 'antigravity-cli)

(defcustom antigravity-cli-program-switches nil
  "List of command line switches to pass to the Antigravity program.
These are passed as SWITCHES parameters to `eat-make`."
  :type '(repeat string)
  :group 'antigravity-cli)

(defcustom antigravity-cli-newline-keybinding-style 'newline-on-shift-return
  "Key binding style for entering newlines and sending messages.

This controls how the return key and its modifiers behave in Antigravity
buffers:
- \\='newline-on-shift-return: S-return enters a line break, RET sends the
  command (default)
- \\='newline-on-alt-return: M-return enters a line break, RET sends the
  command
- \\='shift-return-to-send: RET enters a line break, S-return sends the
  command
- \\='super-return-to-send: RET enters a line break, s-return sends the
  command

`\"S\"' is the shift key.
`\"s\"' is the hyper key, which is the COMMAND key on macOS."
  :type '(choice (const :tag "Newline on shift-return (s-return for newline, RET to send)" newline-on-shift-return)
                 (const :tag "Newline on alt-return (M-return for newline, RET to send)" newline-on-alt-return)
                 (const :tag "Shift-return to send (RET for newline, S-return to send)" shift-return-to-send)
                 (const :tag "Super-return to send (RET for newline, s-return to send)" super-return-to-send))
  :group 'antigravity-cli)

(defcustom antigravity-cli-enable-notifications t
  "Whether to show notifications when Antigravity finishes and awaits input."
  :type 'boolean
  :group 'antigravity-cli)

(defcustom antigravity-cli-notification-function 'antigravity-cli-default-notification
  "Function to call for notifications.

The function is called with two arguments:
- TITLE: Title of the notification
- MESSAGE: Body of the notification

You can set this to your own custom notification function.
The default function displays a message and pulses the modeline
to provide visual feedback when Antigravity is ready for input."
  :type 'function
  :group 'antigravity-cli)

(defcustom antigravity-cli-confirm-kill t
  "Whether to ask for confirmation before killing Antigravity instances.

When non-nil, antigravity-cli-kill will prompt for confirmation.
When nil, Antigravity instances will be killed without confirmation."
  :type 'boolean
  :group 'antigravity-cli)

(defcustom antigravity-cli-optimize-window-resize t
  "Whether to optimize terminal window resizing to prevent unnecessary reflows.

When non-nil, terminal reflows are only triggered when the window width
changes, not when only the height changes. This prevents unnecessary
terminal redraws when windows are split or resized vertically, improving
performance and reducing visual artifacts.

Set to nil if you experience issues with terminal display after window
resizing."
  :type 'boolean
  :group 'antigravity-cli)

(defcustom antigravity-cli-no-delete-other-windows nil
  "Whether to prevent Antigravity CLI windows from being deleted.

When non-nil, antigravity-cli will have the `no-delete-other-windows'
parameter.  This parameter prevents the antigravity-cli window from
closing when calling `delete-other-windows' or any command that would
launch a new full-screen buffer."
  :type 'boolean
  :group 'antigravity-cli-window)

;;;;; Eat terminal customizations
;; Eat-specific terminal faces
(defface antigravity-cli-eat-prompt-annotation-running-face
  '((t :inherit eat-shell-prompt-annotation-running))
  "Face for running prompt annotations in Antigravity eat terminal."
  :group 'antigravity-cli-eat)

(defface antigravity-cli-eat-prompt-annotation-success-face
  '((t :inherit eat-shell-prompt-annotation-success))
  "Face for successful prompt annotations in Antigravity eat terminal."
  :group 'antigravity-cli-eat)

(defface antigravity-cli-eat-prompt-annotation-failure-face
  '((t :inherit eat-shell-prompt-annotation-failure))
  "Face for failed prompt annotations in Antigravity eat terminal."
  :group 'antigravity-cli-eat)

(defface antigravity-cli-eat-term-bold-face
  '((t :inherit eat-term-bold))
  "Face for bold text in Antigravity eat terminal."
  :group 'antigravity-cli-eat)

(defface antigravity-cli-eat-term-faint-face
  '((t :inherit eat-term-faint))
  "Face for faint text in Antigravity eat terminal."
  :group 'antigravity-cli-eat)

(defface antigravity-cli-eat-term-italic-face
  '((t :inherit eat-term-italic))
  "Face for italic text in Antigravity eat terminal."
  :group 'antigravity-cli-eat)

(defface antigravity-cli-eat-term-slow-blink-face
  '((t :inherit eat-term-slow-blink))
  "Face for slow blinking text in Antigravity eat terminal."
  :group 'antigravity-cli-eat)

(defface antigravity-cli-eat-term-fast-blink-face
  '((t :inherit eat-term-fast-blink))
  "Face for fast blinking text in Antigravity eat terminal."
  :group 'antigravity-cli-eat)

(dotimes (i 10)
  (let ((face-name (intern (format "antigravity-cli-eat-term-font-%d-face" i)))
        (eat-face (intern (format "eat-term-font-%d" i))))
    (eval `(defface ,face-name
             '((t :inherit ,eat-face))
             ,(format "Face for font %d in Antigravity eat terminal." i)
             :group 'antigravity-cli-eat))))

(defcustom antigravity-cli-eat-read-only-mode-cursor-type '(box nil nil)
  "Type of cursor to use as invisible cursor in Antigravity CLI terminal buffer.

The value is a list of form (CURSOR-ON BLINKING-FREQUENCY CURSOR-OFF).

When the cursor is on, CURSOR-ON is used as `cursor-type', which see.
BLINKING-FREQUENCY is the blinking frequency of cursor's blinking.
When the cursor is off, CURSOR-OFF is used as `cursor-type'.  This
should be nil when cursor is not blinking.

Valid cursor types for CURSOR-ON and CURSOR-OFF:
- t: Frame default cursor
- box: Filled box cursor
- (box . N): Box cursor with specified size N
- hollow: Hollow cursor
- bar: Vertical bar cursor
- (bar . N): Vertical bar with specified height N
- hbar: Horizontal bar cursor
- (hbar . N): Horizontal bar with specified width N
- nil: No cursor

BLINKING-FREQUENCY can be nil (no blinking) or a number."
  :type '(list
          (choice
           (const :tag "Frame default" t)
           (const :tag "Filled box" box)
           (cons :tag "Box with specified size" (const box) integer)
           (const :tag "Hollow cursor" hollow)
           (const :tag "Vertical bar" bar)
           (cons :tag "Vertical bar with specified height" (const bar)
                 integer)
           (const :tag "Horizontal bar" hbar)
           (cons :tag "Horizontal bar with specified width"
                 (const hbar) integer)
           (const :tag "None" nil))
          (choice
           (const :tag "No blinking" nil)
           (number :tag "Blinking frequency"))
          (choice
           (const :tag "Frame default" t)
           (const :tag "Filled box" box)
           (cons :tag "Box with specified size" (const box) integer)
           (const :tag "Hollow cursor" hollow)
           (const :tag "Vertical bar" bar)
           (cons :tag "Vertical bar with specified height" (const bar)
                 integer)
           (const :tag "Horizontal bar" hbar)
           (cons :tag "Horizontal bar with specified width"
                 (const hbar) integer)
           (const :tag "None" nil)))
  :group 'antigravity-cli-eat)

(defcustom antigravity-cli-eat-never-truncate-antigravity-buffer nil
  "When non-nil, disable truncation of Antigravity output buffer.

By default, Eat will truncate the terminal scrollback buffer when it
reaches a certain size.  This can cause Antigravity's output to be cut off
when dealing with large responses.  Setting this to non-nil disables
the scrollback size limit, allowing Antigravity to output unlimited content
without truncation.

Note: Disabling truncation may consume more memory for very large
outputs."
  :type 'boolean
  :group 'antigravity-cli-eat)

(make-obsolete-variable 'antigravity-cli-eat-never-truncate-antigravity-buffer
                        "Setting it to t can consume more memory for very large outputs and can cause performance issues with long Antigravity sessions"
                        "0.4.0")

;;;;; Vterm terminal customizations
(defcustom antigravity-cli-vterm-buffer-multiline-output t
  "Whether to buffer vterm output to prevent flickering on multi-line input.

When non-nil, vterm output that appears to be redrawing multi-line
input boxes will be buffered briefly and processed in a single
batch. This prevents the flickering that can occur when Antigravity redraws
its input box as it expands to multiple lines.

This only affects the vterm backend."
  :type 'boolean
  :group 'antigravity-cli-vterm)

(defcustom antigravity-cli-vterm-multiline-delay 0.01
  "Delay in seconds before processing buffered vterm output.

This controls how long vterm waits to collect output before processing
it when `antigravity-cli-vterm-buffer-multiline-output' is enabled.
The delay should be long enough to collect bursts of updates but short
enough to not be noticeable to the user.

The default value of 0.01 seconds (10ms) provides a good balance
between reducing flickering and maintaining responsiveness."
  :type 'number
  :group 'antigravity-cli-vterm)

;;;; Forward declrations for flycheck
(declare-function flycheck-overlay-errors-at "flycheck")
(declare-function flycheck-error-filename "flycheck")
(declare-function flycheck-error-line "flycheck")
(declare-function flycheck-error-message "flycheck")

;;;; Internal state variables
(defvar antigravity-cli--directory-buffer-map (make-hash-table :test 'equal)
  "Hash table mapping directories to user-selected Antigravity buffers.
Keys are directory paths, values are buffer objects.
This allows remembering which Antigravity instance the user selected
for each directory across multiple invocations.")

(defvar antigravity-cli--window-widths nil
  "Hash table mapping windows to their last known widths for eat terminals.")

(defvar-local antigravity-cli--vterm-last-output-time nil
  "Time of last output received from vterm process.")

(defvar-local antigravity-cli--vterm-resize-timer nil
  "Timer for applying deferred window resize to vterm.")

(defvar-local antigravity-cli--vterm-pending-resize nil
  "Pending resize dimensions (width . height) waiting to be sent to vterm.")

(defvar-local antigravity-cli--vterm-multiline-buffer-timer nil
  "Timer for processing buffered multi-line vterm output.")

;;;; Key bindings
;;;###autoload (autoload 'antigravity-cli-command-map "antigravity-cli")
(defvar antigravity-cli-command-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "/") 'antigravity-cli-slash-commands-popup)
    (define-key map (kbd "!") 'antigravity-cli-send-shell)
    (define-key map (kbd "a") 'antigravity-cli-add-context)
    (define-key map (kbd "b") 'antigravity-cli-switch-to-buffer)
    (define-key map (kbd "B") 'antigravity-cli-select-buffer)
    (define-key map (kbd "c") 'antigravity-cli)
    (define-key map (kbd "C") 'antigravity-cli-continue)
    (define-key map (kbd "RET") 'antigravity-cli-quick-response)
    (define-key map (kbd "R") 'antigravity-cli-resume)
    (define-key map (kbd "i") 'antigravity-cli-new-instance)
    (define-key map (kbd "d") 'antigravity-cli-start-in-directory)
    (define-key map (kbd "e") 'antigravity-cli-fix-error-at-point)
    (define-key map (kbd "E") 'antigravity-cli-esc)
    (define-key map (kbd "k") 'antigravity-cli-kill)
    (define-key map (kbd "K") 'antigravity-cli-kill-all)
    (define-key map (kbd "m") 'antigravity-cli-transient)
    (define-key map (kbd "ESC") 'antigravity-cli-esc)
    (define-key map [escape] 'antigravity-cli-esc)
    (define-key map (kbd "f") 'antigravity-cli-fork)
    (define-key map (kbd "r") 'antigravity-cli-send-region)
    (define-key map (kbd "s") 'antigravity-cli-send-command)
    (define-key map (kbd "t") 'antigravity-cli-toggle)
    (define-key map (kbd "x") 'antigravity-cli-send-command-with-context)
    (define-key map (kbd "y") 'antigravity-cli-send-return)
    (define-key map (kbd "z") 'antigravity-cli-toggle-read-only-mode)
    (define-key map (kbd "1") 'antigravity-cli-send-1)
    (define-key map (kbd "2") 'antigravity-cli-send-2)
    (define-key map (kbd "3") 'antigravity-cli-send-3)
    (define-key map (kbd "4") 'antigravity-cli-send-4)
    (define-key map (kbd "M") 'antigravity-cli-cycle-mode)
    (define-key map (kbd "o") 'antigravity-cli-send-buffer-file)
    map)
  "Keymap for Antigravity commands.")

;;;; Transient Menus
;;;###autoload (autoload 'antigravity-cli-transient "antigravity-cli" nil t)
(transient-define-prefix antigravity-cli-transient ()
  "Antigravity command menu."
  ["Antigravity Commands"
   ["Start/Stop Antigravity"
    ("c" "Start Antigravity" antigravity-cli)
    ("d" "Start in directory" antigravity-cli-start-in-directory)
    ("C" "Continue conversation" antigravity-cli-continue)
    ("R" "Resume session" antigravity-cli-resume)
    ("i" "New instance" antigravity-cli-new-instance)
    ("k" "Kill Antigravity" antigravity-cli-kill)
    ("K" "Kill all Antigravity instances" antigravity-cli-kill-all)
    ]
   ["Send Commands to Antigravity"
    ("s" "Send command" antigravity-cli-send-command)
    ("x" "Send command with context" antigravity-cli-send-command-with-context)
    ("r" "Send region or buffer" antigravity-cli-send-region)
    ("o" "Send buffer file" antigravity-cli-send-buffer-file)
    ("e" "Fix error at point" antigravity-cli-fix-error-at-point)
    ("E" "Send Escape (ESC)" antigravity-cli-esc)
    ("f" "Fork conversation" antigravity-cli-fork)
    ("/" "Slash Commands" antigravity-cli-slash-commands-popup)]
   ["Manage Antigravity"
    ("t" "Toggle antigravity window" antigravity-cli-toggle)
    ("b" "Switch to Antigravity buffer" antigravity-cli-switch-to-buffer)
    ("B" "Select from all Antigravity buffers" antigravity-cli-select-buffer)
    ("z" "Toggle read-only mode" antigravity-cli-toggle-read-only-mode)
    ("M" "Cycle Antigravity mode" antigravity-cli-cycle-mode :transient t)
    ]
   ["Quick Responses"
    ("1" "Send \"1\"" antigravity-cli-send-1)
    ("2" "Send \"2\"" antigravity-cli-send-2)
    ("3" "Send \"3\"" antigravity-cli-send-3)
    ("4" "Send \"4\"" antigravity-cli-send-4)
    ]])

;;;; add files to context
(defun antigravity-cli-add-context ()
  "Add FILE to Antigravity context."
        (interactive)
        (let ((file (projectile-completing-read "Add file to Antigravity: "
                                               (projectile-project-files (projectile-acquire-root)))))
        (antigravity-cli--do-send-command (concat "@" file))))

(defun antigravity-cli-quick-response ()
  "Send a quick response to Antigravity."
(interactive)
(let ((response (read-number "choose(1, 2, 3 or 4):" 1)))
(cond
 ((equal response 1)
  (antigravity-cli-send-1))
 ((equal response 2)
  (antigravity-cli-send-2))
 ((equal response 3)
  (antigravity-cli-send-3))
 ((equal response 4)
  (antigravity-cli-send-4))
 (t
  (message "Unknown response: %s" response)))))

;;;; Slash Commands with popup menu
(defun antigravity-cli-slash-commands-popup ()
  "Display the Antigravity slash commands menu."
  (interactive)
  (let ((slash-cmd (popup-cascade-menu  antigravity-cli-slash-commands)))
  (antigravity-cli--do-send-command slash-cmd)))

;;;; Terminal abstraction layer
;; This layer abstracts terminal operations to support multiple backends (eat, vterm, etc.)

(require 'cl-lib)

(defcustom antigravity-cli-terminal-backend 'eat
  "Terminal backend to use for Antigravity CLI.
Choose between \\='eat (default) and \\='vterm terminal emulators."
  :type '(radio (const :tag "Eat terminal emulator" eat)
                (const :tag "Vterm terminal emulator" vterm))
  :group 'antigravity-cli)

;;;;; Generic function definitions

(cl-defgeneric antigravity-cli--term-make (backend buffer-name program &optional switches)
  "Create a terminal using BACKEND in BUFFER-NAME running PROGRAM.
Optional SWITCHES are command-line arguments to PROGRAM.
Returns the buffer containing the terminal.")

(cl-defgeneric antigravity-cli--term-send-string (backend terminal string)
  "Send STRING to TERMINAL using BACKEND.")

(cl-defgeneric antigravity-cli--term-kill-process (backend buffer)
  "Kill the terminal process in BUFFER using BACKEND.")

(cl-defgeneric antigravity-cli--term-read-only-mode (backend)
  "Switch current terminal to read-only mode using BACKEND.")

(cl-defgeneric antigravity-cli--term-interactive-mode (backend)
  "Switch current terminal to interactive mode using BACKEND.")

(cl-defgeneric antigravity-cli--term-in-read-only-p (backend)
  "Check if current terminal is in read-only mode using BACKEND.")

(cl-defgeneric antigravity-cli--term-configure (backend)
  "Configure terminal in current buffer with BACKEND specific settings.")

(cl-defgeneric antigravity-cli--term-customize-faces (backend)
  "Apply face customizations for the terminal using BACKEND.")

(cl-defgeneric antigravity-cli--term-setup-keymap (backend)
  "Set up the local keymap for Antigravity CLI buffers using BACKEND.")

(cl-defgeneric antigravity-cli--term-get-adjust-process-window-size-fn (backend)
  "Get the BACKEND specific function that adjusts window size.")

;;;;; eat backend implementations

;; Declare external variables and functions from eat package
(defvar eat--semi-char-mode)
(defvar eat--synchronize-scroll-function)
(defvar eat-invisible-cursor-type)
(defvar eat-term-name)
(defvar eat-terminal)
(declare-function eat--adjust-process-window-size "eat" (&rest args))
(declare-function eat--set-cursor "eat" (terminal &rest args))
(declare-function eat-emacs-mode "eat")
(declare-function eat-kill-process "eat" (&optional buffer))
(declare-function eat-make "eat" (name program &optional startfile &rest switches))
(declare-function eat-semi-char-mode "eat")
(declare-function eat-term-display-beginning "eat" (terminal))
(declare-function eat-term-display-cursor "eat" (terminal))
(declare-function eat-term-live-p "eat" (terminal))
(declare-function eat-term-parameter "eat" (terminal parameter) t)
(declare-function eat-term-redisplay "eat" (terminal))
(declare-function eat-term-reset "eat" (terminal))
(declare-function eat-term-send-string "eat" (terminal string))

;; Helper to ensure eat is loaded
(defun antigravity-cli--ensure-eat ()
  "Ensure eat package is loaded."
  (unless (featurep 'eat)
    (unless (require 'eat nil t)
      (error "The eat package is required for eat terminal backend. Please install it"))))

(cl-defmethod antigravity-cli--term-make ((_backend (eql eat)) buffer-name program &optional switches)
  "Create an eat terminal for BACKEND.

_BACKEND is the terminal backend type (should be \\='eat).
BUFFER-NAME is the name for the new terminal buffer.
PROGRAM is the program to run in the terminal.
SWITCHES are optional command-line arguments for PROGRAM."
  (antigravity-cli--ensure-eat)

  (let* ((trimmed-buffer-name (string-trim-right (string-trim buffer-name "\\*") "\\*")))
    (apply #'eat-make trimmed-buffer-name program nil switches)))

(cl-defmethod antigravity-cli--term-send-string ((_backend (eql eat)) string)
  "Send STRING to eat terminal.

_BACKEND is the terminal backend type (should be \\='eat).
STRING is the text to send to the terminal."
  (eat-term-send-string eat-terminal string))

(cl-defmethod antigravity-cli--term-kill-process ((_backend (eql eat)) buffer)
  "Kill the eat terminal process in BUFFER.

_BACKEND is the terminal backend type (should be \\='eat).
BUFFER is the terminal buffer containing the process to kill."
  (with-current-buffer buffer
    (eat-kill-process)
    (kill-buffer buffer)))

(cl-defmethod antigravity-cli--term-read-only-mode ((_backend (eql eat)))
  "Switch eat terminal to read-only mode.

_BACKEND is the terminal backend type (should be \\'eat)."
  (antigravity-cli--ensure-eat)
  (eat-emacs-mode)
  (setq-local eat-invisible-cursor-type antigravity-cli-eat-read-only-mode-cursor-type)
  (eat--set-cursor nil :invisible))

(cl-defmethod antigravity-cli--term-interactive-mode ((_backend (eql eat)))
  "Switch eat terminal to interactive mode.

_BACKEND is the terminal backend type (should be \\='eat)."
  (antigravity-cli--ensure-eat)
  (eat-semi-char-mode)
  (setq-local eat-invisible-cursor-type nil)
  (eat--set-cursor nil :invisible))

(cl-defmethod antigravity-cli--term-in-read-only-p ((_backend (eql eat)))
  "Check if eat terminal is in read-only mode.

_BACKEND is the terminal backend type (should be \\='eat)."
  (not eat--semi-char-mode))

(defun antigravity-cli--eat-synchronize-scroll (windows)
  "Synchronize scrolling and point between terminal and WINDOWS.

WINDOWS is a list of windows.  WINDOWS may also contain the special
symbol `buffer', in which case the point of current buffer is set.

This custom version keeps the prompt at the bottom of the window when
possible, preventing the scrolling up issue when editing other buffers."
  (dolist (window windows)
    (if (eq window 'buffer)
        (goto-char (eat-term-display-cursor eat-terminal))
      ;; Don't move the cursor around when in eat-emacs-mode
      (when (not buffer-read-only)
        (let ((cursor-pos (eat-term-display-cursor eat-terminal)))
          ;; Always set point to cursor position
          (set-window-point window cursor-pos)
          ;; Try to keep cursor visible with minimal scrolling
          (cond
           ;; If cursor is at/near end, keep at bottom
           ((>= cursor-pos (- (point-max) 2))
            (with-selected-window window
              (goto-char cursor-pos)
              (recenter -1)))
           ;; If cursor not visible, scroll minimally to show it
           ((not (pos-visible-in-window-p cursor-pos window))
            (with-selected-window window
              (goto-char cursor-pos)
              ;; Center cursor in window instead of jumping to term beginning
              (recenter)))))))))

(cl-defmethod antigravity-cli--term-configure ((_backend (eql eat)))
  "Configure eat terminal in current buffer.

_BACKEND is the terminal backend type (should be \\='eat)."
  (antigravity-cli--ensure-eat)
  ;; Configure eat-specific settings
  (setq-local eat-term-name antigravity-cli-term-name)
  (setq-local eat-enable-directory-tracking nil)
  (setq-local eat-enable-shell-command-history nil)
  (setq-local eat-enable-shell-prompt-annotation nil)
  (when antigravity-cli-eat-never-truncate-antigravity-buffer
    (setq-local eat-term-scrollback-size nil))

  ;; Set up custom scroll function to stop eat from scrolling to the top
  (setq-local eat--synchronize-scroll-function #'antigravity-cli--eat-synchronize-scroll)

  ;; Configure bell handler - ensure eat-terminal exists
  (when (bound-and-true-p eat-terminal)
    (eval '(setf (eat-term-parameter eat-terminal 'ring-bell-function) #'antigravity-cli--notify)))

  ;; fix wonky initial terminal layout that happens sometimes if we show the buffer before antigravity is ready
  (sleep-for antigravity-cli-startup-delay))

(cl-defmethod antigravity-cli--term-customize-faces ((_backend (eql eat)))
  "Apply face customizations for eat terminal.

_BACKEND is the terminal backend type (should be \\='eat)."
  ;; Remap eat faces to Antigravity-specific faces
  (face-remap-add-relative 'eat-shell-prompt-annotation-running 'antigravity-cli-eat-prompt-annotation-running-face)
  (face-remap-add-relative 'eat-shell-prompt-annotation-success 'antigravity-cli-eat-prompt-annotation-success-face)
  (face-remap-add-relative 'eat-shell-prompt-annotation-failure 'antigravity-cli-eat-prompt-annotation-failure-face)
  (face-remap-add-relative 'eat-term-bold 'antigravity-cli-eat-term-bold-face)
  (face-remap-add-relative 'eat-term-faint 'antigravity-cli-eat-term-faint-face)
  (face-remap-add-relative 'eat-term-italic 'antigravity-cli-eat-term-italic-face)
  (face-remap-add-relative 'eat-term-slow-blink 'antigravity-cli-eat-term-slow-blink-face)
  (face-remap-add-relative 'eat-term-fast-blink 'antigravity-cli-eat-term-fast-blink-face)
  (dolist (i (number-sequence 0 9))
    (let ((eat-face (intern (format "eat-term-font-%d" i)))
          (antigravity-face (intern (format "antigravity-cli-eat-term-font-%d-face" i))))
      (face-remap-add-relative eat-face antigravity-face))))

(cl-defmethod antigravity-cli--term-setup-keymap ((_backend (eql eat)))
  "Set up the local keymap for Antigravity CLI buffers.

_BACKEND is the terminal backend type (should be \\='eat)."
  (let ((map (make-sparse-keymap)))
    ;; Inherit parent eat keymap
    (set-keymap-parent map (current-local-map))

    ;; C-g for escape
    (define-key map (kbd "C-g") #'antigravity-cli-send-escape)

    ;; Configure key bindings based on user preference
    (pcase antigravity-cli-newline-keybinding-style
      ('newline-on-shift-return
       ;; S-return enters a line break, RET sends the command
       (define-key map (kbd "<S-return>") #'antigravity-cli--eat-send-alt-return)
       (define-key map (kbd "<return>") #'antigravity-cli--eat-send-return))
      ('newline-on-alt-return
       ;; M-return enters a line break, RET sends the command
       (define-key map (kbd "<M-return>") #'antigravity-cli--eat-send-alt-return)
       (define-key map (kbd "<return>") #'antigravity-cli--eat-send-return))
      ('shift-return-to-send
       ;; RET enters a line break, S-return sends the command
       (define-key map (kbd "<return>") #'antigravity-cli--eat-send-alt-return)
       (define-key map (kbd "<S-return>") #'antigravity-cli--eat-send-return))
      ('super-return-to-send
       ;; RET enters a line break, s-return sends the command.
       (define-key map (kbd "<return>") #'antigravity-cli--eat-send-alt-return)
       (define-key map (kbd "<s-return>") #'antigravity-cli--eat-send-return)))
    (use-local-map map)))

(defun antigravity-cli--eat-send-alt-return ()
  "Send <alt>-<return> to eat."
  (interactive)
  (eat-term-send-string eat-terminal "\e\C-m"))

(defun antigravity-cli--eat-send-return ()
  "Send <return> to eat."
  (interactive)
  (eat-term-send-string eat-terminal (kbd "RET")))

(cl-defmethod antigravity-cli--term-get-adjust-process-window-size-fn ((_backend (eql eat)))
  "Get the BACKEND specific function that adjusts window size."
  #'eat--adjust-process-window-size)

;;;;; vterm backend implementations

;; Declare external variables and functions from vterm package
(defvar vterm-buffer-name)
(defvar vterm-copy-mode)
(defvar vterm-environment)
(defvar vterm-shell)
(defvar vterm-term-environment-variable)
(defvar vterm--term)
(declare-function vterm "vterm" (&optional buffer-name))
(declare-function vterm--window-adjust-process-window-size "vterm" (process window))
(declare-function vterm--set-size "vterm" (vterm-term rows cols))
(declare-function vterm-copy-mode "vterm" (&optional arg))
(declare-function vterm-mode "vterm")
(declare-function vterm-send-key "vterm" key &optional shift meta ctrl accept-proc-output)
(declare-function vterm-send-string "vterm" (string &optional paste-p))

;; Helper to ensure vterm is loaded
(cl-defmethod antigravity-cli--term-make ((_backend (eql vterm)) buffer-name program &optional switches)
  "Create a vterm terminal.

_BACKEND is the terminal backend type (should be \\='vterm).
BUFFER-NAME is the name for the new terminal buffer.
PROGRAM is the program to run in the terminal.
SWITCHES are optional command-line arguments for PROGRAM."
  (antigravity-cli--ensure-vterm)
  (let* ((vterm-shell (if switches
                          (concat program " " (mapconcat #'identity switches " "))
                        program))
         (buffer (get-buffer-create buffer-name)))
    (with-current-buffer buffer
      ;; vterm needs to have an open window before starting the antigravity
      ;; process; otherwise Antigravity doesn't seem to know how wide its
      ;; terminal window is and it draws the input box too wide. But
      ;; the user may not want to pop to the buffer. For some reason
      ;; `display-buffer' also leads to wonky results, it has to be
      ;; `pop-to-buffer'. So, show the buffer, start vterm-mode (which
      ;; starts the vterm-shell antigravity process), and then hide the
      ;; buffer. We'll optionally re-open it later.
      ;;
      ;; [TODO] see if there's a cleaner way to do this.
      (pop-to-buffer buffer)
      (vterm-mode)
      (delete-window (get-buffer-window buffer))
      buffer)))

(defun antigravity-cli--ensure-vterm ()
  "Ensure vterm package is loaded."
  (unless (featurep 'vterm)
    (unless (require 'vterm nil t)
      (error "The vterm package is required for vterm terminal backend. Please install it"))))

(cl-defmethod antigravity-cli--term-send-string ((_backend (eql vterm)) string)
  "Send STRING to vterm terminal.

_BACKEND is the terminal backend type (should be \\='vterm).
_TERMINAL is unused for vterm backend.
STRING is the text to send to the terminal."
  (vterm-send-string string))

(cl-defmethod antigravity-cli--term-kill-process ((_backend (eql vterm)) buffer)
  "Kill the vterm terminal process in BUFFER.

_BACKEND is the terminal backend type (should be \\='vterm).
BUFFER is the terminal buffer containing the process to kill."
  (kill-process (get-buffer-process buffer)))

;; Mode operations
(cl-defmethod antigravity-cli--term-read-only-mode ((_backend (eql vterm)))
  "Switch vterm terminal to read-only mode.

_BACKEND is the terminal backend type (should be \\='vterm)."
  (antigravity-cli--ensure-vterm)
  (vterm-copy-mode 1)
  (setq-local cursor-type t))

(cl-defmethod antigravity-cli--term-interactive-mode ((_backend (eql vterm)))
  "Switch vterm terminal to interactive mode.

_BACKEND is the terminal backend type (should be \\='vterm)."
  (antigravity-cli--ensure-vterm)
  (vterm-copy-mode -1)
  (setq-local cursor-type nil))

(cl-defmethod antigravity-cli--term-in-read-only-p ((_backend (eql vterm)))
  "Check if vterm terminal is in read-only mode.

_BACKEND is the terminal backend type (should be \\='vterm)."
  vterm-copy-mode)

(cl-defmethod antigravity-cli--term-configure ((_backend (eql vterm)))
  "Configure vterm terminal in current buffer.

_BACKEND is the terminal backend type (should be \\='vterm)."
  (antigravity-cli--ensure-vterm)
  ;; set TERM
  (setq vterm-term-environment-variable antigravity-cli-term-name)
  ;; Prevent vterm from automatically renaming the buffer
  (setq-local vterm-buffer-name-string nil)
  ;; Disable automatic scrolling to bottom on output to prevent flickering
  (setq-local vterm-scroll-to-bottom-on-output nil)
  ;; Disable immediate redraw to batch updates and reduce flickering
  (setq-local vterm--redraw-immididately nil)
  ;; Try to prevent cursor flickering by disabling Emacs' own cursor management
  (setq-local cursor-in-non-selected-windows nil)
  (setq-local blink-cursor-mode nil)
  (setq-local cursor-type nil)  ; Let vterm handle the cursor entirely
  ;; Set timer delay to nil for faster updates (reduces visible flicker duration)
  ;; (setq-local vterm-timer-delay nil)
  ;; Increase process read buffering to batch more updates together
  (when-let ((proc (get-buffer-process (current-buffer))))
    (set-process-query-on-exit-flag proc nil)
    ;; Try to make vterm read larger chunks at once
    (process-put proc 'read-output-max 4096))
  ;; Set up bell detection advice
  (advice-add 'vterm--filter :around #'antigravity-cli--vterm-bell-detector)
  ;; Set up multi-line buffering to prevent flickering
  (advice-add 'vterm--filter :around #'antigravity-cli--vterm-multiline-buffer-filter))

(cl-defmethod antigravity-cli--term-customize-faces ((_backend (eql vterm)))
  "Apply face customizations for vterm terminal.

_BACKEND is the terminal backend type (should be \\='vterm)."
  ;; no faces to customize yet (this could change)
  )

(defun antigravity-cli--vterm-send-escape ()
  "Send escape key to vterm."
  (interactive)
  (vterm-send-key "escape"))

(defun antigravity-cli--vterm-send-return ()
  "Send escape key to vterm."
  (interactive)
  (vterm-send-key "
"))

(defun antigravity-cli--vterm-send-alt-return ()
  "Send <alt>-<return> to vterm."
  (interactive)
  (vterm-send-key "
" nil t))

(defun antigravity-cli--vterm-send-shift-return ()
  "Send shift return to vterm."
  (interactive)
  (vterm-send-key "
" t))

(defun antigravity-cli--vterm-send-super-return ()
  "Send escape key to vterm."
  (interactive)
  ;; (vterm-send-key " " t)
  (vterm-send-key (kbd "s-<return>") t))

;; (defun antigravity-cli--vterm-send-alt-return ()
;;   "Send alt-return to vterm for newline without submitting."
;;   (message "antigravity-cli--vterm-send-alt-return invoked")
;;   (interactive)
;;   (vterm-send-key "" nil t))

(cl-defmethod antigravity-cli--term-setup-keymap ((_backend (eql vterm)))
  "Set up the local keymap for Antigravity CLI buffers.

_BACKEND is the terminal backend type (should be \\='vterm)."
  (let ((map (make-sparse-keymap)))
    ;; Inherit parent eat keymap
    (set-keymap-parent map (current-local-map))

    ;; C-g for escape
    (define-key map (kbd "C-g") #'antigravity-cli--vterm-send-escape)

    (pcase antigravity-cli-newline-keybinding-style
      ('newline-on-shift-return
       ;; S-return enters a line break, RET sends the command
       (define-key map (kbd "<S-return>") #'antigravity-cli--vterm-send-alt-return)
       (define-key map (kbd "<return>") #'antigravity-cli--vterm-send-return))
      ('newline-on-alt-return
       ;; M-return enters a line break, RET sends the command
       (define-key map (kbd "<M-return>") #'antigravity-cli--vterm-send-alt-return)
       (define-key map (kbd "<return>") #'antigravity-cli--vterm-send-return))
      ('shift-return-to-send
       ;; RET enters a line break, S-return sends the command
       (define-key map (kbd "<return>") #'antigravity-cli--vterm-send-alt-return)
       (define-key map (kbd "<S-return>") #'antigravity-cli--vterm-send-return))
      ('super-return-to-send
       ;; RET enters a line break, s-return sends the command.
       (define-key map (kbd "<return>") #'antigravity-cli--vterm-send-alt-return)
       (define-key map (kbd "<s-return>") #'antigravity-cli--vterm-send-return)))

    (use-local-map map)))

(cl-defmethod antigravity-cli--term-get-adjust-process-window-size-fn ((_backend (eql vterm)))
  "Get the BACKEND specific function that adjusts window size."
  #'vterm--window-adjust-process-window-size)

;;;; Private util functions
(defmacro antigravity-cli--with-buffer (&rest body)
  "Execute BODY with the Antigravity buffer, handling buffer selection and display.

Gets or prompts for the Antigravity buffer, executes BODY within that buffer's
context, displays the buffer, and shows not-running message if no buffer
is found."
  `(if-let ((antigravity-cli-buffer (antigravity-cli--get-or-prompt-for-buffer)))
       (with-current-buffer antigravity-cli-buffer
         ,@body
         (display-buffer antigravity-cli-buffer))
     (antigravity-cli--show-not-running-message)))

(defun antigravity-cli--buffer-p (buffer)
  "Return non-nil if BUFFER is a Antigravity buffer.

BUFFER can be either a buffer object or a buffer name string."
  (let ((name (if (stringp buffer)
                  buffer
                (buffer-name buffer))))
    (and name (string-match-p "^\\*antigravity:" name))))

(defun antigravity-cli--directory ()
  "Get get the root Antigravity directory for the current buffer.

If not in a project and no buffer file return `default-directory'."
  (let* ((project (project-current))
         (current-file (buffer-file-name)))
    (cond
     ;; Case 1: In a project
     (project (project-root project))
     ;; Case 2: Has buffer file (when not in VC repo)
     (current-file (file-name-directory current-file))
     ;; Case 3: No project and no buffer file
     (t default-directory))))

(defun antigravity-cli--find-all-antigravity-buffers ()
  "Find all active Antigravity buffers across all directories.

Returns a list of buffer objects."
  (cl-remove-if-not
   #'antigravity-cli--buffer-p
   (buffer-list)))

(defun antigravity-cli--find-antigravity-buffers-for-directory (directory)
  "Find all active Antigravity buffers for a specific DIRECTORY.

Returns a list of buffer objects."
  (cl-remove-if-not
   (lambda (buf)
     (let ((buf-dir (antigravity-cli--extract-directory-from-buffer-name (buffer-name buf))))
       (and buf-dir
            (string= (file-truename (abbreviate-file-name directory))
                     (file-truename buf-dir)))))
   (antigravity-cli--find-all-antigravity-buffers)))

(defun antigravity-cli--extract-directory-from-buffer-name (buffer-name)
  "Extract the directory path from a Antigravity BUFFER-NAME.

For example, *antigravity:/path/to/project/* returns /path/to/project/.
For example, *antigravity:/path/to/project/:tests* returns /path/to/project/."
  (when (string-match "^\\*antigravity:\\([^:]+\\)\\(?::\\([^*]+\\)\\)?\\*$" buffer-name)
    (match-string 1 buffer-name)))

(defun antigravity-cli--extract-instance-name-from-buffer-name (buffer-name)
  "Extract the instance name from a Antigravity BUFFER-NAME.

For example, *antigravity:/path/to/project/:tests* returns \"tests\".
For example, *antigravity:/path/to/project/* returns nil."
  (when (string-match "^\\*antigravity:\\([^:]+\\)\\(?::\\([^*]+\\)\\)?\\*$" buffer-name)
    (match-string 2 buffer-name)))

(defun antigravity-cli--buffer-display-name (buffer)
  "Create a display name for Antigravity BUFFER.

Returns a formatted string like `project:instance (directory)' or
`project (directory)'."
  (let* ((name (buffer-name buffer))
         (dir (antigravity-cli--extract-directory-from-buffer-name name))
         (instance-name (antigravity-cli--extract-instance-name-from-buffer-name name)))
    (if instance-name
        (format "%s:%s (%s)"
                (file-name-nondirectory (directory-file-name dir))
                instance-name
                dir)
      (format "%s (%s)"
              (file-name-nondirectory (directory-file-name dir))
              dir))))

(defun antigravity-cli--buffers-to-choices (buffers &optional simple-format)
  "Convert BUFFERS list to an alist of (display-name . buffer) pairs.

If SIMPLE-FORMAT is non-nil, use just the instance name as display name."
  (mapcar (lambda (buf)
            (let ((display-name (if simple-format
                                    (or (antigravity-cli--extract-instance-name-from-buffer-name
                                         (buffer-name buf))
                                        "default")
                                  (antigravity-cli--buffer-display-name buf))))
              (cons display-name buf)))
          buffers))

(defun antigravity-cli--select-buffer-from-choices (prompt buffers &optional simple-format)
  "Prompt user to select a buffer from BUFFERS list using PROMPT.

If SIMPLE-FORMAT is non-nil, use simplified display names.
Returns the selected buffer or nil."
  (when buffers
    (let* ((choices (antigravity-cli--buffers-to-choices buffers simple-format))
           (selection (completing-read prompt
                                       (mapcar #'car choices)
                                       nil t)))
      (cdr (assoc selection choices)))))

(defun antigravity-cli--prompt-for-antigravity-buffer ()
  "Prompt user to select from available Antigravity buffers.

Returns the selected buffer or nil if canceled. If a buffer is selected,
it's remembered for the current directory."
  (let* ((current-dir (antigravity-cli--directory))
         (antigravity-buffers (antigravity-cli--find-all-antigravity-buffers)))
    (when antigravity-buffers
      (let* ((prompt (substitute-command-keys
                      (format "No Antigravity instance running in %s. Cancel (\\[keyboard-quit]), or select Antigravity instance: "
                              (abbreviate-file-name current-dir))))
             (selected-buffer (antigravity-cli--select-buffer-from-choices prompt antigravity-buffers)))
        ;; Remember the selection for this directory
        (when selected-buffer
          (puthash current-dir selected-buffer antigravity-cli--directory-buffer-map))
        selected-buffer))))

(defun antigravity-cli--get-or-prompt-for-buffer ()
  "Get Antigravity buffer for current directory or prompt for selection.

First checks for Antigravity buffers in the current directory. If there are
multiple, prompts the user to select one. If there are none, checks if
there's a remembered selection for this directory. If not, and there are
other Antigravity buffers running, prompts the user to select one. Returns
the buffer or nil."
  (let* ((current-dir (antigravity-cli--directory))
         (dir-buffers (antigravity-cli--find-antigravity-buffers-for-directory current-dir)))
    (cond
     ;; Multiple buffers for this directory - prompt for selection
     ((> (length dir-buffers) 1)
      (antigravity-cli--select-buffer-from-choices
       (format "Select Antigravity instance for %s: "
               (abbreviate-file-name current-dir))
       dir-buffers
       t))  ; Use simple format (just instance names)
     ;; Single buffer for this directory - use it
     ((= (length dir-buffers) 1)
      (car dir-buffers))
     ;; No buffers for this directory - check remembered or prompt for other directories
     (t
      ;; Check for remembered selection for this directory
      (let ((remembered-buffer (gethash current-dir antigravity-cli--directory-buffer-map)))
        (if (and remembered-buffer (buffer-live-p remembered-buffer))
            remembered-buffer
          ;; No valid remembered buffer, check for other Antigravity instances
          (let ((other-buffers (antigravity-cli--find-all-antigravity-buffers)))
            (when other-buffers
              (antigravity-cli--prompt-for-antigravity-buffer)))))))))

(defun antigravity-cli--switch-to-selected-buffer (selected-buffer)
  "Switch to SELECTED-BUFFER if it's not the current buffer.

This is used after command functions to ensure we switch to the
selected Antigravity buffer when the user chose a different instance."
  (when (and selected-buffer
             (not (eq selected-buffer (current-buffer))))
    (pop-to-buffer selected-buffer)))

(defun antigravity-cli--buffer-name (&optional instance-name)
  "Generate the Antigravity buffer name based on project or current buffer file.

If INSTANCE-NAME is provided, include it in the buffer name.
If not in a project and no buffer file, raise an error."
  (let ((dir (antigravity-cli--directory)))
    (if dir
        (if instance-name
            (format "*antigravity:%s:%s*" (abbreviate-file-name (file-truename dir)) instance-name)
          (format "*antigravity:%s*" (abbreviate-file-name (file-truename dir))))
      (error "Cannot determine Antigravity directory - no `default-directory'!"))))

(defun antigravity-cli--prompt-for-instance-name (dir existing-instance-names &optional force-prompt)
  "Prompt user for a new instance name for directory DIR.

EXISTING-INSTANCE-NAMES is a list of existing instance names.
If FORCE-PROMPT is non-nil, always prompt even if no instances exist."
  (if (or existing-instance-names force-prompt)
      (let ((proposed-name ""))
        (while (or (string-empty-p proposed-name)
                   (member proposed-name existing-instance-names))
          (setq proposed-name
                (read-string (if (and existing-instance-names (not force-prompt))
                                 (format "Instances already running for %s (existing: %s), new instance name: "
                                         (abbreviate-file-name dir)
                                         (mapconcat #'identity existing-instance-names ", "))
                               (format "Instance name for %s: " (abbreviate-file-name dir)))
                             nil nil proposed-name))
          (cond
           ((string-empty-p proposed-name)
            (message "Instance name cannot be empty. Please enter a name.")
            (sit-for 1))
           ((member proposed-name existing-instance-names)
            (message "Instance name '%s' already exists. Please choose a different name." proposed-name)
            (sit-for 1))))
        proposed-name)
    "default"))

(defun antigravity-cli--show-not-running-message ()
  "Show a message that Antigravity is not running in any directory."
  (message "Antigravity is not running"))

(defun antigravity-cli--kill-buffer (buffer)
  "Kill a Antigravity BUFFER by cleaning up hooks and processes."
  (when (buffer-live-p buffer)
    (with-current-buffer buffer
      ;; Remove the adjust window size advice if it was added
      (when antigravity-cli-optimize-window-resize
        (advice-remove (antigravity-cli--term-get-adjust-process-window-size-fn antigravity-cli-terminal-backend) #'antigravity-cli--adjust-window-size-advice))
      ;; Remove vterm advice if using vterm backend
      (when (eq antigravity-cli-terminal-backend 'vterm)
        (advice-remove 'vterm--filter #'antigravity-cli--vterm-bell-detector)
        (advice-remove 'vterm--filter #'antigravity-cli--vterm-multiline-buffer-filter)
        ;; Cancel any pending timers
        (when antigravity-cli--vterm-resize-timer
          (cancel-timer antigravity-cli--vterm-resize-timer))
        (when antigravity-cli--vterm-multiline-buffer-timer
          (cancel-timer antigravity-cli--vterm-multiline-buffer-timer)))
      ;; Clean the window widths hash table
      (when antigravity-cli--window-widths
        (clrhash antigravity-cli--window-widths))
      ;; Kill the process
      (antigravity-cli--term-kill-process antigravity-cli-terminal-backend buffer))))

(defun antigravity-cli--cleanup-directory-mapping ()
  "Remove entries from directory-buffer map when this buffer is killed.

This function is added to `kill-buffer-hook' in Antigravity buffers to clean up
the remembered directory->buffer associations."
  (let ((dying-buffer (current-buffer)))
    (maphash (lambda (dir buffer)
               (when (eq buffer dying-buffer)
                 (remhash dir antigravity-cli--directory-buffer-map)))
             antigravity-cli--directory-buffer-map)))

(defun antigravity-cli--get-buffer-file-name ()
  "Get the file name associated with the current buffer."
  (when buffer-file-name
    (file-local-name (file-truename buffer-file-name))))

(defun antigravity-cli--format-file-reference (&optional file-name line-start line-end)
  "Format a file reference in the @file:line style.

FILE-NAME is the file path.  If nil, get from current buffer.
LINE-START is the starting line number.  If nil, use current line.
LINE-END is the ending line number for a range.  If nil, format single line."
  (let ((file (or file-name (antigravity-cli--get-buffer-file-name)))
        (start (or line-start (line-number-at-pos)))
        (end line-end))
    (when file
      (if end
          (format "@%s:%d-%d" file start end)
        (format "@%s:%d" file start)))))

(defun antigravity-cli--do-send-command (cmd)
  "Send a command CMD to Antigravity if Antigravity buffer exists.

After sending the command, move point to the end of the buffer.
Returns the selected Antigravity buffer or nil."
  (if-let ((antigravity-cli-buffer (antigravity-cli--get-or-prompt-for-buffer)))
      (progn
        (with-current-buffer antigravity-cli-buffer
          (antigravity-cli--term-send-string antigravity-cli-terminal-backend cmd)
          (sleep-for 0.1)
          (antigravity-cli--term-send-string antigravity-cli-terminal-backend (kbd "RET"))
          (display-buffer antigravity-cli-buffer))
        antigravity-cli-buffer)
    (antigravity-cli--show-not-running-message)
    nil))

(defun antigravity-cli--start (arg extra-switches &optional force-prompt force-switch-to-buffer)
  "Start Antigravity with given command-line EXTRA-SWITCHES.

ARG is the prefix argument controlling directory and buffer switching.
EXTRA-SWITCHES is a list of additional command-line switches to pass
to Antigravity.
If FORCE-PROMPT is non-nil, always prompt for instance name.
If FORCE-SWITCH-TO-BUFFER is non-nil, always switch to the
Antigravity buffer.

With single prefix ARG (\\[universal-argument]), switch to buffer after
creating.
With double prefix ARG (\\[universal-argument] \\[universal-argument]),
prompt for the project directory."
  (let* ((dir (if (equal arg '(16))     ; Double prefix
                  (read-directory-name "Project directory: ")
                (antigravity-cli--directory)))
         (switch-after (or (equal arg '(4)) force-switch-to-buffer)) ; Single prefix or force-switch-to-buffer
         (default-directory dir)
         ;; Check for existing Antigravity instances in this directory
         (existing-buffers (antigravity-cli--find-antigravity-buffers-for-directory dir))
         ;; Get existing instance names
         (existing-instance-names (mapcar (lambda (buf)
                                            (or (antigravity-cli--extract-instance-name-from-buffer-name
                                                 (buffer-name buf))
                                                "default"))
                                          existing-buffers))
         ;; Prompt for instance name (only if instances exist, or force-prompt is true)
         (instance-name (antigravity-cli--prompt-for-instance-name dir existing-instance-names force-prompt))
         (buffer-name (antigravity-cli--buffer-name instance-name))
         (program-switches (if extra-switches
                               (append antigravity-cli-program-switches extra-switches)
                             antigravity-cli-program-switches))

         ;; Set process-adaptive-read-buffering to nil to avoid flickering while Antigravity is processing
         (process-adaptive-read-buffering nil)

         ;; Start the terminal process
         (buffer (antigravity-cli--term-make antigravity-cli-terminal-backend buffer-name antigravity-cli-program program-switches)))

    ;; Check if the antigravity program is available
    (unless (executable-find antigravity-cli-program)
      (error "Antigravity CLI program '%s' not found in PATH" antigravity-cli-program))

    ;; Check if buffer was successfully created
    (unless (buffer-live-p buffer)
      (error "Failed to create Antigravity CLI buffer"))

    ;; setup antigravity buffer
    (with-current-buffer buffer

      ;; Configure terminal with backend-specific settings
      (antigravity-cli--term-configure antigravity-cli-terminal-backend)

      ;; Initialize the window widths hash table
      (setq antigravity-cli--window-widths (make-hash-table :test 'eq :weakness 'key))

      ;; Set up window width tracking if optimization is enabled
      (when antigravity-cli-optimize-window-resize
        (advice-add (antigravity-cli--term-get-adjust-process-window-size-fn antigravity-cli-terminal-backend) :around #'antigravity-cli--adjust-window-size-advice))

      ;; Setup our custom key bindings
      (antigravity-cli--term-setup-keymap antigravity-cli-terminal-backend)

      ;; Customize terminal faces
      (antigravity-cli--term-customize-faces antigravity-cli-terminal-backend)

      ;; remove underlines from _>_
      (face-remap-add-relative 'nobreak-space :underline nil)

      ;; set buffer face
      (buffer-face-set :inherit 'antigravity-cli-repl-face)

      ;; disable scroll bar, fringes
      (setq-local vertical-scroll-bar nil)
      (setq-local fringe-mode 0)

      ;; Add cleanup hook to remove directory mappings when buffer is killed
      (add-hook 'kill-buffer-hook #'antigravity-cli--cleanup-directory-mapping nil t)

      ;; run start hooks
      (run-hooks 'antigravity-cli-start-hook)

      ;; Disable vertical scroll bar in antigravity buffer
      (setq-local vertical-scroll-bar nil)

      ;; Display buffer, setting window parameters
      (let ((window (display-buffer-in-side-window buffer '((side . right)(window-width . 0.4)))))
        (when window
          ;; turn off fringes and margins in the Antigravity buffer
          (set-window-parameter window 'left-margin-width 0)
          (set-window-parameter window 'right-margin-width 0)
          (set-window-parameter window 'left-fringe-width 0)
          (set-window-parameter window 'right-fringe-width 0)
          ;; set no-delete-other-windows parameter for antigravity-cli window
          (set-window-parameter window 'no-delete-other-windows antigravity-cli-no-delete-other-windows))))

    ;; switch to the Antigravity buffer if asked to
    (when switch-after
      (pop-to-buffer buffer))))

;;;###autoload
(defun antigravity-cli (&optional arg)
  "Start Antigravity in an eat terminal and enable `antigravity-cli-mode'.

If current buffer belongs to a project start Antigravity in the project's
root directory. Otherwise start in the directory of the current buffer
file, or the current value of `default-directory' if no project and no
buffer file.

With single prefix ARG (\\[universal-argument]), switch to buffer after creating.
With double prefix ARG (\\[universal-argument] \\[universal-argument]), prompt for the project directory."
  (interactive "P")
  (antigravity-cli--start arg nil))

;;;###autoload
(defun antigravity-cli-start-in-directory (&optional arg)
  "Prompt for a directory and start Antigravity there.

This is a convenience command equivalent to using `antigravity-cli` with
double prefix arg (\\[universal-argument] \\[universal-argument]).

With prefix ARG (\\[universal-argument]), switch to buffer after creating."
  (interactive "P")
  ;; Always prompt for directory (like double prefix)
  ;; If user gave us a prefix arg, also switch to buffer after creating
  (let ((dir (read-directory-name "Project directory: ")))
    ;; We need to temporarily override antigravity-cli--directory to return our chosen dir
    (cl-letf (((symbol-function 'antigravity-cli--directory) (lambda () dir)))
      (antigravity-cli (when arg '(4))))))

;;;###autoload
(defun antigravity-cli-continue (&optional arg)
  "Start Antigravity and continue the previous conversation.

This command starts Antigravity with the --continue flag to resume
where you left off in your last session.

If current buffer belongs to a project start Antigravity in the project's
root directory. Otherwise start in the directory of the current buffer
file, or the current value of `default-directory' if no project and no
buffer file.

With prefix ARG (\\[universal-argument]), switch to buffer after creating.
With double prefix ARG (\\[universal-argument] \\[universal-argument]), prompt for the project directory."
  (interactive "P")
  (antigravity-cli--start arg '("--continue")))

;;;###autoload
(defun antigravity-cli-resume (arg)
  "Resume a specific Antigravity session.

This command starts Antigravity with the --resume flag to resume a specific
past session. Antigravity will present an interactive list of past sessions
to choose from.

If current buffer belongs to a project start Antigravity in the project's
root directory. Otherwise start in the directory of the current buffer
file, or the current value of `default-directory' if no project and no
 buffer file.

With double prefix ARG (\\[universal-argument] \\[universal-argument]), prompt for the project directory."
  (interactive "P")

  (let ((extra-switches '("--resume")))
    (antigravity-cli--start arg extra-switches nil t))
  (antigravity-cli--term-send-string antigravity-cli-terminal-backend "")
  (goto-char (point-min)))

;;;###autoload
(defun antigravity-cli-new-instance (&optional arg)
  "Create a new Antigravity instance, prompting for instance name.

This command always prompts for an instance name, unlike `antigravity-cli'
which uses \"default\" when no instances exist.

If current buffer belongs to a project start Antigravity in the project's
root directory. Otherwise start in the directory of the current buffer
file, or the current value of `default-directory' if no project and no
buffer file.

With single prefix ARG (\\[universal-argument]), switch to buffer after creating.
With double prefix ARG (\\[universal-argument] \\[universal-argument]), prompt
for the project directory."
  (interactive "P")

  ;; Call antigravity-cli--start with force-prompt=t
  (antigravity-cli--start arg nil t))

(defun antigravity-cli--format-errors-at-point ()
  "Format errors at point as a string with file and line numbers.
First tries flycheck errors if flycheck is enabled, then falls back
to help-at-pt (used by flymake and other systems).
Returns a string with the errors or a message if no errors found."
  (interactive)
  (cond
   ;; Try flycheck first if available and enabled
   ((and (featurep 'flycheck) (bound-and-true-p flycheck-mode))
    (let ((errors (flycheck-overlay-errors-at (point)))
          (result ""))
      (if (not errors)
          "No flycheck errors at point"
        (dolist (err errors)
          (let ((file (flycheck-error-filename err))
                (line (flycheck-error-line err))
                (msg (flycheck-error-message err)))
            (setq result (concat result
                                 (format "%s:%d: %s\n"
                                         file
                                         line
                                         msg)))))
        (string-trim-right result))))
   ;; Fall back to help-at-pt-kbd-string (works with flymake and other sources)
   ((help-at-pt-kbd-string)
    (let ((help-str (help-at-pt-kbd-string)))
      (if (not (null help-str))
          (substring-no-properties help-str)
        "No help string available at point")))
   ;; No errors found by any method
   (t "No errors at point")))

(defun antigravity-cli--pulse-modeline ()
  "Pulse the modeline to provide visual notification."
  ;; First pulse - invert
  (invert-face 'mode-line)
  (run-at-time 0.1 nil
               (lambda ()
                 ;; Return to normal
                 (invert-face 'mode-line)
                 ;; Second pulse
                 (run-at-time 0.1 nil
                              (lambda ()
                                (invert-face 'mode-line)
                                ;; Final return to normal
                                (run-at-time 0.1 nil
                                             (lambda ()
                                               (invert-face 'mode-line))))))))

(defun antigravity-cli-default-notification (title message)
  "Default notification function that displays a message and pulses the modeline.

TITLE is the notification title.
MESSAGE is the notification body."
  ;; Display the message
  (message "%s: %s" title message)
  ;; Pulse the modeline for visual feedback
  (antigravity-cli--pulse-modeline)
  (message "%s: %s" title message))

(defun antigravity-cli--notify (_terminal)
  "Notify the user that Antigravity has finished and is awaiting input.

TERMINAL is the eat terminal parameter (not used)."
  (when antigravity-cli-enable-notifications
    (funcall antigravity-cli-notification-function
             "Antigravity Ready"
             "Waiting for your response")))

(defun antigravity-cli--vterm-bell-detector (orig-fun process input)
  "Detect bell characters in vterm output and trigger notifications.

ORIG-FUN is the original vterm--filter function.
PROCESS is the vterm process.
INPUT is the terminal output string."
  ;; Track output timestamp for resize deferral
  (with-current-buffer (process-buffer process)
    (setq antigravity-cli--vterm-last-output-time (current-time)))

  (when (and (string-match-p "\007" input)
             (buffer-local-value 'antigravity-cli-mode (process-buffer process))
             ;; Ignore bells in OSC sequences (terminal title updates)
             (not (string-match-p "]0;.*\007" input)))
    (antigravity-cli--notify nil))

  (funcall orig-fun process input))

(defvar-local antigravity-cli--vterm-multiline-buffer nil
  "Buffer for accumulating multi-line vterm output.")

(defun antigravity-cli--vterm-multiline-buffer-filter (orig-fun process input)
  "Buffer vterm output when it appears to be redrawing multi-line input.
This prevents flickering when Antigravity redraws its input box as it expands
to multiple lines. We detect this by looking for escape sequences that
indicate cursor positioning and line clearing operations.

ORIG-FUN is the original vterm--filter function.
PROCESS is the vterm process.
INPUT is the terminal output string."
  (if (not antigravity-cli-vterm-buffer-multiline-output)
      ;; Feature disabled, pass through normally
      (funcall orig-fun process input)
    (with-current-buffer (process-buffer process)
      ;; Only buffer if we see strong indicators of multiline redraw
      (let* ((has-clear-line (string-match-p "\033\\[K" input))
             (has-cursor-up (string-match-p "\033\\[[0-9]*A" input))
             (has-cursor-pos (string-match-p "\033\\[[0-9]+;[0-9]+H" input))
             (escape-count (cl-count ?\033 input))
             ;; Very specific pattern: clear line + cursor movement in same chunk
             (is-multiline-redraw (and has-clear-line
                                       (or has-cursor-up has-cursor-pos)
                                       (>= escape-count 3))))

        (cond
         ;; Start buffering only for very specific redraw pattern
         (is-multiline-redraw
          (setq antigravity-cli--vterm-multiline-buffer input)
          ;; Cancel existing timer
          (when antigravity-cli--vterm-multiline-buffer-timer
            (cancel-timer antigravity-cli--vterm-multiline-buffer-timer))
          ;; Very short timer - just enough to batch a single redraw
          (setq antigravity-cli--vterm-multiline-buffer-timer
                (run-at-time 0.005 nil
                             #'antigravity-cli--vterm-flush-multiline-buffer
                             (current-buffer))))

         ;; If we're buffering and see more escape sequences, add to buffer
         ((and antigravity-cli--vterm-multiline-buffer
               (> escape-count 0))
          (setq antigravity-cli--vterm-multiline-buffer
                (concat antigravity-cli--vterm-multiline-buffer input))
          ;; Reset timer
          (when antigravity-cli--vterm-multiline-buffer-timer
            (cancel-timer antigravity-cli--vterm-multiline-buffer-timer))
          (setq antigravity-cli--vterm-multiline-buffer-timer
                (run-at-time 0.005 nil
                             #'antigravity-cli--vterm-flush-multiline-buffer
                             (current-buffer))))

         ;; Otherwise process normally
         (t
          (funcall orig-fun process input)))))))

(defun antigravity-cli--vterm-flush-multiline-buffer (buffer)
  "Flush the accumulated multiline buffer for BUFFER."
  (when (buffer-live-p buffer)
    (with-current-buffer buffer
      (when antigravity-cli--vterm-multiline-buffer
        (let ((inhibit-redisplay t)
              (data antigravity-cli--vterm-multiline-buffer))
          ;; Clear buffer state
          (setq antigravity-cli--vterm-multiline-buffer nil
                antigravity-cli--vterm-multiline-buffer-timer nil)
          ;; Process all buffered data at once with redisplay inhibited
          (funcall (symbol-function 'vterm--filter)
                   (get-buffer-process buffer)
                   data))))))

(defun antigravity-cli--vterm-output-recent-p ()
  "Check if vterm output was received recently.

Returns t if output was received within the last 100ms."
  (and antigravity-cli--vterm-last-output-time
       (< (float-time (time-subtract (current-time) antigravity-cli--vterm-last-output-time))
          0.1)))

(defun antigravity-cli--vterm-apply-deferred-resize (buffer)
  "Apply deferred resize to vterm in BUFFER."
  (when (buffer-live-p buffer)
    (with-current-buffer buffer
      (when antigravity-cli--vterm-pending-resize
        (let* ((size antigravity-cli--vterm-pending-resize)
               (width (car size))
               (height (cdr size))
               (process (get-buffer-process buffer))
               (windows (get-buffer-window-list buffer))
               ;; Save window positions before resize
               (window-states (mapcar (lambda (win)
                                        (cons win (cons (window-start win)
                                                        (>= (window-point win)
                                                            (- (point-max) 2)))))
                                      windows)))
          (setq antigravity-cli--vterm-pending-resize nil)
          (setq antigravity-cli--vterm-resize-timer nil)
          ;; Send the resize to vterm
          (when (and process (process-live-p process))
            (vterm--set-size vterm--term height width)
            ;; Restore window positions after resize
            (dolist (state window-states)
              (let ((win (car state))
                    (start (cadr state))
                    (was-at-bottom (cddr state)))
                (when (window-live-p win)
                  (if was-at-bottom
                      ;; If we were at bottom, stay at bottom
                      (with-selected-window win
                        (goto-char (point-max))
                        (recenter -1))
                    ;; Otherwise restore previous position
                    (set-window-start win start t)))))))))))

(defun antigravity-cli--adjust-window-size-advice (orig-fun &rest args)
  "Advice to only signal on width change and defer during active output.

Works with `eat--adjust-process-window-size' or
`vterm--adjust-process-window-size' to prevent unnecessary reflows.

Returns the size returned by ORIG-FUN only when the width of any Antigravity
window has changed, not when only the height has changed. This prevents
unnecessary terminal reflows when only vertical space changes.

For vterm, also defers resize during active output to prevent scrolling issues.

ARGS is passed to ORIG-FUN unchanged."
  (let ((result (apply orig-fun args)))
    ;; Check all windows for Antigravity buffers
    (let ((width-changed nil))
      (dolist (window (window-list))
        (let ((buffer (window-buffer window)))
          (when (and buffer (antigravity-cli--buffer-p buffer))
            (let ((current-width (window-width window))
                  (stored-width (gethash window antigravity-cli--window-widths)))
              ;; Check if this is a new window or if width changed
              (when (or (not stored-width) (/= current-width stored-width))
                (setq width-changed t)
                ;; Update stored width
                (puthash window current-width antigravity-cli--window-widths))))))
      ;; Return result only if a Antigravity window width changed and
      ;; we're not in read-only mode. otherwise nil. Nil means do
      ;; not send a window size changed event to the Antigravity process.
      (if (and width-changed (not (antigravity-cli--term-in-read-only-p antigravity-cli-terminal-backend)))
          (cond
           ;; For vterm backend, defer resize if output is recent
           ((and (eq antigravity-cli-terminal-backend 'vterm)
                 (antigravity-cli--vterm-output-recent-p))
            ;; Store pending resize
            (setq antigravity-cli--vterm-pending-resize result)
            ;; Cancel any existing timer
            (when antigravity-cli--vterm-resize-timer
              (cancel-timer antigravity-cli--vterm-resize-timer))
            ;; Set timer to apply resize after output settles
            (setq antigravity-cli--vterm-resize-timer
                  (run-at-time 0.15 nil
                               #'antigravity-cli--vterm-apply-deferred-resize
                               (current-buffer)))
            nil) ; Don't resize now
           ;; Otherwise, resize immediately
           (t result))
        nil))))

;;;; Interactive Commands

;;;###autoload
(defun antigravity-cli-send-region (&optional arg)
  "Send the current region to Antigravity.

If no region is active, send the entire buffer if it's not too large.
For large buffers, ask for confirmation first.

With prefix ARG, prompt for instructions to add to the text before
sending. With two prefix ARGs (C-u C-u), both add instructions and
switch to Antigravity buffer."
  (interactive "P")
  (let* ((text (if (use-region-p)
                   (buffer-substring-no-properties (region-beginning) (region-end))
                 (if (> (buffer-size) antigravity-cli-large-buffer-threshold)
                     (when (yes-or-no-p "Buffer is large.  Send anyway? ")
                       (buffer-substring-no-properties (point-min) (point-max)))
                   (buffer-substring-no-properties (point-min) (point-max)))))
         (prompt (cond
                  ((equal arg '(4))     ; C-u
                   (read-string "Instructions: "))
                  (t nil)))
         (full-text (if prompt
                        (format "%s\n\n%s" prompt text)
                      text)))
    (when full-text
      (let ((selected-buffer (antigravity-cli--do-send-command full-text)))
        (when (and (equal arg '(16)) selected-buffer) ; Only switch buffer with C-u C-u
          (pop-to-buffer selected-buffer))))))

;;;###autoload
(defun antigravity-cli-toggle ()
  "Show or hide the Antigravity window.

If the Antigravity buffer doesn't exist, create it."
  (interactive)
  (let ((antigravity-cli-buffer (antigravity-cli--get-or-prompt-for-buffer)))
    (if antigravity-cli-buffer
        (if (get-buffer-window antigravity-cli-buffer)
            (delete-window (get-buffer-window antigravity-cli-buffer))
      (let ((window (display-buffer-in-side-window antigravity-cli-buffer '((side . right)(window-width . 0.4)))))
            ;; set no-delete-other-windows parameter for antigravity-cli window
            (set-window-parameter window 'no-delete-other-windows antigravity-cli-no-delete-other-windows)))
      (antigravity-cli--show-not-running-message))))

;;;###autoload
(defun antigravity-cli--switch-to-all-instances-helper ()
  "Helper function to switch to a Antigravity buffer from all available instances.

Returns t if a buffer was selected and switched to, nil otherwise."
  (let ((all-buffers (antigravity-cli--find-all-antigravity-buffers)))
    (cond
     ((null all-buffers)
      (antigravity-cli--show-not-running-message)
      nil)
     ((= (length all-buffers) 1)
      ;; Only one buffer, just switch to it
      (pop-to-buffer (car all-buffers))
      t)
     (t
      ;; Multiple buffers, let user choose
      (let ((selected-buffer (antigravity-cli--select-buffer-from-choices
                              "Select Antigravity instance: "
                              all-buffers)))
        (when selected-buffer
          (pop-to-buffer selected-buffer)
          t))))))

(defun antigravity-cli-switch-to-buffer (&optional arg)
  "Switch to the Antigravity buffer if it exists.

With prefix ARG, show all Antigravity instances across all directories."
  (interactive "P")
  (if arg
      ;; With prefix arg, show all Antigravity instances
      (antigravity-cli--switch-to-all-instances-helper)
    ;; Without prefix arg, use normal behavior
    (if-let ((antigravity-cli-buffer (antigravity-cli--get-or-prompt-for-buffer)))
        (pop-to-buffer antigravity-cli-buffer)
      (antigravity-cli--show-not-running-message))))

;;;###autoload
(defun antigravity-cli-select-buffer ()
  "Select and switch to a Antigravity buffer from all running instances.

This command shows all Antigravity instances across all projects and
directories, allowing you to choose which one to switch to."
  (interactive)
  (antigravity-cli--switch-to-all-instances-helper))

(defun antigravity-cli--kill-all-instances ()
  "Kill all Antigravity instances across all directories."
  (let ((all-buffers (antigravity-cli--find-all-antigravity-buffers)))
    (if all-buffers
        (let* ((buffer-count (length all-buffers))
               (plural-suffix (if (= buffer-count 1) "" "s")))
          (if antigravity-cli-confirm-kill
              (when (yes-or-no-p (format "Kill %d Antigravity instance%s? " buffer-count plural-suffix))
                (dolist (buffer all-buffers)
                  (antigravity-cli--kill-buffer buffer))
                (message "%d Antigravity instance%s killed" buffer-count plural-suffix))
            (dolist (buffer all-buffers)
              (antigravity-cli--kill-buffer buffer))
            (message "%d Antigravity instance%s killed" buffer-count plural-suffix)))
      (antigravity-cli--show-not-running-message))))

;;;###autoload
(defun antigravity-cli-kill ()
  "Kill Antigravity process and close its window."
  (interactive)
  (if-let ((antigravity-cli-buffer (antigravity-cli--get-or-prompt-for-buffer)))
      (if antigravity-cli-confirm-kill
          (when (yes-or-no-p "Kill Antigravity instance? ")
            (antigravity-cli--kill-buffer antigravity-cli-buffer)
            (message "Antigravity instance killed"))
        (antigravity-cli--kill-buffer antigravity-cli-buffer)
        (message "Antigravity instance killed"))
    (antigravity-cli--show-not-running-message)))

;;;###autoload
(defun antigravity-cli-kill-all ()
  "Kill ALL Antigravity processes across all directories."
  (interactive)
  (antigravity-cli--kill-all-instances))

;;;###autoload
(defun antigravity-cli-send-command (&optional arg)
  "Read a Antigravity command from the minibuffer and send it.

With prefix ARG, switch to the Antigravity buffer after sending CMD."
  (interactive)
  (let ((selected-buffer (antigravity-cli--do-send-command
                          (read-string "Prompt: "))))
    (when (and arg selected-buffer)
      (pop-to-buffer selected-buffer))))

;;;##autoload
(defun antigravity-cli-send-shell (cmd &optional arg)
  "Read a Antigravity command from the minibuffer and send it.

With prefix ARG, switch to the Antigravity buffer after sending CMD."
  (interactive "sAntigravity command: !\nP")
  (let ((selected-buffer (antigravity-cli--do-send-command (concat "!" cmd))))
    (when selected-buffer
      (with-current-buffer selected-buffer
        (antigravity-cli--do-send-command "!")))
    (when (and arg selected-buffer)
      (pop-to-buffer selected-buffer))))

;;;###autoload
(defun antigravity-cli-send-command-with-context (&optional arg)
  "Read a Antigravity command and send it with current file and line context.

If region is active, include region line numbers.
With prefix ARG, switch to the Antigravity buffer after sending CMD."
  (interactive)
  (let* ((cmd (read-string "Prompt:"))
         (file-ref (if (use-region-p)
                       (antigravity-cli--format-file-reference
                        nil
                        (line-number-at-pos (region-beginning))
                        (line-number-at-pos (region-end)))
                     (antigravity-cli--format-file-reference)))
         (cmd-with-context (if file-ref
                               (format "%s\n%s" cmd file-ref)
                             cmd)))
    (let ((selected-buffer (antigravity-cli--do-send-command cmd-with-context)))
      (when (and arg selected-buffer)
        (pop-to-buffer selected-buffer)))))

;;;###autoload
(defun antigravity-cli-send-return ()
  "Send <return> to the Antigravity CLI REPL.

This is useful for saying Yes when Antigravity asks for confirmation without
having to switch to the REPL buffer."
  (interactive)
  (antigravity-cli--do-send-command ""))

;;;###autoload
(defun antigravity-cli-send-1 ()
  "Send \"1\" to the Antigravity CLI REPL.

This selects the first option when Antigravity presents a numbered menu."
  (interactive)
  (antigravity-cli--do-send-command "1"))

;;;###autoload
(defun antigravity-cli-send-2 ()
  "Send \"2\" to the Antigravity CLI REPL.

This selects the second option when Antigravity presents a numbered menu."
  (interactive)
  (antigravity-cli--do-send-command "2"))

;;;###autoload
(defun antigravity-cli-send-3 ()
  "Send \"3\" to the Antigravity CLI REPL.

This selects the third option when Antigravity presents a numbered menu."
  (interactive)
  (antigravity-cli--do-send-command "3"))

;;;###autoload
(defun antigravity-cli-send-4 ()
  "Send \"4\" to the Antigravity CLI REPL.

This selects the third option when Antigravity presents a numbered menu."
  (interactive)
  (antigravity-cli--do-send-command "4"))

;;;###autoload
(defun antigravity-cli-esc ()
  "Send an ESC key/character to the active Antigravity CLI REPL buffer.

This is useful for sending the Escape key to cancel a prompt or navigate menus
in the agy TUI."
  (interactive)
  (antigravity-cli--with-buffer
   (cond
    ((eq antigravity-cli-terminal-backend 'vterm)
     (antigravity-cli--ensure-vterm)
     (vterm-send-key "escape"))
    ((eq antigravity-cli-terminal-backend 'eat)
     (antigravity-cli--ensure-eat)
     (eat-term-send-string eat-terminal "\e"))
    (t
     (antigravity-cli--term-send-string antigravity-cli-terminal-backend (kbd "ESC"))))))

;;;###autoload
(defun antigravity-cli-send-escape ()
  "Send <escape> to the Antigravity CLI REPL.
This is an alias for `antigravity-cli-esc'."
  (interactive)
  (antigravity-cli-esc))

;;;###autoload
(defun antigravity-cli-send-file (file-path)
  "Send the specified FILE-PATH to Antigravity prefixed with `@'.

FILE-PATH should be an absolute path to the file to send."
  (interactive "fFile to send to Antigravity: ")
  (let ((command (format "@%s" (expand-file-name file-path))))
    (antigravity-cli--do-send-command command)))

;;;###autoload
(defun antigravity-cli-send-buffer-file (&optional arg)
  "Send the file associated with current buffer to Antigravity prefixed with `@'.

With prefix ARG, prompt for instructions to add to the file before sending.
With two prefix ARGs, both add instructions and switch to Antigravity buffer."
  (interactive "P")
  (let ((file-path (antigravity-cli--get-buffer-file-name)))
    (if file-path
        (let* ((prompt (when arg
                        (read-string "Instructions: ")))
               (command (if prompt
                           (format "%s\n\n@%s" prompt file-path)
                         (format "@%s" file-path))))
          (let ((selected-buffer (antigravity-cli--do-send-command command)))
            (when (and arg selected-buffer)
              (pop-to-buffer selected-buffer))))
      (error "Current buffer is not associated with a file"))))

(defun antigravity-cli--send-meta-return ()
  "Send Meta-Return key sequence to the terminal."
  (interactive)
  (antigravity-cli--term-send-string antigravity-cli-terminal-backend "\e\C-m"))

(defun antigravity-cli--send-return ()
  "Send Return key to the terminal."
  (interactive)
  (antigravity-cli--term-send-string antigravity-cli-terminal-backend (kbd "RET")))

;;;###autoload
(defun antigravity-cli-cycle-mode ()
  "Send Shift-Tab to Antigravity to cycle between modes.

Antigravity uses Shift-Tab to cycle through:
- Default mode
- Auto-accept edits mode
- Plan mode"
  (interactive)
  (antigravity-cli--with-buffer
   (antigravity-cli--term-send-string antigravity-cli-terminal-backend "\e[Z")))

;; (define-key key-translation-map (kbd "ESC") "")

;;;###autoload
(defun antigravity-cli-fork ()
  "Jump to a previous conversation by invoking the Antigravity fork command.

Sends <escape><escape> to the Antigravity CLI REPL."
  (interactive)
  (if-let ((antigravity-cli-buffer (antigravity-cli--get-or-prompt-for-buffer)))
      (with-current-buffer antigravity-cli-buffer
        (antigravity-cli--term-send-string antigravity-cli-terminal-backend "")
        ;; (display-buffer antigravity-cli-buffer)
        (pop-to-buffer antigravity-cli-buffer))
    (antigravity-cli--show-not-running-message)))

;;;###autoload
(defun antigravity-cli-fix-error-at-point (&optional arg)
  "Ask Antigravity to fix the error at point.

Gets the error message, file name, and line number, and instructs Antigravity
to fix the error. Supports both flycheck and flymake error systems, as well
as any system that implements help-at-pt.

With prefix ARG, switch to the Antigravity buffer after sending."
  (interactive "P")
  (let* ((error-text (antigravity-cli--format-errors-at-point))
         (file-ref (antigravity-cli--format-file-reference)))
    (if (string= error-text "No errors at point")
        (message "No errors found at point")
      (let ((command (format "Fix this error at %s:\nDo not run any external linter or other program, just fix the error at point using the context provided in the error message: <%s>"
                             (or file-ref "current position") error-text)))
        (let ((selected-buffer (antigravity-cli--do-send-command command)))
          (when (and arg selected-buffer)
            (pop-to-buffer selected-buffer)))))))

;;;###autoload
(defun antigravity-cli-read-only-mode ()
  "Enter read-only mode in Antigravity buffer with visible cursor.

In this mode, you can interact with the terminal buffer just like a
regular buffer. This mode is useful for selecting text in the Antigravity
buffer. However, you are not allowed to change the buffer contents or
enter Antigravity commands.

Use `antigravity-cli-exit-read-only-mode' to switch back to normal mode."
  (interactive)
  (antigravity-cli--with-buffer
   (antigravity-cli--term-read-only-mode antigravity-cli-terminal-backend)
   (message "Antigravity read-only mode enabled")))

;;;###autoload
(defun antigravity-cli-exit-read-only-mode ()
  "Exit read-only mode and return to normal mode (eat semi-char mode)."
  (interactive)
  (antigravity-cli--with-buffer
   (antigravity-cli--term-interactive-mode antigravity-cli-terminal-backend)
   (message "Antigravity read-only disabled")))

;;;###autoload
(defun antigravity-cli-toggle-read-only-mode ()
  "Toggle between read-only mode and normal mode.

In read-only mode you can interact with the terminal buffer just like a
regular buffer. This mode is useful for selecting text in the Antigravity
buffer. However, you are not allowed to change the buffer contents or
enter Antigravity commands."
  (interactive)
  (antigravity-cli--with-buffer
   (if (not (antigravity-cli--term-in-read-only-p antigravity-cli-terminal-backend))
       (antigravity-cli-read-only-mode)
     (antigravity-cli-exit-read-only-mode))))

;;;; Mode definition
;;;###autoload
(define-minor-mode antigravity-cli-mode
  "Minor mode for interacting with Antigravity AI CLI.

When enabled, provides functionality for starting, sending commands to,
and managing Antigravity sessions."
  :init-value nil
  :lighter " Antigravity"
  :global t
  :group 'antigravity-cli)

;;;; Provide the feature
(provide 'antigravity-cli)

;;; antigravity-cli.el ends here
