#pragma once

#include <cstdint>
#include <optional>
#include <string>
#include <string_view>
#include <vector>

namespace DNT::Parchment
{
    // A full CFTO carriage sheet exposes 27 native destinations. Leave a small
    // amount of headroom for providers that add DLC stops without weakening the
    // bounded-request guarantee at the Papyrus/native boundary.
    inline constexpr std::size_t MaxDestinations = 32;
    inline constexpr std::size_t MaxRouteLandmarks = 48;
    inline constexpr std::size_t MaxRouteSegments = 192;
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
        std::string idleMarkerTexturePath;
        float markerScale{ 1.0F };
        float selectionRingOffsetX{ 0.0F };
        float selectionRingOffsetY{ 0.0F };
        float selectionRingScale{ 1.0F };
        std::string selectionRingTexturePath;
    };

    struct RouteOrigin
    {
        float normalizedX{ 0.5F };
        float normalizedY{ 0.5F };
    };

    struct RoutePoint
    {
        float normalizedX{ 0.5F };
        float normalizedY{ 0.5F };
    };

    struct RouteSegment
    {
        RoutePoint start;
        RoutePoint end;
    };

    struct Request
    {
        std::string requestId;
        std::string providerId;
        std::string sourceLabel;
        std::string texturePath;
        std::string overlayTexturePath;
        std::string idleMarkerTexturePath;
        std::string selectedMarkerTexturePath;
        std::string originMarkerTexturePath;
        std::string selectionRingTexturePath;
        float selectionRingScale{ 2.0F };
        float artAspectRatio{ 1.5F };
        float textureUvMinX{ 0.0F };
        float textureUvMinY{ 0.0F };
        float textureUvMaxX{ 1.0F };
        float textureUvMaxY{ 1.0F };
        std::optional<RoutePoint> paymentLabelPosition;
        std::optional<RouteOrigin> routeOrigin;
        std::vector<RouteSegment> routeSegments;
        std::vector<RoutePoint> routeLandmarks;
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
    [[nodiscard]] bool SetSourceLabel(Request& a_request, std::string a_sourceLabel, std::string& a_error);
    [[nodiscard]] bool SetOverlayTexture(Request& a_request, std::string a_texturePath, std::string& a_error);
    [[nodiscard]] bool SetMarkerTextures(
        Request& a_request,
        std::string a_idleTexturePath,
        std::string a_selectedTexturePath,
        std::string& a_error);
    [[nodiscard]] bool SetOriginMarkerTexture(
        Request& a_request,
        std::string a_texturePath,
        std::string& a_error);
    [[nodiscard]] bool SetSelectionRingTexture(
        Request& a_request,
        std::string a_texturePath,
        std::string& a_error);
    [[nodiscard]] bool SetSelectionRingScale(
        Request& a_request,
        float a_scale,
        std::string& a_error);
    [[nodiscard]] bool SetPaymentLabelPosition(Request& a_request, RoutePoint a_position, std::string& a_error);
    [[nodiscard]] bool SetRouteOrigin(Request& a_request, RouteOrigin a_origin, std::string& a_error);
    [[nodiscard]] bool AddRouteSegment(Request& a_request, RouteSegment a_segment, std::string& a_error);
    [[nodiscard]] bool AddRouteLandmark(Request& a_request, RoutePoint a_landmark, std::string& a_error);
    [[nodiscard]] bool AddDestination(Request& a_request, Destination a_destination, std::string& a_error);
    [[nodiscard]] bool SetDestinationMarkerTexture(
        Request& a_request,
        std::string_view a_destinationId,
        std::string a_texturePath,
        std::string& a_error);
    [[nodiscard]] bool SetDestinationMarkerScale(
        Request& a_request,
        std::string_view a_destinationId,
        float a_scale,
        std::string& a_error);
    [[nodiscard]] bool SetDestinationSelectionRingStyle(
        Request& a_request,
        std::string_view a_destinationId,
        float a_offsetX,
        float a_offsetY,
        float a_scale,
        std::string& a_error);
    [[nodiscard]] bool SetDestinationSelectionRingTexture(
        Request& a_request,
        std::string_view a_destinationId,
        std::string a_texturePath,
        std::string& a_error);
    [[nodiscard]] std::vector<RoutePoint> FindRoutePath(const Request& a_request, const Destination& a_destination);
    [[nodiscard]] std::optional<std::size_t> FindDirectionalDestination(
        const Request& a_request,
        std::optional<std::size_t> a_currentIndex,
        float a_directionX,
        float a_directionY);
    [[nodiscard]] bool ValidateReadyRequest(const Request& a_request, std::string& a_error);
    [[nodiscard]] bool ValidatePresentation(const Presentation& a_presentation, std::string& a_error);
    [[nodiscard]] float PresentationWindowSeconds(float a_voiceDurationSeconds);
    [[nodiscard]] Layout ComputeLayout(float a_viewportWidth, float a_viewportHeight, float a_artAspectRatio);
    [[nodiscard]] std::vector<float> ComputeDestinationHitSizes(const Request& a_request, const Layout& a_layout);
}
