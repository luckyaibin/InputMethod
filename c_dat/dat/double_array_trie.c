
#include<stdlib.h>
#include<stdio.h>

typedef unsigned char dat_uint8;
typedef unsigned int dat_uint32;
typedef unsigned short dat_uin16;
typedef char dat_int8;
typedef short dat_int16;
typedef int dat_int32;


dat_uint8 WordEndFlag = 1;
dat_uint8 AlphabetMin = 1;
dat_uint8 AlphabetMax = 256;

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
}dat;

#define new_node(v) 

dat * dat_create(dat_int32 size)
{
	size = size <= 0 ? 1024 : size;
	dat_int32 init_size = size + 1;
	dat * d = malloc(sizeof(dat));
	d->count = 0;
	d->size = init_size;
	d->base = malloc(sizeof(dat_int32) * init_size);
	d->check = malloc(sizeof(dat_int32)*init_size);

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
	}

}


int main()
{

	return 0;
}