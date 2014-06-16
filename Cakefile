{spawn} = require 'child_process'

task 'build', 'Build lib from src', (callback) ->
  spawn 'coffee', ['--compile', '--output', 'lib/', 'src/'], stdio: 'inherit', (err) ->
    throw new Error(err) if err
    callback?()

task 'test', 'Run Mocha tests', (callback) ->
    spawn 'mocha', ['--compilers', 'coffee:coffee-script/register', '--recursive', 'test'], stdio: 'inherit', (err) ->
      throw new Error(err) if err
      callback?()
