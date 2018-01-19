local cjson = require 'cjson'

local function exit_error(src, ...)
	io.stderr:write(string.format('*** %s error: %s\n', src, string.format(...)))
	os.exit(1)
end


local has_domains = (os.execute('ls -d "$IPKG_INSTROOT"/lib/gluon/domains/ >/dev/null 2>&1') == 0)


local function load_json(filename)
	local f = assert(io.open(filename))
	local json = cjson.decode(f:read('*a'))
	f:close()
	return json
end


local function get_domains()
	local domains = {}
	local dirs = io.popen("find \"$IPKG_INSTROOT\"/lib/gluon/domains/ -name '*.json'")
	for filename in dirs:lines() do
		local name = string.match(filename, '([^/]+).json$')
		domains[name] = load_json(filename)
	end
	dirs:close()

	if not next(domains) then
		exit_error('site', 'no domain configurations found')
	end

	return domains
end

local site, domain_code, domain, conf


local function merge(a, b)
	local function is_array(t)
		local n = 0
		for k, v in pairs(t) do
			n = n + 1
		end
		return n == #t
	end

	if not b then return a end
	if type(a) ~= type(b) then return b end
	if type(b) ~= 'table' then return b end
	if not next(b) then return a end
	if is_array(a) ~= is_array(b) then return b end

	local m = {}
	for k, v in pairs(a) do
		m[k] = v
	end
	for k, v in pairs(b) do
		m[k] = merge(m[k], v)
	end

	return m
end


function in_site(var)
	return var
end

function in_domain(var)
	return var
end

function this_domain()
	return domain_code
end


local function path_to_string(path)
	return table.concat(path, '/')
end

local function array_to_string(array)
	return '[' .. table.concat(array, ', ') .. ']'
end


local loadpath

local function site_src()
	return 'site.conf'
end

local function domain_src()
	return 'domains/' .. domain_code .. '.conf'
end

local function var_error(path, val, msg)
	if type(val) == 'string' then
		val = string.format('%q', val)
	end

	local src

	if has_domains then
		if loadpath(nil, domain, unpack(path)) ~= nil then
			src = domain_src()
		elseif loadpath(nil, site, unpack(path)) ~= nil then
			src = site_src()
		else
			src = site_src() .. ' / ' .. domain_src()
		end
	else
		src = site_src()
	end

	exit_error(src, 'expected %s to %s, but it is %s', path_to_string(path), msg, tostring(val))
end


function extend(path, c)
	if not path then return nil end

	local p = {unpack(path)}

	for _, e in ipairs(c) do
		p[#p+1] = e
	end
	return p
end

function loadpath(path, base, c, ...)
	if not c or base == nil then
		return base
	end

	if type(base) ~= 'table' then
		if path then
			var_error(path, base, 'be a table')
		else
			return nil
		end
	end

	return loadpath(extend(path, {c}), base[c], ...)
end

local function loadvar(path)
	return loadpath({}, conf, unpack(path))
end

local function check_type(t)
	return function(val)
		return type(val) == t
	end
end

local function check_one_of(array)
	return function(val)
		for _, v in ipairs(array) do
			if v == val then
				return true
			end
		end
		return false
	end
end

function need(path, check, required, msg)
	local val = loadvar(path)
	if required == false and val == nil then
		return nil
	end

	if not check(val) then
		var_error(path, val, msg)
	end

	return val
end

local function need_type(path, type, required, msg)
	return need(path, check_type(type), required, msg)
end


function need_alphanumeric_key(path)
	local val = path[#path]
	-- We don't use character classes like %w here to be independent of the locale
	if not val:match('^[0-9a-zA-Z_]+$') then
		var_error(path, val, 'have a key using only alphanumeric characters and underscores')
	end
end


function need_string(path, required)
	return need_type(path, 'string', required, 'be a string')
end

function need_string_match(path, pat, required)
	local val = need_string(path, required)
	if not val then
		return nil
	end

	if not val:match(pat) then
		var_error(path, val, "match pattern '" .. pat .. "'")
	end

	return val
end

function need_number(path, required)
	return need_type(path, 'number', required, 'be a number')
end

function need_boolean(path, required)
	return need_type(path, 'boolean', required, 'be a boolean')
end

function need_array(path, subcheck, required)
	local val = need_type(path, 'table', required, 'be an array')
	if not val then
		return nil
	end

	if subcheck then
		for i = 1, #val do
			subcheck(extend(path, {i}))
		end
	end

	return val
end

function need_table(path, subcheck, required)
	local val = need_type(path, 'table', required, 'be a table')
	if not val then
		return nil
	end

	if subcheck then
		for k, _ in pairs(val) do
			subcheck(extend(path, {k}))
		end
	end

	return val
end

function need_value(path, value, required)
	return need(path, function(v)
		return v == value
	end, required, 'be ' .. tostring(value))
end

function need_one_of(path, array, required)
	return need(path, check_one_of(array), required, 'be one of the given array ' .. array_to_string(array))
end

function need_string_array(path, required)
	return need_array(path, need_string, required)
end

function need_string_array_match(path, pat, required)
	return need_array(path, function(e) need_string_match(e, pat) end, required)
end

function need_array_of(path, array, required)
	return need_array(path, function(e) need_one_of(e, array) end, required)
end


local check = assert(loadfile())

site = load_json(os.getenv('IPKG_INSTROOT') .. '/lib/gluon/site.json')

if has_domains then
	for k, v in pairs(get_domains()) do
		domain_code = k
		domain = v
		conf = merge(site, domain)
		check()
	end
else
	conf = site
	check()
end
