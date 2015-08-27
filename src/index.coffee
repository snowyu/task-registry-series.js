isString          = require 'util-ex/lib/is/type/string'
isArray           = require 'util-ex/lib/is/type/array'
isObject          = require 'util-ex/lib/is/type/object'
Task              = require 'task-registry'
once              = require 'once'
tick              = require 'next-tick'
register          = Task.register
aliases           = Task.aliases
defineProperties  = Task.defineProperties
getObjectKeys     = Object.keys

INVALID_ARGUMENT  = 'Task argument should be a task name or object'

module.exports = class SeriesTask
  register SeriesTask
  aliases SeriesTask, 'tasks', 'Tasks', 'series'
  defineProperties SeriesTask,
    force:
      type: 'Boolean'
    pipeline:
      type: 'Boolean'
      value: false
    log:
      type: 'Function'
      value: console.error
  constructor: -> return super
  error: (err)->
    if isString err
      err = new TypeError err
    if @force
      @log err
    else
      throw err
    return
  _execTaskSync: (aTask, result)->
    if isString aTask
      task = Task aTask
      if task
        try
          result.push task.executeSync()
        catch err
          @error err
      else
        @error 'Task "' + aTask + '" is not exists.'
    else if isObject
      for k,v of aTask
        task = Task k
        if task
          try
            result.push task.executeSync(v)
          catch err
            @error err
        else
          @error 'Task "' + k + '" is not exists.'
    else
      @error INVALID_ARGUMENT
    result
  _executeSync: (aTasks)->
    result = []
    if isArray aTasks
      aTasks.forEach (obj)=>
        @_execTaskSync obj, result
    else
      @_execTaskSync aTasks, result
    result
  _executePipeSync: (aTasks)->
    result = null
    if isArray aTasks
      aTasks.forEach (obj, i)=>
        if isString obj
          task = Task obj
          if task
            try
              result = task.executeSync(result)
            catch err
              @error err
          else
            @error 'Task "' + obj + '" is not exists.'
        else if isObject obj
          for k,v of obj
            task = Task k
            result = v if i == 0
            if task
              try
                result = task.executeSync(result)
              catch err
                @error err
            else
              @error 'Task "' + k + '" is not exists.'
        else
          @error INVALID_ARGUMENT
    else
      first = true
      for k,v of obj
        task = Task k
        if first
          result = v
          first = false
        if task
          try
            result = task.executeSync(result)
          catch err
            @error err
        else
          @error 'Task "' + k + '" is not exists.'
    result
  _execute: (aTasks, done)->
    results = []
    idx = 0

    nextObj = (aTask)->
      keys = getObjectKeys aTask
      vObjLen = keys.length
      vObjIx = 0
      _nextObj = (name)=>
        task = Task name
        if task
          task.execute aTask[name], once (err, result)=>
            if err
              @log err
              unless @force
                return done(err)
            results.push result
            if ++vObjIx < vObjLen
              _nextObj(keys[vObjIx])
            else if length and ++idx < length
              nextArray(aTasks[idx])
            else
              done(null, results)
        else if @force
          if ++vObjIx < vObjLen
            tick _nextObj(keys[vObjIx])
          else if length and ++idx < length
            nextArray(aTasks[idx])
          else
            done(null, results)
        else
          return done new TypeError('task ', name, ' is not exists.')
      _nextObj(keys[vObjIx])

    nextArray = (aTask)=>
      if isString aTask
        task = Task aTask
        if task
          task.execute once (err, result)=>
            if err
              @log err
              return done(err) unless @force
            results.push result
            if ++idx < length
              nextArray(aTasks[idx])
            else
              done(null, results)
        else if @force
          if ++idx < length
            tick nextArray(aTasks[idx])
          else
            done(null, results)
        else
          return done new TypeError('task ', aTask, ' is not exists.')
      else if isObject aTask
        nextObj(aTask)
      else if @force
        if ++idx < length
          tick nextArray(aTasks[idx])
        else
          done(null, results)
      else
        return done new TypeError(INVALID_ARGUMENT)

    if isArray aTasks
      length = aTasks.length
      nextArray(aTasks[idx])
    else
      nextObj(aTasks)
    return
  _executePipe: (aTasks, done)->
    results = null
    idx = 0
    first = true

    nextObj = (aTask)->
      keys = getObjectKeys aTask
      vObjLen = keys.length
      vObjIx = 0
      _nextObj = (name)=>
        task = Task name
        if task
          if first
            results = aTask[name]
            first = false
          task.execute results, once (err, result)=>
            if err
              @log err
              unless @force
                return done(err)
            results = result
            if ++vObjIx < vObjLen
              _nextObj(keys[vObjIx])
            else if length and ++idx < length
              nextArray(aTasks[idx])
            else
              done(null, results)
        else if @force
          if ++vObjIx < vObjLen
            tick _nextObj(keys[vObjIx])
          else if length and ++idx < length
            nextArray(aTasks[idx])
          else
            done(null, results)
        else
          return done new TypeError('task ', name, ' is not exists.')
      _nextObj(keys[vObjIx])

    nextArray = (aTask)=>
      if isString aTask
        task = Task aTask
        if task
          first = false if first
          task.execute results, once (err, result)=>
            if err
              @log err
              return done(err) unless @force
            results = result
            if ++idx < length
              nextArray(aTasks[idx])
            else
              done(null, results)
        else if @force
          if ++idx < length
            tick nextArray(aTasks[idx])
          else
            done(null, results)
        else
          return done new TypeError('task ', aTask, ' is not exists.')
      else if isObject aTask
        nextObj(aTask)
      else if @force
        if ++idx < length
          tick nextArray(aTasks[idx])
        else
          done(null, results)
      else
        return done new TypeError(INVALID_ARGUMENT)

    if isArray aTasks
      length = aTasks.length
      nextArray(aTasks[idx])
    else
      nextObj(aTasks)
    return

  executeSync: (aOptions)->
    if isString aOptions
      vTasks = [aOptions]
    else if isArray aOptions
      vTasks = aOptions
    else if aOptions
      vPipeline = aOptions.pipeline
      vTasks = aOptions.tasks

    if vTasks
      if vPipeline
        result = @_executePipeSync(vTasks)
      else
        result = @_executeSync(vTasks)
    result

  execute: (aOptions, done)->
    if isString aOptions
      vTasks = [aOptions]
    else if isArray aOptions
      vTasks = aOptions
    else if aOptions
      vPipeline = aOptions.pipeline
      vTasks = aOptions.tasks
    done = once(done)

    if vTasks
      if vPipeline
        result = @_executePipe(vTasks, done)
      else
        result = @_execute(vTasks, done)
    return @