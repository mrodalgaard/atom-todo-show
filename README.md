# TODO-show package

Fetches TODO, FIXME, CHANGED, XXX comments from the project. Or anything else you want (settings).

![](https://raw.github.com/jamischarles/atom-todo-show/master/screenshots/preview.png)

## Exculde files/folders from scan
__globally__:
- `Ignored Names` from atom core settings
- `todo-show.ignoreThesePaths` in package settings (Syntax according to [.gitignore](http://git-scm.com/docs/gitignore))

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

# To contribute
1. `$ git clone https://github.com/jamischarles/atom-todo-show.git` (easiest is) to ~/github/
2. `$ rm -rf ~/.atom/packages/todo-show` to remove the installed package (or from settings)
3. `$ apm link` in your cloned repo (~/github/atom-todo-show) to symlink your version so atom will load that
4. Open `~/github/atom-todo-show` in atom dev mode (View -> Developer -> Open in Dev Mode)
5. Make your changes.
6. Reload your atom to see the package changes take effect (View -> Reload)
7. Test it.
8. Issue your PR.
9. Restore the package back normally (you can repeat #2, then reinstall it the official way)
