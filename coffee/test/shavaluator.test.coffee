_ = require('underscore')
async = require('async')
should = require('should')
Shavaluator = require('../lib/shavaluator')
testHelper = require('./test_helper')

# Redis client for testing. We'll create this asglobal here because mocha's
# before() doesn't provide a this-scope that is accessible by the actual examples.
#
# You can override the default connection by filling out PROJECT/test/redis.json.
# See PROJECT/test/redis.sample.json for an example.
redisClient = null

describe 'Shavaluator', () ->

  before () ->
    redisClient = testHelper.getRedisClient()

  beforeEach (done) ->
    @shavaluator = new Shavaluator(redisClient)
    async.parallel [
      (cb) -> redisClient.flushdb cb,
      (cb) -> redisClient.send_command 'script', ['flush'], cb # Hack due bug in redis client, which doesn't implement "script *" correctly
    ], done

  it 'should pass an error if the script was never loaded', (done) ->
    @shavaluator.eval 'nonexistent', (err, result) ->
      err.message.should.match /not loaded/
      done()

  describe '_parseEvalParams()/eval() syntax', () ->

    before (done) ->
      @paramsAsObject =
        keys: [ 'key1', 'key2' ]
        args: [ 'arg1', 'arg2' ]
      @paramsAsArray = [ 2, 'key1', 'key2', 'arg1', 'arg2' ]
      @callbackParam = -> # doesn't need to do anything except exist as a value
      done()

    describe 'object syntax', () ->

      it 'should create an array from object hashes', (done) ->
        parsed = Shavaluator._parseEvalParams @paramsAsObject
        parsed.params.should.eql @paramsAsArray
        parsed.callback?.should.be.false()
        done()

      it 'should include a callback in the return value if provided', (done) ->
        parsed = Shavaluator._parseEvalParams @paramsAsObject, @callbackParam
        parsed.params.should.eql @paramsAsArray
        parsed.callback.should.eql @callbackParam
        done()

      it 'should accept non-array keys and arguments', (done) ->
        parsed = Shavaluator._parseEvalParams { keys: 'key', args: 'arg' }
        parsed.params.should.eql [ 1, 'key', 'arg' ]
        done()

    describe 'single-array syntax', () ->
      it 'should pass through single-array parameters', (done) ->
        parsed = Shavaluator._parseEvalParams @paramsAsArray
        parsed.params.should.eql @paramsAsArray
        parsed.callback?.should.be.false()
        done()

      it 'should include a callback in the return value if provided', (done) ->
        parsed = Shavaluator._parseEvalParams @paramsAsArray, @callbackParam
        parsed.params.should.eql @paramsAsArray
        parsed.callback.should.eql @callbackParam
        done()

    describe 'direct-params-style syntax', () ->
      it 'should convert direct params to an array', (done) ->
        parsed = Shavaluator._parseEvalParams @paramsAsArray...
        parsed.params.should.eql @paramsAsArray
        parsed.callback?.should.be.false()
        done()

      it 'should include a callback in the return value if provided', (done) ->
        parsed = Shavaluator._parseEvalParams (@paramsAsArray.concat(@callbackParam))...
        parsed.params.should.eql @paramsAsArray
        parsed.callback.should.eql @callbackParam
        done()

  describe 'load()', () ->

    it 'binds methods for loaded scripts', (done) ->
      @shavaluator.load foobar: "not a valid script"
      _.isFunction(@shavaluator.foobar).should.eql true
      done()

  describe 'eval()', () ->

    beforeEach (done) ->
      @shavaluator.load
        echo: 'return ARGV[1]'
        luaget: "return redis.call('GET', KEYS[1])"
        setnxget: "redis.call('SETNX', KEYS[1], ARGV[1]); return redis.call('GET', KEYS[1]);"
      done()

    it 'evaluates scripts with arguments', (done) ->
      @shavaluator.echo { args: 'testValue' }, (err, result) ->
        err?.should.be.false()
        result.should.eql 'testValue'
        done()

    it 'runs the same script multiple times', (done) ->
      samples = []
      for i in [0..10]
        do (i) =>
          samples.push (cb) =>
            @shavaluator.echo { args: "test#{i}"}, (err, result) ->
              err?.should.be.false()
              result.should.eql "test#{i}"
              cb()
      async.waterfall samples, done

    it 'evaluates scripts with keys', (done) ->
      redisClient.set 'testKey', 'testValue'
      @shavaluator.luaget { keys: 'testKey' }, (err, result) ->
        err?.should.be.false()
        result.should.eql 'testValue'
        done()

    it 'evaluates scripts with both keys and arguments', (done) ->
      t = Date.now().toString()
      @shavaluator.setnxget { keys: [ 'hey' ], args: [ t ] }, (err, result) ->
        err?.should.be.false()
        result.should.eql t
        done()
