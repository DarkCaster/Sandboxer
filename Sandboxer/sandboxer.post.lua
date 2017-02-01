-- sandbox table verification
assert(type(sandbox)=="table", "sandbox param incorrect")



-- load profile, and perform it's verification
profile=loadstring("return " .. loader.extra[1])()
