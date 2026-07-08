#pragma once
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

typedef struct {
  uint64_t *bits;
  size_t num_bits;
} BloomFilter;

BloomFilter *bloom_create(size_t num_bits);
void bloom_destroy(BloomFilter *bf);
void bloom_add(BloomFilter *bf, uint32_t hash);
bool bloom_test(const BloomFilter *bf, uint32_t hash);
