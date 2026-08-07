#include "DNT/ParchmentMenu.h"

#include "DNT/MenuFrameworkAPI.h"

#include <RE/R/Renderer.h>

#include <algorithm>
#include <array>
#include <atomic>
#include <cmath>
#include <unordered_map>
#include <unordered_set>

namespace
{
    struct HiddenHudLayer
    {
        std::string menuName;
        RE::GPtr<RE::GFxMovieView> movie;
        bool wasVisible{ false };
        std::optional<double> rootAlpha;
    };

    struct ActiveRequest
    {
        DNT::Parchment::Request request;
        RE::FormID sourceFormId{ 0 };
        bool visible{ false };
        std::vector<HiddenHudLayer> hiddenHudLayers;
    };

    // These are optional movie names used by vanilla and common LoreRim HUD
    // plugins. The list mirrors LoreRim's installed Ultimate Immersion Toggle
    // targets; absent menus are skipped without becoming dependencies.
    inline constexpr std::array<std::string_view, 14> hudMenuNames{
        "HUD Menu",
        "MiniMapMenu",
        "TrueHUD",
        "lvlWidget",
        "goldWidget",
        "gametimeWidget",
        "shoutWidget",
        "resistWidget",
        "playtimeWidget",
        "weightWidget",
        "equipWidget_STB",
        "STBActiveEffects",
        "BTPS Menu",
        "BTPS Ovelay Menu"
    };

    constexpr DNT::MenuFramework::Color MakeColor(
        const std::uint8_t a_red,
        const std::uint8_t a_green,
        const std::uint8_t a_blue,
        const std::uint8_t a_alpha)
    {
        return static_cast<DNT::MenuFramework::Color>(a_red) |
               (static_cast<DNT::MenuFramework::Color>(a_green) << 8U) |
               (static_cast<DNT::MenuFramework::Color>(a_blue) << 16U) |
               (static_cast<DNT::MenuFramework::Color>(a_alpha) << 24U);
    }

    [[nodiscard]] bool EqualsAsciiInsensitive(
        const std::string_view a_left,
        const std::string_view a_right)
    {
        if (a_left.size() != a_right.size()) {
            return false;
        }
        for (std::size_t index = 0; index < a_left.size(); ++index) {
            auto left = a_left[index];
            auto right = a_right[index];
            if (left >= 'A' && left <= 'Z') {
                left = static_cast<char>(left - 'A' + 'a');
            }
            if (right >= 'A' && right <= 'Z') {
                right = static_cast<char>(right - 'A' + 'a');
            }
            if (left != right) {
                return false;
            }
        }
        return true;
    }

    void DrawFerryDestinationMarker(
        DNT::MenuFramework::API& a_framework,
        const DNT::MenuFramework::DrawList a_drawList,
        const DNT::MenuFramework::Texture a_idleMarkerTexture,
        const DNT::MenuFramework::Texture a_selectedMarkerTexture,
        const DNT::MenuFramework::Vec2 a_center,
        const float a_radius,
        const bool a_highlighted,
        const bool a_scaleOnlyHighlight = false,
        const float a_artScale = 1.0F)
    {
        if (!a_drawList) {
            return;
        }

        constexpr auto darkInk = MakeColor(39, 25, 15, 238);
        constexpr auto parchmentIvory = MakeColor(238, 229, 207, 245);
        constexpr std::int32_t closedPolyline = 1;
        const auto baseExtent = std::clamp(a_radius, 17.0F, 34.0F);
        const auto extent = baseExtent * a_artScale *
            (a_highlighted && a_scaleOnlyHighlight ? 1.18F : 1.0F);
        const auto ink = darkInk;

        if (a_highlighted) {
            if (a_selectedMarkerTexture) {
                const auto iconExtent = extent * 1.12F;
                a_framework.AddImage(
                    a_drawList,
                    a_selectedMarkerTexture,
                    { a_center.x - iconExtent, a_center.y - iconExtent },
                    { a_center.x + iconExtent, a_center.y + iconExtent });
                return;
            }
        }

        if (!a_highlighted && a_idleMarkerTexture) {
            const auto iconExtent = extent * 1.12F;
            a_framework.AddImage(
                a_drawList,
                a_idleMarkerTexture,
                { a_center.x - iconExtent, a_center.y - iconExtent },
                { a_center.x + iconExtent, a_center.y + iconExtent });
            return;
        }

        const DNT::MenuFramework::Vec2 mastTop{
            a_center.x - extent * 0.10F,
            a_center.y - extent * 0.78F
        };
        const DNT::MenuFramework::Vec2 mastBottom{
            mastTop.x,
            a_center.y + extent * 0.28F
        };
        const std::array<DNT::MenuFramework::Vec2, 3> sail{
            mastTop,
            DNT::MenuFramework::Vec2{
                a_center.x + extent * 0.67F,
                a_center.y + extent * 0.08F },
            DNT::MenuFramework::Vec2{
                mastTop.x,
                a_center.y + extent * 0.08F }
        };
        const std::array<DNT::MenuFramework::Vec2, 5> hull{
            DNT::MenuFramework::Vec2{
                a_center.x - extent * 0.82F,
                a_center.y + extent * 0.20F },
            DNT::MenuFramework::Vec2{
                a_center.x + extent * 0.82F,
                a_center.y + extent * 0.20F },
            DNT::MenuFramework::Vec2{
                a_center.x + extent * 0.52F,
                a_center.y + extent * 0.60F },
            DNT::MenuFramework::Vec2{
                a_center.x - extent * 0.42F,
                a_center.y + extent * 0.60F },
            DNT::MenuFramework::Vec2{
                a_center.x - extent * 0.68F,
                a_center.y + extent * 0.43F }
        };

        a_framework.AddTriangleFilled(a_drawList, sail[0], sail[1], sail[2], parchmentIvory);
        a_framework.AddPolyline(
            a_drawList,
            sail.data(),
            static_cast<std::int32_t>(sail.size()),
            ink,
            closedPolyline,
            2.4F);
        a_framework.AddLine(a_drawList, mastTop, mastBottom, ink, 3.0F);
        a_framework.AddConcavePolyFilled(
            a_drawList,
            hull.data(),
            static_cast<std::int32_t>(hull.size()),
            parchmentIvory);
        a_framework.AddPolyline(
            a_drawList,
            hull.data(),
            static_cast<std::int32_t>(hull.size()),
            ink,
            closedPolyline,
            2.6F);
    }

    void DrawRouteConnection(
        DNT::MenuFramework::API& a_framework,
        const DNT::MenuFramework::DrawList a_drawList,
        const DNT::MenuFramework::Vec2 a_origin,
        const DNT::MenuFramework::Vec2 a_destination,
        const bool a_highlighted)
    {
        if (!a_drawList) {
            return;
        }

        constexpr auto darkInk = MakeColor(35, 22, 13, 215);
        constexpr auto gold = MakeColor(224, 184, 100, 220);
        constexpr auto activeGlow = MakeColor(235, 35, 42, 14);
        constexpr auto activeBody = MakeColor(218, 27, 39, 28);
        constexpr auto activeCenter = MakeColor(198, 20, 38, 42);
        if (a_highlighted) {
            a_framework.AddLine(a_drawList, a_origin, a_destination, activeGlow, 22.0F);
            a_framework.AddLine(a_drawList, a_origin, a_destination, activeBody, 13.0F);
            a_framework.AddLine(a_drawList, a_origin, a_destination, activeCenter, 7.0F);
        } else {
            a_framework.AddLine(a_drawList, a_origin, a_destination, darkInk, 4.0F);
            a_framework.AddLine(a_drawList, a_origin, a_destination, gold, 2.0F);
        }
    }

    void DrawActiveRoutePath(
        DNT::MenuFramework::API& a_framework,
        const DNT::MenuFramework::DrawList a_drawList,
        const std::vector<DNT::MenuFramework::Vec2>& a_points)
    {
        if (!a_drawList || a_points.size() < 2) {
            return;
        }

        std::vector<DNT::MenuFramework::Vec2> roundedPoints;
        roundedPoints.reserve(a_points.size() * 6);
        roundedPoints.push_back(a_points.front());
        for (std::size_t index = 1; index + 1 < a_points.size(); ++index) {
            const auto previous = a_points[index - 1];
            const auto corner = a_points[index];
            const auto next = a_points[index + 1];
            const auto incomingX = corner.x - previous.x;
            const auto incomingY = corner.y - previous.y;
            const auto outgoingX = next.x - corner.x;
            const auto outgoingY = next.y - corner.y;
            const auto incomingLength = std::hypot(incomingX, incomingY);
            const auto outgoingLength = std::hypot(outgoingX, outgoingY);
            if (incomingLength < 1.0F || outgoingLength < 1.0F) {
                roundedPoints.push_back(corner);
                continue;
            }

            const auto cornerRadius = std::min({
                44.0F,
                incomingLength * 0.42F,
                outgoingLength * 0.42F
            });
            const DNT::MenuFramework::Vec2 entry{
                corner.x - incomingX / incomingLength * cornerRadius,
                corner.y - incomingY / incomingLength * cornerRadius
            };
            const DNT::MenuFramework::Vec2 exit{
                corner.x + outgoingX / outgoingLength * cornerRadius,
                corner.y + outgoingY / outgoingLength * cornerRadius
            };
            roundedPoints.push_back(entry);
            constexpr std::size_t curveSteps = 10;
            for (std::size_t step = 1; step <= curveSteps; ++step) {
                const auto t = static_cast<float>(step) / static_cast<float>(curveSteps);
                const auto inverseT = 1.0F - t;
                roundedPoints.push_back({
                    inverseT * inverseT * entry.x + 2.0F * inverseT * t * corner.x +
                        t * t * exit.x,
                    inverseT * inverseT * entry.y + 2.0F * inverseT * t * corner.y +
                        t * t * exit.y
                });
            }
        }
        roundedPoints.push_back(a_points.back());

        constexpr auto activeGlow = MakeColor(235, 35, 42, 14);
        constexpr auto activeBody = MakeColor(218, 27, 39, 28);
        constexpr auto activeCenter = MakeColor(198, 20, 38, 42);
        constexpr std::int32_t openPolyline = 0;
        const auto pointCount = static_cast<std::int32_t>(roundedPoints.size());
        a_framework.AddPolyline(
            a_drawList,
            roundedPoints.data(),
            pointCount,
            activeGlow,
            openPolyline,
            22.0F);
        a_framework.AddPolyline(
            a_drawList,
            roundedPoints.data(),
            pointCount,
            activeBody,
            openPolyline,
            13.0F);
        a_framework.AddPolyline(
            a_drawList,
            roundedPoints.data(),
            pointCount,
            activeCenter,
            openPolyline,
            7.0F);
    }

    void DrawRouteOrigin(
        DNT::MenuFramework::API& a_framework,
        const DNT::MenuFramework::DrawList a_drawList,
        const DNT::MenuFramework::Texture a_markerTexture,
        const DNT::MenuFramework::Vec2 a_center,
        const float a_radius)
    {
        if (!a_drawList) {
            return;
        }

        const auto iconExtent = std::clamp(a_radius, 17.0F, 34.0F) * 1.12F;
        if (a_markerTexture) {
            a_framework.AddImage(
                a_drawList,
                a_markerTexture,
                { a_center.x - iconExtent, a_center.y - iconExtent },
                { a_center.x + iconExtent, a_center.y + iconExtent });
            return;
        }
        DrawFerryDestinationMarker(
            a_framework,
            a_drawList,
            nullptr,
            nullptr,
            a_center,
            a_radius,
            false);
    }

    void DrawRouteLandmark(
        DNT::MenuFramework::API& a_framework,
        const DNT::MenuFramework::DrawList a_drawList,
        const DNT::MenuFramework::Texture a_markerTexture,
        const DNT::MenuFramework::Vec2 a_center,
        const float a_radius)
    {
        if (!a_drawList || !a_markerTexture) {
            return;
        }

        constexpr auto inactiveGray = MakeColor(170, 174, 178, 168);
        const auto iconExtent = std::clamp(a_radius, 17.0F, 34.0F) * 1.12F;
        a_framework.AddImage(
            a_drawList,
            a_markerTexture,
            { a_center.x - iconExtent, a_center.y - iconExtent },
            { a_center.x + iconExtent, a_center.y + iconExtent },
            {},
            { 1.0F, 1.0F },
            inactiveGray);
    }

    struct DestinationVisual
    {
        DNT::MenuFramework::Vec2 center;
        float radius{ 0.0F };
        bool highlighted{ false };
    };

    template <std::size_t N>
    std::array<DNT::MenuFramework::Vec2, N> TransformCursorPoints(
        const std::array<DNT::MenuFramework::Vec2, N>& a_points,
        const DNT::MenuFramework::Vec2 a_origin,
        const float a_scale)
    {
        auto transformed = a_points;
        for (auto& point : transformed) {
            point.x = a_origin.x + point.x * a_scale;
            point.y = a_origin.y + point.y * a_scale;
        }
        return transformed;
    }

    void DrawParchmentCursor(
        DNT::MenuFramework::API& a_framework,
        const float a_viewportHeight)
    {
        constexpr std::int32_t noMouseCursor = -1;
        a_framework.SetMouseCursor(noMouseCursor);
        const auto drawList = a_framework.GetForegroundDrawList();
        if (!drawList) {
            return;
        }

        const auto mouse = a_framework.GetMousePos();
        if (!std::isfinite(mouse.x) || !std::isfinite(mouse.y) ||
            mouse.x < 0.0F || mouse.y < 0.0F) {
            return;
        }
        const auto scale = std::clamp(a_viewportHeight / 1440.0F, 0.8F, 1.25F);
        constexpr std::array<DNT::MenuFramework::Vec2, 8> outerShape{
            DNT::MenuFramework::Vec2{ 0.5F, 0.1F },
            DNT::MenuFramework::Vec2{ 30.4F, 24.75F },
            DNT::MenuFramework::Vec2{ 23.0F, 31.0F },
            DNT::MenuFramework::Vec2{ 26.0F, 37.2F },
            DNT::MenuFramework::Vec2{ 20.2F, 40.0F },
            DNT::MenuFramework::Vec2{ 16.8F, 35.2F },
            DNT::MenuFramework::Vec2{ 11.8F, 35.4F },
            DNT::MenuFramework::Vec2{ 5.0F, 38.6F }
        };
        constexpr std::array<DNT::MenuFramework::Vec2, 7> paleInset{
            DNT::MenuFramework::Vec2{ 3.1F, 4.7F },
            DNT::MenuFramework::Vec2{ 26.2F, 24.8F },
            DNT::MenuFramework::Vec2{ 19.5F, 30.1F },
            DNT::MenuFramework::Vec2{ 23.0F, 35.8F },
            DNT::MenuFramework::Vec2{ 20.4F, 37.0F },
            DNT::MenuFramework::Vec2{ 16.0F, 30.8F },
            DNT::MenuFramework::Vec2{ 8.1F, 33.0F }
        };
        constexpr std::array<DNT::MenuFramework::Vec2, 7> darkInset{
            DNT::MenuFramework::Vec2{ 6.0F, 9.0F },
            DNT::MenuFramework::Vec2{ 22.0F, 24.5F },
            DNT::MenuFramework::Vec2{ 16.6F, 29.0F },
            DNT::MenuFramework::Vec2{ 20.0F, 34.7F },
            DNT::MenuFramework::Vec2{ 18.8F, 35.4F },
            DNT::MenuFramework::Vec2{ 14.4F, 29.5F },
            DNT::MenuFramework::Vec2{ 10.0F, 30.5F }
        };
        const auto outer = TransformCursorPoints(outerShape, mouse, scale);
        const auto pale = TransformCursorPoints(paleInset, mouse, scale);
        const auto dark = TransformCursorPoints(darkInset, mouse, scale);

        constexpr auto border = MakeColor(165, 165, 165, 255);
        constexpr auto paleFill = MakeColor(230, 230, 230, 255);
        constexpr auto darkFill = MakeColor(18, 18, 18, 150);
        constexpr auto outline = MakeColor(20, 20, 20, 230);
        constexpr std::int32_t closedPolyline = 1;
        a_framework.AddConcavePolyFilled(
            drawList, outer.data(), static_cast<std::int32_t>(outer.size()), border);
        a_framework.AddPolyline(
            drawList,
            outer.data(),
            static_cast<std::int32_t>(outer.size()),
            outline,
            closedPolyline,
            1.25F * scale);
        a_framework.AddConcavePolyFilled(
            drawList, pale.data(), static_cast<std::int32_t>(pale.size()), paleFill);
        a_framework.AddConcavePolyFilled(
            drawList, dark.data(), static_cast<std::int32_t>(dark.size()), darkFill);
    }

    std::mutex requestLock;
    std::optional<ActiveRequest> activeRequest;
    std::atomic_bool navigationFocusEngaged{ false };
    DNT::MenuFramework::Window* pickerWindow{ nullptr };
    std::int64_t inputRegistration{ -1 };
    DNT::MenuFramework::Texture loadedTexture{ nullptr };
    std::string loadedTexturePath;
    DNT::MenuFramework::Texture loadedOverlayTexture{ nullptr };
    std::string loadedOverlayTexturePath;
    std::string loadedRequestId;
    bool textureLoadAttempted{ false };
    bool overlayTextureLoadAttempted{ false };
    constexpr std::string_view defaultSelectedMarkerTexturePath =
        "Data/textures/DiegeticTravel/shipwreck-marker.dds";
    constexpr std::string_view defaultIdleMarkerTexturePath =
        "Data/textures/DiegeticTravel/docks-marker.dds";
    DNT::MenuFramework::Texture loadedIdleMarkerTexture{ nullptr };
    std::string loadedIdleMarkerTexturePath;
    bool idleMarkerTextureLoadAttempted{ false };
    DNT::MenuFramework::Texture loadedSelectedMarkerTexture{ nullptr };
    std::string loadedSelectedMarkerTexturePath;
    bool selectedMarkerTextureLoadAttempted{ false };
    DNT::MenuFramework::Texture loadedOriginMarkerTexture{ nullptr };
    std::string loadedOriginMarkerTexturePath;
    bool originMarkerTextureLoadAttempted{ false };
    std::unordered_map<std::string, DNT::MenuFramework::Texture> loadedDestinationMarkerTextures;
    std::unordered_set<std::string> destinationMarkerTextureLoadAttempts;

    void FinishRequest(std::int32_t a_selectionIndex, std::string_view a_reason)
    {
        ActiveRequest finished;
        {
            std::scoped_lock lock(requestLock);
            if (!activeRequest) {
                return;
            }
            finished = *activeRequest;
            activeRequest.reset();
            if (pickerWindow) {
                pickerWindow->isOpen = false;
            }
        }

        for (auto& layer : finished.hiddenHudLayers) {
            if (layer.rootAlpha) {
                layer.movie->SetVariable("_root._alpha", RE::GFxValue(*layer.rootAlpha));
            }
            layer.movie->SetVisible(layer.wasVisible);
            logger::info(
                "PARCHMENT_HUD_LAYER_RESTORED request={} menu=\"{}\" visible={} alpha={}",
                finished.request.requestId,
                layer.menuName,
                layer.wasVisible,
                layer.rootAlpha ? std::format("{:.1f}", *layer.rootAlpha) : "<unavailable>");
        }
        logger::info(
            "PARCHMENT_HUD_RESTORED request={} layers={}",
            finished.request.requestId,
            finished.hiddenHudLayers.size());

        if (a_selectionIndex >= 0 &&
            static_cast<std::size_t>(a_selectionIndex) < finished.request.destinations.size()) {
            logger::info(
                "PARCHMENT_SELECT request={} provider={} destination={} index={}",
                finished.request.requestId,
                finished.request.providerId,
                finished.request.destinations[static_cast<std::size_t>(a_selectionIndex)].id,
                a_selectionIndex);
        } else {
            a_selectionIndex = -1;
            logger::info(
                "PARCHMENT_CANCEL request={} provider={} reason={}",
                finished.request.requestId,
                finished.request.providerId,
                a_reason);
        }

        const auto requestId = finished.request.requestId;
        const auto sourceFormId = finished.sourceFormId;
        SKSE::GetTaskInterface()->AddTask([requestId, sourceFormId, a_selectionIndex]() {
            auto* source = RE::TESForm::LookupByID(sourceFormId);
            SKSE::ModCallbackEvent event{
                DNT::ParchmentMenu::ResultEvent.data(),
                requestId.c_str(),
                static_cast<float>(a_selectionIndex),
                source
            };
            SKSE::GetModCallbackEventSource()->SendEvent(&event);
        });
    }

    bool __stdcall OnInput(RE::InputEvent* a_event)
    {
        {
            std::scoped_lock lock(requestLock);
            if (!activeRequest || !activeRequest->visible) {
                return false;
            }
        }

        const auto* button = a_event ? a_event->AsButtonEvent() : nullptr;
        if (!button || !button->IsDown()) {
            return false;
        }

        const auto key = button->GetIDCode();
        const bool keyboardCancel =
            a_event->device == RE::INPUT_DEVICE::kKeyboard &&
            key == RE::BSWin32KeyboardDevice::Key::kEscape;
        const bool gamepadCancel =
            a_event->device == RE::INPUT_DEVICE::kGamepad &&
            key == RE::BSWin32GamepadDevice::Key::kB;
        if (keyboardCancel || gamepadCancel) {
            FinishRequest(-1, keyboardCancel ? "escape" : "gamepad_b");
            return true;
        }
        if (a_event->device == RE::INPUT_DEVICE::kKeyboard ||
            a_event->device == RE::INPUT_DEVICE::kGamepad) {
            navigationFocusEngaged.store(true, std::memory_order_relaxed);
        }
        return false;
    }

    void __stdcall RenderPicker()
    {
        ActiveRequest snapshot;
        {
            std::scoped_lock lock(requestLock);
            if (!activeRequest || !activeRequest->visible) {
                return;
            }
            snapshot = *activeRequest;
        }

        auto& framework = DNT::MenuFramework::API::GetSingleton();
        const auto screen = RE::BSGraphics::Renderer::GetScreenSize();
        const auto viewportWidth = static_cast<float>(screen.width ? screen.width : 1920);
        const auto viewportHeight = static_cast<float>(screen.height ? screen.height : 1080);
        const auto layout = DNT::Parchment::ComputeLayout(
            viewportWidth,
            viewportHeight,
            snapshot.request.artAspectRatio);

        framework.SetNextWindowPos({ 0.0F, 0.0F });
        framework.SetNextWindowSize({ viewportWidth, viewportHeight });
        framework.SetNextWindowBgAlpha(0.0F);
        constexpr std::int32_t windowFlags =
            DNT::MenuFramework::kNoTitleBar |
            DNT::MenuFramework::kNoResize |
            DNT::MenuFramework::kNoMove |
            DNT::MenuFramework::kNoScrollbar |
            DNT::MenuFramework::kNoCollapse |
            DNT::MenuFramework::kNoBackground |
            DNT::MenuFramework::kNoSavedSettings |
            DNT::MenuFramework::kNoDocking;

        std::optional<std::int32_t> selectedIndex;
        if (framework.Begin("Parchment travel map##DNT", windowFlags)) {
            if (snapshot.request.requestId != loadedRequestId) {
                for (const auto& [path, texture] : loadedDestinationMarkerTextures) {
                    if (texture && !path.empty()) {
                        framework.DisposeTexture(path);
                    }
                }
                loadedDestinationMarkerTextures.clear();
                destinationMarkerTextureLoadAttempts.clear();
                loadedRequestId = snapshot.request.requestId;
                textureLoadAttempted = false;
                overlayTextureLoadAttempted = false;
            }
            if (snapshot.request.texturePath != loadedTexturePath) {
                if (loadedTexture && !loadedTexturePath.empty()) {
                    framework.DisposeTexture(loadedTexturePath);
                }
                loadedTexture = nullptr;
                loadedTexturePath = snapshot.request.texturePath;
                textureLoadAttempted = false;
            }
            if (!loadedTexture && !loadedTexturePath.empty() && !textureLoadAttempted) {
                textureLoadAttempted = true;
                loadedTexture = framework.LoadTexture(loadedTexturePath);
                if (!loadedTexture) {
                    logger::warn("PARCHMENT_ART_MISSING path={}", loadedTexturePath);
                }
            }
            if (snapshot.request.overlayTexturePath != loadedOverlayTexturePath) {
                if (loadedOverlayTexture && !loadedOverlayTexturePath.empty()) {
                    framework.DisposeTexture(loadedOverlayTexturePath);
                }
                loadedOverlayTexture = nullptr;
                loadedOverlayTexturePath = snapshot.request.overlayTexturePath;
                overlayTextureLoadAttempted = false;
            }
            if (!loadedOverlayTexture && !loadedOverlayTexturePath.empty() &&
                !overlayTextureLoadAttempted) {
                overlayTextureLoadAttempted = true;
                loadedOverlayTexture = framework.LoadTexture(loadedOverlayTexturePath);
                if (!loadedOverlayTexture) {
                    logger::warn(
                        "PARCHMENT_OVERLAY_MISSING path={}",
                        loadedOverlayTexturePath);
                }
            }
            const std::string desiredSelectedMarkerTexturePath =
                snapshot.request.selectedMarkerTexturePath.empty() ?
                    std::string(defaultSelectedMarkerTexturePath) :
                    snapshot.request.selectedMarkerTexturePath;
            if (desiredSelectedMarkerTexturePath != loadedSelectedMarkerTexturePath) {
                if (loadedSelectedMarkerTexture && !loadedSelectedMarkerTexturePath.empty()) {
                    framework.DisposeTexture(loadedSelectedMarkerTexturePath);
                }
                loadedSelectedMarkerTexture = nullptr;
                loadedSelectedMarkerTexturePath = desiredSelectedMarkerTexturePath;
                selectedMarkerTextureLoadAttempted = false;
            }
            if (!loadedSelectedMarkerTexture && !loadedSelectedMarkerTexturePath.empty() &&
                !selectedMarkerTextureLoadAttempted) {
                selectedMarkerTextureLoadAttempted = true;
                loadedSelectedMarkerTexture = framework.LoadTexture(loadedSelectedMarkerTexturePath);
                if (!loadedSelectedMarkerTexture) {
                    logger::warn(
                        "PARCHMENT_SELECTED_MARKER_MISSING path={}",
                        loadedSelectedMarkerTexturePath);
                } else {
                    logger::info(
                        "PARCHMENT_SELECTED_MARKER_READY path={}",
                        loadedSelectedMarkerTexturePath);
                }
            }
            const std::string desiredOriginMarkerTexturePath =
                snapshot.request.originMarkerTexturePath;
            if (desiredOriginMarkerTexturePath != loadedOriginMarkerTexturePath) {
                if (loadedOriginMarkerTexture && !loadedOriginMarkerTexturePath.empty()) {
                    framework.DisposeTexture(loadedOriginMarkerTexturePath);
                }
                loadedOriginMarkerTexture = nullptr;
                loadedOriginMarkerTexturePath = desiredOriginMarkerTexturePath;
                originMarkerTextureLoadAttempted = false;
            }
            if (!loadedOriginMarkerTexture && !loadedOriginMarkerTexturePath.empty() &&
                !originMarkerTextureLoadAttempted) {
                originMarkerTextureLoadAttempted = true;
                loadedOriginMarkerTexture = framework.LoadTexture(loadedOriginMarkerTexturePath);
                if (!loadedOriginMarkerTexture) {
                    logger::warn(
                        "PARCHMENT_ORIGIN_MARKER_MISSING path={}",
                        loadedOriginMarkerTexturePath);
                } else {
                    logger::info(
                        "PARCHMENT_ORIGIN_MARKER_READY path={}",
                        loadedOriginMarkerTexturePath);
                }
            }
            const std::string desiredIdleMarkerTexturePath =
                snapshot.request.idleMarkerTexturePath.empty() ?
                    std::string(defaultIdleMarkerTexturePath) :
                    snapshot.request.idleMarkerTexturePath;
            if (desiredIdleMarkerTexturePath != loadedIdleMarkerTexturePath) {
                if (loadedIdleMarkerTexture && !loadedIdleMarkerTexturePath.empty()) {
                    framework.DisposeTexture(loadedIdleMarkerTexturePath);
                }
                loadedIdleMarkerTexture = nullptr;
                loadedIdleMarkerTexturePath = desiredIdleMarkerTexturePath;
                idleMarkerTextureLoadAttempted = false;
            }
            if (!loadedIdleMarkerTexture && !loadedIdleMarkerTexturePath.empty() &&
                !idleMarkerTextureLoadAttempted) {
                idleMarkerTextureLoadAttempted = true;
                loadedIdleMarkerTexture = framework.LoadTexture(loadedIdleMarkerTexturePath);
                if (!loadedIdleMarkerTexture) {
                    logger::warn(
                        "PARCHMENT_IDLE_MARKER_MISSING path={}",
                        loadedIdleMarkerTexturePath);
                } else {
                    logger::info(
                        "PARCHMENT_IDLE_MARKER_READY path={}",
                        loadedIdleMarkerTexturePath);
                }
            }
            for (const auto& destination : snapshot.request.destinations) {
                const auto& path = destination.idleMarkerTexturePath;
                if (path.empty() ||
                    (path == loadedIdleMarkerTexturePath && loadedIdleMarkerTexture) ||
                    loadedDestinationMarkerTextures.contains(path) ||
                    destinationMarkerTextureLoadAttempts.contains(path)) {
                    continue;
                }
                destinationMarkerTextureLoadAttempts.insert(path);
                if (auto texture = framework.LoadTexture(path)) {
                    loadedDestinationMarkerTextures.emplace(path, texture);
                    logger::info(
                        "PARCHMENT_DESTINATION_MARKER_READY destination={} path={}",
                        destination.id,
                        path);
                } else {
                    logger::warn(
                        "PARCHMENT_DESTINATION_MARKER_MISSING destination={} path={} fallback={}",
                        destination.id,
                        path,
                        loadedIdleMarkerTexturePath);
                }
            }

            if (loadedTexture) {
                framework.SetCursorScreenPos({ layout.left, layout.top });
                framework.Image(
                    loadedTexture,
                    { layout.width, layout.height },
                    { snapshot.request.textureUvMinX, snapshot.request.textureUvMinY },
                    { snapshot.request.textureUvMaxX, snapshot.request.textureUvMaxY });
            } else {
                framework.SetCursorScreenPos({ layout.left + 24.0F, layout.top + 24.0F });
                framework.TextUnformatted("Map artwork dependency is missing; selection remains available for testing.");
            }
            if (loadedOverlayTexture) {
                framework.SetCursorScreenPos({ layout.left, layout.top });
                framework.Image(
                    loadedOverlayTexture,
                    { layout.width, layout.height },
                    { 0.0F, 0.0F },
                    { 1.0F, 1.0F },
                    { 1.0F, 1.0F, 1.0F, 0.40F });
            }

            std::string focusedDescription;
            const auto drawList = framework.GetForegroundDrawList();
            std::vector<DestinationVisual> destinationVisuals;
            destinationVisuals.reserve(snapshot.request.destinations.size());
            const auto hitSizes = DNT::Parchment::ComputeDestinationHitSizes(
                snapshot.request,
                layout);
            std::optional<std::size_t> hoveredIndex;
            std::optional<std::size_t> focusedIndex;
            for (std::size_t index = 0; index < snapshot.request.destinations.size(); ++index) {
                const auto& destination = snapshot.request.destinations[index];
                const auto centerX = layout.left + destination.normalizedX * layout.width;
                const auto centerY = layout.top + destination.normalizedY * layout.height;
                const auto hitSize = hitSizes[index];
                framework.SetCursorScreenPos({
                    centerX - hitSize * 0.5F,
                    centerY - hitSize * 0.5F
                });

                const auto label = std::format(
                    "##DNT-destination-{}",
                    destination.id);
                if (framework.InvisibleButton(label, { hitSize, hitSize })) {
                    selectedIndex = static_cast<std::int32_t>(index);
                }
                if (framework.IsItemHovered()) {
                    hoveredIndex = index;
                }
                if (navigationFocusEngaged.load(std::memory_order_relaxed) &&
                    framework.IsItemFocused()) {
                    focusedIndex = index;
                }
                destinationVisuals.push_back({
                    .center = { centerX, centerY },
                    // Keep collision-safe hitboxes independent from the art:
                    // tightly clustered ports should not render smaller boats.
                    .radius = std::clamp(layout.markerHeight * 0.68F, 17.0F, 34.0F),
                    .highlighted = false
                });
            }

            // Mouse hover wins over retained navigation focus so exactly one
            // route is active. With no mouse hover, controller/keyboard focus
            // remains visible and navigable.
            const auto activeIndex = hoveredIndex ? hoveredIndex : focusedIndex;
            if (activeIndex && *activeIndex < destinationVisuals.size()) {
                destinationVisuals[*activeIndex].highlighted = true;
                const auto& activeDestination = snapshot.request.destinations[*activeIndex];
                focusedDescription = std::format(
                    "{} to {}    {} gold",
                    snapshot.request.sourceLabel,
                    activeDestination.label,
                    activeDestination.fare);
            }

            const auto isBoatProvider = EqualsAsciiInsensitive(
                snapshot.request.providerId,
                "boat");
            const auto isCollegeProvider = EqualsAsciiInsensitive(
                snapshot.request.providerId,
                "college");
            const auto isCarriageProvider = EqualsAsciiInsensitive(
                snapshot.request.providerId,
                "carriage");
            const auto showRouteLines = !isBoatProvider && !isCollegeProvider;
            if (snapshot.request.routeOrigin) {
                const DNT::MenuFramework::Vec2 routeOrigin{
                    layout.left + snapshot.request.routeOrigin->normalizedX * layout.width,
                    layout.top + snapshot.request.routeOrigin->normalizedY * layout.height
                };
                if (showRouteLines) {
                    if (!snapshot.request.routeSegments.empty()) {
                        if (snapshot.request.overlayTexturePath.empty()) {
                            for (const auto& segment : snapshot.request.routeSegments) {
                                DrawRouteConnection(
                                    framework,
                                    drawList,
                                    {
                                        layout.left + segment.start.normalizedX * layout.width,
                                        layout.top + segment.start.normalizedY * layout.height
                                    },
                                    {
                                        layout.left + segment.end.normalizedX * layout.width,
                                        layout.top + segment.end.normalizedY * layout.height
                                    },
                                    false);
                            }
                        }
                        if (snapshot.request.overlayTexturePath.empty() &&
                            activeIndex && *activeIndex < snapshot.request.destinations.size()) {
                            const auto activePath = DNT::Parchment::FindRoutePath(
                                snapshot.request,
                                snapshot.request.destinations[*activeIndex]);
                            std::vector<DNT::MenuFramework::Vec2> activeScreenPath;
                            activeScreenPath.reserve(activePath.size());
                            for (const auto& point : activePath) {
                                activeScreenPath.push_back({
                                    layout.left + point.normalizedX * layout.width,
                                    layout.top + point.normalizedY * layout.height
                                });
                            }
                            DrawActiveRoutePath(framework, drawList, activeScreenPath);
                        }
                    } else {
                        for (const auto& visual : destinationVisuals) {
                            if (snapshot.request.overlayTexturePath.empty()) {
                                DrawRouteConnection(
                                    framework,
                                    drawList,
                                    routeOrigin,
                                    visual.center,
                                    visual.highlighted);
                            }
                        }
                    }
                }
                for (const auto& landmark : snapshot.request.routeLandmarks) {
                    DrawRouteLandmark(
                        framework,
                        drawList,
                        loadedIdleMarkerTexture,
                        {
                            layout.left + landmark.normalizedX * layout.width,
                            layout.top + landmark.normalizedY * layout.height
                        },
                        std::clamp(layout.markerHeight * 0.68F, 17.0F, 34.0F));
                }
                DrawRouteOrigin(
                    framework,
                    drawList,
                    loadedOriginMarkerTexture ?
                        loadedOriginMarkerTexture : loadedSelectedMarkerTexture,
                    routeOrigin,
                    std::clamp(layout.markerHeight * 0.68F, 17.0F, 34.0F));
            }
            for (std::size_t index = 0; index < destinationVisuals.size(); ++index) {
                const auto& visual = destinationVisuals[index];
                auto idleMarkerTexture = loadedIdleMarkerTexture;
                auto selectedMarkerTexture = loadedSelectedMarkerTexture;
                const auto& destinationTexturePath =
                    snapshot.request.destinations[index].idleMarkerTexturePath;
                if (!destinationTexturePath.empty()) {
                    const auto destinationTexture =
                        loadedDestinationMarkerTextures.find(destinationTexturePath);
                    if (destinationTexture != loadedDestinationMarkerTextures.end()) {
                        idleMarkerTexture = destinationTexture->second;
                        // A destination-specific icon identifies the place in
                        // both states. Selection styling must not replace a
                        // hold icon with the provider's hub icon.
                        selectedMarkerTexture = destinationTexture->second;
                    }
                }
                auto markerArtScale = 1.0F;
                if (isCarriageProvider) {
                    markerArtScale = destinationTexturePath.find("-capital.dds") !=
                            std::string::npos ?
                        1.25F : 0.84F;
                }
                DrawFerryDestinationMarker(
                    framework,
                    drawList,
                    idleMarkerTexture,
                    selectedMarkerTexture,
                    visual.center,
                    visual.radius,
                    visual.highlighted,
                    isCollegeProvider,
                    markerArtScale);
            }

            if (!focusedDescription.empty()) {
                constexpr std::int32_t textStyleIndex = 0;
                constexpr auto textShadow = MakeColor(20, 14, 10, 235);
                constexpr auto inventoryIvory = MakeColor(238, 229, 207, 255);
                constexpr auto wizardMapInk = MakeColor(69, 44, 13, 255);
                const auto textColor = isCollegeProvider ? wizardMapInk : inventoryIvory;
                const auto paymentLabelPosition = snapshot.request.paymentLabelPosition.value_or(
                    DNT::Parchment::RoutePoint{ .normalizedX = 0.080F, .normalizedY = 0.760F });
                framework.SetWindowFontScale(1.08F);
                const auto textSize = framework.CalcTextSize(focusedDescription);
                constexpr float edgePadding = 12.0F;
                const auto minimumTextX = layout.left + edgePadding;
                const auto maximumTextX = std::max(
                    minimumTextX,
                    layout.left + layout.width - textSize.x - edgePadding);
                const auto centeredTextX =
                    layout.left + layout.width * paymentLabelPosition.normalizedX - textSize.x * 0.5F;
                const DNT::MenuFramework::Vec2 textPosition{
                    std::clamp(centeredTextX, minimumTextX, maximumTextX),
                    layout.top + layout.height * paymentLabelPosition.normalizedY
                };
                if (!isCollegeProvider) {
                    framework.SetCursorScreenPos({ textPosition.x + 2.0F, textPosition.y + 2.0F });
                    framework.PushStyleColor(textStyleIndex, textShadow);
                    framework.TextUnformatted(focusedDescription);
                    framework.PopStyleColor();
                }
                framework.SetCursorScreenPos(textPosition);
                framework.PushStyleColor(textStyleIndex, textColor);
                framework.TextUnformatted(focusedDescription);
                framework.PopStyleColor();
                framework.SetWindowFontScale(1.0F);
            }
        }
        framework.End();
        DrawParchmentCursor(framework, viewportHeight);

        if (selectedIndex) {
            FinishRequest(*selectedIndex, "selected");
        }
    }
}

bool DNT::ParchmentMenu::Initialize()
{
    if (pickerWindow) {
        return true;
    }

    auto& framework = MenuFramework::API::GetSingleton();
    if (!framework.Resolve()) {
        logger::warn("PARCHMENT_FRAMEWORK_UNAVAILABLE required=SKSEMenuFramework");
        return false;
    }

    pickerWindow = framework.AddWindow(RenderPicker);
    if (!pickerWindow) {
        logger::error("PARCHMENT_INIT_FAILED reason=add_window");
        return false;
    }
    inputRegistration = framework.AddInputEvent(OnInput);
    logger::info(
        "PARCHMENT_INIT frameworkVersion={} inputRegistration={}",
        framework.Version(),
        inputRegistration);
    return true;
}

bool DNT::ParchmentMenu::IsAvailable()
{
    return pickerWindow && MenuFramework::API::GetSingleton().IsReady();
}

bool DNT::ParchmentMenu::BeginRequest(
    const std::string_view a_requestId,
    const std::string_view a_providerId,
    RE::TESObjectREFR* a_source,
    const std::string_view a_texturePath,
    const float a_artAspectRatio,
    const float a_textureUvMinX,
    const float a_textureUvMinY,
    const float a_textureUvMaxX,
    const float a_textureUvMaxY)
{
    if (!IsAvailable() || !a_source) {
        return false;
    }

    ActiveRequest candidate{
        .request = {
            .requestId = std::string(a_requestId),
            .providerId = std::string(a_providerId),
            .texturePath = std::string(a_texturePath),
            .artAspectRatio = a_artAspectRatio,
            .textureUvMinX = a_textureUvMinX,
            .textureUvMinY = a_textureUvMinY,
            .textureUvMaxX = a_textureUvMaxX,
            .textureUvMaxY = a_textureUvMaxY,
            .destinations = {}
        },
        .sourceFormId = a_source->GetFormID(),
        .visible = false
    };
    std::string error;
    if (!Parchment::ValidateRequestHeader(candidate.request, error)) {
        logger::warn("PARCHMENT_BEGIN_REJECT request={} reason={}", a_requestId, error);
        return false;
    }

    std::scoped_lock lock(requestLock);
    if (activeRequest) {
        logger::warn("PARCHMENT_BEGIN_REJECT request={} reason=already_active", a_requestId);
        return false;
    }
    activeRequest = std::move(candidate);
    navigationFocusEngaged.store(false, std::memory_order_relaxed);
    logger::info(
        "PARCHMENT_BEGIN request={} provider={} source={:08X} uv=({:.3f},{:.3f})-({:.3f},{:.3f})",
        a_requestId,
        a_providerId,
        a_source->GetFormID(),
        a_textureUvMinX,
        a_textureUvMinY,
        a_textureUvMaxX,
        a_textureUvMaxY);
    return true;
}

bool DNT::ParchmentMenu::SetOverlayTexture(
    const std::string_view a_requestId,
    const std::string_view a_texturePath)
{
    std::scoped_lock lock(requestLock);
    if (!activeRequest || activeRequest->request.requestId != a_requestId || activeRequest->visible) {
        return false;
    }

    std::string error;
    const auto added = Parchment::SetOverlayTexture(
        activeRequest->request,
        std::string(a_texturePath),
        error);
    if (!added) {
        logger::warn(
            "PARCHMENT_OVERLAY_REJECT request={} path={} reason={}",
            a_requestId,
            a_texturePath,
            error);
    } else {
        logger::info(
            "PARCHMENT_OVERLAY_SET request={} path={}",
            a_requestId,
            a_texturePath);
    }
    return added;
}

bool DNT::ParchmentMenu::SetMarkerTextures(
    const std::string_view a_requestId,
    const std::string_view a_idleTexturePath,
    const std::string_view a_selectedTexturePath)
{
    std::scoped_lock lock(requestLock);
    if (!activeRequest || activeRequest->request.requestId != a_requestId || activeRequest->visible) {
        return false;
    }

    std::string error;
    const auto added = Parchment::SetMarkerTextures(
        activeRequest->request,
        std::string(a_idleTexturePath),
        std::string(a_selectedTexturePath),
        error);
    if (!added) {
        logger::warn(
            "PARCHMENT_MARKERS_REJECT request={} idle={} selected={} reason={}",
            a_requestId,
            a_idleTexturePath,
            a_selectedTexturePath,
            error);
    } else {
        logger::info(
            "PARCHMENT_MARKERS_SET request={} idle={} selected={}",
            a_requestId,
            a_idleTexturePath,
            a_selectedTexturePath);
    }
    return added;
}

bool DNT::ParchmentMenu::SetOriginMarkerTexture(
    const std::string_view a_requestId,
    const std::string_view a_texturePath)
{
    std::scoped_lock lock(requestLock);
    if (!activeRequest || activeRequest->request.requestId != a_requestId || activeRequest->visible) {
        return false;
    }

    std::string error;
    const auto added = Parchment::SetOriginMarkerTexture(
        activeRequest->request,
        std::string(a_texturePath),
        error);
    if (!added) {
        logger::warn(
            "PARCHMENT_ORIGIN_MARKER_REJECT request={} path={} reason={}",
            a_requestId,
            a_texturePath,
            error);
    } else {
        logger::info(
            "PARCHMENT_ORIGIN_MARKER_SET request={} path={}",
            a_requestId,
            a_texturePath);
    }
    return added;
}

bool DNT::ParchmentMenu::SetSourceLabel(
    const std::string_view a_requestId,
    const std::string_view a_sourceLabel)
{
    std::scoped_lock lock(requestLock);
    if (!activeRequest || activeRequest->request.requestId != a_requestId || activeRequest->visible) {
        return false;
    }

    std::string error;
    const auto added = Parchment::SetSourceLabel(
        activeRequest->request,
        std::string(a_sourceLabel),
        error);
    if (!added) {
        logger::warn(
            "PARCHMENT_SOURCE_LABEL_REJECT request={} label=\"{}\" reason={}",
            a_requestId,
            a_sourceLabel,
            error);
    } else {
        logger::info(
            "PARCHMENT_SOURCE_LABEL_SET request={} label=\"{}\"",
            a_requestId,
            activeRequest->request.sourceLabel);
    }
    return added;
}

bool DNT::ParchmentMenu::AddDestination(
    const std::string_view a_requestId,
    const std::string_view a_destinationId,
    const std::string_view a_label,
    const std::int32_t a_fare,
    const float a_normalizedX,
    const float a_normalizedY)
{
    std::scoped_lock lock(requestLock);
    if (!activeRequest || activeRequest->request.requestId != a_requestId || activeRequest->visible) {
        return false;
    }

    std::string error;
    const auto added = Parchment::AddDestination(
        activeRequest->request,
        Parchment::Destination{
            .id = std::string(a_destinationId),
            .label = std::string(a_label),
            .fare = a_fare,
            .normalizedX = a_normalizedX,
            .normalizedY = a_normalizedY
        },
        error);
    if (!added) {
        logger::warn(
            "PARCHMENT_DESTINATION_REJECT request={} destination={} reason={}",
            a_requestId,
            a_destinationId,
            error);
    }
    return added;
}

bool DNT::ParchmentMenu::SetDestinationMarkerTexture(
    const std::string_view a_requestId,
    const std::string_view a_destinationId,
    const std::string_view a_texturePath)
{
    std::scoped_lock lock(requestLock);
    if (!activeRequest || activeRequest->request.requestId != a_requestId || activeRequest->visible) {
        return false;
    }

    std::string error;
    const auto added = Parchment::SetDestinationMarkerTexture(
        activeRequest->request,
        a_destinationId,
        std::string(a_texturePath),
        error);
    if (!added) {
        logger::warn(
            "PARCHMENT_DESTINATION_MARKER_REJECT request={} destination={} path={} reason={}",
            a_requestId,
            a_destinationId,
            a_texturePath,
            error);
    } else {
        logger::info(
            "PARCHMENT_DESTINATION_MARKER_SET request={} destination={} path={}",
            a_requestId,
            a_destinationId,
            a_texturePath);
    }
    return added;
}

bool DNT::ParchmentMenu::SetRouteOrigin(
    const std::string_view a_requestId,
    const float a_normalizedX,
    const float a_normalizedY)
{
    std::scoped_lock lock(requestLock);
    if (!activeRequest || activeRequest->request.requestId != a_requestId || activeRequest->visible) {
        return false;
    }

    std::string error;
    const auto added = Parchment::SetRouteOrigin(
        activeRequest->request,
        Parchment::RouteOrigin{
            .normalizedX = a_normalizedX,
            .normalizedY = a_normalizedY
        },
        error);
    if (!added) {
        logger::warn(
            "PARCHMENT_ROUTE_ORIGIN_REJECT request={} reason={}",
            a_requestId,
            error);
    } else {
        logger::info(
            "PARCHMENT_ROUTE_ORIGIN request={} point=({:.3f},{:.3f})",
            a_requestId,
            a_normalizedX,
            a_normalizedY);
    }
    return added;
}

bool DNT::ParchmentMenu::SetPaymentLabelPosition(
    const std::string_view a_requestId,
    const float a_normalizedX,
    const float a_normalizedY)
{
    std::scoped_lock lock(requestLock);
    if (!activeRequest || activeRequest->request.requestId != a_requestId || activeRequest->visible) {
        return false;
    }

    std::string error;
    const auto added = Parchment::SetPaymentLabelPosition(
        activeRequest->request,
        Parchment::RoutePoint{
            .normalizedX = a_normalizedX,
            .normalizedY = a_normalizedY
        },
        error);
    if (!added) {
        logger::warn(
            "PARCHMENT_PAYMENT_LABEL_REJECT request={} reason={}",
            a_requestId,
            error);
    } else {
        logger::info(
            "PARCHMENT_PAYMENT_LABEL_POSITION request={} point=({:.3f},{:.3f})",
            a_requestId,
            a_normalizedX,
            a_normalizedY);
    }
    return added;
}

bool DNT::ParchmentMenu::AddRouteSegment(
    const std::string_view a_requestId,
    const float a_startNormalizedX,
    const float a_startNormalizedY,
    const float a_endNormalizedX,
    const float a_endNormalizedY)
{
    std::scoped_lock lock(requestLock);
    if (!activeRequest || activeRequest->request.requestId != a_requestId || activeRequest->visible) {
        return false;
    }

    std::string error;
    const auto added = Parchment::AddRouteSegment(
        activeRequest->request,
        Parchment::RouteSegment{
            .start = { a_startNormalizedX, a_startNormalizedY },
            .end = { a_endNormalizedX, a_endNormalizedY }
        },
        error);
    if (!added) {
        logger::warn(
            "PARCHMENT_ROUTE_SEGMENT_REJECT request={} start=({:.3f},{:.3f}) end=({:.3f},{:.3f}) reason={}",
            a_requestId,
            a_startNormalizedX,
            a_startNormalizedY,
            a_endNormalizedX,
            a_endNormalizedY,
            error);
    }
    return added;
}

bool DNT::ParchmentMenu::AddRouteLandmark(
    const std::string_view a_requestId,
    const float a_normalizedX,
    const float a_normalizedY)
{
    std::scoped_lock lock(requestLock);
    if (!activeRequest || activeRequest->request.requestId != a_requestId || activeRequest->visible) {
        return false;
    }

    std::string error;
    const auto added = Parchment::AddRouteLandmark(
        activeRequest->request,
        Parchment::RoutePoint{
            .normalizedX = a_normalizedX,
            .normalizedY = a_normalizedY
        },
        error);
    if (!added) {
        logger::warn(
            "PARCHMENT_ROUTE_LANDMARK_REJECT request={} point=({:.3f},{:.3f}) reason={}",
            a_requestId,
            a_normalizedX,
            a_normalizedY,
            error);
    }
    return added;
}

bool DNT::ParchmentMenu::Show(const std::string_view a_requestId)
{
    std::scoped_lock lock(requestLock);
    if (!activeRequest || activeRequest->request.requestId != a_requestId || activeRequest->visible) {
        return false;
    }

    std::string error;
    if (!Parchment::ValidateReadyRequest(activeRequest->request, error)) {
        logger::warn("PARCHMENT_SHOW_REJECT request={} reason={}", a_requestId, error);
        return false;
    }

    if (auto* ui = RE::UI::GetSingleton()) {
        for (const auto menuName : hudMenuNames) {
            auto movie = ui->GetMovieView(menuName);
            if (!movie) {
                continue;
            }

            HiddenHudLayer layer{
                .menuName = std::string(menuName),
                .movie = movie,
                .wasVisible = movie->GetVisible(),
                .rootAlpha = std::nullopt
            };
            RE::GFxValue alpha;
            if (movie->GetVariable(&alpha, "_root._alpha") && alpha.IsNumber()) {
                layer.rootAlpha = alpha.GetNumber();
                movie->SetVariable("_root._alpha", RE::GFxValue(0.0));
            }
            movie->SetVisible(false);
            logger::info(
                "PARCHMENT_HUD_LAYER_HIDDEN request={} menu=\"{}\" previousVisible={} previousAlpha={}",
                activeRequest->request.requestId,
                layer.menuName,
                layer.wasVisible,
                layer.rootAlpha ? std::format("{:.1f}", *layer.rootAlpha) : "<unavailable>");
            activeRequest->hiddenHudLayers.push_back(std::move(layer));
        }
    }
    logger::info(
        "PARCHMENT_HUD_HIDDEN request={} layers={}",
        activeRequest->request.requestId,
        activeRequest->hiddenHudLayers.size());
    activeRequest->visible = true;
    pickerWindow->isOpen = true;
    logger::info(
        "PARCHMENT_OPEN request={} provider={} destinations={} routeSegments={} routeLandmarks={} texture={} overlay={} idleMarker={} selectedMarker={} originMarker={}",
        activeRequest->request.requestId,
        activeRequest->request.providerId,
        activeRequest->request.destinations.size(),
        activeRequest->request.routeSegments.size(),
        activeRequest->request.routeLandmarks.size(),
        activeRequest->request.texturePath.empty() ? "<none>" : activeRequest->request.texturePath,
        activeRequest->request.overlayTexturePath.empty() ?
            "<none>" : activeRequest->request.overlayTexturePath,
        activeRequest->request.idleMarkerTexturePath.empty() ?
            defaultIdleMarkerTexturePath : activeRequest->request.idleMarkerTexturePath,
        activeRequest->request.selectedMarkerTexturePath.empty() ?
            defaultSelectedMarkerTexturePath : activeRequest->request.selectedMarkerTexturePath,
        activeRequest->request.originMarkerTexturePath.empty() ?
            (activeRequest->request.selectedMarkerTexturePath.empty() ?
                defaultSelectedMarkerTexturePath : activeRequest->request.selectedMarkerTexturePath) :
            activeRequest->request.originMarkerTexturePath);
    return true;
}

bool DNT::ParchmentMenu::Cancel(const std::string_view a_requestId)
{
    {
        std::scoped_lock lock(requestLock);
        if (!activeRequest || activeRequest->request.requestId != a_requestId) {
            return false;
        }
    }
    FinishRequest(-1, "papyrus_cancel");
    return true;
}
