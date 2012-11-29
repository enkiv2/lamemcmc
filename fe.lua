#!/usr/bin/env lua
--[[ fe.lua

Copyright (c) 2012 John Ohno

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following
conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.
	
]]--

-- If we don't seed the random number generator, we always get the same numbers
math.randomseed(os.time())

replyrate=23
saverate=10
replyratio=0.01
nick="enki-v"

-- Load serialization code
dofile("dumper.lua")

dofile("mm.lua")

function loadDB()
	-- Load the old copy of mm if we have database loading on
	if io.open("mm.db", "r")~=nil and fLoadDB==nil then dofile("mm.db") end
end

function saveDB()
	if fSaveDB==nil then 
		io.open("mm.db", "w"):write(DataDumper(mm, "mm", true))
	end
end

function exitNormal()
	saveDB()
	os.exit(0)
end

function iotrain(file)
	loadDB()
	if fTrain then -- training from files is off
		return nil
	end
	if file==nil then 
		file="stdin" 
		read=io.read 
	else 
		f=io.open(file, 'r')
		read=function (s) return f:read(s) end
	end
	if f==nil then return nil end
	print ("Reading "..file.."...")
	line=read("*l")
	while line ~= nil do
		train(line)
		line=read("*l")
	end
end

function parseFlags(arg)
	if arg=="-nl" then
		fLoadDB=true
	elseif arg=="-ns" then
		fSaveDB=true
	elseif arg=="-nt" then
		fTrain=true
	elseif arg=="-i" then
		fInteractive=true
	elseif arg=="-h" or arg=="-help" then
		print("Usage: \n\tmm [-h]\n\tmm [-nl][-ns] [-nt] [filename] [filename ...]\n\n\t\t-h\t\tPrint this help\n\t\t-nl\t\tDo not load db\n\t\t-ns\t\tDo not save db\n\t\t-nt\t\tDo not train from files\n\t\t-i\t\tInteractive mode")
		os.exit(0)
	else
		print("Could not understand flag: \""..arg.."\". Try -h for options.")
	end
end

-- Arg handling is here, actually.
function main ()
	if #arg < 1 then 
		iotrain()
	else
		loadDB()
		for _,filename in ipairs(arg) do
			if (string.find(filename, "-")==1) then 
				parseFlags(filename)
			else
				iotrain(filename)
			end
		end
		--print("Done!")
	end
	if fInteractive~=nil then interactiveMode() end
	exitNormal()
end

-- Interactive mode. Some of this is irc-specific, nick-specific, 
-- client-specific. All you really need to know is that you take lines and
-- optionally run them through bestResponse(), decide whether or not they
-- rank well enough, and then train them after responding. If you train
-- before responding, you might just repeat whatever the guy said.
function interactiveMode()
	line=io.read("*l")
	while line~=nil do
		--- epic prefixes "***" to server info lines
		if string.find(line, "\*\*\*")~=1 
			and string.find(line, "-")~=1 -- hyphen before server 
			and string.find(line, ">")~=1 -- epic prefixes ">" to
			-- lines typed by the user.
		then 
			replynick=""
			-- epic-specific again. Assume nicks are in brokets.
			if string.find(line, "<")==1 then 
				line=string.gsub(line, "^(<[^>]+> )", 
					function (c) 
						replynick=string.sub(c, 2, 
							string.len(c)-2)..": "
						if string.find(replynick, "#")~=nil then
							replynick="/msg "..string.sub(replynick, string.find(replynick, "#"), string.len(replynick)-1).." "
						end
						return ""
					end)
			end
			-- Save every ten lines, but not evenly.
			if math.random(100)<saverate then saveDB() end
			-- Convert bot commands to irc commands
			if string.find(line, "!")==1 then
				if string.find(line, "!save")==1 then
					print(replynick.."Saving...")
					saveDB()
					print(replynick.."Done!")
				elseif string.find(line, "!replyrate")==1 then
					temp=string.sub(line, string.len("!replyrate")+1)
					if tonumber(temp)~=nil then
						replyrate=tonumber(temp)
						print(replynick.."Reply rate set to "..temp.."%")
					else
						print(replynick.."Reply rate is "..replyrate.."%")
					end
				elseif string.find(line, "!autosaverate")==1 
				then
					temp=string.sub(line, string.len("!autosaverate")+1)
					if tonumber(temp)~=nil then
						saverate=tonumber(temp)
						print(replynick.."Autosave rate set to "..temp.."%")
					else
						print(replynick.."Autosave rate is "..saverate.."%")
					end
				elseif string.find(line, "!replyratio") then
					temp=string.sub(line, string.len("!replyratio")+1)
					if tonumber(temp)~=nil then
						replyratio=tonumber(temp)
						print(replynick.."Only responses with ranks under "..temp.." will now be printed.")
					else
						print(replynick.."Only responses with ranks under "..replyratio.." will be printed.")
					end
				elseif string.find(line, "!help") then
					print(replynick.."Available commands are: !help !replyrate !replyratio !nick !quit !say !save !autosaverate !join !part")
					if (string.len(line)>string.len("!help")) then
						temp=string.sub(line, 7)
						if temp=="replyrate" then
							print(replynick.."replyrate: show/set probability of replies, in percent")
						elseif temp=="replyratio" then
							print(replynick.."replyratio: show/set the maximum ranking for a response to be printed")
						elseif temp=="autosaverate" then
							print(replynick.."autosaverate: show/set probability of auto-saving per line, in percent. Set to 0 to turn off autosave.")
						elseif temp=="save" then
							print(replynick.."save: save database, if saving is on")
						elseif temp~= "" then
							print(replynick.."I cannot help you with "..temp..". Figure it out on your own.")
						end
					end
				else
					print("/"..string.sub(line, 2))
				end
				-- The program should exit too.
				if string.find(line, "quit")==2 then
					print("Saving...")
					exitNormal()
					os.exit(0)
				elseif string.find(line, "nick ")==2 then
					-- Update our internal nickname
					nick=string.sub(line, 2+string.len("nick"))
				end
			elseif math.random(100)<replyrate or 
				string.find(line, nick)==1 
			then
				if string.find(line, nick)==1 then
					tr=replyratio
					replyratio=100
				end
				s,r=bestResponse(10, 50, line)
				-- Don't be picky if your name is said
				if(r<replyratio or string.find(line, nick)==1) 
				then 
					print(replynick..s) 
				end
				if string.find(line, nick)==1 then
					replyratio=tr
				end
			end
			train(line)
		end
		io.flush()
		line=io.read("*l")
	end
end

main()
