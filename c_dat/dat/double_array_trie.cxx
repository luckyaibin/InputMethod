#include<stdlib.h>
#include<stdio.h>
#include<memory.h>
#include <string.h>
#include<string>
#include<sstream>
#include<iostream>
#include<fstream>;
using std::ofstream;
using std::string;

typedef unsigned char dat_uint8;
typedef unsigned int dat_uint32;
typedef unsigned short dat_uin16;
typedef char dat_int8;
typedef short dat_int16;
typedef int dat_int32;

dat_int32 WordEndFlag = 1;
dat_int32 AlphabetMin = 1;
dat_int32 AlphabetMax = 256;
 
static dat_int32 DAT_SIGN_MASK = 0x80000000;
static dat_int32 DAT_FLAG_MASK = 0x70000000;
static dat_int32 DAT_DATA_MASK = 0x0FFFFFFF;
 
/*  最高位为符号位s，表示数据d的正负；接下来 n 比特位为标记位f，剩下的为数据位d
1 000 0000  00000000 00000000 00000000
s  f  |<-------------- d ----------->|
*/
dat_int32 get_value(dat_int32 v)
{
	if (DAT_SIGN_MASK & v)//有符号位，是负数
	{
		dat_int32 vv = (DAT_DATA_MASK & v);
		return -vv;
	}
	else
	{
		dat_int32 vv = (DAT_DATA_MASK & v);
		return vv;
	}
}

dat_int32 get_prop(dat_int32 v)
{
	dat_int32 vv = (DAT_FLAG_MASK & v);
	vv = vv >> 28;
	return vv;
}

void set_value(dat_int32 *to_addr_of_v, dat_int32 from_v)
{
	//超过了上限和下限
	if (from_v > DAT_DATA_MASK)
		exit(-100);
	if (from_v < -DAT_DATA_MASK)
		exit(-200);
	dat_int32 to_v = to_addr_of_v[0];
	dat_int32 to_v_flag = DAT_FLAG_MASK & to_v;
	dat_int32 final_v = 0;
	if (from_v >= 0)
	{
		final_v = to_v_flag | from_v;
	}
	else
	{
		final_v = to_v_flag | (-from_v);
		final_v = final_v | DAT_SIGN_MASK;
	}
	*to_addr_of_v = final_v;
}

void set_prop(dat_int32 *to_addr_of_v, dat_int32 prop_v)
{
	if (prop_v != 1 && prop_v !=0)
	{
		std::cout << "wrong prop.";
	}
	dat_int32 to_v = to_addr_of_v[0];
	dat_int32 to_v_no_flag = to_v & (~DAT_FLAG_MASK);
	to_v = to_v_no_flag | (prop_v << 28);
	*to_addr_of_v = to_v;
}

typedef struct dat_base_tag
{
	dat_uint32 flag : 1;
	dat_uint32 base : 31;
}dat_base;

typedef struct dat_tag {
	dat_int32 size;
	dat_int32 count;

	dat_int32 *base;
	dat_int32 *check;
}dat_t;


void dat_dump(dat_t *dat);

dat_t * dat_create(dat_int32 size)
{
	size = size <= 0 ? 1024 : size;
	dat_int32 init_size = size + 1;
	dat_t * d = (dat_t*)malloc(sizeof(dat_t));
	d->count = 0;
	d->size = size;
	d->base = (dat_int32*)malloc(sizeof(dat_int32)* init_size);
	d->check = (dat_int32*)malloc(sizeof(dat_int32)* init_size);

	//空闲队列开始，每次都从它开始遍历, base[0]不使用，base[0]保存的是freelist的起始idx
	for (dat_int32 i = 0; i < init_size; i++)
	{
		if (i == 0)
		{
			d->base[i] = -1;
			d->check[i] = -init_size;
		}
		else if (i == init_size - 1)
		{
			d->base[i] = 0;
			d->check[i] = -(i - 1);
		}
		else {
			d->base[i] = -(i + 1);
			d->check[i] = -(i - 1);
		}
	}
	return d;
}


dat_t * dat_realloc(dat_t *dat, float factor)
{
	//dat_dump(dat);
	dat_int32 curr_size = dat->size;
	dat_int32 new_size = curr_size * factor;

	dat_int32 *base = (dat_int32*)malloc(sizeof(dat_int32)* (new_size + 1));
	dat_int32 *check = (dat_int32*)malloc(sizeof(dat_int32)* (new_size + 1));

	//原样拷贝
	memmove(base, dat->base, sizeof(dat_int32)* (dat->size + 1));
	memmove(check, dat->check, sizeof(dat_int32)* (dat->size + 1));

	dat_int32 old_last_empty = -dat->check[0];
	base[old_last_empty] = -(dat->size + 1);//--最后一个空闲的下一个指向新分配的第一个
	for (dat_int32 i = dat->size + 1; i <= new_size; i++)
	{
		if (i == dat->size + 1)
		{
			base[i] = -(i + 1);			//下一个不变
			check[i] = -old_last_empty;	//--第一个空闲的前一个指向最后一个空闲
		}
		else if (i == new_size)
		{
			base[i] = 0;		//最后一个空闲的下一个指向0
			check[i] = -(i - 1);//--前一个
		}
		else
		{
			base[i] = -(i + 1);//
			check[i] = -(i - 1);//
		}
	}

	//如果之前从来没有空闲，那么
	if (base[0] == 0)
	{
		base[0] = -(dat->size + 1);
	}
	check[0] = -new_size;

	free(dat->base);
	free(dat->check);
	dat->base = base;
	dat->check = check;
	dat->size = new_size;
	std::cout << "重新分配完成:\n";
	//dat_dump(dat);
	return dat;
}

//使用第i个格子。
//！！！要在使用前标记。如果先使用，那么里面的值已经被改变了，无法找到前驱和后继节点了
void dat_mark_use(dat_t *dat, dat_int32 i)
{
	dat_int32 is_free = dat->check[i] <= 0;
	if (!is_free)
		return;
	dat_int32 next = -dat->base[i];
	dat_int32 pre = -dat->check[i];
	dat->base[pre] = -next;
	dat->check[next] = -pre;
}

/*释放第i个格子（让它和前后空闲格子连接起来)。
！！！要在使用后标记
i:		0		1		2		3		4
b :		-1		- 2		- 3		- 4		0
c :		-4		- 0		- 1		- 2		- 3
*/
void dat_mark_unuse0(dat_t *dat, dat_int32 i)
{
	dat_int32 pre_free = i;
	while (pre_free > 0 && dat->check[pre_free] > 0)
		pre_free = pre_free - 1;

	dat_int32 next_free = -dat->base[pre_free];
	dat->base[pre_free] = -i;
	dat->check[i] = -pre_free;
	dat->base[i] = -next_free;
	dat->check[next_free] = -i;
}

void dat_mark_unuse(dat_t *dat, dat_int32 i)
{
	dat_int32 pre_free = 0;
	while (dat->base[pre_free] <= 0)
	{
		dat_int32 nxt = -dat->base[pre_free];
		if (nxt >= i)
			break;
		else
			pre_free = nxt;
		if (pre_free == 0)
			break;
	}

	dat_int32 next_free = -dat->base[pre_free];
	dat->base[pre_free] = -i;
	dat->check[i] = -pre_free;
	dat->base[i] = -next_free;
	dat->check[next_free] = -i;
}

string tostring(int num)
{
	std::stringstream ss;
	ss << num;
	string s1 = ss.str();
	return s1;
}

void dat_dump(dat_t *dat)
{
	string index = "index:\t";
	string base = "base:\t";
	string check = "check:\t";
	string value = "value:\t";

	for (dat_int32 i = 0; i < dat->size + 1; i++)
	{
		index = index + ",\t" + tostring(i);
		dat_int32 base_v = dat->base[i];
		dat_int32 check_v = dat->check[i];
		base = base + "\t" + tostring(base_v);
		check = check + "\t" + tostring(check_v);
		//有数据
		if (check_v > 0)
		{
			dat_int32 v = get_value(base_v);
			dat_int32 p = get_prop(base_v);
			if (check_v == i)
			{
				value = value + ",\t" + tostring(v) + "[" + tostring(p) + "]";
			}
			else {
				value = value + ",\t" + tostring(i - get_value(dat->base[check_v])) + "[" + tostring(p) + "]";
			}
		}
		else {
			value = value + ",\t" + "x";
		}
	}
	string log = "dat size:" + tostring(dat->size) + "\n"
		+ "dat count:" + tostring(dat->count) + "\n"
		+ index + "\n"
		+ base + "\n"
		+ check + "\n"
		+ value + "\n\n";
	std::cout << log;
	ofstream outfile;
	outfile.open("dat_log.txt");
	outfile << log;
	outfile.close();
}

static dat_int32 children_cache[257] = { 0 };
//获得某个状态s的所有子节点
dat_int32 * dat_get_children(dat_t * dat, dat_int32 s)
{
	dat_int32 child_num = 0;
	memset(children_cache, 0, sizeof(children_cache));
	dat_int32 base_of_s = get_value(dat->base[s]);
	for (dat_int32 child_index = base_of_s + AlphabetMin; child_index <= base_of_s + AlphabetMax; child_index++)
	{
		if (child_index > 0 && child_index <= dat->size)
		{
			if (dat->check[child_index] == s && child_index != s)
			{
				children_cache[++child_num] = child_index;
			}
		}
	}
	children_cache[0] = child_num;
	return children_cache;
}



int word_id_list_sort(const void* a, const void *b)
{
	return *(dat_int32*)a - *(dat_int32*)(b);
}

//找出parent_index的所有子节点可以挪动的位置
dat_int32 dat_search_for(dat_t* dat, dat_int32 parent_index, dat_int32* word_id_list, dat_int32 skip_index)
{
	dat_int32 word_id_list_size = word_id_list[0];
	qsort(word_id_list + 1, word_id_list_size, sizeof(dat_int32), word_id_list_sort);

	dat_int32 free_curr = -dat->base[0];//空闲列表起始索引
	if (free_curr == 0)//无空闲，重新分配内存
		dat_realloc(dat, 1.5f);

	dat_int32 free_curr_try = -dat->base[0];
	while (true) {
		dat_int32 i = 1;
		dat_int32 len = word_id_list_size;
		while (i <= len)
		{
			dat_int32 word_pos = free_curr_try + word_id_list[i] - word_id_list[1];
			while (word_pos > dat->size - 1)//;超过了dat的范围，重新分配内存
				dat_realloc(dat, 1.5f);
			if (skip_index > 0 && word_pos == skip_index)
				break;
			else if (dat->check[word_pos] <= 0)//空闲
				i = i + 1;
			else if (dat->check[word_pos] == parent_index)//某个其他子节点cj。可以被某个ci覆盖，可以使用
				i = i + 1;
			else//不空闲，不满足
				break;

		}
		if (i == len + 1)//成功
			return free_curr_try;
		else
			free_curr_try = -dat->base[free_curr_try];

		if (free_curr_try == 0)//遍历到最后一个空闲的还没找到，重新分配内存
			dat_realloc(dat, 1.5f);
	}
}



//移动 parent_index 的某个子节点ci ，除修改parent_index的base值，ci的子节点d1,d2..di等的check也要修改
//移动 parent_index 的所有的转移状态 children_index_list ，到 base_index 开始的索引
//watch_index ，监测这个值移动到了哪个新位置。函数最后返回这个新位置
dat_int32 dat_relocate(dat_t* dat, dat_int32 parent_index, dat_int32* children_index_list, dat_int32 base_index, dat_int32 watch_index)
{	// s:state,b:base_index;
	dat_int32 diff = base_index - children_index_list[1];
	//diff 大于0，整体都向右移动了。需要从右向左开始遍历移动子节点,因为兄弟节点间是会覆盖的，需要注意方向。
	//diff 小于0，整体都向左移动了。相反
	dat_int32 from, to, step;
	if (diff > 0) {
		from = children_index_list[0];
		to = 1;
		step = -1;
	}
	else {
		from = 1;
		to = children_index_list[0];
		step = 1;
	}

	for (dat_int32 i = from;; i = i + step) {
		dat_int32 child_index = children_index_list[i];
		dat_int32 child_new_index = child_index + diff;
		if (watch_index == child_index)
			watch_index = child_new_index;
		dat_mark_use(dat, child_new_index);
		//1. 可能某个child是将要加入到 parent_index 的子节点， 那么child_index可能是<=0的，也可能超过dat大小
		//2. 对于某个子节点，计算出来的下标和父节点重复在一起是不可能的，那么这个子节点一定是新的子节点，还没
		//来得及加入到dat里，所以需要限制条件: check[child] ~= parent_index.
		if (child_index > 0 && (dat->check[child_index] == parent_index) && (child_index != parent_index)) {
			dat->base[child_new_index] = dat->base[child_index];//拷贝数据
			dat->check[child_new_index] = dat->check[child_index];//拷贝数据

			dat_int32 child_base = get_value(dat->base[child_index]);
			for (dat_int32 j = child_base + AlphabetMin; j <= child_base + AlphabetMax; j++)//某个子节点移动到新位置，还要修改子节点的子节点的check，指向新的位置
			{
				if (j > 0 && j <= dat->size && dat->check[j] == child_index && dat->check[j] != j)
					dat->check[j] = child_new_index;
			}
			dat_mark_unuse(dat, child_index);//释放
		}
		else {//child_index 将要成为s的子节点
			  //新节点
			dat->base[child_new_index] = 0;
			dat->check[child_new_index] = parent_index;
		}
		if (i == to)//终止
			break;
	}
	//修改父节s点的base值 :dat.base[parent_index] = dat.base[parent_index] + diff;
	dat_int32 parent_new_base_value = get_value(dat->base[parent_index]) + diff;//这里新的父节点的base值parent_new_base_value变成了是负数，设置回去就出错了
	dat_int32 parent_new_base_prop = get_prop(dat->base[parent_index]);

	//dat->base[parent_index] = 0;
	//dat->base[parent_index] = parent_new_base_value;
	dat_int32 test_base = dat->base[parent_index];
	set_value(&test_base, parent_new_base_value);
	set_prop(&test_base, parent_new_base_prop);
	if (test_base == -16)
	{
		std::cout << "it's wrong.";
	}

	set_value(&dat->base[parent_index], parent_new_base_value);
	set_prop(&dat->base[parent_index], parent_new_base_prop);

	
	return watch_index;
}

//想要把 word 插入，作为 curr_word_parent_index 的子节点，但是 curr_word_index 这个位置被占用了。
//这时候移动curr_word_parent_index的所有子节点，让出 conflict_index 这个位置。
//最后返回word被插入或挪动到的位置
dat_int32 dat_solve_conflict(dat_t* dat, dat_int32 conflict_index, dat_int32 curr_word_parent_index, dat_int32 word) {
	dat_int32 word_final_index;
	dat_int32* children_index_list = dat_get_children(dat, curr_word_parent_index);
	dat_int32 curr_word_index = get_value(dat->base[curr_word_parent_index]) + word;

	//可以根据谁的节点多少来移动哪个。这里暂时简单处理, 仅仅移动 curr_word_parent_index的子节点
	//table.insert(children_index_list, curr_word_index)--加进去
	dat_int32 count = children_index_list[0];
	children_index_list[++count] = curr_word_index;
	children_index_list[0] = count;


	dat_int32 first_ok_index = dat_search_for(dat, curr_word_parent_index, children_index_list, conflict_index);
	word_final_index = dat_relocate(dat, curr_word_parent_index, children_index_list, first_ok_index, curr_word_index);
	return word_final_index;
}

void dat_insert(dat_t* dat, dat_int32 words[]) {
	dat_int32 parent_index = 0;
	dat_int32 word_index = words[1];
	dat_int32 word = words[1];
	while (word_index > dat->size)
		dat_realloc(dat, 1.5f);

	if (dat->check[word_index] <= 0)//空闲，直接插入
	{
		dat_mark_use(dat, word_index);
		dat->base[word_index] = 0;
		dat->check[word_index] = word_index; //头结点的父节点指向自己
		parent_index = word_index;

		dat->count = dat->count + 1;
	}
	else if (dat->check[word_index] == word_index)//已存在，不处理。
		parent_index = word_index;
	else //冲突,头结点被占用了
	{
		dat_int32 curr_hold_parent = dat->check[word_index];
		dat_int32* children_index_list = dat_get_children(dat, curr_hold_parent);
		dat_int32 first_ok_index = dat_search_for(dat, curr_hold_parent, children_index_list, word_index);//让出头结点位置
		dat_int32 moved_to = dat_relocate(dat, curr_hold_parent, children_index_list, first_ok_index, word_index);

		dat_mark_use(dat, word_index);
		dat->base[word_index] = 0;
		dat->check[word_index] = word_index;//--头结点的父节点指向自己
		parent_index = word_index;
		dat->count = dat->count + 1;
	}
	for (dat_int32 i = 2; i <= words[0]; i++) {
		dat_int32 word = words[i];
		dat_int32 word_index = get_value(dat->base[parent_index]) + word;
		while (word_index > dat->size)
			dat_realloc(dat, 1.5f);
		if (word_index > 0 && dat->check[word_index] <= 0)//空闲，直接插入
		{
			dat_mark_use(dat, word_index);
			dat->base[word_index] = 0;
			dat->check[word_index] = parent_index;
			parent_index = word_index;
			dat->count = dat->count + 1;
		}
		else if (word_index > 0 &&
			dat->check[word_index] == parent_index &&
			parent_index != word_index)//已经存在了，不需要插入
		{
			parent_index = word_index;
		}
		else {//冲突处理
			parent_index = dat_solve_conflict(dat, word_index, parent_index, word);
			dat->count = dat->count + 1;
		}

		//dat_dump(dat);
	}

	set_prop(&dat->base[parent_index], WordEndFlag);
}


bool dat_search_check_prop(dat_t* dat, dat_int32* words) {
	dat_int32 parent_idx = words[1];
	if (parent_idx <= 0 || parent_idx > dat->size)
	{
		return false;
	}
	if (words[0] == 1
		&& dat->check[parent_idx] == parent_idx
		&& get_prop(dat->base[parent_idx]) == WordEndFlag)
	{
		return true;
	}

	for (dat_int32 i = 2; i <= words[0]; i++) {
		dat_int32 word = words[i];
		if (get_value(dat->base[parent_idx]) + word <= 0 || get_value(dat->base[parent_idx]) + word > dat->size)
			return false;
		if (dat->check[get_value(dat->base[parent_idx]) + word] == parent_idx)
			parent_idx = get_value(dat->base[parent_idx]) + word;
		else
			return false;
	}
	if (get_prop(dat->base[parent_idx]) == WordEndFlag)
		return true;
	else
		return false;

}

bool dat_search(dat_t* dat, dat_int32* words) {
	dat_int32 parent_idx = words[1];
	if (parent_idx <= 0 || parent_idx > dat->size)
	{
		return false;
	}
	if (words[0] == 1
		&& dat->check[parent_idx] == parent_idx)
	{
		return true;
	}

	for (dat_int32 i = 2; i <= words[0]; i++) {
		dat_int32 word = words[i];
		if (get_value(dat->base[parent_idx]) + word <= 0 || get_value(dat->base[parent_idx]) + word > dat->size)
			return false;
		if (dat->check[get_value(dat->base[parent_idx]) + word] == parent_idx)
			parent_idx = get_value(dat->base[parent_idx]) + word;
		else
			return false;
	}
	if (get_prop(dat->base[parent_idx]) == WordEndFlag)
		return true;
	else
		return false;
}

//根据某个索引，获得这个索引的字符串
std::string dat_get_words(dat_t *dat, dat_int32 idx) {
	std::string words = "";
	while (true) {
		dat_int32 parent_idx = dat->check[idx];
		if (parent_idx <= 0)//无效
			return "";// '无效位置'..idx

		dat_int32 word = 0;
		//自己是头结点，所在位置就是编码
		if (dat->check[idx] == idx)
			word = parent_idx;
		else// 子节点，用子节点位置，减去父节点的base值
			word = idx - get_value(dat->base[parent_idx]);

		words = tostring(word) + "," + words;
		if (dat->check[idx] == idx)
			break;
		idx = parent_idx;
	}
	return words;
}

void dat_dump_all_words(dat_t * dat) {
	std::string all_words = "";
	for (dat_int32 i = dat->size - 1; i >= 0; i = i - 1) {
		dat_int32* chindren = dat_get_children(dat, i);
		if (chindren[0] == 0) { //没有子节点的才算
			std::string str = dat_get_words(dat, i);
			if (str.length() > 0) {
				all_words = all_words + "\n" + str;
			}
		}
	}
	std::cout << "当前包含:" + all_words + "\n\n";
}

int main()
{
	bool is_find = true;
	dat_t* dat = dat_create(10);
	dat_dump(dat);

	dat_int32 word1[2] = { 1, 10 };
	dat_int32 word2[3] = { 2, 10, 20 };
	dat_int32 word3[4] = { 3, 10, 20, 30 };
	dat_int32 word4[5] = { 4, 40, 50, 30, 20 };
	dat_int32 word5[6] = { 5, 50, 40, 30, 20, 10 };

#define TRY_COUNT  27
	dat_int32 * each_try[TRY_COUNT] = { 0 };
	for (int try_count = 0; try_count < TRY_COUNT; try_count++)
	{
		if (try_count == 26)
		{
			std::cout << "checkt it.";
			dat_dump(dat);
		}
		dat_int32 count = rand() % 20 + 1;
		dat_int32 *word6 = (dat_int32*)malloc(sizeof(dat_int32)* (count + 1));
		word6[0] = count;
		for (dat_int32 i = 1; i <= count; i++)
		{
			dat_int32 v = rand() % 256 + 1;
			word6[i] = v;
		}
		dat_insert(dat, word6);
		is_find = dat_search(dat, word6);
		if (!is_find)
		{
			std::cout << "insert self error...";
		}
		if (try_count == 26)
		{
			std::cout << "after insert,checkt it.";
			dat_dump(dat);
		}
		each_try[try_count] = word6;//保存起来
	}

	//挨个都遍历一边，看是否插入成功
	for (int try_count = 0; try_count < TRY_COUNT; try_count++)
	{
		dat_int32 *word6 = each_try[try_count];
		if(try_count==8)
			is_find = dat_search(dat, word6);
		is_find = dat_search(dat, word6);
		if (!is_find)
		{
			std::cout << "error...";
		}
	}
	return 0;
	dat_int32 count = 10;
	dat_int32 *word6 = (dat_int32*)malloc(sizeof(dat_int32)* (count + 1));
	word6[0] = count;
	for (dat_int32 i = 1; i <= count; i++)
	{
		dat_int32 v = rand() % 256 + 1;
		word6[i] = v;
	}
	dat_insert(dat, word6);
	is_find = dat_search(dat, word6);
	dat_insert(dat, word1);
	is_find = dat_search(dat, word1);
	dat_dump_all_words(dat);
	dat_dump(dat);

	dat_insert(dat, word2);
	is_find = dat_search(dat, word1);
	is_find = dat_search(dat, word2);
	dat_dump_all_words(dat);
	dat_dump(dat);

	dat_insert(dat, word3);
	is_find = dat_search(dat, word1);
	is_find = dat_search(dat, word2);
	is_find = dat_search(dat, word3);
	dat_dump_all_words(dat);
	dat_dump(dat);

	dat_insert(dat, word4);
	is_find = dat_search(dat, word1);
	is_find = dat_search(dat, word2);
	is_find = dat_search(dat, word3);
	is_find = dat_search(dat, word4);
	dat_dump_all_words(dat);
	dat_dump(dat);

	dat_insert(dat, word5);
	is_find = dat_search(dat, word1);
	is_find = dat_search(dat, word2);
	is_find = dat_search(dat, word3);
	is_find = dat_search(dat, word4);
	is_find = dat_search(dat, word5);
	dat_dump_all_words(dat);
	dat_dump(dat);

	return 0;
}
