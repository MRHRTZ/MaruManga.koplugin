local Migration=dofile("storage/migration.lua")
local snapshot={marumanga={version=3},marumanga_queue={version=1,items={}},marumanga_repositories={items={}},
    marumanga_library={version=1,manga={},history={},chapters={},chapter_sync={},archives={
        ["/old/books/series.cbz"]={manga={id="series",source_id="komiku",title="Series"},chapters={}}}}}
local manifest=assert(Migration.create(snapshot,{{path="/old/books/series.cbz",entry="files/000001.cbz"}}))
assert(Migration.validate(manifest))
local restored=assert(Migration.restore(manifest,{["/old/books/series.cbz"]="/new/books/series.cbz"}))
assert(restored.marumanga.version==3 and restored.marumanga_queue.version==1 and restored.marumanga_repositories.items)
assert(restored.marumanga_library.archives["/new/books/series.cbz"].manga.title=="Series")
assert(next(restored.marumanga_library.archives)=="/new/books/series.cbz")
local bad={format=manifest.format,version=manifest.version,settings=snapshot,archives={{path="/safe.cbz",entry="files/../../evil.cbz"}}}
assert(not Migration.validate(bad))
local duplicate={format=manifest.format,version=manifest.version,settings=snapshot,archives={
    {path="/one.cbz",entry="files/000001.cbz"},{path="/one.cbz",entry="files/000002.cbz"}}}
assert(not Migration.validate(duplicate))
assert(not Migration.validate({format="other",version=1,settings={},archives={}}))
print("Migration manifest tests passed")
