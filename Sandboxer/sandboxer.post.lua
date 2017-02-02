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

-- load profile, and perform it's verification
profile=loadstring("return " .. config.profile)()

