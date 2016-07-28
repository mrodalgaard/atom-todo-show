## 1.7.0
- Option to show status bar count
- Loading bug fixed
- Faster startup

## 1.6.0
- Fix left splitting list
- Handle unsaved files
- Open multi-project file bug fix

## 1.5.0
- Search project option
- Support pending tabs
- Use text before todo if empty after
- Can show file and path
- Accept other separators
- Improved readme
- Support Google style guide

## 1.4.0
- Major performance improvement by only using one regex
- Handle duplicate todos
- Better doc and settings view
- Show todo count in bar title

## 1.3.0
- Minor internal improvements
- Model restructure

## 1.2.0
- Filter todos input field
- Extract todo tags
- Save todos as markdown table
- Links in saved markdown

## 1.1.0
- Internal improvements

## 1.0.0
- New package owner (@mrodalgaard)
- Total code refactor
- Improved config
- Options dialog
- Update table upon save
- TODOs in flexible table
- Travis CI

## 0.16.0
- Use native exclude for ignoreThesePaths
- Notification on invalid config input
- Tab icon

## 0.15.0
- Improved default regex with full description
- Respect imdone numbering syntax
- Support for empty todos (e.g. // TODO)

## 0.14.0
- Group matches by regex, file or none (groupMatchesBy config)
- Remember todo list width (rememberViewSize config)
- Improved markdown output when saving todo list
- Remove PHP comment endings

## 0.13.0
- Enforce a trailing space on todos
- Add line numbers to saved output

## 0.12.0
- Do not show match groups with no matches
- Show what happened when no matches where found
- Command to only scan todos in open files (find-in-open-files)

## 0.11.0
- Use alt+shift+t on windows and linux
- Same patterns as language-todo, thanks @KylePDavis
- Work on reopen tabs
- Line break long match texts
- Scan progress when loading todos

## 0.10.0
- Strip common block comment endings
- Truncate matches over 120 characters
- Configurable where the pane opens with openListInDirection
- Updated styling
- Save and refresh buttons

## 0.9.0
- Removed all deprecation calls for Atom 1.0
- Valid ignore syntax for node_modules, vendor and bower_components
- Toggle todo view
- Working keymap ctrl-shift-t
- New maintainer of atom-todo-show @MRodalgaard

## 0.8.0
- Change how the ignore paths are handled.
- https://github.com/jamischarles/atom-todo-show/pull/35
- Thanks andischerer

## 0.7.0
- Change color scheme to inherit from the UI theme
- https://github.com/jamischarles/atom-todo-show/pull/32
- Thanks mthadley

## 0.6.1
- Fix deprecation errors
- https://github.com/jamischarles/atom-todo-show/pull/38
- Thanks @framerate.

## 0.6.0
- ignore /vendor and /node_modules
- colon after token is optional
- added 'XXX' as a token to find
- Fixed keybinding
- Added some test cases
