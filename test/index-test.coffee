chai            = require 'chai'
sinon           = require 'sinon'
sinonChai       = require 'sinon-chai'
should          = chai.should()
expect          = chai.expect
assert          = chai.assert
chai.use(sinonChai)

setImmediate    = setImmediate || process.nextTick


isNumber        = require 'util-ex/lib/is/type/number'
Task            = require 'task-registry'
Tasks           = require '../src'
register        = Task.register
aliases         = Task.aliases


class ErrorTask
  register ErrorTask

  constructor: -> return super

  _executeSync: sinon.spy (aOptions)->throw new Error 'MyError'

class Add1Task
  register Add1Task

  constructor: -> return super

  _executeSync: sinon.spy (aOptions)->
    aOptions = 1 unless isNumber aOptions
    aOptions+1

class Add2Task
  register Add2Task

  constructor: -> return super

  _executeSync: sinon.spy (aOptions)->
    aOptions = 1 unless isNumber aOptions
    aOptions+2

fakeLogger =
  logs: []
  statuses: []
  errors: []
  log: sinon.spy (msg)-> @logs.push msg
  status: sinon.spy (aStatus, args...)->
    @errors.push args if aStatus.toUpperCase() is 'ERROR'
    @statuses.push {status:aStatus, args:args}
  write: sinon.spy()
  reset: ->
    @errors = []
    @logs = []
    @errors = []
    @statuses = []
    @log.reset()
    @status.reset()
    @write.reset()

describe 'Tasks', ->
  beforeEach ->
    Add1Task::_executeSync.reset()
    Add2Task::_executeSync.reset()
    fakeLogger.reset()
  it 'should get series via aliases', ->
    tasks = Task 'series'
    expect(tasks).be.instanceOf Tasks
    tasks = Task 'Series'
    expect(tasks).be.instanceOf Tasks

  describe '.executeSync', ->
    tasks = Task 'Series'
    it 'should run a single task as string', ->
      result = tasks.executeSync 'Add1'
      expect(result).deep.equal [2]
      expect(Add1Task::_executeSync).be.callOnce

    it 'should run a single task as object', ->
      result = tasks.executeSync tasks: 'Add1': 2
      expect(result).deep.equal [3]
      expect(Add1Task::_executeSync).be.callOnce

    it 'should run a multi tasks', ->
      result = tasks.executeSync tasks:['Add1', 'Add2': 2]
      expect(result).deep.equal [2, 4]
      expect(Add1Task::_executeSync).be.callOnce
      expect(Add2Task::_executeSync).be.callOnce

    it 'should run a multi tasks via array', ->
      result = tasks.executeSync ['Add1':5, 'Add2': 2]
      expect(result).deep.equal [6, 4]
      expect(Add1Task::_executeSync).be.callOnce
      expect(Add2Task::_executeSync).be.callOnce

    it 'should run a multi tasks as pipeline', ->
      result = tasks.executeSync pipeline:true, tasks:['Add1':3, 'Add2']
      expect(result).deep.equal 6
      expect(Add1Task::_executeSync).be.callOnce
      expect(Add2Task::_executeSync).be.callOnce

    it 'should run a multi tasks as pipeline 2', ->
      result = tasks.executeSync pipeline:true, tasks:['Add1', 'Add2':45]
      expect(result).deep.equal 4
      expect(Add1Task::_executeSync).be.callOnce
      expect(Add2Task::_executeSync).be.callOnce

    it 'should run a multi tasks as pipeline 3', ->
      result = tasks.executeSync pipeline:true, tasks:'Add1':3, 'Add2':45
      expect(result).deep.equal 6
      expect(Add1Task::_executeSync).be.callOnce
      expect(Add2Task::_executeSync).be.callOnce

    it 'should throw error when an invalid arguments', ->
      should.throw tasks.executeSync.bind(tasks, tasks:[true, 'None']), 'Task argument should be a task name or object'
      should.throw tasks.executeSync.bind(tasks), 'missing tasks'
    it 'should throw error when a task throw error', ->
      should.throw tasks.executeSync.bind(tasks, 'Error'), 'MyError'
      should.throw tasks.executeSync.bind(tasks, tasks:{'Error':123}), 'MyError'
    it 'should throw error when a task not exists', ->
      should.throw tasks.executeSync.bind(tasks, tasks:['Add1', 'None']), 'Task "None" is not exists'
    it 'should throw error when a task not exists via array', ->
      should.throw tasks.executeSync.bind(tasks, ['Add1', 'None']), 'Task "None" is not exists'
    it 'should throw error when a task not exists with argument', ->
      should.throw tasks.executeSync.bind(tasks, ['Add1', 'None':12]), 'Task "None" is not exists'
    it 'should throw error when a task not exists via object', ->
      should.throw tasks.executeSync.bind(tasks, tasks:'Add1':1, 'None':23), 'Task "None" is not exists'
    it 'should throw error when a task not exists as pipeline via object', ->
      should.throw tasks.executeSync.bind(tasks, pipeline:true, tasks:'Add1':1, 'None':23),
        'Task "None" is not exists'
    it 'should throw error when a task not exists as pipeline', ->
      should.throw tasks.executeSync.bind(tasks, pipeline:true, tasks:['Add1':1, 'None':23]),
        'Task "None" is not exists'
    it 'should throw error when a task not exists as pipeline with string', ->
      should.throw tasks.executeSync.bind(tasks, pipeline:true, tasks:['Add1':1, 'None']),
        'Task "None" is not exists'

    it 'should force invalid tasks to continue', ->
      errs = fakeLogger.errors
      result = tasks.executeSync logger:fakeLogger, force:true
      expect(result).be.not.exist
      expect(errs).have.length 1
      expect(errs[0][0]).be.equal 'missing tasks option'
    it 'should force tasks to continue', ->
      errs = fakeLogger.errors
      result = tasks.executeSync logger:fakeLogger, force:true, tasks:['Error', true, 'Add1', 'None', {Add2:12, None:11, Add1:2}]
      expect(result).deep.equal [undefined, undefined, 2, undefined, 14, undefined, 3]
      expect(Add1Task::_executeSync).be.callOnce
      expect(Add2Task::_executeSync).be.callOnce
      expect(errs).have.length 4
      expect(errs[3][0]).be.equal 'Task "None" is not exists.'
      expect(errs[0][1]).be.equal 'MyError'
      expect(errs[1][0]).be.equal 'Task argument should be a task name or object'

    it 'should force pipeline tasks to continue', ->
      errs = fakeLogger.errors
      result = tasks.executeSync logger:fakeLogger, pipeline:true, force:true, tasks:['Error', true, 'Add1':2, 'None', {Add2:12, None:11, Add1:2}]
      expect(result).deep.equal 5
      expect(Add1Task::_executeSync).be.callOnce
      expect(Add2Task::_executeSync).be.callOnce
      expect(errs).have.length 4
      expect(errs[3][0]).be.equal 'Task "None" is not exists.'

  describe '.execute', ->
    tasks = Task 'Series'
    it 'should run a single task as string', (done)->
      tasks.execute 'Add1', (err, result)->
        unless err
          expect(result).deep.equal [2]
          expect(Add1Task::_executeSync).be.callOnce
        done(err)
    it 'should run a single task as object', (done)->
      tasks.execute tasks: 'Add1': 2, (err, result)->
        unless err
          expect(result).deep.equal [3]
          expect(Add1Task::_executeSync).be.callOnce
        done(err)
    it 'should run a multi tasks', (done)->
      tasks.execute tasks:['Add1', 'Add2': 2, 'Add1'], (err, result)->
        unless err
          expect(result).deep.equal [2, 4, 2]
          expect(Add1Task::_executeSync).be.callOnce
          expect(Add2Task::_executeSync).be.callOnce
        done(err)
    it 'should run a multi tasks via array', (done)->
      tasks.execute ['Add1':5, 'Add2': 2], (err, result)->
        unless err
          expect(result).deep.equal [6, 4]
          expect(Add1Task::_executeSync).be.callOnce
          expect(Add2Task::_executeSync).be.callOnce
        done(err)
    it 'should run a multi tasks as pipeline', (done)->
      tasks.execute pipeline:true, tasks:['Add1':3, 'Add2'], (err, result)->
        unless err
          expect(result).deep.equal 6
          expect(Add1Task::_executeSync).be.callOnce
          expect(Add2Task::_executeSync).be.callOnce
        done(err)
    it 'should run a multi tasks as pipeline 2', (done)->
      tasks.execute pipeline:true, tasks:['Add1', 'Add2':45], (err, result)->
        unless err
          expect(result).deep.equal 4
          expect(Add1Task::_executeSync).be.callOnce
          expect(Add2Task::_executeSync).be.callOnce
        done(err)
    it 'should run a multi tasks as pipeline 2', (done)->
      tasks.execute pipeline:true, tasks:'Add1':3, 'Add2':45, (err, result)->
        unless err
          expect(result).deep.equal 6
          expect(Add1Task::_executeSync).be.callOnce
          expect(Add2Task::_executeSync).be.callOnce
        done(err)

    it 'should throw error when an invalid arguments', (done)->
      tasks.execute tasks:[true, 'None'], (err, result)->
        expect(err).have.property 'message', 'Task argument should be a task name or object'
        expect(result).have.not.exist
        done()
    it 'should throw error when an invalid arguments 2', (done)->
      tasks.execute {}, (err, result)->
        expect(err).have.property 'message', 'missing tasks option'
        expect(result).have.not.exist
        done()
    it 'should throw error when a task not exists', (done)->
      tasks.execute tasks:['Add1', 'None'], (err, result)->
        expect(err).have.property 'message', 'Task "None" is not exists.'
        expect(result).have.not.exist
        done()
    it 'should throw error when a task not exists via array', (done)->
      tasks.execute ['Add1', 'None'], (err, result)->
        expect(err).have.property 'message', 'Task "None" is not exists.'
        expect(result).have.not.exist
        done()
    it 'should throw error when a task not exists with argument', (done)->
      tasks.execute tasks:['Add1', 'None':123], (err, result)->
        expect(err).have.property 'message', 'Task "None" is not exists.'
        expect(result).have.not.exist
        done()
    it 'should throw error when a task not exists via object', (done)->
      tasks.execute tasks:'Add1':12, 'None':123, (err, result)->
        expect(err).have.property 'message', 'Task "None" is not exists.'
        expect(result).have.not.exist
        done()
    it 'should throw error when a task not exists as pipeline via object', (done)->
      tasks.execute pipeline:true, tasks:'Add1':12, 'None':123, (err, result)->
        expect(err).have.property 'message', 'Task "None" is not exists.'
        expect(result).have.not.exist
        done()
    it 'should throw error when a task not exists as pipeline', (done)->
      tasks.execute pipeline:true, tasks:['Add1':12, 'None':123], (err, result)->
        expect(err).have.property 'message', 'Task "None" is not exists.'
        expect(result).have.not.exist
        done()
    it 'should throw error when a task not exists as pipeline via string', (done)->
      tasks.execute pipeline:true, tasks:['Add1':12, 'None'], (err, result)->
        expect(err).have.property 'message', 'Task "None" is not exists.'
        expect(result).have.not.exist
        done()

    it 'should force invalid tasks to continue', (done)->
      errs = fakeLogger.errors
      tasks.execute logger:fakeLogger, force:true, (err, result)->
        unless err
          expect(result).be.not.exist
          expect(errs).have.length 1
          expect(errs[0][0]).be.equal 'missing tasks option'
        done(err)

    it 'should force tasks to continue', (done)->
      errs = fakeLogger.errors
      tasks.execute logger:fakeLogger, force:true, tasks:['Add1', 'None', {Add2:12, None:11}], (err, result)->
        unless err
          expect(result).deep.equal [2, undefined, 14, undefined]
          expect(Add1Task::_executeSync).be.callOnce
          expect(Add2Task::_executeSync).be.callOnce
          expect(errs).have.length 2
          expect(errs[0][0]).be.equal 'Task "None" is not exists.'
        done(err)
    it 'should force tasks to continue 1', (done)->
      errs = fakeLogger.errors
      tasks.execute logger:fakeLogger, force:true, tasks:['Add1', 'None', {Add2:12, None:11, Add1:2}], (err, result)->
        unless err
          expect(result).deep.equal [2, undefined, 14, undefined, 3]
          expect(Add1Task::_executeSync).be.callOnce
          expect(Add2Task::_executeSync).be.callOnce
          expect(errs).have.length 2
          expect(errs[0][0]).be.equal 'Task "None" is not exists.'
        done(err)
    it 'should force tasks to continue 2', (done)->
      errs = fakeLogger.errors
      tasks.execute logger:fakeLogger, force:true, tasks:[Error:1,'Add1', true, 'None', {Add2:12, None:11}, 'Add1'], (err, result)->
        unless err
          expect(result).deep.equal [undefined, 2, undefined, undefined, 14, undefined, 2]
          expect(Add1Task::_executeSync).be.callOnce
          expect(Add2Task::_executeSync).be.callOnce
          expect(errs).have.length 4
          expect(errs[3][0]).be.equal 'Task "None" is not exists.'
          expect(errs[0][1]).be.equal 'MyError'
          expect(errs[1][0]).be.equal 'Task argument should be a task name or object'
        done(err)

    it 'should force pipeline tasks to continue', (done)->
      errs = fakeLogger.errors
      tasks.execute logger:fakeLogger, pipeline:true, force:true, tasks:['Error', 'Add1', 'None', {Add2:12, None:11}], (err, result)->
        unless err
          expect(result).deep.equal 4
          expect(Add1Task::_executeSync).be.callOnce
          expect(Add2Task::_executeSync).be.callOnce
          expect(errs).have.length 3
          expect(errs[2][0]).be.equal 'Task "None" is not exists.'
        done(err)
    it 'should force pipeline tasks to continue 1', (done)->
      errs = fakeLogger.errors
      tasks.execute logger:fakeLogger, pipeline:true, force:true, tasks:['Add1':2, 'None', {Add2:12, None:11, Add1:2}], (err, result)->
        unless err
          expect(result).deep.equal 6
          expect(Add1Task::_executeSync).be.callOnce
          expect(Add2Task::_executeSync).be.callOnce
          expect(errs).have.length 2
          expect(errs[0][0]).be.equal 'Task "None" is not exists.'
          expect(errs[1][0]).be.equal 'Task "None" is not exists.'
        done(err)
    it 'should force pipeline tasks to continue 2', (done)->
      errs = fakeLogger.errors
      tasks.execute logger:fakeLogger, pipeline:true, force:true, tasks:[Error:1, true, 'Add1':2, 'None', {Add2:12, None:11}, 'Add1'], (err, result)->
        unless err
          expect(result).deep.equal 5
          expect(Add1Task::_executeSync).be.callOnce
          expect(Add2Task::_executeSync).be.callOnce
          expect(errs).have.length 4
          expect(errs[3][0]).be.equal 'Task "None" is not exists.'
          expect(errs[0][1]).be.equal 'MyError'
          expect(errs[1][0]).be.equal 'Task argument should be a task name or object'
        done(err)



