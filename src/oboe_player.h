//
// Created by Herbert Poul on 27.08.25.
//

#ifndef ANDROID_OBOE_PLAYER_H
#define ANDROID_OBOE_PLAYER_H

#include <stdint.h>

#if _WIN32
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT
#endif


#ifdef __cplusplus

#include <oboe/Oboe.h>

class OboePlayer : public oboe::AudioStreamDataCallback, public oboe::AudioStreamErrorCallback {
public:
    void playBeep();
    int16_t *beep_data;
    int beep_data_size;
    int pos = 0;

    oboe::DataCallbackResult onAudioReady(oboe::AudioStream *audioStream, void *audioData, int32_t numFrames) override;
    bool onError(oboe::AudioStream *, oboe::Result error)  override;
    void onErrorAfterClose(oboe::AudioStream *, oboe::Result error) override;
    void onErrorBeforeClose(oboe::AudioStream *, oboe::Result error) override;
protected:
//    class MyCallback;
//    class MyCallback : public oboe::AudioStreamDataCallback;
private:
    std::shared_ptr<oboe::AudioStream> mStream;
};

#endif

#ifdef __cplusplus
extern "C" {
#endif

FFI_PLUGIN_EXPORT void my_play_beep();
FFI_PLUGIN_EXPORT void load_beep_data(int16_t *data, int size);

#ifdef __cplusplus
}
#endif

#endif //ANDROID_OBOE_PLAYER_H
