{ puts, inspect } = require('util')
crypto = require('crypto')
_ = require('underscore')

sha1 = (string) ->
  crypto.createHash('sha1').update(string, 'utf8').digest('hex')

defaultConfig =
  autobind: true

module.exports = class Shavaluator

  # Class methods

  @hashifyScript: (lua) ->
    lua: lua
    sha: sha1(lua)

  @_parseEvalParams = (params...) ->
    callback = if _.isFunction(params[params.length - 1])
      params.pop()
    else
      null

    # Extract command parameters if they are given as a { keys:, args: } hash
    if params.length == 1 && _.isObject(params[0])
      if _.isArray(params[0])
        params = params[0]
      else
        keys = params[0].keys ? []
        keys = if _.isArray(keys) then keys else [ keys ]
        args = params[0].args ? []
        args = if _.isArray(args) then args else [ args ]

        if keys.length == 0 && args.length == 0
          params = []
        else
          params = [ keys.length ].concat(keys).concat(args)

    { params: params, callback: callback }

  # Instance methods

  constructor: (@redis, opts) ->
    @scripts = {}
    @config = _.extend {}, defaultConfig
    _.extend @config, opts if opts?

  add: (scripts, opts = {}) ->
    for scriptName, lua of scripts
      @scripts[scriptName] = @constructor.hashifyScript(lua)
      @_bind(scriptName) if (opts.autobind ? @config.autobind) && !@[scriptName]?

  _bind: (scriptName) ->
    @[scriptName] = (params...) =>
      @eval scriptName, params...

  # @scriptName {string} The name assigned to a Lua script when it was added.
  #   An error will be passed to the callback if the script was never added.
  #
  # The next arguments represent parameters passed intto the script.
  # These can be passed in one of three ways:
  #   1. An object with two array fields:
  #     {
  #       keys: [ key1, key2, ... ]
  #       args: [ arg1, arg2, ... ]
  #     }
  #   2. An array of parameters, matching the syntax of the Redis EVAL command
  #     [ numKeys, key1, key2, ..., arg1, arg2, ... ]
  #   3. A series of parameters passed directly, matching the syntax of the Redis EVAL command
  #     eval(scriptName, numKeys, key1, key2, ..., arg1, arg2, ..., callback)
  #
  # @callback {function, optional} A callback, triggered when the Redis command completes or raises an error.
  eval: (scriptName, params...) ->
    { params, callback } = Shavaluator._parseEvalParams(params...)
    script = @scripts[scriptName]

    unless script
      if callback
        process.nextTick () ->
          err = new Error("'#{scriptName}' script was not added")
          callback err

      # Early out
      return

    @redis.evalsha [ script.sha ].concat(params), (err, res) =>
      if err?
        if /NOSCRIPT/.test(err.message)
          evalParams = [ script.lua ].concat(params)
          evalParams.push(callback) if callback?
          @redis.eval evalParams...
        else if callback?
          callback err, res
      else if callback?
        callback err, res
