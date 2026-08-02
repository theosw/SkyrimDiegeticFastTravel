#pragma once

#include <cstdint>
#include <optional>
#include <string>
#include <string_view>
#include <vector>

namespace DNT::Parchment
{
    inline constexpr std::size_t MaxDestinations = 24;
    inline constexpr std::size_t MaxPresentationVoicePath = 260;
    inline constexpr std::size_t MaxPresentationSubtitle = 512;
    inline constexpr float PresentationTaskMarginSeconds = 0.20F;

    struct Destination
    {
        std::string id;
        std::string label;
        std::int32_t fare{ 0 };
        float normalizedX{ 0.5F };
        float normalizedY{ 0.5F };
    };

    struct RouteOrigin
    {
        float normalizedX{ 0.5F };
        float normalizedY{ 0.5F };
    };

    struct Request
    {
        std::string requestId;
        std::string providerId;
        std::string texturePath;
        float artAspectRatio{ 1.5F };
        float textureUvMinX{ 0.0F };
        float textureUvMinY{ 0.0F };
        float textureUvMaxX{ 1.0F };
        float textureUvMaxY{ 1.0F };
        std::optional<RouteOrigin> routeOrigin;
        std::vector<Destination> destinations;
    };

    struct Presentation
    {
        std::string voicePath;
        std::string subtitle;
        float voiceDurationSeconds{ 0.0F };
    };

    struct Layout
    {
        float left{ 0.0F };
        float top{ 0.0F };
        float width{ 0.0F };
        float height{ 0.0F };
        float markerWidth{ 0.0F };
        float markerHeight{ 0.0F };
    };

    [[nodiscard]] bool IsValidIdentifier(std::string_view a_value);
    [[nodiscard]] bool ValidateRequestHeader(const Request& a_request, std::string& a_error);
    [[nodiscard]] bool SetRouteOrigin(Request& a_request, RouteOrigin a_origin, std::string& a_error);
    [[nodiscard]] bool AddDestination(Request& a_request, Destination a_destination, std::string& a_error);
    [[nodiscard]] bool ValidateReadyRequest(const Request& a_request, std::string& a_error);
    [[nodiscard]] bool ValidatePresentation(const Presentation& a_presentation, std::string& a_error);
    [[nodiscard]] float PresentationWindowSeconds(float a_voiceDurationSeconds);
    [[nodiscard]] Layout ComputeLayout(float a_viewportWidth, float a_viewportHeight, float a_artAspectRatio);
}
