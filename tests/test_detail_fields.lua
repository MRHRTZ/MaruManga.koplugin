local DetailFields = dofile("core/detail_fields.lua")

assert(DetailFields.genreNames(nil) == "")
assert(DetailFields.genreNames("Action") == "")
assert(DetailFields.genreNames({"Action", "Adventure"}) == "Action, Adventure")
assert(DetailFields.genreNames({
    {id=7, name="Romance", slug="romance"},
    {id=153, name="Supernatural", slug="supernatural"},
}) == "Romance, Supernatural")
assert(DetailFields.genreNames({
    {title="Fantasy"}, {label="Drama"}, {slug="slice-of-life"}, {name={invalid=true}}, false, 42,
}) == "Fantasy, Drama, slice-of-life")

print("Manga detail field tests passed")
