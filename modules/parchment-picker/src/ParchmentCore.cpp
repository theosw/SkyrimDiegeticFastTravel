#include "DNT/ParchmentCore.h"

#include <algorithm>
#include <cmath>
#include <limits>
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

    bool IsValidSelectionRingScale(const float a_scale)
    {
        return std::isfinite(a_scale) && a_scale >= 0.5F && a_scale <= 4.0F;
    }

    bool IsValidDestinationRingStyle(
        const float a_offsetX,
        const float a_offsetY,
        const float a_scale)
    {
        return std::isfinite(a_offsetX) && std::isfinite(a_offsetY) &&
               a_offsetX >= -1.0F && a_offsetX <= 1.0F &&
               a_offsetY >= -1.0F && a_offsetY <= 1.0F &&
               std::isfinite(a_scale) && a_scale >= 0.5F && a_scale <= 2.0F;
    }

    bool IsValidDestinationMarkerScale(const float a_scale)
    {
        return std::isfinite(a_scale) && a_scale >= 0.5F && a_scale <= 2.0F;
    }

    constexpr float RoutePointTolerance = 0.0001F;

    bool SameRoutePoint(
        const DNT::Parchment::RoutePoint& a_left,
        const DNT::Parchment::RoutePoint& a_right)
    {
        return std::abs(a_left.normalizedX - a_right.normalizedX) <= RoutePointTolerance &&
               std::abs(a_left.normalizedY - a_right.normalizedY) <= RoutePointTolerance;
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
    if (a_request.idleMarkerTexturePath.size() > 512 ||
        a_request.selectedMarkerTexturePath.size() > 512 ||
        a_request.originMarkerTexturePath.size() > 512 ||
        a_request.selectionRingTexturePath.size() > 512) {
        a_error = "marker texture path exceeds 512 characters";
        return false;
    }
    if (a_request.idleMarkerTexturePath.empty() !=
        a_request.selectedMarkerTexturePath.empty()) {
        a_error = "idle and selected marker texture paths must be set together";
        return false;
    }
    if (!IsValidSelectionRingScale(a_request.selectionRingScale)) {
        a_error = "selection-ring scale must be between 0.5 and 4.0";
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
    if (a_request.paymentLabelPosition &&
        !IsNormalizedPoint(
            a_request.paymentLabelPosition->normalizedX,
            a_request.paymentLabelPosition->normalizedY)) {
        a_error = "payment label coordinates must be normalized to [0, 1]";
        return false;
    }
    return true;
}

bool DNT::Parchment::SetSourceLabel(
    Request& a_request,
    std::string a_sourceLabel,
    std::string& a_error)
{
    if (!a_request.sourceLabel.empty()) {
        a_error = "source label is already set";
        return false;
    }
    a_sourceLabel = TrimLabel(std::move(a_sourceLabel));
    if (!HasPrintableLabel(a_sourceLabel)) {
        a_error = "source label is empty or too long";
        return false;
    }
    a_request.sourceLabel = std::move(a_sourceLabel);
    return true;
}

bool DNT::Parchment::SetMarkerTextures(
    Request& a_request,
    std::string a_idleTexturePath,
    std::string a_selectedTexturePath,
    std::string& a_error)
{
    if (!a_request.idleMarkerTexturePath.empty() ||
        !a_request.selectedMarkerTexturePath.empty()) {
        a_error = "marker textures are already set";
        return false;
    }
    if (a_idleTexturePath.empty() || a_idleTexturePath.size() > 512 ||
        a_selectedTexturePath.empty() || a_selectedTexturePath.size() > 512) {
        a_error = "marker texture paths must each contain 1-512 characters";
        return false;
    }
    a_request.idleMarkerTexturePath = std::move(a_idleTexturePath);
    a_request.selectedMarkerTexturePath = std::move(a_selectedTexturePath);
    return true;
}

bool DNT::Parchment::SetOriginMarkerTexture(
    Request& a_request,
    std::string a_texturePath,
    std::string& a_error)
{
    if (!a_request.originMarkerTexturePath.empty()) {
        a_error = "origin marker texture is already set";
        return false;
    }
    if (a_texturePath.empty() || a_texturePath.size() > 512) {
        a_error = "origin marker texture path must contain 1-512 characters";
        return false;
    }
    a_request.originMarkerTexturePath = std::move(a_texturePath);
    return true;
}

bool DNT::Parchment::SetSelectionRingTexture(
    Request& a_request,
    std::string a_texturePath,
    std::string& a_error)
{
    if (!a_request.selectionRingTexturePath.empty()) {
        a_error = "selection-ring texture is already set";
        return false;
    }
    if (a_texturePath.empty() || a_texturePath.size() > 512) {
        a_error = "selection-ring texture path must contain 1-512 characters";
        return false;
    }
    a_request.selectionRingTexturePath = std::move(a_texturePath);
    return true;
}

bool DNT::Parchment::SetSelectionRingScale(
    Request& a_request,
    const float a_scale,
    std::string& a_error)
{
    if (!IsValidSelectionRingScale(a_scale)) {
        a_error = "selection-ring scale must be between 0.5 and 4.0";
        return false;
    }
    a_request.selectionRingScale = a_scale;
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

bool DNT::Parchment::SetPaymentLabelPosition(
    Request& a_request,
    const RoutePoint a_position,
    std::string& a_error)
{
    if (a_request.paymentLabelPosition) {
        a_error = "payment label position is already set";
        return false;
    }
    if (!IsNormalizedPoint(a_position.normalizedX, a_position.normalizedY)) {
        a_error = "payment label coordinates must be normalized to [0, 1]";
        return false;
    }
    a_request.paymentLabelPosition = a_position;
    return true;
}

bool DNT::Parchment::AddRouteLandmark(
    Request& a_request,
    const RoutePoint a_landmark,
    std::string& a_error)
{
    if (a_request.routeLandmarks.size() >= MaxRouteLandmarks) {
        a_error = "route landmark limit exceeded";
        return false;
    }
    if (!IsNormalizedPoint(a_landmark.normalizedX, a_landmark.normalizedY)) {
        a_error = "route landmark coordinates must be normalized to [0, 1]";
        return false;
    }
    if (std::ranges::any_of(a_request.routeLandmarks, [&](const RoutePoint& a_existing) {
            return SameRoutePoint(a_existing, a_landmark);
        })) {
        a_error = "route landmark is already present";
        return false;
    }
    a_request.routeLandmarks.push_back(a_landmark);
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
    if (a_destination.idleMarkerTexturePath.size() > 512 ||
        a_destination.selectionRingTexturePath.size() > 512) {
        a_error = "destination texture path exceeds 512 characters";
        return false;
    }
    if (!IsValidDestinationMarkerScale(a_destination.markerScale)) {
        a_error = "destination marker scale must be between 0.5 and 2.0";
        return false;
    }
    if (!IsValidDestinationRingStyle(
            a_destination.selectionRingOffsetX,
            a_destination.selectionRingOffsetY,
            a_destination.selectionRingScale)) {
        a_error = "destination selection-ring offsets must be inside [-1, 1] and scale inside [0.5, 2.0]";
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

bool DNT::Parchment::SetDestinationMarkerScale(
    Request& a_request,
    const std::string_view a_destinationId,
    const float a_scale,
    std::string& a_error)
{
    const auto destination = std::ranges::find(
        a_request.destinations,
        a_destinationId,
        &Destination::id);
    if (destination == a_request.destinations.end()) {
        a_error = "destination marker-scale target was not found";
        return false;
    }
    if (!IsValidDestinationMarkerScale(a_scale)) {
        a_error = "destination marker scale must be between 0.5 and 2.0";
        return false;
    }
    destination->markerScale = a_scale;
    return true;
}

bool DNT::Parchment::SetDestinationSelectionRingStyle(
    Request& a_request,
    const std::string_view a_destinationId,
    const float a_offsetX,
    const float a_offsetY,
    const float a_scale,
    std::string& a_error)
{
    const auto destination = std::ranges::find(
        a_request.destinations,
        a_destinationId,
        &Destination::id);
    if (destination == a_request.destinations.end()) {
        a_error = "destination selection-ring target was not found";
        return false;
    }
    if (!IsValidDestinationRingStyle(a_offsetX, a_offsetY, a_scale)) {
        a_error = "destination selection-ring offsets must be inside [-1, 1] and scale inside [0.5, 2.0]";
        return false;
    }
    destination->selectionRingOffsetX = a_offsetX;
    destination->selectionRingOffsetY = a_offsetY;
    destination->selectionRingScale = a_scale;
    return true;
}

bool DNT::Parchment::SetDestinationSelectionRingTexture(
    Request& a_request,
    const std::string_view a_destinationId,
    std::string a_texturePath,
    std::string& a_error)
{
    const auto destination = std::ranges::find(
        a_request.destinations,
        a_destinationId,
        &Destination::id);
    if (destination == a_request.destinations.end()) {
        a_error = "destination selection-ring target was not found";
        return false;
    }
    if (!destination->selectionRingTexturePath.empty()) {
        a_error = "destination selection-ring texture is already set";
        return false;
    }
    if (a_texturePath.empty() || a_texturePath.size() > 512) {
        a_error = "destination selection-ring texture path must contain 1-512 characters";
        return false;
    }
    destination->selectionRingTexturePath = std::move(a_texturePath);
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
    if (!HasPrintableLabel(a_request.sourceLabel)) {
        a_error = "request has no source label";
        return false;
    }
    if (a_request.destinations.size() > MaxDestinations) {
        a_error = "destination limit exceeded";
        return false;
    }
    if (a_request.routeLandmarks.size() > MaxRouteLandmarks) {
        a_error = "route landmark limit exceeded";
        return false;
    }
    if (std::ranges::any_of(a_request.destinations, [](const Destination& a_destination) {
            return a_destination.idleMarkerTexturePath.size() > 512 ||
                a_destination.selectionRingTexturePath.size() > 512;
        })) {
        a_error = "destination marker texture path exceeds 512 characters";
        return false;
    }
    if (std::ranges::any_of(a_request.destinations, [](const Destination& a_destination) {
            return !IsValidDestinationMarkerScale(a_destination.markerScale);
        })) {
        a_error = "destination marker scale is invalid";
        return false;
    }
    if (std::ranges::any_of(a_request.destinations, [](const Destination& a_destination) {
            return !IsValidDestinationRingStyle(
                a_destination.selectionRingOffsetX,
                a_destination.selectionRingOffsetY,
                a_destination.selectionRingScale);
        })) {
        a_error = "destination selection-ring style is invalid";
        return false;
    }
    if (std::ranges::any_of(a_request.routeLandmarks, [](const RoutePoint& a_landmark) {
            return !IsNormalizedPoint(a_landmark.normalizedX, a_landmark.normalizedY);
        })) {
        a_error = "route landmark coordinates must be normalized to [0, 1]";
        return false;
    }
    return true;
}

std::optional<std::size_t> DNT::Parchment::FindDirectionalDestination(
    const Request& a_request,
    const std::optional<std::size_t> a_currentIndex,
    const float a_directionX,
    const float a_directionY)
{
    if (a_request.destinations.empty() ||
        !std::isfinite(a_directionX) || !std::isfinite(a_directionY)) {
        return std::nullopt;
    }

    const auto directionLength = std::hypot(a_directionX, a_directionY);
    if (directionLength <= 0.0001F) {
        return std::nullopt;
    }
    const auto directionX = a_directionX / directionLength;
    const auto directionY = a_directionY / directionLength;

    std::optional<std::size_t> bestIndex;
    auto bestScore = std::numeric_limits<float>::max();

    if (!a_currentIndex || *a_currentIndex >= a_request.destinations.size()) {
        // There is deliberately no default selection. The first navigation
        // press enters the map from the opposite edge of the requested
        // direction, preferring a marker near the perpendicular center line.
        for (std::size_t index = 0; index < a_request.destinations.size(); ++index) {
            const auto& destination = a_request.destinations[index];
            const auto projection =
                destination.normalizedX * directionX + destination.normalizedY * directionY;
            const auto perpendicularFromCenter = std::abs(
                (destination.normalizedX - 0.5F) * -directionY +
                (destination.normalizedY - 0.5F) * directionX);
            const auto score = projection + perpendicularFromCenter * 0.25F;
            if (score < bestScore) {
                bestScore = score;
                bestIndex = index;
            }
        }
        return bestIndex;
    }

    const auto& current = a_request.destinations[*a_currentIndex];
    for (std::size_t index = 0; index < a_request.destinations.size(); ++index) {
        if (index == *a_currentIndex) {
            continue;
        }
        const auto& destination = a_request.destinations[index];
        const auto deltaX = destination.normalizedX - current.normalizedX;
        const auto deltaY = destination.normalizedY - current.normalizedY;
        const auto forward = deltaX * directionX + deltaY * directionY;
        if (forward <= 0.0001F) {
            continue;
        }
        const auto lateral = std::abs(deltaX * -directionY + deltaY * directionX);
        // Prefer a nearby marker in the intended direction, with enough
        // lateral penalty that a more aligned row/column wins naturally.
        const auto score = forward + lateral * 2.0F;
        if (score < bestScore) {
            bestScore = score;
            bestIndex = index;
        }
    }
    return bestIndex;
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

std::vector<float> DNT::Parchment::ComputeDestinationHitSizes(
    const Request& a_request,
    const Layout& a_layout)
{
    std::vector<float> sizes;
    sizes.reserve(a_request.destinations.size());
    const auto preferredSize = std::max(a_layout.markerHeight * 2.65F, 84.0F);
    if (a_request.destinations.size() < 2) {
        sizes.assign(a_request.destinations.size(), preferredSize);
        return sizes;
    }

    constexpr float separationMargin = 0.88F;
    for (std::size_t index = 0; index < a_request.destinations.size(); ++index) {
        const auto& destination = a_request.destinations[index];
        auto nearestSeparation = std::numeric_limits<float>::infinity();
        for (std::size_t otherIndex = 0; otherIndex < a_request.destinations.size(); ++otherIndex) {
            if (index == otherIndex) {
                continue;
            }
            const auto& other = a_request.destinations[otherIndex];
            const auto horizontal = std::abs(
                destination.normalizedX - other.normalizedX) * a_layout.width;
            const auto vertical = std::abs(
                destination.normalizedY - other.normalizedY) * a_layout.height;
            nearestSeparation = std::min(
                nearestSeparation,
                std::max(horizontal, vertical));
        }
        sizes.push_back(std::min(preferredSize, nearestSeparation * separationMargin));
    }
    return sizes;
}
