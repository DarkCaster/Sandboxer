#include "hash.h"
#include "cmd_defs.h"

uint32_t get_hash(uint32_t seed, const uint8_t* data, int32_t offset, int32_t len)
{
    uint32_t k=0u; //key
    uint32_t hash=seed; //seed
    int32_t fullChunks = len / 4;
    for(int32_t i=0; i<fullChunks; ++i)
    {
        k = (uint32_t)(data[offset] | data[offset+1] << 8 | data[offset+2] << 16 | data[offset+3] << 24);
        k *= 0xcc9e2d51;
        k = ( k << 15 ) | ( k >> 17 ); // k <- (k ROL r1)
        k *= 0x1b873593;
        hash ^= k;
        hash = ( hash << 13 ) | ( hash >> 19 ); // hash <- (hash ROL r2)
        hash = hash * 5 + 0xe6546b64;
        offset += 4;
    }
    int32_t remainder=len % 4;
    if(remainder>0)
    {
        k=0U;
        for(int32_t i=0; i<remainder; ++i)
            k |= (uint32_t)(data[offset+i]<<(i*8));

        k *= 0xcc9e2d51;
        k = ( k << 15 ) | ( k >> 17 ); // remainingBytes <- (remainingBytes ROL r1)
        k *= 0x1b873593;
        hash ^= k;
    }
    //Finalize hash
    hash ^= (uint32_t)len;
    hash ^= hash >> 16;
    hash *= 0x85ebca6b;
    hash ^= hash >> 13;
    hash *= 0xc2b2ae35;
    hash ^= hash >> 16;
    return hash;
}

static uint32_t read_hash(const uint8_t* buffer, int32_t offset)
{
    return u32_read(buffer,offset);
}

static void write_hash(uint8_t* const buffer, int32_t offset, uint32_t hash)
{
    u32_write(buffer,offset,hash);
}

uint8_t verify_hash(uint32_t seed, const uint8_t* buffer, int32_t offset, int32_t full_len)
{
    if(full_len<HASHSZ)
        return 0;
    if(read_hash(buffer,offset+(full_len-HASHSZ))==get_hash(seed,buffer,offset,full_len-HASHSZ))
        return 1;
    return 0;
}

int32_t append_hash(uint32_t seed, uint8_t* const buffer, int32_t offset, int32_t orig_len)
{
    if(orig_len<0)
        return orig_len;
    write_hash(buffer,offset+orig_len,get_hash(seed,buffer,offset,orig_len));
    return orig_len+HASHSZ;
}

int32_t get_hpl_len(int32_t full_len)
{
    if(full_len<HASHSZ)
        return -1;
    return full_len-HASHSZ;
}
