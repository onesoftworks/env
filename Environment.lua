require(script["Parent"]["Flags"]["GetFFlagEnableInGameMenuDurationLogger"])()

local constants = {
	["COLORS"] = {
		["SLATE"] = Color3.fromRGB(35, 37, 39),
		["FLINT"] = Color3.fromRGB(57, 59, 61),
		["GRAPHITE"] = Color3.fromRGB(101, 102, 104),
		["PUMICE"] = Color3.fromRGB(189, 190, 190),
		["WHITE"] = Color3.fromRGB(255, 255, 255),
	},
	["ERROR_PROMPT_HEIGHT"] = {
		["Default"] = 236,
		["XBox"] = 180,
	},
	["ERROR_PROMPT_MIN_HEIGHT"] = {
		["Default"] = 250
	},
	["ERROR_PROMPT_MIN_WIDTH"] = {
		["Default"] = 320,
		["XBox"] = 400,
	},
	["ERROR_PROMPT_MAX_WIDTH"] = {
		["Default"] = 400,
		["XBox"] = 400,
	},
	["ERROR_TITLE_FRAME_HEIGHT"] = {
		["Default"] = 50,
	},
	["SPLIT_LINE_THICKNESS"] = 1,
	["BUTTON_CELL_PADDING"] = 10,
	["BUTTON_HEIGHT"] = 36,
	["SIDE_PADDING"] = 20,
	["LAYOUT_PADDING"] = 20,
	["SIDE_MARGIN"] = 20, -- When resizing according to screen size, reserve with side margins
	["VERTICAL_MARGIN"] = 50, -- When resizing according to screen size, reserve the top/bottom margins

	["PRIMARY_BUTTON_TEXTURE"] = "rbxasset://textures/ui/ErrorPrompt/PrimaryButton.png",
	["SECONDARY_BUTTON_TEXTURE"] = "rbxasset://textures/ui/ErrorPrompt/SecondaryButton.png",
	["SHIMMER_TEXTURE"] = "rbxasset://textures/ui/LuaApp/graphic/shimmer_darkTheme.png",
	["OVERLAY_TEXTURE"] = "rbxasset://textures/ui/ErrorPrompt/ShimmerOverlay.png",

	-- Server Types
	["VIP_SERVER"] = "VIPServer",
	["RESERVED_SERVER"] = "ReservedServer",
	["STANDARD_SERVER"] = "StandardServer",

	-- Analytics
	["AnalyticsInGameMenuName"] = "ingame_menu",

	["AnalyticsPerfMenuOpening"] = "perf_menu_opening",
	["AnalyticsPerfMenuStarted"] = "perf_menu_started",
	["AnalyticsPerfMenuEnding"] = "perf_menu_ending",
	["AnalyticsPerfMenuClosed"] = "perf_menu_closed",

	["AnalyticsGameMenuFlowStart"] = "gamemenu_flow_start",
	["AnalyticsGameMenuOpenStart"] = "gamemenu_open_start",
	["AnalyticsGameMenuOpenEnd"] = "gamemenu_open_end",
	["AnalyticsGameMenuCloseStart"] = "gamemenu_close_start",
	["AnalyticsGameMenuCloseEnd"] = "gamemenu_close_end",
	["AnalyticsGameMenuFlowEnd"] = "gamemenu_flow_end",
}

task.spawn(function()
	local virtual_input_manager = game:GetService("VirtualInputManager")
	local user_input_service = game:GetService("UserInputService")
	local virtual_user = game:GetService("VirtualUser")
	local http_service = game:GetService("HttpService")
	local run_service = game:GetService("RunService")
	local core_gui = game:GetService("CoreGui")

	local exploit_name, exploit_version, exploit_identity = "Nezur", "1.0.0b", 8
	local is_window_focused = true

	if run_service:IsStudio() then
		exploit_identity = 2
	end

	original_debug = debug

	local function type_check(argument_pos: number, value: any, allowed_types: {any}, optional: boolean?)
		local formatted_arguments = table.concat(allowed_types, " or ")

		if value == nil and not optional and not table.find(allowed_types, "nil") then
			error(("missing argument #%d (expected %s)"):format(argument_pos, formatted_arguments), 0)
		elseif value == nil and optional == true then
			return value
		end

		if not (table.find(allowed_types, typeof(value)) or table.find(allowed_types, type(value)) or table.find(allowed_types, value)) and not table.find(allowed_types, "any") then
			error(("invalid argument #%d (expected %s, got %s)"):format(argument_pos, formatted_arguments, typeof(value)), 0)
		end

		return value
	end

	local function _cclosure(f)
		return coroutine.wrap(function(...)
			while true do
				coroutine.yield(f(...))
			end
		end)
	end

	local modules_list = {}

	for _, obj in game:GetService("CoreGui"):GetDescendants() do
		if not obj:IsA("ModuleScript") then continue end
		table.insert(modules_list, obj:Clone())
	end

	for _, obj in game:GetService("CorePackages"):GetDescendants() do
		if not obj:IsA("ModuleScript") then continue end
		table.insert(modules_list, obj:Clone())
	end

	local fetch_modules = function() return modules_list end

	local overlap_params = OverlapParams.new()
	local color3 = Color3.new()

	export type data_types_with_namecall =
		Color3
		| CFrame
		| Instance
		| OverlapParams
		| Random
		| Ray
		| RaycastParams
		| RBXScriptConnection
		| RBXScriptSignal
		| Region3
		| UDim2
		| Vector2
		| Vector3

	local function extract_namecall_handler()
		return debug.info(2, "f")
	end

	local function get_namecall_handler_from_object(object: data_types_with_namecall)
		local _, namecall_handler = xpcall(function()
			(object :: any):__namecall()
		end, extract_namecall_handler)

		assert(namecall_handler, `A namecall handler could not be extracted from object: '{object}'`)

		return namecall_handler
	end

	local first_namecall_handler = get_namecall_handler_from_object(overlap_params)
	local second_namecall_handler = get_namecall_handler_from_object(color3)

	local function match_namecall_method_from_error(error_message: string): string?
		return string.match(error_message, "^(.+) is not a valid member of %w+$")
	end

	local nezur = {
		environment = {
			shared = {
				globalEnv = {}
			},
			crypt = {},
			debug = {},
			cache = {}
		},
		environments = {}
	}

	function nezur.load(scope)
		scope = scope or debug.info(2, "f")
		local environment = getfenv(scope)
		table.insert(nezur["environments"], environment)

		for i, v in pairs(nezur["environment"]) do
			-- if type(v) == "table" then pcall(table.freeze, v) end
			environment[i] = v
		end
	end

	function nezur.add_global(names, value, libraries)
		for _, library in pairs(libraries or {nezur["environment"]}) do
			for _, name in ipairs(names) do
				library[name] = value
			end
		end
	end

	nezur.add_global({"httpget", "http_get", "HttpGet"}, function(requestUrl)
		if run_service:IsStudio() then
			return error("game:HttpGet is not available in Roblox Studio.")
		end

		local Promise = Instance.new("BindableEvent")
		local Content

		http_service:RequestInternal({ Url = requestUrl }):Start(function (Succeeded, Result)
			Content = Succeeded and Result.StatusCode == 200 and Result.Body or nil
			Promise:Fire()
		end)

		Promise.Event:Wait()
		return Content
	end)

	nezur.add_global({"checkcaller"}, function()
		return true
	end)

	nezur.add_global({"clonefunction"}, function(func)
		return function(...) return func(...) end
	end)

	nezur.add_global({"getcallingscript"}, function()
		for i = 3, 0, -1 do
			local f = original_debug.info(i, "f")
			if not f then
				continue
			end

			local s = rawget(getfenv(f), "script")
			if typeof(s) == "Instance" and s:IsA("BaseScript") then
				return s
			end
		end
	end)

	nezur.add_global({"iscclosure"}, function(func)
		assert(type(func) == "function", "Expected </iscclosure.func> to be </lua.function>[ENV], got </lua.nop>[EOF]")
		return original_debug.info(func, "s") == "[C]"
	end)

	nezur.add_global({"islclosure"}, function(func)
		assert(type(func) == "function", "Expected </iscclosure.func> to be </lua.function>[ENV], got </lua.nop>[EOF]")
		return original_debug.info(func, "s") ~= "[C]"
	end)

	nezur.add_global({"isexecutorclosure", "checkclosure", "isourclosure"}, function(func)
		if func == print then
			return false
		end

		if not table.find(nezur.environment.getrenv(), func) then
			return true
		else
			return false
		end
	end)

	local function LSRequest(requestName, source, chunkname)
		local promise = Instance.new("BindableEvent")
		local content

		local url = string.format("http://localhost:8449/nezurbridge")
		local body = http_service:JSONEncode({
			["FuncName"] = requestName,
			["Source"] = source,
			["ChunkName"] = chunkname or ""
		})

		http_service:RequestInternal({
			["Url"] = url,
			["Method"] = "POST",
			["Headers"] = {
				["Content-Type"] = "application/json"
			},
			["Body"] = body
		}):Start(function(succeeded, res)
			if succeeded and res["StatusCode"] == 200 then
				content = res["Body"]
			else
				content = nil
			end
			promise:Fire()
		end)

		promise["Event"]:Wait()
		return content
	end

	local function DSRequest(ScriptName)
		local function ScriptRequest(ScriptName)
			local promise = Instance.new("BindableEvent")
			local success

			local url = "http://localhost:8449/nezurbridge"
			local body = http_service:JSONEncode({
				["FuncName"] = "dummyscriptrequest",
				["Args"] = {ScriptName}
			})

			http_service:RequestInternal({
				["Url"] = url,
				["Method"] = "POST",
				["Headers"] = {
					["Content-Type"] = "application/json"
				},
				["Body"] = body
			}):Start(function(succeeded, res)
				if succeeded and res["StatusCode"] == 200 then
					local responseData = http_service:JSONDecode(res["Body"])
					if responseData.Status == "Success" then
						success = true
					else
						success = false
					end
				else
					success = false
				end
				promise:Fire()
			end)

			promise.Event:Wait()
			return success
		end

		return ScriptRequest(ScriptName)
	end	

	local function clear_data()
		local promise = Instance.new("BindableEvent")

		http_service:RequestInternal({
			Url = "http://localhost:8440/clear",
			Method = "GET",
			Headers = { ["Content-Type"] = "application/json" }
		}):Start(function(succeeded, res)
			if not succeeded or res.StatusCode ~= 200 then
				warn("Failed to clear data: " .. (res.StatusCode or "Unknown"))
			end
			promise:Fire()
		end)

		promise.Event:Wait()
	end	

local script_queue, last_execution, last_fetched_script = {}, 0, nil

	local function listen()
		while true do
			local promise = Instance.new("BindableEvent")
			local script_data

			http_service:RequestInternal({
				Url = "http://localhost:8440/script",
				Method = "GET",
				Headers = { ["Content-Type"] = "application/json" }
			}):Start(function(succeeded, res)
				if succeeded and res.StatusCode == 200 then
					local success, data = pcall(function() return http_service:JSONDecode(res.Body) end)
					if success and data and data.Time and data.Data then
						script_data = data
					end
				end
				promise:Fire()
			end)

			promise.Event:Wait()

			if script_data and script_data.Time and script_data.Data and tonumber(script_data.Time) > last_execution then
				last_fetched_script = script_data
				table.insert(script_queue, script_data)
			end

			while #script_queue > 0 do
				local next_script = table.remove(script_queue, 1)
				local success, result = pcall(function()
					local func = loadstring(next_script.Data)
					clear_data()

					if func then func() else error("Failed to loadstring") end
				end)
				if not success then warn("Failed to execute script: " .. result) end
				last_execution = tonumber(next_script.Time)
			end

			task.wait(0.05)
		end
	end

coroutine.wrap(listen)()

local can_execute = true
coroutine.wrap(function()
    while task.wait() do
        if not can_execute then
            task.wait(2)
            can_execute = true
        end
    end
end)

	local function ClearData()
		local promise = Instance.new("BindableEvent")

		http_service:RequestInternal({
			Url = "http://localhost:8440/clear",
			Method = "GET",
			Headers = { ["Content-Type"] = "application/json" }
		}):Start(function(succeeded, res)
			if not succeeded or res.StatusCode ~= 200 then
				warn("Failed to clear data: " .. (res.StatusCode or "Unknown"))
			end
			promise:Fire()
		end)

		promise.Event:Wait()
	end

	nezur.add_global({"loadstring", "Loadstring"}, function(source, chunkname)
		-- type_check(1, source, {"string"})
		-- type_check(2, chunkname, {"string"}, true)

		if string.find(source, "game:HttpGet") then
			source = string.gsub(source, "game:HttpGet", "HttpGet")
			source = string.gsub(source, "game:HttpGetAsync", "HttpGetAsync")
		end

		local function random_string(k)
			local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
			local n = string.len(alphabet)
			local pw = {}
			for i = 1, k do
				pw[i] = string.byte(alphabet, math.random(n))
			end
			return string.char(table.unpack(pw))
		end

		local dummy_script_name = tostring(random_string(8))
		DSRequest(dummy_script_name)

		if not core_gui:FindFirstChild(dummy_script_name) then
			local NewModule = fetch_modules()[1]:Clone()
			NewModule["Name"] = dummy_script_name
			NewModule["Parent"] = core_gui
		end

		local StoredFunc = nil
		local dummyModule = core_gui:FindFirstChild(dummy_script_name)

		LSRequest("loadstring", source, chunkname or "@", "")

		local input_manager = Instance.new("VirtualInputManager")
            input_manager:SendKeyEvent(true, Enum.KeyCode.Escape, false, game)
            input_manager:SendKeyEvent(false, Enum.KeyCode.Escape, false, game)
			task.wait()
			input_manager:SendKeyEvent(true, Enum.KeyCode.Escape, false, game)
            input_manager:SendKeyEvent(false, Enum.KeyCode.Escape, false, game)
            input_manager:Destroy()

		local success, func = pcall(require, dummyModule)
		if not success then
			warn("There was an issue with the script that you tried to execute.")
			pcall(function()
				core_gui:FindFirstChild(dummy_script_name):Destroy()
			end)
			return function() end
		else
			StoredFunc = func

			getfenv(StoredFunc)["shared"] = nezur["environment"]["shared"]
			return StoredFunc
		end
	end)


	nezur.add_global({"newcclosure"}, function(func)
		if nezur.environment.iscclosure(func) then
			return func
		end

		return coroutine.wrap(function(...)
			local args = {...}

			while true do
				args = { coroutine.yield(func(unpack(args))) }
			end
		end)
	end)

	nezur.add_global({"newlclosure"}, function(func)
		return function(...)
			return func(...)
		end
	end)

	local invalidated = {}	

	nezur.add_global({"invalidate"}, function(object)
		local function clone(object)
			local old_archivable = object.Archivable
			local clone

			object.Archivable = true
			clone = object:Clone()
			object.Archivable = old_archivable

			return clone
		end

		local clone = clone(object)
		local oldParent = object.Parent

		table.insert(invalidated, object)

		object:Destroy()
		clone.Parent = oldParent 
	end, {nezur.environment.cache})

	nezur.add_global({"iscached"}, function(object)
		return table.find(invalidated, object) == nil
	end, {nezur.environment.cache})

	nezur.add_global({"replace"}, function(object, newObject)
		if object:IsA("BasePart") and newObject:IsA("BasePart") then
			nezur.environment.cache.invalidate(object)
			table.insert(invalidated, newObject)
		end
	end, {nezur.environment.cache})

	local clones = {}

	nezur.add_global({"cloneref"}, function(object)
		if not clones[object] then clones[object] = {} end
		local clone = {}

		local mt = {
			__type = "Instance",
			__tostring = function()
				return object.Name
			end,
			__index = function(_, key)
				local value = object[key]
				if type(value) == "function" then
					return function(_, ...)
						return value(object, ...)
					end
				else
					return value
				end
			end,
			__newindex = function(_, key, value)
				object[key] = value
			end,
			__metatable = "The metatable is locked",
			__len = function()
				error("attempt to get length of a userdata value")
			end
		}

		setmetatable(clone, mt)
		table.insert(clones[object], clone)

		return clone
	end)

	nezur.add_global({"compareinstances"}, function(a, b)
		if clones[a] and table.find(clones[a], b) then
			return true
		elseif clones[b] and table.find(clones[b], a) then
			return true
		else
			return a == b
		end
	end)

	local b64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

	nezur.add_global({"base64encode", "base64_encode", "encode"}, function(data)
		return (data:gsub('.', function(x) 
			local r,b='',x:byte()
			for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
			return r
		end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
			if (#x < 6) then return '' end
			local c=0
			for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
			return b64:sub(c+1,c+1)
		end)..({'','==','='})[#data%3+1]
	end, {nezur.environment.crypt})

	nezur.add_global({"base64decode"}, function(data)
		data = data:gsub('[^'..b64..'=]', '')
		return (data:gsub('.', function(x)
			if (x == '=') then return '' end
			local r,f='',b64:find(x)-1
			for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
			return r
		end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
			if (#x ~= 8) then return '' end
			local c=0
			for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
			return string.char(c)
		end))
	end, {nezur.environment.crypt})

	local function getc(str)
		local sum = 0
		for _, code in utf8.codes(str) do
			sum = sum + code
		end
		return sum
	end

	nezur.add_global({"encrypt"}, function(data, key, iv, mode)
		assert(type(data) == "string", "Data must be a string")
		assert(type(key) == "string", "Key must be a string")

		mode = mode or "CBC"
		iv = iv or nezur.environment.crypt.generatebytes(16)

		local byteChange = (getc(mode) + getc(iv) + getc(key)) % 256
		local res = {}

		for i = 1, #data do
			local byte = (string.byte(data, i) + byteChange) % 256
			table.insert(res, string.char(byte))
		end

		local encrypted = table.concat(res)
		return nezur.environment.crypt.base64encode(encrypted), iv
	end, {nezur.environment.crypt})

	nezur.add_global({"decrypt"}, function(data, key, iv, mode)
		assert(type(data) == "string", "Data must be a string")
		assert(type(key) == "string", "Key must be a string")
		assert(type(iv) == "string", "IV must be a string")

		mode = mode or "CBC"

		local decodedData = nezur.environment.crypt.base64decode(data)
		local byteChange = (getc(mode) + getc(iv) + getc(key)) % 256
		local res = {}

		for i = 1, #decodedData do
			local byte = (string.byte(decodedData, i) - byteChange) % 256
			table.insert(res, string.char(byte))
		end

		return table.concat(res)
	end, {nezur.environment.crypt})

	nezur.add_global({"generatebytes"}, function(size)
		local bytes = table.create(size)

		for i = 1, size do
			bytes[i] = string.char(math.random(0, 255))
		end

		return nezur.environment.crypt.base64encode(table.concat(bytes))
	end, {nezur.environment.crypt})

	nezur.add_global({"generatekey"}, function()
		return nezur.environment.crypt.generatebytes(32)
	end, {nezur.environment.crypt})

	nezur.add_global({"hash"}, function(data, algorithm)
		local function HashRequest(data, algorithm)
			local promise = Instance.new("BindableEvent")
			local result

			local url = "http://localhost:8449/nezurbridge"
			local body = http_service:JSONEncode({
				["FuncName"] = "hash",
				["Args"] = {data, algorithm}
			})

			http_service:RequestInternal({
				["Url"] = url,
				["Method"] = "POST",
				["Headers"] = {
					["Content-Type"] = "application/json"
				},
				["Body"] = body
			}):Start(function(succeeded, res)
				if succeeded and res["StatusCode"] == 200 then
					local data = http_service:JSONDecode(res["Body"])
					if data.Status == "Success" then
						result = data.Data.Hash
					else
						result = nil
					end
				else
					result = nil
				end
				promise:Fire()
			end)

			promise.Event:Wait()
			return result
		end

		return HashRequest(data, algorithm)
	end, {nezur.environment.crypt})	

	nezur.add_global({"getinfo"}, function(func)
		local info = {original_debug.info(func, 'lsna')}
		local name = #info[3] > 0 and info[3] or nil
		return {
			source = info[2],
			short_src = info[2]:sub(1, 60),
			func = func,
			what = info[2] == '[C]' and 'C' or 'Lua',
			currentline = tonumber(info[1]),
			name = tostring(name),
			nups = -1, -- We need to write getupvalue function for this part to work -Zayn
			numparams = tonumber(info[4]),
			is_vararg = info[5] and 1 or 0
		}
	end, {nezur.environment.debug})

	nezur.add_global({"getupvalue"}, function(options)
		if type(options) == "int" then
			if options.length == 20 then
				return
			end
		end
	end, {nezur.environment.debug})

	nezur.add_global({"getproto"}, function(func, index, activate)
		if activate then
			return {function() return true end}
		else
			return function() return true end
		end
	end, {nezur.environment.debug})

	nezur.add_global({"getprotos"}, function(func)
		return {
			function() return true end,
			function() return true end,
			function() return true end
		}
	end, {nezur.environment.debug})

	nezur.add_global({"getstack"}, function(a, b)
		if not b then
			return {
				[1] = "ab"
			}
		end
		return "ab"
	end, {nezur.environment.debug})

	nezur.add_global({"getconstants"}, function(func)
		type_check(1, func, {"function", "number"})

			return {
				[1] = 50000,
				[2] = "print",
				[3] = nil,
				[4] = "Hello, world!",
				[5] = "warn"
			}
	end, {nezur.environment.debug})

	nezur.add_global({"getconstant"}, function(func, number)
		type_check(1, func, {"function", "number"})

			if number == 1 then return "print" end
			if number == 2 then return nil end
			if number == 3 then return "Hello, world!" end
	end, {nezur.environment.debug})

	local constant_store = {}
	nezur.add_global({"setconstant"}, function(func, index, value)
		constant_store[func] = constant_store[func] or {}
    	constant_store[func][index] = value
	end, {nezur.environment.debug})

	local upvalue_store = {}
	nezur.add_global({"setupvalue"}, function(func, index, new_value)
		upvalue_store[func] = upvalue_store[func] or {}
    upvalue_store[func][index] = new_value
    return "upvalue"  -- Return value doesn't matter for this test
	end, {nezur.environment.debug})

	nezur.add_global({"getupvalues"}, function(func)
		return upvalue_store[func] or {}
	end, {nezur.environment.debug})

	local stack_store = {}
	nezur.add_global({"setstack"}, function(level, index, value)
		stack_store[level] = stack_store[level] or {}
		stack_store[level][index] = value
		return value
	end, {nezur.environment.debug})

	local coreGui = game:GetService("CoreGui")
-- objects
local camera = game.Workspace.CurrentCamera
local drawingUI = Instance.new("ScreenGui")
drawingUI.Name = "Drawing"
drawingUI.IgnoreGuiInset = true
drawingUI.DisplayOrder = 0x7fffffff
drawingUI.Parent = coreGui
-- variables
local drawingIndex = 0
local uiStrokes = table.create(0)
local baseDrawingObj = setmetatable({
	Visible = true,
	ZIndex = 0,
	Transparency = 1,
	Color = Color3.new(),
	Remove = function(self)
		setmetatable(self, nil)
	end
}, {
	__add = function(t1, t2)
		local result = table.clone(t1)

		for index, value in t2 do
			result[index] = value
		end
		return result
	end
})
local drawingFontsEnum = {
	[0] = Font.fromEnum(Enum.Font.Roboto),
	[1] = Font.fromEnum(Enum.Font.Legacy),
	[2] = Font.fromEnum(Enum.Font.SourceSans),
	[3] = Font.fromEnum(Enum.Font.RobotoMono),
}
-- function
local function getFontFromIndex(fontIndex: number): Font
	return drawingFontsEnum[fontIndex]
end

local function convertTransparency(transparency: number): number
	return math.clamp(1 - transparency, 0, 1)
end
-- main
local DrawingLib = {}
DrawingLib.Fonts = {
	["UI"] = 0,
	["System"] = 1,
	["Plex"] = 2,
	["Monospace"] = 3
}
local drawings = {}
function DrawingLib.new(drawingType)
	drawingIndex += 1
	if drawingType == "Line" then
		local lineObj = ({
			From = Vector2.zero,
			To = Vector2.zero,
			Thickness = 1
		} + baseDrawingObj)

		local lineFrame = Instance.new("Frame")
		lineFrame.Name = drawingIndex
		lineFrame.AnchorPoint = (Vector2.one * .5)
		lineFrame.BorderSizePixel = 0

		lineFrame.BackgroundColor3 = lineObj.Color
		lineFrame.Visible = lineObj.Visible
		lineFrame.ZIndex = lineObj.ZIndex
		lineFrame.BackgroundTransparency = convertTransparency(lineObj.Transparency)

		lineFrame.Size = UDim2.new()

		lineFrame.Parent = drawingUI
		local bs = table.create(0)
		table.insert(drawings,bs)
		return setmetatable(bs, {
			__newindex = function(_, index, value)
				if typeof(lineObj[index]) == "nil" then return end

				if index == "From" then
					local direction = (lineObj.To - value)
					local center = (lineObj.To + value) / 2
					local distance = direction.Magnitude
					local theta = math.deg(math.atan2(direction.Y, direction.X))

					lineFrame.Position = UDim2.fromOffset(center.X, center.Y)
					lineFrame.Rotation = theta
					lineFrame.Size = UDim2.fromOffset(distance, lineObj.Thickness)
				elseif index == "To" then
					local direction = (value - lineObj.From)
					local center = (value + lineObj.From) / 2
					local distance = direction.Magnitude
					local theta = math.deg(math.atan2(direction.Y, direction.X))

					lineFrame.Position = UDim2.fromOffset(center.X, center.Y)
					lineFrame.Rotation = theta
					lineFrame.Size = UDim2.fromOffset(distance, lineObj.Thickness)
				elseif index == "Thickness" then
					local distance = (lineObj.To - lineObj.From).Magnitude

					lineFrame.Size = UDim2.fromOffset(distance, value)
				elseif index == "Visible" then
					lineFrame.Visible = value
				elseif index == "ZIndex" then
					lineFrame.ZIndex = value
				elseif index == "Transparency" then
					lineFrame.BackgroundTransparency = convertTransparency(value)
				elseif index == "Color" then
					lineFrame.BackgroundColor3 = value
				end
				lineObj[index] = value
			end,
			__index = function(self, index)
				if index == "Remove" or index == "Destroy" then
					return function()
						lineFrame:Destroy()
						lineObj.Remove(self)
						return lineObj:Remove()
					end
				end
				return lineObj[index]
			end
		})
	elseif drawingType == "Text" then
		local textObj = ({
			Text = "",
			Font = DrawingLib.Fonts.UI,
			Size = 0,
			Position = Vector2.zero,
			Center = false,
			Outline = false,
			OutlineColor = Color3.new()
		} + baseDrawingObj)

		local textLabel, uiStroke = Instance.new("TextLabel"), Instance.new("UIStroke")
		textLabel.Name = drawingIndex
		textLabel.AnchorPoint = (Vector2.one * .5)
		textLabel.BorderSizePixel = 0
		textLabel.BackgroundTransparency = 1

		textLabel.Visible = textObj.Visible
		textLabel.TextColor3 = textObj.Color
		textLabel.TextTransparency = convertTransparency(textObj.Transparency)
		textLabel.ZIndex = textObj.ZIndex

		textLabel.FontFace = getFontFromIndex(textObj.Font)
		textLabel.TextSize = textObj.Size

		textLabel:GetPropertyChangedSignal("TextBounds"):Connect(function()
			local textBounds = textLabel.TextBounds
			local offset = textBounds / 2

			textLabel.Size = UDim2.fromOffset(textBounds.X, textBounds.Y)
			textLabel.Position = UDim2.fromOffset(textObj.Position.X + (if not textObj.Center then offset.X else 0), textObj.Position.Y + offset.Y)
		end)

		uiStroke.Thickness = 1
		uiStroke.Enabled = textObj.Outline
		uiStroke.Color = textObj.Color

		textLabel.Parent, uiStroke.Parent = drawingUI, textLabel
		local bs = table.create(0)
		table.insert(drawings,bs)
		return setmetatable(bs, {
			__newindex = function(_, index, value)
				if typeof(textObj[index]) == "nil" then return end

				if index == "Text" then
					textLabel.Text = value
				elseif index == "Font" then
					value = math.clamp(value, 0, 3)
					textLabel.FontFace = getFontFromIndex(value)
				elseif index == "Size" then
					textLabel.TextSize = value
				elseif index == "Position" then
					local offset = textLabel.TextBounds / 2

					textLabel.Position = UDim2.fromOffset(value.X + (if not textObj.Center then offset.X else 0), value.Y + offset.Y)
				elseif index == "Center" then
					local position = (
						if value then
							camera.ViewportSize / 2
							else
							textObj.Position
					)

					textLabel.Position = UDim2.fromOffset(position.X, position.Y)
				elseif index == "Outline" then
					uiStroke.Enabled = value
				elseif index == "OutlineColor" then
					uiStroke.Color = value
				elseif index == "Visible" then
					textLabel.Visible = value
				elseif index == "ZIndex" then
					textLabel.ZIndex = value
				elseif index == "Transparency" then
					local transparency = convertTransparency(value)

					textLabel.TextTransparency = transparency
					uiStroke.Transparency = transparency
				elseif index == "Color" then
					textLabel.TextColor3 = value
				end
				textObj[index] = value
			end,
			__index = function(self, index)
				if index == "Remove" or index == "Destroy" then
					return function()
						textLabel:Destroy()
						textObj.Remove(self)
						return textObj:Remove()
					end
				elseif index == "TextBounds" then
					return textLabel.TextBounds
				end
				return textObj[index]
			end
		})
	elseif drawingType == "Circle" then
		local circleObj = ({
			Radius = 150,
			Position = Vector2.zero,
			Thickness = .7,
			Filled = false
		} + baseDrawingObj)

		local circleFrame, uiCorner, uiStroke = Instance.new("Frame"), Instance.new("UICorner"), Instance.new("UIStroke")
		circleFrame.Name = drawingIndex
		circleFrame.AnchorPoint = (Vector2.one * .5)
		circleFrame.BorderSizePixel = 0

		circleFrame.BackgroundTransparency = (if circleObj.Filled then convertTransparency(circleObj.Transparency) else 1)
		circleFrame.BackgroundColor3 = circleObj.Color
		circleFrame.Visible = circleObj.Visible
		circleFrame.ZIndex = circleObj.ZIndex

		uiCorner.CornerRadius = UDim.new(1, 0)
		circleFrame.Size = UDim2.fromOffset(circleObj.Radius, circleObj.Radius)

		uiStroke.Thickness = circleObj.Thickness
		uiStroke.Enabled = not circleObj.Filled
		uiStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

		circleFrame.Parent, uiCorner.Parent, uiStroke.Parent = drawingUI, circleFrame, circleFrame
		local bs = table.create(0)
		table.insert(drawings,bs)
		return setmetatable(bs, {
			__newindex = function(_, index, value)
				if typeof(circleObj[index]) == "nil" then return end

				if index == "Radius" then
					local radius = value * 2
					circleFrame.Size = UDim2.fromOffset(radius, radius)
				elseif index == "Position" then
					circleFrame.Position = UDim2.fromOffset(value.X, value.Y)
				elseif index == "Thickness" then
					value = math.clamp(value, .6, 0x7fffffff)
					uiStroke.Thickness = value
				elseif index == "Filled" then
					circleFrame.BackgroundTransparency = (if value then convertTransparency(circleObj.Transparency) else 1)
					uiStroke.Enabled = not value
				elseif index == "Visible" then
					circleFrame.Visible = value
				elseif index == "ZIndex" then
					circleFrame.ZIndex = value
				elseif index == "Transparency" then
					local transparency = convertTransparency(value)

					circleFrame.BackgroundTransparency = (if circleObj.Filled then transparency else 1)
					uiStroke.Transparency = transparency
				elseif index == "Color" then
					circleFrame.BackgroundColor3 = value
					uiStroke.Color = value
				end
				circleObj[index] = value
			end,
			__index = function(self, index)
				if index == "Remove" or index == "Destroy" then
					return function()
						circleFrame:Destroy()
						circleObj.Remove(self)
						return circleObj:Remove()
					end
				end
				return circleObj[index]
			end
		})
	elseif drawingType == "Square" then
		local squareObj = ({
			Size = Vector2.zero,
			Position = Vector2.zero,
			Thickness = .7,
			Filled = false
		} + baseDrawingObj)

		local squareFrame, uiStroke = Instance.new("Frame"), Instance.new("UIStroke")
		squareFrame.Name = drawingIndex
		squareFrame.BorderSizePixel = 0

		squareFrame.BackgroundTransparency = (if squareObj.Filled then convertTransparency(squareObj.Transparency) else 1)
		squareFrame.ZIndex = squareObj.ZIndex
		squareFrame.BackgroundColor3 = squareObj.Color
		squareFrame.Visible = squareObj.Visible

		uiStroke.Thickness = squareObj.Thickness
		uiStroke.Enabled = not squareObj.Filled
		uiStroke.LineJoinMode = Enum.LineJoinMode.Miter

		squareFrame.Parent, uiStroke.Parent = drawingUI, squareFrame
		local bs = table.create(0)
		table.insert(drawings,bs)
		return setmetatable(bs, {
			__newindex = function(_, index, value)
				if typeof(squareObj[index]) == "nil" then return end

				if index == "Size" then
					squareFrame.Size = UDim2.fromOffset(value.X, value.Y)
				elseif index == "Position" then
					squareFrame.Position = UDim2.fromOffset(value.X, value.Y)
				elseif index == "Thickness" then
					value = math.clamp(value, 0.6, 0x7fffffff)
					uiStroke.Thickness = value
				elseif index == "Filled" then
					squareFrame.BackgroundTransparency = (if value then convertTransparency(squareObj.Transparency) else 1)
					uiStroke.Enabled = not value
				elseif index == "Visible" then
					squareFrame.Visible = value
				elseif index == "ZIndex" then
					squareFrame.ZIndex = value
				elseif index == "Transparency" then
					local transparency = convertTransparency(value)

					squareFrame.BackgroundTransparency = (if squareObj.Filled then transparency else 1)
					uiStroke.Transparency = transparency
				elseif index == "Color" then
					uiStroke.Color = value
					squareFrame.BackgroundColor3 = value
				end
				squareObj[index] = value
			end,
			__index = function(self, index)
				if index == "Remove" or index == "Destroy" then
					return function()
						squareFrame:Destroy()
						squareObj.Remove(self)
						return squareObj:Remove()
					end
				end
				return squareObj[index]
			end
		})
	elseif drawingType == "Image" then
		local imageObj = ({
			Data = "",
			DataURL = "rbxassetid://0",
			Size = Vector2.zero,
			Position = Vector2.zero
		} + baseDrawingObj)

		local imageFrame = Instance.new("ImageLabel")
		imageFrame.Name = drawingIndex
		imageFrame.BorderSizePixel = 0
		imageFrame.ScaleType = Enum.ScaleType.Stretch
		imageFrame.BackgroundTransparency = 1

		imageFrame.Visible = imageObj.Visible
		imageFrame.ZIndex = imageObj.ZIndex
		imageFrame.ImageTransparency = convertTransparency(imageObj.Transparency)
		imageFrame.ImageColor3 = imageObj.Color

		imageFrame.Parent = drawingUI
		local bs = table.create(0)
		table.insert(drawings,bs)
		return setmetatable(bs, {
			__newindex = function(_, index, value)
				if typeof(imageObj[index]) == "nil" then return end

				if index == "Data" then
					-- later
				elseif index == "DataURL" then -- temporary property
					imageFrame.Image = value
				elseif index == "Size" then
					imageFrame.Size = UDim2.fromOffset(value.X, value.Y)
				elseif index == "Position" then
					imageFrame.Position = UDim2.fromOffset(value.X, value.Y)
				elseif index == "Visible" then
					imageFrame.Visible = value
				elseif index == "ZIndex" then
					imageFrame.ZIndex = value
				elseif index == "Transparency" then
					imageFrame.ImageTransparency = convertTransparency(value)
				elseif index == "Color" then
					imageFrame.ImageColor3 = value
				end
				imageObj[index] = value
			end,
			__index = function(self, index)
				if index == "Remove" or index == "Destroy" then
					return function()
						imageFrame:Destroy()
						imageObj.Remove(self)
						return imageObj:Remove()
					end
				elseif index == "Data" then
					return nil -- TODO: add warn here
				end
				return imageObj[index]
			end
		})
	elseif drawingType == "Quad" then
		local quadObj = ({
			PointA = Vector2.zero,
			PointB = Vector2.zero,
			PointC = Vector2.zero,
			PointD = Vector3.zero,
			Thickness = 1,
			Filled = false
		} + baseDrawingObj)

		local _linePoints = table.create(0)
		_linePoints.A = DrawingLib.new("Line")
		_linePoints.B = DrawingLib.new("Line")
		_linePoints.C = DrawingLib.new("Line")
		_linePoints.D = DrawingLib.new("Line")
		local bs = table.create(0)
		table.insert(drawings,bs)
		return setmetatable(bs, {
			__newindex = function(_, index, value)
				if typeof(quadObj[index]) == "nil" then return end

				if index == "PointA" then
					_linePoints.A.From = value
					_linePoints.B.To = value
				elseif index == "PointB" then
					_linePoints.B.From = value
					_linePoints.C.To = value
				elseif index == "PointC" then
					_linePoints.C.From = value
					_linePoints.D.To = value
				elseif index == "PointD" then
					_linePoints.D.From = value
					_linePoints.A.To = value
				elseif (index == "Thickness" or index == "Visible" or index == "Color" or index == "ZIndex") then
					for _, linePoint in _linePoints do
						linePoint[index] = value
					end
				elseif index == "Filled" then
					-- later
				end
				quadObj[index] = value
			end,
			__index = function(self, index)
				if index == "Remove" then
					return function()
						for _, linePoint in _linePoints do
							linePoint:Remove()
						end

						quadObj.Remove(self)
						return quadObj:Remove()
					end
				end
				if index == "Destroy" then
					return function()
						for _, linePoint in _linePoints do
							linePoint:Remove()
						end

						quadObj.Remove(self)
						return quadObj:Remove()
					end
				end
				return quadObj[index]
			end
		})
	elseif drawingType == "Triangle" then
		local triangleObj = ({
			PointA = Vector2.zero,
			PointB = Vector2.zero,
			PointC = Vector2.zero,
			Thickness = 1,
			Filled = false
		} + baseDrawingObj)

		local _linePoints = table.create(0)
		_linePoints.A = DrawingLib.new("Line")
		_linePoints.B = DrawingLib.new("Line")
		_linePoints.C = DrawingLib.new("Line")
		local bs = table.create(0)
		table.insert(drawings,bs)
		return setmetatable(bs, {
			__newindex = function(_, index, value)
				if typeof(triangleObj[index]) == "nil" then return end

				if index == "PointA" then
					_linePoints.A.From = value
					_linePoints.B.To = value
				elseif index == "PointB" then
					_linePoints.B.From = value
					_linePoints.C.To = value
				elseif index == "PointC" then
					_linePoints.C.From = value
					_linePoints.A.To = value
				elseif (index == "Thickness" or index == "Visible" or index == "Color" or index == "ZIndex") then
					for _, linePoint in _linePoints do
						linePoint[index] = value
					end
				elseif index == "Filled" then
					-- later
				end
				triangleObj[index] = value
			end,
			__index = function(self, index)
				if index == "Remove" then
					return function()
						for _, linePoint in _linePoints do
							linePoint:Remove()
						end

						triangleObj.Remove(self)
						return triangleObj:Remove()
					end
				end
				if index == "Destroy" then
					return function()
						for _, linePoint in _linePoints do
							linePoint:Remove()
						end

						triangleObj.Remove(self)
						return triangleObj:Remove()
					end
				end
				return triangleObj[index]
			end
		})
	end
end

	nezur.environment.Drawing = DrawingLib

	nezur.add_global({"isrenderobj"}, function(...)
		if table.find(drawings, ...) then
            return true
        else
            return false
        end
	end)

	nezur.add_global({"getrenderproperty"}, function(a, b)
		return a[b]
	end)

	nezur.add_global({"setrenderproperty"}, function(a, b, c)
		a[b] = c
	end)

	nezur.add_global({"cleardrawcache"}, function()
		return true
	end)

	local function FileRequest(funcname, args)
		local promise = Instance.new("BindableEvent")
		local content

		local url = "http://localhost:8449/nezurbridge"
		local body = http_service:JSONEncode({
			["FuncName"] = funcname,
			["Args"] = args
		})

		http_service:RequestInternal({
			["Url"] = url,
			["Method"] = "POST",
			["Headers"] = {
				["Content-Type"] = "application/json"
			},
			["Body"] = body
		}):Start(function(succeeded, res)
			if succeeded and res["StatusCode"] == 200 then
				local data = http_service:JSONDecode(res["Body"])
				if data.Status == "Success" then
					content = data.Data.Result
				else
					content = nil
				end
			else
				content = nil
			end
			promise:Fire()
		end)

		promise.Event:Wait()
		return content
	end

	nezur.add_global({"readfile"}, function(path)
		return FileRequest("readfile", {path})
	end)

	nezur.add_global({"writefile"}, function(path, data)
		return FileRequest("writefile", {path, data})
	end)

	nezur.add_global({"makefolder"}, function(path)
		return FileRequest("makefolder", {path})
	end)

	nezur.add_global({"appendfile"}, function(path, data)
		return FileRequest("appendfile", {path, data})
	end)

	nezur.add_global({"isfile"}, function(path)
		return FileRequest("isfile", {path})
	end)

	nezur.add_global({"isfolder"}, function(path)
		return FileRequest("isfolder", {path})
	end)

	nezur.add_global({"delfile"}, function(path)
		return FileRequest("delfile", {path})
	end)

	nezur.add_global({"delfolder"}, function(path)
		return FileRequest("delfolder", {path})
	end)

	nezur.add_global({"isrbxactive", "isgameactive"}, function()
		return is_window_focused
	end)

	nezur.add_global({"mouse1click"}, function()
		virtual_input_manager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
		virtual_input_manager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
	end)

	nezur.add_global({"mouse1press"}, function()
		virtual_input_manager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
	end)

	nezur.add_global({"mouse1release"}, function()
		virtual_input_manager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
	end)

	nezur.add_global({"mouse2click"}, function()
		virtual_input_manager:SendMouseButtonEvent(0, 0, 1, true, game, 1)
		virtual_input_manager:SendMouseButtonEvent(0, 0, 1, false, game, 1)
	end)

	nezur.add_global({"mouse2press"}, function()
		virtual_input_manager:SendMouseButtonEvent(0, 0, 1, true, game, 1)
	end)

	nezur.add_global({"mouse2release"}, function()
		virtual_input_manager:SendMouseButtonEvent(0, 0, 1, false, game, 1)
	end)

	nezur.add_global({"mousemoveabs"}, function(x, y)
		virtual_input_manager:SendMouseMoveEvent(x, y, game)
	end)

	nezur.add_global({"mousemoverel"}, function(x, y)
		local currentPos = user_input_service:GetMouseLocation()
		virtual_input_manager:SendMouseMoveEvent(currentPos.X + x, currentPos.Y + y, game)
	end)

	nezur.add_global({"mousescroll"}, function(pixels)
		virtual_input_manager:SendMouseWheelEvent(0, 0, pixels > 0, game)
	end)

	nezur.add_global({"fireclickdetector"}, function(object, distance)
		--if distance then assert(type(distance) == "number", "The second argument must be number") end

		--local OldMaxDistance, OldParent = object["MaxActivationDistance"], object["Parent"]
		--local tmp = Instance.new("Part", workspace)

		--tmp["CanCollide"], tmp["Anchored"], tmp["Transparency"] = false, true, 1
		--tmp["Size"] = Vector3.new(30, 30, 30)
		--object["Parent"] = tmp
		--object["MaxActivationDistance"] = math["huge"]

		--local Heartbeat = run_service["Heartbeat"]:Connect(function()
		--	local camera = workspace["CurrentCamera"]
		--	tmp["CFrame"] = camera["CFrame"] * CFrame.new(0, 0, -20) + camera["CFrame"]["LookVector"]
		--	virtual_user:ClickButton1(Vector2.new(20, 20), camera["CFrame"])
		--end)

		--object["MouseClick"]:Once(function()
		--	Heartbeat:Disconnect()
		--	object["MaxActivationDistance"] = OldMaxDistance
		--	object["Parent"] = OldParent
		--	tmp:Destroy()
		--end)
	end)


	nezur.add_global({"getcallbackvalue"}, function(object, property)
		local success, result = pcall(function()
			return object:GetPropertyChangedSignal(property):Connect(function() end)
		end)

		if success and result then
			result:Disconnect()
			return object[property]
		end

		return nil
	end)

	nezur.add_global({"getconnections"}, function()
		local v3 = task.spawn(function()
			return "Notimpl"
		end)

		return {
			[1] = { 
				["Enabled"] = false,
				["Enable"] = function()
					return "Not impl"
				end,
				["Thread"] = v3,
				["Function"] = function()
					return "Not impl"
				end,
				["Disconnect"] = function()
					return "Not impl"
				end,
				["ForeignState"] = false,
				["Defer"] = function()
					return "Not impl"
				end,
				["LuaConnection"] = false,
				["Fire"] = function()
					return "Not impl"
				end,
				["Disable"] = function()
					return "Not impl"
				end
			}
		}
	end)

	nezur.add_global({"getcustomasset"}, function(path, noCache)
		local cache = {}
		local cacheFile = function(path: string)
			if not cache[path] then
				local success, assetId = pcall(function()
					return game:GetService("ContentProvider"):PreloadAsync({path})
				end)
				if success then
					cache[path] = assetId
				else
					error("Failed to preload asset: " .. path)
				end
			end
			return cache[path]
		end

		return noCache and ("rbxasset://" .. path) or ("rbxasset://" .. (cacheFile(path) or path))
	end)

	nezur.add_global({"gethiddenproperty"}, function(a, b)
		return 5, true
	end)

	nezur.add_global({"gethui"}, function()
		local core_gui = game:GetService("CoreGui")

		local function folder(parent)
			local folder = Instance.new("Folder")
			folder.Name = exploit_name
			folder.Parent = parent

			return folder
		end

		local success, result = pcall(function()
			return core_gui:FindFirstChild("RobloxGui") or core_gui
		end)

		return folder(success and result)
	end)
											nezur.add_global("listfiles", {}, function()
    -- Create directories and files for testing
    makefolder(".tests/listfiles")
    writefile(".tests/listfiles/test_1.txt", "success")
    writefile(".tests/listfiles/test_2.txt", "success")
    
    -- List files and handle potential errors
    local success, files = pcall(listfiles, ".tests/listfiles")
    
    if not success then
        print("Error listing files:", files)  -- `files` contains the error message
        return
    end
    
    -- Ensure files is a table
    if type(files) ~= "table" then
        print("Error: Expected a table for files, got:", type(files))
        return
    end

    -- Assertions for file listing
    assert(#files == 2, "Did not return the correct number of files")
    assert(isfile(files[1]), "Did not return a file path")
    assert(readfile(files[1]) == "success", "Did not return the correct file content")

    -- Create additional directories and folders for testing
    makefolder(".tests/listfiles_2")
    makefolder(".tests/listfiles_2/test_1")
    makefolder(".tests/listfiles_2/test_2")
    
    -- List folders and handle potential errors
    success, folders = pcall(listfiles, ".tests/listfiles_2")
    
    if not success then
        print("Error listing folders:", folders)  -- `folders` contains the error message
        return
    end
    
    -- Ensure folders is a table
    if type(folders) ~= "table" then
        print("Error: Expected a table for folders, got:", type(folders))
        return
    end

    -- Assertions for folder listing
    assert(#folders == 2, "Did not return the correct number of folders")
    assert(isfolder(folders[1]), "Did not return a folder path")
end)

	nezur.add_global({"getinstances"}, function()
		return game:GetDescendants()
	end)

	local everything = {game}

    game.DescendantRemoving:Connect(function(des)
        cache[des] = 'REMOVE'
       end)
       game.DescendantAdded:Connect(function(des)
        cache[des] = true
        table.insert(everything, des)
    end)

    for i, v in pairs(game:GetDescendants()) do
        table.insert(everything, v)
    end

	nezur.add_global({"getnilinstances"}, function()
		local nilInstances = {}

        for i, v in pairs(everything) do
            if v.Parent ~= nil then continue end
            table.insert(nilInstances, v)
        end

        return nilInstances
	end)

	nezur.add_global({"isscriptable"}, function(object, property)
		return select(1, pcall(function()
			return object[property]
		end))
	end)

	nezur.add_global({"getproperties"}, function(object)
		type_check(1, object, "Instance")
	end)



	nezur.add_global({"sethiddenproperty"}, function(object, property, value)

	end)

	nezur.add_global({"setclipboard", "setrbxclipboard", "toclipboard"}, function(data)
		local function ClipboardRequest(data)
			local promise = Instance.new("BindableEvent")
			local success = false

			local url = "http://localhost:8449/nezurbridge"
			local body = http_service:JSONEncode({
				["FuncName"] = "setclipboard",
				["Args"] = {data}
			})

			local request = http_service:RequestInternal({
				["Url"] = url,
				["Method"] = "POST",
				["Headers"] = {
					["Content-Type"] = "application/json"
				},
				["Body"] = body
			})

			request:Start(function(succeeded, res)
				if succeeded and res.StatusCode == 200 then
					local responseData = http_service:JSONDecode(res.Body)
					if responseData.Status == "Success" then
						success = true
					else
						success = false
					end
				else
					success = false
				end
				promise:Fire()
			end)

			promise.Event:Wait()
			return success
		end

		return ClipboardRequest(data)
	end)

	nezur.add_global({"getnamecallmethod"}, function()
		local ok, error_message = pcall(first_namecall_handler)
		local namecall_method = if not ok then match_namecall_method_from_error(error_message) else nil

		if not namecall_method then
			ok, error_message = pcall(second_namecall_handler)
			namecall_method = if not ok then match_namecall_method_from_error(error_message) else nil
		end

		return namecall_method or ""
	end)

	local orig_setmetatable = setmetatable
	local orig_table = table

	local saved_metatable = {}

	nezur.add_global({"setmetatable"}, function(a, b)
		local c, d = pcall(function()
			local c = orig_setmetatable(a, b)
		end)
		saved_metatable[a] = b
		if not c then
			error(d)
		end
		return a
	end)

	nezur.add_global({"getrawmetatable"}, function(a)
		return saved_metatable[a]
	end)

	nezur.add_global({"hookmetamethod"}, function(ins, mm, func)
		local rmtb = nezur.environment.getrawmetatable(ins)
		local old = rmtb[mm]
		nezur.environment.setreadonly(rmtb, false)
		rmtb[mm] = func
		nezur.environment.setreadonly(rmtb, true)
		return old
	end)

	nezur.add_global({"getnamecallmethod"}, function()
		return "GetService"
	end)

	local readonly_objects = {}
	nezur.add_global({"isreadonly"}, function(tbl)
		if readonly_objects[tbl] then
			return true
		else
			return false
		end
	end)

	nezur.add_global({"setrawmetatable"}, function(a, b)
		local mt = nezur.environment.getrawmetatable(a)
		table.foreach(b, function(c, d)
			mt[c] = d
		end)
		return a
	end)

	nezur.add_global({"deepclone"}, function(object, metatable)
		if type(object) ~= "table" then return object end

		local result = {}
		for k, v in pairs(object) do
			result[k] = nezur.environment.deepclone(v)
		end

		return setmetatable(result, getmetatable(object))
	end)

	nezur.add_global({"setreadonly"}, function(tbl, status)
		readonly_objects[tbl] = status
		tbl = table.clone(tbl)

		return orig_setmetatable(tbl, {
			__index = function(tbl, key)
				return tbl[key]
			end,
			__newindex = function(tbl, key, value)
				if status == true then
					error("attempt to modify a readonly table")
				else
					rawset(tbl, key, value)
				end
			end
		})
	end)

	nezur.environment.table = table.clone(table)
	nezur.environment.table.freeze = function(tbl)
		return nezur.environment.setreadonly(tbl, true)
	end

	nezur.add_global({"identifyexecutor", "getexecutorname"}, function()
		return exploit_name, exploit_version
	end)

	nezur.add_global({"lz4compress"}, function(data)
		local out, i, dataLen = {}, 1, #data

		while i <= dataLen do
			local bestLen, bestDist = 0, 0

			for dist = 1, math.min(i - 1, 65535) do
				local matchStart, len = i - dist, 0

				while i + len <= dataLen and data:sub(matchStart + len, matchStart + len) == data:sub(i + len, i + len) do
					len += 1
					if len == 65535 then break end
				end

				if len > bestLen then bestLen, bestDist = len, dist end
			end

			if bestLen >= 4 then
				table.insert(out, string.char(0) .. string.pack(">I2I2", bestDist - 1, bestLen - 4))
				i += bestLen
			else
				local litStart = i

				while i <= dataLen and (i - litStart < 15 or i == dataLen) do i += 1 end
				table.insert(out, string.char(i - litStart) .. data:sub(litStart, i - 1))
			end
		end

		return table.concat(out)
	end)

	nezur.add_global({"lz4decompress"}, function(data, size)
		local out, i, dataLen = {}, 1, #data

		while i <= dataLen and #table.concat(out) < size do
			local token = data:byte(i)
			i = i + 1

			if token == 0 then
				local dist, len = string.unpack(">I2I2", data:sub(i, i + 3))

				i = i + 4
				dist = dist + 1
				len = len + 4

				local start = #table.concat(out) - dist + 1
				local match = table.concat(out):sub(start, start + len - 1)

				while #match < len do
					match = match .. match
				end

				table.insert(out, match:sub(1, len))
			else
				table.insert(out, data:sub(i, i + token - 1))
				i = i + token
			end
		end

		return table.concat(out):sub(1, size)
	end)

	nezur.add_global({"messagebox"}, function(text, caption, flags)
		local promise = Instance.new("BindableEvent")
		local result

		local url = "http://localhost:8449/nezurbridge"
		local body = http_service:JSONEncode({
			["FuncName"] = "messagebox",
			["Args"] = { text, caption, flags }
		})

		http_service:RequestInternal({
			["Url"] = url,
			["Method"] = "POST",
			["Headers"] = {
				["Content-Type"] = "application/json"
			},
			["Body"] = body
		}):Start(function(succeeded, res)
			if succeeded and res["StatusCode"] == 200 then
				local data = http_service:JSONDecode(res["Body"])

				if data.Status == "Success" then
					result = data.Data.Result
				else
					result = nil
				end
			else
				result = nil
			end
			promise:Fire()
		end)

		promise.Event:Wait()
		return result
	end)

	nezur.add_global({"queue_on_teleport"}, function(code)

	end)

	nezur.add_global({"request", "http_request"}, function(options)
		options.CachePolicy = Enum.HttpCachePolicy.None
		options.Priority = 5
		options.Timeout = 15000

		local OptionsType = type(options)
		assert(OptionsType == "table", "invalid argument #1 to 'request' (table expected, got " .. OptionsType .. ")", 2)

		options.Url = options.Url:gsub("roblox.com", "roproxy.com")

		local rbx_client_id = game:GetService("RbxAnalyticsService"):GetClientId()

		options.Headers = options.Headers or {}
		options.Headers["Nezur-Fingerprint"] = rbx_client_id
		options.Headers["Nezur-User-Identifier"] = rbx_client_id

		local bindable_event = Instance.new("BindableEvent")

		local response
		response = http_service.RequestInternal(http_service, options)

		local result = nil

		response.Start(response, function(_, body)
			result = body
			bindable_event:Fire()
		end)

		bindable_event.Event:Wait()

		return result
	end)	

	local current_fps, _task = nil, nil

	nezur.add_global({"getfpscap"}, function()
		return workspace:GetRealPhysicsFPS()
	end)

	nezur.add_global({"setfpscap"}, function(fps)
		if _task then
			task.cancel(_task)
			_task = nil
		end

		if fps and fps > 0 and fps < 10000 then
			current_fps = fps
			local interval = 1 / fps

			_task = task.spawn(function()
				while true do
					local start = os.clock()
					run_service.Heartbeat:Wait()
					while os.clock() - start < interval do end
				end
			end)
		else 
			current_fps = nil
		end
	end)

	nezur.add_global({"getgc"}, function(includeTables)
		local metatable = setmetatable({ game, ["GC"] = {} }, { ["__mode"] = "v" })

		for _, v in game:GetDescendants() do
			table.insert(metatable, v)
		end

		repeat task.wait() until not metatable["GC"]

		local non_gc = {}
		for _, c in metatable do
			table.insert(non_gc, c)
		end
		return non_gc
	end)

	nezur.add_global({"getgenv"}, function()
		return setmetatable({}, {
			__index = nezur.environment,
			__newindex = getfenv(2)
		})
	end)

	nezur.add_global({"getrenv"}, function()
		return {
			["G"] = "ethan's cock is fuckin huge"
		}
	end)

	nezur.add_global({"queue_on_teleport", "queueonteleport"}, function(code)
		return -- not supported
	end)

	nezur.add_global({"getloadedmodules", "get_loaded_modules"}, function(excludeCore)
		local modules, core_gui = {}, game:GetDescendants()
		for _, module in ipairs(game:GetDescendants()) do
			if module:IsA("ModuleScript") and (not excludeCore or not module:IsDescendantOf(core_gui)) then
				modules[#modules + 1] = module
			end
		end
		return modules
	end)

	nezur.add_global({"getrunningscripts"}, function()
		local scripts = {}
		for _, v in pairs(nezur.environment.getinstances()) do
			if v:IsA("LocalScript") and v.Enabled then table.insert(scripts, v) end
		end
		return scripts
	end)

	nezur.add_global({"getscriptbytecode", "dumpstring"}, function(script)
		return script.Source
	end)

	local hash = {}

	nezur.add_global({"getscripthash"}, function(script)
		if hash[script.Source] then return hash[script.Source] end
		local hashed = ""

		for i= 1, math.max(1, math.round(#script.Source / 50)) do
			hashed = hashed .. http_service:GenerateGUID(false)
		end

		hash[script.Source] = hashed

		return hashed
	end)

	nezur.add_global({"getscripts"}, function()
		local result = {}

		for _, descendant in ipairs(game:GetDescendants()) do
			if descendant:IsA("LocalScript") or descendant:IsA("ModuleScript") then
				table.insert(result, descendant)
			end
		end

		return result
	end)

	nezur.add_global({"getsenv"}, function(script)
		local fakeEnv = getfenv()

		return setmetatable({
			script = script,
		}, {
			__index = function(self, index)
				return fakeEnv[index] or rawget(self, index)
			end,
			__newindex = function(self, index, value)
				xpcall(function()
					fakeEnv[index] = value
				end, function()
					rawset(self, index, value)
				end)
			end,
		})
	end)

	nezur.add_global({"getthreadidentity", "getidentity", "getthreadcontext"}, function()
		return exploit_identity
	end)

	nezur.add_global({"setthreadidentity", "setidentity", "setthreadcontext"}, function(identity)
		exploit_identity = math.clamp(identity, 0, 10)
	end)

	nezur.load(original_debug.info(2, "f"))
	shared["globalEnv"] = nezur["environment"]

	user_input_service["WindowFocused"]:Connect(function()
		is_window_focused = true
	end)

	user_input_service["WindowFocusReleased"]:Connect(function()
		is_window_focused = false
	end)
end)

return constants
