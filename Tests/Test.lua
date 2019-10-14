-- Test.lua
-- Written by KyrosKrane Sylvanblade (kyros@kyros.info)
-- Test harness file for ChatLink-1.0.lua. Not for production use


local addonName, addonTable = ...

local ChatLink = LibStub("ChatLink-1.0")

function addonTable:HandleClick(Callback, DisplayText, Data)
	ChatLink:DebugPrint("In HandleClick")

	ChatLink:DebugPrint("Callback is ", Callback)
	ChatLink:DebugPrint("DisplayText is ", DisplayText)
	ChatLink:DebugPrint("Data is ", Data)
end

local function MakeLink(DisplayText, Data, SkipFormat, CallbackID)
	local Link, Callback = ChatLink:CreateChatLink(DisplayText, Data, SkipFormat, CallbackID)
	ChatLink:DebugPrint("In MakeLink, link is ", Link, ", raw link is ", Link and Link:gsub("|","||") or "nil", ", Callback is ", Callback)
	if Callback then
		ChatLink.RegisterCallback(addonTable, Callback, "HandleClick")
	end
end

function addonTable.TestLinks()
	-- Input values
	local DisplayText, Data, SkipFormat, CallbackID

	-- Sunny day scenarios

	DisplayText = "Display Text Only"
	Data = nil
	SkipFormat = nil
	CallbackID = nil
	MakeLink(DisplayText, Data, SkipFormat, CallbackID)

	DisplayText = "Display and Data"
	Data = "XX123XX"
	SkipFormat = nil
	CallbackID = nil
	MakeLink(DisplayText, Data, SkipFormat, CallbackID)

	DisplayText = "Colon Data"
	Data = "XX:123:XX"
	SkipFormat = nil
	CallbackID = nil
	MakeLink(DisplayText, Data, SkipFormat, CallbackID)

	DisplayText = "|cFFFF0000Display with Formatting!|r"
	Data = nil
	SkipFormat = true
	CallbackID = nil
	MakeLink(DisplayText, Data, SkipFormat, CallbackID)

	DisplayText = "Link with custom event"
	Data = nil
	SkipFormat = nil
	CallbackID = "MyEvent"
	MakeLink(DisplayText, Data, SkipFormat, CallbackID)

	DisplayText = "Display:with:colons and | a pipe"
	Data = nil
	SkipFormat = nil
	CallbackID = nil
	MakeLink(DisplayText, Data, SkipFormat, CallbackID)


	-- Error cases

	DisplayText = "Data with pipes"
	Data = "XX1|2||3|||4||||X"
	SkipFormat = nil
	CallbackID = nil
	MakeLink(DisplayText, Data, SkipFormat, CallbackID)

end

-- Create a sample slash command to test the addon.
SLASH_LINKS1 = "/links"
SlashCmdList.LINKS = function (...) addonTable.TestLinks(...) end
