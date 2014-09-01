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



# start with the basics first...


# TODO: make some test fixtures? pages... load those in require those instead? We really just want to unit test it
# and not run the whole thing... The more we can split it up the better...




# Should truncate really long comments
# Should only show TODOs in sections marked as 'comment'?


# buildRegexLookups
# test that regexes work from override settings as well as from default
