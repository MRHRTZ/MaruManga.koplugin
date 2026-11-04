local Scan=dofile("core/archive_scan.lua")
local entries={{source_id="s",chapter_id="a",path="a",sha256="one"},{source_id="s",chapter_id="b",path="b",sha256="one"},{source_id="s",chapter_id="c",path="c"},{source_id="s",chapter_id="d",path="d"},{source_id="s",chapter_id="e",path="e",sha256="one"}}
local result=Scan.run(entries,function(path) if path=="e" then return nil end; return path=="a" and "one" or "two" end,function(path) return path~="d" and not path:match("%.incomplete$") end)
assert(result["s:a"]=="valid" and result["s:b"]=="modified" and result["s:c"]=="unverified" and result["s:d"]=="missing" and result["s:e"]=="error")
print("Archive synchronization classification tests passed")
