#pragma once
#include <cstdlib>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#ifdef __APPLE__

#include <arm_acle.h>
#include <arm_neon.h>

#endif

static inline void *kv_aligned_alloc(size_t alignment, size_t size) {
#ifdef _WIN2
  return _aligned_malloc(size, alignment);
#else
  return aligned_alloc(alignment, size);
#endif
}

static inline void kv_aligned_free(void *ptr) {
#ifdef _WIN32
  _aligned_free(ptr);
#else
  free(ptr);
#endif
}

#define CACHE_LINE_SIZE 128 // cache line size
