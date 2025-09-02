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

    int startRecording() {
        oboe::AudioStreamBuilder builder;
        builder.setDirection(oboe::Direction::Input);
        builder.setPerformanceMode(oboe::PerformanceMode::LowLatency);
        builder.setSharingMode(oboe::SharingMode::Exclusive);
        builder.setFormat(oboe::AudioFormat::Float);
        builder.setChannelCount(oboe::ChannelCount::Mono);
        builder.setSampleRate(4000);
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
        auto sampleRate = mStream->getSampleRate();
        auto millis = mStream->calculateLatencyMillis();
        auto framesPerDataCallback = mStream->getFramesPerDataCallback();
        LOGI("OboeRecorder Successfully opened stream. sampleRate: %d, latency: %fms, framesPerDataCallback: %d",
                sampleRate, millis.value(), framesPerDataCallback);
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
    }

    oboe::DataCallbackResult onAudioReady(oboe::AudioStream *audioStream, void *audioData, int32_t numFrames) override {
//        LOGI("==== OboeRecorder onAudioReady() numFrames:%d", numFrames);

        // Calculate the size of the data in bytes
        size_t bufferSize = numFrames * sizeof(float);

        // Allocate new memory
        float *copiedAudioData = static_cast<float *>(malloc(bufferSize));

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


FFI_PLUGIN_EXPORT int start_recording(void (*callback)(float *, int)) {
    oboeRecorder.callback = callback;
    return oboeRecorder.startRecording();
}

FFI_PLUGIN_EXPORT int stop_recording() {
    return oboeRecorder.stopRecording();
}
