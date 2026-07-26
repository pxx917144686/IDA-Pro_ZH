#ifndef SurgeInjector_h
#define SurgeInjector_h

#import <Foundation/Foundation.h>

int surge_spawn_and_inject(const char *app_path, const char *dylib_path, char **error_msg);
bool surge_check_sip_enabled(void);

#endif
