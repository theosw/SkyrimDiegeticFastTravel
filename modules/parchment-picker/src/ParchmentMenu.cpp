#include "DNT/ParchmentMenu.h"

#include "DNT/MenuFrameworkAPI.h"

#include <RE/R/Renderer.h>

#include <array>
#include <atomic>

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

    void DrawDestinationHighlight(
        DNT::MenuFramework::API& a_framework,
        const DNT::MenuFramework::DrawList a_drawList,
        const DNT::MenuFramework::Vec2 a_center,
        const float a_radius,
        const bool a_highlighted)
    {
        if (!a_drawList) {
            return;
        }

        constexpr auto gold = MakeColor(224, 184, 100, 245);
        constexpr auto goldFill = MakeColor(190, 139, 49, 58);
        constexpr auto activeRed = MakeColor(205, 54, 42, 255);
        constexpr auto activeFill = MakeColor(142, 30, 22, 108);
        constexpr auto softRed = MakeColor(232, 91, 65, 205);
        const auto ringColor = a_highlighted ? activeRed : gold;
        const auto fillColor = a_highlighted ? activeFill : goldFill;
        const auto thickness = a_highlighted ? 4.0F : 2.5F;

        a_framework.AddCircleFilled(a_drawList, a_center, a_radius, fillColor, 32);
        a_framework.AddCircle(a_drawList, a_center, a_radius, ringColor, 32, thickness);
        if (a_highlighted) {
            a_framework.AddCircle(a_drawList, a_center, a_radius + 6.0F, softRed, 32, 2.0F);
        }
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
        constexpr auto activeRed = MakeColor(205, 54, 42, 255);
        if (a_highlighted) {
            a_framework.AddLine(a_drawList, a_origin, a_destination, darkInk, 6.0F);
            a_framework.AddLine(a_drawList, a_origin, a_destination, activeRed, 3.25F);
        } else {
            a_framework.AddLine(a_drawList, a_origin, a_destination, darkInk, 4.0F);
            a_framework.AddLine(a_drawList, a_origin, a_destination, gold, 2.0F);
        }
    }

    void DrawRouteOrigin(
        DNT::MenuFramework::API& a_framework,
        const DNT::MenuFramework::DrawList a_drawList,
        const DNT::MenuFramework::Vec2 a_center,
        const float a_radius)
    {
        if (!a_drawList) {
            return;
        }

        constexpr auto ink = MakeColor(43, 28, 16, 225);
        constexpr auto fill = MakeColor(190, 139, 49, 72);
        constexpr auto softGold = MakeColor(224, 184, 100, 235);
        a_framework.AddCircleFilled(a_drawList, a_center, a_radius, fill, 32);
        a_framework.AddCircle(a_drawList, a_center, a_radius, ink, 32, 2.0F);
        a_framework.AddCircle(a_drawList, a_center, a_radius + 5.0F, softGold, 32, 1.5F);
        a_framework.AddCircleFilled(a_drawList, a_center, 3.0F, ink, 16);
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
    std::string loadedRequestId;
    bool textureLoadAttempted{ false };

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
                loadedRequestId = snapshot.request.requestId;
                textureLoadAttempted = false;
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

            std::string focusedDescription;
            const auto drawList = framework.GetForegroundDrawList();
            std::vector<DestinationVisual> destinationVisuals;
            destinationVisuals.reserve(snapshot.request.destinations.size());
            std::optional<std::size_t> hoveredIndex;
            std::optional<std::size_t> focusedIndex;
            for (std::size_t index = 0; index < snapshot.request.destinations.size(); ++index) {
                const auto& destination = snapshot.request.destinations[index];
                const auto centerX = layout.left + destination.normalizedX * layout.width;
                const auto centerY = layout.top + destination.normalizedY * layout.height;
                const auto hitSize = std::max(layout.markerHeight * 1.65F, 56.0F);
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
                    .radius = hitSize * 0.46F,
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
                    "{} - {} gold",
                    activeDestination.label,
                    activeDestination.fare);
            }

            if (snapshot.request.routeOrigin) {
                const DNT::MenuFramework::Vec2 routeOrigin{
                    layout.left + snapshot.request.routeOrigin->normalizedX * layout.width,
                    layout.top + snapshot.request.routeOrigin->normalizedY * layout.height
                };
                for (const auto& visual : destinationVisuals) {
                    DrawRouteConnection(
                        framework,
                        drawList,
                        routeOrigin,
                        visual.center,
                        visual.highlighted);
                }
                DrawRouteOrigin(
                    framework,
                    drawList,
                    routeOrigin,
                    std::max(layout.markerHeight * 0.38F, 14.0F));
            }
            for (const auto& visual : destinationVisuals) {
                DrawDestinationHighlight(
                    framework,
                    drawList,
                    visual.center,
                    visual.radius,
                    visual.highlighted);
            }

            framework.SetCursorScreenPos({
                layout.left + layout.width - layout.markerWidth,
                layout.top + layout.height - layout.markerHeight - 12.0F
            });
            if (framework.Button("Close map##DNT-cancel", { layout.markerWidth, layout.markerHeight })) {
                selectedIndex = -1;
            }

            if (!focusedDescription.empty()) {
                framework.SetCursorScreenPos({ layout.left + 24.0F, layout.top + layout.height - 38.0F });
                framework.TextUnformatted(focusedDescription);
            }
        }
        framework.End();
        DrawParchmentCursor(framework, viewportHeight);

        if (selectedIndex) {
            FinishRequest(*selectedIndex, *selectedIndex < 0 ? "cancel_button" : "selected");
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
        "PARCHMENT_OPEN request={} provider={} destinations={} texture={}",
        activeRequest->request.requestId,
        activeRequest->request.providerId,
        activeRequest->request.destinations.size(),
        activeRequest->request.texturePath.empty() ? "<none>" : activeRequest->request.texturePath);
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
