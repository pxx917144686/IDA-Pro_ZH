#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <sys/sysctl.h>
#include <libproc.h>
#include <pthread.h>
#include <mach-o/dyld_images.h>
#include <spawn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <mach-o/dyld.h>
#include <libgen.h>
#include <signal.h>

#ifdef __x86_64__

static const unsigned char mach_thread_code[] =
{
    0x55,
    0x48, 0x89, 0xe5,
    0x48, 0x89, 0xef,
    0xff, 0xd0,
    0x48, 0xc7, 0xc0, 0x09, 0x03, 0x00, 0x00,
    0xe9, 0xfb, 0xff, 0xff, 0xff
};

static const unsigned char posix_thread_code[] =
{
    0x55,
    0x48, 0x89, 0xe5,
    0x48, 0x8b, 0x07,
    0x48, 0x8b, 0x7f, 0xf8,
    0xbe, 0x01, 0x00, 0x00, 0x00,
    0xff, 0xd0,
    0xc9,
    0xc3
};

#define PTR_SIZE sizeof(void*)
#define STACK_SIZE 1024
#define MACH_CODE_SIZE sizeof(mach_thread_code)
#define POSIX_CODE_SIZE sizeof(posix_thread_code)

#else

typedef struct
{
    __uint64_t __x[29];
    __uint64_t __fp;
    __uint64_t __lr;
    __uint64_t __sp;
    __uint64_t __pc;
    __uint32_t __cpsr;
    __uint32_t __pad;
}
__arm_thread_state64_t;

unsigned char mach_thread_code[] =
{
    "\x80\x00\x3f\xd6"
    "\x00\x00\x00\x14"
};
#define MACH_CODE_SIZE sizeof(mach_thread_code)
#define STACK_SIZE 1024
#endif

int pthread_create_from_mach_thread(pthread_t *thread,
                                    const pthread_attr_t *attr,
                                    void *(*start_routine)(void *),
                                    void *arg);

extern char **environ;

static int injector_error_code = 0;
static char injector_error_msg[512] = {0};

#define INJ_ERR(fmt, ...) do { \
    snprintf(injector_error_msg, sizeof(injector_error_msg), fmt, ##__VA_ARGS__); \
    return injector_error_code; \
} while(0)

static bool is_dylib_loaded_in_task(const task_t task, const char* dylib_path)
{
    bool image_exists = false;
    mach_msg_type_number_t dataCnt = 0;
    vm_offset_t readData = 0;
    
    struct task_dyld_info dyld_info;
    mach_msg_type_number_t count = TASK_DYLD_INFO_COUNT;
    kern_return_t kr = task_info(task, TASK_DYLD_INFO, (task_info_t)&dyld_info, &count);
    if (kr != KERN_SUCCESS) return false;
    
    mach_vm_size_t size = sizeof(struct dyld_all_image_infos);
    kr = mach_vm_read(task, dyld_info.all_image_info_addr, size, &readData, &dataCnt);
    if (kr != KERN_SUCCESS) return false;
    
    struct dyld_all_image_infos* infos = (struct dyld_all_image_infos*)readData;
    size = sizeof(struct dyld_image_info)*(infos->infoArrayCount);
    kr = mach_vm_read(task, (mach_vm_address_t)infos->infoArray, size, &readData, &dataCnt);
    if (kr != KERN_SUCCESS) return false;
    
    struct dyld_image_info* info = (struct dyld_image_info*)readData;
    
    for (int i = 0; i < (infos->infoArrayCount); i++)
    {
        size = PATH_MAX;
        kr = mach_vm_read(task, (mach_vm_address_t)info[i].imageFilePath, size, &readData, &dataCnt);
        if (kr != KERN_SUCCESS) continue;
        unsigned char* foundpath = (unsigned char*)readData;
        if (foundpath && strcmp((const char*)foundpath, dylib_path) == 0)
        {
            image_exists = true;
            break;
        }
    }
    return image_exists;
}

static kern_return_t wait_for_dyld_loaded(pid_t pid) {
    kill(pid, SIGCONT);
    task_t task;
    kern_return_t kr = task_for_pid(mach_task_self(), pid, &task);
    if (kr != KERN_SUCCESS) return kr;
    
    task_dyld_info_data_t dyld_info;
    mach_msg_type_number_t count = TASK_DYLD_INFO_COUNT;
    
    int retries = 0;
    int MAX_RETRIES = 1000;
    while (retries < MAX_RETRIES) {
        kr = task_info(task, TASK_DYLD_INFO, (task_info_t)&dyld_info, &count);
        if (kr == KERN_SUCCESS && dyld_info.all_image_info_addr != 0) {
            return KERN_SUCCESS;
        }
        retries++;
        usleep(1000);
    }
    return KERN_FAILURE;
}

#ifdef __x86_64__
static int inject_dylib_x86_64(pid_t pid, const char *lib){
    const static void* pthread_create_from_mach_thread_address =
    (const void*)pthread_create_from_mach_thread;

    const static void* dlopen_address = (const void*)dlopen;

    vm_size_t path_length = strlen(lib);

    task_t task;
    kern_return_t kr = task_for_pid(mach_task_self_, pid, &task);
    if (kr != KERN_SUCCESS) {
        injector_error_code = (int)kr;
        INJ_ERR("task_for_pid failed: %s", mach_error_string(kr));
    }
    
    if (is_dylib_loaded_in_task(task, lib)) {
        injector_error_code = 0;
        return 0;
    }

    mach_vm_address_t mach_code_mem = 0;
    mach_vm_address_t posix_code_mem = 0;
    mach_vm_address_t stack_mem = 0;
    mach_vm_address_t path_mem = 0;
    mach_vm_address_t posix_param_mem = 0;
    
    kr = mach_vm_allocate(task, &mach_code_mem, MACH_CODE_SIZE, VM_FLAGS_ANYWHERE);
    if (kr != KERN_SUCCESS) { injector_error_code = (int)kr; INJ_ERR("mach_vm_allocate mach_code: %s", mach_error_string(kr)); }
    
    kr = mach_vm_allocate(task, &posix_code_mem, POSIX_CODE_SIZE, VM_FLAGS_ANYWHERE);
    if (kr != KERN_SUCCESS) { injector_error_code = (int)kr; INJ_ERR("mach_vm_allocate posix_code: %s", mach_error_string(kr)); }
    
    kr = mach_vm_allocate(task, &stack_mem, STACK_SIZE, VM_FLAGS_ANYWHERE);
    if (kr != KERN_SUCCESS) { injector_error_code = (int)kr; INJ_ERR("mach_vm_allocate stack: %s", mach_error_string(kr)); }
    
    kr = mach_vm_allocate(task, &path_mem, path_length, VM_FLAGS_ANYWHERE);
    if (kr != KERN_SUCCESS) { injector_error_code = (int)kr; INJ_ERR("mach_vm_allocate path: %s", mach_error_string(kr)); }
    
    kr = mach_vm_allocate(task, &posix_param_mem, (PTR_SIZE * 2), VM_FLAGS_ANYWHERE);
    if (kr != KERN_SUCCESS) { injector_error_code = (int)kr; INJ_ERR("mach_vm_allocate param: %s", mach_error_string(kr)); }

    kr = mach_vm_write(task, path_mem, (vm_offset_t)lib, (int)path_length);
    if (kr != KERN_SUCCESS) { injector_error_code = (int)kr; INJ_ERR("mach_vm_write path: %s", mach_error_string(kr)); }
    
    kr = mach_vm_write(task, posix_param_mem, (vm_offset_t)&dlopen_address, PTR_SIZE);
    if (kr != KERN_SUCCESS) { injector_error_code = (int)kr; INJ_ERR("mach_vm_write dlopen_addr: %s", mach_error_string(kr)); }
    
    kr = mach_vm_write(task, (posix_param_mem - PTR_SIZE), (vm_offset_t)&path_mem, PTR_SIZE);
    if (kr != KERN_SUCCESS) { injector_error_code = (int)kr; INJ_ERR("mach_vm_write path_addr: %s", mach_error_string(kr)); }
    
    kr = mach_vm_write(task, mach_code_mem, (vm_offset_t)&mach_thread_code, MACH_CODE_SIZE);
    if (kr != KERN_SUCCESS) { injector_error_code = (int)kr; INJ_ERR("mach_vm_write mach_code: %s", mach_error_string(kr)); }
    
    kr = mach_vm_write(task, posix_code_mem, (vm_offset_t)&posix_thread_code, POSIX_CODE_SIZE);
    if (kr != KERN_SUCCESS) { injector_error_code = (int)kr; INJ_ERR("mach_vm_write posix_code: %s", mach_error_string(kr)); }
    
    kr = mach_vm_protect(task, mach_code_mem, MACH_CODE_SIZE, FALSE, VM_PROT_ALL);
    if (kr != KERN_SUCCESS) { injector_error_code = (int)kr; INJ_ERR("mach_vm_protect mach: %s", mach_error_string(kr)); }
    
    kr = mach_vm_protect(task, posix_code_mem, POSIX_CODE_SIZE, FALSE, VM_PROT_ALL);
    if (kr != KERN_SUCCESS) { injector_error_code = (int)kr; INJ_ERR("mach_vm_protect posix: %s", mach_error_string(kr)); }

    mach_msg_type_number_t state_count = x86_THREAD_STATE64_COUNT;
    mach_msg_type_number_t state = x86_THREAD_STATE64;

    x86_thread_state64_t regs;
    bzero(&regs, sizeof(regs));

    regs.__rip = (__uint64_t)mach_code_mem;
    regs.__rsp = (__uint64_t)(stack_mem + STACK_SIZE);
    regs.__rax = (__uint64_t)pthread_create_from_mach_thread_address;
    regs.__rdx = (__uint64_t)posix_code_mem;
    regs.__rcx = (__uint64_t)posix_param_mem;

    thread_act_t thread;
    kr = thread_create_running(task, state, (thread_state_t)(&regs), state_count, &thread);
    if (kr != KERN_SUCCESS) { injector_error_code = (int)kr; INJ_ERR("thread_create_running: %s", mach_error_string(kr)); }

    for (int i = 0; i < 1000; i++) {
        mach_msg_type_number_t sc = state_count;
        x86_thread_state64_t check_regs;
        kr = thread_get_state(thread, state, (thread_state_t)(&check_regs), &sc);
        if (kr == KERN_SUCCESS && check_regs.__rax == 777) {
            break;
        }
        usleep(2000);
    }

    thread_suspend(thread);
    thread_terminate(thread);

    mach_vm_deallocate(task, stack_mem, STACK_SIZE);
    mach_vm_deallocate(task, mach_code_mem, MACH_CODE_SIZE);
    
    return 0;
}
#else
static int inject_dylib_arm64(pid_t pid, const char *lib){
    task_t task;
    kern_return_t kr = task_for_pid(mach_task_self_, pid, &task);
    if (kr != KERN_SUCCESS) {
        injector_error_code = (int)kr;
        INJ_ERR("task_for_pid failed: %s", mach_error_string(kr));
    }
    
    if (is_dylib_loaded_in_task(task, lib)) {
        injector_error_code = 0;
        return 0;
    }
    
    mach_vm_address_t remote_mach_code = 0;
    mach_vm_address_t remote_stack = 0;
    mach_vm_address_t remote_pthread_mem = 0;
    mach_vm_address_t remote_path = 0;
    
    kr = mach_vm_allocate(task, &remote_mach_code, MACH_CODE_SIZE, VM_FLAGS_ANYWHERE);
    if (kr != KERN_SUCCESS) { injector_error_code = (int)kr; INJ_ERR("mach_vm_allocate code: %s", mach_error_string(kr)); }
    
    kr = mach_vm_allocate(task, &remote_stack, STACK_SIZE, VM_FLAGS_ANYWHERE);
    if (kr != KERN_SUCCESS) { injector_error_code = (int)kr; INJ_ERR("mach_vm_allocate stack: %s", mach_error_string(kr)); }
    
    kr = mach_vm_allocate(task, &remote_pthread_mem, 8, VM_FLAGS_ANYWHERE);
    if (kr != KERN_SUCCESS) { injector_error_code = (int)kr; INJ_ERR("mach_vm_allocate pthread: %s", mach_error_string(kr)); }
    
    kr = mach_vm_allocate(task, &remote_path, strlen(lib), VM_FLAGS_ANYWHERE);
    if (kr != KERN_SUCCESS) { injector_error_code = (int)kr; INJ_ERR("mach_vm_allocate path: %s", mach_error_string(kr)); }
    
    kr = mach_vm_write(task, remote_path, (vm_address_t)lib, (int)strlen(lib));
    if (kr != KERN_SUCCESS) { injector_error_code = (int)kr; INJ_ERR("mach_vm_write path: %s", mach_error_string(kr)); }
    
    kr = mach_vm_write(task, remote_mach_code, (vm_address_t)mach_thread_code, MACH_CODE_SIZE);
    if (kr != KERN_SUCCESS) { injector_error_code = (int)kr; INJ_ERR("mach_vm_write code: %s", mach_error_string(kr)); }
    
    kr = mach_vm_protect(task, remote_mach_code, MACH_CODE_SIZE, FALSE, VM_PROT_READ|VM_PROT_EXECUTE);
    if (kr != KERN_SUCCESS) { injector_error_code = (int)kr; INJ_ERR("mach_vm_protect: %s", mach_error_string(kr)); }
    
    __arm_thread_state64_t regs;
    bzero(&regs, sizeof(regs));
    regs.__pc = remote_mach_code;
    regs.__sp = remote_stack + STACK_SIZE;
    
    const static void* pthread_create_from_mach_thread_address =
            (const void*)pthread_create_from_mach_thread;
    regs.__x[4] = (vm_address_t)pthread_create_from_mach_thread_address;
    regs.__x[0] = remote_pthread_mem;
    regs.__x[1] = 0;
    regs.__x[2] = (vm_address_t)dlopen;
    regs.__x[3] = remote_path;
    
    thread_act_t thread;
    kr = thread_create(task, &thread);
    if (kr != KERN_SUCCESS) { injector_error_code = (int)kr; INJ_ERR("thread_create: %s", mach_error_string(kr)); }
    
    mach_msg_type_number_t state_count = sizeof(regs) / sizeof(uint32_t);
    kr = thread_set_state(thread, ARM_THREAD_STATE64, (thread_state_t)&regs, state_count);
    if (kr != KERN_SUCCESS) { injector_error_code = (int)kr; INJ_ERR("thread_set_state: %s", mach_error_string(kr)); }
    
    kr = thread_resume(thread);
    if (kr != KERN_SUCCESS) { injector_error_code = (int)kr; INJ_ERR("thread_resume: %s", mach_error_string(kr)); }
    
    for (int i = 0; i < 500; i++) {
        mach_msg_type_number_t sc = state_count;
        __arm_thread_state64_t check_regs;
        kr = thread_get_state(thread, ARM_THREAD_STATE64, (thread_state_t)(&check_regs), &sc);
        if (kr == KERN_SUCCESS && check_regs.__x[0] == 777) {
            break;
        }
        usleep(2000);
    }
    
    thread_suspend(thread);
    thread_terminate(thread);
    
    mach_vm_deallocate(task, remote_stack, STACK_SIZE);
    mach_vm_deallocate(task, remote_mach_code, MACH_CODE_SIZE);
    
    return 0;
}
#endif

int surge_spawn_and_inject(const char *app_path, const char *dylib_path, char **error_msg, pid_t *out_pid) {
    injector_error_code = 0;
    injector_error_msg[0] = '\0';
    
    if (!app_path || !dylib_path) {
        if (error_msg) *error_msg = "Invalid parameters";
        return -1;
    }
    
    pid_t pid = 0;
    posix_spawnattr_t attr;
    posix_spawnattr_init(&attr);
    short flags = POSIX_SPAWN_START_SUSPENDED;
    posix_spawnattr_setflags(&attr, flags);
    
    posix_spawn_file_actions_t file_actions;
    posix_spawn_file_actions_init(&file_actions);
    
    int spawn_result = posix_spawn(&pid, app_path, &file_actions, &attr, (char *const[]){(char *)app_path, NULL}, environ);
    
    posix_spawnattr_destroy(&attr);
    posix_spawn_file_actions_destroy(&file_actions);
    
    if (spawn_result != 0) {
        if (error_msg) *error_msg = strerror(spawn_result);
        return spawn_result;
    }
    
    if (out_pid) *out_pid = pid;
    
    kern_return_t wait_kr = wait_for_dyld_loaded(pid);
    if (wait_kr != KERN_SUCCESS) {
        kill(pid, SIGKILL);
        if (out_pid) *out_pid = 0;
        if (error_msg) {
            char buf[256];
            snprintf(buf, sizeof(buf), "wait_for_dyld failed: %s", mach_error_string(wait_kr));
            *error_msg = strdup(buf);
        }
        return (int)wait_kr;
    }
    
#ifdef __x86_64__
    int ret = inject_dylib_x86_64(pid, dylib_path);
#elif defined(__arm64__)
    int ret = inject_dylib_arm64(pid, dylib_path);
#else
    int ret = -1;
    if (error_msg) *error_msg = "Unsupported architecture";
#endif
    
    if (ret != 0) {
        kill(pid, SIGKILL);
        if (out_pid) *out_pid = 0;
        if (error_msg) *error_msg = strdup(injector_error_msg);
        return ret;
    }
    
    kill(pid, SIGCONT);
    return 0;
}

bool surge_check_sip_enabled(void) {
    FILE *fp = popen("/usr/bin/csrutil status 2>/dev/null", "r");
    if (!fp) {
        return false;
    }
    
    char buf[256];
    bool enabled = true;
    if (fgets(buf, sizeof(buf), fp) != NULL) {
        if (strstr(buf, "disabled") != NULL) {
            enabled = false;
        } else if (strstr(buf, "enabled") != NULL) {
            enabled = true;
        }
    }
    pclose(fp);
    return enabled;
}
