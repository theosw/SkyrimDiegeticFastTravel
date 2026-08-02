#include "DNT/ParchmentCore.h"

#include <algorithm>
#include <cmath>
#include <utility>

namespace
{
    std::string TrimLabel(std::string a_value)
    {
        const auto first = a_value.find_first_not_of(" \t\r\n");
        if (first == std::string::npos) {
            return {};
        }
        const auto last = a_value.find_last_not_of(" \t\r\n");
        return a_value.substr(first, last - first + 1);
    }

    bool HasPrintableLabel(std::string_view a_value)
    {
        if (a_value.empty() || a_value.size() > 96) {
            return false;
        }
        return std::ranges::any_of(a_value, [](const unsigned char a_character) {
            return a_character > 0x20;
        });
    }

    bool IsNormalizedPoint(const float a_x, const float a_y)
    {
        return std::isfinite(a_x) && std::isfinite(a_y) &&
               a_x >= 0.0F && a_x <= 1.0F &&
               a_y >= 0.0F && a_y <= 1.0F;
    }

    bool HasPrefix(const std::string_view a_value, const std::string_view a_prefix)
    {
        return a_value.size() >= a_prefix.size() &&
               a_value.substr(0, a_prefix.size()) == a_prefix;
    }

    bool HasCaseInsensitiveFuzSuffix(const std::string_view a_value)
    {
        if (a_value.size() < 4) {
            return false;
        }
        const auto suffix = a_value.substr(a_value.size() - 4);
        return suffix[0] == '.' &&
               (suffix[1] == 'f' || suffix[1] == 'F') &&
               (suffix[2] == 'u' || suffix[2] == 'U') &&
               (suffix[3] == 'z' || suffix[3] == 'Z');
    }
}

bool DNT::Parchment::IsValidIdentifier(const std::string_view a_value)
{
    if (a_value.empty() || a_value.size() > 64) {
        return false;
    }

    return std::ranges::all_of(a_value, [](const unsigned char a_character) {
        return (a_character >= 'a' && a_character <= 'z') ||
               (a_character >= 'A' && a_character <= 'Z') ||
               (a_character >= '0' && a_character <= '9') ||
               a_character == '_' || a_character == '-' || a_character == '.';
    });
}

bool DNT::Parchment::ValidateRequestHeader(const Request& a_request, std::string& a_error)
{
    if (!IsValidIdentifier(a_request.requestId)) {
        a_error = "request ID must contain 1-64 letters, digits, dots, underscores, or hyphens";
        return false;
    }
    if (!IsValidIdentifier(a_request.providerId)) {
        a_error = "provider ID must contain 1-64 letters, digits, dots, underscores, or hyphens";
        return false;
    }
    if (a_request.texturePath.size() > 512) {
        a_error = "texture path exceeds 512 characters";
        return false;
    }
    if (!std::isfinite(a_request.artAspectRatio) || a_request.artAspectRatio < 0.5F ||
        a_request.artAspectRatio > 3.0F) {
        a_error = "art aspect ratio must be between 0.5 and 3.0";
        return false;
    }
    if (!std::isfinite(a_request.textureUvMinX) || !std::isfinite(a_request.textureUvMinY) ||
        !std::isfinite(a_request.textureUvMaxX) || !std::isfinite(a_request.textureUvMaxY) ||
        a_request.textureUvMinX < 0.0F || a_request.textureUvMinY < 0.0F ||
        a_request.textureUvMaxX > 1.0F || a_request.textureUvMaxY > 1.0F ||
        a_request.textureUvMaxX <= a_request.textureUvMinX ||
        a_request.textureUvMaxY <= a_request.textureUvMinY) {
        a_error = "texture UV crop must be an ordered rectangle inside [0, 1]";
        return false;
    }
    if (a_request.routeOrigin &&
        !IsNormalizedPoint(a_request.routeOrigin->normalizedX, a_request.routeOrigin->normalizedY)) {
        a_error = "route origin coordinates must be normalized to [0, 1]";
        return false;
    }
    return true;
}

bool DNT::Parchment::SetRouteOrigin(Request& a_request, const RouteOrigin a_origin, std::string& a_error)
{
    if (a_request.routeOrigin) {
        a_error = "route origin is already set";
        return false;
    }
    if (!IsNormalizedPoint(a_origin.normalizedX, a_origin.normalizedY)) {
        a_error = "route origin coordinates must be normalized to [0, 1]";
        return false;
    }
    a_request.routeOrigin = a_origin;
    return true;
}

bool DNT::Parchment::AddDestination(Request& a_request, Destination a_destination, std::string& a_error)
{
    if (a_request.destinations.size() >= MaxDestinations) {
        a_error = "destination limit exceeded";
        return false;
    }
    if (!IsValidIdentifier(a_destination.id)) {
        a_error = "destination ID is invalid";
        return false;
    }
    a_destination.label = TrimLabel(std::move(a_destination.label));
    if (!HasPrintableLabel(a_destination.label)) {
        a_error = "destination label is empty or too long";
        return false;
    }
    if (a_destination.fare < 0) {
        a_error = "destination fare cannot be negative";
        return false;
    }
    if (!IsNormalizedPoint(a_destination.normalizedX, a_destination.normalizedY)) {
        a_error = "destination coordinates must be normalized to [0, 1]";
        return false;
    }
    const auto duplicate = std::ranges::find(a_request.destinations, a_destination.id, &Destination::id);
    if (duplicate != a_request.destinations.end()) {
        a_error = "destination IDs must be unique";
        return false;
    }

    a_request.destinations.push_back(std::move(a_destination));
    return true;
}

bool DNT::Parchment::ValidateReadyRequest(const Request& a_request, std::string& a_error)
{
    if (!ValidateRequestHeader(a_request, a_error)) {
        return false;
    }
    if (a_request.destinations.empty()) {
        a_error = "request has no destinations";
        return false;
    }
    if (a_request.destinations.size() > MaxDestinations) {
        a_error = "destination limit exceeded";
        return false;
    }
    return true;
}

bool DNT::Parchment::ValidatePresentation(
    const Presentation& a_presentation,
    std::string& a_error)
{
    const auto& voicePath = a_presentation.voicePath;
    if (voicePath.empty() || voicePath.size() > MaxPresentationVoicePath) {
        a_error = "presentation voice path must contain 1-260 characters";
        return false;
    }
    if (!HasPrefix(voicePath, "Voice/") || !HasCaseInsensitiveFuzSuffix(voicePath)) {
        a_error = "presentation voice path must be a Voice/*.fuz path";
        return false;
    }
    if (voicePath.find("..") != std::string::npos ||
        !std::ranges::all_of(voicePath, [](const unsigned char a_character) {
            return (a_character >= 'a' && a_character <= 'z') ||
                   (a_character >= 'A' && a_character <= 'Z') ||
                   (a_character >= '0' && a_character <= '9') ||
                   a_character == '_' || a_character == '-' ||
                   a_character == '.' || a_character == '/' ||
                   a_character == ' ';
        })) {
        a_error = "presentation voice path contains an unsafe character";
        return false;
    }

    const auto& subtitle = a_presentation.subtitle;
    if (subtitle.empty() || subtitle.size() > MaxPresentationSubtitle) {
        a_error = "presentation subtitle must contain 1-512 bytes";
        return false;
    }
    if (!std::ranges::all_of(subtitle, [](const unsigned char a_character) {
            return a_character >= 0x20 && a_character != 0x7F;
        })) {
        a_error = "presentation subtitle contains a control character";
        return false;
    }
    if (!std::isfinite(a_presentation.voiceDurationSeconds) ||
        a_presentation.voiceDurationSeconds <= 0.0F ||
        a_presentation.voiceDurationSeconds > 30.0F) {
        a_error = "presentation voice duration must be inside (0, 30] seconds";
        return false;
    }
    return true;
}

float DNT::Parchment::PresentationWindowSeconds(const float a_voiceDurationSeconds)
{
    return a_voiceDurationSeconds + PresentationTaskMarginSeconds;
}

DNT::Parchment::Layout DNT::Parchment::ComputeLayout(
    const float a_viewportWidth,
    const float a_viewportHeight,
    const float a_artAspectRatio)
{
    const auto viewportWidth = std::max(a_viewportWidth, 640.0F);
    const auto viewportHeight = std::max(a_viewportHeight, 360.0F);
    const auto aspect = std::clamp(a_artAspectRatio, 0.5F, 3.0F);

    constexpr float maxWidthFraction = 0.86F;
    constexpr float maxHeightFraction = 0.88F;
    const auto width = std::min(viewportWidth * maxWidthFraction, viewportHeight * maxHeightFraction * aspect);
    const auto height = width / aspect;
    const auto scale = std::clamp(height / 900.0F, 0.75F, 1.6F);

    return Layout{
        .left = (viewportWidth - width) * 0.5F,
        .top = (viewportHeight - height) * 0.5F,
        .width = width,
        .height = height,
        .markerWidth = 168.0F * scale,
        .markerHeight = 38.0F * scale
    };
}
