assert(config.profile~="dbus" and
 config.profile~="pulse" and
 config.profile~="profile" and
 config.profile~="loader" and
 config.profile~="config" and
 config.profile~="defaults" and
 config.profile~="tunables" and
 config.profile~="control",
 "cannot use service table name as profile: "..config.profile)

assert(type(defaults.basedir)=="string" and defaults.basedir~="", "defaults.basedir param incorrect")

-- load profile
profile=loadstring("return " .. config.profile)()

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

assert(type(sandbox.setup.static_executor)=="nil" or type(sandbox.setup.static_executor)=="boolean", "sandbox.setup.static_executor param incorrect")
if type(sandbox.setup.static_executor)=="nil" then sandbox.setup.static_executor=false end

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
  for index,field in ipairs(target) do
   assert(type(field)=="table", name.."[" .. index .. "] subtable is incorrect")
   for mi,mf in ipairs(field) do
    assert(type(mf)=="string", name.."["..index.."]["..mi.."] value is incorrect")
   end
  end
 end
end

function loader.check_two_level_env_set_list(target, name)
 assert(type(target)=="nil" or type(target)=="table", name.." table is incorrect")
 if type(target)=="table" then
  for index,field in ipairs(target) do
   assert(type(field)=="table", name.."["..index.."] subtable is incorrect")
   for mi,mf in ipairs(field) do
    assert(type(mf)=="table", name.."["..index.."]["..mi.."] value is incorrect (it should be a table)")
    local env_idx=0
    for vi,vf in ipairs(mf) do
     assert(vi<3, name.."["..index.."]["..mi.."] has incorrect strings count")
     assert(type(vf)=="string", name.."["..index.."]["..mi.."]["..vi.."] value is incorrect")
     env_idx=env_idx+1
    end
    assert(env_idx==2 or env_idx==0, name.."["..index.."]["..mi.."] has incorrect strings count")
   end
  end
 end
end

function loader.check_one_level_env_set_list(target, name)
 assert(type(target)=="nil" or type(target)=="table", name.." table is incorrect")
 if type(target)=="table" then
  for index,field in ipairs(target) do
   assert(type(field)=="table", name.."["..index.."] subtable is incorrect")
   local env_idx=0
   for mi,mf in ipairs(field) do
    assert(mi<3, name.."["..index.."] has incorrect strings count")
    assert(type(mf)=="string", name.."["..index.."]["..mi.."] value is incorrect")
    env_idx=env_idx+1
   end
   assert(env_idx==2 or env_idx==0, name.."["..index.."] has incorrect strings count")
  end
 end
end

-- custom command table
loader.check_two_level_string_list(sandbox.setup.commands,"sandbox.setup.commands")

-- env tables
loader.check_two_level_string_list(sandbox.setup.env_blacklist,"sandbox.setup.env_blacklist")
loader.check_two_level_string_list(sandbox.setup.env_whitelist,"sandbox.setup.env_whitelist")
loader.check_two_level_env_set_list(sandbox.setup.env_set,"sandbox.setup.env_set")

-- bwrap table
assert(type(sandbox.bwrap)=="table", "sandbox.bwrap param incorrect")
for index,field in ipairs(sandbox.bwrap) do
 assert(type(field)=="table", "sandbox.bwrap[" .. index .. "] value is incorrect")
 for mi,mf in ipairs(field) do
  if mi==1 then
   assert(type(mf)=="string", "sandbox.bwrap["..index.."]["..mi.."] value is incorrect")
  else
   assert(type(mf)~="table" and type(mf)~="function" and type(mf)~="nil", "sandbox.bwrap["..index.."]["..mi.."] value is incorrect")
  end
 end
end

-- check profile
function loader.check_profile(profile, name)
 assert(type(profile)=="table", name.." profile is incorrect")
 assert(type(profile.exec)=="string", name..".exec value is incorrect or missing")
 assert(type(profile.path)=="string" or type(profile.path)=="nil", name..".path value is incorrect or missing")
 loader.check_one_level_string_list(profile.args, name..".args")
 loader.check_one_level_string_list(profile.env_unset, name..".env_unset")
 loader.check_one_level_env_set_list(profile.env_set, name..".env_set")
 assert(type(profile.term_signal)=="number" or type(profile.term_signal)=="nil", name..".term_signal value is incorrect or missing")
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
loader.check_profile(pulse,"pulse")

