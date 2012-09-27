{exec, spawn} = require 'child_process'
fs = require 'fs'

build = (callback) ->
  exec 'mkdir -p lib', (err, stdout, stderr) ->
    throw new Error(err) if err
    exec './node_modules/coffee-script/bin/coffee --compile --output lib/ src/', (err, stdout, stderr) ->
      throw new Error(err) if err
      callback() if callback

test = ->
  build ->
    spawn './node_modules/mocha/bin/mocha', ['./test/'], stdio: 'inherit'

task 'build', 'Build lib from src', -> build()
task 'test', 'Test project', -> test()
