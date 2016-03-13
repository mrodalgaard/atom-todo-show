# Todo Show Package [![Build Status](https://travis-ci.org/mrodalgaard/atom-todo-show.svg)](https://travis-ci.org/mrodalgaard/atom-todo-show)

Finds all TODO, FIXME, CHANGED, XXX, IDEA, HACK, NOTE, REVIEW comments in your project and shows them in a nice overview tab.

Open using command palette `Todo Show: Find In Project` or `Todo Show: Find In Open Files`. Keyboard shortcuts <kbd>CTRL</kbd> + <kbd>SHIFT</kbd> + <kbd>T</kbd> on Mac OSX or <kbd>ALT</kbd> + <kbd>SHIFT</kbd> + <kbd>T</kbd> on Windows and Linux.

![todo-show-package](https://raw.githubusercontent.com/mrodalgaard/atom-todo-show/master/screenshots/preview.png)

## Config

* __findTheseTodos__: An array of todo types used by the search regex (`['FIXME', 'TODO', ...]`).
* __findUsingRegex__: Regex string used to find all your todos. `${TODOS}` is replaced with `findTheseTodos` from above. See the "Regex Details" section below for more information.
* __ignoreThesePaths__: An array of files / folders to exclude (syntax according to [scandal](https://github.com/atom/scandal) used internally by Atom).
  - __globally__: `Ignored Names` from atom core settings.
  - __locally__: Ignores anything in your `.gitignore` file if the current project is a valid git repository and atom core setting `Exclude VCS Ignored Paths` is checked.
* __showInTable__: An array of properties to show for each todo in table.
* __sortBy__: Sort table by this todo property.
* __sortAscending__: Sort table in ascending or descending order.
* __openListInDirection__: Defines where the todo list is shown.
* __rememberViewSize__: Remember the todo list width or split in the middle.
* __saveOutputAs__: Choose which format to use for saved markdown.

## Regex Details

The regexes in `findTheseRegexes` are used for searching the workspace for todo matches. They are configurable to match the users specific needs.

Default regex form: `'/\\b(${TODOS}):?\\d*($|\\s.*$)/g'`
* `\b` start at word boundary
* `${TODOS}` todo type match (is replaced with `findTheseTodos`)
* `:?` optional semicolon after type
* `\d*` optional digits for supporting [imdone](http://imdone.io/) sorting
* `$` to end todos without additional text (newline)
* Or `\s.*$` to match the todo text with a non-optional space in front
* Because Atom config only accepts strings all `\` characters are also escaped.

To extend the default todo types and search regex, the existing config needs to be copied into your config.cson. See [show-todo.coffee](https://github.com/mrodalgaard/atom-todo-show/blob/master/lib/show-todo.coffee) for current defaults.

## Credits
Created by [Jamis Charles](https://github.com/jamischarles)

Maintained by [Martin Rodalgaard](https://github.com/mrodalgaard)
