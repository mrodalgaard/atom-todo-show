path = require 'path'

TodoCollection = require '../lib/todo-collection'
ShowTodo = require '../lib/show-todo'
TodoModel = require '../lib/todo-model'
TodoRegex = require '../lib/todo-regex'

sample1Path = path.join(__dirname, 'fixtures/sample1')
sample2Path = path.join(__dirname, 'fixtures/sample2')
fixturesPath = path.join(__dirname, 'fixtures')

describe 'Todo Collection', ->
  [collection, todoRegex, defaultShowInTable] = []

  addTestTodos = ->
    collection.addTodo(
      new TodoModel(
        all: '#FIXME: fixme 1'
        loc: 'file1.txt'
        position: [[3,6], [3,10]]
        regex: todoRegex.regex
        regexp: todoRegex.regexp
      )
    )
    collection.addTodo(
      new TodoModel(
        all: '#TODO: todo 1'
        loc: 'file1.txt'
        position: [[4,5], [4,9]]
        regex: todoRegex.regex
        regexp: todoRegex.regexp
      )
    )
    collection.addTodo(
      new TodoModel(
        all: '#FIXME: fixme 2'
        loc: 'file2.txt'
        position: [[5,7], [5,11]]
        regex: todoRegex.regex
        regexp: todoRegex.regexp
      )
    )

  beforeEach ->
    todoRegex = new TodoRegex(
      ShowTodo.config.findUsingRegex.default
      ['FIXME', 'TODO']
    )
    defaultShowInTable = ['Text', 'Type', 'File']

    collection = new TodoCollection
    atom.project.setPaths [sample1Path]

  describe 'fetchRegexItem(todoRegex)', ->
    it 'scans project for regex', ->
      waitsForPromise ->
        collection.fetchRegexItem(todoRegex)

      runs ->
        expect(collection.todos).toHaveLength 4
        expect(collection.todos[0].text).toBe 'Comment in C'
        expect(collection.todos[1].text).toBe 'This is the first todo'
        expect(collection.todos[2].text).toBe 'This is the second todo'
        expect(collection.todos[3].text).toBe 'Add more annnotations :)'

    it 'scans full workspace', ->
      atom.project.addPath sample2Path
      waitsForPromise ->
        collection.fetchRegexItem(todoRegex)
      runs ->
        expect(collection.todos).toHaveLength 10

    it 'should handle other regexes', ->
      waitsForPromise ->
        todoRegex.regexp = /#include(.+)/g
        collection.fetchRegexItem(todoRegex)
      runs ->
        expect(collection.todos).toHaveLength 1
        expect(collection.todos[0].text).toBe '<stdio.h>'

    it 'should handle special character regexes', ->
      waitsForPromise ->
        todoRegex.regexp = /This is the (?:first|second) todo/g
        collection.fetchRegexItem(todoRegex)
      runs ->
        expect(collection.todos).toHaveLength 2
        expect(collection.todos[0].text).toBe 'This is the first todo'
        expect(collection.todos[1].text).toBe 'This is the second todo'

    it 'should handle regex without capture group', ->
      lookup =
        title: 'This is Code'
        regex: ''

      waitsForPromise ->
        todoRegex.regexp = /[\w\s]+code[\w\s]*/g
        collection.fetchRegexItem(todoRegex)
      runs ->
        expect(collection.todos).toHaveLength 1
        expect(collection.todos[0].text).toBe 'Sample quicksort code'

    it 'should handle post-annotations with special regex', ->
      waitsForPromise ->
        todoRegex.regexp = /(.+).{3}DEBUG\s*$/g
        collection.fetchRegexItem(todoRegex)
      runs ->
        expect(collection.todos).toHaveLength 1
        expect(collection.todos[0].text).toBe 'return sort(Array.apply(this, arguments));'

    it 'should handle post-annotations with non-capturing group', ->
      waitsForPromise ->
        todoRegex.regexp = /(.+?(?=.{3}DEBUG\s*$))/
        collection.fetchRegexItem(todoRegex)
      runs ->
        expect(collection.todos).toHaveLength 1
        expect(collection.todos[0].text).toBe 'return sort(Array.apply(this, arguments));'

    it 'should truncate todos longer than the defined max length of 120', ->
      waitsForPromise ->
        todoRegex.regexp = /LOONG:?(.+$)/g
        collection.fetchRegexItem(todoRegex)
      runs ->
        text = 'Lorem ipsum dolor sit amet, dapibus rhoncus. Scelerisque quam,'
        text += ' id ante molestias, ipsum lorem magnis et. A eleifend i...'

        text2 = '_SpgLE84Ms1K4DSumtJDoNn8ZECZLL+VR0DoGydy54vUoSpgLE84Ms1K4DSum'
        text2 += 'tJDoNn8ZECZLLVR0DoGydy54vUonRClXwLbFhX2gMwZgjx250ay+V0lF...'

        expect(collection.todos[0].text).toHaveLength 120
        expect(collection.todos[0].text).toBe text

        expect(collection.todos[1].text).toHaveLength 120
        expect(collection.todos[1].text).toBe text2

    it 'should strip common block comment endings', ->
      atom.project.setPaths [sample2Path]

      waitsForPromise -> collection.fetchRegexItem(todoRegex)
      runs ->
        expect(collection.todos).toHaveLength 6
        expect(collection.todos[0].text).toBe 'C block comment'
        expect(collection.todos[1].text).toBe 'HTML comment'
        expect(collection.todos[2].text).toBe 'PowerShell comment'
        expect(collection.todos[3].text).toBe 'Haskell comment'
        expect(collection.todos[4].text).toBe 'Lua comment'
        expect(collection.todos[5].text).toBe 'PHP comment'

  describe 'fetchRegexItem(todoRegex, activeProjectOnly)', ->
    beforeEach ->
      atom.project.addPath sample2Path

    it 'scans active project for regex', ->
      collection.setActiveProject(sample1Path)

      waitsForPromise -> collection.fetchRegexItem(todoRegex, true)
      runs ->
        expect(collection.todos).toHaveLength 4
        expect(collection.todos[0].text).toBe 'Comment in C'
        expect(collection.todos[1].text).toBe 'This is the first todo'
        expect(collection.todos[2].text).toBe 'This is the second todo'
        expect(collection.todos[3].text).toBe 'Add more annnotations :)'

    it 'changes active project', ->
      collection.setActiveProject(sample2Path)

      waitsForPromise -> collection.fetchRegexItem(todoRegex, true)
      runs ->
        expect(collection.todos).toHaveLength 6
        collection.clear()
        collection.setActiveProject(sample1Path)

        waitsForPromise -> collection.fetchRegexItem(todoRegex, true)
        runs ->
          expect(collection.todos).toHaveLength 4

    it 'still respects ignored paths', ->
      atom.config.set('todo-show.ignoreThesePaths', ['sample.js'])
      waitsForPromise ->
        collection.fetchRegexItem(todoRegex, true)
      runs ->
        expect(collection.todos).toHaveLength 1
        expect(collection.todos[0].text).toBe 'Comment in C'

    it 'handles no project situations', ->
      expect(collection.activeProject).not.toBeDefined()
      expect(path.basename(collection.getActiveProject())).toBe 'sample1'

      atom.project.setPaths []
      collection.activeProject = undefined
      waitsForPromise -> collection.fetchRegexItem(todoRegex, true)
      runs ->
        expect(collection.todos).toHaveLength 0

  describe 'ignore path rules', ->
    it 'works with no paths added', ->
      atom.config.set('todo-show.ignoreThesePaths', [])
      waitsForPromise ->
        collection.fetchRegexItem(todoRegex)
      runs ->
        expect(collection.todos).toHaveLength 4

    it 'must be an array', ->
      collection.onDidFailSearch notificationSpy = jasmine.createSpy()

      atom.config.set('todo-show.ignoreThesePaths', '123')
      waitsForPromise ->
        collection.fetchRegexItem(todoRegex)
      runs ->
        expect(collection.todos).toHaveLength 4

        notification = notificationSpy.mostRecentCall.args[0]
        expect(notificationSpy).toHaveBeenCalled()
        expect(notification.indexOf('ignoreThesePaths')).not.toBe -1

    it 'respects ignored files', ->
      atom.config.set('todo-show.ignoreThesePaths', ['sample.js'])
      waitsForPromise ->
        collection.fetchRegexItem(todoRegex)
      runs ->
        expect(collection.todos).toHaveLength 1
        expect(collection.todos[0].text).toBe 'Comment in C'

    it 'respects ignored directories and filetypes', ->
      atom.project.setPaths [fixturesPath]
      atom.config.set('todo-show.ignoreThesePaths', ['sample1', '*.md'])

      waitsForPromise ->
        collection.fetchRegexItem(todoRegex)
      runs ->
        expect(collection.todos).toHaveLength 6
        expect(collection.todos[0].text).toBe 'C block comment'

    it 'respects ignored wildcard directories', ->
      atom.project.setPaths [fixturesPath]
      atom.config.set('todo-show.ignoreThesePaths', ['**/sample.js', '**/sample.txt', '*.md'])

      waitsForPromise ->
        collection.fetchRegexItem(todoRegex)
      runs ->
        expect(collection.todos).toHaveLength 1
        expect(collection.todos[0].text).toBe 'Comment in C'

    it 'respects more advanced ignores', ->
      atom.project.setPaths [fixturesPath]
      atom.config.set('todo-show.ignoreThesePaths', ['output(-grouped)?\\.*', '*1/**'])

      waitsForPromise ->
        collection.fetchRegexItem(todoRegex)
      runs ->
        expect(collection.todos).toHaveLength 6
        expect(collection.todos[0].text).toBe 'C block comment'

  describe 'fetchOpenRegexItem(lookupObj)', ->
    editor = null

    beforeEach ->
      waitsForPromise ->
        atom.workspace.open 'sample.c'
      runs ->
        editor = atom.workspace.getActiveTextEditor()

    it 'scans open files for the regex that is passed and fill lookup results', ->
      waitsForPromise ->
        collection.fetchOpenRegexItem(todoRegex)

      runs ->
        expect(collection.todos).toHaveLength 1
        expect(collection.todos.length).toBe 1
        expect(collection.todos[0].text).toBe 'Comment in C'

    it 'works with files outside of workspace', ->
      waitsForPromise ->
        atom.workspace.open '../sample2/sample.txt'

      runs ->
        waitsForPromise ->
          collection.fetchOpenRegexItem(todoRegex)

        runs ->
          expect(collection.todos).toHaveLength 7
          expect(collection.todos[0].text).toBe 'Comment in C'
          expect(collection.todos[1].text).toBe 'C block comment'
          expect(collection.todos[6].text).toBe 'PHP comment'

    it 'handles unsaved documents', ->
      editor.setText 'TODO: New todo'

      waitsForPromise ->
        collection.fetchOpenRegexItem(todoRegex)
      runs ->
        expect(collection.todos).toHaveLength 1
        expect(collection.todos[0].type).toBe 'TODO'
        expect(collection.todos[0].text).toBe 'New todo'

    it 'ignores todo without leading space', ->
      editor.setText 'A line // TODO:text'

      waitsForPromise ->
        collection.fetchOpenRegexItem(todoRegex)
      runs ->
        expect(collection.todos).toHaveLength 0

    it 'ignores todo with unwanted characters', ->
      editor.setText 'define("_JS_TODO_ALERT_", "js:alert(&quot;TODO&quot;);");'

      waitsForPromise ->
        collection.fetchOpenRegexItem(todoRegex)
      runs ->
        expect(collection.todos).toHaveLength 0

    it 'ignores binary data', ->
      editor.setText '// TODOe�d��RPPP0�'

      waitsForPromise ->
        collection.fetchOpenRegexItem(todoRegex)
      runs ->
        expect(collection.todos).toHaveLength 0

    it 'does not add duplicates', ->
      addTestTodos()
      expect(collection.todos).toHaveLength 3
      addTestTodos()
      expect(collection.todos).toHaveLength 3

  describe 'getActiveProject', ->
    beforeEach ->
      atom.project.addPath sample2Path

    it 'returns active project', ->
      collection.activeProject = sample2Path
      expect(collection.getActiveProject()).toBe sample2Path

    it 'falls back to first project', ->
      expect(collection.getActiveProject()).toBe sample1Path

    it 'falls back to first open item', ->
      waitsForPromise ->
        atom.workspace.open path.join(sample2Path, 'sample.txt')
      runs ->
        expect(collection.getActiveProject()).toBe sample2Path

    it 'handles no project paths', ->
      atom.project.setPaths []
      expect(collection.getActiveProject()).toBeFalsy()
      expect(collection.activeProject).not.toBeDefined()

  describe 'setActiveProject', ->
    it 'sets active project from file path and returns true if changed', ->
      atom.project.addPath sample2Path
      expect(collection.getActiveProject()).toBe sample1Path
      res = collection.setActiveProject path.join(sample2Path, 'sample.txt')
      expect(res).toBe true
      expect(collection.getActiveProject()).toBe sample2Path
      res = collection.setActiveProject path.join(sample2Path, 'sample.txt')
      expect(res).toBe false

    it 'ignores if file is not in project', ->
      res = collection.setActiveProject path.join(sample2Path, 'sample.txt')
      expect(res).toBe false
      expect(collection.getActiveProject()).toBe sample1Path

    it 'handles invalid arguments', ->
      expect(collection.setActiveProject()).toBe false
      expect(collection.activeProject).not.toBeDefined()

      expect(collection.setActiveProject(false)).toBe false
      expect(collection.activeProject).not.toBeDefined()

      expect(collection.setActiveProject({})).toBe false
      expect(collection.activeProject).not.toBeDefined()

  describe 'Sort todos', ->
    {sortSpy} = []

    beforeEach ->
      addTestTodos()
      sortSpy = jasmine.createSpy()
      collection.onDidSortTodos sortSpy

    it 'can sort simple todos', ->
      collection.sortTodos(sortBy: 'Text', sortAsc: false)
      expect(collection.todos[0].text).toBe 'todo 1'
      expect(collection.todos[2].text).toBe 'fixme 1'

      collection.sortTodos(sortBy: 'Text', sortAsc: true)
      expect(collection.todos[0].text).toBe 'fixme 1'
      expect(collection.todos[2].text).toBe 'todo 1'

      collection.sortTodos(sortBy: 'Text')
      expect(collection.todos[0].text).toBe 'todo 1'
      expect(collection.todos[2].text).toBe 'fixme 1'

      collection.sortTodos(sortAsc: true)
      expect(collection.todos[0].text).toBe 'fixme 1'
      expect(collection.todos[2].text).toBe 'todo 1'

      collection.sortTodos()
      expect(collection.todos[0].text).toBe 'todo 1'
      expect(collection.todos[2].text).toBe 'fixme 1'

    it 'sort by other values', ->
      collection.sortTodos(sortBy: 'Range', sortAsc: true)
      expect(collection.todos[0].range).toBe '3,6,3,10'
      expect(collection.todos[2].range).toBe '5,7,5,11'

      collection.sortTodos(sortBy: 'File', sortAsc: false)
      expect(collection.todos[0].path).toBe 'file2.txt'
      expect(collection.todos[2].path).toBe 'file1.txt'

    it 'sort line as number', ->
      collection.addTodo(
        new TodoModel(
          all: '#FIXME: fixme 3'
          loc: 'file3.txt'
          position: [[12,14], [12,16]]
          regex: todoRegex.regex
          regexp: todoRegex.regexp
        )
      )

      collection.sortTodos(sortBy: 'Line', sortAsc: true)
      expect(collection.todos[0].line).toBe '4'
      expect(collection.todos[1].line).toBe '5'
      expect(collection.todos[2].line).toBe '6'
      expect(collection.todos[3].line).toBe '13'

      collection.sortTodos(sortBy: 'Range', sortAsc: true)
      expect(collection.todos[0].range).toBe '3,6,3,10'
      expect(collection.todos[1].range).toBe '4,5,4,9'
      expect(collection.todos[2].range).toBe '5,7,5,11'
      expect(collection.todos[3].range).toBe '12,14,12,16'

  describe 'Filter todos', ->
    {filterSpy} = []

    beforeEach ->
      atom.config.set 'todo-show.showInTable', defaultShowInTable
      addTestTodos()
      filterSpy = jasmine.createSpy()
      collection.onDidFilterTodos filterSpy

    it 'can filter simple todos', ->
      collection.filterTodos('TODO')
      expect(filterSpy.callCount).toBe 1
      expect(filterSpy.calls[0].args[0]).toHaveLength 1

    it 'can filter todos with multiple results', ->
      collection.filterTodos('file1')
      expect(filterSpy.callCount).toBe 1
      expect(filterSpy.calls[0].args[0]).toHaveLength 2

    it 'handles no results', ->
      collection.filterTodos('XYZ')
      expect(filterSpy.callCount).toBe 1
      expect(filterSpy.calls[0].args[0]).toHaveLength 0

    it 'handles empty filter', ->
      collection.filterTodos('')
      expect(filterSpy.callCount).toBe 1
      expect(filterSpy.calls[0].args[0]).toHaveLength 3

    it 'case insensitive filter', ->
      collection.addTodo(
        new TodoModel(
          all: '#FIXME: THIS IS WITH CAPS'
          loc: 'file2.txt'
          position: [[6,7], [6,11]]
          regex: todoRegex.regex
          regexp: todoRegex.regexp
        )
      )

      collection.filterTodos('FIXME 1')
      result = filterSpy.calls[0].args[0]
      expect(filterSpy.callCount).toBe 1
      expect(result).toHaveLength 1
      expect(result[0].text).toBe 'fixme 1'

      collection.filterTodos('caps')
      result = filterSpy.calls[1].args[0]
      expect(filterSpy.callCount).toBe 2
      expect(result).toHaveLength 1
      expect(result[0].text).toBe 'THIS IS WITH CAPS'

      collection.filterTodos('NONEXISTING')
      result = filterSpy.calls[2].args[0]
      expect(filterSpy.callCount).toBe 3
      expect(result).toHaveLength 0

  describe 'Markdown', ->
    beforeEach ->
      atom.config.set 'todo-show.findTheseTodos', ['FIXME', 'TODO']
      atom.config.set 'todo-show.showInTable', defaultShowInTable

    it 'creates a markdown string from regexes', ->
      addTestTodos()
      expect(collection.getMarkdown()).toEqual """
        - fixme 1 __FIXME__ [file1.txt](file1.txt)
        - todo 1 __TODO__ [file1.txt](file1.txt)
        - fixme 2 __FIXME__ [file2.txt](file2.txt)\n
      """

    it 'creates markdown with sorting', ->
      addTestTodos()
      collection.sortTodos(sortBy: 'Text', sortAsc: true)
      expect(collection.getMarkdown()).toEqual """
        - fixme 1 __FIXME__ [file1.txt](file1.txt)
        - fixme 2 __FIXME__ [file2.txt](file2.txt)
        - todo 1 __TODO__ [file1.txt](file1.txt)\n
      """

    it 'creates markdown with inverse sorting', ->
      addTestTodos()
      collection.sortTodos(sortBy: 'Text', sortAsc: false)
      expect(collection.getMarkdown()).toEqual """
        - todo 1 __TODO__ [file1.txt](file1.txt)
        - fixme 2 __FIXME__ [file2.txt](file2.txt)
        - fixme 1 __FIXME__ [file1.txt](file1.txt)\n
      """

    it 'creates markdown with different items', ->
      addTestTodos()
      atom.config.set 'todo-show.showInTable', ['Type', 'File', 'Range']
      expect(collection.getMarkdown()).toEqual """
        - __FIXME__ [file1.txt](file1.txt) _:3,6,3,10_
        - __TODO__ [file1.txt](file1.txt) _:4,5,4,9_
        - __FIXME__ [file2.txt](file2.txt) _:5,7,5,11_\n
      """

    it 'creates markdown as table', ->
      addTestTodos()
      atom.config.set 'todo-show.saveOutputAs', 'Table'
      expect(collection.getMarkdown()).toEqual """
        | Text | Type | File |
        |--------------------|
        | fixme 1 | __FIXME__ | [file1.txt](file1.txt) |
        | todo 1 | __TODO__ | [file1.txt](file1.txt) |
        | fixme 2 | __FIXME__ | [file2.txt](file2.txt) |\n
      """

    it 'creates markdown as table with different items', ->
      addTestTodos()
      atom.config.set 'todo-show.saveOutputAs', 'Table'
      atom.config.set 'todo-show.showInTable', ['Type', 'File', 'Range']
      expect(collection.getMarkdown()).toEqual """
        | Type | File | Range |
        |---------------------|
        | __FIXME__ | [file1.txt](file1.txt) | _:3,6,3,10_ |
        | __TODO__ | [file1.txt](file1.txt) | _:4,5,4,9_ |
        | __FIXME__ | [file2.txt](file2.txt) | _:5,7,5,11_ |\n
      """

    it 'accepts missing ranges and paths in regexes', ->
      collection.addTodo(
        new TodoModel(
          text: 'fixme 1'
          type: 'FIXME'
        , plain: true)
      )
      expect(collection.getMarkdown()).toEqual """
        - fixme 1 __FIXME__\n
      """

      atom.config.set 'todo-show.showInTable', ['Type', 'File', 'Range', 'Text']
      markdown = '\n## Unknown File\n\n- fixme 1 `FIXMEs`\n'
      expect(collection.getMarkdown()).toEqual """
        - __FIXME__ fixme 1\n
      """

    it 'accepts missing title in regexes', ->
      collection.addTodo(
        new TodoModel(
          text: 'fixme 1'
          file: 'file1.txt'
        , plain: true)
      )
      expect(collection.getMarkdown()).toEqual """
        - fixme 1 [file1.txt](file1.txt)\n
      """

      atom.config.set 'todo-show.showInTable', ['Title']
      expect(collection.getMarkdown()).toEqual """
        - No details\n
      """

    it 'accepts missing items in table output', ->
      collection.addTodo(
        new TodoModel(
          text: 'fixme 1'
          type: 'FIXME'
        , plain: true)
      )
      atom.config.set 'todo-show.saveOutputAs', 'Table'
      expect(collection.getMarkdown()).toEqual """
        | Text | Type | File |
        |--------------------|
        | fixme 1 | __FIXME__ | |\n
      """

      atom.config.set 'todo-show.showInTable', ['Line']
      expect(collection.getMarkdown()).toEqual """
        | Line |
        |------|
        | |\n
      """
