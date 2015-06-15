
path = require 'path'

ShowTodoView = require '../lib/show-todo-view'

describe 'ShowTodoView fetching logic and data handling', ->
  showTodoView = null

  beforeEach ->
    pathname = 'dummyData'
    showTodoView = new ShowTodoView(pathname)
    atom.project.setPaths [path.join(__dirname, 'fixtures/sample1')]

  describe 'buildRegexLookups(regexes)', ->
    it 'should return an array of objects (title, regex, results) when passed an array of regexes (and titles)', ->
      findTheseRegexes = [
        'TODOs'
        '/TODO:?(.+$)/g'
      ]

      regexes = showTodoView.buildRegexLookups(findTheseRegexes)

      lookups = [{
        title: 'TODOs'
        regex: '/TODO:?(.+$)/g'
        results: []
      }]
      expect(regexes).toEqual(lookups)

    it 'should work with a lot of regexes', ->
      findTheseRegexes = [
        'FIXMEs'
        '/FIXME:?(.+$)/g'
        'TODOs'
        '/TODO:?(.+$)/g'
        'CHANGEDs'
        '/CHANGED:?(.+$)/g'
        'XXXs'
        '/XXX:?(.+$)/g'
      ]
      regexes = showTodoView.buildRegexLookups(findTheseRegexes)
      lookups = [
        {
          title: 'FIXMEs'
          regex: '/FIXME:?(.+$)/g'
          results: []
        }
        {
          title: 'TODOs'
          regex: '/TODO:?(.+$)/g'
          results: []
        }
        {
          title: 'CHANGEDs'
          regex: '/CHANGED:?(.+$)/g'
          results: []
        }
        {
          title: 'XXXs'
          regex: '/XXX:?(.+$)/g'
          results: []
        }
      ]
      expect(regexes).toEqual(lookups)

  describe 'makeRegexObj(regexStr)', ->
    it 'should return a RegExp obj when passed a regex literal (string)', ->
      regexStr = '/TODO:?(.+$)/g'
      regexObj = showTodoView.makeRegexObj(regexStr)

      # Assertions duck test. Am I a regex obj?
      expect(typeof regexObj.test).toBe('function')
      expect(typeof regexObj.exec).toBe('function')

    it 'should return false bool when passed an invalid regex literal (string)', ->
      regexStr = 'arstastTODO:.+$)/g'
      regexObj = showTodoView.makeRegexObj(regexStr)

      expect(regexObj).toBe(false)

  describe 'handleScanResult(result, regex)', ->
    {result, regex} = []

    beforeEach ->
      regex = /\b@?TODO:?\s(.+$)/g
      result =
        filePath: "#{atom.project.getPaths()[0]}/sample.c"
        matches: [
          matchText: ' TODO: Comment in C '
          range: [
            [0, 1]
            [0, 20]
          ]
        ]

    it 'should handle results from workspace scan (also tested in fetchRegexItem)', ->
      output = showTodoView.handleScanResult(result)
      expect(output.matches[0].matchText).toEqual 'TODO: Comment in C'

    it 'should remove regex part', ->
      output = showTodoView.handleScanResult(result, regex)
      expect(output.matches[0].matchText).toEqual 'Comment in C'

    it 'should serialize range and relativize path', ->
      output = showTodoView.handleScanResult(result, regex)
      expect(output.relativePath).toEqual 'sample.c'
      expect(output.matches[0].rangeString).toEqual '0,1,0,20'

  describe 'fetchRegexItem: (lookupObj)', ->
    todoLookup = []

    beforeEach ->
      todoLookup =
        title: 'TODOs'
        regex: '/\\b@?TODO:?\\s(.+$)/g'
        results: []

    it 'should scan the workspace for the regex that is passed and fill lookup results', ->
      waitsForPromise ->
        showTodoView.fetchRegexItem(todoLookup)

      runs ->
        expect(todoLookup.results.length).toBe 2
        expect(todoLookup.results[0].matches[0].matchText).toBe 'Comment in C'
        expect(todoLookup.results[1].matches[0].matchText).toBe 'This is the first todo'
        expect(todoLookup.results[1].matches[1].matchText).toBe 'This is the second todo'

    it 'should respect ignored paths', ->
      atom.config.set('todo-show.ignoreThesePaths', '*/sample.js')

      waitsForPromise ->
        showTodoView.fetchRegexItem(todoLookup)
      runs ->
        expect(todoLookup.results.length).toBe 1
        expect(todoLookup.results[0].matches[0].matchText).toBe 'Comment in C'

    it 'should handle other regexes', ->
      lookup =
        title: 'Includes'
        regex: '/#include(.+)/g'
        results: []

      waitsForPromise ->
        showTodoView.fetchRegexItem(lookup)
      runs ->
        expect(lookup.results[0].matches[0].matchText).toBe '<stdio.h>'

    it 'should handle specieal character regexes', ->
      lookup =
        title: 'Todos'
        regex: '/ This is the (?:first|second) todo/g'
        results: []

      waitsForPromise ->
        showTodoView.fetchRegexItem(lookup)
      runs ->
        expect(lookup.results[0].matches[0].matchText).toBe 'This is the first todo'
        expect(lookup.results[0].matches[1].matchText).toBe 'This is the second todo'

    it 'should handle regex without capture group', ->
      lookup =
        title: 'This is Code'
        regex: '/[\\w\\s]+code[\\w\\s]*/g'
        results: []

      waitsForPromise ->
        showTodoView.fetchRegexItem(lookup)
      runs ->
        expect(lookup.results[0].matches[0].matchText).toBe 'Sample quicksort code'

    it 'should handle post-annotations with special regex', ->
      lookup =
        title: 'Pre-DEBUG'
        regex: '/(.+).{3}DEBUG\\s*$/g'
        results: []

      waitsForPromise ->
        showTodoView.fetchRegexItem(lookup)
      runs ->
        expect(lookup.results[0].matches[0].matchText).toBe 'return sort(Array.apply(this, arguments));'

    it 'should handle post-annotations with non-capturing group', ->
      lookup =
        title: 'Pre-DEBUG'
        regex: '/(.+?(?=.{3}DEBUG\\s*$))/'
        results: []

      waitsForPromise ->
        showTodoView.fetchRegexItem(lookup)
      runs ->
        expect(lookup.results[0].matches[0].matchText).toBe 'return sort(Array.apply(this, arguments));'

    it 'should truncate matches longer than the defined max length of 120', ->
      lookup =
        title: 'Long Annotation'
        regex: '/LOONG:?(.+$)/g'
        results: []

      waitsForPromise ->
        showTodoView.fetchRegexItem(lookup)
      runs ->
        matchText = 'Lorem ipsum dolor sit amet, dapibus rhoncus. Scelerisque quam,'
        matchText += ' id ante molestias, ipsum lorem magnis et. A eleifend i...'

        matchText2 = '_SpgLE84Ms1K4DSumtJDoNn8ZECZLL+VR0DoGydy54vUoSpgLE84Ms1K4DSum'
        matchText2 += 'tJDoNn8ZECZLLVR0DoGydy54vUonRClXwLbFhX2gMwZgjx250ay+V0lF...'

        expect(lookup.results[0].matches[0].matchText.length).toBe 120
        expect(lookup.results[0].matches[0].matchText).toBe matchText

        expect(lookup.results[0].matches[1].matchText.length).toBe 120
        expect(lookup.results[0].matches[1].matchText).toBe matchText2

    it 'should strip common block comment endings', ->
      atom.project.setPaths [path.join(__dirname, 'fixtures/sample2')]

      waitsForPromise ->
        showTodoView.fetchRegexItem(todoLookup)
      runs ->
        expect(todoLookup.results[0].matches.length).toBe 5
        expect(todoLookup.results[0].matches[0].matchText).toBe 'C block comment'
        expect(todoLookup.results[0].matches[1].matchText).toBe 'HTML comment'
        expect(todoLookup.results[0].matches[2].matchText).toBe 'PowerShell comment'
        expect(todoLookup.results[0].matches[3].matchText).toBe 'Haskell comment'
        expect(todoLookup.results[0].matches[4].matchText).toBe 'Lua comment'

  describe 'fetchOpenRegexItem: (lookupObj)', ->
    todoLookup = []

    beforeEach ->
      todoLookup =
        title: 'TODOs'
        regex: '/\\b@?TODO:?\\s(.+$)/g'
        results: []
      waitsForPromise ->
        atom.workspace.open 'sample.c'

    it 'should scan open files for the regex that is passed and fill lookup results', ->
      waitsForPromise ->
        showTodoView.fetchOpenRegexItem(todoLookup)

      runs ->
        expect(todoLookup.results.length).toBe 1
        expect(todoLookup.results[0].matches.length).toBe 1
        expect(todoLookup.results[0].matches[0].matchText).toBe 'Comment in C'

    it 'should work with files outside of workspace', ->
      waitsForPromise ->
        atom.workspace.open '../sample2/sample.txt'

      runs ->
        waitsForPromise ->
          showTodoView.fetchOpenRegexItem(todoLookup)

        runs ->
          expect(todoLookup.results.length).toBe 2
          expect(todoLookup.results[0].matches[0].matchText).toBe 'Comment in C'
          expect(todoLookup.results[1].matches[0].matchText).toBe 'C block comment'


# TODO:
# - make buildRegexLookups testable. Input, and output. It doesn't care about state. Functional goodness...
# - look at symbol generator for extracting comment blocks
