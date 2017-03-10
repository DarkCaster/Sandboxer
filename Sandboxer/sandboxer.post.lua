assert(config.profile~="dbus" and
  config.profile~="profile" and
  config.profile~="loader" and
  config.profile~="config" and
  config.profile~="defaults" and
  config.profile~="x11util" and
  config.profile~="tunables" and
  config.profile~="control",
  "cannot use service table name as profile: "..config.profile)

assert(type(tunables.basedir)=="string" and tunables.basedir~="", "tunables.basedir param incorrect")

-- load profile
if loader.lua_version.num>=5002000 then
  profile=load("return " .. config.profile)()
else
  profile=loadstring("return " .. config.profile)()
end

-- sandbox table verification
assert(type(sandbox)=="table", "sandbox param incorrect")

-- features table
assert(type(sandbox.features)=="nil" or type(sandbox.features)=="table", "sandbox.features param incorrect")
if type(sandbox.features)=="nil" then sandbox.features={} end

if type(sandbox.features)=="table" then
  for index,field in ipairs(sandbox.features) do
    assert(type(field)=="string", "sandbox.features[".. index .."] value is incorrect (must be a string)")
    assert(string.match(field,'^[0-9a-z_]*$')==field, "sandbox.features[".. index .."] value contain invalid characters")
  end
end

-- setup table
assert(type(sandbox.setup)=="table", "sandbox.setup param incorrect")

assert(type(sandbox.setup.executor_build)=="nil" or type(sandbox.setup.executor_build)=="string", "sandbox.setup.executor_build param incorrect")
if type(sandbox.setup.executor_build)=="nil" then sandbox.setup.executor_build="default" end
assert(string.match(sandbox.setup.executor_build,'^[0-9a-z_.-]*$')==sandbox.setup.executor_build, 'sandbox.setup.executor_build value contain invalid characters: only numbers, letters (lowercase) and "_", ".", "-" characters allowed')

assert(type(sandbox.setup.cleanup_on_exit)=="nil" or type(sandbox.setup.cleanup_on_exit)=="boolean", "sandbox.setup.cleanup_on_exit param incorrect")
if type(sandbox.setup.cleanup_on_exit)=="nil" then sandbox.setup.cleanup_on_exit=true end

assert(type(sandbox.setup.security_key)=="nil" or type(sandbox.setup.security_key)=="number", "sandbox.setup.security_key param incorrect")
if type(sandbox.setup.security_key)=="nil" then sandbox.setup.security_key=42 end

assert(type(sandbox.setup.chroot)=="nil" or type(sandbox.setup.chroot)=="table", "sandbox.setup.chroot param incorrect")

function loader.check_one_level_string_list(target, name)
  assert(type(target)=="nil" or type(target)=="table", name.." table is incorrect")
  if type(target)=="table" then
    for index,field in ipairs(target) do
      assert(type(field)=="string", name.."[".. index .."] value is incorrect")
    end
  end
end

function loader.check_two_level_string_list(target, name)
  assert(type(target)=="nil" or type(target)=="table", name.." table is incorrect")
  if type(target)=="table" then
    for i1,f1 in ipairs(target) do
      assert(type(f1)=="table", name.."[" .. i1 .. "] subtable is incorrect")
      for i2,f2 in ipairs(f1) do
        assert(type(f2)=="string", name.."["..i1.."]["..i2.."] value is incorrect")
      end
    end
  end
end

function loader.transform_env_unset_list(target, name)
  assert(type(target)=="nil" or type(target)=="table", name.." table is incorrect")
  local result={}
  if type(target)=="table" then
    if target.enabled==false then return nil end
    for i1,f1 in pairs(target) do
      if(type(i1)=="number") then
        assert(type(f1)=="table" or type(f1)=="string", name.."[" .. i1 .. "] subtable is incorrect")
        if type(f1)=="table" then
          for i2,f2 in ipairs(f1) do
            assert(type(f2)=="string", name.."["..i1.."]["..i2.."] value is incorrect")
            table.insert(result,f2)
          end
        else
          table.insert(result,f1)
        end
      else
        if(tostring(i1)~="enabled") then print("config: skipping value of "..name.."["..tostring(i1).."]") end
      end
    end
    return result
  else
    return nil
  end
end

function loader.transform_env_set_list(target, name)
  assert(type(target)=="nil" or type(target)=="table", name.." table is incorrect")
  local result={}
  if type(target)=="table" then -- main container
    if target.enabled==false then return nil end
    for i1,f1 in pairs(target) do  -- f1 is a container top-level element
      if(type(i1)=="number") then
        assert(type(f1)=="table", name.."["..i1.."] subtable is incorrect")
        local top_level_is_target=false
        for i2,f2 in ipairs(f1) do -- f2 is a container 2nd-level element
          assert(type(f2)=="table" or type(f2)=="string" , name.."["..i1.."]["..i2.."] value is incorrect (it should be a table or string)")
          if type(f2)=="table" and top_level_is_target==false then
            assert(#f2==2 or #f2==0, name.."["..i1.."]["..i2.."] has incorrect strings count")
            for i3,f3 in ipairs(f2) do -- f3 is a 3rd level container, may contain only strings
              assert(type(f3)=="string", name.."["..i1.."]["..i2.."]["..i3.."] value is incorrect")
            end
            if #f2==2 then table.insert(result,f2) end
          else
            top_level_is_target=true
            assert(type(f2)=="string", name.."["..i1.."]["..i2.."] value is incorrect")
          end
        end -- for 2nd-level
        if top_level_is_target==true then
          assert(#f1==2 or #f1==0, name.."["..i1.."] has incorrect strings count, expected count==2, actual count=="..#f1)
          if #f1==2 then table.insert(result,f1) end
        end
      else
        if(tostring(i1)~="enabled") then print("config: skipping value of "..name.."["..tostring(i1).."]") end
      end
    end
    return result
  else
    return nil
  end
end

-- custom command table
loader.check_two_level_string_list(sandbox.setup.commands,"sandbox.setup.commands")

-- env tables
sandbox.setup.env_blacklist=loader.transform_env_unset_list(sandbox.setup.env_blacklist,"sandbox.setup.env_blacklist")
sandbox.setup.env_whitelist=loader.transform_env_unset_list(sandbox.setup.env_whitelist,"sandbox.setup.env_whitelist")
sandbox.setup.env_set=loader.transform_env_set_list(sandbox.setup.env_set,"sandbox.setup.env_set")

-- bwrap table
sandbox.tags={}

function loader.check_bwrap_entry(entry,name)
  assert(type(entry.tag)=="nil" or type(entry.tag)=="string", name..".tag value is incorrect")
  if type(entry.tag)~="nil" then
    assert(type(sandbox.tags[entry.tag])=="nil", name.." entry with tag '"..entry.tag.."' already defined!")
    sandbox.tags[entry.tag]=true
  end
  assert(type(entry.prio)=="number" or type(entry.prio)=="nil", name..".prio value is incorrect")
  if type(entry.prio)=="number" then
    assert(entry.prio>=0 and entry.prio<=100, name.."].prio value is out of range (should be 0 <= prio <= 100)")
  else
    entry.prio=100
  end
  for mi,mf in ipairs(entry) do
    if mi==1 then
      assert(type(mf)=="string", name.."["..mi.."] value is incorrect")
    else
      assert(type(mf)~="table" and type(mf)~="function" and type(mf)~="nil", name.."["..mi.."] value is incorrect")
    end
  end
end

function loader.transform_bwrap_list(target, name, result)
  assert(type(target)=="table", name.." table is incorrect or missing")
  for i1,f1 in pairs(target) do  -- f1 is a container top-level element
    if(type(i1)=="number") then
      assert(type(f1)=="table", name.."["..i1.."] subtable is incorrect")
      for i2,f2 in ipairs(f1) do -- f2 is a container 2nd-level element
        assert(type(f2)=="table" or type(f2)=="string" , name.."["..i1.."]["..i2.."] value is incorrect (it should be a table or string)")
        if type(f2)=="table" then
          loader.check_bwrap_entry(f2,name.."["..i1.."]["..i2.."]")
          if #f2>0 then table.insert(result,f2) end
        else
          assert(i2==1,name.."["..i1.."]["..i2.."] value cannot be string, because previous value in this container is also a table!")
          loader.check_bwrap_entry(f1,name.."["..i1.."]")
          table.insert(result,f1)
          break
        end
      end -- for 2nd-level
    else
      print("config: skipping value of "..name.."["..tostring(i1).."]")
    end -- type(i1)=="number"
  end -- for 1nd-level
end

-- produce result sandbox.bwrap tables with all definitions needed for bwrap to perform mounts and it's setup tasks.
-- if there will be added another sandboxing tool support, this part will be different.
-- for now just transform, simplify and concatenate sandbox.setup.mounts and sandbox.bwrap tables.
loader.bwrap_table_result={}
loader.transform_bwrap_list(sandbox.bwrap,"sandbox.bwrap",loader.bwrap_table_result)
loader.transform_bwrap_list(sandbox.setup.mounts,"sandbox.setup.mounts",loader.bwrap_table_result)
sandbox.bwrap=loader.bwrap_table_result

-- sort bwrap table, according to prio parameters
function loader.bwrap_compare(first,second)
  if first.prio<second.prio then return true end
  return false
end

table.sort(sandbox.bwrap,loader.bwrap_compare)

-- check profile
function loader.check_profile(profile, name)
  assert(type(profile)=="table", name.." profile is incorrect")
  assert(type(profile.exec)=="string", name..".exec value is incorrect or missing")
  assert(type(profile.path)=="string" or type(profile.path)=="nil", name..".path value is incorrect or missing")
  loader.check_one_level_string_list(profile.args, name..".args")
  profile.env_unset=loader.transform_env_unset_list(profile.env_unset, name..".env_unset")
  profile.env_set=loader.transform_env_set_list(profile.env_set, name..".env_set")
  assert(type(profile.term_signal)=="number" or type(profile.term_signal)=="nil", name..".term_signal value is incorrect or missing")
  assert(type(profile.term_child_only)=="boolean" or type(profile.term_child_only)=="nil", name..".term_child_only value is incorrect or missing")
  assert(type(profile.attach)=="boolean" or type(profile.attach)=="nil", name..".attach value is incorrect or missing")
  if type(profile.attach)=="nil" then profile.attach=false end
  assert(type(profile.pty)=="boolean" or type(profile.pty)=="nil", name..".pty value is incorrect or missing")
  if type(profile.pty)=="nil" then profile.pty=false end
  assert(type(profile.exclusive)=="boolean" or type(profile.exclusive)=="nil", name..".exclusive value is incorrect or missing")
  if type(profile.exclusive)=="nil" then profile.exclusive=false end
  -- start command opcode
  if profile.attach==true and profile.pty==false then
    profile.start_opcode=100
  elseif profile.attach==false and profile.pty==false then
    profile.start_opcode=101
  elseif profile.attach==true and profile.pty==true then
    profile.start_opcode=200
  elseif profile.attach==false and profile.pty==true then
    profile.start_opcode=201
  end
end

loader.check_profile(profile,config.profile)
loader.check_profile(dbus,"dbus")
loader.check_profile(x11util,"x11util")
