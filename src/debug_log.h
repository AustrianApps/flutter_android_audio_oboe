//
// Created by Herbert Poul on 27.08.25.
//

#ifndef ANDROID_DEBUG_LOG_H
#define ANDROID_DEBUG_LOG_H

#include <android/log.h>

#define MODULE_NAME "android_audio_oboe"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, MODULE_NAME, __VA_ARGS__)
#define LOGW(...) __android_log_print(ANDROID_LOG_WARN, MODULE_NAME, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, MODULE_NAME, __VA_ARGS__)
#define LOGF(...) __android_log_print(ANDROID_LOG_FATAL, MODULE_NAME, __VA_ARGS__)


#endif //ANDROID_DEBUG_LOG_H
