#include "../third_party/llama_flutter_android/android/src/main/cpp/pipspeak/unicode_bridge.h"
#include <iostream>
#include <stdexcept>
using namespace std::string_literals;

void require(bool condition, const char* message) {
    if (!condition) throw std::runtime_error(message);
}

int main() {
    const std::u16string original = u"Kumusta café 語言 🎤\0test"s;
    const std::string bytes = pipspeak::utf16ToUtf8(
        reinterpret_cast<const uint16_t*>(original.data()), original.size());
    pipspeak::Utf8StreamDecoder decoder;
    std::u16string decoded;
    for (char byte : bytes) decoded += decoder.append(&byte, 1);
    decoded += decoder.finish();
    require(decoded == original, "byte-split Unicode round trip failed");

    // Every possible token boundary must preserve supplementary/BMP scalars.
    for (std::size_t split = 0; split <= bytes.size(); ++split) {
        pipspeak::Utf8StreamDecoder partial;
        auto result = partial.append(bytes.data(), split);
        result += partial.append(bytes.data() + split, bytes.size() - split);
        result += partial.finish();
        require(result == original, "two-token boundary corrupted Unicode");
    }
    const uint16_t invalid[] = {0xd800, 'A', 0xdc00};
    require(pipspeak::utf16ToUtf8(invalid, 3) == "\xef\xbf\xbd" "A" "\xef\xbf\xbd", "unpaired surrogate handling failed");
    pipspeak::Utf8StreamDecoder incomplete;
    require(incomplete.append("\xf0\x9f", 2).empty(), "partial emoji emitted prematurely");
    require(incomplete.finish() == u"\ufffd", "incomplete scalar did not finish safely");
    pipspeak::Utf8StreamDecoder illegal;
    const auto result = illegal.append("\xed\xa0\x80" "A", 4);
    require(!result.empty() && result.back() == u'A', "invalid scalar swallowed following ASCII");
    std::cout << "PASS Unicode JNI bridge: full/byte-split/all-boundary UTF-8, emoji, NUL, malformed scalars\n";
}
