local lpeg = require "lpeg"
local json = require "cjson"

local _compatible = true

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

function csv2table.translate(odata)
	if _compatible == false then
		return odata
	end

	local ndata = {}

	for k,v in pairs(odata) do
		--key为number,转为string,v如果是table,必须再递归转换
		if type(k) == "number" then
			if type(v) == "table" then
				ndata[tostring(k)] = csv2table.translate(v)
			else
				ndata[tostring(k)] = v
			end
		else
			if type(v) == "table" then
				ndata[k] = csv2table.translate(v)
			else
				ndata[k] = v
			end
		end
	end
	return ndata
end

--[[
第一行为header,#为注释,*为类型
可以加个@表示此行是引用哪个表的?
]]
function csv2table.parse(csv,file)
	--找到一个表中的所有行,组成table数组
	local lines = csv2table.split(csv,'\r\n')
	--第一行,也就是key行先保存下来
	local headline = lines[1]
	
	local table = {}
	local headtable = csv2table.csv(headline)
	for i = 2,#lines do
		if lines[i]:sub(0,1) ~= "#" and lines[i]:sub(0,1) ~= "*" then
			local ct = csv2table.csv(lines[i])
			assert(ct ~= nil,string.format("%s,line:%d,content:[%s]",file,i,lines[i]))
			if ct[1] ~= '' then
				local line = {}
				for j = 1,#headtable do
					--以{或者[开头的就是json格式
					if ct[j]:sub(1,1) == '{' or ct[j]:sub(1,1) == '[' then
						local success,result = pcall(json.decode,ct[j])
						if success == false then
							assert(false,string.format("%s,line:%d,content:[%s],sub:[%s]",file,i,lines[i],ct[j]))
						end
						--为了兼容以前的老版本csv的key都是字符串,加了个translate函数
						line[headtable[j]]= csv2table.translate(json.decode(ct[j]))
					else
						--如果能转成数字,证明是数字,以number保存
						if tonumber(ct[j]) ~= nil then
							line[headtable[j]] = tonumber(ct[j])
						else
							--以空或者空格字符串,直接过滤
							if ct[j] == "" or ct[j] == " " then
								-- print(headtable[j],ct[j])
							else
								line[headtable[j]] = ct[j]
							end
						end
					end
				end

				--第一行的第一个字段,都默认为id,如果是数字侧以number保存
				if tonumber(ct[1]) ~= nil then
					line["id"] = tonumber(ct[1])
				else
					line["id"] = ct[1]
				end

				--为了兼容以前的老版本csv的key都是字符串
				if _compatible == true then
					table[tostring(ct[1])] = line
				else					
					--否则,能以数字做索引都用数字
					if tonumber(ct[1]) ~= nil then
						table[tonumber(ct[1])] = line
					else
						table[ct[1]] = line
					end
				end
			end
		end
	end
	
	return table
end

return csv2table
