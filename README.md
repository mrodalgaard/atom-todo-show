# TODO-show package

Fetches TODO, FIXME, CHANGED, XXX comments from the project. Or anything else you want (settings).

![](https://raw.github.com/jamischarles/atom-todo-show/master/screenshots/preview.png)

## Exculde files/folders from scan
__globally__:
- `Ignored Names` from atom core settings
- `todo-show.ignoreThesePaths` in package settings (Syntax according to [.gitignore](http://git-scm.com/docs/gitignore)

__locally__: Ignores anything in your .gitignore file if the current project is a valid git repository and atom core setting `Exclude VCS Ignored Paths` is checked.

## Coming features (PR's welcome)
- ~~TODO, FIXME, CHANGED included in search~~
- ~~ignore /vendor, /node_modules~~
- goto result should start at comment, NOT at todo symbol
- don't open multiple search windows when we search multiple times
- how do we handle file changes?
- nicer styling
- ignore TODOs outside of comment blocks
- have nice message when no results are found
- refactor and clean up code
- ~~fix / add keymap shortcut~~
- add test cases

Inspired by the textmate TODO bundle.
