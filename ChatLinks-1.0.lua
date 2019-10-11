
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


--Get a random value for our self ID.
local NumDigits = 7 -- 8 causes an integer overflow
ChatLinks.ID = string.format(string.format("0x%%%d.%dX", NumDigits, NumDigits), math.random() * 16^NumDigits) -- yeah, this is a little silly.


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

-- Keep a running count of how many links we've made.
ChatLinks.NextLinkID = 0




--[[
This function creates a chat link and sets up a callback (using CallbackHandler) that will be fired when the user clicks the link.
The calling app should subscribe to the callback identifier to handle the click event, and can unsubscribe after the first click if multiple clicks are not desired.

Inputs:

	displaytext
		a required text string displayed in the user's chat that can be clicked.
	data
		an optional text string included as a parameter in the chat link, then passed to the callback function when the link is clicked.
		It's intended to help the calling addon distinguish which text link was clicked, in case it makes multiple links with identical display text.
	skipformat
		an optional boolean defaulting to false.
		If it is true, the function will use displaytext verbatim, without applying formatting. The calling addon supplies its own formatting.
		If it is false or nil (not specified), the library will automatically enclose displaytext in [ [ ] ] brackets and highlight it in color for visibility.
	clickevent
		the event name of a callback event that is fired when the user clicks a link.
		If it is nil or omitted, an arbitrary value is generated.

Returns:
	chatlink
		a string containing a chat link.
	clickevent
		a callback event that should be subscribed to. The event fires when the user clicks the link.
		If the caller specified an event name in the input, that value is returned; otherwise a value is generated and returned.

	If errors are encountered, returns nil for both parameters.

@TODO: callback parameters doc
The passed back parameters are:
--		displaytext
--		data
Both are passed back as-is. If the callback function is not accessible when the chat link is requested, this function returns nil.


]]
function ChatLinks:CreateChatLink(displaytext, data, skipformat, clickevent)
	-- Validate the inputs
	if not displaytext then
		return nil, nil
	end

	-- First format the text for display
	local TextPart
	if skipformat then
		TextPart = displaytext
	else
		TextPart = ("|c%s[[%s]]|r"):format(ChatLinks.Highlight, displaytext)
	end

	-- Next, assemble the data portion
	local DataPart = ("%s:%s:%s"):format(BLIZZ_LINK_TYPE, ChatLinks.LinkType, data or "")

	-- Now we get the callback ID
	local CallbackID
	if clickevent then
		-- use what the caller passed in.
		CallbackID = clickevent
	else
		-- create a new, arbitrary ID
		ChatLinks.NextLinkID = ChatLinks.NextLinkID + 1
		CallbackID = string.format("%s-%s", ChatLinks.ID, ChatLinks.NextLinkID)
	end

	-- After that, we set up the callback
	-- @TODO: fill this in

	-- Finally, return the link and the event name.
	return ("|H%s|h%s|h"):format(DataPart, TextPart), CallbackID
end
