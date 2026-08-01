#pragma once

#include <cstdint>
#include <optional>
#include <string>
#include <string_view>
#include <vector>

namespace DNT::Parchment
{
    inline constexpr std::size_t MaxDestinations = 24;

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
    [[nodiscard]] Layout ComputeLayout(float a_viewportWidth, float a_viewportHeight, float a_artAspectRatio);
}
