require("serialization")

--存储的是utf8形式的，每个字的utf8串存到dat里
--一个字节char的范围（暂时不用1-255，都+1,方便跳过索引0）
local WordEndFlag=1;
local AlphabetMin=1;
local AlphabetMax=256;
local AlphabetCount= AlphabetMax - AlphabetMin + 1;
--创建节点，传入值和属性
function new_node(value,prop)
	prop = prop or 0;
	value = value or 0;
	return {value = value,prop = prop};
end

function copy_node(node,node_from)
	node.value = node_from.value;
	node.prop = node_from.prop;
end


function set_value(node,value)
	node.value = value;
end

function set_prop(node,prop)
	node.prop = prop;
end

--获得值
function get_value(node)
	return node.value;
end


--获得属性
function get_prop(node)
	return node.prop;
end



--初始化dat结构
function dat_create()
	local dat = {};
	dat.base = {};
	dat.check = {};
	--空闲队列开始，每次都从它开始遍历,base[0]不使用，base[0]保存的是freelist的起始idx
	local init_size = 10--AlphabetCount * 2;
	local base = dat.base;
	local check = dat.check;
	for i=0,init_size do --0 1 2 。。。init_size
		if i==0 then
			base[i] = new_node(-1);
			check[i] = new_node(-init_size);
		elseif i < init_size then--base指向下一个空闲位置，check指向前一个空闲位置。
			base[i] = new_node(-(i+1));
			check[i]= new_node(-(i-1));
		elseif i== init_size then
			base[i]= new_node(0);
			check[i]=new_node(-(i-1));
		end
	end
	dat.size = init_size;
	dat.count = 0;--子节点数量
	
	--先占满字母表，防止以后插入子节点占用头结点位置，处理起来很麻烦
	--[[for word = AlphabetMin,AlphabetMax do 
		dat_mark_use(dat,word);
		set_value(dat.base[word],AlphabetCount+1);
		set_value(dat.check[word],word);
		dat.count = dat.count+1;
	end--]]
	
	return dat
end



--重新分配内存，扩大dat容量
function dat_realloc(dat,factor)
	local curr_size = dat.size;
	factor = factor or 1.2;
	local new_size = math.ceil(curr_size*factor);
	local new_size = curr_size + AlphabetMax - 1;
	local new_dat = {};
	new_dat.base = {};
	new_dat.check = {};
	new_dat.size = new_size;
	
	--1. 原样拷贝
	for i=0,dat.size do 
		new_dat.base[i] = new_node();
		new_dat.check[i] = new_node();
		copy_node(new_dat.base[i],dat.base[i]);
		copy_node(new_dat.check[i],dat.check[i]);
	end
	local old_first_empty = -get_value(dat.base[0]);
	local old_last_empty = -get_value(dat.check[0]);
	set_value(new_dat.base[old_last_empty],-(dat.size+1));--最后一个空闲的下一个指向新分配的第一个
	local prop = 0;
	for i=dat.size+1,new_size do 
		if(i == dat.size+1) then
			new_dat.base[i] = new_node( -(i+1),prop );--下一个不变
			new_dat.check[i] = new_node( - old_last_empty,prop );--第一个空闲的前一个指向最后一个空闲
		elseif i==new_size then --最后一个空闲的下一个指向0
			new_dat.base[i] = new_node( -0,prop );
			new_dat.check[i] = new_node( -(i-1) ,prop );--前一个
		else
			new_dat.base[i] = new_node( -(i+1),prop );
			new_dat.check[i] = new_node( -(i-1) ,prop );--前一个
		end
	end
	
	if get_value(new_dat.base[0]) == 0 then
		set_value(new_dat.base[0],-(dat.size+1))
	end
	set_value(new_dat.check[0],-new_size)
	
	dat.base = new_dat.base;
	dat.check = new_dat.check;
	dat.size = new_dat.size;
	dat.count = dat.count;
	--dat_dump(dat);
	return new_dat;
end

--使用第i个格子。
--！！！要在使用前标记
function dat_mark_use(dat,i)
	local is_free = ( get_value(dat.check[i]) <= 0 );
	if not is_free then
		--dat_dump(dat)
		return;
	end
	assert(is_free, i .. ' 不是空闲格子')
	local next = - get_value(dat.base[i]);
	local pre = -get_value(dat.check[i]);
	set_value(dat.base[pre], -next);
	set_value(dat.check[next],-pre);
end
 
--释放第i个格子（让它和前后空闲格子连接起来)。
--！！！要在使用后标记
--[[
i:	0		1		2		3		4
b: 	-1		-2		-3		-4		0
c:	-4		-0		-1		-2		-3

]]
function dat_mark_unuse(dat,i)
	assert(not( get_value(dat.check[i]) <= 0),'不能释放空闲格子');
	local pre_free = i;
	while pre_free > 0 and get_value(dat.check[pre_free]) > 0 do 
		pre_free = pre_free - 1;
	end
	local next_free = -get_value(dat.base[pre_free]);
	set_value(dat.base[pre_free],-i);
	set_value(dat.check[i],-pre_free);
	set_value(dat.base[i],-next_free);
	set_value(dat.check[next_free],-i);
end

--这个比上面的更快一些
function dat_mark_unuse(dat,i)
	assert(not( get_value(dat.check[i]) <= 0),'不能释放空闲格子');
	local pre_free = 0;
	while pre_free >= 0 and get_value(dat.base[pre_free]) <= 0 do 
		local nxt = -get_value(dat.base[pre_free]);
		if nxt >= i then
			break;
		else
			pre_free = nxt;
		end
		if pre_free == 0 then
			break;
		end
	end
	local next_free = -get_value(dat.base[pre_free]);
	set_value(dat.base[pre_free],-i);
	set_value(dat.check[i],-pre_free);
	set_value(dat.base[i],-next_free);
	set_value(dat.check[next_free],-i);
end

function dat_dump(dat)
	local index = 'index:\t';
	local base = 'base:\t';
	local check = 'check:\t';
	local value = 'value:\t';
	
	for i=0,dat.size do 
		index = index .. ',\t' .. i;
		local base_v = get_value(dat.base[i]);
		local check_v = get_value(dat.check[i]);
		local prop = get_prop(dat.check[i]);
		base = base ..',\t' .. base_v;
		check = check .. ',\t' .. check_v;
		
		if check_v > 0 then
			if check_v == i then
				value = value ..',\t' ..i..'[h]';
			else
				value = value ..',\t' .. (i - get_value(dat.base[check_v]));
			end
		else
			value = value ..',\t' ..  'x';
		end
	end
	
	print('dat size:' .. dat.size ..'\n' 
		..'dat count:' .. dat.count ..'\n' 
		..index .. '\n'
		.. base .. '\n' 
		.. check .. '\n' 
		.. value);
end

--获得某个状态s的所有子节点
function dat_get_children(dat,s)
	local children = {};
	
	local children2 = {};
	local base_of_s = get_value(dat.base[s]);
	for child_index=base_of_s+AlphabetMin,base_of_s+AlphabetMax do
		if child_index > 0 and child_index <= dat.size then
			if get_value(dat.check[child_index]) == s and child_index ~= s then
				local child = child_index;
				table.insert(children,child);
			end
		end
	end
	return children;
end


--找出parent_index的所有子节点可以挪动的位置
function dat_search_for(dat,parent_index,word_id_list,skip_index)
	table.sort(word_id_list,function(a,b) return a < b end );
	local free_curr = -get_value(dat.base[0]);--空闲列表起始索引
	if free_curr == 0 then --无空闲，重新分配内存
		dat_realloc(dat);
	end
	local free_curr_try = -get_value(dat.base[0]);
	while(true) do
		local i=1;
		local len = #word_id_list;
		while i<=len do 
			local word_pos = free_curr_try + word_id_list[i] -  word_id_list[1];
			while word_pos > dat.size - 1 do--超过了dat的范围，重新分配内存
				dat_realloc(dat);
			end
			if skip_index >0 and word_pos == skip_index then 
				break;
			elseif get_value(dat.check[word_pos]) <= 0 then--空闲
				i=i+1;
			elseif get_value(dat.check[word_pos]) == parent_index then --某个其他子节点cj。可以被某个ci覆盖，可以使用
				i=i+1;
			else --不空闲，不满足
				break;
			end
		end
		if i==len+1 then--成功
			return free_curr_try;
		else
			free_curr_try = - get_value(dat.base[free_curr_try]);
		end
		if free_curr_try == 0 then --遍历到最后一个空闲的还没找到，重新分配内存
			dat_realloc(dat);
		end
	end
end

--移动 parent_index 的某个子节点ci ，除修改parent_index的base值，ci的子节点d1,d2..di等的check也要修改
--移动 parent_index 的所有的转移状态 children_index_list ，到 base_index 开始的索引
-- watch_index ，监测这个值移动到了哪个新位置。函数最后返回这个新位置
function dat_relocate(dat,parent_index,children_index_list,base_index,watch_index) -- s:state,b:base_index;
	local diff = base_index - children_index_list[1];
	--diff 大于0，整体都向右移动了。需要从右向左开始遍历移动子节点,因为兄弟节点间是会覆盖的，需要注意方向。
	--diff 小于0，整体都向左移动了。相反
	local from,to,step;
	if diff>0 then
		from = #children_index_list;
		to=1;
		step=-1;
	else
		from = 1;
		to=#children_index_list;
		step=1;
	end
	
	for i=from,to,step do 
		local child_index = children_index_list[i];
		local child_new_index = child_index + diff;
		if watch_index == child_index then
			watch_index = child_new_index;
		end
		dat_mark_use(dat,child_new_index);
		--1. 可能某个child是将要加入到 parent_index 的子节点， 那么child_index可能是<=0的，也可能超过dat大小
		--2. 对于某个子节点，计算出来的下标和父节点重复在一起是不可能的，那么这个子节点一定是新的子节点，还没
		--来得及加入到dat里，所以需要限制条件: check[child] ~= parent_index.
		if child_index > 0 and get_value(dat.check[child_index]) == parent_index  and child_index ~= parent_index then
			copy_node(dat.base[child_new_index],dat.base[child_index]);--拷贝数据
			copy_node(dat.check[child_new_index],dat.check[child_index]);--拷贝数据
			
			local child_base = get_value(dat.base[child_index]);
			for j=child_base + AlphabetMin,child_base+AlphabetMax do --某个子节点移动到新位置，还要修改子节点的子节点的check，指向新的位置
				if j > 0 and j<=dat.size and get_value(dat.check[j]) == child_index and get_value(dat.check[j])~= j then
					set_value(dat.check[j], child_new_index);
				end
			end
			dat_mark_unuse (dat,child_index);--释放
		else-- child_index 将要成为s的子节点
			--新节点
			set_value(dat.base[child_new_index],0);
			set_value(dat.check[child_new_index],parent_index)
		end
	end
	--修改父节s点的base值 :dat.base[parent_index] = dat.base[parent_index] + diff;
	set_value(dat.base[parent_index], get_value(dat.base[parent_index]) + diff);
	return watch_index;
end

--想要把 word 插入，作为 curr_word_parent_index 的子节点，但是 curr_word_index 这个位置被占用了。
--这时候移动curr_word_parent_index的所有子节点，让出 conflict_index 这个位置。
--最后返回word被插入或挪动到的位置
function dat_solve_conflict(dat,conflict_index,curr_word_parent_index,word)
	local word_final_index;
	local children_index_list = dat_get_children(dat,curr_word_parent_index)
	local curr_word_index = get_value(dat.base[curr_word_parent_index]) + word;

	--可以根据谁的节点多少来移动哪个。这里暂时简单处理,仅仅移动 curr_word_parent_index的子节点
	table.insert(children_index_list,curr_word_index)--加进去
	local first_ok_index = dat_search_for(dat,curr_word_parent_index,children_index_list,conflict_index);
	word_final_index = dat_relocate(dat,curr_word_parent_index,children_index_list,first_ok_index,curr_word_index)
	return word_final_index;
end





function dat_insert(dat,words)
	local parent_index = 0;
	local word_index = words[1];
	local word = words[1];
	while word_index > dat.size do
		dat_realloc(dat)
	end
	if get_value(dat.check[word_index]) <= 0 then --空闲，直接插入
		dat_mark_use(dat,word_index);
		set_value(dat.base[word_index],0);
		set_value(dat.check[word_index],word_index);--头结点的父节点指向自己
		parent_index = word_index;
		
		dat.count = dat.count + 1;
	elseif  get_value(dat.check[word_index]) == word_index then--已存在，不处理。
		parent_index = word_index;
	else --冲突,头结点被占用了
		local curr_hold_parent = get_value(dat.check[word_index]);
		local children_index_list = dat_get_children(dat,curr_hold_parent)
		local first_ok_index = dat_search_for(dat,curr_hold_parent,children_index_list,word_index);--让出头结点位置
		local moved_to = dat_relocate(dat,curr_hold_parent,children_index_list,first_ok_index,word_index)
		
		dat_mark_use(dat,word_index);
		set_value(dat.base[word_index],0);
		set_value(dat.check[word_index],word_index);--头结点的父节点指向自己
		parent_index = word_index;
		dat.count = dat.count + 1;
	end
	for i=2,#words do 
		local word = words[i];
		local word_index = get_value(dat.base[parent_index]) + word;
		while word_index > dat.size do
			dat_realloc(dat)
		end
		if word_index > 0 and get_value(dat.check[word_index]) <= 0 then --空闲，直接插入
			dat_mark_use(dat,word_index);
			set_value(dat.base[word_index],0);
			set_value(dat.check[word_index],parent_index);
			parent_index = word_index;
			dat.count = dat.count + 1;
		elseif word_index > 0 and get_value(dat.check[word_index]) == parent_index and parent_index ~= word_index  then --已经存在了，不需要插入
			parent_index = word_index;
		else--冲突处理
			parent_index = dat_solve_conflict(dat,word_index,parent_index,word)
			dat.count = dat.count + 1;
		end
	end
	
	set_prop(dat.base[parent_index],WordEndFlag);
end


--根据某个索引，获得这个索引的字符串
function dat_get_words(dat,idx)
	local words = '';
	while(true) do 
		local parent_idx = get_value(dat.check[idx]);
		if parent_idx <= 0 then --无效
			return '' -- '无效位置'..idx
		end
		
		local word = '';
		--自己是头结点，所在位置就是编码
		if get_value(dat.check[idx]) == idx then
			word = parent_idx;
		else--子节点，用子节点位置，减去父节点的base值
			word = idx - get_value(dat.base[parent_idx]);
		end 
		words =  word ..','.. words;
		if get_value(dat.check[idx]) == idx then
			break;
		end
		idx = parent_idx;
	end
	return words;
end

function dat_get_words_utf8(dat,idx)
	local words = '';
	while(true) do 
		local parent_idx = get_value(dat.check[idx]);
		if parent_idx <= 0 then --无效
			return '' -- '无效位置'..idx
		end
		
		local word = '';
		--自己是头结点，所在位置就是编码
		if get_value(dat.check[idx]) == idx then
			word = parent_idx;
		else--子节点，用子节点位置，减去父节点的base值
			word = idx - get_value(dat.base[parent_idx]);
		end 
		words =  string.char(word-1).. words;
		if get_value(dat.check[idx]) == idx then
			break;
		end
		idx = parent_idx;
	end
	return words;
end

function dat_dump_all_words(dat)
	local all_words = '';
	for i=dat.size-1,0,-1 do 
		local chindren = dat_get_children(dat,i);
		if #chindren == 0 then--没有子节点的才算
			local str = dat_get_words(dat,i);
			if str:len()>0 then
				all_words = all_words .. '\n' .. str;
			end
		end
	end
	print('所有字符串:',all_words)
end

function dat_dump_all_words_utf8(dat)
	local all_words = '';
	for i=dat.size-1,0,-1 do 
		local chindren = dat_get_children(dat,i);
		if #chindren == 0 then--没有子节点的才算
			local str = dat_get_words_utf8(dat,i);
			if str:len()>0 then
				all_words = all_words .. '\n' .. str;
			end
		end
	end
	print('所有字符串:',all_words)
end

function dat_search(dat,words)
	local parent_idx = words[1];
	if parent_idx <=0 or parent_idx> dat.size then
		return false;
	end
	if #words == 1 
		and get_value(dat.check[parent_idx]) == parent_idx 
		and get_prop(dat.base[parent_idx]) == WordEndFlag then
		return true;
	end
	for i=2,#words do 
		local word = words[i];
		if get_value(dat.base[parent_idx]) + word <=0 or get_value(dat.base[parent_idx]) + word > dat.size then
			return false;
		end
		if get_value(dat.check [ get_value(dat.base[parent_idx]) + word ]) == parent_idx then
			parent_idx = get_value(dat.base[parent_idx]) + word;
		else
			return false;
		end
	end
	if get_prop(dat.base[parent_idx]) == WordEndFlag then
		return true;
	else
		return false;
	end
end


function dat_insert_utf8string(dat,words)
	local parent_index = nil;
	local word_index = string.byte(words,1) + 1;
	while word_index > dat.size do
		dat_realloc(dat)
	end
	if get_value(dat.check[word_index]) <= 0 then --空闲，直接插入
		dat_mark_use(dat,word_index);
		set_value(dat.base[word_index],0);
		set_value(dat.check[word_index],word_index);--头结点的父节点指向自己
		parent_index = word_index;
		
		dat.count = dat.count + 1;
	elseif  get_value(dat.check[word_index]) == word_index then--已存在，不处理。
		parent_index = word_index;
	else --冲突,头结点被占用了
		local curr_hold_parent = get_value(dat.check[word_index]);
		local children_index_list = dat_get_children(dat,curr_hold_parent)
		local first_ok_index = dat_search_for(dat,curr_hold_parent,children_index_list,word_index);--让出头结点位置
		local moved_to = dat_relocate(dat,curr_hold_parent,children_index_list,first_ok_index,word_index)
		
		dat_mark_use(dat,word_index);
		set_value(dat.base[word_index],0);
		set_value(dat.check[word_index],word_index);--头结点的父节点指向自己
		parent_index = word_index;
		dat.count = dat.count + 1;
	end
	
	--------------
	--迭代每个utf8字符的每个字节
	local start_index = 1;
	while true do
		local char = string.sub(words,start_index,start_index);
		if char and start_index <= string.len(words) then
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
				assert(nil,c .. ' is error');
			end
			--对于每个字符c，迭代c的每个字节each_byte
			for i=start_index,start_index+len-1 do 
				local word = string.byte(words,i)+1;
				if not(start_index == 1 and i == start_index) then--第一个utf8字符的第一个字节已经特殊处理过
					local word_index = get_value(dat.base[parent_index]) + word;
					while word_index > dat.size do
						dat_realloc(dat)
					end
					if word_index > 0 and get_value(dat.check[word_index]) <= 0 then --空闲，直接插入
						dat_mark_use(dat,word_index);
						set_value(dat.base[word_index],0);
						set_value(dat.check[word_index],parent_index);
						parent_index = word_index;
						dat.count = dat.count + 1;
					elseif word_index > 0 and get_value(dat.check[word_index]) == parent_index and parent_index ~= word_index  then --已经存在了，不需要插入
						parent_index = word_index;
					else--冲突处理
						parent_index = dat_solve_conflict(dat,word_index,parent_index,word)
						dat.count = dat.count + 1;
					end
				end
				
			end
			start_index = start_index + len;
		else
			break;
		end
	end
	set_prop(dat.base[parent_index],WordEndFlag);
end

function dat_search_utf8string(dat,words)
	local parent_idx = string.byte(words,1) + 1;--头结点要特殊先判断
	if parent_idx <=0 or parent_idx> dat.size then
		return false;
	end
	if #words == 1 
		and get_value(dat.check[parent_idx]) == parent_idx 
		and get_prop(dat.base[parent_idx]) == WordEndFlag then
		return true;
	end
	
	--迭代每个utf8字符的每个字节
	local start_index = 1;
	while true do
		local char = string.sub(words,start_index,start_index);
		if char and start_index <= string.len(words) then
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
				assert(nil,c .. ' is error');
			end
			--对于每个字符c，迭代c的每个字节each_byte
			for i=start_index,start_index+len-1 do 
				local word = string.byte(words,i)+1;
				if not(start_index == 1 and i == start_index) then--第一个utf8字符的第一个字节已经特殊处理过
					if get_value(dat.base[parent_idx]) + word <=0 or get_value(dat.base[parent_idx]) + word > dat.size then
						return false;
					end
					if get_value(dat.check [ get_value(dat.base[parent_idx]) + word ]) == parent_idx then
						parent_idx = get_value(dat.base[parent_idx]) + word;
					else
						return false;
					end
				end
				
			end
			start_index = start_index + len;
		else
			break;
		end
	end
	--检查最后一个字节是不是结束标记
	if get_prop(dat.base[parent_idx]) == WordEndFlag then
		return true;
	else
		return false;
	end
end

function test_dat_utf8()
	local dat = dat_create(5);
	local test_words = {
			'中国',
			'中国人民',
			'hi',
			'hill',
			'hill church',
		};
	--依次插入所有词
	for k,v in pairs(test_words) do
		dat_insert_utf8string(dat,v)
	end
	
	print('查找开始:',os.clock())
	for i=1,1000 do 
		for k,v in pairs(test_words) do
			local find = dat_search_utf8string(dat,v);
			if not find then
				print('这个没找到:',v );
				--dat_dump(dat)
			end
		end
	end
	--dat_dump_all_words_utf8(dat)
	print('查找结束:',os.clock())
 
	dat_dump(dat)
end

function test_dat2()
	local test_words={};
	
	local start_time = os.clock();
	print('开始:',start_time)
	for test_cnt = 0,37 do--100 个词
		local word_len = math.random(1,5);--每个词1~10的长度
		local word = {};
		for i=1,word_len do 
			local w = math.random(1,256);--每个字母取值 1~1000
			table.insert(word,w);
		end
		table.insert(test_words,word);
	end
	
	
	
	for k,v in pairs(test_words) do 
		local v_str = '';
		for kk,vv in pairs(v) do 
			v_str = v_str  .. vv..',';
		end
		print('{' ,v_str,'},')
	end
	local dat = dat_create(50);
	
	local cal_time_of_count= 50;--每多少个计算一下平均用时，预估剩余时间
	local cal_time_curr_count = 0;
	local cal_time_use_time = 0;
	local cal_time_start_time = os.clock();
	--依次插入所有词
	for k,v in pairs(test_words) do
		local t1 = os.clock();
		dat_insert(dat,v)
		local t2 = os.clock();
		
		cal_time_curr_count = cal_time_curr_count + 1;
		if cal_time_curr_count >= cal_time_of_count then
			cal_time_use_time = os.clock() - cal_time_start_time;
			local average_time = cal_time_use_time / cal_time_of_count;
			local left_time = (#test_words - k) * average_time
			print('剩余时间:',math.floor((left_time)/60),'分')
			cal_time_curr_count = 0;
			cal_time_start_time = os.clock();
		end
		
		if t2-t1 >= 1 then
			print(dat.size,dat.count,'too slow',t2-t1,':',k,'->',table.concat(v,','))
		end
	end
	
	print('结束:',os.clock())
	--print("准备序列化")
	--local res,err = serialize(dat)
	--print('序列化结束:',os.clock())
	
	--writefile('dat.bin',res);
	
	--local content = readfile('dat.bin')
	--local dat = unserialize(content);
	--print('反序列化结束:',os.clock())
	
	
	for kkk=1,1 do
		for k,v in pairs(test_words) do
			local find = dat_search(dat,v);
			if not find then
				print('这个没找到:',table.concat(v,',') );
				dat_dump(dat)
			end
		end
	end
	
	print('1000词查找结束:',os.clock())
 
	dat_dump(dat)
end

function test_serilize()
	local test_words={};
	
	local start_time = os.clock();
	print('开始:',start_time)
	for test_cnt = 0,300 do--100 个词
		local word_len = math.random(1,14);--每个词1~10的长度
		local word = {};
		for i=1,word_len do 
			local w = math.random(1,256);--每个字母取值 1~1000
			table.insert(word,w);
		end
		table.insert(test_words,word);
	end

	print("准备反序列化")
	local content = readfile('dat.bin')
	local dat = unserialize(content);
	print('反序列化结束:',os.clock())
	
	
	for kkk=1,100 do
		for k,v in pairs(test_words) do
			local find = dat_search(dat,v);
			if not find then
				print('这个没找到:',table.concat(v,',') );
				dat_dump(dat)
			end
		end
	end
	
	print('1000词查找结束:',os.clock())
 
	dat_dump(dat)
end
 
test_dat_utf8();
--test_dat2();
--test_serilize()

 
