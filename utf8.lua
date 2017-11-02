--[[
UTF-8采用如下所示的二进制方式来表示31位UCS-4，X表示有效位：
1字节 0XXXXXXX
2字节 110XXXXX 10XXXXXX
3字节 1110XXXX 10XXXXXX 10XXXXXX
4字节 11110XXX 10XXXXXX 10XXXXXX 10XXXXXX
5字节 111110XX 10XXXXXX 10XXXXXX 10XXXXXX 10XXXXXX
6字节 1111110X 10XXXXXX 10XXXXXX 10XXXXXX 10XXXXXX 10XXXXXX
从上可以看得出，如果处在第一字节的引导字节最高位为0，则是一字节。否则看前导1的个数，来确定是几个字节长。前导1与有效位之间有0相隔，也可以通过首字节的值范围来确定字节数。
1字节 0  ~127
2字节 192~223
3字节 224~239
4字节 240~247
5字节 248~251
6字节 252~253
随后的字节每个都以10为前导位，取值范围则在128~191之间。可以立即得知一个字节是否为后续字节，因为引导字节的引导位不是00、01就是11，不会是10。
]]--
--获取utf8编码字符串里面字符（中文韩文英文等所有utf8编码的单个有效字符）的个数,而不是字节的长度

function get_utf8_chrctr_num(str)
	local character_num = 0;
	local start_index = 1;
	while true do
		local char = string.sub(str,start_index,start_index);
		if char and start_index <= string.len(str) then
			local c = string.byte(char);
			local len = 1;
			if 0 <= c and c <= 127 then
				len = 1;
			elseif 192 <= c and c <= 223 then
				len = 2;
			elseif 224 <= c and c <= 239 then
				len = 3;
			elseif 240 <= c and c <= 247 then
				len = 4;
			elseif 248 <= c and c <= 251 then
				len = 5;
			elseif 252 <= c and c <= 253 then
				len = 6;
			else
				print(c,'error');
			end
			--print(start_index,len,c,char);
			--print('长度',len)
			start_index = start_index + len;
			character_num = character_num + 1;
		else
			break;
		end
	end
	--print('character_num::::',character_num);
	return character_num;
end