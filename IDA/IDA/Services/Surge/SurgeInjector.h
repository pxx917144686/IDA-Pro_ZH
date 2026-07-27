#ifndef SurgeInjector_h
#define SurgeInjector_h

#import <Foundation/Foundation.h>

int surge_spawn_and_inject(const char *app_path, const char *dylib_path, char **error_msg, pid_t *out_pid);
bool surge_check_sip_enabled(void);
bool surge_check_dylib_loaded(pid_t pid, const char *dylib_path);
pid_t surge_find_pid_by_path(const char *app_path);
bool surge_can_check_dylib(void);

#endif
