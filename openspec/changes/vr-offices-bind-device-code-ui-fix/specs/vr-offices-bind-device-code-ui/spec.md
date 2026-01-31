## ADDED Requirements

### Requirement: Desk context menu label is English
When the operator right-clicks a desk, the context menu SHALL include an item labeled `Bind Device Code…`.

#### Scenario: Context menu shows English bind label
- **WHEN** the operator right-clicks a desk
- **THEN** the context menu contains an item labeled `Bind Device Code…`

### Requirement: Bind-device-code dialog is readable
When the operator opens the bind-device-code dialog, it SHALL open with a minimum width of **640 px** so its title, hint text, and controls are not truncated at the default UI scale.

#### Scenario: Dialog opens with minimum width
- **WHEN** the operator selects `Bind Device Code…` from the desk context menu
- **THEN** the bind-device-code dialog opens with width greater than or equal to **640 px**
