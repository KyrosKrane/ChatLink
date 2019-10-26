-- ChatLink-1.0.lua
-- Written by KyrosKrane Sylvanblade (kyros@kyros.info)
-- Copyright (c) 2019 KyrosKrane Sylvanblade
-- Licensed under the MIT License, as per the included file.

-- File revision: @file-abbreviated-hash@
-- File last updated: @file-date-iso@

--[==[
This library provides tools that let you create a chat link, then react to it when the user clicks the link.

Sample use cases

	1) An addon alerts the user to an issue by adding a line to the chat. The user can click a chat link to open a window (addon frame) with more information.
	2) An addon identifies a rare and puts its location in the zone general chat. Any user who also has the addon installed should be able to click the chat link to add a waypoint arrow to Tomtom (or similar).
	3) A roleplaying/storytelling addon allows a group of players to create a branching text system. The "GM" pre-populates a set of story segments and responses. Each segment has key words highlighted, and when other players indicate interest in the key words, the appropriate response is given (optionally with more key words). Other players in the group can click the chat text to "respond" and hear the next segment of the story.

Usage:

	1) Get the library using LibStub (also be sure it's in your TOC file).
		local ChatLink = LibStub("ChatLink-1.0")

	2) Create a chat link. Full documentation of the parameters is below. Optional parameters are skipped for this example.
		local DisplayText = "click here"
		local Link, CallbackID = ChatLink:CreateChatLink(DisplayText)

	3) If the link was created without error, register a callback so you get notified when the user clicks the link.
		if CallbackID then
			ChatLink.RegisterCallback(MyAddon, CallbackID, "HandleClick")
		end

		You must have a method named MyAddon:HandleClick() defined somewhere in your addon.
		The method name can be whatever you want, so long as it matches what you register.

	4) Display the link to the user.
		if Link then
			DEFAULT_CHAT_FRAME:AddMessage("You can " .. Link .. " to do the thing.")
		end

		The user will see:
			You can [[click here]] to do the thing.

	5) When the user clicks the link, the callback you requested will be fired, and you can respond to that as you wish.
		function MyAddon:HandleClick(CallbackID, DisplayText, Data)
			DEFAULT_CHAT_FRAME:AddMessage("Now doing the thing!")
			MyAddon:DoTheThing()
		end

		The callback parameters are:
			CallbackID
				The same callback ID that was returned by CreateChatLink()
			DisplayText
				The DisplayText that was passed to CreateChatLink(), as modified by that function.
				See "SkipFormat" in the Link Creation API below for how this might differ from what was passed in.
			Data
				The Data that was passed to CreateChatLink().
				Data is returned unchanged.

Link Creation API

	Link, CallbackID = ChatLink:CreateChatLink(DisplayText, Data, SkipFormat, CallbackID, PublicMessageID)

	This function creates a chat link and sets up a callback (using CallbackHandler) that will be fired when the user clicks the link.
	The calling app should subscribe to the callback identifier to handle the click event, and can unsubscribe after the first click if multiple clicks are not desired.

	Inputs:

		DisplayText
			A required text string that will be displayed in the user's chat to click on.
			See SkipFormat below on how this value might get modified.
		Data
			An optional text string included as a parameter in the chat link, then passed to the callback function when the link is clicked.
			It's intended to help the calling addon distinguish which text link was clicked, in case it makes multiple links with identical display text.
			This must NOT include any pipe characters (|). If it does, the function returns the error values nil, nil.
		SkipFormat
			An optional boolean defaulting to false.
			If it is true, the function will use DisplayText verbatim, without applying formatting. The calling addon supplies its own formatting. Note that pipe symbols are NOT escapte if SkipFormat is true, which means it's up to the calling addon to ensure the pipes are correct and don't corrupt the link.
			If it is false or nil (not specified), the library will automatically enclose DisplayText in brackets and highlight it in color for visibility.  Pipe symbols will also be escaped to prevent corrupting the chat link.
		CallbackID
			The optional event name of a callback event that is fired when the user clicks a link.
			If it is nil or omitted, an arbitrary value is generated.
			This should usually be omitted so that the library generates a unique value for each link.
			If you include it, it must be globally unique across ALL addons that use ChatLink, or you may accidentally fire an event for another addon that registered the same name.
			This feature can be used for multiple addons that coordinate to use certain event names in common, or by an addon that has to be run by multiple users who need to click each others' links.
		PublicMessageID
			An optional string that identifies the addon-managed message type. If not nil, it means this is a public link that any user (with the appropriate addon installed) can click to do something.
			When this is not nil, the function will register the PublicMessageID as a public link type, and simply pass on the link details to the callback handler without validating them. It's up to the callback handler to validate and parse the link and data.
			Note that there can only be one CallbackID for each PublicMessageID. Subsequent calls with the same PublicMessageID will replace the prior CallbackID.

	Returns:
		Link
			A string containing the chat link.
		CallbackID
			The callback event (string value) that should be registered. The event fires when the user clicks the link.
			If the caller specified an event name in the input, that same value is returned; otherwise a value is generated and returned.

		If errors are encountered, returns nil for both outputs.

Persistent Private Links

	Normally in WoW, chat history is cleared when the user logs out or reloads the UI. Some addons provide a way to store chat from prior game sessions. If a user has an addon like that and clicks a private link from a prior session, it will not work. The self ID and salt will be different, as they are created when the library is initialized (at each login or reload).

	This is something under consideration for future development.

]==]

--#########################################
--# Script setup
--#########################################

-- Minor revision tracker
-- 1: Initial alpha release with private links
-- 2: Second alpha release implementing public links

-- Use Libstub to set up as a library
local MAJOR, MINOR = "ChatLink-1.0", 2
assert(LibStub, MAJOR .. " requires LibStub")

local ChatLink, oldversion = LibStub:NewLibrary(MAJOR, MINOR)
if not ChatLink then return end

-- Set up the callback handler
local CBH = LibStub("CallbackHandler-1.0")
assert(CBH, MAJOR .. " requires CallbackHandler-1.0")
ChatLink.callbacks = CBH:New(ChatLink, nil, nil, false)

local sha1 = LibStub("LibSHA1")
assert(sha1, MAJOR .. " requires LibSHA1")

local LB64 = LibStub("LibBase64-1.0")
assert(LB64, MAJOR .. " requires LibBase64-1.0")


--#########################################
--# Debug settings
--#########################################

-- True turns on debugging output, which users shouldn't normally need to see.
ChatLink.DebugMode = false

--@alpha@
ChatLink.DebugMode = true
--@end-alpha@

-- Print debug output to the chat frame.
function ChatLink:DebugPrint(...)
	if not ChatLink.DebugMode then return end

	local msg = ""
	local args = { n = select("#", ...), ... }
	for i=1,args.n do
	   if i > 1 then msg = msg .. " " end
	   if nil == args[i] then
		  msg = msg .. "nil"
	   else
		  msg = msg .. tostring(args[i])
	   end
	end

	DEFAULT_CHAT_FRAME:AddMessage("ChatLink Debug: " .. msg)
end -- ChatLink:DebugPrint()


--#########################################
--# Utility functions
--#########################################

 -- These functions for converting a table to a string are taken from:
 -- http://lua-users.org/wiki/TableUtils
 local function table_val_to_str(v)
	if "string" == type(v) then
		v = string.gsub(v, "\n", "\\n")
		if string.match(string.gsub(v, '[^\'"]', ""), '^"+$') then
			return "'" .. v .. "'"
		end
		return '"' .. string.gsub(v, '"', '\\"') .. '"'
	else
		return "table" == type(v) and table_tostring(v) or tostring(v)
	end
end


local function table_key_to_str(k)
	if "string" == type(k) and string.match(k, "^[_%a][_%a%d]*$") then
		return k
	else
		return "[" .. table_val_to_str(k) .. "]"
	end
end


local function table_tostring(tbl)
	local result, done = {}, {}
	for k, v in ipairs(tbl) do
		table.insert(result, table_val_to_str(v))
		done[k] = true
	end
	for k, v in pairs(tbl) do
		if not done[k] then
			table.insert(result, table_key_to_str(k) .. "=" .. table_val_to_str(v))
		end
	end
	return "{" .. table.concat(result, ",") .. "}"
end


-- This function gets an arbitrary number of random bytes encoded in a string
local function GetRandom(n)
	local beginTime = debugprofilestop()

	local t = {} -- table for storing the output
	for i = 1, n do
		table.insert(t, string.char(math.random(0, 255)))
	end
	local out = table.concat(t)
	local timeUsed = debugprofilestop()  - beginTime
	ChatLink:DebugPrint(("GetRandom with %d used %s ms."):format(n, timeUsed))
	return out
end


-- Create a hashing function
-- If any input parameter is nil, it is treated as an empty string.
-- Otherwise, it returns the MD5 of the concatenation of all the arguments.
local function GetHash(...)
	local FuncStart = debugprofilestop()

	-- Get the number of arguments
	local n=select('#', ...)

	-- Iterate over the arguments. Replace nils with an empty string, and replace other non-strings with a string represenation.
	local args = {}
	local v
	for i = 1, n do
		v = select(i, ...)
		if nil == v then
			args[i] = ""
		elseif "table" == type(v) then
			args[i] = table_tostring(v) -- brute-force serialization
		else
			args[i] = tostring(v)
		end
	end -- for

	local concat_args = table.concat(args)

	local ArgParseTime = debugprofilestop()  - FuncStart
	ChatLink:DebugPrint(("Arg parsing with %d params used %s ms."):format(n, ArgParseTime))

	--ChatLink:DebugPrint((concat_args):gsub("|", "||"))

	-- Concatenate the arguments table, hash it (which returns the binary hash in four parts), combine the hash parts, and Base64-encode the resulting binary value.
	-- local hash = table.concat(MD5.MD5AsTable(concat_args))
	-- local hash = MD5Lua.sum(concat_args)
	local HashStart = debugprofilestop()
	local hash = sha1.binary(concat_args)
	local HashTime = debugprofilestop()  - HashStart
	ChatLink:DebugPrint(("Hashing used %s ms."):format(HashTime))

	local EncodeStart = debugprofilestop()
	local out = LB64.Encode(hash)
	local EncodeTime = debugprofilestop()  - EncodeStart
	ChatLink:DebugPrint(("Base64 encoding used %s ms."):format(EncodeTime))

	local timeUsed = debugprofilestop()  - FuncStart
	ChatLink:DebugPrint(("GetHash with %d params used %s ms."):format(n, timeUsed))

	return out

end -- GetHash()


-- A no-op function to silence Luacheck on empty "if" branches
local function NOOP() end


--#########################################
--# Link Settings
--#########################################

-- These settings control the link's data portion

-- This is the Blizzard link type. It can only be one of a set number of values, documented here:
-- https://wow.gamepedia.com/UI_escape_sequences
-- And of those, only a very few can be overloaded for our purposes. The "garrmission" type is safest to use.
local BLIZZ_LINK_TYPE = "garrmission"

-- Set the link type's data paramater used by this library
ChatLink.LinkType = "ChatLink"

-- Get a random value for our self ID. Six bytes of data becomes eight characters when encoded; that should be plenty.
ChatLink.ID = LB64.Encode(GetRandom(6))

-- Get a value used when hashing data to prove a link came from us
-- Note that this is a local value so it cannot be overridden by other addons.
local Salt = LB64.Encode(GetRandom(128))


--#########################################
--# Display settings
--#########################################

-- These settings control the link's display portion.

-- Set the default link color
ChatLink.Highlight = "FFFF00CC"
ChatLink.PreMarker = "[["
ChatLink.PostMarker = "]]"


--#########################################
--# Callback settings
--#########################################

-- These variables control the callback functionality

-- Constants to identify whether a link is public (should be usable by anyone else with the same addon installed) or private (only by the user who generated it)
local PUBLIC, PRIVATE = "1", "0"

-- Keep a running count of how many links we've made.
ChatLink.LinkCount = 0

-- Keep a map of link IDs to callback values.
ChatLink.Mapping = {}


--#########################################
--# Chat link creation
--#########################################

-- This function creates a chat link and sets up a callback (using CallbackHandler) that will be fired when the user clicks the link.
-- See the API section above for full documentation
function ChatLink:CreateChatLink(DisplayText, Data, SkipFormat, CallbackID, PublicMessageID)
	-- Validate the inputs
	if not DisplayText or "string" ~= type(DisplayText) or "" == DisplayText then
		ChatLink:DebugPrint("DisplayText is invalid.")
		return nil, nil
	end
	if Data then
		if "string" ~= type(Data) or Data:find("|", nil, true) then
			ChatLink:DebugPrint("Data is invalid.")
			return nil, nil
		end
	end
	if SkipFormat and "boolean" ~= type(SkipFormat) then
		ChatLink:DebugPrint("SkipFormat is invalid.")
		return nil, nil
	end
	if CallbackID then
		if "string" ~= type(CallbackID) or "" == CallbackID then
			ChatLink:DebugPrint("CallbackID is invalid.")
			return nil, nil
		end
	end
	if PublicMessageID then
		if "string" ~= type(PublicMessageID) or "" == PublicMessageID then
			ChatLink:DebugPrint("PublicMessageID is invalid.")
			return nil, nil
		end
	end

	-- First format the text for display
	local TextPart
	if SkipFormat then
		TextPart = DisplayText
	else
		TextPart = WrapTextInColorCode(("%s%s%s"):format(ChatLink.PreMarker, DisplayText:gsub("|", "||"), ChatLink.PostMarker), ChatLink.Highlight)
	end

	-- Next, assemble the data portion, which has these parts:
	--	BLIZZ_LINK_TYPE
	--	ChatLink.LinkType
	--	Message type (public or private)
	--	Message ID
	--	Secure hash
	--	Data

	-- The message ID is how we link the ID used in the link to the callback.
	-- For public links, the calling addon supplies a name to reference that message type.
	-- For private links, we construct a message ID consisting of a sender ID, a dash, then a sequence number

	-- Determine whether the link should be clickable by anyone, or just the sender
	local IsPublic, MessageID, Hash
	if PublicMessageID then
		-- The caller requested a public message. The addon will handle all validation of the link.
		-- The message ID will be replaced by the value the caller provided.
		-- Public messages get a hash of zero
		IsPublic = PUBLIC
		MessageID = PublicMessageID
		Hash = 0
	else
		IsPublic = PRIVATE
		ChatLink.LinkCount = ChatLink.LinkCount + 1
		MessageID = string.format("%s-%s", ChatLink.ID, ChatLink.LinkCount)
		-- Hash the secure parts of the data.
		Hash = GetHash("**", MessageID, "**", Data, "**", TextPart, "**", Salt, "**")
	end

	-- Assemble the data portion of the link
	local DataPart = ("%s:%s:%s:%s:%s:%s"):format(BLIZZ_LINK_TYPE, ChatLink.LinkType, IsPublic, MessageID, Hash, Data or "")

	-- Now we get the the callback ID and put it in our mapping list
	-- If the user didn't supply one, assign an arbitrary name to the callback event
	ChatLink.Mapping[MessageID] = CallbackID or MessageID

	-- Finally, return the link and the event name.
	return ("|H%s|h%s|h"):format(DataPart, TextPart), ChatLink.Mapping[MessageID]

end -- ChatLink:CreateChatLink()


-- For public links, sometimes you want to just handle links that are created by another person.
-- In that scenario, you can just register a callback for your PublicMessageID without having to create a link first
-- The parameters PublicMessageID and CallbackID are the same as those used by CreateChatLink().
-- PublicMessageID is required. CallbackID is optional; if not provided, a value will be generated and returned.
-- Returns the CallbackID if the handler was registered successfully, nil if there was an error in the input values
-- Note that there can only be one CallbackID for each PublicMessageID. Subsequent calls with the same PublicMessageID will replace the prior CallbackID.
function ChatLink:RegisterMessageID(PublicMessageID, CallbackID)
	-- Validate the inputs
	if not PublicMessageID or "string" ~= type(PublicMessageID) or "" == PublicMessageID then
		ChatLink:DebugPrint("PublicMessageID is invalid.")
		return nil
	end
	if CallbackID then
		if "string" ~= type(CallbackID) or "" == CallbackID then
			ChatLink:DebugPrint("CallbackID is invalid.")
			return nil
		end
	else
		-- No callback ID supplied, generate one
		ChatLink.LinkCount = ChatLink.LinkCount + 1
		CallbackID = string.format("%s-%s", ChatLink.ID, ChatLink.LinkCount)
	end

	ChatLink.Mapping[PublicMessageID] = CallbackID
	return CallbackID
end


--#########################################
--# Callback invocation
--#########################################

-- When the user clicks a link in chat, the secure function SetItemRef() is invoked.
-- For "garrmission" links with an invalid ID (which our link type is), it exits silently and without error.
-- So, we can hook it to process our chatlink clicks.
hooksecurefunc("SetItemRef", function(LinkData, FullLink)
	-- for debugging
	ChatLink:DebugPrint("LinkData is " .. LinkData .. ", FullLink is " .. FullLink:gsub("|", "||"))

	-- Get the parts of the link data
	local BlizzLinkType, SubType, IsPublic, MessageID, Hash, Data = strsplit(":", LinkData, 6)
	ChatLink:DebugPrint("BlizzLinkType is ", BlizzLinkType, ", SubType is ", SubType)

	-- Make sure the link type that was clicked is one created by our addon.
	if BlizzLinkType ~= BLIZZ_LINK_TYPE or SubType ~= ChatLink.LinkType then
		-- not our chat link, ignore
		ChatLink:DebugPrint("Wrong link type")
		return
	end

	ChatLink:DebugPrint("IsPublic is ", IsPublic)
	ChatLink:DebugPrint("MessageID is ", MessageID)
	ChatLink:DebugPrint("Hash is ", Hash)
	ChatLink:DebugPrint("Data is ", Data)

	-- Extract the text the user clicked.
	local TextPart = FullLink:match("^%|H.+%|h(.+)%|h$")
	ChatLink:DebugPrint("TextPart is ", TextPart)

	-- Validate private messages
	if IsPublic == PRIVATE then
		-- Make sure the hash matches
		local ValidationHash = GetHash("**", MessageID, "**", Data, "**", TextPart, "**", Salt, "**")
		ChatLink:DebugPrint("ValidationHash is ", ValidationHash)
		if ValidationHash ~= Hash then
			-- Bad chat link
			ChatLink:DebugPrint("Hash validation failed")
			return
		end

		-- Extract the sender ID and message ID to make sure it's our message
		local SenderID, SeqID = strsplit("-", MessageID)
		ChatLink:DebugPrint("SenderID is ", SenderID, ", SeqID is ", SeqID, ", ChatLink.ID is ", ChatLink.ID)
		if SenderID ~= ChatLink.ID then
			-- not our chat link, ignore
			ChatLink:DebugPrint("Wrong sender ID")
			return
		end
	elseif IsPublic == PUBLIC then
		-- no special validation
		NOOP()
	else
		-- Bad public/private marker
		ChatLink:DebugPrint("Invalid IsPublic value")
		return
	end

	-- Get the event name to be fired
	local CallbackID = ChatLink.Mapping[MessageID]
	if not CallbackID then
		-- not our chat link, ignore
		ChatLink:DebugPrint("Message ID not in callback mapping")
		return
	end

	-- All validations have passed.

	-- Fire the callback
	ChatLink.callbacks:Fire(CallbackID, TextPart, Data)

end)
