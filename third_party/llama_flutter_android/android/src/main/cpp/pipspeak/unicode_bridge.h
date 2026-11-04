#pragma once

#include <cstddef>
#include <cstdint>
#include <string>

// JNI strings are UTF-16, not standard UTF-8. Model token pieces may split a
// Unicode scalar between calls. Keep conversions independent of Android/JNI so
// the same code can be exercised by a normal host C++ compiler.
namespace pipspeak {
inline void appendUtf8(std::string& output, uint32_t scalar) {
    if (scalar <= 0x7f) output.push_back(static_cast<char>(scalar));
    else if (scalar <= 0x7ff) {
        output.push_back(static_cast<char>(0xc0 | (scalar >> 6)));
        output.push_back(static_cast<char>(0x80 | (scalar & 0x3f)));
    } else if (scalar <= 0xffff) {
        output.push_back(static_cast<char>(0xe0 | (scalar >> 12)));
        output.push_back(static_cast<char>(0x80 | ((scalar >> 6) & 0x3f)));
        output.push_back(static_cast<char>(0x80 | (scalar & 0x3f)));
    } else {
        output.push_back(static_cast<char>(0xf0 | (scalar >> 18)));
        output.push_back(static_cast<char>(0x80 | ((scalar >> 12) & 0x3f)));
        output.push_back(static_cast<char>(0x80 | ((scalar >> 6) & 0x3f)));
        output.push_back(static_cast<char>(0x80 | (scalar & 0x3f)));
    }
}

inline std::string utf16ToUtf8(const uint16_t* characters, std::size_t length) {
    std::string output;
    output.reserve(length);
    for (std::size_t index = 0; index < length; ++index) {
        uint32_t scalar = characters[index];
        if (scalar >= 0xd800 && scalar <= 0xdbff) {
            if (index + 1 < length && characters[index + 1] >= 0xdc00 && characters[index + 1] <= 0xdfff) {
                scalar = 0x10000 + ((scalar - 0xd800) << 10) + (characters[++index] - 0xdc00);
            } else scalar = 0xfffd;
        } else if (scalar >= 0xdc00 && scalar <= 0xdfff) scalar = 0xfffd;
        appendUtf8(output, scalar);
    }
    return output;
}

class Utf8StreamDecoder {
public:
    std::u16string append(const char* bytes, std::size_t length, bool finish = false) {
        pending_.append(bytes, length);
        std::u16string output;
        std::size_t cursor = 0;
        while (cursor < pending_.size()) {
            const auto lead = static_cast<uint8_t>(pending_[cursor]);
            std::size_t count;
            uint32_t scalar;
            if (lead < 0x80) { count = 1; scalar = lead; }
            else if (lead >= 0xc2 && lead <= 0xdf) { count = 2; scalar = lead & 0x1f; }
            else if (lead >= 0xe0 && lead <= 0xef) { count = 3; scalar = lead & 0x0f; }
            else if (lead >= 0xf0 && lead <= 0xf4) { count = 4; scalar = lead & 0x07; }
            else { output.push_back(0xfffd); ++cursor; continue; }
            if (pending_.size() - cursor < count) {
                if (finish) { output.push_back(0xfffd); cursor = pending_.size(); }
                break;
            }
            bool valid = true;
            for (std::size_t index = 1; index < count; ++index) {
                const auto byte = static_cast<uint8_t>(pending_[cursor + index]);
                if ((byte & 0xc0) != 0x80) { valid = false; break; }
                scalar = (scalar << 6) | (byte & 0x3f);
            }
            if (!valid || (count == 2 && scalar < 0x80) || (count == 3 && scalar < 0x800) ||
                (count == 4 && scalar < 0x10000) || (scalar >= 0xd800 && scalar <= 0xdfff) || scalar > 0x10ffff) {
                output.push_back(0xfffd); ++cursor; continue;
            }
            cursor += count;
            if (scalar <= 0xffff) output.push_back(static_cast<char16_t>(scalar));
            else {
                scalar -= 0x10000;
                output.push_back(static_cast<char16_t>(0xd800 | (scalar >> 10)));
                output.push_back(static_cast<char16_t>(0xdc00 | (scalar & 0x3ff)));
            }
        }
        pending_.erase(0, cursor);
        return output;
    }
    std::u16string finish() { return append("", 0, true); }
private:
    std::string pending_;
};
} // namespace pipspeak
