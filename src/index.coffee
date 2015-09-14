isString          = require 'util-ex/lib/is/type/string'
isArray           = require 'util-ex/lib/is/type/array'
isObject          = require 'util-ex/lib/is/type/object'
isFunction        = require 'util-ex/lib/is/type/function'
format            = require 'util-ex/lib/format'
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
    logger: # it should be an object with write method at least.
      type: 'Object'
      clone: false
      assign: (value, dest, src, name)->
        if isObject(value)
          if !isFunction(value.status)
            value.status = (args...)->
              @write.apply @, args
              @write()
              value
          if !isFunction(value.write)
            value.write = ->
              vStr = if arguments.length then format.apply(null, arguments) else '\n'
              process.stderr.write vStr
              value
            value.status('WARNING', 'the logger object has no "status" method.')

          value
        else if value?
          throw new TypeError 'the logger should be an object'
  constructor: -> return super
  error: (err, aOptions, aTask, raiseError = true)->
    aOptions ?= @
    if isString err
      err = new TypeError err
    if aOptions.force or !raiseError
      if aOptions.logger
        if aTask
          aOptions.logger.status 'ERROR', aTask, err.message
        else
          aOptions.logger.status 'ERROR', err.message
    else
      throw err
    err
  _execTaskSync: (aTask, result, aOptions)->
    logger = aOptions.logger
    #vHasSingleStatus = logger and logger.single and logger.single.status
    if isString aTask
      task = Task aTask
      if task
        try
          logger.status 'DEBUG', 'INVOKE', task.inspect() if logger
          result.push task.executeSync()
          logger.status 'DEBUG', 'INVOKE', task.inspect(), 'result=', result if logger
          logger.status 'INVOKE', task.inspect(), 'ok' if logger
        catch err
          @error err, aOptions, task.inspect()
          result.push undefined
      else
        @error 'Task "'+aTask+'" is not exists.', aOptions
        result.push undefined
    else if isObject aTask
      for k,v of aTask
        task = Task k
        if task
          try
            logger.status 'DEBUG', 'INVOKE', task.inspect() if logger
            result.push task.executeSync(v)
            logger.status 'DEBUG', 'INVOKE', task.inspect(), 'result=', result if logger
            logger.status 'INVOKE', task.inspect(), 'ok' if logger
          catch err
            @error err, aOptions, task
            result.push undefined
        else
          @error 'Task "'+k+'" is not exists.', aOptions
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
    logger = aOptions.logger
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
              logger.status 'DEBUG', 'INVOKE', task.inspect() if logger
              result = task.executeSync(result)
              logger.status 'DEBUG', 'INVOKE', task.inspect(), 'result=', result if logger
              logger.status 'INVOKE', task.inspect(), 'ok' if logger
            catch err
              @error err, aOptions, task.inspect()
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
                @error err, aOptions, task.inspect()
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
            @error err, aOptions, task.inspect()
        else
          @error 'Task "' + k + '" is not exists.', aOptions
    result
  _execute: (aOptions, done)->
    logger = aOptions.logger
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
          logger.status 'DEBUG', 'INVOKE', task.inspect() if logger
          task.execute aTask[name], once (err, result)->
            if err
              logger.status 'ERROR', task.inspect(), err.message if logger
              unless aOptions.force
                return done(err)
            logger.status 'DEBUG', 'INVOKE', task.inspect(), 'result=', result if logger
            logger.status 'INVOKE', task.inspect(), 'ok' if logger
            results.push result
            if ++vObjIx < vObjLen
              _nextObj(keys[vObjIx])
            else if length and ++idx < length
              nextArray(vTasks[idx])
            else
              done(null, results)
        else if aOptions.force
          logger.status 'ERROR', 'Task "' + name + '" is not exists.' if logger
          results.push undefined
          if ++vObjIx < vObjLen
            _nextObj(keys[vObjIx])
          else if length and ++idx < length
            nextArray(vTasks[idx])
          else
            done(null, results)
        else
          logger.status 'ERROR', 'Task "' + name + '" is not exists.' if logger
          return done new TypeError('Task "'+ name+ '" is not exists.')
      _nextObj(keys[vObjIx])

    nextArray = (aTask)->
      if isString aTask
        task = Task aTask
        if task
          logger.status 'DEBUG', 'INVOKE', task.inspect() if logger
          task.execute once (err, result)->
            if err
              logger.status 'ERROR', task.inspect(), err.message if logger
              return done(err) unless aOptions.force
            results.push result
            logger.status 'DEBUG', 'INVOKE', task.inspect(), 'result=', result if logger
            logger.status 'INVOKE', task.inspect(), 'ok' if logger
            if ++idx < length
              nextArray(vTasks[idx])
            else
              done(null, results)
        else if aOptions.force
          logger.status 'ERROR', 'Task "' + aTask + '" is not exists.' if logger
          results.push undefined
          if ++idx < length
            nextArray(vTasks[idx])
          else
            done(null, results)
        else
          logger.status 'ERROR', 'Task "' + aTask + '" is not exists.' if logger
          return done new TypeError('Task "' + aTask + '" is not exists.')
      else if isObject aTask
        nextObj(aTask)
      else if aOptions.force
        results.push undefined
        logger.status 'ERROR', INVALID_ARGUMENT if logger
        if ++idx < length
          nextArray(vTasks[idx])
        else
          done(null, results)
      else
        logger.status 'ERROR', INVALID_ARGUMENT if logger
        return done new TypeError(INVALID_ARGUMENT)

    if isArray vTasks
      length = vTasks.length
      nextArray(vTasks[idx])
    else
      nextObj(vTasks)
    return
  _executePipe: (aOptions, done)->
    logger = aOptions.logger
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
          logger.status 'DEBUG', 'INVOKE', task.inspect() if logger
          task.execute results, once (err, result)->
            if err
              logger.status 'ERROR', task.inspect(), err.message if logger
              unless aOptions.force
                return done(err)
            results = result
            logger.status 'DEBUG', 'INVOKE', task.inspect(), 'result=', result if logger
            logger.status 'INVOKE', task.inspect(), 'ok' if logger
            if ++vObjIx < vObjLen
              _nextObj(keys[vObjIx])
            else if length and ++idx < length
              nextArray(vTasks[idx])
            else
              done(null, results)
        else if aOptions.force
          logger.status 'ERROR', 'Task "' + name + '" is not exists.' if logger
          if ++vObjIx < vObjLen
            _nextObj(keys[vObjIx])
          else if length and ++idx < length
            nextArray(vTasks[idx])
          else
            done(null, results)
        else
          logger.status 'ERROR', 'Task "' + name + '" is not exists.' if logger
          return done new TypeError('Task "'+ name + '" is not exists.')
      _nextObj(keys[vObjIx])

    nextArray = (aTask)->
      if isString aTask
        task = Task aTask
        if task
          first = false if first
          logger.status 'DEBUG', 'INVOKE', task.inspect() if logger
          task.execute results, once (err, result)->
            if err
              logger.status 'ERROR', task.inspect(), err.message if logger
              return done(err) unless aOptions.force
            results = result
            logger.status 'DEBUG', 'INVOKE', task.inspect(), 'result=', result if logger
            logger.status 'INVOKE', task.inspect(), 'ok' if logger
            if ++idx < length
              nextArray(vTasks[idx])
            else
              done(null, results)
        else if aOptions.force
          logger.status 'ERROR', 'Task "' + aTask + '" is not exists.' if logger
          if ++idx < length
            nextArray(vTasks[idx])
          else
            done(null, results)
        else
          logger.status 'ERROR', 'Task "' + aTask + '" is not exists.' if logger
          return done new TypeError('Task "' + aTask + '" is not exists.')
      else if isObject aTask
        nextObj(aTask)
      else if aOptions.force
        first = false if first
        logger.status 'ERROR', INVALID_ARGUMENT if logger
        if ++idx < length
          nextArray(vTasks[idx])
        else
          done(null, results)
      else
        logger.status 'ERROR', INVALID_ARGUMENT if logger
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
      logger = aOptions.logger
      # TODO: the INVOKE logging should move to task-registry.
      logger.status 'DEBUG', 'INVOKE', @inspect() if logger
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

    logger = aOptions.logger
    if vTasks
      # TODO: the INVOKE logging should move to task-registry.
      logger.status 'DEBUG', 'INVOKE', @inspect() if logger
      if vPipeline
        result = @_executePipe(aOptions, done)
      else
        result = @_execute(aOptions, done)
    else
      err = new TypeError MISS_TASKS_OPTION
      logger.status 'ERROR', MISS_TASKS_OPTION if logger
      err = null if aOptions.force
      done(err)

    return @