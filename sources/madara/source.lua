-- Default Madara selectors are a profile, not a guarantee for every site.
-- Callers may replace any selector or path in the supplied configuration.
local M={}
function M.profile(config)
    assert(type(config)=="table")
    local p={
        search_path="{page_path}/?s={query}&post_type=wp-manga",
        popular_path="/manga{page_path}/?m_orderby=views",
        latest_path="/manga{page_path}/?m_orderby=latest",
        list_selectors={".page-item-detail",".manga__item",".c-tabs-item__content"},
        list_link_selectors={".item-thumb a",".post-title a"},
        list_title_selector=".post-title a",next_selectors={"a.next","a.nextpostslink","div.nav-previous a"},
        title_selector=".post-title h1",description_selector=".summary__content",
        author_selector=".author-content a",artist_selector=".artist-content a",
        genre_selector=".genres-content a",cover_selector=".summary_image img",
        chapter_selector="li.wp-manga-chapter a",page_selector=".reading-content img",
        -- Lazy-image attribute priority adapted from Keiyoushi MadaraBase
        -- (Apache-2.0); see ATTRIBUTION.md and third_party/keiyoushi/LICENSE.
        page_attributes={"data-src","data-lazy-src","data-lzl-src","data-cfsrc","data-manga-src","src"},
    }
    for key,value in pairs(config) do p[key]=value end
    return p
end
return M
