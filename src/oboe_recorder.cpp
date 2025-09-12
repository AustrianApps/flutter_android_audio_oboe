//
// Created by Herbert Poul on 28.08.25.
//

#include "oboe_recorder.h"
#include "debug_log.h"

#include <oboe/Oboe.h>
#include <cstring> // Required for memcpy

class OboeRecorder : public oboe::AudioStreamDataCallback, public oboe::AudioStreamErrorCallback {
private:
    std::shared_ptr <oboe::AudioStream> mStream;
public:
    void (*callback)(float *, int);
    int sampleRate = 8000;
    int framesPerDataCallback = 0;

    int startRecording() {
        oboe::AudioStreamBuilder builder;
        builder.setDirection(oboe::Direction::Input);
        builder.setPerformanceMode(oboe::PerformanceMode::LowLatency);
        builder.setSharingMode(oboe::SharingMode::Exclusive);
        builder.setFormat(oboe::AudioFormat::Float);
        builder.setChannelCount(oboe::ChannelCount::Mono);
        builder.setSampleRate(sampleRate);
//        "The usage is ignored for input streams"
//        builder.setUsage(oboe::Usage::Game);
        builder.setInputPreset(oboe::InputPreset::Unprocessed);
        if (framesPerDataCallback > 0) {
            builder.setFramesPerDataCallback(framesPerDataCallback);
        }
        builder.setDataCallback(this);
        builder.setErrorCallback(this);
        oboe::Result result = builder.openStream(mStream);
        if (result != oboe::Result::OK) {
            LOGE("OboeRecorder Failed to create stream. Error: %s", oboe::convertToText(result));
            return 1;
        }
        oboe::AudioFormat format = mStream->getFormat();
        LOGI("OboeRecorder AudioStream format is %s", oboe::convertToText(format));
        auto startRequest = mStream->requestStart();
        if (startRequest != oboe::Result::OK) {
            LOGE("OboeRecorder Failed to start stream. Error: %s", oboe::convertToText(startRequest));
            return 1;
        }
        auto actualSampleRate = mStream->getSampleRate();
        auto millis = mStream->calculateLatencyMillis();
        auto actualFramesPerDataCallback = mStream->getFramesPerDataCallback();
        LOGI("OboeRecorder Successfully opened stream. sampleRate: %d, latency: %fms, framesPerDataCallback: %d",
                actualSampleRate, millis.value(), actualFramesPerDataCallback);
        return 0;
    }

    int stopRecording() {
        auto stopRequest = mStream->requestStop();
        if (stopRequest != oboe::Result::OK) {
            LOGE("OboeRecorder Failed to stop stream. Error: %s", oboe::convertToText(stopRequest));
            return 1;
        }
        return 0;
    }

    void onErrorBeforeClose(oboe::AudioStream *, oboe::Result error) override {
        LOGI("==== OboeRecorder onErrorBeforeClose() error:%d", error);
    }

    void onErrorAfterClose(oboe::AudioStream *, oboe::Result error) override {
        LOGI("==== OboeRecorder onErrorAfterClose() error:%d", error);
    }

    bool onError(oboe::AudioStream *, oboe::Result error) override {
        LOGI("==== OboeRecorder onError() error:%d", error);
        return false;
    }

    oboe::DataCallbackResult onAudioReady(oboe::AudioStream *audioStream, void *audioData, int32_t numFrames) override {
//        LOGI("==== OboeRecorder onAudioReady() numFrames:%d", numFrames);
        if (audioStream->getFormat() != oboe::AudioFormat::Float) {
            LOGE("OboeRecorder AudioStream format is not Float");
        }

        // Calculate the size of the data in bytes
        size_t bufferSize = numFrames * sizeof(float);

        // Allocate new memory
        auto *copiedAudioData = static_cast<float *>(malloc(bufferSize));

        if (copiedAudioData == nullptr) {
            // Handle memory allocation failure, e.g., log an error
            LOGE("OboeRecorder Failed to allocate memory for audio data copy");
            // Depending on desired behavior, you might want to stop the stream or return an error
            // For now, continuing without calling the callback if allocation fails
            return oboe::DataCallbackResult::Continue;
        }

        // Copy the audio data to the new buffer
        memcpy(copiedAudioData, audioData, bufferSize);

        // Pass the copied data to the callback
        callback(copiedAudioData, numFrames);

        // The responsibility to free 'copiedAudioData' is now with the callback
        // or the code that consumes the data from the callback.

        return oboe::DataCallbackResult::Continue;
    }
};


static OboeRecorder oboeRecorder;

FFI_PLUGIN_EXPORT int oboe_options(int sampleRate, int framesPerDataCallback) {
    oboeRecorder.sampleRate = sampleRate;
    oboeRecorder.framesPerDataCallback = framesPerDataCallback;
}


FFI_PLUGIN_EXPORT int start_recording(void (*callback)(float *, int)) {
    oboeRecorder.callback = callback;
    return oboeRecorder.startRecording();
}

FFI_PLUGIN_EXPORT int stop_recording() {
    return oboeRecorder.stopRecording();
}
