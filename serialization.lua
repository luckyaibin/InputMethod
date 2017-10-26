require("class")
--序列化为服务器可以解析的LuaStream格式的数据
LuaOutputStream = class("LuaOutputStream");
LuaOutputStream.__index = LuaOutputStream;

--LuaOutputStream.TYPE_NIL 		=	-1;
LuaOutputStream.TYPE_NIL 		=	255;--类型是按照字节写入的，写入-1时候其实就是255，这个要注意！
LuaOutputStream.TYPE_FALSE 	= 	0;
LuaOutputStream.TYPE_TRUE 	= 	1;
LuaOutputStream.TYPE_POS_INT 		= 	4;--整数
LuaOutputStream.TYPE_NEG_INT 		= 	5;--负数
LuaOutputStream.TYPE_CSTR 	= 	6;
LuaOutputStream.TYPE_WSTR 	= 	7;
LuaOutputStream.TYPE_TABLE 	= 	8;
LuaOutputStream.TYPE_BYTES 	= 	9;
--LuaOutputStream.TYPE_PNG	 	= 	9;
function LuaOutputStream:init(raw_data)
	self.raw_data = raw_data or '';
	self.raw_data_cursor = 1;
end

--主要用来写入数据类型(unsigned char)
--把一个整数值转换成1字节，添加到流中(这个整数值要<=255)
function LuaOutputStream:__write_int_to_1_byte(unsigned_char)
	assert(unsigned_char<=255,'too big');
	self.raw_data = self.raw_data .. string.char(unsigned_char);
end

--主要用来写入数据长度(int)
--以整数的形式，写入4字节的数据(字符串值)
function LuaOutputStream:__write_int_to_4_byte(int)
	local P1 = math.floor(int / 0x01000000);
	int = int - P1 * 0x01000000;
	local P2 = math.floor(int / 0x00010000);
	int = int - P2 * 0x00010000;
	local P3 = math.floor(int / 0x00000100);
	int = int - P3 * 0x00000100;
	local P4 = int;
	
	--转成字符串
	P1 = string.char(P1);
	P2 = string.char(P2);
	P3 = string.char(P3);
	P4 = string.char(P4);
	--这里需要注意大小端
	--print(P1 .. P2 .. P3 .. P4)
	--print(P4 .. P3 .. P2 .. P1)
	self.raw_data = self.raw_data .. P4 .. P3 .. P2 .. P1;
end

--写入n字节的数据
function LuaOutputStream:write_n_byte(nbyte)
	self:__write_int_to_1_byte(LuaOutputStream.TYPE_BYTES);
	local byte_len = string.len(nbyte);
	self.__write_int_to_4_byte(byte_len);
	self.raw_data = self.raw_data .. nbyte;
end

--是不是宽字符串
local function is_wstr(str)
	local Len = string.len(str);
	for i=1,Len do 
		local char = string.byte(str,i);
		if char >= 127 then
			return true;
		end
	end
	return false
end

function LuaOutputStream:write_nil()
	self:__write_int_to_1_byte(255);
end

function LuaOutputStream:write_bool(bool)
	local boolean = nil;
	local v = 0;
	if bool then
		boolean = 1;
	else
		boolean = 0;
	end
	self:__write_int_to_1_byte(boolean);
end

function LuaOutputStream:write_int(int)
	if int > 0 then
		self:__write_int_to_1_byte(LuaOutputStream.TYPE_POS_INT)
		self:__write_int_to_4_byte(int);
	else
		self:__write_int_to_1_byte(LuaOutputStream.TYPE_NEG_INT)
		self:__write_int_to_4_byte(-int);
	end
end

function LuaOutputStream:write_cstr(cstr)
	self:__write_int_to_1_byte(LuaOutputStream.TYPE_CSTR);
	self.raw_data = self.raw_data .. cstr ..'\0';
end

function LuaOutputStream:write_wstr(wstr)
	self:__write_int_to_1_byte(LuaOutputStream.TYPE_WSTR);
	self.raw_data = self.raw_data ..wstr .. "\0\0";
end

function LuaOutputStream:write_bytes(bytes)
	local Len = string.len(bytes);
	self:__write_int_to_1_byte(LuaOutputStream.TYPE_BYTES);
	self:__write_int_to_4_byte(Len);
	self.raw_data = self.raw_data .. bytes;
end

function LuaOutputStream:write_table(tbl)
	local Len = 0;
	for k,v in pairs(tbl) do 
		Len = Len + 1;
	end
	self:__write_int_to_1_byte(LuaOutputStream.TYPE_TABLE);
	self:__write_int_to_4_byte(Len);
	
	local total_err = '';
	for k,v in pairs(tbl) do 
		local err1 = serialize_helper(k,self);
		if err1 ~='' then
			total_err = total_err .. err1
			break;
		end
		local err2 = serialize_helper(v,self);
		if err2 ~='' then
			total_err = total_err .. err2
			break;
		end
	end
	
	return total_err;
end


--[[t = { 	1,2,3,'hello',
['test'] = { 4,5,6 };
['tbl'] = {
'a','b',
['tbl2'] = { 7,8,9}
[1] = {...}
}
};
--]]
-- tosv 表示 table_or_simple_value ，可能是表或者普通的值
function serialize_helper(tosv,stream)
	local total_err = '';
	if type(tosv) == 'nil' then
		stream:write_nil();
	elseif type(tosv) == 'boolean' then
		stream:write_bool(tosv);
	elseif type(tosv) == 'number' then
		stream:write_int(tosv);
	elseif type(tosv) == 'string' then
		if is_wstr(tosv) then
			stream:write_wstr(tosv);
		else
			stream:write_cstr(tosv);
		end
	elseif type(tosv) == 'table' then
		local err = stream:write_table(tosv);
		total_err = total_err .. err;
	else
		total_err = total_err .. 'serializor not supported type';
	end
	return total_err
end

--tosv
function serialize(tosv)
	local ls = LuaOutputStream.new();
	ls:init();	
	local err = serialize_helper(tosv,ls);
	local ret = ls.raw_data;
	
	return ret,err;
end


--解析服务器的LuaStream格式的数据
LuaInputStream = class("LuaInputStream");
LuaInputStream.__index = LuaInputStream;

--LuaInputStream.TYPE_NIL 		=	-1;
LuaInputStream.TYPE_NIL 		=	255;--类型是按照字节写入的，写入-1时候其实就是255，这个要注意！
LuaInputStream.TYPE_FALSE 	= 	0;
LuaInputStream.TYPE_TRUE 	= 	1;
LuaInputStream.TYPE_POS_INT 		= 	4;
LuaInputStream.TYPE_NEG_INT 		= 	5;
LuaInputStream.TYPE_CSTR 	= 	6;
LuaInputStream.TYPE_WSTR 	= 	7;
LuaInputStream.TYPE_TABLE 	= 	8;
LuaInputStream.TYPE_BYTES 	= 	9;
--LuaInputStream.TYPE_PNG	 	= 	9;
function LuaInputStream:put_raw_data(raw_data)
	self.raw_data = raw_data;
	self.raw_data_cursor = 1;
end

--探测1字节的数据，返回其整数值,游标不前进
function LuaInputStream:__peek_1_byte_to_int()
	local P4 = string.sub(self.raw_data,self.raw_data_cursor,self.raw_data_cursor);
	P4 = string.byte(P4);
	return P4;
end

--读取1字节的数据，返回其整数值
function LuaInputStream:__read_1_byte_to_int()
	local P4 = string.sub(self.raw_data,self.raw_data_cursor,self.raw_data_cursor);
	P4 = string.byte(P4);
	
	self.raw_data_cursor = self.raw_data_cursor + 1;
	return P4;
end

--读取4字节的数据，返回其整数值
function LuaInputStream:__read_4_byte_to_int()
	local data_L = string.sub(self.raw_data,self.raw_data_cursor,self.raw_data_cursor + 3);
	local P1 = string.sub(data_L,1,1);
	local P2 = string.sub(data_L,2,2);
	local P3 = string.sub(data_L,3,3);
	local P4 = string.sub(data_L,4,4);
	
	--转成数字
	P1 = string.byte(P1);
	P2 = string.byte(P2);
	P3 = string.byte(P3);
	P4 = string.byte(P4);
	--这里需要注意大小端
	local int_value = P4 * 0x01000000 + P3 * 0x00010000 + P2 * 0x00000100 + P1;
	self.raw_data_cursor = self.raw_data_cursor + 4;
	return int_value;
end

--读取n字节的数据
function LuaInputStream:__read_n_byte(n)
	local nbytes = string.sub(self.raw_data,self.raw_data_cursor,self.raw_data_cursor + n-1);
	self.raw_data_cursor = self.raw_data_cursor + n;
	return nbytes;
end


function LuaInputStream:read_bool()
	local boolean = nil;
	local v = self:__read_4_byte_to_int();
	if v ~= 0 then
		boolean = true;
	else
		boolean = false;
	end
	return boolean;
end

function LuaInputStream:read_pos_int()
	local v = self:__read_4_byte_to_int();
	return v;
end

function LuaInputStream:read_cstr()
	local str = '';
	while true do
		local v = self:__read_1_byte_to_int();
		if v == 0 then
			break;
		else
			v = string.char(v);
			str = str .. v;
		end
	end
	return str;
end

function LuaInputStream:read_wstr()
	local str = '';
	while true do
		local v1 = self:__read_1_byte_to_int();
		local v2 = self:__peek_1_byte_to_int();
		if v1 == 0 and v2 == 0 then
			local _aaa = self:__read_1_byte_to_int();
			break;
		else
			str = str .. string.char(v1);
		end
	end
	--table.insert(self.curr_lua_structor,str);
	return str;
end

function LuaInputStream:read_bytes()
	local Len = self:__read_4_byte_to_int();
	local bytes = self:__read_n_byte(Len);
	return bytes;
end



--[[t = { 	1,2,3,'hello',
['test'] = { 4,5,6 };
['tbl'] = {
'a','b',
['tbl2'] = { 7,8,9}
[1] = {...}
}
};
--]]
--ls 是 luaStream
function unserialize_helper(ls)
	local total_err = '';
	local type_ = ls:__read_1_byte_to_int();
	local unserialize_value;
	if type_ == LuaInputStream.TYPE_NIL then
		unserialize_value = nil;
	elseif type_ == LuaInputStream.TYPE_FALSE then--boolean值的类型已经代表了它的数值(true 或者false)
		--unserialize_value = ls:read_bool();
		unserialize_value = false;
	elseif type_ == LuaInputStream.TYPE_TRUE then
		--unserialize_value = ls:read_bool();
		unserialize_value = true;
	elseif type_ == LuaInputStream.TYPE_POS_INT then
		unserialize_value = ls:read_pos_int();
	elseif type_ == LuaInputStream.TYPE_NEG_INT then
		unserialize_value = -ls:read_pos_int();
	elseif type_ == LuaInputStream.TYPE_CSTR then
		unserialize_value = ls:read_cstr();
	elseif type_ == LuaInputStream.TYPE_WSTR then
		unserialize_value = ls:read_wstr();
	elseif type_ == LuaInputStream.TYPE_BYTES then
		unserialize_value = ls:read_bytes();
	elseif type_ == LuaInputStream.TYPE_TABLE then
		local Len = ls:__read_4_byte_to_int();
		local tbl = {};
		for i=1,Len do
			local key,err = unserialize_helper(ls);
			if err ~= '' then
				total_err = total_err .. err;
				break;
			end
			local val,err = unserialize_helper(ls);
			if err ~= '' then
				total_err = total_err .. err;
				break;
			end
			tbl[key] = val;
		end
		unserialize_value = tbl;
	else
		unserialize_value = nil;
		total_err = total_err .. 'unserializor not supported type:' .. type_ ;
	end
	return unserialize_value, total_err;
end

--ls 是 luaStream
function unserialize(raw_data_string)
	local ls = LuaInputStream.new();
	ls:put_raw_data(raw_data_string);
	local ret,err = unserialize_helper(ls);
	return ret,err;
end

function readfile(path)
  local file = io.open(path, "rb")
  if file then
    local content = file:read("*a")
    io.close(file)
    return content
  end
  return nil
end

function writefile(path, content, mode)
  mode = mode or "w+b"
  local file = io.open(path, mode)
  if file then
    if file:write(content) == nil then return false end
    io.close(file)
    return true
  else
    return false
  end
end
