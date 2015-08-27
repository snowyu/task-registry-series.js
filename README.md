## task-registry-series [![npm](https://img.shields.io/npm/v/task-registry-series.svg)](https://npmjs.org/package/task-registry-series)

[![Build Status](https://img.shields.io/travis/snowyu/task-registry-series.js/master.svg)](http://travis-ci.org/snowyu/task-registry-series.js)
[![Code Climate](https://codeclimate.com/github/snowyu/task-registry-series.js/badges/gpa.svg)](https://codeclimate.com/github/snowyu/task-registry-series.js)
[![Test Coverage](https://codeclimate.com/github/snowyu/task-registry-series.js/badges/coverage.svg)](https://codeclimate.com/github/snowyu/task-registry-series.js/coverage)
[![downloads](https://img.shields.io/npm/dm/task-registry-series.svg)](https://npmjs.org/package/task-registry-series)
[![license](https://img.shields.io/npm/l/task-registry-series.svg)](https://npmjs.org/package/task-registry-series)

The SeriesTask run a task collection(array) one by one.

## Usage

```coffee
Task    = require 'task-registry'
tasks   = require 'task-registry-series'
register= Task.register

class OneTask
  register OneTask
  executeSync: (aOptions)->
    # the aOptions is the default options object of the task if no arguments passed.
    aOptions = 0 unless isNumber aOptions
    aOptions+1

class TwoTask
  register TwoTask
  executeSync: (aOptions)->
    aOptions = 0 unless isNumber aOptions
    aOptions+2

result = tasks.execSync
  pipeline: true
  tasks: [
    One: 1 # call OneTask with 1 argument
  , 'Two'  # call Two
  ]  # the result should be 4
```

## API

tasks.execSync(aOptions)/task.exec(aOptions, done)

* aOptions *(Object|Array|String)*: it's a tasks if it's array.
  it's a task name if it's string.
  * pipeline *(Boolean)*: whether the pass the result as a pipeline. default to false.
   * If true, the first task will be called with the arguments, and each subsequence task will be called with the result of the previous task.
   * If false, Each task will be called with the arguments, and each may return a value.
  * tasks *(ArrayOf String|Object)*: the tasks to run.
    * Object:
      * key: it's the task name
      * value: it's the arugments object to be passed.



## TODO


## License

MIT
