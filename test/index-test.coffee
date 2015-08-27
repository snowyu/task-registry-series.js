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

describe 'Tasks', ->
  beforeEach ->
    Add1Task::_executeSync.reset()
    Add2Task::_executeSync.reset()
  it 'should get series via aliases', ->
    tasks = Task 'tasks'
    expect(tasks).be.instanceOf Tasks
    tasks = Task 'Tasks'
    expect(tasks).be.instanceOf Tasks
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
      tasks.execute tasks:['Add1', 'Add2': 2], (err, result)->
        unless err
          expect(result).deep.equal [2, 4]
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



