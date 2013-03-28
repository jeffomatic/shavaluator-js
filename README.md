# shavaluator-js

This library provides a convenient wrapper for sending Lua scripts to a Redis server via `EVALSHA`.

#### What is EVALSHA?

`EVALSHA` allows you to send Lua scripts to a Redis server by sending the SHA-1 hashes instead of actual script content. As long as the body of your script was previously sent to Redis via `EVAL` or `SET SCRIPT`, you can use `EVALSHA` to avoid the overhead of sending your entire Lua script over the network.

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
}

shavaluator.load(scripts);
```

### Executing scripts

Scripts loaded into a Shavaluator are bound as top-level methods of the shavaluator object.

## Class reference

### Shavaluator(redis, opts =  {})

### load(scripts)

### eval(scriptName, params...)
