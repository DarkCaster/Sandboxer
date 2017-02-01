-- sandbox table verification
assert(type(sandbox)=="table", "sandbox param incorrect")
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

-- load profile, and perform it's verification
profile=loadstring("return " .. loader.extra[1])()
