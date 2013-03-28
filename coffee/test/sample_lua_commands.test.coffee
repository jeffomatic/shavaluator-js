_ = require('underscore')
should = require('should')
Shavaluator = require('../lib/shavaluator')
testHelper = require('./test_helper')

# Redis client for testing. We'll create this asglobal here because mocha's
# before() doesn't provide a this-scope that is accessible by the actual examples.
#
# You can override the default connection by filling out PROJECT/test/redis.json.
# See PROJECT/test/redis.sample.json for an example.
redisClient = null
shavaluator = new Shavaluator
shavaluator.add require('./sample_lua_commands')

prepopulateExampleSet = (callback) ->
  redisClient.zadd 'testSet', 1, 'one', 2, 'two', 3, 'three', 4, 'four', (err, result) ->
    callback()

testKeys =
  a: 1
  b: 2
  c: 3
  d: 4

describe 'Redis Lua commands', () ->

  before () ->
    redisClient = testHelper.getRedisClient()
    shavaluator.redis = redisClient

  beforeEach (done) ->
    redisClient.flushdb () ->
      done()

  describe 'setnx_pexpire', () ->

    ttl = 50

    describe "with key that hasn't been set yet", ->

      it 'returns 1 for keys the do not yet exist', (done) ->
        shavaluator.setnx_pexpire { keys: 'testKey', args: ['testValue', ttl] },
          (err, result) ->
            result.should.eql 1
            done()

      it 'sets the expiration correctly', (done) ->
        shavaluator.setnx_pexpire { keys: 'testKey', args: ['testValue', ttl] },
          (err, result) ->
            redisClient.pttl 'testKey', (err, result) ->
              result.should.not.be.below 0
              result.should.not.be.above @ttl
              done()

    describe "with key that already exists", (done) ->

      beforeEach (done) ->
        redisClient.set 'testKey', 'testValue', (err, result) ->
          done()

      it 'does not set the key', (done) ->
        shavaluator.setnx_pexpire { keys: 'testKey', args: ['newValue', ttl] },
          (err, result) ->
            result.should.eql 0
            done()

      it 'does not set an expiration time', (done) ->
        redisClient.pttl 'testKey', (err, result) ->
          result.should.eql -1
          done()

  describe 'zmembers', () ->

    describe 'with nonexisting key', () ->

      it 'returns an empty array', (done) ->
        shavaluator.zmembers { keys: 'nonexistingKey' }, (err, result) ->
          err?.should.be.false()
          result.length.should.eql 0
          done()

    describe 'with prepopulated set', () ->

      beforeEach (done) ->
        prepopulateExampleSet done

      it 'returns arguments that are members of the sorted set', (done) ->
        shavaluator.zmembers { keys: 'testSet', args: [ 'one', 'three', 'five' ] }, (err, result) ->
          err?.should.be.false()
          result.should.eql [ 'one', 'three' ]
          done()

  describe 'znotmembers', () ->

    describe 'with nonexisting key', () ->

      it 'returns complete array', (done) ->
        args = [ 'one', 'two', 'three' ]
        shavaluator.znotmembers { keys: 'nonexistingKey', args: args }, (err, result) ->
          err?.should.be.false()
          result.should.eql args
          done()

    describe 'with prepopulated set', () ->

      beforeEach (done) ->
        prepopulateExampleSet done

      it 'returns arguments that are members of the sorted set', (done) ->
        shavaluator.znotmembers { keys: 'testSet', args: [ 'zero', 'one', 'three', 'five' ] }, (err, result) ->
          err?.should.be.false()
          result.should.eql [ 'zero', 'five' ]
          done()

  describe 'delequal', () ->

    beforeEach (done) ->
      args = []
      for k, v of testKeys
        args.push k
        args.push v

      args.push (err, result) ->
        done()

      redisClient.mset args...

    it 'returns zero if the key does not exist', (done) ->
      shavaluator.delequal { keys: 'nonexistent', args: '1' }, (err, result) ->
        err?.should.be.false()
        result.should.eql 0
        done()

    it 'deletes single keys when the matching value is sent', (done) ->
      shavaluator.delequal { keys: 'a', args: testKeys.a }, (err, result) ->
        err?.should.be.false()
        result.should.eql 1
        redisClient.get 'a', (err, result) ->
          err?.should.be.false()
          (result == null).should.eql true
          done()

    it 'does not delete a single key when an unmatching value is sent', (done) ->
      shavaluator.delequal { keys: 'a', args: 'x' }, (err, result) ->
        err?.should.be.false()
        result.should.eql 0
        redisClient.get 'a', (err, result) ->
          err?.should.be.false()
          result.should.eql '1'
          done()

    it 'only deletes keys that match', (done) ->
      deleteParams =
        keys: [ 'a', 'b', 'c', 'd' ]
        args: [ 1, 'x', 3, 'x' ]
      shavaluator.delequal deleteParams, (err, result) ->
        err?.should.be.false()
        result.should.eql 2
        redisClient.mget 'a', 'b', 'c', 'd', (err, result) ->
          err?.should.be.false()
          result.should.eql [ null, '2', null, '4' ]
          done()
