#include "hash.h"

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
