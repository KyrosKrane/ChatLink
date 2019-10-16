-- ChatLink-1.0.lua
-- Written by KyrosKrane Sylvanblade (kyros@kyros.info)
-- Copyright (c) 2019 KyrosKrane Sylvanblade
-- Licensed under the MIT License, as per the included file.

-- File revision: @file-abbreviated-hash@
-- File last updated: @file-date-iso@

--[[
	This library provides tools that let you create a chat link, then react to it when the user clicks the link.

	Sample use cases

		1) An addon alerts the user to an issue by adding a line to the chat. The user can click a chat link to open a window (addon frame) with more information.
		2) An addon identifies a rare and puts its location in the zone general chat. Any user who also has the addon installed should be able to click the chat link to add a waypoint arrow to Tomtom (or similar).
		3) A roleplaying/storytelling addon allows a group of players to create a branching text system. The "GM" pre-populates a set of story segments and responses. Each segment has key words highlighted, and when other players indicate interest in the key words, the appropriate response is given (optionally with more key words). Other players in the group can click the chat text to "respond" and hear the next segment of the story.

	Usage:

		1) Add the library to your addon using LibStub (also be sure it's in your TOC file).
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
				You can [click here] to do the thing.

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

		Link, CallbackID = ChatLink:CreateChatLink(DisplayText, Data, SkipFormat, CallbackID)

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

		Returns:
			Link
				A string containing the chat link.
			CallbackID
				The callback event (string value) that should be registered. The event fires when the user clicks the link.
				If the caller specified an event name in the input, that same value is returned; otherwise a value is generated and returned.

			If errors are encountered, returns nil for both outputs.

]]

--#########################################
--# Script setup
--#########################################

-- Use Libstub to set up as a library
local MAJOR, MINOR = "ChatLink-1.0", 1
assert(LibStub, MAJOR .. " requires LibStub")

local ChatLink, oldversion = LibStub:NewLibrary(MAJOR, MINOR)
if not ChatLink then return end

-- Set up the callback handler
local CBH = LibStub("CallbackHandler-1.0")
assert(CBH, MAJOR .. " requires CallbackHandler-1.0")
ChatLink.callbacks = ChatLink.callbacks or CBH:New(ChatLink, nil, nil, false)

-- Get a random value for our self ID. Seven characters should be sufficient.
ChatLink.ID = string.format("0x%7.7X", math.random(16^7))


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
-- This is not actually implemented yet.
local PUBLIC, PRIVATE = 1, 0

-- Keep a running count of how many links we've made.
ChatLink.LinkCount = 0

-- Keep a map of link IDs to callback values.
ChatLink.Mapping = {}


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
--# Chat link creation
--#########################################

-- Create a fake MD5 hashing function
local function GetRandomID(...)
	return string.format("%7.7X%7.7X%7.7X%7.7X%4.4X", math.random(16^7), math.random(16^7), math.random(16^7), math.random(16^7), math.random(16^4))
end

-- This function creates a chat link and sets up a callback (using CallbackHandler) that will be fired when the user clicks the link.
-- See the API section above for full documentation
function ChatLink:CreateChatLink(DisplayText, Data, SkipFormat, CallbackID, IsPublic)
	-- Validate the inputs
	if not DisplayText or "string" ~= type(DisplayText) then
		return nil, nil
	end
	if Data then
		if "string" ~= type(Data) or Data:find("|", nil, true) then
			return nil, nil
		end
	end
	if SkipFormat and "boolean" ~= type(SkipFormat) then
		return nil, nil
	end
	if CallbackID and "string" ~= type(CallbackID) then
		return nil, nil
	end
	if IsPublic and "boolean" ~= type(IsPublic) then
		return nil, nil
	end

	-- First format the text for display
	local TextPart
	if SkipFormat then
		TextPart = DisplayText
	else
		TextPart = ("|c%s%s%s%s|r"):format(ChatLink.Highlight, ChatLink.PreMarker, DisplayText:gsub("|", "||"), ChatLink.PostMarker)
	end

	-- Next, assemble the data portion, which has these parts:
	--	BLIZZ_LINK_TYPE
	--	ChatLink.LinkType
	--	Message type (public or private)
	--	Message ID
	--	Data

	-- Determine whether the link should be clickable by anyone, or just the sender
	local MessageType
	if IsPublic then
		MessageType = PUBLIC
	else
		MessageType = PRIVATE
	end

	-- The message ID is how we link the ID used in the link to the callback.
	-- A message ID consists of a sender ID, a dash, then a sequence number
	ChatLink.LinkCount = ChatLink.LinkCount + 1
	local MessageID = string.format("%s-%s", ChatLink.ID, ChatLink.LinkCount)

	-- Assemble the data portion of the link
	local DataPart = ("%s:%s:%s:%s:%s"):format(BLIZZ_LINK_TYPE, ChatLink.LinkType, MessageType, MessageID, Data or "")

	-- Now we get the the callback ID and put it in our mapping list
	-- If the user didn't supply one, assign an arbitrary name to the callback event
	ChatLink.Mapping[MessageID] = CallbackID or MessageID

	-- Finally, return the link and the event name.
	return ("|H%s|h%s|h"):format(DataPart, TextPart), ChatLink.Mapping[MessageID]

end -- ChatLink:CreateChatLink()


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
	local BlizzLinkType, AddonLinker, MessageType, MessageID, Data = strsplit(":", LinkData, 5)
	ChatLink:DebugPrint("BlizzLinkType is ", BlizzLinkType)
	ChatLink:DebugPrint("AddonLinker is ", AddonLinker)
	ChatLink:DebugPrint("MessageType is ", MessageType)
	ChatLink:DebugPrint("MessageID is ", MessageID)
	ChatLink:DebugPrint("Data is ", Data)

	-- Make sure the link type that was clicked is one created by our addon.
	if BlizzLinkType ~= BLIZZ_LINK_TYPE or AddonLinker ~= ChatLink.LinkType then
		-- not our chat link, ignore
		ChatLink:DebugPrint("Wrong link type")
		return
	end

	-- Extract the sender ID and message ID to make sure it's our message
	local SenderID, SeqID = strsplit("-", MessageID)
	ChatLink:DebugPrint("SenderID is ", SenderID)
	ChatLink:DebugPrint("SeqID is ", SeqID)
	ChatLink:DebugPrint("ChatLink.ID is ", ChatLink.ID)
	if SenderID ~= ChatLink.ID then
		-- not our chat link, ignore
		ChatLink:DebugPrint("Wrong sender ID")
		return
	end

	-- Get the event name to be fired
	local CallbackID = ChatLink.Mapping[MessageID]
	if not CallbackID then
		-- not our chat link, ignore
		ChatLink:DebugPrint("Wrong message ID, not in callback mapping")
		return
	end

	-- Extract the text the user clicked.
	ChatLink:DebugPrint("FullLink is ", FullLink:gsub("|","||"))
	local DisplayText = FullLink:match("^%|H.+%|h(.+)%|h$")

	-- for debugging
	ChatLink:DebugPrint("DisplayText is ", DisplayText)

	-- Fire the callback
	ChatLink.callbacks:Fire(CallbackID, DisplayText, Data)

end)
