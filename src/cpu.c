#include "cpu.h"
#include <_time.h>
#ifdef __APPLE__
#include <sys/sysctl.h>
#endif

CpuFeatures cpu_detect(void){

    CpuFeatures f = {0};

    #ifdef __APPLE__
    int ret; size_t sz = sizeof(ret);
    if(sysctlbyname("hw.optional.arm.FEAT_CRC32", &ret, &sz, NULL, 0)== 0 && ret)
        f.has_crc32 = true;
    if(sysctlbyname("hw.optional.neon", &ret, &sz, NULL, 0)== 0 && ret)
        f.has_neon = true;
    #endif
       return f;

}
