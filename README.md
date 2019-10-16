# ChatLink-1.0
A framework for World of Warcraft addons to provide clickable chat links.

Written by KyrosKrane Sylvanblade (kyros@kyros.info)  
Copyright (c) 2019 KyrosKrane Sylvanblade  
Licensed under the MIT License, as per the included file.

This library provides tools that let you create a chat link, then react to it when the user clicks the link.
## Sample use cases
1) An addon alerts the user to an issue by adding a line to the chat. The user can click a chat link to open a window (addon frame) with more information.
2) An addon identifies a rare and puts its location in the zone general chat. Any user who also has the addon installed should be able to click the chat link to add a waypoint arrow to Tomtom (or similar).
3) A roleplaying/storytelling addon allows a group of players to create a branching text system. The "GM" pre-populates a set of story segments and responses. Each segment has key words highlighted, and when other players indicate interest in the key words, the appropriate response is given (optionally with more key words). Other players in the group can click the chat text to "respond" and hear the next segment of the story.

## Usage:
1) Add the library to your addon using LibStub (also be sure it's in your TOC file).
```lua
   local ChatLink = LibStub("ChatLink-1.0")
```

2) Create a chat link. Full documentation of the parameters is below. Optional parameters are skipped for this example.
```lua
    local DisplayText = "click here"`
    local Link, CallbackID = ChatLink:CreateChatLink(DisplayText)
```

3) If the link was created without error, register a callback so you get notified when the user clicks the link. You must have a method named MyAddon:HandleClick() defined somewhere in your addon. The method name can be whatever you want, so long as it matches what you register.
```lua
    if CallbackID then
        ChatLink.RegisterCallback(MyAddon, CallbackID, "HandleClick")
    end
```

4) Display the link to the user. 

```lua
    if Link then
        DEFAULT_CHAT_FRAME:AddMessage("You can " .. Link .. " to do the thing.")
    end
```
The user will see:
`You can [[click here]] to do the thing.`

5) When the user clicks the link, the callback you requested will be fired, and you can respond to that as you wish.
```lua
    function MyAddon:HandleClick(CallbackID, DisplayText, Data)
        DEFAULT_CHAT_FRAME:AddMessage("Now doing the thing!")
        MyAddon:DoTheThing()
    end
```
The callback parameters are:

- CallbackID
  - The same callback ID that was returned by CreateChatLink()

- DisplayText
  - The DisplayText that was passed to CreateChatLink(), as modified by that function.
  - See "SkipFormat" in the Link Creation API below for how this might differ from what was passed in.

- Data
  - The Data that was passed to CreateChatLink().
  - Data is returned unchanged.

## Link Creation API
```lua
    Link, CallbackID = ChatLink:CreateChatLink(DisplayText, Data, SkipFormat, CallbackID)
```
This function creates a chat link and sets up a callback (using CallbackHandler) that will be fired when the user clicks the link.

The calling app should subscribe to the callback identifier to handle the click event, and can unsubscribe after the first click if multiple clicks are not desired.

### Inputs:
- DisplayText
  - A required text string that will be displayed in the user's chat to click on.
  - See SkipFormat below on how this value might get modified.
- Data
  - An optional text string included as a parameter in the chat link, then passed to the callback function when the link is clicked.
  - It's intended to help the calling addon distinguish which text link was clicked, in case it makes multiple links with identical display text.
  - This must NOT include any pipe characters (|). If it does, the function returns the error values nil, nil.

- SkipFormat
  - An optional boolean defaulting to false.
  - If it is true, the function will use DisplayText verbatim, without applying formatting. The calling addon supplies its own formatting. Note that pipe symbols are NOT escapte if SkipFormat is true, which means it's up to the calling addon to ensure the pipes are correct and don't corrupt the link.
  - If it is false or nil (not specified), the library will automatically enclose DisplayText in brackets and highlight it in color for visibility. Pipe symbols will also be escaped to prevent corrupting the chat link.

- CallbackID
  - The optional event name of a callback event that is fired when the user clicks a link.
  - If it is nil or omitted, an arbitrary value is generated.
  - This should usually be omitted so that the library generates a unique value for each link.
  - If you include it, it must be globally unique across ALL addons that use ChatLink, or you may accidentally fire an event for another addon that registered the same name.
  - This feature can be used for multiple addons that coordinate to use certain event names in common, or by an addon that has to be run by multiple users who need to click each others' links.

### Returns:
- Link
  - A string containing the chat link.
  
- CallbackID
  - The callback event (string value) that should be registered. The event fires when the user clicks the link.
  - If the caller specified an event name in the input, that same value is returned; otherwise a value is generated and returned.

If errors are encountered, returns nil for both outputs.
