#pragma once
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

typedef struct HashTable HashTable;

HashTable *ht_create(size_t initial_size, size_t max_key_size,
                     size_t max_value_size);
void ht_destroy(HashTable *ht);

// Insert or update. Returns true on success, false if key/value too large.
bool ht_put(HashTable *ht, const void *key, size_t key_len, const void *value,
            size_t value_len);

// Retrieves value (copies into value_out). Returns true if found.
bool ht_get(HashTable *ht, const void *key, size_t key_len, void *value_out,
            size_t *value_len_out);

bool ht_del(HashTable *ht, const void *key, size_t key_len);
bool ht_exists(HashTable *ht, const void *key, size_t key_len);

size_t ht_count(const HashTable *ht);
size_t ht_capacity(const HashTable *ht);
