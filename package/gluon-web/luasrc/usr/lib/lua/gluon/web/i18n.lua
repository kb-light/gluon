-- Copyright 2018 Matthias Schiffer <mschiffer@universe-factory.net>
-- Licensed to the public under the Apache License 2.0.

local tparser = require "gluon.web.template.parser"
local util = require "gluon.web.util"
local fs = require "nixio.fs"


local i18ndir = util.libpath() .. "/i18n"


local function i18n_file(lang, pkg)
	return string.format('%s/%s.%s.lmo', i18ndir, pkg, lang)
end

local function no_translation(key)
	return nil
end

local function load_catalog(lang, pkg)
	if pkg then
		local file = i18n_file(lang, pkg)
		local cat = fs.access(file) and tparser.load_catalog(file)

		if cat then return cat end
	end

	return no_translation
end


module "gluon.web.i18n"

function supported(lang)
	return lang == 'en' or fs.access(i18n_file(lang, 'gluon-web'))
end

function load(lang, pkg)
	local _translate = load_catalog(lang, pkg)

	local function translate(key)
		return _translate(key) or key
	end

	local function translatef(key, ...)
		return translate(key):format(...)
	end

	return {
		_translate = _translate,
		translate = translate,
		translatef = translatef,
	}
end
