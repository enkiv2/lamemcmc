#!/usr/bin/env lua
--[[ mm.lua

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

--[[ Markov model structure:
	mm=[ "word1":[ "word2":["word3":["word1", ...], ...], ...], ...]
The special separator word is empty string, being both START and END.
	
--]]
mm={}
START=""
END=""



-- Re-initialize this because it's used in rank
if replyratio==nil then replyratio=0.01 end

--[[ Tokenize on the division between alphanumeric (%w) and non-alphanumeric 
	(%W) characters. This way, 'hello!', 'hello?', and 'hello...' are not
	all completely different single tokens. On the flipside, this 
	encourages crazy contractions like "shouldn'm" and "i't", which
	rankByBadContractions() discourages.
]]--
function split(string)
	local tokens={}
	for i,j in string.gmatch(string, "(%w*)(%W*)") do 
		--print(i)
		table.insert(tokens, i) 
		--print(j) 
		table.insert(tokens, j)
	end
	table.insert(tokens, "")
	return tokens
end

-- Train the bot
function train(string) 
	tokens=split(string)
	--print("Number of tokens: " .. #tokens)
	tc=#tokens
	w1=""
	w2=""
	w3=""
	for i=1,tc do
		-- All this is setting up the dictionary structure.
		for _,tok in pairs({tokens[i], w1, w2, w3}) do
			if mm[tok] == nil then
				mm[tok]={}
			end
		end
		if mm[w1][w2]==nil then
			mm[w1][w2]={}
		end
		if mm[w1][w2][w3]==nil then
			mm[w1][w2][w3]={}
		end
		if mm[w2][w3]==nil then
			mm[w2][w3]={}
		end
		if mm[w2][w3][tokens[i]]==nil then
			mm[w2][w3][tokens[i]]={}
		end
		-- Now we actually set up counts
		if mm[w1][w2][w3][w1]==nil then
			mm[w1][w2][w3][w1]=1
		else
			mm[w1][w2][w3][w1]=mm[w1][w2][w3][w1]+1
		end
		if mm[w2][w3][tokens[i]][w2]==nil then
			mm[w2][w3][tokens[i]][w2]=1
		else
			mm[w2][w3][tokens[i]][w2]=mm[w2][w3][tokens[i]][w2]+1
		end
		if mm[w3][tokens[i]]==nil then
			mm[w3][tokens[i]]={}
		end
		-- Ok, now set up the next iteration
		w1=w2
		w2=w3
		w3=tokens[i]
	end
end

--[[ Do markov chain monte carlo on mm. $seed is the first word in the 
	sentence (if any). $ttl is the maximum number of iterations.
--]]
function mcmc(seed, ttl)
	ret=""
	if mm[seed]==nil then return ret end -- $seed isn't actually in our db
	if ttl<1 then return ret end -- $ttl is 0 or lower.
	--if #mm[seed]<1 then return ret end -- $seed exists only as the last word
	rax={}
	rc=0 
	-- Put the total number of paths starting with $seed in $rc
	-- Also, put each one in $rax indexed by the number of paths that lead
	-- to it.
	for i in pairs(mm[seed]) do
		for j in pairs(mm[seed][i]) do
			for k,l in pairs(mm[seed][i][j]) do
				--print(i.."->"..j.."->"..k.."->"..l)
				if(k==seed) then
					rc=rc+l
					if rax[i]==nil then
						rax[i]=l
					else 
						rax[i]=rax[i]+l
					end
				end
			end
		end
	end
	--print(rc)
	ri=math.random(rc+1) -- Choose a random endpoint. The +1 is lua-only
	i=1
	-- Count until we get to endpoint number $ri, then recurse or return
	for k in pairs(mm[seed]) do
		for l in pairs(mm[seed][k]) do
			for m,n in pairs(mm[seed][k][l]) do
				for j=1,n do
					if i==ri then 
						ret=k
						if ttl>1 and l~="" then 
							return ret..l..mcmc(l, ttl-1) 
						else 
							return ret
						end
					end
					i=i+1
				end
			end
		end
	end
	return ret
end

-- Return true if a word is in the dictionary
function dictionaryWord(word)
	return (0==os.execute("grep -q '^"..word.."$' /usr/share/dict/words"))
end

-- Choose the best response from rankings
function bestResponse(n, ttl, seed)
	--print("Generating responses...")
	local responses={}
	local words=split(seed)
	local s
	for i=1, n do
		s=words[math.random(#words)+1]
		table.insert(responses, mcmc(s, ttl))
	end
	return rank(responses, seed)
end

function string_split(s, pat)
	local tmp={}
	string.gsub(s, pat, function(c) table.insert(tmp, c) return c end)
	return tmp
end

-- Rank by similarity to some input statement.
-- This can only make a response rank better, never worse.
function rankBySemdist(s, s2)
	tcount=1
	scount=1
	for w in string.gmatch(s, "([%w']+)") do
		for w2 in string.gmatch(s2, "([%w']+)") do
			if w==w2 then 
				tcount=tcount+5 
				scount=scount+1
			end
		end
	end
	return scount/tcount
end

-- Make words with apostrophes that aren't actually real contractions rank 
-- worse.
function rankByBadContractions(s)
	tcount=1
	nwcount=1
	acronyms={"don't", "won't", "can't", "shouldn't", "he's", "she's", "it's", "what's", "who's"}
	for w in string.gmatch(s, "([%w']+)") do
		tcount=tcount+1
		nf=true
		if string.find(w, "'")==nil then nf=false end
		for _,a in pairs(acronyms) do
			if a==w then nf=false end
		end
		if nf then nwcount=nwcount+2 end
	end
	return nwcount/tcount
end

-- Make responses with lots of non-dictionary-words rank worse
function rankBySpelling(s)
	tcount=2.0
	nwcount=1.0
	for w in string.gmatch(s, "(%w+)") do
		tcount=tcount+1
		if not dictionaryWord(w) then nwcount=nwcount+1 end
	end
	return (nwcount/tcount)
end

-- Rank responses from best to worst, with a higher score being worse.
-- Return the response with the smallest/best score
function rank(responses, seed)
	ranked={}
	min=replyratio
	max=-1
	
	io.stderr:write("Response candidates:\n")
	for _,s in pairs(responses) do
		io.stderr:write("\t"..s.."\n")
	end
	for _,s in pairs(responses) do
		local rank=rankByBadContractions(s)
		if(rank==nil) then rank=100000 end
		if(min==nil) then min=0 end
		-- All this rank<min stuff here is optimization. We are only
		-- concerned with good rankings, so we might as well rank in 
		-- the easiest/fastest ways first and eliminate those responses
		-- unlikely to make the grade later.
		if rank<min then
			if seed~=nil then rank=rank*rankBySemdist(s, seed) end
			if rank<min then
				rank=rank*rankBySpelling(s)
				if rank>max then max=rank end
				if rank<min then min=rank end
				io.stderr:write("\t"..tostr(rank).."\t"..s)
				if ranked[rank]==nil then
					ranked[rank]={s}
				else
					table.insert(ranked[rank], s)
				end
			end
		end
	end

	--print("("..min..") Response: "..ranked[min][1])
	if ranked[min]==nil or ranked[min][1]==nil then return "", 1000 end
	return ranked[min][1], min
end
