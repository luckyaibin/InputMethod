require("serialization")
--�����ڵ㣬����ֵ������
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

--���ֵ
function get_value(node)
	return node.value;
end


--�������
function get_prop(node)
	return node.prop;
end

--һ���ֽ�char�ķ�Χ����ʱ����1-255����+1,������������0��
local AlphabetMin=1;
local AlphabetMax=256;
local AlphabetCount= AlphabetMax - AlphabetMin + 1;


--��ʼ��dat�ṹ
function dat_create()
	local dat = {};
	dat.base = {};
	dat.check = {};
	--���ж��п�ʼ��ÿ�ζ�������ʼ����,base[0]��ʹ�ã�base[0]�������freelist����ʼidx
	local init_size = 10--AlphabetCount * 2;
	local base = dat.base;
	local check = dat.check;
	for i=0,init_size do --0 1 2 ������init_size
		if i==0 then
			base[i] = new_node(-1);
			check[i] = new_node(-init_size);
		elseif i < init_size then--baseָ����һ������λ�ã�checkָ��ǰһ������λ�á�
			base[i] = new_node(-(i+1));
			check[i]= new_node(-(i-1));
		elseif i== init_size then
			base[i]= new_node(0);
			check[i]=new_node(-(i-1));
		end
	end
	dat.size = init_size;
	dat.count = 0;--�ӽڵ�����
	
	--��ռ����ĸ����ֹ�Ժ�����ӽڵ�ռ��ͷ���λ�ã������������鷳
	--[[for word = AlphabetMin,AlphabetMax do 
		dat_mark_use(dat,word);
		set_value(dat.base[word],AlphabetCount+1);
		set_value(dat.check[word],word);
		dat.count = dat.count+1;
	end--]]
	
	return dat
end



--���·����ڴ棬����dat����
function dat_realloc(dat,factor)
	local curr_size = dat.size;
	factor = factor or 1.2;
	local new_size = math.ceil(curr_size*factor);
	local new_size = curr_size + AlphabetMax - 1;
	local new_dat = {};
	new_dat.base = {};
	new_dat.check = {};
	new_dat.size = new_size;
	
	--1. ԭ������
	for i=0,dat.size do 
		new_dat.base[i] = new_node();
		new_dat.check[i] = new_node();
		copy_node(new_dat.base[i],dat.base[i]);
		copy_node(new_dat.check[i],dat.check[i]);
	end
	local old_first_empty = -get_value(dat.base[0]);
	local old_last_empty = -get_value(dat.check[0]);
	set_value(new_dat.base[old_last_empty],-(dat.size+1));--���һ�����е���һ��ָ���·���ĵ�һ��
	local prop = 0;
	for i=dat.size+1,new_size do 
		if(i == dat.size+1) then
			new_dat.base[i] = new_node( -(i+1),prop );--��һ������
			new_dat.check[i] = new_node( - old_last_empty,prop );--��һ�����е�ǰһ��ָ�����һ������
		elseif i==new_size then --���һ�����е���һ��ָ��0
			new_dat.base[i] = new_node( -0,prop );
			new_dat.check[i] = new_node( -(i-1) ,prop );--ǰһ��
		else
			new_dat.base[i] = new_node( -(i+1),prop );
			new_dat.check[i] = new_node( -(i-1) ,prop );--ǰһ��
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

--ʹ�õ�i�����ӡ�
--������Ҫ��ʹ��ǰ���
function dat_mark_use(dat,i)
	local is_free = ( get_value(dat.check[i]) <= 0 );
	if not is_free then
		--dat_dump(dat)
		return;
	end
	assert(is_free, i .. ' ���ǿ��и���')
	local next = - get_value(dat.base[i]);
	local pre = -get_value(dat.check[i]);
	set_value(dat.base[pre], -next);
	set_value(dat.check[next],-pre);
end
 
--�ͷŵ�i�����ӣ�������ǰ����и�����������)��
--������Ҫ��ʹ�ú���
--[[
i:	0		1		2		3		4
b: 	-1		-2		-3		-4		0
c:	-4		-0		-1		-2		-3

]]
function dat_mark_unuse(dat,i)
	assert(not( get_value(dat.check[i]) <= 0),'�����ͷſ��и���');
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

--���������ĸ���һЩ
function dat_mark_unuse(dat,i)
	assert(not( get_value(dat.check[i]) <= 0),'�����ͷſ��и���');
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

--���ĳ��״̬s�������ӽڵ�
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


--�ҳ�parent_index�������ӽڵ����Ų����λ��
function dat_search_for(dat,parent_index,word_id_list,skip_index)
	table.sort(word_id_list,function(a,b) return a < b end );
	local free_curr = -get_value(dat.base[0]);--�����б���ʼ����
	if free_curr == 0 then --�޿��У����·����ڴ�
		dat_realloc(dat);
	end
	local free_curr_try = -get_value(dat.base[0]);
	while(true) do
		local i=1;
		local len = #word_id_list;
		while i<=len do 
			local word_pos = free_curr_try + word_id_list[i] -  word_id_list[1];
			while word_pos > dat.size - 1 do--������dat�ķ�Χ�����·����ڴ�
				dat_realloc(dat);
			end
			if skip_index >0 and word_pos == skip_index then 
				break;
			elseif get_value(dat.check[word_pos]) <= 0 then--����
				i=i+1;
			elseif get_value(dat.check[word_pos]) == parent_index then --ĳ�������ӽڵ�cj�����Ա�ĳ��ci���ǣ�����ʹ��
				i=i+1;
			else --�����У�������
				break;
			end
		end
		if i==len+1 then--�ɹ�
			return free_curr_try;
		else
			free_curr_try = - get_value(dat.base[free_curr_try]);
		end
		if free_curr_try == 0 then --���������һ�����еĻ�û�ҵ������·����ڴ�
			dat_realloc(dat);
		end
	end
end

--�ƶ� parent_index ��ĳ���ӽڵ�ci �����޸�parent_index��baseֵ��ci���ӽڵ�d1,d2..di�ȵ�checkҲҪ�޸�
--�ƶ� parent_index �����е�ת��״̬ children_index_list ���� base_index ��ʼ������
-- watch_index ��������ֵ�ƶ������ĸ���λ�á�������󷵻������λ��
function dat_relocate(dat,parent_index,children_index_list,base_index,watch_index) -- s:state,b:base_index;
	local diff = base_index - children_index_list[1];
	--diff ����0�����嶼�����ƶ��ˡ���Ҫ��������ʼ�����ƶ��ӽڵ�,��Ϊ�ֵܽڵ���ǻḲ�ǵģ���Ҫע�ⷽ��
	--diff С��0�����嶼�����ƶ��ˡ��෴
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
		--1. ����ĳ��child�ǽ�Ҫ���뵽 parent_index ���ӽڵ㣬 ��ôchild_index������<=0�ģ�Ҳ���ܳ���dat��С
		--2. ����ĳ���ӽڵ㣬����������±�͸��ڵ��ظ���һ���ǲ����ܵģ���ô����ӽڵ�һ�����µ��ӽڵ㣬��û
		--���ü����뵽dat�������Ҫ��������: check[child] ~= parent_index.
		if child_index > 0 and get_value(dat.check[child_index]) == parent_index  and child_index ~= parent_index then
			copy_node(dat.base[child_new_index],dat.base[child_index]);--��������
			copy_node(dat.check[child_new_index],dat.check[child_index]);--��������
			
			local child_base = get_value(dat.base[child_index]);
			for j=child_base + AlphabetMin,child_base+AlphabetMax do --ĳ���ӽڵ��ƶ�����λ�ã���Ҫ�޸��ӽڵ���ӽڵ��check��ָ���µ�λ��
				if j > 0 and j<=dat.size and get_value(dat.check[j]) == child_index and get_value(dat.check[j])~= j then
					set_value(dat.check[j], child_new_index);
				end
			end
			dat_mark_unuse (dat,child_index);--�ͷ�
		else-- child_index ��Ҫ��Ϊs���ӽڵ�
			--�½ڵ�
			set_value(dat.base[child_new_index],0);
			set_value(dat.check[child_new_index],parent_index)
		end
	end
	--�޸ĸ���s���baseֵ :dat.base[parent_index] = dat.base[parent_index] + diff;
	set_value(dat.base[parent_index], get_value(dat.base[parent_index]) + diff);
	return watch_index;
end

--��Ҫ�� word ���룬��Ϊ curr_word_parent_index ���ӽڵ㣬���� curr_word_index ���λ�ñ�ռ���ˡ�
--��ʱ���ƶ�curr_word_parent_index�������ӽڵ㣬�ó� conflict_index ���λ�á�
--��󷵻�word�������Ų������λ��
function dat_solve_conflict(dat,conflict_index,curr_word_parent_index,word)
	local word_final_index;
	local children_index_list = dat_get_children(dat,curr_word_parent_index)
	local curr_word_index = get_value(dat.base[curr_word_parent_index]) + word;

	--���Ը���˭�Ľڵ�������ƶ��ĸ���������ʱ�򵥴���,�����ƶ� curr_word_parent_index���ӽڵ�
	table.insert(children_index_list,curr_word_index)--�ӽ�ȥ
	local first_ok_index = dat_search_for(dat,curr_word_parent_index,children_index_list,conflict_index);
	word_final_index = dat_relocate(dat,curr_word_parent_index,children_index_list,first_ok_index,curr_word_index)
	return word_final_index;
end





function dat_insert(dat,words,is_dump)
	local parent_index = 0;
	local word_index = words[1];
	local word = words[1];
	while word_index > dat.size do
		dat_realloc(dat)
	end
	if get_value(dat.check[word_index]) <= 0 then --���У�ֱ�Ӳ���
		dat_mark_use(dat,word_index);
		set_value(dat.base[word_index],0);
		set_value(dat.check[word_index],word_index);--ͷ���ĸ��ڵ�ָ���Լ�
		parent_index = word_index;
		
		dat.count = dat.count + 1;
	elseif  get_value(dat.check[word_index]) == word_index then--�Ѵ��ڣ�������
		parent_index = word_index;
	else --��ͻ,ͷ��㱻ռ����
		local curr_hold_parent = get_value(dat.check[word_index]);
		local children_index_list = dat_get_children(dat,curr_hold_parent)
		local first_ok_index = dat_search_for(dat,curr_hold_parent,children_index_list,word_index);--�ó�ͷ���λ��
		local moved_to = dat_relocate(dat,curr_hold_parent,children_index_list,first_ok_index,word_index)
		
		dat_mark_use(dat,word_index);
		set_value(dat.base[word_index],0);
		set_value(dat.check[word_index],word_index);--ͷ���ĸ��ڵ�ָ���Լ�
		parent_index = word_index;
		dat.count = dat.count + 1;
	end
	local parent_index_test = parent_index;
	for i=2,#words do 
		local word = words[i];
		local word_index = get_value(dat.base[parent_index]) + word;
		while word_index > dat.size do
			dat_realloc(dat)
		end
		if word_index > 0 and get_value(dat.check[word_index]) <= 0 then --���У�ֱ�Ӳ���
			dat_mark_use(dat,word_index);
			set_value(dat.base[word_index],0);
			set_value(dat.check[word_index],parent_index);
			parent_index = word_index;
			dat.count = dat.count + 1;
		elseif word_index > 0 and get_value(dat.check[word_index]) == parent_index and parent_index ~= word_index  then --�Ѿ������ˣ�����Ҫ����
			parent_index = word_index;
		else--��ͻ����
			parent_index = dat_solve_conflict(dat,word_index,parent_index,word)
			dat.count = dat.count + 1;
		end
		parent_index_test = parent_index;
	end
end


--����ĳ���������������������ַ���
function dat_get_words(dat,idx)
	local words = '';
	while(true) do 
		local parent_idx = get_value(dat.check[idx]);
		if parent_idx <= 0 then --��Ч
			return '' -- '��Чλ��'..idx
		end
		
		local word = '';
		--�Լ���ͷ��㣬����λ�þ��Ǳ���
		if get_value(dat.check[idx]) == idx then
			word = parent_idx;
		else--�ӽڵ㣬���ӽڵ�λ�ã���ȥ���ڵ��baseֵ
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

function dat_dump_all_words(dat)
	local all_words = '';
	for i=dat.size-1,0,-1 do 
		local chindren = dat_get_children(dat,i);
		if #chindren == 0 then--û���ӽڵ�Ĳ���
			local str = dat_get_words(dat,i);
			if str:len()>0 then
				all_words = all_words .. '\n' .. str;
			end
		end
	end
	print(all_words)
end

function dat_search(dat,words)
	local parent_idx = words[1];
	if parent_idx <=0 or parent_idx> dat.size then
		return false;
	end
	if #words == 1 and get_value(dat.check[parent_idx]) == parent_idx then
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
	return true;
end

function test_dat2()
	local test_words={};
	
	local start_time = os.clock();
	print('��ʼ:',start_time)
	for test_cnt = 0,300 do--100 ����
		local word_len = math.random(1,14);--ÿ����1~10�ĳ���
		local word = {};
		for i=1,word_len do 
			local w = math.random(1,256);--ÿ����ĸȡֵ 1~1000
			table.insert(word,w);
		end
		table.insert(test_words,word);
	end
	
	
	
	for k,v in pairs({} or test_words) do 
		local v_str = '';
		for kk,vv in pairs(v) do 
			v_str = v_str  .. vv..',';
		end
		print('{' ,v_str,'},')
	end
	local dat = dat_create(5000);
	
	local cal_time_of_count= 50;--ÿ���ٸ�����һ��ƽ����ʱ��Ԥ��ʣ��ʱ��
	local cal_time_curr_count = 0;
	local cal_time_use_time = 0;
	local cal_time_start_time = os.clock();
	--���β������д�
	for k,v in pairs(test_words) do
		local t1 = os.clock();
		dat_insert(dat,v)
		local t2 = os.clock();
		
		cal_time_curr_count = cal_time_curr_count + 1;
		if cal_time_curr_count >= cal_time_of_count then
			cal_time_use_time = os.clock() - cal_time_start_time;
			local average_time = cal_time_use_time / cal_time_of_count;
			local left_time = (#test_words - k) * average_time
			print('ʣ��ʱ��:',math.floor((left_time)/60),'��')
			cal_time_curr_count = 0;
			cal_time_start_time = os.clock();
		end
		
		if t2-t1 >= 1 then
			print(dat.size,dat.count,'too slow',t2-t1,':',k,'->',table.concat(v,','))
		end
	end
	
	print('����:',os.clock())
	print("׼�����л�")
	local res,err = serialize(dat)
	print('���л�����:',os.clock())
	
	writefile('dat.bin',res);
	
	local content = readfile('dat.bin')
	local dat = unserialize(content);
	print('�����л�����:',os.clock())
	
	
	for kkk=1,100 do
		for k,v in pairs(test_words) do
			local find = dat_search(dat,v);
			if not find then
				print('���û�ҵ�:',table.concat(v,',') );
				dat_dump(dat)
			end
		end
	end
	
	print('1000�ʲ��ҽ���:',os.clock())
 
	dat_dump(dat)
end

function test_serilize()
	local test_words={};
	
	local start_time = os.clock();
	print('��ʼ:',start_time)
	for test_cnt = 0,300 do--100 ����
		local word_len = math.random(1,14);--ÿ����1~10�ĳ���
		local word = {};
		for i=1,word_len do 
			local w = math.random(1,256);--ÿ����ĸȡֵ 1~1000
			table.insert(word,w);
		end
		table.insert(test_words,word);
	end

	print("׼�������л�")
	local content = readfile('dat.bin')
	local dat = unserialize(content);
	print('�����л�����:',os.clock())
	
	
	for kkk=1,100 do
		for k,v in pairs(test_words) do
			local find = dat_search(dat,v);
			if not find then
				print('���û�ҵ�:',table.concat(v,',') );
				dat_dump(dat)
			end
		end
	end
	
	print('1000�ʲ��ҽ���:',os.clock())
 
	dat_dump(dat)
end
 
--test_dat2();
test_serilize()

 
