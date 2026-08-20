#pragma once

#include "DNT/ParchmentCore.h"

#include <RE/Skyrim.h>

#include <cstdint>
#include <string_view>

namespace DNT::ParchmentMenu
{
    inline constexpr std::string_view ResultEvent = "DNT_ParchmentResult";

    [[nodiscard]] bool Initialize();
    [[nodiscard]] bool IsAvailable();
    [[nodiscard]] bool BeginRequest(
        std::string_view a_requestId,
        std::string_view a_providerId,
        RE::TESObjectREFR* a_source,
        std::string_view a_texturePath,
        float a_artAspectRatio,
        float a_textureUvMinX,
        float a_textureUvMinY,
        float a_textureUvMaxX,
        float a_textureUvMaxY);
    [[nodiscard]] bool SetMarkerTextures(
        std::string_view a_requestId,
        std::string_view a_idleTexturePath,
        std::string_view a_selectedTexturePath);
    [[nodiscard]] bool SetFallbackArtwork(
        std::string_view a_requestId,
        Parchment::ArtworkProfile a_artwork);
    [[nodiscard]] bool SetOriginMarkerTexture(
        std::string_view a_requestId,
        std::string_view a_texturePath);
    [[nodiscard]] bool SetSelectionRingTexture(
        std::string_view a_requestId,
        std::string_view a_texturePath);
    [[nodiscard]] bool SetSelectionRingScale(
        std::string_view a_requestId,
        float a_scale);
    [[nodiscard]] bool SetSourceLabel(
        std::string_view a_requestId,
        std::string_view a_sourceLabel);
    [[nodiscard]] bool SetPaymentLabelPosition(
        std::string_view a_requestId,
        float a_normalizedX,
        float a_normalizedY);
    [[nodiscard]] bool SetRouteOrigin(
        std::string_view a_requestId,
        float a_normalizedX,
        float a_normalizedY);
    [[nodiscard]] bool AddRouteLandmark(
        std::string_view a_requestId,
        float a_normalizedX,
        float a_normalizedY);
    [[nodiscard]] bool AddDestination(
        std::string_view a_requestId,
        std::string_view a_destinationId,
        std::string_view a_label,
        std::int32_t a_fare,
        float a_normalizedX,
        float a_normalizedY);
    [[nodiscard]] bool AddStyledDestination(
        std::string_view a_requestId,
        std::string_view a_destinationId,
        std::string_view a_label,
        std::int32_t a_fare,
        float a_normalizedX,
        float a_normalizedY,
        std::string_view a_markerTexturePath,
        float a_markerScale,
        float a_ringOffsetX,
        float a_ringOffsetY,
        float a_ringScale);
    [[nodiscard]] bool SetDestinationMarkerScale(
        std::string_view a_requestId,
        std::string_view a_destinationId,
        float a_scale);
    [[nodiscard]] bool SetDestinationSelectionRingStyle(
        std::string_view a_requestId,
        std::string_view a_destinationId,
        float a_offsetX,
        float a_offsetY,
        float a_scale);
    [[nodiscard]] bool SetDestinationSelectionRingTexture(
        std::string_view a_requestId,
        std::string_view a_destinationId,
        std::string_view a_texturePath);
    [[nodiscard]] bool Show(std::string_view a_requestId);
    [[nodiscard]] bool Cancel(std::string_view a_requestId);
}
