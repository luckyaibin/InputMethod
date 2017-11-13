require "serialization"
require "double_array_trie"
local path = "C:/Users/coder/Desktop/HyperTelegram/IM";
local dict_file_name = path ..'/' .. 'dict.txt';
local dict_data = readfile(dict_file_name)
--print(dict_data)
--dict_data = string.sub(dict_data,1,500)

local dat = dat_create(50);
--依次插入所有词
dict_data = string.gsub(dict_data,"%d+%s+(%S+).-\n",
function(words)
	print(words)
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




