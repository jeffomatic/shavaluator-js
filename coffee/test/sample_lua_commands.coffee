module.exports =
  # Like SETNX, but also issues an expire if the value is set. Returns the
  # result of SETNX.
  setnx_pexpire:
    """
    local result = redis.call('SETNX', KEYS[1], ARGV[1])
    if result == 1 then
      redis.call('PEXPIRE', KEYS[1], ARGV[2])
    end
    return result
    """

  # Deletes keys if they equal the given values
  delequal:
    """
    local deleted = 0
    for i = 1, #KEYS, 1 do
      if redis.call('GET', KEYS[i]) == ARGV[i] then
        redis.call('DEL', KEYS[i])
        deleted = deleted + 1
      end
    end
    return deleted
    """

  # Given the name of a sorted set key and multiple arguments,
  # returns the given arguments that actually exist in the sorted set.
  zmembers:
    """
    local key = KEYS[1]
    local results = {}

    if redis.call('ZCARD', key) == 0 then
      return {}
    end

    for i = 1, #ARGV, 1 do
      local memberName = ARGV[i]
      if redis.call('ZSCORE', key, memberName) then
        table.insert(results, memberName)
      end
    end

    return results;
    """

  znotmembers:
    """
    local key = KEYS[1]
    local results = {}

    if redis.call('ZCARD', key) == 0 then
      return ARGV
    end

    for i = 1, #ARGV, 1 do
      local memberName = ARGV[i]
      if not redis.call('ZSCORE', key, memberName) then
        table.insert(results, memberName)
      end
    end

    return results;
    """