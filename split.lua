require "serialization"
require "double_array_trie"
local path = "C:/Users/coder/Desktop/HyperTelegram/IM";
local dict_file_name = path ..'/' .. 'dict.txt';
local dict_data = readfile(dict_file_name)
--print(dict_data)
--dict_data = string.sub(dict_data,1,500)
function seconds2HMS(seconds)
	local hour = math.floor(seconds / 3600);
	local minute = math.floor( (seconds - hour * 3600) / 60 );
	local second = seconds % 60;
	return hour,minute,second;
end
local dat = dat_create(297952*9);

local start_time_stamp = os.clock();
local pre_time_stamp = os.clock();
local count = 0;
--依次插入所有词
dict_data = string.gsub(dict_data,"%d+%s+(%S+).-\n",
function(words)
	count = count + 1;
	if count % 50 == 0 then
		print(count,words)
		local use_hour,use_minute,use_second =seconds2HMS(os.clock() - start_time_stamp);
		
		local average_time = (os.clock() - pre_time_stamp) / 50;
		local left_time = (297952 - count) * average_time;
		local hour,minute,second =  seconds2HMS(left_time)
		print('耗时:\t' ..use_hour ..'小时'..use_minute..'分钟' ..use_second ..'秒'
		.. '\t预计剩余',hour..'小时'..minute..'分钟', dat.count ..'/'.. dat.size 
			.. '[' ..(dat.count / dat.size * 100)% 100 .. '%]' )
		pre_time_stamp = os.clock();
	end
	dat_insert_utf8string(dat,words)
end)

print('结束:',os.clock())
print("准备序列化")
local res,err = serialize(dat);
writefile(path .. '/dat.bin',res);

local content = readfile(path ..'/' .. 'dat.bin')
local dat2 = unserialize(content);
print('反序列化结束:',os.clock())
dat_dump_all_words_utf8(dat2)

local res = dat_search_utf8string(dat,'李白')
print(res)




