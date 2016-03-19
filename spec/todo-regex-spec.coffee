TodoRegex = require '../lib/todo-regex'
ShowTodo = require '../lib/show-todo'

describe 'Todo Regex', ->
  [defaultRegexStr, defaultTodoList] = []

  beforeEach ->
    defaultRegexStr = ShowTodo.config.findUsingRegex.default
    defaultTodoList = ShowTodo.config.findTheseTodos.default

  describe 'create regexp', ->
    it 'includes a regular expression', ->
      todoRegex = new TodoRegex(defaultRegexStr, defaultTodoList)
      expect(typeof todoRegex.regexp.test).toBe('function')
      expect(typeof todoRegex.regexp.exec).toBe('function')
      expect(todoRegex.regex).toBe(defaultRegexStr)
      expect(todoRegex.error).toBe(false)

    it 'sets error on invalid input', ->
      todoRegex = new TodoRegex('arstastTODO:.+$)/g', defaultTodoList)
      expect(todoRegex.error).toBe(true)

      todoRegex = new TodoRegex(defaultRegexStr, 'a string')
      expect(todoRegex.error).toBe(true)

      todoRegex = new TodoRegex(defaultRegexStr, [])
      expect(todoRegex.error).toBe(true)

    it 'handles empty input', ->
      todoRegex = new TodoRegex()
      expect(todoRegex.error).toBe(true)

      todoRegex = new TodoRegex('', defaultTodoList)
      expect(todoRegex.error).toBe(true)
