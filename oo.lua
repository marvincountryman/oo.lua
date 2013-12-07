--[[
	   Copyright © 2013 Marvin Countryman <marvincountryman@gmail.com>

    This work is free. You can redistribute it and/or modify it under the
    terms of the Do What The Fuck You Want To Public License, Version 2,
    as published by Sam Hocevar. See http://www.wtfpl.net/ for more details.
]]

oo = {}
oo.version = "1.0"
oo.classes = {}

function using(path, as)
	local key
	local fenv 		= getfenv(2)
	local object 	= _G
	local structure = path:split "."

	for i = 1, #structure do
		key = structure[i]

		if object[key] then
			object = object[key]
		else
			error("the type or table " .. path .. " could not be found!")
		end
	end
	if type(object) == "table" then
		if as then
			fenv[as] = object
		else
			if isClass(object) then
				fenv[key] = object
			else
				for k, v in pairs(object) do
					fenv[k] = v
				end
			end
		end
	end
end

function class(name, parent, ...)
	local class 		= {}
	local metamethods 	= {
		"__add",
		"__call",
		"__concat",
		"__div",
		"__le",
		"__lt",
		"__gc",
		"__mod",
		"__mul",
		"__pow",
		"__sub",
		"__tostring",
		"__unm"
	}

	local function createLookupMetamethod(name)
		return function(...)
			local method = class.__parent[name]
			assert(type(method) == "function", class.__type .. " doesn't implement metamethod '" .. name .. "'")
			return method(...)
		end
	end
	local function createNewIndexDetour(index)
		return function(self, key, value)
			if index then
				if type(value) == "function" then
					getfenv(value)["parent"] = class.__parent
				end

				rawset(index, key, value)
			end
		end
	end

	class.static 		= {}

	class.__instance 	= {}
	class.__children 	= {}
	class.__mixins 		= {}
	class.__parent 		= nil
	class.__index 		= class
	class.__type 		= name

	class.__instance.__index = class.__instance

	local mixins 	= {...}
	local parent 	= parent

	if parent == nil and oo.Object then
		parent = oo.Object
	end
	if parent then
		if type(parent) == "string" then
			parent = oo.classes[parent] or error("bad argument #2 to 'class' (expected existing Class object)")
		else
			assert(isClass(parent), "bad argument #2 to 'class' (expected Class object, got " .. type(parent) .. ")")
		end

		setmetatable(class.__instance, parent.__instance)
		setmetatable(class.static, {
			__index = function(self, key)
				return class.__instance[key] or parent.static[key]
			end,
			__newindex = createNewIndexDetour(class.static)
		})

		class.__parent 				= parent
		parent.__children[class] 	= true
	else
		setmetatable(class.static, {
			__index = function(_, key)
				return class.__instance[key]
			end,
			__newindex = createNewIndexDetour(class.static)
		})
	end
	if mixins then
		for _, mixin in pairs(mixins) do
			for key, value in pairs(mixin) do
				if key ~= "included" and key ~= "static" then
					class[key] = value
				end
			end

			for key, value in pairs(mixin.static or {}) do
				class.static[key] = value
			end

			if type(mixin.included) == "function" then mixin:included(class) end
			class.__mixins[mixin] = true
		end
	end

	setmetatable(class, {
		__tostring 	= function() return class.__type end,
		__newindex 	= createNewIndexDetour(class.__instance),
		__index 	= class.static,
		__call 		= function(self, ...)
			local instance 		= setmetatable({class = class}, class.__instance)
			local initializer 	= class[name]

			if not initializer
				and class.__parent
				and class.__parent[class.__parent.__type]
			then
				initializer = class.__parent[class.__parent.__type]
			end

			for _, metamethod in pairs(metamethods) do
				instance[metamethod] = createLookupMetamethod(metamethod)
			end

			if type(initializer) == "function" then
				initializer(self, ...)
			end

			return instance
		end
	})

	oo.classes[name] = class
	return class
end

function isClass(object)
	if
		type(object) == "table" 	and
		object.__instance 	~= nil 	and
		object.__children 	~= nil 	and
		object.__mixins 	~= nil 	and
		object.__index 		~= nil 	and
		object.__type 		~= nil
	then
		return true
	end
end
function isInstanceOf(object_1, object_2)
	return (
		type(object_1) == "table" 		and
		type(object_2) == "table" 		and

		type(object_1.class) == "table" and

		(
			object_2 == object_1.class

				or

			type(object_2.isSubclassOf) == "function" and
			object_1.class:isSubclassOf(object_2)
		)
	)
end
function isSubclassOf(object_1, object_2)
	return (
		type(object_1) 	== "table" and
		type(object_2) 	== "table" and
		type(object_1.__parent) == "table" and

		(
			object_1.__parent == object_2

				or

			type(object_1.__parent.isSubclassOf) == "function" and
			object_1.__:isSubclassOf(object_2)
		)
	)
end

-- Base object
local Object = class "Object"

function Object:__tostring() return self.__type end

function Object:isValid() 					return true end
function Object:isInstanceOf(object) 		return isInstanceOf(self, object) end
function Object.static:isSubclassOf(object) return isSubclassOf(self, object) end

oo.Object = Object