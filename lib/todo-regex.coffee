module.exports =
class TodoRegex
  constructor: (@regex, todoList) ->
    @error = false
    @regexp = @createRegexp(@regex, todoList)

  makeRegexObj: (regexStr = '') ->
    # Extract the regex pattern (anything between the slashes)
    pattern = regexStr.match(/\/(.+)\//)?[1]
    # Extract the flags (after last slash)
    flags = regexStr.match(/\/(\w+$)/)?[1]

    unless pattern
      @error = true
      return false
    new RegExp(pattern, flags)

  createRegexp: (regexStr, todoList) ->
    unless Object.prototype.toString.call(todoList) is '[object Array]' and
    todoList.length > 0 and
    regexStr
      @error = true
      return false
    @makeRegexObj(regexStr.replace('${TODOS}', todoList.join('|')))
