path = require 'path'
ShowTodoView = require '../lib/show-todo-view'

describe 'ShowTodoView fetching logic and data handling', ->
  [showTodoView, defaultRegexes, defaultLookup] = []

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

    showTodoView = new ShowTodoView('dummyPath')
    showTodoView.matches = []
    atom.project.setPaths [path.join(__dirname, 'fixtures/sample1')]

  describe 'buildRegexLookups(regexes)', ->
    it 'should return an array of lookup objects when passed an array of regexes', ->
      regexes = showTodoView.buildRegexLookups(defaultRegexes)
      lookups = [
        {
          title: defaultRegexes[0]
          regex: defaultRegexes[1]
        }
        {
          title: defaultRegexes[2]
          regex: defaultRegexes[3]
        }
      ]
      expect(regexes).toEqual(lookups)

  describe 'makeRegexObj(regexStr)', ->
    it 'should return a RegExp obj when passed a regex literal (string)', ->
      regexStr = defaultLookup.regex
      regexObj = showTodoView.makeRegexObj(regexStr)

      # Assertions duck test. Am I a regex obj?
      expect(typeof regexObj.test).toBe('function')
      expect(typeof regexObj.exec).toBe('function')

    it 'should return false bool when passed an invalid regex literal (string)', ->
      regexStr = 'arstastTODO:.+$)/g'
      regexObj = showTodoView.makeRegexObj(regexStr)

      expect(regexObj).toBe(false)

  describe 'handleScanMatch(match, regex)', ->
    {match, regex} = []

    beforeEach ->
      regex = /\b@?TODO:?\d*($|\s.*$)/g
      match =
        path: "#{atom.project.getPaths()[0]}/sample.c"
        matchText: ' TODO: Comment in C '
        range: [
          [0, 1]
          [0, 20]
        ]

    it 'should handle results from workspace scan (also tested in fetchRegexItem)', ->
      output = showTodoView.handleScanMatch(match)
      expect(output.matchText).toEqual 'TODO: Comment in C'

    it 'should remove regex part', ->
      output = showTodoView.handleScanMatch(match, regex)
      expect(output.matchText).toEqual 'Comment in C'

    it 'should serialize range and relativize path', ->
      output = showTodoView.handleScanMatch(match, regex)
      expect(output.relativePath).toEqual 'sample.c'
      expect(output.rangeString).toEqual '0,1,0,20'

  describe 'fetchRegexItem(lookupObj)', ->
    it 'should scan the workspace for the regex that is passed and fill lookup results', ->
      waitsForPromise ->
        showTodoView.fetchRegexItem(defaultLookup)

      runs ->
        expect(showTodoView.matches).toHaveLength 3
        expect(showTodoView.matches[0].matchText).toBe 'Comment in C'
        expect(showTodoView.matches[1].matchText).toBe 'This is the first todo'
        expect(showTodoView.matches[2].matchText).toBe 'This is the second todo'

    it 'should respect ignored paths', ->
      atom.config.set('todo-show.ignoreThesePaths', '*/sample.js')

      waitsForPromise ->
        showTodoView.fetchRegexItem(defaultLookup)
      runs ->
        expect(showTodoView.matches).toHaveLength 1
        expect(showTodoView.matches[0].matchText).toBe 'Comment in C'

    it 'should handle other regexes', ->
      lookup =
        title: 'Includes'
        regex: '/#include(.+)/g'

      waitsForPromise ->
        showTodoView.fetchRegexItem(lookup)
      runs ->
        expect(showTodoView.matches).toHaveLength 1
        expect(showTodoView.matches[0].matchText).toBe '<stdio.h>'

    it 'should handle special character regexes', ->
      lookup =
        title: 'Todos'
        regex: '/ This is the (?:first|second) todo/g'

      waitsForPromise ->
        showTodoView.fetchRegexItem(lookup)
      runs ->
        expect(showTodoView.matches).toHaveLength 2
        expect(showTodoView.matches[0].matchText).toBe 'This is the first todo'
        expect(showTodoView.matches[1].matchText).toBe 'This is the second todo'

    it 'should handle regex without capture group', ->
      lookup =
        title: 'This is Code'
        regex: '/[\\w\\s]+code[\\w\\s]*/g'

      waitsForPromise ->
        showTodoView.fetchRegexItem(lookup)
      runs ->
        expect(showTodoView.matches).toHaveLength 1
        expect(showTodoView.matches[0].matchText).toBe 'Sample quicksort code'

    it 'should handle post-annotations with special regex', ->
      lookup =
        title: 'Pre-DEBUG'
        regex: '/(.+).{3}DEBUG\\s*$/g'

      waitsForPromise ->
        showTodoView.fetchRegexItem(lookup)
      runs ->
        expect(showTodoView.matches).toHaveLength 1
        expect(showTodoView.matches[0].matchText).toBe 'return sort(Array.apply(this, arguments));'

    it 'should handle post-annotations with non-capturing group', ->
      lookup =
        title: 'Pre-DEBUG'
        regex: '/(.+?(?=.{3}DEBUG\\s*$))/'

      waitsForPromise ->
        showTodoView.fetchRegexItem(lookup)
      runs ->
        expect(showTodoView.matches).toHaveLength 1
        expect(showTodoView.matches[0].matchText).toBe 'return sort(Array.apply(this, arguments));'

    it 'should truncate matches longer than the defined max length of 120', ->
      lookup =
        title: 'Long Annotation'
        regex: '/LOONG:?(.+$)/g'

      waitsForPromise ->
        showTodoView.fetchRegexItem(lookup)
      runs ->
        matchText = 'Lorem ipsum dolor sit amet, dapibus rhoncus. Scelerisque quam,'
        matchText += ' id ante molestias, ipsum lorem magnis et. A eleifend i...'

        matchText2 = '_SpgLE84Ms1K4DSumtJDoNn8ZECZLL+VR0DoGydy54vUoSpgLE84Ms1K4DSum'
        matchText2 += 'tJDoNn8ZECZLLVR0DoGydy54vUonRClXwLbFhX2gMwZgjx250ay+V0lF...'

        expect(showTodoView.matches[0].matchText).toHaveLength 120
        expect(showTodoView.matches[0].matchText).toBe matchText

        expect(showTodoView.matches[1].matchText).toHaveLength 120
        expect(showTodoView.matches[1].matchText).toBe matchText2

    it 'should strip common block comment endings', ->
      atom.project.setPaths [path.join(__dirname, 'fixtures/sample2')]

      waitsForPromise ->
        showTodoView.fetchRegexItem(defaultLookup)
      runs ->
        expect(showTodoView.matches).toHaveLength 6
        expect(showTodoView.matches[0].matchText).toBe 'C block comment'
        expect(showTodoView.matches[1].matchText).toBe 'HTML comment'
        expect(showTodoView.matches[2].matchText).toBe 'PowerShell comment'
        expect(showTodoView.matches[3].matchText).toBe 'Haskell comment'
        expect(showTodoView.matches[4].matchText).toBe 'Lua comment'
        expect(showTodoView.matches[5].matchText).toBe 'PHP comment'

  describe 'fetchOpenRegexItem(lookupObj)', ->
    editor = null

    beforeEach ->
      waitsForPromise ->
        atom.workspace.open 'sample.c'
      runs ->
        editor = atom.workspace.getActiveTextEditor()

    it 'scans open files for the regex that is passed and fill lookup results', ->
      waitsForPromise ->
        showTodoView.fetchOpenRegexItem(defaultLookup)

      runs ->
        expect(showTodoView.matches).toHaveLength 1
        expect(showTodoView.matches.length).toBe 1
        expect(showTodoView.matches[0].matchText).toBe 'Comment in C'

    it 'works with files outside of workspace', ->
      waitsForPromise ->
        atom.workspace.open '../sample2/sample.txt'

      runs ->
        waitsForPromise ->
          showTodoView.fetchOpenRegexItem(defaultLookup)

        runs ->
          expect(showTodoView.matches).toHaveLength 7
          expect(showTodoView.matches[0].matchText).toBe 'Comment in C'
          expect(showTodoView.matches[1].matchText).toBe 'C block comment'
          expect(showTodoView.matches[6].matchText).toBe 'PHP comment'

    it 'handles unsaved documents', ->
      editor.setText 'TODO: New todo'

      waitsForPromise ->
        showTodoView.fetchOpenRegexItem(defaultLookup)
      runs ->
        expect(showTodoView.matches).toHaveLength 1
        expect(showTodoView.matches[0].title).toBe 'TODOs'
        expect(showTodoView.matches[0].matchText).toBe 'New todo'

    it 'respects imdone syntax (https://github.com/imdone/imdone-atom)', ->
      editor.setText '''
        TODO:10 todo1
        TODO:0 todo2
      '''

      waitsForPromise ->
        showTodoView.fetchOpenRegexItem(defaultLookup)
      runs ->
        expect(showTodoView.matches).toHaveLength 2
        expect(showTodoView.matches[0].title).toBe 'TODOs'
        expect(showTodoView.matches[0].matchText).toBe 'todo1'
        expect(showTodoView.matches[1].matchText).toBe 'todo2'

    it 'handles number in todo (as long as its not without space)', ->
      editor.setText """
        Line 1 //TODO: 1 2 3
        Line 1 // TODO:1 2 3
      """

      waitsForPromise ->
        showTodoView.fetchOpenRegexItem(defaultLookup)
      runs ->
        expect(showTodoView.matches).toHaveLength 2
        expect(showTodoView.matches[0].matchText).toBe '1 2 3'
        expect(showTodoView.matches[1].matchText).toBe '2 3'

    it 'handles empty todos', ->
      editor.setText """
        Line 1 // TODO
        Line 2 //TODO
      """

      waitsForPromise ->
        showTodoView.fetchOpenRegexItem(defaultLookup)
      runs ->
        expect(showTodoView.matches).toHaveLength 2
        expect(showTodoView.matches[0].matchText).toBe 'No details'
        expect(showTodoView.matches[1].matchText).toBe 'No details'

    it 'handles empty block todos', ->
      editor.setText """
        /* TODO */
        Line 2 /* TODO */
      """

      waitsForPromise ->
        showTodoView.fetchOpenRegexItem(defaultLookup)
      runs ->
        expect(showTodoView.matches).toHaveLength 2
        expect(showTodoView.matches[0].matchText).toBe 'No details'
        expect(showTodoView.matches[1].matchText).toBe 'No details'

    it 'handles todos with @ in front', ->
      editor.setText """
        Line 1 //@TODO: text
        Line 2 //@TODO: text
        Line 3 @TODO: text
      """

      waitsForPromise ->
        showTodoView.fetchOpenRegexItem(defaultLookup)
      runs ->
        expect(showTodoView.matches).toHaveLength 3
        expect(showTodoView.matches[0].matchText).toBe 'text'
        expect(showTodoView.matches[1].matchText).toBe 'text'
        expect(showTodoView.matches[2].matchText).toBe 'text'

    it 'handles tabs in todos', ->
      editor.setText 'Line //TODO:\ttext'

      waitsForPromise ->
        showTodoView.fetchOpenRegexItem(defaultLookup)
      runs ->
        expect(showTodoView.matches[0].matchText).toBe 'text'

    it 'handles todo without semicolon', ->
      editor.setText 'A line // TODO text'

      waitsForPromise ->
        showTodoView.fetchOpenRegexItem(defaultLookup)
      runs ->
        expect(showTodoView.matches[0].matchText).toBe 'text'

    it 'ignores todos without leading space', ->
      editor.setText 'A line // TODO:text'

      waitsForPromise ->
        showTodoView.fetchOpenRegexItem(defaultLookup)
      runs ->
        expect(showTodoView.matches).toHaveLength 0

    it 'ignores todo if unwanted chars are present', ->
      editor.setText 'define("_JS_TODO_ALERT_", "js:alert(&quot;TODO&quot;);");'

      waitsForPromise ->
        showTodoView.fetchOpenRegexItem(defaultLookup)
      runs ->
        expect(showTodoView.matches).toHaveLength 0

    it 'ignores binary data', ->
      editor.setText '// TODOe�d��RPPP0�'

      waitsForPromise ->
        showTodoView.fetchOpenRegexItem(defaultLookup)
      runs ->
        expect(showTodoView.matches).toHaveLength 0

  describe 'getMarkdown()', ->
    matches = []

    beforeEach ->
      atom.config.set 'todo-show.findTheseRegexes', defaultRegexes

      matches = [
        {
          matchText: 'fixme #1'
          relativePath: 'file1.txt'
          title: 'FIXMEs'
          range: [
            [3,6]
            [3,10]
          ]
        },
        {
          matchText: 'todo #1'
          relativePath: 'file1.txt'
          title: 'TODOs'
          range: [
            [4,5]
            [4,9]
          ]
        },
        {
          matchText: 'fixme #2'
          relativePath: 'file2.txt'
          title: 'FIXMEs'
          range: [
            [5,7]
            [5,11]
          ]
        }
      ]

    it 'creates a markdown string from regexes', ->
      markdown =  '\n## FIXMEs\n\n- fixme #1 `file1.txt` `:4`\n- fixme #2 `file2.txt` `:6`\n'
      markdown += '\n## TODOs\n\n- todo #1 `file1.txt` `:5`\n'
      expect(showTodoView.getMarkdown(matches)).toEqual markdown

    it 'creates markdown with file grouping', ->
      atom.config.set 'todo-show.groupMatchesBy', 'file'
      markdown =  '\n## file1.txt\n\n- fixme #1 `FIXMEs`\n- todo #1 `TODOs`\n'
      markdown += '\n## file2.txt\n\n- fixme #2 `FIXMEs`\n'
      expect(showTodoView.getMarkdown(matches)).toEqual markdown

    it 'creates markdown with non grouping', ->
      atom.config.set 'todo-show.groupMatchesBy', 'none'
      markdown =  '\n## All Matches\n\n- fixme #1 _(FIXMEs)_ `file1.txt` `:4`'
      markdown += '\n- fixme #2 _(FIXMEs)_ `file2.txt` `:6`\n- todo #1 _(TODOs)_ `file1.txt` `:5`\n'
      expect(showTodoView.getMarkdown(matches)).toEqual markdown

    it 'accepts missing ranges and paths in regexes', ->
      matches = [
        {
          matchText: 'fixme #1'
          title: 'FIXMEs'
        }
      ]
      markdown = '\n## FIXMEs\n\n- fixme #1\n'
      expect(showTodoView.getMarkdown(matches)).toEqual markdown

      atom.config.set 'todo-show.groupMatchesBy', 'file'
      markdown = '\n## Unknown File\n\n- fixme #1 `FIXMEs`\n'
      expect(showTodoView.getMarkdown(matches)).toEqual markdown

      atom.config.set 'todo-show.groupMatchesBy', 'none'
      markdown = '\n## All Matches\n\n- fixme #1 _(FIXMEs)_\n'
      expect(showTodoView.getMarkdown(matches)).toEqual markdown

    it 'accepts missing title in regexes', ->
      matches = [
        {
          matchText: 'fixme #1'
          relativePath: 'file1.txt'
        }
      ]
      markdown = '\n## No Title\n\n- fixme #1 `file1.txt`\n'
      expect(showTodoView.getMarkdown(matches)).toEqual markdown

      atom.config.set 'todo-show.groupMatchesBy', 'file'
      markdown = '\n## file1.txt\n\n- fixme #1\n'
      expect(showTodoView.getMarkdown(matches)).toEqual markdown

      atom.config.set 'todo-show.groupMatchesBy', 'none'
      markdown = '\n## All Matches\n\n- fixme #1 `file1.txt`\n'
      expect(showTodoView.getMarkdown(matches)).toEqual markdown
