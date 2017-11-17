
#include<stdlib.h>
#include<stdio.h>
#include<memory.h>
#include <string.h>
#include<string>
#include<sstream>
using std::string;

typedef unsigned char dat_uint8;
typedef unsigned int dat_uint32;
typedef unsigned short dat_uin16;
typedef char dat_int8;
typedef short dat_int16;
typedef int dat_int32;


dat_uint8 WordEndFlag = 1;
dat_uint8 AlphabetMin = 1;
dat_uint8 AlphabetMax = 256;

//数据占用bit数量
#define DATA_BIT_NUM	9
//额外信息占用bit数量
#define EXT_BIT_NUM		8


#define DATA_BIT_MASK 0x000001FF // ((1<<(DATA_BIT_NUM+))-1)
#define EXT_BIT_MASK  0x0000FE00 //


#define get_value(v)	((v) & DATA_BIT_MASK)
#define get_prop(v)		( ( (v) & EXT_BIT_MASK )>>DATA_BIT_NUM )

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

#define new_node(v) 

dat_t * dat_create(dat_int32 size)
{
	size = size <= 0 ? 1024 : size;
	dat_int32 init_size = size + 1;
	dat_t * d = (dat_t*)malloc(sizeof(dat_t));
	d->count = 0;
	d->size = init_size;
	d->base =  (dat_int32*)malloc(sizeof(dat_int32) * init_size);
	d->check = (dat_int32*)malloc(sizeof(dat_int32) * init_size);
	
	//空闲队列开始，每次都从它开始遍历, base[0]不使用，base[0]保存的是freelist的起始idx
	for (dat_int32 i = 0; i < init_size; i++)
	{
		if (i==0)
		{
			d->base[i] = -1;
			d->check[i] = -init_size;
		}
		else if (i==init_size-1)
		{
			d->base[i] = 0;
			d->check[i] = -(i - 1);
		}
		else {
			d->base[i] = -(i + 1);
			d->check[i] = -(i - 1);
		}
	}
}


dat_t * dat_realloc(dat_t *dat, float factor)
{
	dat_int32 curr_size = dat->size;
	dat_int32 new_size = curr_size * factor;

	dat_int32 *base = (dat_int32*)malloc(sizeof(dat_int32) * new_size);
	dat_int32 *check = (dat_int32*)malloc(sizeof(dat_int32) * new_size);

	//原样拷贝
	memmove(base, dat->base, sizeof(dat_int32) * dat->size);
	memmove(check, dat->check, sizeof(dat_int32) * dat->size);

	dat_int32 old_last_empty = -dat->check[0];
	base[old_last_empty] = -(dat->size + 1);//--最后一个空闲的下一个指向新分配的第一个
	for (dat_int32 i = dat->size + 1; new_size; i++)
	{
		if (i==dat->size+1)
		{
			base[i] = -(i + 1);			//下一个不变
			check[i] = -old_last_empty;	//--第一个空闲的前一个指向最后一个空闲
		}
		else if (i==new_size)
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
void dat_mark_unuse(dat_t *dat,dat_int32 i)
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

	for (dat_int32 i = 0; dat->size; i++)
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
			if (check_v ==)
			{
			}
		}
	}
}

int main()
{

	return 0;
}