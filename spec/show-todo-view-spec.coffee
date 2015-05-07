# Tests in this file are all about the TODO fetching logic, and how we handle that data and then pass to the views.
# Good example:
# https://github.com/atom/tabs/blob/master/spec/tabs-spec.coffee

# TODO:
# - make buildRegexLookups testable. Input, and output. It doesn't care about state. Functional goodness...
# - look at symbol generator for extracting comment blocks

ShowTodoView = require '../lib/show-todo-view'

describe "buildRegexLookups(regexes)", ->
  showTodoView = null
  
  beforeEach ->
    pathname = "dummyData"
    showTodoView = new ShowTodoView(pathname)
  
  it "should return an array of objects (title, regex, results) when passed an array of regexes (and titles)", ->
    findTheseRegexes = [
      'TODOs'
      '/TODO:(.+$)/g'
    ]
    
    # build the regex
    regexes = showTodoView.buildRegexLookups(findTheseRegexes)

    # assert result should match the following
    lookups = [{
      'title': 'TODOs',
      'regex': '/TODO:(.+$)/g',
      'results': []
    }]
    expect(regexes).toEqual(lookups)
  
  it "should work a lot of regexes", ->
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
        'title': 'FIXMEs',
        'regex': '/FIXME:?(.+$)/g',
        'results': []
      },
      {
        'title': 'TODOs',
        'regex': '/TODO:?(.+$)/g',
        'results': []
      },
      {
        'title': 'CHANGEDs',
        'regex': '/CHANGED:?(.+$)/g',
        'results': []
      },
      {
        'title': 'XXXs',
        'regex': '/XXX:?(.+$)/g',
        'results': []
      }
    ]
    expect(regexes).toEqual(lookups)

describe "makeRegexObj(regexStr)", ->
  showTodoView = null
  
  beforeEach ->
    pathname = "dummyData"
    showTodoView = new ShowTodoView(pathname)

  it "should return a RegExp obj when passed a regex literal (string)", ->
    regexStr = "/TODO:(.+$)/g"
    regexObj = showTodoView.makeRegexObj(regexStr)

    # assertions duck test. Am I a regex obj?
    expect(typeof regexObj.test).toBe("function")
    expect(typeof regexObj.exec).toBe("function")

  it "should return false bool when passed an invalid regex literal (string)", ->
    regexStr = "arstastTODO:.+$)/g"
    regexObj = showTodoView.makeRegexObj(regexStr)

    expect(regexObj).toBe(false)

describe "fetchRegexItem: (lookupObj)", ->
  showTodoView = null
  
  beforeEach ->
    pathname = "dummyData"
    showTodoView = new ShowTodoView(pathname)
  
  it "should scan the workspace for the regex that is passed and fill lookups results", ->
    promise = null
    
    lookups = {
      'title': 'TODOs',
      'regex': '/TODO:(.+$)/g',
      'results': []
    }
    
    waitsForPromise ->
      promise = showTodoView.fetchRegexItem(lookups)
    
    runs ->
      # matches for sample.js (first file scraped)
      matches = lookups.results[0].matches
      expect(matches.length).toBe(2)
      expect(matches[0].matchText).toBe("This is the first todo")
      expect(matches[1].matchText).toBe("This is the second todo")



scan_mock = require './fixtures/atom_scan_mock_result.json'


# TODO: make some test fixtures? pages... load those in require those instead? We really just want to unit test it
# and not run the whole thing... The more we can split it up the better...




# Should truncate really long comments
# Should only show TODOs in sections marked as 'comment'?


# buildRegexLookups
# test that regexes work from override settings as well as from default
