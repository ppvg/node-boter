flour = require 'flour'
cp    = require 'child_process'

mochaArgs = [
  '--compilers', 'coffee:coffee-script'
  '-r', 'test/common'
  '-c'
]
mochaPath = 'node_modules/mocha/bin/mocha'

task 'build', "Compile the source files to into lib/", ->
  for file in ['Bot', 'Message', 'UserDB', 'regex', 'index']
    compile "src/#{file}.coffee", "lib/#{file}.js"

task 'test', "Run the tests using mocha", ->
  invoke 'build'
  args = mochaArgs.concat ['--reporter', 'spec']
  cp.spawn mochaPath, args, {stdio: 'inherit'}

task 'coverage', "Generate code coverage report using jscoverage (saved as coverage.html)", ->
  invoke 'build'
  jscov = cp.spawn 'jscoverage', ['--no-highlight', 'lib', 'lib-cov'], {stdio: 'inherit'}
  jscov.on 'exit', (code, signal) ->
    if code is 0 and not signal?
      file = require('fs').createWriteStream 'coverage.html'
      args = mochaArgs.concat ['--reporter', 'html-cov']
      process.env['BOTER_COV'] = 1
      mocha = cp.spawn mochaPath, args
      mocha.stdout.pipe file
      mocha.on 'exit', -> cp.spawn 'rm', ['-r', 'lib-cov']

task 'watch', "Watch src/ and test/ and run 'test' when anything changes", ->
  invoke 'watch-src'
  args = mochaArgs.concat ['--watch', '--reporter', 'min', '-G']
  cp.spawn mochaPath, args, {stdio: 'inherit'}

task 'watch-src', "Watch src/ and run 'build' when anything changes", ->
  invoke 'build'
  watch 'src/', -> invoke 'build'

task 'make', "Alias for 'build'", -> invoke 'build'
task 'cov', "Alias for 'coverage'", -> invoke 'coverage'
