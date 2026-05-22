# Changelog

All notable changes to antigravity-cli.el will be documented in this file.
## RoadMap
Support multiple ai CLI tools
- [ ] qwen code
- [ ] ...

## [1.0.0]
totally support antigravity-cli

### [0.4.3]

### Added
- New `antigravity-cli-vterm-multiline-delay` customization variable to control the delay before processing buffered vterm output
  - Default value changed from 0.001 to 0.01 seconds (10ms) to better reduce flickering
  - Allows fine-tuning the balance between flickering reduction and responsiveness
  
### Fixed
- Fix bug in eat keybindings 

## [0.4.2]

### Changed
- File references now use `@file:line` format instead of verbose context format

## [0.4.1]

### Changed
- upgrade to the latest transient release

## [0.4.0]

### Changed
- `antigravity-cli-eat-never-truncate-antigravity-buffer` is now obsolete
  - Setting it to t can consume excessive memory and cause performance issues with long sessions
  - The variable will be removed in a future release

### Added

- New `antigravity-cli-eat` customization group for eat backend specific settings
  - All eat-specific faces moved to this group with `antigravity-cli-eat-` prefix
  - Faces can be customized via `M-x customize-group RET antigravity-cli-eat RET`
- vterm support
  - New `antigravity-cli-terminal-backend` customization variable to choose between eat (default) and vterm
  - New `antigravity-cli-vterm` customization group for vterm-specific settings
  - `antigravity-cli-vterm-buffer-multiline-output` prevents flickering when Antigravity redraws multi-line input boxes
- New `antigravity-cli-newline-keybinding-style` customization variable to configure how return and modifier keys behave in Antigravity buffers
  - `'default` (default): M-return inserts newline, RET sends message
  - `'newline-on-return`: RET inserts newline, M-return sends message
  - `'newline-on-shift-return`: RET sends message, S-return inserts newline
  - `'super-return-to-send`: RET inserts newline, s-return sends message
- Single ESC key now works as expected in Antigravity buffers for canceling operations
- C-g can be used as an alternative to ESC for canceling in Antigravity buffers
- New `antigravity-cli-confirm-kill` customization variable to control kill confirmation prompts
  - When `t` (default), prompts for confirmation before killing Antigravity instances
  - When `nil`, kills Antigravity instances without confirmation
- New `antigravity-cli-continue` command to explicitly continue previous conversations
  - Bound to `C-c c C` in the command map
  - Supports same prefix arguments as `antigravity-cli` command
- New `antigravity-cli-resume` command to resume specific past sessions
  - Bound to `C-c c R` in the command map
  - Allows resuming any past session from an interactive list
  - Can programmatically resume a specific session by ID
  - Supports same prefix arguments as `antigravity-cli` command
- New `antigravity-cli-start-in-directory` command for convenience
  - Bound to `C-c c d` in the command map
  - Always prompts for directory (equivalent to `C-u C-u antigravity-cli`)
  - With prefix arg, switches to buffer after creating
- New `antigravity-cli-new-instance` command to create a new Antigravity instance with a custom name
  - Bound to `C-c c i` in the command map
  - Always prompts for instance name (unlike `antigravity-cli` which uses "default" for the first instance)
  - Supports same prefix arguments as `antigravity-cli` command
- New `antigravity-cli-select-buffer` command to select from all Antigravity instances
  - Bound to `C-c c B` in the command map
  - Shows all Antigravity instances across all projects and directories
  - Provides a dedicated command for global instance selection (similar to `C-u antigravity-cli-switch-to-buffer`)
- New `antigravity-cli-kill-all` command to kill all Antigravity instances
  - Bound to `C-c c K` in the command map
  - Kills all Antigravity instances across all projects and directories
  - Provides dedicated functionality previously available via `C-u antigravity-cli-kill`
- New notification system for when Antigravity finishes processing and awaits input
  - `antigravity-cli-enable-notifications` customization variable to toggle notifications (default: t)
  - `antigravity-cli-notification-function` customization variable to set custom notification behavior
  - Default notification displays a message and pulses the modeline for visual feedback
- New `antigravity-cli-optimize-window-resize` customization variable to prevent unnecessary terminal reflows
  - When enabled (default), terminal only reflows when window width changes, not height
  - Improves performance and reduces visual artifacts when splitting windows vertically

### Changed

- Renamed internal variable from `antigravity-cli-key-binding-style` to `antigravity-cli-newline-keybinding-style` for clarity
- Simplified `antigravity-cli` command prefix arguments:
  - Single prefix (`C-u`) now switches to buffer after creating
  - Double prefix (`C-u C-u`) now prompts for project directory
  - Removed support for continuing conversations (use `antigravity-cli-continue` instead)
- `antigravity-cli-kill` no longer accepts prefix arguments
  - Use the new `antigravity-cli-kill-all` command to kill all instances

### Fixed

- Fixed startup error "Symbol's function definition is void: (setf eat-term-parameter)" that occurred when starting antigravity-cli for the first time
  - Added proper compile-time handling of eat package dependencies

## [0.3.8]

### Added

- New `antigravity-cli-never-truncate-antigravity-buffer` customization variable to disable truncation of Antigravity output buffer
  - When set to `t`, disables Eat's scrollback size limit, allowing Antigravity to output unlimited content without truncation
  - Useful when working with large Antigravity responses
  - Defaults to `nil` to maintain backward compatibility

## [0.3.7]

### Added

- New quick response commands for numbered menu selection:
  - `antigravity-cli-send-1` (`C-c c 1`) - Send "1" to select first option in Antigravity menus
  - `antigravity-cli-send-2` (`C-c c 2`) - Send "2" to select second option
  - `antigravity-cli-send-3` (`C-c c 3`) - Send "3" to select third option
- New `antigravity-cli-cycle-mode` command (`C-c c TAB`) to send Shift-Tab to Antigravity for cycling between default mode, auto-accept edits mode, and plan mode
- Added "Quick Responses" section to transient menu grouping numbered and yes/no responses

### Changed

- Excluded experimental `sockets-mcp/` directory from version control via .gitignore

## [0.3.6]

### Changed

- Added confirmation prompts before killing Antigravity instances to prevent accidental termination (thanks to [microamp](https://github.com/microamp))
  - `antigravity-cli-kill` now asks "Kill Antigravity instance?" before terminating
  - With prefix arg (`C-u`), asks for confirmation before killing all instances

## [0.3.5]

### Fixed

- Potential fix for issue #29: check if eat process is still running before adjusting antigravity buffer window size

## [0.3.4]

### Fixed

- Do not move to end of buffer when in eat-emacs-mode (read-only mode)

## [0.3.3]

### Fixed 

- Fixed `antigravity-cli-send-command-with-context` and `antigravity-cli-fix-error-at-point` to use full absolute paths for files outside of projects, ensuring commands work correctly with non-project files.

## [0.3.2]

### Fixed

- Further reduce flickering by only telling the Antigravity process about window resize events when the _width_ of the Antigravity window has changed. When the width has changed, Antigravity needs to redraw the prompt input box. But when only the height has changed, Antigravity does not have to re-create everything. This greatly reduces flickering that can occur when editing while a Antigravity window is open in Emacs.

## [0.3.1]

### Fixed

- Fixed bug using `antigravity-cli-send-command-with-context` and `antigravity-cli-fix-error-at-point` when invoked outside of a project, where it incorrectly prompted for a project.

## [0.3.0]

### Added

- **New feature**: Launch repository-specific Antigravity sessions - work on multiple projects simultaneously with separate Antigravity instances
- **New feature**: Support for multiple named Antigravity instances per directory (e.g., one for coding, another for tests)
  - Prompts for instance name when creating additional instances in the same directory
  - Buffer names now include instance names: `*antigravity:/path/to/project:instance-name*`
- Intelligent instance selection: When switching between directories, antigravity-cli.el prompts to select from existing Antigravity instances or start a new one
- Instance memory: Your Antigravity instance selections are remembered per directory during the current Emacs session
- Simplified startup behavior: `antigravity-cli` now automatically detects the appropriate directory (project root, current file directory, or default directory)
- Added prefix arg support to `antigravity-cli-switch-to-buffer` - use `C-u` to see all Antigravity instances across all directories
- Added prefix arg support to `antigravity-cli-kill` - use `C-u` to kill ALL Antigravity instances across all directories

### Changed

- Improved performance by reducing terminal reflows - Antigravity windows now only trigger terminal resizing when width changes, not height

- Antigravity buffer names now use abbreviated file paths for better readability (e.g., `*antigravity:~/projects/myapp*`)
- Reorganized prefix arguments for `antigravity-cli` command:
  - Single prefix (`C-u`) now switches to buffer after creating (more commonly used)
  - Double prefix (`C-u C-u`) continues previous conversation (unchanged)
  - Triple prefix (`C-u C-u C-u`) prompts for project directory (previously single prefix)

### Removed

- Removed `antigravity-cli-current-directory` command - its functionality is now integrated into the main `antigravity-cli` command
- Removed limitation of only supporting one Antigravity process at a time

## [0.2.5] - 2025-06-06

### Added
- New `antigravity-cli-fork` command to jump to previous conversations by sending escape-escape to Antigravity
  - Bound to `C-c c f` in the command map
  - Available in the transient menu

### Fixed
- Disabled unnecessary shell integration features (command history and prompt annotation) to improve performance

### Changed

## [0.2.4] - 2025-06-05

### Added

- New `antigravity-cli-fork` command to jump to previous conversations by sending escape-escape to Antigravity
  - Bound to `C-c c f` in the command map
  - Available in the transient menu

### Changed
- `antigravity-cli-kill` now shows a message instead of throwing an error when Antigravity is not running

### Changed
-  `antigravity-cli-kill` now shows a message instead of throwing an error when Antigravity is not running

## [0.2.3] - 2025-05-23

### Fixed
- Fixed Antigravity buffer jumping to top when editing in other windows (#8)

## [0.2.2] - 2025-05-22

### Added
- Support for continuing previous conversations with double prefix arg (`C-u C-u`) in `antigravity-cli` and `antigravity-cli-current-directory` commands
    - Uses Antigravity's `--continue` flag to resume previous sessions
- Read-only mode for text selection in Antigravity terminal. Toggle with `antigravity-cli-toggle-read-only-mode`.
- Customizable cursor appearance in read-only mode via `antigravity-cli-read-only-mode-cursor-type`

## [0.2.1] - 2025-05-01

### Added
- Extended `antigravity-cli-fix-error-at-point` to support flymake and any system implementing help-at-pt

### Changed
- Fixed compiler warnings (thanks to [ncaq](https://github.com/ncaq))

## [0.2.0] - 2025-04-22

### Added
- New `antigravity-cli-fix-error-at-point` function to help fix flycheck errors. A flymake version will come later.
- Adding option to prompt for extra input in `antigravity-cli-send-region`.
- Confirm before sending large regions or buffers in `antigravity-cli-send-region`. The customization variable `antigravity-cli-large-buffer-threshold` determines what is "large". 
- Added gitleaks pre-commit hook for security

### Changed
- Renamed functions to follow elisp naming conventions:
  - `antigravity-fix-error-at-point` → `antigravity-cli-fix-error-at-point`
  - `antigravity--format-flycheck-errors-at-point` → `antigravity-cli--format-flycheck-errors-at-point`
- Removed prefix key customization in favor of manual key binding, fixes #2. 
- Updated Makefile to disable sentence-end-double-space
- Enhanced documentation for flycheck integration and build process

