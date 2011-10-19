sdm_printPrefix = "|cffff7700Super Duper Macro|r - "
sdm_countUpdateMacrosEvents=0
sdm_validChars = {1,2,3,4,5,6,7,8,11,12,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90,92,93,94,95,96,97,98,99,100,101,102,103,104,105,106,107,108,109,110,111,112,113,114,115,116,117,118,119,120,121,122,123,124,125,126,127,128,129,130,131,132,133,134,135,136,137,138,139,140,141,142,143,144,145,146,147,148,149,150,151,152,153,154,155,156,157,158,159,160,161,162,163,164,165,166,167,168,169,170,171,172,173,174,175,176,177,178,179,180,181,182,183,184,185,186,187,188,189,190,191,192,193,194,195,196,197,198,199,200,201,202,203,204,205,206,207,208,209,210,211,212,213,214,215,216,217,218,219,220,221,222,223,224,225,226,227,228,229,230,231,232,233,234,235,236,237,238,239,240,241,242,243,244,245,246,247,248,249,250,251,252,253,254,255}
sdm_thisChar = {name=UnitName("player"), realm=GetRealmName()}
sdm_doAfterCombat={} --a collection of strings that will be run as scripts when combat ends

function sdm_SlashHandler(command)
	if command=="" then
		if sdm_mainFrame:IsShown() then
			sdm_Quit()
		else
			sdm_mainFrame:Show()
		end
	elseif command:sub(1,4):lower()=="run " then
		sdm_RunScript(command:sub(5))
	else
	  print(sdm_printPrefix.."SDM did not recognize the command \""..command.."\"")
	end
end
SlashCmdList["SUPERDUPERMACRO"] = sdm_SlashHandler;
SLASH_SUPERDUPERMACRO1 = "/sdm";

sdm_eventFrame = CreateFrame("Frame")
sdm_eventFrame:RegisterEvent("VARIABLES_LOADED")
sdm_eventFrame:RegisterEvent("UPDATE_MACROS")
sdm_eventFrame:RegisterEvent("ADDON_LOADED")
sdm_eventFrame:RegisterEvent("CHAT_MSG_ADDON")
sdm_eventFrame:SetScript("OnEvent", function (self, event, ...)
	if event=="VARIABLES_LOADED" then
		local oldVersion = sdm_version
		sdm_version=GetAddOnMetadata("SuperDuperMacro", "Version") --the version of this addon
		sdm_eventFrame:UnregisterEvent("VARIABLES_LOADED")
		if (not sdm_macros) then
			sdm_macros={} --type tokens: "b": button macro.  "f": floating macro.  "s": scripts.  "c": containers (folders)
		elseif sdm_CompareVersions(oldVersion,"1.6.1")==2 then
			if sdm_CompareVersions(oldVersion,"1.6")==2 then
				if sdm_CompareVersions(oldVersion,"1.3")==2 then
					--when updating from before 1.3:
					local oldMacros=sdm_macros
					sdm_macros={}
					local ID=1
					for i,v in ipairs(oldMacros) do
						sdm_macros[i]={type=v[1], name=v[2], text=v[3]}
						if v[4] then
							sdm_macros[i].character={name=v[4], server=v[5]}
						end
						if v[1]=="b" then
							sdm_macros[i].ID=ID
							ID=ID+1
							end
					end
				end
				--when updating from before 1.6:
				local attempt, found
				for i,v in pairs(sdm_macros) do
					if (not v.ID) then
						attempt = 0
						while true do --keep going until we find an unused ID
							found = nil
							for _,v in pairs(sdm_macros) do
								if v.ID==attempt then
									found=1
									break
								end
							end
							if not found then
								break
							end
							attempt = attempt+1
						end
						v.ID=attempt
					end
					if v.character then
						v.character.realm=v.character.server
						v.character.server=nil
					end
					v.icon=1
					if v.hideName then
						v.buttonName=" "
						v.hideName=nil
					end
					if sdm_ContainsIllegalChars(v.name) then
						v.name = "<renamed>"..v.ID
					elseif sdm_DoesNameConflict(v.name, v.type, v.character, i) then
						v.name = v.name.."<renamed>"..v.ID
					end
				end
			end
			--when updating from before 1.6.1:
			for i,v in pairs(sdm_macros) do
				if v.buttonName=="" then
					v.buttonName=" "
				end
			end
		end
		--Saving strips away numeric keys.  Now we have to put the macros back into their proper indices.
		local savedMacros = sdm_macros
		sdm_macros = {}
		for _,v in pairs(savedMacros) do
			sdm_macros[v.ID]=v
		end
		if sdm_mainContents==nil then
			sdm_ResetContainers()
		end
		sdm_iconSize=sdm_iconSize or 36
		if not sdm_listFilters then
			sdm_listFilters={b=true, f=true, s=true, global=true}
			sdm_listFilters["true"]=true
			sdm_listFilters["false"]=true
		end
		sdm_mainFrame_iconSizeSlider:SetValue(sdm_iconSize)
		sdm_mainFrame_iconSizeSlider:SetScript("OnValueChanged", function(self) sdm_iconSize = self:GetValue() sdm_UpdateList() end)
		sdm_SelectItem(nil) --We want to start with no macro selected
	elseif event=="UPDATE_MACROS" then
		sdm_countUpdateMacrosEvents=sdm_countUpdateMacrosEvents+1
		if sdm_countUpdateMacrosEvents==2 then
			sdm_eventFrame:UnregisterEvent("UPDATE_MACROS")
			local killOnSight = {}
			local macrosToDelete = {}
			local iIsPerCharacter=false
			local thisID, mTab
			for i=1,54 do --Check each macro to see if it's been orphaned by a previous installation of SDM.
				if i==37 then iIsPerCharacter=true end
				thisID = sdm_GetSdmID(i)
				mTab = sdm_macros[thisID]
				if thisID then --if the macro was created by SDM...
					if killOnSight[thisID] then --if this ID is marked as kill-on-sight, kill it.
						table.insert(macrosToDelete, i)
					elseif (not mTab) or mTab.type~="b" or (not sdm_UsedByThisChar(mTab)) then --if this ID is not in use by this character as a button macro, kill it and mark this ID as KoS
						table.insert(macrosToDelete, i)
						killOnSight[thisID]=1
					elseif (mTab.character~=nil)~=iIsPerCharacter then --if the macro is in the wrong spot based on perCharacter, kill it, but give it a chance to find one in the right spot.
						table.insert(macrosToDelete, i)
					else --This macro is good and should be here.  Kill any duplicates.
						killOnSight[thisID]=1
					end
				end
			end
			for i=getn(macrosToDelete),1,-1 do
				print(sdm_printPrefix.."Deleting extraneous macro "..macrosToDelete[i]..": "..GetMacroInfo(macrosToDelete[i]))
				DeleteMacro(macrosToDelete[i])
			end
			for i,v in pairs(sdm_macros) do
				if sdm_UsedByThisChar(sdm_macros[i]) then
					sdm_SetUpMacro(sdm_macros[i])
				end
			end
		end
	elseif event=="ADDON_LOADED" then
		local addonName = ...;
		if addonName=="Blizzard_MacroUI" then
			sdm_DefaultMacroFrameLoaded()
		end
	elseif event=="PLAYER_REGEN_ENABLED" then
		sdm_eventFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
		for _,luaText in ipairs(sdm_doAfterCombat) do
			RunScript(luaText)
		end
		sdm_doAfterCombat={}
		print(sdm_printPrefix.."Your macros are now up to date.")
	elseif event=="CHAT_MSG_ADDON" then
		sdm_InterpretAddonMessage(...)
	end
end)

function sdm_MakeMacroFrame(name, text)
	sdm_DoOrQueue("local temp = getglobal("..sdm_Stringer(name)..") or CreateFrame(\"Button\", "..sdm_Stringer(name)..", nil, \"SecureActionButtonTemplate\")\
	temp:SetAttribute(\'type\', \'macro\')\
	temp:SetAttribute(\'macrotext\', "..sdm_Stringer(text)..")")
	if string.len(text)>1023 then print(sdm_printPrefix.."The following line is "..(string.len(text)-1023).." characters too long:\n"..text) end
end

function sdm_MakeBlizzardMacro(ID, name, icon, text, perCharacter)
	sdm_DoOrQueue("local macroIndex = sdm_GetMacroIndex("..sdm_Stringer(ID)..")\
	if macroIndex then\
		EditMacro(macroIndex, "..sdm_Stringer(name)..", "..sdm_Stringer(icon)..", "..sdm_Stringer(text)..", 1, "..sdm_Stringer(perCharacter)..")\
	else\
		CreateMacro("..sdm_Stringer(name)..", "..sdm_Stringer(icon or 1)..", "..sdm_Stringer(text)..", "..sdm_Stringer(perCharacter)..", 1)\
	end")
end

function sdm_GetSdmID(macroIndex)
	local thisMacroText=GetMacroBody(macroIndex)
	if thisMacroText and thisMacroText:sub(1,4)=="#sdm" then
		return sdm_charsToNum(thisMacroText:sub(5,thisMacroText:find("\n")-1))
	else
		return nil
	end
end

function sdm_GetMacroIndex(sdmID)
	for i=1,54 do
		if sdm_GetSdmID(i)==sdmID then
			return i
		end
	end
	return nil
end

function sdm_GetLinkText(nextName)
	return "/click [btn:5]"..nextName.." Button5;[btn:4]"..nextName.." Button4;[btn:3]"..nextName.." MiddleButton;[btn:2]"..nextName.." RightButton;"..nextName
end

function sdm_SetUpMacro(mTab)
	local type = mTab.type
	if type~="b" and type~="f" then
		return
	end
	local text = mTab.text
	local perCharacter = mTab.character~=nil
	local ID = mTab.ID
	local icon = mTab.icon
	local charLimit = 255
	if type=="b" then
		text="#sdm"..sdm_numToChars(ID).."\n"..text
	end
	local nextFrameName = "sdh"..sdm_numToChars(ID)
	local frameText
	if text:len()<=charLimit then
		frameText = text
	else
		frameText = ""
		local linkText = "\n"..sdm_GetLinkText(nextFrameName)
		for line in text:gmatch("[^\r\n]+") do
			if line~="" then
				if frameText~="" then --if this is not the first line of the frame, we need to add a carriage return before it.
					line="\n"..line
				end
				if frameText:len()+line:len()+linkText:len() > charLimit then --adding this line would be too much, so just add the link and be done with it. (note that this line does NOT get removed from the master text)
					frameText = frameText..linkText
					break
				end
				frameText = frameText..line
			end
			text=text:sub((text:find("\n") or text:len())+1) --remove the line from the text
		end
	end
	sdm_SetUpMacroFrames(nextFrameName, text, 1)
	if type=="b" then
		sdm_MakeBlizzardMacro(ID, (mTab.buttonName or mTab.name), icon, frameText, perCharacter)
		sdm_MakeMacroFrame("sdb_"..mTab.name, frameText)
	elseif type=="f" then
		sdm_MakeMacroFrame("sdf_"..mTab.name, frameText)
	end
end

function sdm_SetUpMacroFrames(clickerName, text, currentLayer) --returns the frame to be clicked
	local currentFrame=1
	local frameText=""
	local nextLayerText=""
	for line in text:gmatch("[^\r\n]+") do
		if line~="" then
			if frameText~="" then --if this is not the first line of the frame, we need to add a carriage return before it.
				line="\n"..line
			end
			if (frameText:len()+line:len() > 1023) then --adding this line would be too much, so finish this frame and move on to the next.
				sdm_MakeMacroFrame(clickerName.."_"..currentLayer.."_"..currentFrame, frameText)
				if nextLayerText~="" then nextLayerText= nextLayerText.."\n" end
				nextLayerText = nextLayerText..sdm_GetLinkText(clickerName.."_"..currentLayer.."_"..currentFrame)
				frameText = ""
				currentFrame = currentFrame+1
			end
			frameText = frameText..line
		end
		text=text:sub((text:find("\n") or text:len())+1) --remove the line from the text
	end
	if currentFrame==1 then
		return sdm_MakeMacroFrame(clickerName, frameText)
	else
		sdm_MakeMacroFrame(clickerName.."_"..currentLayer.."_"..currentFrame, frameText) --repeated from above; just finishing off this frame
		nextLayerText = nextLayerText.."\n"..sdm_GetLinkText(clickerName.."_"..currentLayer.."_"..currentFrame)
		return sdm_SetUpMacroFrames(clickerName, nextLayerText, currentLayer+1)
	end
end

function sdm_CreateCancelButtonPressed()
	sdm_newFrame:Hide()
	if sdm_receiving then
		sdm_CancelReceive()
	end
end

function sdm_DoOrQueue(luaText) --If player is not in combat, runs the command. Otherwise, queues it up to be executed when combat is dropped.
	if InCombatLockdown() then
		sdm_eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
		print(sdm_printPrefix.."Changes to macros will not take effect until combat ends.")
		table.insert(sdm_doAfterCombat, luaText)
	else
		RunScript(luaText)
	end
end

function sdm_Stringer(var) --converts a variable to a string for purposes of putting it in a string for RunScript(). Strings are formatted as quoted strings, other vars are converted to strings.
	if type(var)=="string" then
		return string.format("%q", var)
	else
		return tostring(var)
	end
end

function sdm_CompareVersions(firstString, secondString) --returns 1 if the first is bigger, 2 if the second is bigger, and 0 if they are equal.
	local strings = {firstString, secondString}
	local numbers = {}
	while 1 do
		for i=1, 2 do
			if (not strings[i]) then strings[i]="0" end
			local indexOfPeriod=(strings[i]):find("%.")
			if (not indexOfPeriod) then
				numbers[i]=strings[i]
				strings[i]=nil
			else
				numbers[i]=strings[i]:sub(1, indexOfPeriod-1)
				strings[i] = strings[i]:sub(indexOfPeriod+1)
			end
			numbers[i] = tonumber(numbers[i])
		end
		if numbers[1] > numbers[2] then
			return 1
		elseif numbers[2] > numbers[1] then
			return 2
		elseif (not strings[1]) and (not strings[2]) then
			return 0
		end
	end
end

function sdm_Edit(mTab, text)
	mTab.text=text
	sdm_SetUpMacro(mTab)
	sdm_mainFrame_saveButton:Disable()
end

function sdm_CheckCreationSafety(type, name, character) --returns the mTab of the new macro, or nil if creation failed
	if name=="" then
		print(sdm_printPrefix.."Invalid name")
		return false
	end
	if (type=="b" or type=="f") and sdm_ContainsIllegalChars(name, true) then
		return false
	end
	if (not character) and GetMacroInfo(36) then
		print(sdm_printPrefix.."You already have 36 global macros.")
		return false
	elseif character and character.name==sdm_thisChar.name and character.realm==sdm_thisChar.realm and GetMacroInfo(54) then
		print(sdm_printPrefix.."You already have 18 character-specific macros.")
		return false
	end
	local conflict = sdm_DoesNameConflict(name, type, character, nil, true)
	if conflict then
		return false
	end
	return true
end

function sdm_GetEmptySlot() -- returns the lowest unused index in sdm_macros
	local result = 0
	while sdm_macros[result] do --keep going until we find an empty slot
		result = result+1
	end
	return result
end

function sdm_CreateNew(type, name, character) --returns the mTab of the new macro
	local mTab = {}
	mTab.ID = sdm_GetEmptySlot()
	while sdm_macros[mTab.ID] do --keep going until we find an empty slot
		mTab.ID = mTab.ID+1
	end
	sdm_macros[mTab.ID]=mTab
	mTab.type=type
	mTab.name=name
	if type=="c" then
		mTab.open = true
		mTab.contents = {}
	else
		mTab.icon=1
		if sdm_receiving and sdm_receiving.text then
			mTab.text=sdm_receiving.text
			mTab.icon=sdm_receiving.icon
			SendAddonMessage("SDM recDone", "", "WHISPER", sdm_receiving.playerName)
			sdm_EndReceiving("|cff44ff00Saved|r")
		else
			if type=="s" then
				mTab.text="-- Enter lua commands here."
			elseif type=="b" or type=="f" then
				mTab.text="# Enter macro text here."
			else --this shouldn't happen
				mTab.text=""
			end
		end
		mTab.character=character
		sdm_SetUpMacro(mTab)
	end
	sdm_ChangeContainer(mTab, nil)
	return mTab
end

function sdm_UpgradeMacro() -- Upgrades the currently selected standard macro to a Super Duper macro
	if InCombatLockdown() then
		print(sdm_printPrefix.."You can't upgrade a macro during combat.")
		return
	end
	local index = MacroFrame.selectedMacro
	if index==nil then
		print(sdm_printPrefix.."You must select a standard macro first.")
		return
	end
	local name, texture = GetMacroInfo(index)
	local character
	if index > 36 then
		character = sdm_thisChar
	end
	local safe = sdm_CheckCreationSafety("b", name, character)
	if not safe then
		return -- the creation failed
	end
	MacroSaveButton:Click()
	local body = GetMacroBody(index)
	EditMacro(index, nil, nil, "#sdm"..sdm_numToChars(sdm_GetEmptySlot()).."\n#placeholder") -- let SDM know that this is the macro to edit
	local iconIndex = 1
	for iii = 1,GetNumMacroIcons() do
		if GetMacroIconInfo(iii) == texture then -- find out if there's a more efficient way of getting this. This must be done AFTER the macro body is cleared, or the question mark could show up as something else.
			iconIndex = iii
			break
		end
	end
	local newMacro = sdm_CreateNew("b", name, character)
	newMacro.icon = iconIndex
	sdm_Edit(newMacro, body)
	MacroFrame_linkToSDM:Click() -- show the SDM frame
	sdm_SelectItem(newMacro.ID) -- select the newly upgraded macro
	MacroFrame.selectedMacro = nil -- deselect the macro in the standard macro frame
end

function sdm_RunScript(name)
	local luaText = nil
	for i,v in pairs(sdm_macros) do
		if v.type=="s" and v.name==name and sdm_UsedByThisChar(v) then
			luaText=v.text
			break
		end
	end
	if luaText then
		RunScript(luaText)
	else
		print(sdm_printPrefix.."SDM could not find a script named \""..name.."\".")
	end
end

function sdm_DoesNameConflict(name, type, char, ignoring, printWarning) --returns a conflict if we find a macro of the same type and name that can be seen for a given character.  If no character is passed, we it's assumed to be global.  If we are passed <ignoring>, we will skip that particular macro index while checking.
	for i,v in pairs(sdm_macros) do
		if v.type~="c" and i~=ignoring and v.type==type and v.name==name and ((not char) or (not sdm_macros[i].character) or (char.name==sdm_macros[i].character.name and char.realm==sdm_macros[i].character.realm)) then --If they're the same name and type, we can only return false if they're both specific to different characters.
			if printWarning then
				print(sdm_printPrefix.."You may not have more than one of the same type with the same name (unless they are specific to different characters).")
			end
			return i
		end
	end
end

function sdm_ContainsIllegalChars(s, printWarning) --s is the string to evaluate, printWarning is a boolean
	local b, found
	for i=1,s:len() do
		b = s:byte(i)
		found = false
		for _,v in ipairs(sdm_validChars) do
			if b==v then
				found=true
				break
			end
		end
		if not found then
			local badChar = s:sub(i,i)
			if printWarning then
				print(sdm_printPrefix.."You may not use the character \""..badChar.."\" in the name.  If this is a button macro, you might be able to use that character in the name displayed on the button (click \"Change Name/Icon\").")
			end
			return badChar
		end
	end
end

function sdm_UsedByThisChar(mTab) --returns true if the macro is global or specific to this character.  Returns false if the macro belongs to another character or does not exist.
	if not mTab then
		return false
	end
	return (not mTab.character or (mTab.character.name==sdm_thisChar.name and mTab.character.realm==sdm_thisChar.realm))
end

function sdm_numToChars(num) --converts a number into a string (with maximum compression)
	local base = getn(sdm_validChars) --the counting system we're working in.  sdm_validChars[1] is the digit for 0, [2] is the digit for 1, and so on.
	local place=0 --the power on the base that you multiply by the digit to get the value (0 is the ones place)
	while num >= math.pow(base, place+1) do
		place=place+1
	end
	local chars=""
	local count=0
	local digit
	local value
	while place>=0 do
		digit=base
		while digit>0 do
			digit=digit-1
			value = digit*math.pow(base, place)
			if count+value<=num then
				break
			end
		end
		count=count+value
		chars=chars..string.format("%c",sdm_validChars[digit+1])
		place=place-1
	end
	if count~=num then return nil end --this should never happen
	return chars
end

function sdm_charsToNum(chars) --converts characters back into a number
	local base = getn(sdm_validChars)
	local num = 0
	local found
	for i=1,chars:len() do
		found = false
		for j,v in ipairs(sdm_validChars) do
			if chars:byte(i)==v then
				num = num + (j-1)*math.pow(base, (chars:len()-i))
				found = true
				break
			end
		end
		if not found then return nil end --this shouldn't happen unless we give bad chars
	end
	return num
end