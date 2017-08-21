const {CompositeDisposable} = require('event-kit')

const ShowTodoView = require('./todo-view')
const TodoCollection = require('./todo-collection')
const TodoIndicatorView = require('./todo-indicator-view')

module.exports =
class TodoShow {
  constructor() {
    this.URI = 'atom://todo-show'
  }

  activate() {
    this.createCollection()

    this.disposables = new CompositeDisposable
    this.disposables.add(atom.commands.add('atom-workspace', {
      'todo-show:toggle': () => this.show(),
      'todo-show:find-in-workspace': () => this.show('workspace'),
      'todo-show:find-in-project': () => this.show('project'),
      'todo-show:find-in-open-files': () => this.show('open'),
      'todo-show:find-in-active-file': () => this.show('active')
    }))

    this.disposables.add(atom.workspace.addOpener(uri => {
      if (uri === this.URI) {
        return this.deserializeTodoView()
      }
    }))
  }

  deactivate() {
    this.destroyTodoIndicator()
    if (this.showTodoView) this.showTodoView.destroy()
    if (this.disposables) this.disposables.dispose()
    this.showTodoView = null
  }

  deserializeTodoView(state = {}) {
    this.createCollection()

    if (state.scope) this.collection.setSearchScope(state.scope)

    if (!this.showTodoView) {
      this.showTodoView = new ShowTodoView(this.collection, this.URI)
    }

    // Make sure a search is executed when deserialized and visible
    if (state.deserializer) {
      setTimeout(() => {
        this.showTodoView.search()
      }, 1000)
    }

    return this.showTodoView
  }

  createCollection() {
    if (this.collection) return
    this.collection = new TodoCollection()

    const config = atom.config.getSchema('todo-show')
    if (config) {
      this.collection.setAvailableTableItems(config.properties.sortBy.enum)
    }
  }

  show(scope) {
    if (scope) {
      const prevScope = this.collection.scope
      if (prevScope !== scope) {
        this.collection.setSearchScope(scope)
        if (this.showTodoView && this.showTodoView.isVisible()) return
      }
    }

    const prevPane = atom.workspace.getActivePane()
    atom.workspace.toggle(this.URI).then(item => {
      this.showTodoView = item
      if (item) {
        this.showTodoView.search()
        prevPane.activate()
      }
    })
  }

  consumeStatusBar(statusBar) {
    atom.config.observe('todo-show.statusBarIndicator', newValue => {
      if (newValue)
        if (!this.todoIndicatorView) {
          this.todoIndicatorView = new TodoIndicatorView(this.collection)
          this.statusBarTile = statusBar.addLeftTile({
            item: this.todoIndicatorView,
            priority: 200
          })
        }
      else {
        this.destroyTodoIndicator()
      }
    })
  }

  destroyTodoIndicator() {
    if (this.todoIndicatorView) this.todoIndicatorView.destroy()
    if (this.statusBarTile) this.statusBarTile.destroy()
    this.todoIndicatorView = null
    this.statusBarTile = null
  }
}
