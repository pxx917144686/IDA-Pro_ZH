#ifndef PXX_ANTI_REVERSE_H
#define PXX_ANTI_REVERSE_H

#include <Foundation/Foundation.h>
#include <dlfcn.h>
#include <sys/types.h>
#include <sys/ptrace.h>
#include <sys/sysctl.h>
#include <sys/mman.h>
#include <mach/mach.h>
#include <mach/mach_host.h>
#include <mach/task.h>
#include <mach/vm_map.h>
#include <signal.h>
#include <setjmp.h>
#include <execinfo.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <stdarg.h>

#define PXX_XOR_KEY_BASE 0xA5C3
#define PXX_PTR_XOR_KEY  0x7F3E9D2C

static __inline__ int pxx_xor_strlen(const char *s) {
    int len = 0;
    while (s[len] != 0) len++;
    return len;
}

static __inline__ char *pxx_decrypt_string(const char *enc, int len) {
    char *buf = (char *)malloc(len + 1);
    if (!buf) return NULL;
    unsigned short key = PXX_XOR_KEY_BASE;
    for (int i = 0; i < len; i++) {
        key = (key * 1103515245 + 12345) & 0xFFFF;
        buf[i] = enc[i] ^ (key & 0xFF);
    }
    buf[len] = '\0';
    return buf;
}

#define PXX_ENCSTR(dec) ({ \
    const char *_enc = dec; \
    int _len = pxx_xor_strlen(_enc); \
    char *_result = pxx_decrypt_string(_enc, _len); \
    _result; \
})

static __inline__ int pxx_opaque_true(void) {
    volatile int x = 0;
    for (int i = 0; i < 37; i++) {
        x += (i * 7 + 3) % 11;
    }
    return (x > 0) ? 1 : 1;
}

static __inline__ int pxx_opaque_false(void) {
    volatile int x = 0;
    for (int i = 0; i < 37; i++) {
        x += (i * 7 + 3) % 11;
    }
    return (x < 0) ? 1 : 0;
}

#define PXX_IF(cond) if ((cond) && pxx_opaque_true())
#define PXX_IF_NOT(cond) if (!(cond) || pxx_opaque_false())

static __inline__ BOOL pxx_is_debugged_sysctl(void) {
    struct kinfo_proc info;
    size_t info_size = sizeof(info);
    int name[4];
    name[0] = CTL_KERN;
    name[1] = KERN_PROC;
    name[2] = KERN_PROC_PID;
    name[3] = getpid();
    if (sysctl(name, 4, &info, &info_size, NULL, 0) == -1) {
        return NO;
    }
    return (info.kp_proc.p_flag & P_TRACED) != 0;
}

static __inline__ BOOL pxx_is_debugged_ptrace(void) {
    int ret = ptrace(PT_DENY_ATTACH, 0, 0, 0);
    return ret == -1;
}

static __inline__ void pxx_suicide(void) {
    volatile int junk = 0;
    for (int i = 0; i < 500; i++) {
        junk += (i * 13 + 7) % 23;
    }
    if (pxx_opaque_true()) {
        kill(getpid(), SIGKILL);
    }
}

static __inline__ void pxx_anti_reverse_check(void) {
    volatile int junk = 0;

    for (int i = 0; i < 100; i++) {
        junk += (i * 13 + 7) % 23;
    }

    if (pxx_opaque_true()) {
        if (pxx_is_debugged_sysctl()) {
            pxx_suicide();
        }
    }

    if (pxx_opaque_true()) {
        pxx_is_debugged_ptrace();
    }

    if (junk < -1000000) {
        pxx_suicide();
    }
}

typedef enum {
    PXX_S0 = 0,
    PXX_S1 = 1,
    PXX_S2 = 2,
    PXX_S3 = 3,
    PXX_S4 = 4,
    PXX_S5 = 5,
    PXX_S6 = 6,
    PXX_S7 = 7,
    PXX_S_END = 99
} pxx_state_t;

#define PXX_FLATTEN_BEGIN \
    do { \
        volatile pxx_state_t _pxx_st = PXX_S0; \
        volatile int _pxx_junk = arc4random() % 1000; \
        for (;;) { \
            _pxx_junk += (int)_pxx_st * 7; \
            switch (_pxx_st) { \
                case PXX_S0:

#define PXX_STATE(s) \
                    break; \
                case s:

#define PXX_GOTO(s) \
                    do { \
                        _pxx_st = s; \
                        _pxx_junk = (_pxx_junk * 3 + 5) % 997; \
                    } while (0); \
                    continue;

#define PXX_FLATTEN_END \
                    break; \
                default: \
                    _pxx_junk = (_pxx_junk + 13) * 3; \
                    break; \
            } \
            break; \
        } \
    } while (0);

static __inline__ uint32_t pxx_crc32(const uint8_t *data, size_t length) {
    uint32_t crc = 0xFFFFFFFF;
    for (size_t i = 0; i < length; i++) {
        crc ^= data[i];
        for (int j = 0; j < 8; j++) {
            uint32_t mask = -(crc & 1);
            crc = (crc >> 1) ^ (0xEDB88320 & mask);
        }
    }
    return ~crc;
}

static __inline__ void *pxx_decode_ptr(uintptr_t enc, uintptr_t key) {
    uintptr_t val = enc ^ key;
    val ^= (val >> 16);
    return (void *)val;
}

static __inline__ uintptr_t pxx_encode_ptr(void *ptr, uintptr_t key) {
    uintptr_t val = (uintptr_t)ptr;
    val ^= (val >> 16);
    return val ^ key;
}

#define PXX_ENCODE_PTR(ptr) pxx_encode_ptr((ptr), PXX_PTR_XOR_KEY)
#define PXX_DECODE_PTR(enc) pxx_decode_ptr((enc), PXX_PTR_XOR_KEY)

static __inline__ void pxx_junk_code(void) {
    volatile long a = arc4random();
    volatile long b = arc4random();
    volatile long c = 0;
    for (int i = 0; i < 50; i++) {
        c += (a ^ b) + (i * 17);
        a = (a * 1103515245 + 12345) & 0x7FFFFFFF;
        b = (b * 69069 + 1) & 0x7FFFFFFF;
    }
    if (c < 0) {
        c = -c;
    }
}

#define PXX_JUNK() pxx_junk_code()

static __inline__ void pxx_spaghetti_jump(int count, ...) {
    va_list args;
    va_start(args, count);
    volatile int idx = arc4random() % count;
    for (int i = 0; i < count; i++) {
        void (*fn)(void) = va_arg(args, void (*)(void));
        if (i == idx) {
            if (pxx_opaque_true()) {
                fn();
            }
        }
    }
    va_end(args);
}

#endif
