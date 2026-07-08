#include "hash.h"
#include "cpu.h"
#include <string.h>

static uint32_t crc32c_sw(const uint8_t *p, size_t len) {
     // fallback implementation
}

#ifdef __APPLE__
static uint32_t crc32c_arm(const uint8_t *p, size_t len) {
    // __crc32cd / __crc32cw implementation
}
#endif

static CpuFeatures g_cpu;   // initialised once

void kv_hash_init(void) {   // call at engine startup
    g_cpu = cpu_detect();
}

uint32_t kv_hash(const void *key, size_t len) {
    const uint8_t *p = (const uint8_t*)key;
#ifdef __APPLE__
    if (g_cpu.has_crc32)
        return crc32c_arm(p, len);
#endif
    return crc32c_sw(p, len);
}
