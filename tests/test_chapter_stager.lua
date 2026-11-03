local Stager = dofile("reader/chapter_stager.lua")
local validate = dofile("reader/image_validation.lua").validate
local files, built, finished = {}, nil, nil
local deps = {validate=validate, pathFor=function(i) return "staging/" .. i end, remove=function(p) files[p]=nil end,
    download=function(page,path,limit,cb) files[path]=true; cb({content_type="image/jpeg",size=4,prefix="\255\216\255x"}) end,
    build=function(target,pages) built={target=target,count=#pages,first=pages[1].path,last=pages[#pages].path}; return true end}
Stager.start(deps,{{image_url="https://one"},{image_url="https://two"}},"out.cbz",function(ok,err) finished=ok or err end)
assert(finished == true and built.count == 2 and built.first == "staging/1" and built.last == "staging/2" and next(files) == nil)
deps.download=function(page,path,limit,cb) files[path]=true; cb({content_type="text/html",size=4,prefix="no"}) end
Stager.start(deps,{{image_url="https://one"}},"out.cbz",function(ok,err) finished=err end)
assert(finished and next(files)==nil)
local callback, cancelled
 deps.download=function(page,path,limit,cb) files[path]=true; callback=cb; return function() cancelled=true end end
local job=Stager.start(deps,{{image_url="https://one"}},"out.cbz",function(ok,err) finished=err end)
job:cancel(); assert(cancelled and next(files)~=nil)
callback(nil,"Cancelled"); assert(finished == "Cancelled" and next(files)==nil)
print("Chapter staging tests passed")
