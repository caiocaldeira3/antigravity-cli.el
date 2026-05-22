# antigravity-cli.el

![antigravity-cli](./antigravity-cli.png)

An Emacs interface for [Antigravity CLI](https://blog.google/technology/developers/introducing-antigravity-cli-open-source-ai-agent/), providing integration between Emacs and Antigravity AI for coding assistance.

> **Note**: This package was formerly known as `gemini-cli.el`. It has been migrated to support the new Antigravity CLI following the deprecation of the Gemini CLI.

## Features

- **Seamless Emacs Integration** - Start, manage, and interact with Antigravity without leaving Emacs
- **Stay in Your Buffer** - Send code, regions, or commands to Antigravity while keeping your focus
- **Fix Errors Instantly** - Point at a flycheck/flymake error and ask Antigravity to fix it
- **Multiple Instances** - Run separate Antigravity sessions for different projects or tasks
- **Quick Responses** - Answer Antigravity with a keystroke (<return>/<escape>/1/2/3) without switching buffers
- **Smart Context** - Optionally include file paths and line numbers when sending commands to Antigravity
- **Transient Menu** - Access all commands and slash commands through a transient menu
- **Continue Conversations** - Resume previous sessions or fork to earlier points
- **Read-Only Mode** - Toggle to select and copy text with normal Emacs commands and keybindings
- **Mode Cycling** - Quick switch between default, auto-accept edits, and plan modes
- **Desktop Notifications** - Get notified when Antigravity finishes processing
- **Terminal Choice** - Works with both eat and vterm backends
- **Fully Customizable** - Configure keybindings, notifications, and display preferences

## Installation {#installation}

### Prerequisites

- Emacs 30.0 or higher
- [Antigravity CLI](https://github.com/google-antigravity/antigravity-cli) installed and configured
- Required: transient (0.7.5+)
- Optional: eat (0.9.2+) for eat backend, vterm for vterm backend
- Note: If not using a `:vc` install, the `eat` package requires NonGNU ELPA:
    ```elisp
    (add-to-list 'package-archives '("nongnu" . "https://elpa.nongnu.org/nongnu/"))
    ```

### Using builtin use-package (Emacs 30+)

```elisp
;; add melp to package archives, as vterm is on melpa:
(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(package-initialize)

;; for eat terminal backend:
(use-package eat :ensure t)

;; for vterm terminal backend:
(use-package vterm :ensure t)
;; for slash commands popup
(use-package popup :ensure t)
;; install antigravity-cli.el
(use-package antigravity-cli :ensure t
  :vc (:url "https://github.com/caiocaldeira3/antigravity-cli.el" :rev :newest)
  :config (antigravity-cli-mode)
  :bind-keymap ("C-c c" . antigravity-cli-command-map)) ;; or your preferred key
```

### Using straight.el

```elisp
;; for eat terminal backend:
(use-package eat
  :straight (:type git
                   :host codeberg
                   :repo "akib/emacs-eat"
                   :files ("*.el" ("term" "term/*.el") "*.texi"
                           "*.ti" ("terminfo/e" "terminfo/e/*")
                           ("terminfo/65" "terminfo/65/*")
                           ("integration" "integration/*")
                           (:exclude ".dir-locals.el" "*-tests.el"))))

;; for vterm terminal backend:
(use-package vterm :straight t)

;; for slash commands popup
(use-package popup :ensure t)
(use-package antigravity-cli
  :straight (:type git :host github :repo "caiocaldeira3/antigravity-cli.el" :branch "main"
                   :files ("*.el" (:exclude "demo.gif")))
  :bind-keymap
  ("C-c c" . antigravity-cli-command-map)
  :config
  (antigravity-cli-mode))
```

### Doom Emacs

To install in Doom Emacs, configure your packages and configuration as follows:

1. Add the package recipe to your `packages.el` (typically in `~/.config/doom/packages.el`):
   ```elisp
   (package! antigravity-cli
     :recipe (:host github
              :repo "caiocaldeira3/antigravity-cli.el"
              :branch "main"
              :files ("*.el" (:exclude "demo.gif"))))
   ```

2. Add the configuration to your `config.el` (typically in `~/.config/doom/config.el`):
   ```elisp
   (use-package! antigravity-cli
     :config
     ;; Set your preferred terminal backend (vterm or eat)
     (setq antigravity-cli-terminal-backend 'vterm)
     
     ;; Centralized Doom bindings under the leader key (usually SPC)
     (map! :leader
           (:prefix-map ("l" . "LLMs CLI Agents")
            :desc "Antigravity CLI Menu" "a" #'antigravity-cli-transient)))
   ```

3. Run `doom sync` in your terminal to download, build, and synchronize the package.

## Basic Usage

### Setting Prefix Key
You need to set your own key binding for the Antigravity CLI command map, as described in the [Installation](#installation) section. The examples in this README use `C-c c` as the prefix key.

### Picking Eat or Vterm

By default antigravity-cli.el uses the `eat` backend. If you prefer vterm customize
`antigravity-cli-terminal-backend`:

```elisp
(setq antigravity-cli-terminal-backend 'vterm)
```

### Transient Menu

You can see a menu of the important commands by invoking the transient, `antigravity-cli-transient` (`C-c c m`):

![](./images/transient.png)

### Starting and Stopping Antigravity

To start Antigravity, run `antigravity-cli` (`C-c c c`). This will start a new Antigravity instance in the root
project directory of the buffer file, or the current directory if outside of a project.
Antigravity-code.el uses Emacs built-in
[project.el](https://www.gnu.org/software/emacs/manual/html_node/emacs/Projects.html) which works
with most version control systems.

To start Antigravity in a specific directory use `antigravity-cli-start-in-directory` (`C-c c d`). It will
prompt you for the directory.

The `antigravity-cli-continue` command will continue the previous conversation, and `antigravity-cli-resume` will let you pick from a list of previous sessions.

To kill the Antigravity process and close its window use `antigravity-cli-kill` (`C-c c k`).

### Sending Commands to Antigravity

Once Antigravity has started, you can switch to the Antigravity buffer and start entering prompts.
Alternately, you can send prompts to Antigravity using the minibuffer via `antigravity-cli-send-command`
(`C-c c s`). `antigravity-cli-send-command-with-context` (`C-c c x`) will also send the current file name and line
number to Antigravity. This is useful for asking things like "what does this code do?", or "fix the bug
in this code".

Use the `antigravity-cli-send-region` (`C-c c r`) command to send the selected region to Antigravity, or the entire buffer if no region is selected. This command is useful for writing a prompt in a regular Emacs buffer and sending it to Antigravity. With a single prefix arg (`C-u C-c c r`) it will prompt for extra context before sending the region to Antigravity.

You can also send files directly to Antigravity using `antigravity-cli-send-file` to send any file by path, or `antigravity-cli-send-buffer-file` (`C-c c o`) to send the file associated with the current buffer. The `antigravity-cli-send-buffer-file` command supports prefix arguments similar to `antigravity-cli-send-region` - with a single prefix arg it prompts for instructions, and with double prefix it also switches to the Antigravity buffer.

If you put your cursor over a flymake or flycheck error, you can ask Antigravity to fix it via `antigravity-cli-fix-error-at-point` (`C-c c e`).

To show and hide the Antigravity buffer use `antigravity-cli-toggle` (`C-c c t`).  To jump to the Antigravity buffer use `antigravity-cli-switch-to-buffer` (`C-c c b`). This will open the buffer if hidden.

### Managing Antigravity Windows

The `antigravity-cli-toggle` (`C-c c t`) will show and hide the Antigravity window. Use the `antigravity-cli-switch-to-buffer` (`C-c c b`) command to switch to the Antigravity window even if it is hidden. 

To enter read-only mode in the Antigravity buffer use `antigravity-cli-toggle-read-only-mode` (`C-c c z`). In this mode you can select and copy text, and use regular Emacs keybindings. To exit read-only mode invoke `antigravity-cli-toggle-read-only-mode` again.

### Quick Responses

Sometimes you want to send a quick response to Antigravity without switching to the Antigravity buffer. The following commands let you answer a query from Antigravity without leaving your current editing buffer:

- `antigravity-cli-send-return` (`C-c c y`) - send the return or enter key to Antigravity, commonly used to respond with "Yes" to Antigravity queries
- `antigravity-cli-esc` (`C-c c E` or `C-c c ESC`) - send the escape key to say "No" to Antigravity, navigate menus, or cancel a running Antigravity action (alias: `antigravity-cli-send-escape`)
- `antigravity-cli-send-1` (`C-c c 1`) - send "1" to Antigravity, to choose option "1" in response to a Antigravity query
- `antigravity-cli-send-2` (`C-c c 2`) - send "2" to Antigravity
- `antigravity-cli-send-3` (`C-c c 3`) - send "3" to Antigravity

## Working with Multiple Antigravity Instances

`antigravity-cli.el` supports running multiple Antigravity instances across different projects and directories. Each Antigravity instance is associated with a specific directory (project root, file directory, or current directory).

#### Instance Management

- When you start Antigravity with `antigravity-cli`, it creates an instance for the current directory
- If a Antigravity instance already exists for the directory, you'll be prompted to name the new instance (e.g., "tests", "docs")
- You can also use `antigravity-cli-new-instance` to explicitly create a new instance with a custom name
- Buffer names follow the format:
  - `*antigravity:/path/to/directory:instance-name*` (e.g., `*antigravity:/home/user/project:tests*`)
- If you're in a directory without a Antigravity instance but have instances running in other directories, you'll be prompted to select one
- Your selection is remembered for that directory, so you won't be prompted again

### Instance Selection

Commands that operate on an instance (`antigravity-send-command`, `antigravity-cli-switch-to-buffer`, `antigravity-cli-kill`, etc.) will prompt you for the Antigravity instance if there is more than one instance associated with the current buffer's project.

If the buffer file is not associated with a running Antigravity instance, you can select an instance running in a different project. This is useful when you want Antigravity to analyze dependent projects or files that you have checked out in sibling directories.

Antigravity-cli.el remembers which buffers are associated with which Antigravity instances, so you won't be repeatedly prompted. This association also helps antigravity-cli.el "do the right thing" when killing a Antigravity process and deleting its associated buffer.

### Multiple Instances Per Directory

You can run multiple Antigravity instances for the same directory to support different workflows:

- The first instance in a directory is the "default" instance
- Additional instances require a name when created (e.g., "tests", "docs", "refactor")
- When multiple instances exist for a directory, commands that interact with Antigravity will prompt you to select which instance to use
- Use `C-u antigravity-cli-switch-to-buffer` to see all Antigravity instances across all directories (not just the current directory)
- Use `antigravity-cli-select-buffer` as a dedicated command to always show all Antigravity instances across all directories

This allows you to have separate Antigravity conversations for different aspects of your work within the same project, such as one instance for writing cli and another for writing tests.

## Working in the Antigravity Buffer

antigravity-cli.el is designed to support using Antigravity CLI in Emacs using the minibuffer and regular Emacs buffers, with normal keybindings and full Emacs editing facilities. However, antigravity-cli.el also adds a few niceties for working in the Antigravity CLI terminal buffer:

You can type `C-g` as an alternative to escape. Also antigravity-cli.el supports several options for
entering newlines in the Antigravity CLI session:

- **Default (newline-on-shift-return)**: Press `Shift-Return` to insert a newline, `Return` to send your message
- **Alt-return style**: Press `Alt-Return` to insert a newline, `Return` to send
- **Shift-return to send**: Press `Return` to insert a newline, `Shift-Return` to send
- **Super-return to send**: Press `Return` to insert a newline, `Command-Return` (macOS) to send

You can change this behavior by customizing `antigravity-cli-newline-keybinding-style` (see [Customization](#customization)).

### Command Reference

- `antigravity-cli-transient` (`C-c c m`) - Show all commands (transient menu)
- `antigravity-cli` (`C-c c c`) - Start Antigravity. With prefix arg (`C-u`), switches to the Antigravity buffer after creating. With double prefix (`C-u C-u`), prompts for the project directory
- `antigravity-cli-start-in-directory` (`C-c c d`) - Prompt for a directory and start Antigravity there. With prefix arg (`C-u`), switches to the Antigravity buffer after creating
- `antigravity-cli-continue` (`C-c c C`) - Start Antigravity and continue the previous conversation. With prefix arg (`C-u`), switches to the Antigravity buffer after creating. With double prefix (`C-u C-u`), prompts for the project directory
- `antigravity-cli-resume` (`C-c c R`) - Resume a specific Antigravity session from an interactive list. With prefix arg (`C-u`), switches to the Antigravity buffer after creating. With double prefix (`C-u C-u`), prompts for the project directory
- `antigravity-cli-new-instance` (`C-c c i`) - Create a new Antigravity instance with a custom name. Always prompts for instance name, unlike `antigravity-cli` which uses "default" when no instances exist. With prefix arg (`C-u`), switches to the Antigravity buffer after creating. With double prefix (`C-u C-u`), prompts for the project directory
- `antigravity-cli-kill` (`C-c c k`) - Kill Antigravity session
- `antigravity-cli-kill-all` (`C-c c K`) - Kill ALL Antigravity instances across all directories
- `antigravity-cli-send-command` (`C-c c s`) - Send command to Antigravity. With prefix arg (`C-u`), switches to the Antigravity buffer after sending
- `antigravity-cli-send-command-with-context` (`C-c c x`) - Send command with current file and line context. With prefix arg (`C-u`), switches to the Antigravity buffer after sending
- `antigravity-cli-send-region` (`C-c c r`) - Send the current region or buffer to Antigravity. With prefix arg (`C-u`), prompts for instructions to add to the text. With double prefix (`C-u C-u`), adds instructions and switches to Antigravity buffer
- `antigravity-cli-send-file` - Send a specified file to Antigravity. Prompts for file path
- `antigravity-cli-send-buffer-file` (`C-c c o`) - Send the file associated with current buffer to Antigravity. With prefix arg (`C-u`), prompts for instructions to add to the file. With double prefix (`C-u C-u`), adds instructions and switches to Antigravity buffer
- `antigravity-cli-fix-error-at-point` (`C-c c e`) - Ask Antigravity to fix the error at the current point (works with flycheck, flymake, and any system that implements help-at-pt). With prefix arg (`C-u`), switches to the Antigravity buffer after sending
- `antigravity-cli-fork` (`C-c c f`) - Fork conversation (jump to previous conversation by sending escape-escape to Antigravity)
- `antigravity-cli-slash-commands` (`C-c c /`) - Access Antigravity slash commands menu
- `antigravity-cli-toggle` (`C-c c t`) - Toggle Antigravity window
- `antigravity-cli-switch-to-buffer` (`C-c c b`) - Switch to the Antigravity buffer. With prefix arg (`C-u`), shows all Antigravity instances across all directories
- `antigravity-cli-select-buffer` (`C-c c B`) - Select and switch to a Antigravity buffer from all running instances across all projects and directories
- `antigravity-cli-toggle-read-only-mode` (`C-c c z`) - Toggle between read-only mode and normal mode in Antigravity buffer (useful for selecting and copying text)
- `antigravity-cli-cycle-mode` (`C-c c M`) - Send Shift-Tab to Antigravity to cycle between default mode, auto-accept edits mode, and plan mode

- `antigravity-cli-send-return` (`C-c c y`) - Send return key to Antigravity (useful for confirming with Antigravity without switching to the Antigravity REPL buffer) (useful for responding with "Yes" to Antigravity)
- `antigravity-cli-esc` (`C-c c E` or `C-c c ESC`) - Send escape key to Antigravity (useful for saying "No" when Antigravity asks for confirmation or to cancel a running action without switching to the Antigravity REPL buffer) (alias: `antigravity-cli-send-escape`)
- `antigravity-cli-send-1` (`C-c c 1`) - Send "1" to Antigravity (useful for selecting the first option when Antigravity presents a numbered menu)
- `antigravity-cli-send-2` (`C-c c 2`) - Send "2" to Antigravity (useful for selecting the second option when Antigravity presents a numbered menu)
- `antigravity-cli-send-3` (`C-c c 3`) - Send "3" to Antigravity (useful for selecting the third option when Antigravity presents a numbered menu)

## Desktop Notifications

antigravity-cli.el notifies you when Antigravity finishes processing and is waiting for input. By default, it displays a message in the minibuffer and pulses the modeline for visual feedback.

### macOS Native Notifications

To use macOS native notifications with sound, add this to your configuration:

```elisp
(defun my-antigravity-notify (title message)
  "Display a macOS notification with sound."
  (call-process "osascript" nil nil nil
                "-e" (format "display notification \"%s\" with title \"%s\" sound name \"Glass\""
                             message title)))

(setq antigravity-cli-notification-function #'my-antigravity-notify)
```

This will display a system notification with a "Glass" sound effect when Antigravity is ready. You can change the sound name to any system sound (e.g., "Ping", "Hero", "Morse", etc.) or remove the `sound name` part for silent notifications.

### Linux Native Notifications

For Linux desktop notifications, you can use `notify-send` (GNOME/Unity) or `kdialog` (KDE):

```elisp
;; For GNOME/Unity desktops
(defun my-antigravity-notify (title message)
  "Display a Linux notification using notify-send."
  (if (executable-find "notify-send")
      (call-process "notify-send" nil nil nil title message)
    (message "%s: %s" title message)))

(setq antigravity-cli-notification-function #'my-antigravity-notify)
```

To add sound on Linux:

```elisp
(defun my-antigravity-notify-with-sound (title message)
  "Display a Linux notification with sound."
  (when (executable-find "notify-send")
    (call-process "notify-send" nil nil nil title message))
  ;; Play sound if paplay is available
  (when (executable-find "paplay")
    (call-process "paplay" nil nil nil "/usr/share/sounds/freedesktop/stereo/message.oga")))

(setq antigravity-cli-notification-function #'my-antigravity-notify-with-sound)
```

### Windows Native Notifications

For Windows, you can use PowerShell to create toast notifications:

```elisp
(defun my-antigravity-notify (title message)
  "Display a Windows notification using PowerShell."
  (call-process "powershell" nil nil nil
                "-NoProfile" "-Command"
                (concat "[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null; "
                        "$template = '<toast><visual><binding template=\"ToastGeneric\"><text>" title "</text><text>" message "</text></binding></visual></toast>'; "
                        "$xml = New-Object Windows.Data.Xml.Dom.XmlDocument; "
                        "$xml.LoadXml($template); "
                        "$toast = [Windows.UI.Notifications.ToastNotification]::new($xml); "
                        "[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('Emacs').Show($toast)")))

(setq antigravity-cli-notification-function #'my-antigravity-notify)
```

*Note: Linux and Windows examples are untested. Feedback and improvements are welcome!*

## Tips and Tricks

- **Paste images**: Use `C-v` to paste images into the Antigravity window. Note that on macOS, this is `Control-v`, not `Command-v`.
- **Paste text**: Use `C-y` (`yank`) to paste text into the Antigravity window. 
- **Save files before sending commands**: Antigravity reads files directly from disk, not from Emacs buffers. Always save your files (`C-x C-s`) before sending commands that reference file content. Consider enabling `global-auto-revert-mode` to automatically sync Emacs buffers with file changes made by Antigravity:
  ```elisp
  (global-auto-revert-mode 1)
  ;; If files aren't reliably auto-reverting after Antigravity makes changes,
  ;; disable file notification and use polling instead:
  (setq auto-revert-use-notify nil)
  ``` 

## Customization

```elisp
;; Set your key binding for the command map.
(global-set-key (kbd "C-c C-a") antigravity-cli-command-map)

;; Set terminal type for the Antigravity terminal emulation (default is "xterm-256color").
;; This determines terminal capabilities like color support.
;; See the documentation for eat-term-name for more information.
(setq antigravity-cli-term-name "xterm-256color")

;; Change the path to the Antigravity executable (default is "agy").
;; Useful if Antigravity is not in your PATH or you want to use a specific version.
(setq antigravity-cli-program "/usr/local/bin/agy")

;; Set command line arguments for Antigravity
;; For example, to enable verbose output
(setq antigravity-cli-program-switches '("--verbose"))

;; Add hooks to run after Antigravity is started
(add-hook 'antigravity-cli-start-hook 'my-antigravity-setup-function)

;; Adjust initialization delay (default is 0.1 seconds)
;; This helps prevent terminal layout issues if the buffer is displayed before Antigravity is fully ready.
(setq antigravity-cli-startup-delay 0.2)

;; Configure the buffer size threshold for confirmation prompt (default is 100000 characters)
;; If a buffer is larger than this threshold, antigravity-cli-send-region will ask for confirmation
;; before sending the entire buffer to Antigravity.
(setq antigravity-cli-large-buffer-threshold 100000)

;; Configure key binding style for entering newlines and sending messages in Antigravity buffers.
;; Available styles:
;;   'newline-on-shift-return - S-return inserts newline, RET sends message (default)
;;   'newline-on-alt-return   - M-return inserts newline, RET sends message
;;   'shift-return-to-send    - RET inserts newline, S-return sends message
;;   'super-return-to-send    - RET inserts newline, s-return sends message (Command+Return on macOS)
(setq antigravity-cli-newline-keybinding-style 'newline-on-shift-return)

;; Enable or disable notifications when Antigravity finishes and awaits input (default is t).
(setq antigravity-cli-enable-notifications t)

;; Customize the notification function (default is antigravity-cli--default-notification).
;; The function should accept two arguments: title and message.
;; The default function displays a message and pulses the modeline for visual feedback.
(setq antigravity-cli-notification-function 'antigravity-cli--default-notification)

;; Example: Use your own notification function
(defun my-antigravity-notification (title message)
  "Custom notification function for Antigravity CLI."
  ;; Your custom notification logic here
  (message "[%s] %s" title message))
(setq antigravity-cli-notification-function 'my-antigravity-notification)

;; Configure kill confirmation behavior (default is t).
;; When t, antigravity-cli-kill prompts for confirmation before killing instances.
;; When nil, kills Antigravity instances without confirmation.
(setq antigravity-cli-confirm-kill t)

;; Enable/disable window resize optimization (default is t)
;; When enabled, terminal reflows are only triggered when window width changes,
;; not when only height changes. This prevents unnecessary redraws when splitting
;; windows vertically, improving performance and reducing visual artifacts.
;; Set to nil if you experience issues with terminal display after resizing.
(setq antigravity-cli-optimize-window-resize t)

;; Enable/disable no-delete-other-windows parameter (default is nil)
;; When enabled, Antigravity CLI windows have the no-delete-other-windows
;; parameter set. This prevents the Antigravity window from being closed
;; when you run delete-other-windows or similar commands, keeping the
;; Antigravity buffer visible and accessible.
(setq antigravity-cli-no-delete-other-windows t)
```

### Customizing Window Position

You can control how the Antigravity Cli window appears using Emacs' `display-buffer-alist`. For example, to make the Antigravity window appear in a persistent side window on the right side of your screen with 33% width:

```elisp
(add-to-list 'display-buffer-alist
                 '("^\\*antigravity"
                   (display-buffer-in-side-window)
                   (side . right)
                   (window-width . 90)))
```

This layout works best on wide screens.

### Font Setup

Antigravity CLI uses a lot of special unicode characters, and most common programming fonts don't include them all. To ensure that Antigravity renders special characters correctly in Emacs, you need to either use a font with really good unicode support, or set up fallback fonts for Emacs to use when your preferred font does not have a character. 

### Using System Fonts as Fallbacks

If you don't want to install any new fonts, you can use fonts already on your system as fallbacks. Here's a good setup for macOS, assuming your default, preferred font is "Maple Mono".  Substitute "Maple Mono" with whatever your default font is, and add this to your `init.el` file:

```elisp
;; important - tell emacs to use our fontset settings
(setq use-default-font-for-symbols nil)

;; add least preferred fonts first, most preferred last
(set-fontset-font t 'symbol "STIX Two Math" nil 'prepend)
(set-fontset-font t 'symbol "Zapf Dingbats" nil 'prepend)
(set-fontset-font t 'symbol "Menlo" nil 'prepend)

;; add your default, preferred font last
(set-fontset-font t 'symbol "Maple Mono" nil 'prepend)
```

The configuration on Linux or Windows will depend on the fonts available on your system. To test if
your system has a certain font, evaluate this expression:

```elisp
(find-font (font-spec :family "DejaVu Sans Mono"))
```

On Linux it might look like this:

```elisp
(setq use-default-font-for-symbols nil)
(set-fontset-font t 'symbol "DejaVu Sans Mono" nil 'prepend)

;; your preferred, default font:
(set-fontset-font t 'symbol "Maple Mono" nil 'prepend)
```

### Using JuliaMono as Fallback

A cross-platform approach is to install a fixed-width font with really good unicode symbols support. 
[JuliaMono](https://juliamono.netlify.app/) has excellent Unicode symbols support. To let the Antigravity CLI buffer use Julia Mono for rendering Unicode characters while still using your default font for ASCII characters add this elisp code:

```elisp
(setq use-default-font-for-symbols nil)
(set-fontset-font t 'unicode (font-spec :family "JuliaMono"))

;; your preferred, default font:
(set-fontset-font t 'symbol "Maple Mono" nil 'prepend)
```

### Using a Custom Antigravity CLI Font

If instead you want to use a particular font just for the Antigravity CLI REPL but use a different font
everywhere else you can customize the `antigravity-cli-repl-face`:

```elisp
(custom-set-faces
   '(antigravity-cli-repl-face ((t (:family "JuliaMono")))))
```

(If you set the Antigravity CLI font to "JuliaMono", you can skip all the fontset fallback configurations above.)

### Reducing Flickering on Window Configuration Changes

To reduce flickering in the Antigravity buffer on window configuration changes, you can adjust eat latency variables in a hook. This reduces flickering at the cost of some increased latency:

```elisp
  ;; reduce flickering
  (add-hook 'antigravity-cli-start-hook
            (lambda ()
              (setq-local eat-minimum-latency 0.033
                          eat-maximum-latency 0.1)))
```

*Note*: Recent changes to antigravity-cli.el have fixed flickering issues, making customization of these latency values less necessary. 

### Fixing Spaces Between Vertical Bars

If you see spaces between vertical bars in Antigravity's output, you can fix this by adjusting the `line-spacing` value. For example:

```elisp
;; Set line spacing to reduce gaps between vertical bars
(setq line-spacing 0.1)
```

Or to apply it only to Antigravity buffers:

```elisp
(add-hook 'antigravity-cli-start-hook
          (lambda ()
            ;; Reduce line spacing to fix vertical bar gaps
            (setq-local line-spacing 0.1))) 
```


### Eat-specific Customization

When using the eat terminal backend, there are additional customization options available:

```elisp
;; Customize cursor type in read-only mode (default is '(box nil nil))
;; The format is (CURSOR-ON BLINKING-FREQUENCY CURSOR-OFF)
;; Cursor type options: 'box, 'hollow, 'bar, 'hbar, or nil
(setq antigravity-cli-eat-read-only-mode-cursor-type '(bar nil nil))

;; Control eat scrollback size for longer conversations
;; The default is 131072 characters, which is usually sufficient
;; For very long Antigravity sessions, you may want to increase it
;; WARNING: Setting to nil (unlimited) is NOT recommended with Antigravity CLI
;; as it can cause severe performance issues with long sessions
(setq eat-term-scrollback-size 500000)  ; Increase to 500k characters
```

### Vterm-specific Customization

When using the vterm terminal backend, there are additional customization options available:

```elisp
;; Enable/disable buffering to prevent flickering on multi-line input (default is t)
;; When enabled, vterm output that appears to be redrawing multi-line input boxes
;; will be buffered briefly and processed in a single batch
;; This prevents flickering when Antigravity redraws its input box as it expands
(setq antigravity-cli-vterm-buffer-multiline-output t)

;; Control the delay before processing buffered vterm output (default is 0.01)
;; This is the time in seconds that vterm waits to collect output bursts
;; A longer delay may reduce flickering more but could feel less responsive
;; The default of 0.01 seconds (10ms) provides a good balance
(setq antigravity-cli-vterm-multiline-delay 0.01)
```

#### Vterm Scrollback Configuration

Vterm has its own scrollback limit that is separate from antigravity-cli.el settings. By default, vterm limits scrollback to 1000 lines. To allow scrolling back to the top of long Antigravity conversations, you can increase `vterm-max-scrollback`:

```elisp
;; Increase vterm scrollback to 100000 lines (the maximum allowed)
;; Note: This increases memory usage
(setq vterm-max-scrollback 100000)
```

If you prefer not to set this globally, you can set it only for Antigravity buffers using a hook:

```elisp
(add-hook 'antigravity-cli-start-hook
          (lambda ()
            ;; Only increase scrollback for vterm backend
            (when (eq antigravity-cli-terminal-backend 'vterm)
              (setq-local vterm-max-scrollback 100000))))
```

This ensures that only Antigravity buffers have increased scrollback, while other vterm buffers maintain the default limit.

#### Vterm Window Width Configuration

Vterm has a minimum window width setting that affects how text wraps. By default, `vterm-min-window-width` is set to 80 columns. If you resize the Antigravity window to be narrower than this limit, the Antigravity input box may wrap incorrectly, causing display issues.

If you prefer to use Antigravity in a narrow window (for example, in a side window), you can adjust `vterm-min-window-width`. Note that this must be set as a custom variable, either via `custom-set-variables` or `setop`, `setq` won't work:

```elisp
;; Allow vterm windows to be as narrow as 40 columns
(setopt vterm-min-window-width 40)
```

This is particularly useful if you like to keep Antigravity in a narrow side window while coding in your main window.

#### Vterm Timer Delay

The `vterm-timer-delay` variable controls how often vterm refreshes its buffer when receiving data. This delay (in seconds) helps manage performance when processing large amounts of output. Setting it to `nil` disables the delay entirely.

The default value of `0.1` seconds works well with Antigravity CLI. Since Antigravity often sends large bursts of data when generating code or explanations, reducing this delay or disabling it (`nil`) can significantly degrade performance. Stick with the default, or use a slightly higher value  unless you experience specific display issues. 

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the Apache License 2.0 - see the LICENSE file for details.

