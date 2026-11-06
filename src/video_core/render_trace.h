// SPDX-License-Identifier: GPL-3.0-or-later

#pragma once

#include <cstdlib>

#include "common/common_types.h"

namespace VideoCommon::RenderTrace {

inline bool Enabled() {
    static const bool enabled = std::getenv("EDEN_NX2_RENDER_TRACE") != nullptr;
    return enabled;
}

inline bool SampleFrame(u64 frame) {
    static const u64 interval = [] {
        const char* value = std::getenv("EDEN_C0_RENDER_TRACE_EVERY");
        const u64 frames = value ? std::strtoull(value, nullptr, 10) : 600;
        return frames == 0 ? 600 : frames;
    }();
    return Enabled() && frame % interval == 0;
}

} // namespace VideoCommon::RenderTrace
