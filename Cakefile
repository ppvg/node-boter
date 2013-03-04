flour = require 'flour'
cp    = require 'child_process'

mocha_args = [
  '--compilers', 'coffee:coffee-script'
  '-r', 'should'
  '-c'
]

task 'build', ->
  for file in ['Boter', 'Message', 'regex']
    compile "src/#{file}.coffee", "lib/#{file}.js"

task 'watch-src', ->
  invoke 'build'
  watch 'src/', -> invoke 'build'

task 'watch', ->
  invoke 'watch-src'
  args = mocha_args.concat ['--watch', '--reporter', 'min']
  cp.spawn 'node_modules/mocha/bin/mocha', args, {stdio: 'inherit'}

task 'test', ->
  invoke 'build'
  args = mocha_args.concat ['--reporter', 'spec']
  cp.spawn 'node_modules/mocha/bin/mocha', args, {stdio: 'inherit'}

###
  TODO: coverage

  coverage: instrument
    @BOTER_COV=1 $(MOCHA) $(MOCHA_OPTS) \
    --reporter html-cov > lib-cov/report.html

   var fs = require('fs'),
       spawn = require('child_process').spawn,
       out = fs.openSync('./out.log', 'a'),
       err = fs.openSync('./out.log', 'a');

   var child = spawn('prg', [], {
     detached: true,
     stdio: [ 'ignore', out, err ]
   });

   child.unref();

###
