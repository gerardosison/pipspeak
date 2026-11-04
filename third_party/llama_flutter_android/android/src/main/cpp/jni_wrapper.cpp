#include <jni.h>
#include <string>
#include <vector>
#include <atomic>
#include <ctime>
#include <cstring>
#include <android/log.h>
#include "llama.cpp/include/llama.h"
#include <vulkan/vulkan.h>
#include "pipspeak/unicode_bridge.h"


#define LOG_TAG "LlamaJNI"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

static llama_model* g_model = nullptr;
static llama_context* g_ctx = nullptr;
static const llama_vocab* g_vocab = nullptr;
static llama_sampler* g_sampler = nullptr;
static std::atomic<bool> g_stop_flag{false};
static int g_n_past = 0;  // Track the number of tokens already in KV cache

extern "C" JNIEXPORT jstring JNICALL
Java_com_write4me_llama_1flutter_1android_LlamaFlutterAndroidPlugin_nativeDetectGpu(
        JNIEnv* env, jobject /* this */, jlongArray outStats) {

    // Zero out output array as safe default (-1 = unknown)
    jlong defaults[2] = {-1L, -1L};
    env->SetLongArrayRegion(outStats, 0, 2, defaults);

    // Minimal instance — no extensions, no validation layers (crash risk on some devices)
    VkApplicationInfo appInfo{};
    appInfo.sType = VK_STRUCTURE_TYPE_APPLICATION_INFO;
    appInfo.apiVersion = VK_API_VERSION_1_0;

    VkInstanceCreateInfo createInfo{};
    createInfo.sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
    createInfo.pApplicationInfo = &appInfo;
    createInfo.enabledExtensionCount = 0;
    createInfo.ppEnabledExtensionNames = nullptr;
    createInfo.enabledLayerCount = 0;
    createInfo.ppEnabledLayerNames = nullptr;

    VkInstance instance = VK_NULL_HANDLE;
    if (vkCreateInstance(&createInfo, nullptr, &instance) != VK_SUCCESS) {
        LOGI("nativeDetectGpu: vkCreateInstance failed — no Vulkan");
        return nullptr;
    }

    // Enumerate physical devices
    uint32_t deviceCount = 0;
    vkEnumeratePhysicalDevices(instance, &deviceCount, nullptr);
    if (deviceCount == 0) {
        LOGI("nativeDetectGpu: no physical devices found");
        vkDestroyInstance(instance, nullptr);
        return nullptr;
    }

    std::vector<VkPhysicalDevice> devices(deviceCount);
    vkEnumeratePhysicalDevices(instance, &deviceCount, devices.data());

    // Select device with the largest device-local memory heap
    VkPhysicalDevice bestDevice = VK_NULL_HANDLE;
    VkDeviceSize bestHeapSize = 0;

    for (auto& dev : devices) {
        VkPhysicalDeviceMemoryProperties memProps{};
        vkGetPhysicalDeviceMemoryProperties(dev, &memProps);
        for (uint32_t i = 0; i < memProps.memoryHeapCount; i++) {
            if ((memProps.memoryHeaps[i].flags & VK_MEMORY_HEAP_DEVICE_LOCAL_BIT) &&
                memProps.memoryHeaps[i].size > bestHeapSize) {
                bestHeapSize = memProps.memoryHeaps[i].size;
                bestDevice = dev;
            }
        }
    }

    if (bestDevice == VK_NULL_HANDLE) {
        LOGI("nativeDetectGpu: no device-local memory found");
        vkDestroyInstance(instance, nullptr);
        return nullptr;
    }

    // Check for compute queue support
    uint32_t queueFamilyCount = 0;
    vkGetPhysicalDeviceQueueFamilyProperties(bestDevice, &queueFamilyCount, nullptr);
    std::vector<VkQueueFamilyProperties> queueFamilies(queueFamilyCount);
    vkGetPhysicalDeviceQueueFamilyProperties(bestDevice, &queueFamilyCount, queueFamilies.data());

    bool hasComputeQueue = false;
    for (auto& qf : queueFamilies) {
        if (qf.queueFlags & VK_QUEUE_COMPUTE_BIT) {
            hasComputeQueue = true;
            break;
        }
    }

    if (!hasComputeQueue) {
        LOGI("nativeDetectGpu: no compute queue — GPU not usable for inference");
        vkDestroyInstance(instance, nullptr);
        return nullptr;
    }

    // Read device properties
    VkPhysicalDeviceProperties props{};
    vkGetPhysicalDeviceProperties(bestDevice, &props);

    // Populate outStats
    jlong stats[2];
    stats[0] = static_cast<jlong>(props.apiVersion);
    stats[1] = static_cast<jlong>(bestHeapSize);
    env->SetLongArrayRegion(outStats, 0, 2, stats);

    LOGI("nativeDetectGpu: GPU='%s' apiVersion=%u heapSize=%llu hasCompute=%d",
         props.deviceName,
         props.apiVersion,
         (unsigned long long)bestHeapSize,
         hasComputeQueue ? 1 : 0);

    vkDestroyInstance(instance, nullptr);
    return env->NewStringUTF(props.deviceName);
}

extern "C" JNIEXPORT void JNICALL
Java_com_write4me_llama_1flutter_1android_LlamaFlutterAndroidPlugin_nativeLoadModel(
    JNIEnv* env, jobject thiz,
    jstring path, jlong n_threads, jlong ctx_size, jlong n_gpu_layers,
    jobject progress_callback) {

    const char* model_path = env->GetStringUTFChars(path, nullptr);
    LOGI("Loading model: %s", model_path);

    // Model parameters
    llama_model_params model_params = llama_model_default_params();
    model_params.n_gpu_layers = n_gpu_layers;

    // Load model
    g_model = llama_model_load_from_file(model_path, model_params);
    env->ReleaseStringUTFChars(path, model_path);

    if (!g_model) {
        LOGE("Failed to load model");
        jclass exception = env->FindClass("java/lang/RuntimeException");
        env->ThrowNew(exception, "Failed to load model");
        return;
    }

    // Context parameters with memory optimizations for low-end devices
    llama_context_params ctx_params = llama_context_default_params();
    ctx_params.n_ctx = ctx_size;
    ctx_params.n_threads = n_threads;
    ctx_params.n_threads_batch = n_threads;
    ctx_params.abort_callback = [](void*) { return g_stop_flag.load(); };
    ctx_params.abort_callback_data = nullptr;

    // Memory optimization: reduce memory usage by limiting batch processing
    ctx_params.n_batch = 512;  // Process smaller batches to reduce memory spikes

    // Create context (using new API)
    g_ctx = llama_init_from_model(g_model, ctx_params);
    if (!g_ctx) {
        llama_model_free(g_model);
        g_model = nullptr;
        jclass exception = env->FindClass("java/lang/RuntimeException");
        env->ThrowNew(exception, "Failed to create context");
        return;
    }

    // Get vocab for tokenization
    g_vocab = llama_model_get_vocab(g_model);
    LOGI("Vocab initialized: %p", (void*)g_vocab);

    if (!g_vocab) {
        llama_free(g_ctx);
        llama_model_free(g_model);
        g_ctx = nullptr;
        g_model = nullptr;
        jclass exception = env->FindClass("java/lang/RuntimeException");
        env->ThrowNew(exception, "Failed to get vocab from model");
        return;
    }

    // Reset KV cache position counter for new model
    g_n_past = 0;

    // Report progress completion
    if (progress_callback) {
        jclass callbackClass = env->GetObjectClass(progress_callback);
        jmethodID invokeMethod = env->GetMethodID(callbackClass, "invoke", "(Ljava/lang/Object;)Ljava/lang/Object;");

        // Create Double object for 1.0
        jclass doubleClass = env->FindClass("java/lang/Double");
        jmethodID doubleConstructor = env->GetMethodID(doubleClass, "<init>", "(D)V");
        jobject doubleObj = env->NewObject(doubleClass, doubleConstructor, 1.0);

        env->CallObjectMethod(progress_callback, invokeMethod, doubleObj);
        env->DeleteLocalRef(doubleObj);
        env->DeleteLocalRef(callbackClass);
    }

    LOGI("Model loaded successfully");
}

static jobject g_token_callback = nullptr;

extern "C" JNIEXPORT void JNICALL
Java_com_write4me_llama_1flutter_1android_LlamaFlutterAndroidPlugin_nativeGenerate(
    JNIEnv* env, jobject thiz,
    jstring prompt, jlong max_tokens,
    jdouble temperature, jdouble top_p, jlong top_k, jdouble min_p, jdouble typical_p,
    jdouble repeat_penalty, jdouble frequency_penalty, jdouble presence_penalty, jlong repeat_last_n,
    jlong mirostat, jdouble mirostat_tau, jdouble mirostat_eta,
    jlong seed, jboolean penalize_newline,
    jobject token_callback) {

    if (g_token_callback != nullptr) {
        env->DeleteGlobalRef(g_token_callback);
        g_token_callback = nullptr;
    }
    g_token_callback = env->NewGlobalRef(token_callback);

    if (!g_model || !g_ctx || !g_vocab) {
        jclass exception = env->FindClass("java/lang/IllegalStateException");
        env->ThrowNew(exception, "Model not loaded");
        return;
    }

    // The app sends the complete bounded prompt/history each time. Do not
    // append it to the previous request's KV cache (including another account).
    llama_memory_clear(llama_get_memory(g_ctx), true);
    g_n_past = 0;

    // Tokenize the fresh prompt
    const jchar* prompt_chars = env->GetStringChars(prompt, nullptr);
    if (prompt_chars == nullptr) return; // Preserve pending JNI allocation error.
    const std::string sanitized_prompt = pipspeak::utf16ToUtf8(
        reinterpret_cast<const uint16_t*>(prompt_chars), env->GetStringLength(prompt));
    env->ReleaseStringChars(prompt, prompt_chars);
    // Never log private prompts, transcripts, or document passages.
    const char* sanitized_cstr = sanitized_prompt.c_str();
    const int sanitized_len = sanitized_prompt.length();

    // Tokenize prompt - when tokens is NULL, llama_tokenize returns NEGATIVE count
    const int n_prompt_tokens = -llama_tokenize(g_vocab, sanitized_cstr, sanitized_len, nullptr, 0, true, true);
    LOGI("Token count: %d", n_prompt_tokens);

    if (n_prompt_tokens <= 0) {
        jclass exception = env->FindClass("java/lang/RuntimeException");
        char error_msg[256];
        snprintf(error_msg, sizeof(error_msg), "Failed to tokenize prompt (got %d tokens)", n_prompt_tokens);
        env->ThrowNew(exception, error_msg);
        return;
    }
    std::vector<llama_token> tokens(n_prompt_tokens);
    const int actual_tokens = llama_tokenize(g_vocab, sanitized_cstr, sanitized_len, tokens.data(), tokens.size(), true, true);
    if (actual_tokens < 0) {
        jclass exception = env->FindClass("java/lang/RuntimeException");
        env->ThrowNew(exception, "Failed to tokenize prompt");
        return;
    }
    tokens.resize(actual_tokens);

    const int n_ctx = llama_n_ctx(g_ctx);

    // Check if the context will be exceeded and apply a sliding window for the KV cache
    if (g_n_past + (int)tokens.size() > n_ctx) {
        const int n_discard = n_ctx / 4; // Discard the oldest 25% of the context
        LOGI("Context is full, shifting KV cache by %d tokens", n_discard);

        // Remove the oldest tokens from the sequence
        llama_memory_seq_rm(llama_get_memory(g_ctx), 0, 0, n_discard);

        // Shift the remaining tokens
        llama_memory_seq_add(llama_get_memory(g_ctx), 0, n_discard, g_n_past, -n_discard);

        // Update the past tokens count
        g_n_past -= n_discard;
    }

    // Process prompt in batches to handle long inputs
    const int max_batch_size = 512;
    int tokens_processed = 0;

    llama_batch batch = llama_batch_init(max_batch_size, 0, 1);

    LOGI("Context size: %d", llama_n_ctx(g_ctx));

    while (tokens_processed < tokens.size()) {
        batch.n_tokens = 0;
        int batch_size = std::min((int)tokens.size() - tokens_processed, max_batch_size);

        for (int i = 0; i < batch_size; i++) {
            batch.token[batch.n_tokens] = tokens[tokens_processed + i];
            batch.pos[batch.n_tokens] = g_n_past + tokens_processed + i;
            batch.n_seq_id[batch.n_tokens] = 1;
            batch.seq_id[batch.n_tokens][0] = 0;
            batch.logits[batch.n_tokens] = (tokens_processed + i == tokens.size() - 1);
            batch.n_tokens++;
        }

        LOGI("Decoding batch starting at position %d with %d tokens", g_n_past + tokens_processed, batch.n_tokens);

        LOGI("Decoding batch: g_n_past=%d, batch_size=%d", g_n_past + tokens_processed, batch.n_tokens);
        int decode_result = llama_decode(g_ctx, batch);
        if (decode_result != 0) {
            LOGE("❌ DECODE FAILED! Result code: %d", decode_result);
            llama_batch_free(batch);
            jclass exception = env->FindClass("java/lang/RuntimeException");
            env->ThrowNew(exception, "Failed to decode prompt");
            return;
        }
        tokens_processed += batch_size;
    }

    LOGI("✅ Decode successful! Processed %d total tokens", tokens_processed);

    // Update position counter after decoding the whole prompt
    g_n_past += tokens.size();

    // Create sampler chain with all parameters
    if (g_sampler) {
        llama_sampler_free(g_sampler);
    }

    // Use seed or current time
    uint32_t sampler_seed = (seed >= 0) ? static_cast<uint32_t>(seed) : static_cast<uint32_t>(time(nullptr));

    llama_sampler_chain_params sparams = llama_sampler_chain_default_params();
    g_sampler = llama_sampler_chain_init(sparams);

    // Add penalties first (applied to logits before sampling)
    if (repeat_penalty != 1.0f || frequency_penalty != 0.0f || presence_penalty != 0.0f) {
        llama_sampler_chain_add(g_sampler, llama_sampler_init_penalties(
            repeat_last_n,              // penalty_last_n
            repeat_penalty,             // penalty_repeat
            frequency_penalty,          // penalty_freq
            presence_penalty            // penalty_present
        ));
    }

    // Temperature sampling
    llama_sampler_chain_add(g_sampler, llama_sampler_init_temp(temperature));

    // Add advanced samplers if enabled
    if (mirostat == 1) {
        llama_sampler_chain_add(g_sampler, llama_sampler_init_mirostat(
            llama_vocab_n_tokens(g_vocab),  // Use the vocab to get n_vocab
            sampler_seed,
            mirostat_tau,
            mirostat_eta,
            100  // m parameter
        ));
    } else if (mirostat == 2) {
        llama_sampler_chain_add(g_sampler, llama_sampler_init_mirostat_v2(
            sampler_seed,
            mirostat_tau,
            mirostat_eta
        ));
    } else {
        // Standard sampling chain (only if mirostat is disabled)
        if (min_p > 0.0f && min_p < 1.0f) {
            llama_sampler_chain_add(g_sampler, llama_sampler_init_min_p(min_p, 1));
        }

        if (typical_p < 1.0f) {
            llama_sampler_chain_add(g_sampler, llama_sampler_init_typical(typical_p, 1));
        }

        if (top_k > 0) {
            llama_sampler_chain_add(g_sampler, llama_sampler_init_top_k(top_k));
        }

        if (top_p < 1.0f) {
            llama_sampler_chain_add(g_sampler, llama_sampler_init_top_p(top_p, 1));
        }
    }

    // Final distribution sampler
    llama_sampler_chain_add(g_sampler, llama_sampler_init_dist(sampler_seed));

    // Get callback method
    jclass callbackClass = env->GetObjectClass(token_callback);
    jmethodID invokeMethod = env->GetMethodID(callbackClass, "invoke", "(Ljava/lang/Object;)Ljava/lang/Object;");

    pipspeak::Utf8StreamDecoder text_decoder;
    auto emit_text = [&](const std::u16string& text) {
        if (text.empty()) return;
        const jstring token_str = env->NewString(
            reinterpret_cast<const jchar*>(text.data()), static_cast<jsize>(text.size()));
        if (token_str == nullptr) return;
        env->CallObjectMethod(g_token_callback, invokeMethod, token_str);
        env->DeleteLocalRef(token_str);
    };

    // Generation loop
    LOGI("Starting generation loop: max_tokens=%lld", max_tokens);
    for (int i = 0; i < max_tokens && !g_stop_flag; i++) {
        // Sample next token
        llama_token new_token_id = llama_sampler_sample(g_sampler, g_ctx, -1);

        // Check for end of generation (EOS/EOD tokens)
        if (llama_vocab_is_eog(g_vocab, new_token_id)) {
            LOGI("EOS token detected, ending generation.");
            break;
        }

        // BPE pieces are bytes, not necessarily complete UTF-8 characters.
        char buffer[256];
        int32_t length = llama_token_to_piece(g_vocab, new_token_id, buffer, sizeof(buffer), 0, true);
        std::vector<char> large_piece;
        const char* piece_bytes = buffer;
        if (length < 0) {
            large_piece.resize(static_cast<std::size_t>(-length));
            length = llama_token_to_piece(g_vocab, new_token_id, large_piece.data(), large_piece.size(), 0, true);
            piece_bytes = large_piece.data();
        }
        if (length > 0) emit_text(text_decoder.append(piece_bytes, static_cast<std::size_t>(length)));
        if (env->ExceptionCheck()) break;

        // Prepare next batch
        batch.n_tokens = 0;
        batch.token[batch.n_tokens] = new_token_id;
        batch.pos[batch.n_tokens] = g_n_past;  // Use the tracked position
        batch.n_seq_id[batch.n_tokens] = 1;
        batch.seq_id[batch.n_tokens][0] = 0;
        batch.logits[batch.n_tokens] = true;
        batch.n_tokens++;

        if (llama_decode(g_ctx, batch) != 0) {
            LOGE("Failed to decode after sampling token %d", i + 1);
            break;
        }

        // Update position counter after each generated token
        g_n_past++;
    }
    if (!g_stop_flag && !env->ExceptionCheck()) emit_text(text_decoder.finish());
    LOGI("Generation loop finished.");

    if (g_token_callback != nullptr) {
        env->DeleteGlobalRef(g_token_callback);
        g_token_callback = nullptr;
    }

    // After generation completion, ensure the KV cache is properly managed
    // In some llama.cpp versions, KV cache management may be needed between generations
    // For chat applications, we want to maintain conversation context

    llama_batch_free(batch);
    env->DeleteLocalRef(callbackClass);
}

extern "C" JNIEXPORT void JNICALL
Java_com_write4me_llama_1flutter_1android_LlamaFlutterAndroidPlugin_nativeResetStop(
    JNIEnv* env, jobject thiz) {
    // Called before scheduling a new generation, never from inside JNI decode.
    g_stop_flag = false;
}

extern "C" JNIEXPORT void JNICALL
Java_com_write4me_llama_1flutter_1android_LlamaFlutterAndroidPlugin_nativeStop(
    JNIEnv* env, jobject thiz) {
    g_stop_flag = true;
    // When stopping generation, we just set the flag - KV cache management handled by llama.cpp
}

extern "C" JNIEXPORT void JNICALL
Java_com_write4me_llama_1flutter_1android_LlamaFlutterAndroidPlugin_nativeFreeModel(
    JNIEnv* env, jobject thiz) {
    if (g_token_callback != nullptr) {
        env->DeleteGlobalRef(g_token_callback);
        g_token_callback = nullptr;
    }

    if (g_sampler) {
        llama_sampler_free(g_sampler);
        g_sampler = nullptr;
    }
    if (g_ctx) {
        llama_free(g_ctx);
        g_ctx = nullptr;
    }
    if (g_model) {
        llama_model_free(g_model);
        g_model = nullptr;
    }
    g_vocab = nullptr;
    g_n_past = 0;  // Reset position counter

    LOGI("Model freed");
}

extern "C" JNIEXPORT jint JNICALL
Java_com_write4me_llama_1flutter_1android_LlamaFlutterAndroidPlugin_nativeGetTokensUsed(
    JNIEnv* env, jobject thiz) {
    return g_n_past;
}

extern "C" JNIEXPORT jint JNICALL
Java_com_write4me_llama_1flutter_1android_LlamaFlutterAndroidPlugin_nativeGetContextSize(
    JNIEnv* env, jobject thiz) {
    return g_ctx ? llama_n_ctx(g_ctx) : 0;
}

extern "C" JNIEXPORT void JNICALL
Java_com_write4me_llama_1flutter_1android_LlamaFlutterAndroidPlugin_nativeClearContext(
    JNIEnv* env, jobject thiz) {
    if (!g_ctx) {
        LOGE("Cannot clear context: context is null");
        return;
    }

    llama_memory_t mem = llama_get_memory(g_ctx);
    if (mem) {
        llama_memory_seq_rm(mem, 0, 0, -1);
        g_n_past = 0;
        LOGI("Context cleared, g_n_past reset to 0");
    } else {
        LOGE("Failed to get memory object from context");
    }
}

extern "C" JNIEXPORT void JNICALL
Java_com_write4me_llama_1flutter_1android_LlamaFlutterAndroidPlugin_nativeSetSystemPromptLength(
    JNIEnv* env, jobject thiz, jint length) {
    // Currently not used but available for future smart context management
    LOGI("System prompt length set to: %d tokens (currently unused)", length);
}
