# Todo Show Package [![Build Status](https://travis-ci.org/mrodalgaard/atom-todo-show.svg)](https://travis-ci.org/mrodalgaard/atom-todo-show)

Finds all the TODO, FIXME, CHANGED, XXX, IDEA, HACK, NOTE, REVIEW comments in your project. Or anything else you want to fetch through settings.

Open using command palette `Todo Show: Find In Project` or `Todo Show: Find In Open Files`. Keyboard shortcuts <kbd>CTRL</kbd> + <kbd>SHIFT</kbd> + <kbd>T</kbd> on Mac OSX or <kbd>ALT</kbd> + <kbd>SHIFT</kbd> + <kbd>T</kbd> on Windows and Linux.

![todo-show-package](https://raw.githubusercontent.com/mrodalgaard/atom-todo-show/master/screenshots/preview.png)

## Config

* __findTheseRegexes__: An array of titles and regexes to look for (`['title1', 'regex1', 'title2', 'regex2', ...]`). Look at the "Regex Details" section below for more information.
* __ignoreThesePaths__: An array of files / folders to exclude (syntax according to [scandal](https://github.com/atom/scandal) used internally by Atom).
  - __globally__: `Ignored Names` from atom core settings.
  - __locally__: Ignores anything in your `.gitignore` file if the current project is a valid git repository and atom core setting `Exclude VCS Ignored Paths` is checked.
* __openListInDirection__: Defines where the todo list is shown.
* __groupMatchesBy__: Sets the grouping / sorting of matches.
* __rememberViewSize__: Remember the todo list width or split in the middle.

## Regex Details

The regexes in `findTheseRegexes` are used for searching the workspace for todo matches. They are configurable to match the users specific needs.

Default regex form: `'/\\b@?TODO:?\\d*($|\\s.*$)/g'`
* `@?`: an optional @ in front of todo
* `TODO`: the todo string itself
* `:?` an optional semicolon after todo
* `\d*` optional digits for supporting the [imdone](http://imdone.io/) sorting
* `$` to end todos without additional text (newline)
* Or `\s.*$` to match the todo text with a non-optional space in front
* As the config only accepts strings all `\` characters are also escaped.

To extend the default list of regexes the existing array needs to be copied into your config.cson. See [show-todo.coffee](https://github.com/mrodalgaard/atom-todo-show/blob/master/lib/show-todo.coffee#L12) for current defaults.

# To contribute
1. `$ git clone https://github.com/mrodalgaard/atom-todo-show.git` to e.g. ~/github/
2. `$ apm link` in your cloned repo to symlink your version for atom development mode
3. Open `~/github/atom-todo-show` in atom dev mode (View -> Developer -> Open in Dev Mode) or `atom -d`
4. Make your changes.
5. Reload atom to see the package changes take effect (View -> Reload)
6. Test it.
7. Issue your PR.
8. Optionally `apm unlink` to remove the symlink
