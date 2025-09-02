//
// Created by Herbert Poul on 27.08.25.
//

#include "oboe_player.h"
#include "debug_log.h"

#include <oboe/Oboe.h>
#include <stdint.h>

static OboePlayer oboePlayer;

oboe::DataCallbackResult
OboePlayer::onAudioReady(oboe::AudioStream *audioStream, void *audioData, int32_t numFrames) {
    int size = beep_data_size;
    LOGI("==== onAudioReady() pos:%d, size: %d, numFrames:%d", pos, size, numFrames);

    // We requested AudioFormat::I16. So if the stream opens
    // we know we got the I16 format.
    // If you do not specify a format then you should check what format
    // the stream has and cast to the appropriate type.
    auto *outputData = static_cast<int16_t *>(audioData);

    if (pos == 0) {
        gettimeofday(&beep_start_time, nullptr);
        if (callback != nullptr) {
            callback(1, beep_start_time.tv_sec, beep_start_time.tv_usec);
        }
    }

    // Generate random numbers (white noise) centered around zero.
    for (int i = 0; i < numFrames; ++i) {
        int p = pos++;
        if (p < size) {
            outputData[i] = beep_data[p];
        } else {
            gettimeofday(&beep_finished_time, nullptr);
            LOGI("=== onAudioRead() - end of stream reached. %ld.%ld", beep_finished_time.tv_sec, beep_finished_time.tv_usec);
            if (callback != nullptr) {
                callback(2, beep_finished_time.tv_sec, beep_finished_time.tv_usec);
            }
            return oboe::DataCallbackResult::Stop;
        }
    }

    return oboe::DataCallbackResult::Continue;
}

bool OboePlayer::onError(oboe::AudioStream *, oboe::Result error) {
    LOGI("==== onError() error:%d", error);

}

void OboePlayer::onErrorAfterClose(oboe::AudioStream *, oboe::Result error) {
    LOGI("==== onErrorAfterClose() error:%d", error);
}

void OboePlayer::onErrorBeforeClose(oboe::AudioStream *, oboe::Result error) {
    LOGI("==== onErrorBeforeClose() error:%d", error);
}

void OboePlayer::playBeep() {
    LOGI("from class: Need to play beep!");
    pos = 0;
    oboe::AudioStreamBuilder builder;
    builder.setDirection(oboe::Direction::Output);
    builder.setPerformanceMode(oboe::PerformanceMode::LowLatency);
    builder.setSharingMode(oboe::SharingMode::Exclusive);
    builder.setFormat(oboe::AudioFormat::I16);
    builder.setChannelCount(oboe::ChannelCount::Mono);
//    auto *cb = new MyCallback(this);
    builder.setDataCallback(this);
    builder.setErrorCallback(this);
    oboe::Result result = builder.openStream(mStream);
    if (result != oboe::Result::OK) {
        LOGE("Failed to create stream. Error: %s", oboe::convertToText(result));
    }
    oboe::AudioFormat format = mStream->getFormat();
    LOGI("AudioStream format is %s", oboe::convertToText(format));
    auto startRequest = mStream->requestStart();
    if (startRequest != oboe::Result::OK) {
        LOGE("Failed to start stream. Error: %s", oboe::convertToText(startRequest));
        return;
    }
    auto sampleRate = mStream->getSampleRate();
    LOGI("Successfully opened stream. sampleRate: %d", sampleRate);


}


//
//oboe::DataCallbackResult OboePlayer::MyCallback::onAudioReady(oboe::AudioStream *audioStream, void *audioData, int32_t numFrames) {
//        // We requested AudioFormat::Float. So if the stream opens
//        // we know we got the Float format.
//        // If you do not specify a format then you should check what format
//        // the stream has and cast to the appropriate type.
//        auto *outputData = static_cast<float *>(audioData);
//
//        // Generate random numbers (white noise) centered around zero.
//        const float amplitude = 0.2f;
//        for (int i = 0; i < numFrames; ++i) {
//            outputData[i] = ((float) drand48() - 0.5f) * 2 * amplitude;
//        }
//
//        return oboe::DataCallbackResult::Continue;
//
//}
//
//class OboePlayer::MyCallback : public oboe::AudioStreamDataCallback {
//public:
//    oboe::DataCallbackResult
//    onAudioReady(oboe::AudioStream *audioStream, void *audioData, int32_t numFrames) {
//
//        // We requested AudioFormat::Float. So if the stream opens
//        // we know we got the Float format.
//        // If you do not specify a format then you should check what format
//        // the stream has and cast to the appropriate type.
//        auto *outputData = static_cast<float *>(audioData);
//
//        // Generate random numbers (white noise) centered around zero.
//        const float amplitude = 0.2f;
//        for (int i = 0; i < numFrames; ++i) {
//            outputData[i] = ((float) drand48() - 0.5f) * 2 * amplitude;
//        }
//
//        return oboe::DataCallbackResult::Continue;
//    }
//};


void my_play_beep(void (*fn)(int, long, long)) {
    oboePlayer.callback = fn;
    oboePlayer.playBeep();
}

extern "C" {

FFI_PLUGIN_EXPORT void load_beep_data(int16_t *data, int size) {
    oboePlayer.beep_data = data;
    oboePlayer.beep_data_size = size;
}

}