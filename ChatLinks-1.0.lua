
-- Documentation here


--[[
	Sample use cases

	1) An addon alerts the user to an issue by adding a line to the chat. The user can click a chat link to open a window (addon frame) with more information.
	2) An addon identifies a rare and puts its location in the zone general chat. Any user who also has the addon installed should be able to click the chat link to add a waypoint arrow to Tomtom (or similar).
	3) A roleplaying/storytelling addon allows a group of players to create a branching text system. The "GM" pre-populates a set of story segments and responses. Each segment has key words highlighted, and when other players indicate interest in the key words, the appropriate response is given (optionally with more key words). Other players in the group can click the chat text to "respond" and hear the next segment of the story.
]]



-- Use Libstub to set up as a library
local MAJOR, MINOR = "ChatLinks-1.0", 1
assert(LibStub, MAJOR .. " requires LibStub")

local ChatLinks, oldversion = LibStub:NewLibrary(MAJOR, MINOR)
if not ChatLinks then return end

-- Set up the callback handler
local CBH = LibStub("CallbackHandler-1.0")
assert(CBH, MAJOR .. " requires CallbackHandler-1.0")
ChatLinks.callbacks = ChatLinks.callbacks or CBH:New(ChatLinks, nil, nil, false)


--Get a random value for our self ID. 128 bits (16 bytes) should be sufficient.
ChatLinks.ID = string.format("0x%7.7X", math.random() * 16^7) .. string.format("0x%7.7X", math.random() * 16^7) .. string.format("0x%7.7X", math.random() * 16^2)


-- These settings control the link's data portion

-- This is the Blizzard link type. It can only be one of a set number of values, documented here:
-- https://wow.gamepedia.com/UI_escape_sequences
-- And of those, only a very few can be overloaded for our purposes. The "garrmission" type is safest to use.
local BLIZZ_LINK_TYPE = "garrmission"

-- Set the link type's data paramater used by this library
ChatLinks.LinkType = "ChatLink"


-- These settings control the link's display portion.

-- Set the default link color
ChatLinks.Highlight = "FFFF0000"


-- These settings control the callback functionality

-- Constants to identify whether a link is public (should be usable by anyone else with the same addon installed) or private (only by the user who generated it)
local PUBLIC, PRIVATE = 1, 0

-- Keep a running count of how many links we've made.
ChatLinks.LinkCount = 0




--[[
This function creates a chat link and sets up a callback (using CallbackHandler) that will be fired when the user clicks the link.
The calling app should subscribe to the callback identifier to handle the click event, and can unsubscribe after the first click if multiple clicks are not desired.

Inputs:

	DisplayText
		a required text string displayed in the user's chat that can be clicked.
	Data
		an optional text string included as a parameter in the chat link, then passed to the callback function when the link is clicked.
		It's intended to help the calling addon distinguish which text link was clicked, in case it makes multiple links with identical display text.
	SkipFormat
		an optional boolean defaulting to false.
		If it is true, the function will use DisplayText verbatim, without applying formatting. The calling addon supplies its own formatting.
		If it is false or nil (not specified), the library will automatically enclose DisplayText in [ [ ] ] brackets and highlight it in color for visibility.
	CallbackID
		the optional event name of a callback event that is fired when the user clicks a link.
		If it is nil or omitted, an arbitrary value is generated.

Returns:
	chatlink
		a string containing the chat link.
	CallbackID
		a callback event that should be subscribed to. The event fires when the user clicks the link.
		If the caller specified an event name in the input, that value is returned; otherwise a value is generated and returned.

	If errors are encountered, returns nil for both outputs.

@TODO: callback parameters doc
The passed back parameters are:
--		DisplayText
--		Data
Both are passed back as-is.


]]
function ChatLinks:CreateChatLink(DisplayText, Data, SkipFormat, CallbackID)
	-- Validate the inputs
	if not DisplayText or "string" ~= type(DisplayText) then
		return nil, nil
	end
	if Data and "string" ~= type(Data) then
		return nil, nil
	end
	if SkipFormat and "boolean" ~= type(SkipFormat) then
		return nil, nil
	end
	if CallbackID and "string" ~= type(CallbackID) then
		return nil, nil
	end


	-- First format the text for display
	local TextPart
	if SkipFormat then
		TextPart = DisplayText
	else
		TextPart = ("|c%s[[%s]]|r"):format(ChatLinks.Highlight, DisplayText)
	end

	-- Next, assemble the data portion, which has these parts:
	--	BLIZZ_LINK_TYPE
	--	ChatLinks.LinkType
	--	Message type (public or private)
	--	Message ID
	--	Data

	-- At present, MessageType is not implemented
	local MessageType = PUBLIC

	-- The message ID is how we link the ID used in the link to the callback.
	ChatLinks.LinkCount = ChatLinks.LinkCount + 1
	local MessageID = ChatLinks.LinkCount

	-- Assemble the data portion of the link
	local DataPart = ("%s:%s:%s:%s:%s"):format(BLIZZ_LINK_TYPE, ChatLinks.LinkType, MessageType, MessageID, Data or "")

	-- Now we get the the callback ID and put it in our mapping list
	if not CallbackID then
		-- create a new, arbitrary ID
		CallbackID = string.format("%s-%s", ChatLinks.ID, MessageID)
	end
	ChatLinks.Mapping[MessageID] = CallbackID

	-- Finally, return the link and the event name.
	return ("|H%s|h%s|h"):format(DataPart, TextPart), CallbackID

	-- The calling addon has to:
	-- Print the link
	-- ChatLinks:RegisterCallback(CallbackID, method)
	--   where method is the method or function to be invoked when the user clicks the link.
end




-- When the user clicks a link in chat, the secure function SetItemRef() is invoked.
-- For "garrmission" links with an invalid ID (which our link type is), it exits silently and without error.
-- So, we can hook it to process our chatlink clicks.
hooksecurefunc("SetItemRef", function(LinkData, FullLink)
	-- for debugging
	-- print("LinkData is " .. LinkData .. ", FullLink is " .. FullLink:gsub("|", "||"))

	-- Make sure the link type that was clicked is one created by our addon.
	local ExpectedLinkType = BLIZZ_LINK_TYPE .. ":" .. ChatLinks.LinkType .. ":"
	if ExpectedLinkType ~= LinkData:sub(1, ExpectedLinkType:len()) then
		-- not our chat link, ignore
		return
	end

	-- Get the parts of the link data
	local LinkParts = LinkData.split(":")

	-- Extract the ID and the data the user originally passed in
	local MessageID = LinkParts[4]
	local Data = LinkParts[5]

	-- Get the event name to be fired
	local CallbackID = ChatLinks.Mapping[MessageID]

	-- Extract the text the user clicked.
	local DisplayText = string.match(FullLink, "^%|H.*%|h([^%|]+)%|h$")

	-- for debugging
	--print("DisplayText is " .. DisplayText)

	-- Fire the callback
	ChatLinks.callbacks:Fire(CallbackID, DisplayText, Data)

end)
