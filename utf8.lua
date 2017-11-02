--[[
UTF-8����������ʾ�Ķ����Ʒ�ʽ����ʾ31λUCS-4��X��ʾ��Чλ��
1�ֽ� 0XXXXXXX
2�ֽ� 110XXXXX 10XXXXXX
3�ֽ� 1110XXXX 10XXXXXX 10XXXXXX
4�ֽ� 11110XXX 10XXXXXX 10XXXXXX 10XXXXXX
5�ֽ� 111110XX 10XXXXXX 10XXXXXX 10XXXXXX 10XXXXXX
6�ֽ� 1111110X 10XXXXXX 10XXXXXX 10XXXXXX 10XXXXXX 10XXXXXX
���Ͽ��Կ��ó���������ڵ�һ�ֽڵ������ֽ����λΪ0������һ�ֽڡ�����ǰ��1�ĸ�������ȷ���Ǽ����ֽڳ���ǰ��1����Чλ֮����0�����Ҳ����ͨ�����ֽڵ�ֵ��Χ��ȷ���ֽ�����
1�ֽ� 0  ~127
2�ֽ� 192~223
3�ֽ� 224~239
4�ֽ� 240~247
5�ֽ� 248~251
6�ֽ� 252~253
�����ֽ�ÿ������10Ϊǰ��λ��ȡֵ��Χ����128~191֮�䡣����������֪һ���ֽ��Ƿ�Ϊ�����ֽڣ���Ϊ�����ֽڵ�����λ����00��01����11��������10��
]]--
--��ȡutf8�����ַ��������ַ������ĺ���Ӣ�ĵ�����utf8����ĵ�����Ч�ַ����ĸ���,�������ֽڵĳ���

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
			--print('����',len)
			start_index = start_index + len;
			character_num = character_num + 1;
		else
			break;
		end
	end
	--print('character_num::::',character_num);
	return character_num;
end