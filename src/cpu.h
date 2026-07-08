#pragma once

#include <stdbool.h>

typedef struct {
  bool has_crc32;
  bool has_neon;
} CpuFeatures;

CpuFeatures cpu_detect(void);
