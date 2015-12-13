path = require 'path'

TodoCollection = require '../lib/todo-collection'
TodoModel = require '../lib/todo-model'

describe 'Todo Collection', ->
  [collection, defaultRegexes, defaultLookup, defaultShowInTable] = []

  addTestTodos = ->
    collection.addTodo(
      new TodoModel(
        all: 'fixme 1'
        file: 'file1.txt'
        type: 'FIXMEs'
        range: '3,6,3,10'
        position: [[3,6], [3,10]]
      )
    )
    collection.addTodo(
      new TodoModel(
        all: 'todo 1'
        file: 'file1.txt'
        type: 'TODOs'
        range: '4,5,4,9'
        position: [[4,5], [4,9]]
      )
    )
    collection.addTodo(
      new TodoModel(
        all: 'fixme 2'
        file: 'file2.txt'
        type: 'FIXMEs'
        range: '5,7,5,11'
        position: [[5,7], [5,11]]
      )
    )

  beforeEach ->
    defaultRegexes = [
      'FIXMEs'
      '/\\bFIXME:?\\d*($|\\s.*$)/g'
      'TODOs'
      '/\\bTODO:?\\d*($|\\s.*$)/g'
    ]
    defaultLookup =
      title: defaultRegexes[2]
      regex: defaultRegexes[3]
    defaultShowInTable = ['Text', 'Type', 'File']

    collection = new TodoCollection
    atom.project.setPaths [path.join(__dirname, 'fixtures/sample1')]

  describe 'buildRegexLookups(regexes)', ->
    it 'returns an array of lookup objects when passed an array of regexes', ->
      lookups1 = collection.buildRegexLookups(defaultRegexes)
      lookups2 = [
        {
          title: defaultRegexes[0]
          regex: defaultRegexes[1]
        }
        {
          title: defaultRegexes[2]
          regex: defaultRegexes[3]
        }
      ]
      expect(lookups1).toEqual(lookups2)

    it 'handles invalid input', ->
      collection.onDidFailSearch notificationSpy = jasmine.createSpy()

      regexes = ['TODO']
      lookups = collection.buildRegexLookups(regexes)
      expect(lookups).toHaveLength 0

      notification = notificationSpy.mostRecentCall.args[0]
      expect(notificationSpy).toHaveBeenCalled()
      expect(notification.indexOf('Invalid')).not.toBe -1

  describe 'makeRegexObj(regexStr)', ->
    it 'returns a RegExp obj when passed a regex literal (string)', ->
      regexStr = defaultLookup.regex
      regexObj = collection.makeRegexObj(regexStr)

      # Assertions duck test. Am I a regex obj?
      expect(typeof regexObj.test).toBe('function')
      expect(typeof regexObj.exec).toBe('function')

    it 'returns false and notifies on invalid input', ->
      collection.onDidFailSearch notificationSpy = jasmine.createSpy()

      regexStr = 'arstastTODO:.+$)/g'
      regexObj = collection.makeRegexObj(regexStr)
      expect(regexObj).toBe(false)

      notification = notificationSpy.mostRecentCall.args[0]
      expect(notificationSpy).toHaveBeenCalled()
      expect(notification.indexOf('Invalid')).not.toBe -1

    it 'handles empty input', ->
      regexObj = collection.makeRegexObj()
      expect(regexObj).toBe(false)

  describe 'fetchRegexItem(lookupObj)', ->
    it 'should scan the workspace for the regex that is passed and fill lookup results', ->
      waitsForPromise ->
        collection.fetchRegexItem(defaultLookup)

      runs ->
        expect(collection.todos).toHaveLength 3
        expect(collection.todos[0].text).toBe 'Comment in C'
        expect(collection.todos[1].text).toBe 'This is the first todo'
        expect(collection.todos[2].text).toBe 'This is the second todo'

    it 'should handle other regexes', ->
      lookup =
        title: 'Includes'
        regex: '/#include(.+)/g'

      waitsForPromise ->
        collection.fetchRegexItem(lookup)
      runs ->
        expect(collection.todos).toHaveLength 1
        expect(collection.todos[0].text).toBe '<stdio.h>'

    it 'should handle special character regexes', ->
      lookup =
        title: 'Todos'
        regex: '/ This is the (?:first|second) todo/g'

      waitsForPromise ->
        collection.fetchRegexItem(lookup)
      runs ->
        expect(collection.todos).toHaveLength 2
        expect(collection.todos[0].text).toBe 'This is the first todo'
        expect(collection.todos[1].text).toBe 'This is the second todo'

    it 'should handle regex without capture group', ->
      lookup =
        title: 'This is Code'
        regex: '/[\\w\\s]+code[\\w\\s]*/g'

      waitsForPromise ->
        collection.fetchRegexItem(lookup)
      runs ->
        expect(collection.todos).toHaveLength 1
        expect(collection.todos[0].text).toBe 'Sample quicksort code'

    it 'should handle post-annotations with special regex', ->
      lookup =
        title: 'Pre-DEBUG'
        regex: '/(.+).{3}DEBUG\\s*$/g'

      waitsForPromise ->
        collection.fetchRegexItem(lookup)
      runs ->
        expect(collection.todos).toHaveLength 1
        expect(collection.todos[0].text).toBe 'return sort(Array.apply(this, arguments));'

    it 'should handle post-annotations with non-capturing group', ->
      lookup =
        title: 'Pre-DEBUG'
        regex: '/(.+?(?=.{3}DEBUG\\s*$))/'

      waitsForPromise ->
        collection.fetchRegexItem(lookup)
      runs ->
        expect(collection.todos).toHaveLength 1
        expect(collection.todos[0].text).toBe 'return sort(Array.apply(this, arguments));'

    it 'should truncate todos longer than the defined max length of 120', ->
      lookup =
        title: 'Long Annotation'
        regex: '/LOONG:?(.+$)/g'

      waitsForPromise ->
        collection.fetchRegexItem(lookup)
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
      atom.project.setPaths [path.join(__dirname, 'fixtures/sample2')]

      waitsForPromise ->
        collection.fetchRegexItem(defaultLookup)
      runs ->
        expect(collection.todos).toHaveLength 6
        expect(collection.todos[0].text).toBe 'C block comment'
        expect(collection.todos[1].text).toBe 'HTML comment'
        expect(collection.todos[2].text).toBe 'PowerShell comment'
        expect(collection.todos[3].text).toBe 'Haskell comment'
        expect(collection.todos[4].text).toBe 'Lua comment'
        expect(collection.todos[5].text).toBe 'PHP comment'

  describe 'ignore path rules', ->
    it 'works with no paths added', ->
      atom.config.set('todo-show.ignoreThesePaths', [])
      waitsForPromise ->
        collection.fetchRegexItem(defaultLookup)
      runs ->
        expect(collection.todos).toHaveLength 3

    it 'must be an array', ->
      collection.onDidFailSearch notificationSpy = jasmine.createSpy()

      atom.config.set('todo-show.ignoreThesePaths', '123')
      waitsForPromise ->
        collection.fetchRegexItem(defaultLookup)
      runs ->
        expect(collection.todos).toHaveLength 3

        notification = notificationSpy.mostRecentCall.args[0]
        expect(notificationSpy).toHaveBeenCalled()
        expect(notification.indexOf('ignoreThesePaths')).not.toBe -1

    it 'respects ignored files', ->
      atom.config.set('todo-show.ignoreThesePaths', ['sample.js'])
      waitsForPromise ->
        collection.fetchRegexItem(defaultLookup)
      runs ->
        expect(collection.todos).toHaveLength 1
        expect(collection.todos[0].text).toBe 'Comment in C'

    it 'respects ignored directories and filetypes', ->
      atom.project.setPaths [path.join(__dirname, 'fixtures')]
      atom.config.set('todo-show.ignoreThesePaths', ['sample1', '*.md'])

      waitsForPromise ->
        collection.fetchRegexItem(defaultLookup)
      runs ->
        expect(collection.todos).toHaveLength 6
        expect(collection.todos[0].text).toBe 'C block comment'

    it 'respects ignored wildcard directories', ->
      atom.project.setPaths [path.join(__dirname, 'fixtures')]
      atom.config.set('todo-show.ignoreThesePaths', ['**/sample.js', '**/sample.txt', '*.md'])

      waitsForPromise ->
        collection.fetchRegexItem(defaultLookup)
      runs ->
        expect(collection.todos).toHaveLength 1
        expect(collection.todos[0].text).toBe 'Comment in C'

    it 'respects more advanced ignores', ->
      atom.project.setPaths [path.join(__dirname, 'fixtures')]
      atom.config.set('todo-show.ignoreThesePaths', ['output(-grouped)?\\.*', '*1/**'])

      waitsForPromise ->
        collection.fetchRegexItem(defaultLookup)
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
        collection.fetchOpenRegexItem(defaultLookup)

      runs ->
        expect(collection.todos).toHaveLength 1
        expect(collection.todos.length).toBe 1
        expect(collection.todos[0].text).toBe 'Comment in C'

    it 'works with files outside of workspace', ->
      waitsForPromise ->
        atom.workspace.open '../sample2/sample.txt'

      runs ->
        waitsForPromise ->
          collection.fetchOpenRegexItem(defaultLookup)

        runs ->
          expect(collection.todos).toHaveLength 7
          expect(collection.todos[0].text).toBe 'Comment in C'
          expect(collection.todos[1].text).toBe 'C block comment'
          expect(collection.todos[6].text).toBe 'PHP comment'

    it 'handles unsaved documents', ->
      editor.setText 'TODO: New todo'

      waitsForPromise ->
        collection.fetchOpenRegexItem(defaultLookup)
      runs ->
        expect(collection.todos).toHaveLength 1
        expect(collection.todos[0].type).toBe 'TODOs'
        expect(collection.todos[0].text).toBe 'New todo'

    it 'respects imdone syntax (https://github.com/imdone/imdone-atom)', ->
      editor.setText '''
        TODO:10 todo1
        TODO:0 todo2
      '''

      waitsForPromise ->
        collection.fetchOpenRegexItem(defaultLookup)
      runs ->
        expect(collection.todos).toHaveLength 2
        expect(collection.todos[0].type).toBe 'TODOs'
        expect(collection.todos[0].text).toBe 'todo1'
        expect(collection.todos[1].text).toBe 'todo2'

    it 'handles number in todo (as long as its not without space)', ->
      editor.setText """
        Line 1 //TODO: 1 2 3
        Line 1 // TODO:1 2 3
      """

      waitsForPromise ->
        collection.fetchOpenRegexItem(defaultLookup)
      runs ->
        expect(collection.todos).toHaveLength 2
        expect(collection.todos[0].text).toBe '1 2 3'
        expect(collection.todos[1].text).toBe '2 3'

    it 'handles empty todos', ->
      editor.setText """
        Line 1 // TODO
        Line 2 //TODO
      """

      waitsForPromise ->
        collection.fetchOpenRegexItem(defaultLookup)
      runs ->
        expect(collection.todos).toHaveLength 2
        expect(collection.todos[0].text).toBe 'No details'
        expect(collection.todos[1].text).toBe 'No details'

    it 'handles empty block todos', ->
      editor.setText """
        /* TODO */
        Line 2 /* TODO */
      """

      waitsForPromise ->
        collection.fetchOpenRegexItem(defaultLookup)
      runs ->
        expect(collection.todos).toHaveLength 2
        expect(collection.todos[0].text).toBe 'No details'
        expect(collection.todos[1].text).toBe 'No details'

    it 'handles todos with @ in front', ->
      editor.setText """
        Line 1 //@TODO: text
        Line 2 //@TODO: text
        Line 3 @TODO: text
      """

      waitsForPromise ->
        collection.fetchOpenRegexItem(defaultLookup)
      runs ->
        expect(collection.todos).toHaveLength 3
        expect(collection.todos[0].text).toBe 'text'
        expect(collection.todos[1].text).toBe 'text'
        expect(collection.todos[2].text).toBe 'text'

    it 'handles tabs in todos', ->
      editor.setText 'Line //TODO:\ttext'

      waitsForPromise ->
        collection.fetchOpenRegexItem(defaultLookup)
      runs ->
        expect(collection.todos[0].text).toBe 'text'

    it 'handles todo without semicolon', ->
      editor.setText 'A line // TODO text'

      waitsForPromise ->
        collection.fetchOpenRegexItem(defaultLookup)
      runs ->
        expect(collection.todos[0].text).toBe 'text'

    it 'ignores todos without leading space', ->
      editor.setText 'A line // TODO:text'

      waitsForPromise ->
        collection.fetchOpenRegexItem(defaultLookup)
      runs ->
        expect(collection.todos).toHaveLength 0

    it 'ignores todo if unwanted chars are present', ->
      editor.setText 'define("_JS_TODO_ALERT_", "js:alert(&quot;TODO&quot;);");'

      waitsForPromise ->
        collection.fetchOpenRegexItem(defaultLookup)
      runs ->
        expect(collection.todos).toHaveLength 0

    it 'ignores binary data', ->
      editor.setText '// TODOe�d��RPPP0�'

      waitsForPromise ->
        collection.fetchOpenRegexItem(defaultLookup)
      runs ->
        expect(collection.todos).toHaveLength 0

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
      expect(collection.todos[0].file).toBe 'file2.txt'
      expect(collection.todos[2].file).toBe 'file1.txt'

  describe 'Filter todos', ->
    {filterSpy} = []

    beforeEach ->
      atom.config.set 'todo-show.showInTable', defaultShowInTable
      addTestTodos()
      filterSpy = jasmine.createSpy()
      collection.onDidFilterTodos filterSpy

    it 'can filter simple todos', ->
      collection.filterTodos('todo')
      expect(filterSpy.callCount).toBe 1
      expect(filterSpy.calls[0].args[0]).toHaveLength 1

    it 'can filter todos with multiple results', ->
      collection.filterTodos('FIXME')
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

  describe 'Markdown', ->
    beforeEach ->
      atom.config.set 'todo-show.findTheseRegexes', defaultRegexes
      atom.config.set 'todo-show.showInTable', defaultShowInTable

    it 'creates a markdown string from regexes', ->
      addTestTodos()
      expect(collection.getMarkdown()).toEqual """
        - fixme 1 __FIXMEs__ [file1.txt](file1.txt)
        - todo 1 __TODOs__ [file1.txt](file1.txt)
        - fixme 2 __FIXMEs__ [file2.txt](file2.txt)\n
      """

    it 'creates markdown with sorting', ->
      addTestTodos()
      collection.sortTodos(sortBy: 'Text', sortAsc: true)
      expect(collection.getMarkdown()).toEqual """
        - fixme 1 __FIXMEs__ [file1.txt](file1.txt)
        - fixme 2 __FIXMEs__ [file2.txt](file2.txt)
        - todo 1 __TODOs__ [file1.txt](file1.txt)\n
      """

    it 'creates markdown with inverse sorting', ->
      addTestTodos()
      collection.sortTodos(sortBy: 'Text', sortAsc: false)
      expect(collection.getMarkdown()).toEqual """
        - todo 1 __TODOs__ [file1.txt](file1.txt)
        - fixme 2 __FIXMEs__ [file2.txt](file2.txt)
        - fixme 1 __FIXMEs__ [file1.txt](file1.txt)\n
      """

    it 'creates markdown with different items', ->
      addTestTodos()
      atom.config.set 'todo-show.showInTable', ['Type', 'File', 'Range']
      expect(collection.getMarkdown()).toEqual """
        - __FIXMEs__ [file1.txt](file1.txt) _:3,6,3,10_
        - __TODOs__ [file1.txt](file1.txt) _:4,5,4,9_
        - __FIXMEs__ [file2.txt](file2.txt) _:5,7,5,11_\n
      """

    it 'creates markdown as table', ->
      addTestTodos()
      atom.config.set 'todo-show.saveOutputAs', 'Table'
      expect(collection.getMarkdown()).toEqual """
        | Text | Type | File |
        |--------------------|
        | fixme 1 | __FIXMEs__ | [file1.txt](file1.txt) |
        | todo 1 | __TODOs__ | [file1.txt](file1.txt) |
        | fixme 2 | __FIXMEs__ | [file2.txt](file2.txt) |\n
      """

    it 'creates markdown as table with different items', ->
      addTestTodos()
      atom.config.set 'todo-show.saveOutputAs', 'Table'
      atom.config.set 'todo-show.showInTable', ['Type', 'File', 'Range']
      expect(collection.getMarkdown()).toEqual """
        | Type | File | Range |
        |---------------------|
        | __FIXMEs__ | [file1.txt](file1.txt) | _:3,6,3,10_ |
        | __TODOs__ | [file1.txt](file1.txt) | _:4,5,4,9_ |
        | __FIXMEs__ | [file2.txt](file2.txt) | _:5,7,5,11_ |\n
      """

    it 'accepts missing ranges and paths in regexes', ->
      collection.addTodo(
        new TodoModel(
          text: 'fixme 1'
          type: 'FIXMEs'
        , plain: true)
      )
      expect(collection.getMarkdown()).toEqual """
        - fixme 1 __FIXMEs__\n
      """

      atom.config.set 'todo-show.showInTable', ['Type', 'File', 'Range', 'Text']
      markdown = '\n## Unknown File\n\n- fixme 1 `FIXMEs`\n'
      expect(collection.getMarkdown()).toEqual """
        - __FIXMEs__ fixme 1\n
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
          type: 'FIXMEs'
        , plain: true)
      )
      atom.config.set 'todo-show.saveOutputAs', 'Table'
      expect(collection.getMarkdown()).toEqual """
        | Text | Type | File |
        |--------------------|
        | fixme 1 | __FIXMEs__ | |\n
      """

      atom.config.set 'todo-show.showInTable', ['Line']
      expect(collection.getMarkdown()).toEqual """
        | Line |
        |------|
        | |\n
      """
