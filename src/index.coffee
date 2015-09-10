isString          = require 'util-ex/lib/is/type/string'
isArray           = require 'util-ex/lib/is/type/array'
isObject          = require 'util-ex/lib/is/type/object'
Task              = require 'task-registry'
once              = require 'once'
register          = Task.register
aliases           = Task.aliases
defineProperties  = Task.defineProperties
getObjectKeys     = Object.keys

INVALID_ARGUMENT  = 'Task argument should be a task name or object'
MISS_TASKS_OPTION = 'missing tasks option'

module.exports = class SeriesTask
  register SeriesTask
  aliases SeriesTask, 'series'
  defineProperties SeriesTask,
    force:
      type: 'Boolean'
    pipeline:
      type: 'Boolean'
      value: false
    logger: # it should be an object with log, error methods at least.
      type: 'Object'
      clone: false
      value: console
  constructor: -> return super
  error: (err, aOptions, raiseError = true)->
    aOptions ?= @
    if isString err
      err = new TypeError err
    if aOptions.force or !raiseError
      aOptions.logger.error err
    else
      throw err
    err
  _execTaskSync: (aTask, result, aOptions)->
    if isString aTask
      task = Task aTask
      if task
        try
          result.push task.executeSync()
        catch err
          @error err, aOptions
          result.push undefined
      else
        @error 'Task "' + aTask + '" is not exists.', aOptions
        result.push undefined
    else if isObject aTask
      for k,v of aTask
        task = Task k
        if task
          try
            result.push task.executeSync(v)
          catch err
            @error err, aOptions
            result.push undefined
        else
          @error 'Task "' + k + '" is not exists.', aOptions
          result.push undefined
    else
      @error INVALID_ARGUMENT, aOptions
      result.push undefined
    result
  _executeSync: (aOptions)->
    vTasks = aOptions.tasks
    result = []
    if isArray vTasks
      vTasks.forEach (obj)=>
        @_execTaskSync obj, result, aOptions
    else
      @_execTaskSync vTasks, result, aOptions
    result
  _executePipeSync: (aOptions)->
    vTasks = aOptions.tasks
    result = null
    first = true
    if isArray vTasks
      vTasks.forEach (obj, i)=>
        if isString obj
          task = Task obj
          if task
            first = false if first
            try
              result = task.executeSync(result)
            catch err
              @error err, aOptions
          else
            @error 'Task "' + obj + '" is not exists.', aOptions
        else if isObject obj
          for k,v of obj
            task = Task k
            if first
              result = v
              first = false
            if task
              try
                result = task.executeSync(result)
              catch err
                @error err, aOptions
            else
              @error 'Task "' + k + '" is not exists.', aOptions
        else
          first = false if first
          @error INVALID_ARGUMENT, aOptions
    else
      for k,v of vTasks
        task = Task k
        if first
          result = v
          first = false
        if task
          try
            result = task.executeSync(result)
          catch err
            @error err, aOptions
        else
          @error 'Task "' + k + '" is not exists.', aOptions
    result
  _execute: (aOptions, done)->
    vTasks = aOptions.tasks
    results = []
    idx = 0

    nextObj = (aTask)->
      keys = getObjectKeys aTask
      vObjLen = keys.length
      vObjIx = 0
      _nextObj = (name)->
        task = Task name
        if task
          task.execute aTask[name], once (err, result)->
            if err
              aOptions.logger.error err
              unless aOptions.force
                return done(err)
            results.push result
            if ++vObjIx < vObjLen
              _nextObj(keys[vObjIx])
            else if length and ++idx < length
              nextArray(vTasks[idx])
            else
              done(null, results)
        else if aOptions.force
          aOptions.logger.error new TypeError('Task "' + name + '" is not exists.')
          results.push undefined
          if ++vObjIx < vObjLen
            _nextObj(keys[vObjIx])
          else if length and ++idx < length
            nextArray(vTasks[idx])
          else
            done(null, results)
        else
          return done new TypeError('Task "'+ name+ '" is not exists.')
      _nextObj(keys[vObjIx])

    nextArray = (aTask)->
      if isString aTask
        task = Task aTask
        if task
          task.execute once (err, result)->
            if err
              return done(err) unless aOptions.force
            results.push result
            if ++idx < length
              nextArray(vTasks[idx])
            else
              done(null, results)
        else if aOptions.force
          aOptions.logger.error new TypeError('Task "' + aTask + '" is not exists.')
          results.push undefined
          if ++idx < length
            nextArray(vTasks[idx])
          else
            done(null, results)
        else
          return done new TypeError('Task "' + aTask + '" is not exists.')
      else if isObject aTask
        nextObj(aTask)
      else if aOptions.force
        results.push undefined
        aOptions.logger.error new TypeError(INVALID_ARGUMENT)
        if ++idx < length
          nextArray(vTasks[idx])
        else
          done(null, results)
      else
        return done new TypeError(INVALID_ARGUMENT)

    if isArray vTasks
      length = vTasks.length
      nextArray(vTasks[idx])
    else
      nextObj(vTasks)
    return
  _executePipe: (aOptions, done)->
    vTasks = aOptions.tasks
    results = null
    idx = 0
    first = true

    nextObj = (aTask)->
      keys = getObjectKeys aTask
      vObjLen = keys.length
      vObjIx = 0
      _nextObj = (name)->
        task = Task name
        if task
          if first
            results = aTask[name]
            first = false
          task.execute results, once (err, result)->
            if err
              aOptions.logger.error err
              unless aOptions.force
                return done(err)
            results = result
            if ++vObjIx < vObjLen
              _nextObj(keys[vObjIx])
            else if length and ++idx < length
              nextArray(vTasks[idx])
            else
              done(null, results)
        else if aOptions.force
          aOptions.logger.error new TypeError('Task "' + name + '" is not exists.')
          if ++vObjIx < vObjLen
            _nextObj(keys[vObjIx])
          else if length and ++idx < length
            nextArray(vTasks[idx])
          else
            done(null, results)
        else
          return done new TypeError('Task "'+ name + '" is not exists.')
      _nextObj(keys[vObjIx])

    nextArray = (aTask)->
      if isString aTask
        task = Task aTask
        if task
          first = false if first
          task.execute results, once (err, result)->
            if err
              aOptions.logger.error err
              return done(err) unless aOptions.force
            results = result
            if ++idx < length
              nextArray(vTasks[idx])
            else
              done(null, results)
        else if aOptions.force
          aOptions.logger.error new TypeError('Task "' + aTask + '" is not exists.')
          if ++idx < length
            nextArray(vTasks[idx])
          else
            done(null, results)
        else
          return done new TypeError('Task "' + aTask + '" is not exists.')
      else if isObject aTask
        nextObj(aTask)
      else if aOptions.force
        first = false if first
        aOptions.logger.error new TypeError INVALID_ARGUMENT
        if ++idx < length
          nextArray(vTasks[idx])
        else
          done(null, results)
      else
        return done new TypeError(INVALID_ARGUMENT)

    if isArray vTasks
      length = vTasks.length
      nextArray(vTasks[idx])
    else
      nextObj(vTasks)
    return

  executeSync: (aOptions)->
    if isString aOptions
      vTasks = [aOptions]
      aOptions = {tasks: vTasks}
    else if isArray aOptions
      vTasks = aOptions
      aOptions = {tasks: vTasks}
    else if aOptions
      vPipeline = aOptions.pipeline
      vTasks = aOptions.tasks
    aOptions = @mergeTo(aOptions)

    if vTasks
      if vPipeline
        result = @_executePipeSync(aOptions)
      else
        result = @_executeSync(aOptions)
    else
      err = new TypeError MISS_TASKS_OPTION
      @error err, aOptions
    result

  execute: (aOptions, done)->
    if isString aOptions
      vTasks = [aOptions]
      aOptions = {tasks: vTasks}
    else if isArray aOptions
      vTasks = aOptions
      aOptions = {tasks:vTasks}
    else if aOptions
      vPipeline = aOptions.pipeline
      vTasks = aOptions.tasks
    done = once(done)
    aOptions = @mergeTo(aOptions)

    if vTasks
      if vPipeline
        result = @_executePipe(aOptions, done)
      else
        result = @_execute(aOptions, done)
    else
      err = new TypeError MISS_TASKS_OPTION
      if aOptions.force
        aOptions.logger.error err
        err = null
      done(err)

    return @