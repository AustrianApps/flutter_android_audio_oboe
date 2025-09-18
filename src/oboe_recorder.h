//
// Created by Herbert Poul on 28.08.25.
//

#ifndef ANDROID_OBEO_RECORDER_H
#define ANDROID_OBEO_RECORDER_H

#include <stdint.h>

#if _WIN32
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT
#endif

#ifdef __cplusplus

//#include <oboe/Oboe.h>
//
//
//class OboeRecorder {
//
//};

#endif

#ifdef __cplusplus
extern "C" {
#endif

FFI_PLUGIN_EXPORT int start_recording(void (*fn)(float *, int), void (*onErrorAfterCloseCallback)(int32_t errorCode));

FFI_PLUGIN_EXPORT int stop_recording();

FFI_PLUGIN_EXPORT void oboe_options(int sampleRate, int framesPerDataCallback, int32_t deviceId);

#ifdef __cplusplus
}
#endif

#endif //ANDROID_OBEO_RECORDER_H
