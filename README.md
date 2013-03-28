# shavaluator-js

This library provides a convenient wrapper for sending Lua scripts to a Redis server via `EVALSHA`.

#### What is EVALSHA?

`EVALSHA` allows you to send Lua scripts to a Redis server by sending the SHA-1 hashes instead of actual script content. As long as the body of your script was previously sent to Redis via `EVAL` or `SCRIPT LOAD`, you can use `EVALSHA` to avoid the overhead of sending your entire Lua script over the network.

A shavaluator object wraps a Redis client for executing Lua scripts. When executing Lua scripts, a shavaluator will always attempt `EVALSHA` first, falling back on `EVAL` if the script has not yet been cached by the Redis server.

#### Example

```js
Shavaluator = require('shavaluator')

// 1. Initialize a shavaluator with a Redis client
var shavaluator = new Shavaluator(redis);

// 2. Load a series of named Lua scripts into the shavaluator.
shavaluator.load({
  delequal:
    " \
    if redis.call('GET', KEYS[1]) == ARGV[1] then \
      return redis.call('DEL', KEYS[i]) \
    end \
    return 0 \
    "
});

// 3. The 'delequal' script is now loaded into the shavaluator and bound
//    as a method. When you call this, the shavaluator will first attempt
//    an EVALSHA, and fall back onto EVAL.
shavaluator.delequal({ keys: 'someKey', args: 'deleteMe' });
```

### Loading scripts

Before you can run Lua scripts, you should give each one a name and load them into a shavaluator.

```js
scripts = {
  delequal:
    " \
    if redis.call('GET', KEYS[1]) == ARGV[1] then \
      return redis.call('DEL', KEYS[i]) \
    end \
    return 0 \
    "
    
  zmembers:
    " \
    local key = KEYS[1] \
    local results = {} \
    if redis.call('ZCARD', key) == 0 then \
      return {} \
    end \
    for i = 1, #ARGV, 1 do \
      local memberName = ARGV[i] \
      if redis.call('ZSCORE', key, memberName) then \
        table.insert(results, memberName) \
      end \
    end \
    return results;
    "
};

shavaluator.load(scripts);
```

Loading a script does two things by default: it generates the SHA-1 of the script body, and binds the script name as a function property on the shavaluator object. It **does not** perform any network operations, such as sending `SCRIPT LOAD` to the Redis server.

### Executing scripts

By default, loaded scripts are bound as top-level methods of the shavaluator object. These methods preserve Redis's calling convention for Lua scripts, where *key arguments* are separated from normal arguments.

Shavaluator offers three overloaded function signatures:

##### 1. keys/args hash
```js
args = { keys: ['key1', 'key2'], args: ['arg1', 'arg2'] };
shavaluator.yourScript(args, function(err, result){
  ...
});

// You can use non-array values if you have only one key and/or one argument.
args = { keys: 'soleKey', args: 'soleArg' };
shavaluator.yourScript(args, function(err, result) {
  ...
});
```

##### 2. Original calling convention: keyCount, keys..., args...

```js
shavaluator.yourScript(2, 'key1', 'key2', 'arg1', 'arg2', function(err, result) {
  ...
});
```

##### 3. Original calling convention, as array

```js
args = [ 2, 'key1', 'key2', 'arg1', 'arg2' ];
shavaluator.yourScript(args, function(err, result) {
  ...
});
```

#### eval()

If you don't like the auto-binding interface, you can use the `eval` function, which takes the name of a loaded script.

```js
args = { keys: ['key1', 'key2'], args: ['arg1', 'arg2'] }
shavaluator.eval('yourScript', args, function(err, result){
  ...
});
```

## Class reference

### constructor(redisClient, [options])

Available options:

##### autobind

Set this to `false` if yo don't want the `load` function to automatically bind script-calling functions to the shavaluator object. Defaults to `true`.

### load(scripts, [options])

Loads Lua scripts into the shavaluator. `scripts` is a key/value object, mapping script names to script bodies.

Available options:

##### autobind

Overrides the `autobind` option set in the constructor.

### eval(scriptName, params..., [callback])

Executes the script loaded with the name `scriptName`. Script parameters can be passed in three different ways. See [Executing scripts](#executing-scripts) for usage examples.

The optional `callback` parameter is standard asynchronous callback, taking two arguments:

1. an error, which is null on success
2. the script result
