# Tests in this file are all about the TODO fetching logic, and how we handle that data and then pass to the views.
# Good example:
# https://github.com/atom/tabs/blob/master/spec/tabs-spec.coffee

# TODO:
# - make buildRegexLookups testable. Input, and output. It doesn't care about state. Functional goodness...
# - look at symbol generator for extracting comment blocks

ShowTodoView = require '../lib/show-todo-view'
{WorkspaceView} = require 'atom'

# describe "ShowTodoView", ->
  # it "has one valid test", ->
  #   expect("life").toBe "easy"

# @FIXME: Put this in beforeEach?
pathname = "dummyData"
showTodoView = new ShowTodoView(pathname)

describe "buildRegexLookups(regexes)", ->
  it "should return an array of objects (title, regex, results) when passed an array of regexes (and titles)", ->
    # @FIXME: Should this be outside of this fn?
    findTheseRegexes = [
      'FIXMEs'
      '/FIXME:(.+$)/g'
      'TODOs' #title
      '/TODO:(.+$)/g'
      'CHANGEDs'
      '/CHANGED:(.+$)/g'
    ]

    # Build the regex
    regexes = showTodoView.buildRegexLookups(findTheseRegexes)

    # assert result should match the following
    exp_regexes = [{
      'title': 'FIXMEs',
      'regex': '/FIXME:(.+$)/g',
      'results': []
    },
    {
      'title': 'TODOs',
      'regex': '/TODO:(.+$)/g',
      'results': []
    },
    {
      'title': 'CHANGEDs',
      'regex': '/CHANGED:(.+$)/g',
      'results': []
    }]
    expect(regexes).toEqual(exp_regexes)



describe "makeRegexObj(regexStr)", ->
  it "should return a RegExp obj when passed a regex literal (string)", ->

    regexStr = "/TODO:(.+$)/g"
    regexObj = showTodoView.makeRegexObj(regexStr)

    # Assertions
    # duck test. Am I a regex obj?
    expect(typeof regexObj.test).toBe("function")
    expect(typeof regexObj.exec).toBe("function")

  it "should return false bool when passed an invalid regex literal (string)", ->

    regexStr = "arstastTODO:.+$)/g"
    regexObj = showTodoView.makeRegexObj(regexStr)

    expect(regexObj).toBe(false)



scan_mock = require './fixtures/atom_scan_mock_result.json'


# TODO: make some test fixtures? pages... load those in require those instead? We really just want to unit test it
# and not run the whole thing... The more we can split it up the better...




# Should truncate really long comments
# Should only show TODOs in sections marked as 'comment'?


# buildRegexLookups
# test that regexes work from override settings as well as from default
