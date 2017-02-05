assert(config.profile~="dbus" and
 config.profile~="pulse" and
 config.profile~="profile" and
 config.profile~="loader" and
 config.profile~="config" and
 config.profile~="defaults",
 "cannot use service table name as profile: "..config.profile)

-- load profile
profile=loadstring("return " .. config.profile)()

-- sandbox table verification
assert(type(sandbox)=="table", "sandbox param incorrect")

-- lockdown table
assert(type(sandbox.lockdown)=="nil" or type(sandbox.lockdown)=="table", "sandbox.lockdown param incorrect")
if type(sandbox.lockdown)=="nil" then sandbox.lockdown={} end
assert(type(sandbox.lockdown.user)=="nil" or type(sandbox.lockdown.user)=="boolean", "sandbox.lockdown.user param incorrect")
assert(type(sandbox.lockdown.ipc)=="nil" or type(sandbox.lockdown.ipc)=="boolean", "sandbox.lockdown.ipc param incorrect")
assert(type(sandbox.lockdown.pid)=="nil" or type(sandbox.lockdown.pid)=="boolean", "sandbox.lockdown.pid param incorrect")
assert(type(sandbox.lockdown.net)=="nil" or type(sandbox.lockdown.net)=="boolean", "sandbox.lockdown.net param incorrect")
assert(type(sandbox.lockdown.uts)=="nil" or type(sandbox.lockdown.uts)=="boolean", "sandbox.lockdown.uts param incorrect")
assert(type(sandbox.lockdown.cgroup)=="nil" or type(sandbox.lockdown.cgroup)=="boolean", "sandbox.lockdown.cgroup param incorrect")
if type(sandbox.lockdown.user)=="nil" then sandbox.lockdown.user=true end
if type(sandbox.lockdown.ipc)=="nil" then sandbox.lockdown.ipc=true end
if type(sandbox.lockdown.pid)=="nil" then sandbox.lockdown.pid=true end
if type(sandbox.lockdown.net)=="nil" then sandbox.lockdown.net=false end
if type(sandbox.lockdown.uts)=="nil" then sandbox.lockdown.uts=true end
if type(sandbox.lockdown.cgroup)=="nil" then sandbox.lockdown.cgroup=false end
assert(type(sandbox.lockdown.uid)=="nil" or type(sandbox.lockdown.uid)=="number", "sandbox.lockdown.uid param incorrect")
assert(type(sandbox.lockdown.gid)=="nil" or type(sandbox.lockdown.gid)=="number", "sandbox.lockdown.gid param incorrect")
assert(type(sandbox.lockdown.hostname)=="nil" or type(sandbox.lockdown.hostname)=="string", "sandbox.lockdown.hostname param incorrect")
if type(sandbox.lockdown.uid)=="number" then sandbox.lockdown.user=true end
if type(sandbox.lockdown.gid)=="number" then sandbox.lockdown.user=true end
if type(sandbox.lockdown.hostname)=="string" then sandbox.lockdown.uts=true end

-- integration table
assert(type(sandbox.integration)=="nil" or type(sandbox.integration)=="table", "sandbox.integration param incorrect")
if type(sandbox.integration)=="nil" then sandbox.integration={} end
assert(type(sandbox.integration.pulse)=="nil" or type(sandbox.integration.pulse)=="boolean", "sandbox.integration.pulse param incorrect")
assert(type(sandbox.integration.x11)=="nil" or type(sandbox.integration.x11)=="boolean", "sandbox.integration.x11 param incorrect")
if type(sandbox.integration.pulse)=="nil" then sandbox.integration.pulse=true end
if type(sandbox.integration.x11)=="nil" then sandbox.integration.x11=true end

-- features table
assert(type(sandbox.features)=="nil" or type(sandbox.features)=="table", "sandbox.features param incorrect")
if type(sandbox.features)=="nil" then sandbox.features={} end
assert(type(sandbox.features.dbus)=="nil" or type(sandbox.features.dbus)=="boolean", "sandbox.features.dbus param incorrect")
if type(sandbox.features.dbus)=="nil" then sandbox.features.dbus=true end

-- setup table
assert(type(sandbox.setup)=="table", "sandbox.setup param incorrect")
assert(type(sandbox.setup.basedir)=="string", "sandbox.setup.basedir param incorrect")
assert(type(sandbox.setup.static_executor)=="nil" or type(sandbox.setup.static_executor)=="boolean", "sandbox.setup.static_executor param incorrect")
if type(sandbox.setup.static_executor)=="nil" then sandbox.setup.static_executor=false end
assert(type(sandbox.setup.chroot)=="nil" or type(sandbox.setup.chroot)=="table", "sandbox.setup.chroot param incorrect")

function loader.check_one_level_string_list(target, name)
 assert(type(target)=="nil" or type(target)=="table", name.." table is incorrect")
 for index,field in ipairs(target) do
  assert(type(field)=="string", name.."[".. index .."] value is incorrect")
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

-- custom command table
loader.check_two_level_string_list(sandbox.setup.custom_commands,"sandbox.setup.custom_commands")

-- env tables
loader.check_two_level_string_list(sandbox.setup.env_blacklist,"sandbox.setup.env_blacklist")
loader.check_two_level_string_list(sandbox.setup.env_whitelist,"sandbox.setup.env_whitelist")

-- env set table
assert(type(sandbox.setup.env_set)=="nil" or type(sandbox.setup.env_set)=="table","sandbox.setup.env_set table is incorrect")
if type(sandbox.setup.env_set)=="table" then
 for index,field in ipairs(sandbox.setup.env_set) do
  assert(type(field)=="table", "sandbox.setup.env_set["..index.."] subtable is incorrect")
  for mi,mf in ipairs(field) do
   assert(type(mf)=="table", "sandbox.setup.env_set["..index.."]["..mi.."] value is incorrect")
   env_idx=0
   for vi,vf in ipairs(mf) do
    assert(vi<3,"sandbox.setup.env_set["..index.."]["..mi.."] has incorrect strings count")
    assert(type(vf)=="string","sandbox.setup.env_set["..index.."]["..mi.."]["..vi.."] value is incorrect")
    env_idx=env_idx+1
   end
   assert(env_idx==2,"sandbox.setup.env_set["..index.."]["..mi.."] has incorrect strings count")
  end
 end
end

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
loader.check_two_level_string_list(profile.env_set, name..".env_set")
assert(type(profile.term_signal)=="number" or type(profile.term_signal)=="nil", name..".term_signal value is incorrect or missing")
assert(type(profile.attach)=="boolean" or type(profile.attach)=="nil", name..".attach value is incorrect or missing")
if type(profile.attach)=="nil" then profile.attach=false end
assert(type(profile.pty)=="boolean" or type(profile.pty)=="nil", name..".pty value is incorrect or missing")
if type(profile.pty)=="nil" then profile.pty=false end

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

