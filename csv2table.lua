local lpeg = require "lpeg"
local json = require "json"

local csv2table = {}

function csv2table.split(s,sep)
	sep = lpeg.P(sep)
  	local elem = lpeg.C((1 - sep)^0)
  	local p = lpeg.Ct(elem * (sep * elem)^0)
  	return lpeg.match(p, s)
end

local _field = '"' * lpeg.Cs(((lpeg.P(1) - '"') + lpeg.P'""' / '"')^0) * '"'  + lpeg.C(lpeg.P'{' * (lpeg.P(1) - lpeg.P'}') ^0 * lpeg.P'}') + lpeg.C(lpeg.P'[' * (lpeg.P(1) - lpeg.P']') ^0 * lpeg.P']') + lpeg.C((1 - lpeg.S',\n"')^0)
local _record = _field * (',' * _field)^0 * (lpeg.P'\n' + -1)

function csv2table.csv(s)
	local pat = lpeg.Ct(_record)
 	return lpeg.match(pat, s)
end

function csv2table.load(dir,file)
	print(dir..file)
	local fd = io.open(dir..file,"r")
 	assert(fd ~= nil)
 	local content = fd:read("*a")
 	return csv2table.parse(content,file)
end

function csv2table.parse(csv,file)
	local lines = csv2table.split(csv,'\r\n')

	local headline = lines[1]
	local typeline
	local index = 2
	if lines[2]:sub(0,1) == "*" then
		typeline = lines[2]
		index = 3
	end
	local commentline
	if lines[3]:sub(0,1) == "#" then
		commentline = lines[3]
		index = 4
	end

	local table = {}
	local headtable = csv2table.csv(headline)
	for i = index,#lines do
		if lines[i]:sub(0,1) ~= "#" then
			local ct = csv2table.csv(lines[i])
			assert(ct ~= nil,string.format("%s,line:%d,content:[%s]",file,i,lines[i]))
			if ct[1] ~= '' then
				local line = {}
				for j = 1,#headtable do
					if ct[j]:sub(1,1) == '{' or ct[j]:sub(1,1) == '[' then
						local success,result = pcall(json.decode,ct[j])
						if success == false then
							assert(false,string.format("%s,line:%d,content:[%s],sub:[%s]",file,i,lines[i],ct[j]))
						end
						line[headtable[j]]= json.decode(ct[j])
					else
						line[headtable[j]] = ct[j]
					end
				end
				line["id"] = tonumber(ct[1])
				table[ct[1]] = line
			end
		end
	end
	
	return table
end

return csv2table
