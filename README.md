# shavaluator-js

This library provides a convenient wrapper for sending Lua scripts to a Redis server via `EVALSHA`.

#### What is EVALSHA?

`EVALSHA` is a Redis command that takes advantage of Redis's Lua script caching. Once a Lua script has been sent to Redis via `EVAL` or `SET SCRIPT`, the script will be cached. You can use `EVALSHA` to execute the same script by sending the *SHA-1 hash* of the script, rather than the body of the script itself.

A shavaluator object wraps a Redis client for executing Lua scripts. It will always attempt `EVALSHA` first, falling back on `EVAL` if the script has not yet been cached by the Redis server.

#### Example

```js
Shavaluator = require('shavaluator')

// 1. Initialize a shavaluator with a Redis client
var shavaluator = new Shavaluator(redis);

// 2. Load a series of named Lua scripts into the shavaluator.
shavaluator.load({
  delequal: " \
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

### Executing scripts

## Class reference

### Shavaluator(redis, opts =  {})

### load(scripts)

### eval(scriptName, params...)
