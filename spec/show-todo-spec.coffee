# Tests in this file are all about ensuring the command works properly and loads the proper panes...

ShowTodo = require '../lib/show-todo'

# Use the command `window:run-package-specs` (cmd-alt-ctrl-p) to run specs.
#
# To run a specific `it` or `describe` block add an `f` to the front (e.g. `fit`
# or `fdescribe`). Remove the `f` to unfocus the block.
#
# describe "ShowTodo", ->
#   activationPromise = null
#
#   beforeEach ->
#     atom.workspaceView = new WorkspaceView
#     activationPromise = atom.packages.activatePackage('showTodo')
#
#   describe "when the show-todo:toggle event is triggered", ->
#     it "attaches and then detaches the view", ->
#       expect(atom.workspaceView.find('.show-todo')).not.toExist()
#
#       # This is an activation event, triggering it will cause the package to be
#       # activated.
#       atom.workspaceView.trigger 'show-todo:toggle'
#
#       waitsForPromise ->
#         activationPromise
#
#       runs ->
#         expect(atom.workspaceView.find('.show-todo')).toExist()
#         atom.workspaceView.trigger 'show-todo:toggle'
#         expect(atom.workspaceView.find('.show-todo')).not.toExist()
