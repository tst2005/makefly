#!/usr/bin/env lua
-- process.lua
-- Process db and src directory to create a result
-- Olivier DOSSMANN

--[[Depends

LuaFileSystem is required: 
luarocks install luafilesystem

Markdown is required:
luarocks install markdown

]]--

require 'rope'
require 'lfs'
require 'markdown'

--[[ Variables ]]--

-- requirements
local lfs = require "lfs"

-- default's directories
local currentpath = os.getenv('CURDIR') or '.'
local dbpath = os.getenv('DBDIR') or currentpath .. '/db'
local srcpath = os.getenv('SRCDIR') or currentpath .. '/src'
local tmppath = os.getenv('TMPDIR') or currentpath .. '/tmp'
local templatepath = os.getenv('TMPLDIR') or currentpath .. '/template'
local staticpath = os.getenv('STATICDIR') or currentpath .. '/static'
local specialpath = os.getenv('SPECIALDIR') or currentpath .. '/special'
local langpath = os.getenv('LANGDIR') or currentpath .. '/lang'
local publicpath = os.getenv('DESTDIR') or currentpath .. '/pub'
-- default's files
local makeflyrcfile = os.getenv('conf') or 'makefly.rc'
local themercfile = 'config.mk'
local jskomment_js_filename = 'jskomment.js'
local introduction_filename = 'introduction'
local footer_filename = 'footer'
-- theme filenames
local page_header_name = 'header.xhtml'
local page_footer_name = 'footer.xhtml'
local page_posts_name = 'post.index.xhtml'
local page_article_name = 'article.xhtml'
local page_homepage_article_name = 'article.index.xhtml'
local page_post_element_name = 'element.xhtml'
local page_tag_element_name = 'tagelement.xhtml'
local page_tag_link_name = 'taglink.xhtml'
local page_tag_index_name = 'tags.xhtml'
local page_sidebar_name = 'sidebar.xhtml'
local page_searchbar_name = 'menu.search_bar.xhtml'
local page_about_name = 'menu.about.xhtml'
local page_read_more_name = 'read_more_link.xhtml'
local page_jskomment = templatepath .. '/' .. 'jskomment.article.xhtml'
local page_jskomment_declaration = templatepath .. '/' .. 'jskomment_declaration.xhtml'
local page_jskomment_script = templatepath .. '/' .. jskomment_js_filename
local page_jskomment_css_name = 'jskomment.css'
local page_rss_header = templatepath .. '/' .. 'feed.header.rss'
local page_rss_element = templatepath .. '/' .. 'feed.element.rss'
local page_rss_footer = templatepath .. '/' .. 'feed.footer.rss'
local page_eli_content = templatepath .. '/' .. 'eli_content.xhtml'
local page_eli_css = templatepath .. '/' .. 'eli.css'
local page_eli_declaration = templatepath .. '/' .. 'eli_declaration.xhtml'
local page_eli_script = templatepath .. '/' .. 'eli.js'
-- others
local blog_url = os.getenv('BLOG_URL') or ''
local version = os.getenv('VERSION') or 'unknown-trunk'
local replacements = {} -- substitution table
local today = os.time() -- today's timestamp
local tags = {}
-- default values
local datetime_format_default = '%Y-%m-%dT%H:%M'
local theme_default = "responsive" -- theme
local postdir_name_default = 'posts' -- name for posts directory
local tagdir_name_default = 'tags' -- name for tags directory
local about_default = 'about' -- about's page name in special directory
local intro_default = 'introduction' -- name introduction page in special directory
local footer_default = 'footer' -- footer's name in special directory
local sidebar_default = 'sidebar' -- sidebar's name in special directory
local bodyclass_default = 'single' -- body class for pages
local index_name_default = 'index' -- index name
local rss_name_default = 'rss' -- rss default name
local extension_default = '.html' -- file extension for HTML pages
local rss_extension_default = '.xml' -- rss file extension
local language_default = 'en' -- language name
local max_post_default = 3 -- number of posts displayed on homepage
local max_post_lines_default = nil -- no post limitations
local max_rss_default = 5 -- number of posts displayed in RSS Feed
local jskomment_max_default = 3 -- number of comments displayed by default for each post
local jskomment_url_default = 'http://jskomment.appspot.com' -- default URL of JSKOMMENT comment system
local jskomment_captcha_theme_default = 'white'
local eli_css_name = 'eli.css'
local eli_js_filename = 'eli.js'
local eli_max_default = 5
local eli_type_default = 'user'
local eli_tmp_file = tmppath .. '/' .. 'content.eli'
-- default display values
local display_info =    '  INFO   '
local display_success = ' SUCCESS '
local display_enable =  ' ENABLE  '
local display_disable = ' DISABLE '
local display_warning = ' WARNING '
local display_error =   '  ERROR  '

--[[ Methods ]]--

function string:split(sep)
  local sep, fields = sep or ":", {}
  local pattern = string.format("([^%s]+)", sep)
  self:gsub(pattern, function(c) fields[#fields+1] = c end)
  return fields
end

function deleteBeginSpace(string)
  local res = string.gsub(string, "^ *", '')
  return res
end

function deleteEndSpace(string)
  local res = string.gsub(string, " *$", '')
  return res
end

function listing (path, extension)
  local files = {}
  if lfs.attributes(path) then
    for file in lfs.dir(path) do
      if file ~= "." and file ~= ".." then
        local f = path..'/'..file
        local attr = lfs.attributes (f)
        local filext = (string.match(file, "[^\\/]-%.?([^%.\\/]*)$"))
        if attr.mode == 'file' and filext == extension then
          table.insert(files, f)
        end
      end
    end
  else
    files = nil
  end
  return files
end

function checkDirectory(path)
  if lfs.attributes(path) == nil then
    assert(lfs.mkdir(path))
    -- Display created directory
    print (string.format("-- [%s] New folder: %s", display_success, path))
  end
end

function getConfig(file)
  local result = {}
  local f = assert(io.open(file, 'r'))
  while true do
    local line = f.read(f)
    if not line then break end
    local key = line:match('(.-)[ ]+=')
    local val = line:match('=[ ]+(.*)')
    local comment = string.find(line, '^#+.*')
    if comment then
      -- do nothing with commented lines
    elseif key then
      result[key] = val
    end
  end
  assert(f:close())
  return result
end

function replace(string, table)
  return string:gsub("$(%b{})", function(string)
    return table[string:sub(2,-2)]
   end)
end

function readFile(path, mode)
  local result = ''
  if mode == nil then
    local mode = 'r'
  end
  if mode ~= 'r' and mode ~= 'rb' then
    print(string.format("-- [%s] Unknown read mode while reading this path: %s.", display_error, path))
    os.exit(1)
  end
  local attr = lfs.attributes(path)
  if attr and attr.mode == 'file' then
    local f = assert(io.open(path, mode))
    result = assert(f:read('*a'))
    assert(f:close())
  end
  return result
end

function headFile(path, number)
  local result = ''
  if not number then
    return readFile(path, 'r')
  else
    local attr = lfs.attributes(path)
    if attr and attr.mode == 'file' then
      local f = assert(io.open(path, mode))
      i = 0
      for line in f:lines() do
        result = result .. line .. '\n'
        i = i + 1
        if i == number then break end
      end
    end
  end
  return result
end

function copyFile(origin, destination, replacements)
  local content = ''
  if lfs.attributes(origin) and lfs.attributes(origin).mode == 'file' then
    -- open the file
    content = readFile(origin, 'r')
  end
  -- write in destination
  local result = assert(io.open(destination, 'wb'))
  if content == nil then
    result:close()
  else
    if replacements then
      result:write(replace(content, replacements))
    else
      result:write(content)
    end
  end
  result:close()
end

function copy(origin, destination)
  local attr = lfs.attributes(origin)
  if attr and attr.mode == 'directory' then
    -- create destination if no one exists
    if lfs.attributes(destination) == nil then
      lfs.mkdir(destination)
    end
    -- browse origin directory
    for element in lfs.dir(origin) do
      if element ~= '.' and element ~= '..' then
        local path = origin .. '/' .. element
  -- launch copy directory if element is a directory, otherwise copy file
  if lfs.attributes(path) and lfs.attributes(path).mode == 'directory' then
    copy(path, destination .. '/' .. element)
  else
    copyFile(path, destination .. '/' .. element)
  end
      end
    end
  -- if origin is a file, just launch copyFile function
  elseif attr and attr.mode == 'file' then
    copyFile(origin, destination)
  else
    print (string.format("-- [%s] %s not found in copy method!", display_error, origin))
    os.exit(1)
  end
end

function getSubstitutions(replacements, local_replacements)
  -- create substitutions list
  local result = {}
  for k, v in pairs(replacements) do 
    result[k] = v
  end
  for k, v in pairs(local_replacements) do 
    result[k] = v
  end
  return result
end

function stuffTemplate(filepath, content, variable, option, double_replacement)
  -- default initialization
  local double = nil
  local result = ''
  local markdown_content = ''
  -- get markdown result of content if option is 'markdown'
  if option and option == 'markdown' and content then
    markdown_content = markdown(content)
  end
  -- activate double replacement function if double_replacement not nil
  if double_replacement then
    double = true
  end
  -- get file content
  file = readFile(filepath, 'r')
  if file then
    local template_table = {}
    -- if no content or no variable, it's useless to complete template_table
    if content and variable then
      template_table[variable] = markdown_content
    end
    -- do replacements
    local substitutions = getSubstitutions(replacements, template_table)
    if double then
      local tmp_result = replace(file, substitutions)
      result = replace(tmp_result, replacements)
    else
      result = replace(file, substitutions)
    end
  end
  return result
end

function createPost(file, config, header, footer, tagpath, template_file, template_tag_file, date_format)
  -- get post's title and timestamp
  local timestamp, title = string.match(file, "(%d+),(.+)%.mk")
  -- only create post if date is older than today
  if os.date('%s', today) > os.date('%s', timestamp) then
    -- open template file
    local template = readFile(template_file, 'r')
    -- open post output file
    local out = assert(io.open(postpath .. "/" .. title .. resultextension, 'wb'))
    -- create a rope for post's result
    local post = rope()
    -- open content of post (SRC file)
    local content = readFile(srcpath .. "/" .. title .. ".md", 'r')
    -- markdown process on content
    local markdown_content = markdown(content)
    -- process tags
    local post_tags = {}
    for i, tag in pairs(config['TAGS']:split(',')) do
      local post_tagname = deleteEndSpace(deleteBeginSpace(tag))
      table.insert(post_tags, post_tagname)
    end
    -- create tag links
    local post_tag_links = createTagLinks(post_tags, tagpath, template_tag_file, resultextension)
    -- concatenate all final post subelements
    post:push (header)
    post:push (template)
    post:push (footer)
    -- local replacements
    local post_replacements = {
      TITLE = config['TITLE'],
      POST_TITLE = config['TITLE'],
      ARTICLE_CLASS_TYPE = config['TYPE'],
      CONTENT = markdown_content,
      POST_FILE = title .. resultextension,
      TAG_LINKS_LIST = post_tag_links and replace(post_tag_links, replacements) or '',
      DATE = os.date(date_format, timestamp) or '',
      DATETIME = os.date(datetime_format_default, timestamp) or '',
      POST_AUTHOR = config['AUTHOR'],
      POST_ESCAPED_TITLE = title,
    }
    -- create substitutions list
    local substitutions = {}
    for k, v in pairs(replacements) do 
      substitutions[k] = v
    end
    for k, v in pairs(post_replacements) do 
      substitutions[k] = v
    end
    -- add comment block if comment system is activated
    if template_comment then
      local jskomment_prefix = config['JSKOMMENT_PREFIX'] and config['JSKOMMENT_PREFIX'] ~= '' and config['JSKOMMENT_PREFIX'] or replacements['BLOG_URL']
      local jskomment_id = jskomment_prefix .. '/' .. title
      local jskomment_content = replace(template_comment, {JSKOMMENT_ID=jskomment_id})
      substitutions['JSKOMMENT_CONTENT'] = jskomment_content
    end
    -- ${VARIABLES} substitution on markdown content
    local final_content = replace(post:flatten(), substitutions)
    -- write result to output file
    out:write(final_content)
    -- close output file
    assert(out:close())
    -- Print post title
    print (string.format("-- [%s] New post: %s", display_success, config['TITLE']))
  end
end

function dispatcher ()
  while true do
    local n = table.getn(threads)
    if n == 0 then break end   -- no more threads to run
    for i=1,n do
      local status, res = coroutine.resume(threads[i])
      if not res then    -- thread finished its task?
        table.remove(threads, i)
        break
      end
    end
  end
end

function compare_post(a, b, order)
  local r = a['file'] > b['file']
  if order == nil then
    r = a['file'] > b['file']
  elseif order == 'asc' then
    r = a['file'] < b['file']
  elseif order == 'desc' then
    r = a['file'] > b['file']
  else
    r = a['file'] > b['file']
  end
  return r
end

function pairsByKeys (t, f)
  local a = {}
  for n in pairs(t) do table.insert(a, n) end
  table.sort(a, f)
  local i = 0      -- iterator variable
  local iter = function ()   -- iterator function
    i = i + 1
    if a[i] == nil then return nil
    else return a[i], t[a[i]]
    end
  end
  return iter
end

function createTagLinks(post_tags, tagpath, file, extension)
  -- prepare some values
  local result = ''
  -- get single tag element template
  local template = readFile(file, 'r')
  template = string.gsub(template, '\n$', '')
  -- add each tag
  for k, v in pairs(post_tags) do
    if k > 1 then
      result = result .. ', '
    end
    local tag_page = string.gsub(v, '%s', '_') .. extension
    result = result .. replace(template, {TAG_PAGE=tag_page, TAG_NAME=v})
  end
  return result
end

function createPostIndex(posts, index_file, header, footer, replacements, extension, template_index_file, template_element_file, short_date_format, tagpath, template_taglink_file, template_article_index_file, max_post, max_post_lines)
  -- open result file
  local post_index = io.open(index_file, 'wb')
  -- prepare rss elements
  local rss_index = io.open(publicpath .. '/' .. rss_name_default .. rss_extension_default, 'wb')
  local rss_header = readFile(page_rss_header, 'r')
  local rss_footer = readFile(page_rss_footer, 'r')
  local rss_element = readFile(page_rss_element, 'r')
  -- create a rope to merge all text
  local index = rope()
  local rss = rope()
  -- get header for results
  index:push (header)
  rss:push (rss_header)
  -- get post index general content
  local post_content = readFile(template_index_file, 'r')
  index:push (post_content)
  -- get info for each post
  local post_element = readFile(template_element_file, 'r')
  -- create temporary file with first posts
  local first_posts_file = io.open(tmppath .. '/index.tmp', 'wb')
  -- open template for posts that appears on index
  local template_article_index = readFile(template_article_index_file, 'r')
  -- sort posts in a given order
  table.sort(posts, compare_post)
  -- prepare some values
  index_nb = 0
  -- process posts
  for k, v in pairs(posts) do
    -- get post's title
    local timestamp, title = string.match(v['file'], "(%d+),(.+)%.mk")
    -- only add a link for post older than today
    if os.date('%s', today) > os.date('%s', timestamp) then
      -- local substitutions
      local metadata = {
        POST_TITLE = v['conf']['TITLE'],
        POST_FILE = title .. resultextension,
        POST_AUTHOR = v['conf']['AUTHOR'],
        POST_DESCRIPTION = v['conf']['DESCRIPTION'],
        SHORT_DATE = os.date(short_date_format_default, timestamp) or '',
        DATE = os.date(date_format_default, timestamp) or '',
        DATETIME = os.date(datetime_format_default, timestamp) or '',
      }
      -- registering tags
      local post_conf_tags = v['conf']['TAGS'] or nil
      if post_conf_tags then
        local post_tags = {}
        for i, tag in pairs(post_conf_tags:split(',')) do
          local tagname = deleteEndSpace(deleteBeginSpace(tag))
          -- remember the tagname to create tag links
          table.insert(post_tags, tagname)
          -- add tag to list of all tags
          if tags[tagname] == nil then
            tags[tagname] = {title}
          else
            table.insert(tags[tagname], title)
          end
        end
        -- create tag links
        local tag_links = createTagLinks(post_tags, tagpath, template_taglink_file, extension)
        if tag_links then
          metadata['TAG_LINKS_LIST'] = tag_links
        end
      end
      -- prepare substitutions for the post
      local post_substitutions = getSubstitutions(v, metadata)
      -- remember this post's element for each tag page
      local post_element_content = replace(post_element, post_substitutions)
      local remember_file = assert(io.open(tmppath .. '/' .. title, 'wb'))
      assert(remember_file:write(post_element_content))
      assert(remember_file:close())
      -- push result into index
      index:push(post_element_content)
      -- read post real content
      local post_content_file = srcpath .. '/' .. title .. '.md'
      local real_post_content = readFile(post_content_file, 'r')
      -- process post to be displayed on HOMEPAGE
      local final_post_content = readFile(post_content_file, 'r')
      if index_nb < max_post then
        if max_post_lines then
          local n = 0
          for i in real_post_content:gmatch("\n") do n=n+1 end
          final_post_content = headFile(post_content_file, max_post_lines)
          if max_post_lines < n then
            local page_read_more = readFile(themepath .. '/' .. page_read_more_name, 'r')
            final_post_content = final_post_content .. page_read_more
          end
        end
        local post_content = replace(template_article_index, {CONTENT=markdown(final_post_content)})
        -- complete missing info
        post_substitutions['ARTICLE_CLASS_TYPE'] = v['conf']['TYPE']
        post_substitutions['POST_ESCAPED_TITLE'] = title
        -- add comment block if comment system is activated
        if template_comment then
          local jskomment_prefix = v['conf']['JSKOMMENT_PREFIX'] and v['conf']['JSKOMMENT_PREFIX'] ~= '' and v['conf']['JSKOMMENT_PREFIX'] or replacements['BLOG_URL']
          local jskomment_id = jskomment_prefix .. '/' .. title
          local jskomment_content = replace(template_comment, {JSKOMMENT_ID=jskomment_id})
          post_substitutions['JSKOMMENT_CONTENT'] = jskomment_content
        end
        local content4index = replace(post_content, post_substitutions)
        assert(first_posts_file:write(content4index))
      end
      -- process post to be used in RSS file
      if index_nb < max_rss then
        local rss_post_html_link = blog_url .. '/' .. postdir_name .. '/' .. title .. resultextension
        local rss_post = replace(rss_element, {DESCRIPTION=markdown(real_post_content), TITLE=v['conf']['TITLE'], LINK=rss_post_html_link})
        rss:push(rss_post)
      end
      -- incrementation
      index_nb = index_nb + 1
    end
  end
  -- close first_posts file
  assert(first_posts_file:close())
  index:push (footer)
  -- rss process
  rss:push (rss_footer)
  rss_replace = replace(rss:flatten(), replacements)
  rss_index:write(rss_replace)
  rss_index:close()
  -- Display that RSS file was created
  print (string.format("-- [%s] RSS feed: BUILT.", display_success))
  -- do substitutions on page
  local index_substitutions = getSubstitutions(replacements, {TITLE=replacements['POST_LIST_TITLE']})
  local index_content = replace(index:flatten(), index_substitutions)
  post_index:write(index_content)
  -- Close post's index
  post_index:close()
  -- Display that post index was created
  print (string.format('-- [%s] Post list: BUILT.', display_success))
end

function createTag(filename, title, posts, header, footer, replacements)
  local page = rope()
  page:push(header)
  -- insert content (all posts linked to this tag)
  for k, post in pairs(posts) do
    local content = ''
    content = readFile(tmppath .. '/' .. post, 'r')
    if content then
      page:push(content)
    end
  end
  page:push(footer)
  local page_file = assert(io.open(filename, 'wb'))
  -- do substitutions on page
  local substitutions = getSubstitutions(replacements, {TITLE=title})
  local final_content = replace(page:flatten(), substitutions)
  page_file:write(final_content)
  page_file:close()
  -- Print tag title
  print (string.format("-- [%s] New tag: %s", display_success, title))
end

function createTagIndex(all_tags, tagpath, index_filename, header, footer, replacements, extension, template_index_filename, template_element_filename)
  local index = rope()
  index:push(header)
  local index_file = assert(io.open(tagpath .. '/' .. index_filename, 'wb'))
  -- read general tag index template file
  local template_index = readFile(template_index_filename, 'r')
  -- read tage element template file
  local template_element = readFile(template_element_filename, 'r')
  -- browse all tags
  local taglist_content = ''
  for tag, posts in pairsByKeys(tags) do
    local tag_page = string.gsub(tag, '%s', '_') .. extension
    taglist_content = taglist_content .. replace(template_element, {TAG_PAGE=tag_page, TAG_NAME=tag})
    createTag(tagpath .. '/' .. tag_page, tag, posts, header, footer, replacements)
  end
  index:push(replace(template_index, {TAGLIST_CONTENT=taglist_content}))
  index:push(footer)
  -- do substitutions on page
  local substitutions = getSubstitutions(replacements, {TITLE=replacements['TAG_LIST_TITLE'], BODY_CLASS='tags'})
  local index_content = replace(index:flatten(), substitutions)
  index_file:write(index_content)
  -- Close post's index
  assert(index_file:close())
  -- Display that tag index was created
  print (string.format("-- [%s] Tag list: BUILT.", display_success))
end

function createHomepage(file, title, header, footer)
  local index = rope()
  local index_file = io.open(file, 'wb')
  local content = readFile(tmppath .. '/' .. 'index.tmp', 'r')
  index:push(header)
  index:push(content)
  index:push(footer)
  local substitutions = getSubstitutions(replacements, {BODY_CLASS='home', TITLE=title})
  local final_content = replace(index:flatten(), substitutions)
  index_file:write(final_content)
  assert(index_file:close())
  -- Display that homepage was created
  print (string.format("-- [%s] Homepage: BUILT.", display_success))
end

--[[ MAIN ]]--
-- create thread table
threads = {}

-- Get makefly's configuration
makeflyrc = getConfig(makeflyrcfile)

-- Set variables regarding user configuration
index_name = makeflyrc['INDEX_FILENAME'] or index_name_default
resultextension = makeflyrc['PAGE_EXT'] or extension_default
theme = makeflyrc['THEME'] or theme_default
themepath = templatepath .. '/' .. theme
postdir_name = makeflyrc['POSTDIR_NAME'] or postdir_name_default
tagdir_name = makeflyrc['TAGDIR_NAME'] or tagdir_name_default
bodyclass = makeflyrc['BODY_CLASS'] or bodyclass_default
postpath = publicpath .. '/' .. postdir_name
tagpath = publicpath .. '/' .. tagdir_name
index_filename = index_name .. resultextension
date_format_default = makeflyrc['DATE_FORMAT'] or '%Y-%m-%d at %H:%M'
short_date_format_default = makeflyrc['SHORT_DATE'] or '%Y/%m'
max_post = makeflyrc['MAX_POST'] and tonumber(makeflyrc['MAX_POST']) or max_post_default
max_post_lines = makeflyrc['MAX_POST_LINES'] and tonumber(makeflyrc['MAX_POST_LINES']) or max_post_lines_default
max_rss = makeflyrc['MAX_RSS'] and tonumber(makeflyrc['MAX_RSS']) or max_rss_default
jskomment_max = makeflyrc['JSKOMMENT_MAX'] and tonumber(makeflyrc['JSKOMMENT_MAX']) or jskomment_max_default
jskomment_url = makeflyrc['JSKOMMENT_URL'] or jskomment_url_default
-- Display which theme the user have choosed
print (string.format("-- [%s] Theme: %s", display_info, theme))

-- Get language configuration
language = makeflyrc['BLOG_LANG'] or language_default
languagerc = getConfig(langpath .. '/translate.' .. language)

-- Check if needed directories exists. Otherwise create them
for k,v in pairs({tmppath, publicpath, postpath, tagpath}) do
  checkDirectory(v)
end

-- Create path for template's files
local page_header = themepath .. '/' .. page_header_name
local page_footer = themepath .. '/' .. page_footer_name
local page_article_single = themepath .. '/' .. page_article_name
local page_post_element = themepath .. '/' .. page_post_element_name
local page_tag_element = themepath .. '/' .. page_tag_element_name
local page_tag_link = themepath .. '/' .. page_tag_link_name
local page_sidebar = themepath .. '/' .. page_sidebar_name
local page_searchbar = themepath .. '/' .. page_searchbar_name
local page_article_index = themepath .. '/' .. page_homepage_article_name

-- Read template configuration file
local themerc = getConfig(themepath .. '/' .. themercfile)

-- Some values that comes from template configuration file
local jskomment_captcha_theme = themerc['JSKOMMENT_CAPTCHA_THEME'] or jskomment_captcha_theme_default

-- Read template's mandatory files
local header = readFile(page_header, 'r')
local footer = readFile(page_footer, 'r')

-- Create CSS files
css_file = themepath .. '/style/' .. themerc['CSS_FILE']
local css_color_file_name = themerc['CSS_COLOR_FILE']
if makeflyrc['FLAVOR'] and makeflyrc['FLAVOR'] ~= '' then
  local css_color_file_test = 'color_' .. theme .. '_' .. makeflyrc['FLAVOR'] .. '.css'
  local css_color_file_attr = lfs.attributes(themepath .. '/style/' .. css_color_file_test)
  if css_color_file_attr and css_color_file_attr.mode == 'file' then
    css_color_file_name = css_color_file_test
  else
    print (string.format("-- [%s] Wrong flavor: %s", display_warning, makeflyrc['FLAVOR']))
  end
  print (string.format("-- [%s] Specific flavor: %s", display_info, makeflyrc['FLAVOR']))
end
css_color_file = themepath .. '/style/' .. css_color_file_name
if themerc['JSKOMMENT_CSS'] then
  jskomment_css_file = themepath .. '/' .. themerc['JSKOMMENT_CSS']
  jskomment_css_filename = themerc['JSKOMMENT_CSS']
else
  jskomment_css_file = templatepath .. '/' .. page_jskomment_css_name
  jskomment_css_filename = page_jskomment_css_name
end
table.insert(threads, coroutine.create(function () copyFile(css_file, publicpath .. '/' .. themerc['CSS_FILE'], { BLOG_URL = blog_url }) end))
table.insert(threads, coroutine.create(function () copyFile(css_color_file, publicpath .. '/' .. themerc['CSS_COLOR_FILE']) end))
-- Copy static theme directory
theme_static_directory = themepath .. '/static'
table.insert(threads, coroutine.create(function () copy(theme_static_directory, publicpath) end))

-- Add result to replacements table (to substitute ${VARIABLES} in files)
replacements = {
  VERSION = version,
  BLOG_TITLE = makeflyrc['BLOG_TITLE'],
  BLOG_DESCRIPTION = makeflyrc['BLOG_DESCRIPTION'],
  BLOG_SHORT_DESC = makeflyrc['BLOG_SHORT_DESC'],
  BLOG_URL = blog_url,
  LANG = makeflyrc['BLOG_LANG'],
  BLOG_CHARSET = makeflyrc['BLOG_CHARSET'],
  RSS_FEED_NAME = makeflyrc['RSS_FEED_NAME'],
  SIDEBAR = '',
  ARTICLE_CLASS_TYPE = 'normal',
  SEARCHBAR = '',
  JSKOMMENT_SCRIPT = '',
  JSKOMMENT_CONTENT = '',
  ELI_SCRIPT = '',
  ELI_CONTENT = '',
  ELI_CSS = '',
  ELI_STATUS = '',
  INTRO_CONTENT = '',
  FOOTER_CONTENT = '',
  ABOUT_LINK = '',
  ABOUT_FILENAME = '',
  CSS_NAME = themerc['CSS_NAME'],
  CSS_FILE = themerc['CSS_FILE'],
  CSS_COLOR_FILE = themerc['CSS_COLOR_FILE'],
  JSKOMMENT_CSS = themerc['JSKOMMENT_CSS'],
  TAGDIR_NAME = tagdir_name,
  POSTDIR_NAME = postdir_name,
  BODY_CLASS = bodyclass,
  POSTDIR_INDEX = index_filename,
  TAGDIR_INDEX = index_filename, -- FIXME: delete these two var to add a new one: INDEX_FILENAME which is better for indexes.
}

-- Add language translation to replacements table
for k, v in pairs(languagerc) do 
  replacements[k] = v
end

-- Check about's page presence
about_file_path = specialpath .. '/' .. about_default .. '.md'
about_file = readFile(about_file_path, 'r')
if about_file then
  print (string.format("-- [%s] About's page available", display_enable))
  replacements['ABOUT_INDEX'] = (makeflyrc['ABOUT_FILENAME'] or about_default) .. extension_default
  replacements['ABOUT_LINK'] = stuffTemplate(themepath .. '/' .. page_about_name, '', '', '', false)
else
  print (string.format("-- [%s] About's page not found", display_disable))
end

-- ELI badge
-- FIXME: Delete "link" tag in HTML header for ELI css file (it's useless)
if makeflyrc['ELI_USER'] and makeflyrc['ELI_API'] then
  print (string.format("-- [%s] ELI badge", display_enable))
  -- Set default ELI mandatory variables
  eli_max = makeflyrc['ELI_MAX'] or eli_max_default
  eli_type = makeflyrc['ELI_TYPE'] or eli_type_default
  -- copy ELI css file
  table.insert(threads, coroutine.create(function () copyFile(page_eli_css, publicpath .. '/' .. eli_css_name) end))
  replacements['ELI_CSS'] = eli_css_name
  -- copy ELI script to public directory
  local template_eli_script = readFile(page_eli_script, 'r')
  local eli_script = assert(io.open(publicpath .. '/' .. eli_js_filename, 'wb'))
  eli_script_substitutions = getSubstitutions(replacements, {ELI_MAX=eli_max,ELI_TYPE=eli_type,ELI_API=makeflyrc['ELI_API'],ELI_USER=makeflyrc['ELI_USER']})
  local eli_script_replace = replace(template_eli_script, eli_script_substitutions)
  eli_script:write(eli_script_replace)
  assert(eli_script:close())
  -- ELI script declaration in all pages
  local template_eli_declaration = readFile(page_eli_declaration, 'r')
  replacements['ELI_SCRIPT'] = replace(template_eli_declaration, {eli_name=eli_js_filename, BLOG_URL=blog_url})
  -- FIXME: get ELI status (with lua socket or anything else)
--  local eli_cmd = 'curl -s ${ELI_API}users/show/${ELI_USER}.xml |grep -E "<text>(.+)</text>"|sed "s/<[/]*text>//g" > ${eli_tmp_file}'
--  eli_cmd = replace(eli_cmd, {ELI_MAX=eli_max,ELI_TYPE=eli_type,ELI_API=makeflyrc['ELI_API'],ELI_USER=makeflyrc['ELI_USER'], eli_tmp_file=eli_tmp_file})
--  status_return = assert(os.execute(eli_cmd))
--  if status_return == 0 then
--    local eli_status = readFile(eli_tmp_file, 'r')
--    replacements['ELI_STATUS'] = eli_status
--  end
  replacements['ELI_STATUS'] = languagerc['ELI_DEFAULT_STATUS'] or ''
  -- read ELI content to add it in all pages
  replacements['ELI_CONTENT'] = stuffTemplate(page_eli_content, '', '')
else
  print (string.format("-- [%s] ELI badge", display_disable))
end

-- Sidebar (display that's active/inactive)
local sidebar_filename = (makeflyrc['SIDEBAR_FILENAME'] or sidebar_default) .. '.md'
if (makeflyrc['SIDEBAR'] and makeflyrc['SIDEBAR'] == '1') or (themerc['SIDEBAR'] and themerc['SIDEBAR'] == '1') then
  print (string.format("-- [%s] Sidebar", display_enable))
  local sidebar_content = readFile(specialpath .. '/' .. sidebar_filename, 'r')
  replacements['SIDEBAR'] = stuffTemplate(page_sidebar, sidebar_content, 'SIDEBAR_CONTENT', 'markdown', true)
else
  print (string.format("-- [%s] Sidebar", display_disable))
end

-- Search bar
if makeflyrc['SEARCH_BAR'] and makeflyrc['SEARCH_BAR'] == '1' then
  print (string.format("-- [%s] Search bar", display_enable))
  replacements['SEARCHBAR'] = stuffTemplate(page_searchbar)
else
  print (string.format("-- [%s] Search bar", display_disable))
end

-- JSKOMMENT system
-- FIXME: Delete "link" tag in header file for JSKOMMENT css file (it's useless)
if makeflyrc['JSKOMMENT'] and makeflyrc['JSKOMMENT'] == '1' then
  print (string.format("-- [%s] Comment system", display_enable))
  -- copy jskomment css file
  table.insert(threads, coroutine.create(function () copyFile(jskomment_css_file, publicpath .. '/' .. jskomment_css_filename) end))
  replacements['JSKOMMENT_CSS'] = jskomment_css_filename
  -- copy jskomment javascript
  local template_jskomment_script = readFile(page_jskomment_script, 'r')
  local jskomment_script = assert(io.open(publicpath .. '/' .. jskomment_js_filename, 'wb'))
  jskomment_script_substitutions = getSubstitutions(replacements, {JSKOMMENT_URL=jskomment_url,JSKOMMENT_MAX=jskomment_max,JSKOMMENT_CAPTCHA_THEME=jskomment_captcha_theme})
  jskomment_script:write(replace(template_jskomment_script, jskomment_script_substitutions))
  assert(jskomment_script:close())
  -- jskomment javascript declaration in all pages
  local template_jskomment_declaration = readFile(page_jskomment_declaration, 'r')
  replacements['JSKOMMENT_SCRIPT'] = replace(template_jskomment_declaration, {jskom_name=jskomment_js_filename, BLOG_URL=blog_url})
  -- read different templates for next processes
  template_comment = readFile(page_jskomment, 'r')
else
  print (string.format("-- [%s] Comment system", display_disable))
end

-- Introduction / footer file
-- prepare a list of special files
special_files = {
  INTRO = introduction_filename .. '.md',
  FOOTER = footer_filename .. '.md',
}
-- browse them
for i, j in pairs(special_files) do
  -- read special file if exists
  local special_file_path = specialpath .. '/' .. j
  local special_file = readFile(special_file_path, 'r')
  if special_file and special_file ~= '' then
    print (string.format("-- [%s] %s", display_enable, i))
    local special_file_final_content = replace(markdown(special_file), replacements)
    replacements[i .. '_CONTENT'] = special_file_final_content
  else
    print (string.format("-- [%s] %s", display_disable, i))
  end
end

-- Create about's page if exists
if about_file then
  -- create content
  about_markdown = markdown(about_file)
  about_replaced = replace(about_markdown, replacements)
  -- construct about's page
  about = rope()
  about:push(header)
  about:push(about_replaced)
  about:push(footer)
  -- do replacements
  about_substitutions = getSubstitutions(replacements, {TITLE=languagerc['ABOUT_TITLE']})
  about_content = replace(about:flatten(), about_substitutions)
  -- write changes
  about_file_result = assert(io.open(publicpath .. '/' .. (makeflyrc['ABOUT_FILENAME'] or about_default) .. extension_default, 'wb'))
  about_file_result:write(about_content)
  about_file_result:close()
end

-- Copy static directory content to public path
static_directory = staticpath
copy(static_directory, publicpath)
print (string.format("-- [%s] Folder content copied: %s", display_success, staticpath))

-- Browse DB files
local post_files = {}
dbresult = listing (dbpath, "mk")
if dbresult then
  for k,v in pairs(dbresult) do
    -- parse DB files to get metadata and posts'title
    table.insert(post_files, {file=v, conf=getConfig(v)})
    local co = coroutine.create(function () createPost(v, getConfig(v), header, footer, tagpath, page_article_single, page_tag_link, date_format_default) end)
    table.insert(threads, co)
  end
else
  print (string.format("-- [%s] No DB file(s) found!", display_warning))
end

-- launch dispatcher to create each post and more (copy needed directories/files, etc.)
dispatcher()

-- Create post's index
createPostIndex(post_files, postpath .. '/' .. index_filename, header, footer, replacements, resultextension, themepath .. '/' .. page_posts_name, page_post_element, short_date_format_default, tagpath, page_tag_link, page_article_index, max_post, max_post_lines)

-- Create tag's files: index and each tag's page
createTagIndex(tags, tagpath, index_filename, header, footer, replacements, resultextension, themepath .. '/' .. page_tag_index_name, page_tag_element)

-- Create index
createHomepage(publicpath .. '/' .. index_filename, languagerc['HOME_TITLE'], header, footer)

-- Delete temporary files
for tag, posts in pairs(tags) do
  for i, post in pairs(posts) do
    os.remove(tmppath .. '/' .. post)
  end
end
os.remove(tmppath .. '/' .. 'index.tmp') -- posts that appears on homepage

--[[ END ]]--
return 0

-- vim:expandtab:smartindent:tabstop=2:softtabstop=2:shiftwidth=2:
