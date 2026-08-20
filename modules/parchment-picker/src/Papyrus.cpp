#include "DNT/Papyrus.h"

#include "DNT/ParchmentCore.h"
#include "DNT/ParchmentMenu.h"
#include "DNT/TravelRuntime.h"

#include <algorithm>
#include <array>
#include <chrono>
#include <cctype>
#include <format>
#include <mutex>
#include <string>
#include <string_view>
#include <unordered_map>
#include <vector>

namespace
{
    constexpr std::string_view PapyrusClass = "DNT_ParchmentNative";
    std::mutex carriageRequestLock;
    std::unordered_map<std::string, std::vector<std::string>> carriageRequestDestinations;

    [[nodiscard]] std::string NormalizeTravelId(const std::string_view a_id)
    {
        std::string normalized(a_id);
        std::ranges::transform(normalized, normalized.begin(), [](const unsigned char a_character) {
            return static_cast<char>(std::tolower(a_character));
        });
        return normalized;
    }

    struct CarriageMarkerStyle
    {
        std::string_view texture;
        float markerScale{ 0.80F };
        float ringOffsetX{ 0.0211F };
        float ringOffsetY{ 0.1529F };
        float ringScale{ 1.0F };
    };

    struct WizardDestination
    {
        std::string_view id;
        std::string_view name;
        float normalizedX;
        float normalizedY;
        std::string_view texture;
        float markerScale;
        float ringOffsetX;
        float ringOffsetY;
        float ringScale;
    };

    constexpr std::array<WizardDestination, 7> WizardDestinations{
        WizardDestination{ "whiterun", "Whiterun", 0.532756F, 0.548290F, "Data/textures/DiegeticTravel/norden-whiterun-capital.dds", 1.00F, 0.0316F, -0.0474F, 0.88F },
        WizardDestination{ "riften", "Riften", 0.880078F, 0.833512F, "Data/textures/DiegeticTravel/norden-riften-capital.dds", 0.99F, 0.0F, -0.0580F, 0.88F },
        WizardDestination{ "solitude", "Solitude", 0.365471F, 0.191247F, "Data/textures/DiegeticTravel/norden-solitude-capital.dds", 1.00F, 0.0F, -0.0474F, 0.85F },
        WizardDestination{ "windhelm", "Windhelm", 0.793249F, 0.410699F, "Data/textures/DiegeticTravel/norden-windhelm-capital.dds", 0.93F, 0.0316F, -0.1001F, 0.89F },
        WizardDestination{ "markarth", "Markarth", 0.094238F, 0.507741F, "Data/textures/DiegeticTravel/norden-markarth-capital.dds", 0.95F, 0.0F, -0.1107F, 0.89F },
        WizardDestination{ "dawnstar", "Dawnstar", 0.557529F, 0.185081F, "Data/textures/DiegeticTravel/norden-dawnstar-capital.dds", 1.01F, 0.0F, -0.0474F, 0.86F },
        WizardDestination{ "morthal", "Morthal", 0.400452F, 0.311110F, "Data/textures/DiegeticTravel/norden-morthal-capital.dds", 0.95F, 0.0F, -0.0896F, 0.92F }
    };

    [[nodiscard]] DNT::Parchment::ArtworkProfile FormalMapFallbackArtwork()
    {
        // The preferred Caro chart and Bethesda battle map use different
        // crops. This affine transform is the composition of the checked-in
        // formal-map world fit and the 15-anchor physical-map world fit.
        // It applies uniformly to destinations, origins, and payment labels.
        return DNT::Parchment::ArtworkProfile{
            .texturePath = "Data/textures/dungeons/imperial/battlemap01.dds",
            .artAspectRatio = 1.35809F,
            .textureUvMinX = 0.0F,
            .textureUvMinY = 0.0F,
            .textureUvMaxX = 1.0F,
            .textureUvMaxY = 0.736328F,
            .coordinateTransform = {
                .xFromX = 1.06506646F,
                .xFromY = 0.03186359F,
                .xOffset = -0.04444646F,
                .yFromX = 0.02271570F,
                .yFromY = 1.03031003F,
                .yOffset = -0.05573539F
            }
        };
    }

    [[nodiscard]] CarriageMarkerStyle GetCarriageMarkerStyle(const std::string_view a_id)
    {
        if (a_id == "dawnstar") return { "Data/textures/DiegeticTravel/norden-dawnstar-capital.dds", 1.01F, 0.0F, -0.0474F, 0.86F };
        if (a_id == "falkreath") return { "Data/textures/DiegeticTravel/norden-falkreath-capital.dds", 0.96F, 0.0316F, -0.1107F, 0.89F };
        if (a_id == "markarth") return { "Data/textures/DiegeticTravel/norden-markarth-capital.dds", 0.95F, 0.0F, -0.1107F, 0.89F };
        if (a_id == "morthal") return { "Data/textures/DiegeticTravel/norden-morthal-capital.dds", 0.95F, 0.0F, -0.0896F, 0.92F };
        if (a_id == "riften") return { "Data/textures/DiegeticTravel/norden-riften-capital.dds", 0.99F, 0.0F, -0.0580F, 0.88F };
        if (a_id == "solitude") return { "Data/textures/DiegeticTravel/norden-solitude-capital.dds", 1.0F, 0.0F, -0.0474F, 0.85F };
        if (a_id == "whiterun") return { "Data/textures/DiegeticTravel/norden-whiterun-capital.dds", 1.0F, 0.0316F, -0.0474F, 0.88F };
        if (a_id == "windhelm") return { "Data/textures/DiegeticTravel/norden-windhelm-capital.dds", 0.93F, 0.0316F, -0.1001F, 0.89F };
        if (a_id == "winterhold") return { "Data/textures/DiegeticTravel/norden-winterhold-capital.dds", 0.96F, 0.0211F, -0.0580F, 0.89F };
        if (a_id == "mixwater_mill" || a_id == "halfmoon_mill" || a_id == "heartwood_mill") {
            return { "Data/textures/DiegeticTravel/norden-wood-mill.dds", 0.73F, -0.0105F, 0.0791F, 1.09F };
        }
        if (a_id == "soljunds_sinkhole") {
            return { "Data/textures/DiegeticTravel/norden-mine.dds", 0.78F, -0.0105F, 0.0791F, 1.02F };
        }
        if (a_id == "lakeview_manor" || a_id == "heljarchen_hall" || a_id == "winstad_manor") {
            return { "Data/textures/DiegeticTravel/norden-farm.dds", 0.78F, -0.0422F, -0.0158F, 1.04F };
        }
        if (a_id == "darkwater_crossing" || a_id == "kynesgrove" || a_id == "karthwasten" || a_id == "shors_stone" || a_id == "stonehills" || a_id == "thalmor_embassy") {
            return { "Data/textures/DiegeticTravel/norden-settlement.dds", 0.80F, 0.0105F, 0.1107F, 1.0F };
        }
        return { "Data/textures/DiegeticTravel/norden-town.dds", 0.80F, 0.0211F, 0.1529F, 1.0F };
    }

    [[nodiscard]] RE::TESObjectREFR* ResolveArrivalMarker(const DNT::Travel::Location& a_location)
    {
        auto* const dataHandler = RE::TESDataHandler::GetSingleton();
        if (!dataHandler || a_location.arrivalMarker.plugin.empty()) {
            return nullptr;
        }
        return dataHandler->LookupForm<RE::TESObjectREFR>(
            a_location.arrivalMarker.localFormId,
            a_location.arrivalMarker.plugin);
    }

    [[nodiscard]] bool IsCarriageLocationAvailable(const DNT::Travel::Location& a_location)
    {
        auto* const marker = ResolveArrivalMarker(a_location);
        if (!marker) {
            return false;
        }
        return a_location.availability != DNT::Travel::Availability::kQuestLocked || !marker->IsDisabled();
    }

    [[nodiscard]] std::optional<DNT::Travel::Quote> GetAvailableCarriageQuote(
        const std::string_view a_originId,
        const std::string_view a_destinationId,
        const bool a_freeRide)
    {
        const auto originId = NormalizeTravelId(a_originId);
        const auto destinationId = NormalizeTravelId(a_destinationId);
        const auto location = DNT::TravelRuntime::GetLocation(destinationId);
        if (!location || !IsCarriageLocationAvailable(*location)) {
            return std::nullopt;
        }
        return DNT::TravelRuntime::EstimateQuote(
            "carriage",
            originId,
            destinationId,
            DNT::Travel::QuoteOptions{ .freeRide = a_freeRide });
    }

    bool IsAvailable(RE::StaticFunctionTag*)
    {
        return DNT::ParchmentMenu::IsAvailable();
    }

    float GetMonotonicSeconds(RE::StaticFunctionTag*)
    {
        static const auto processEpoch = std::chrono::steady_clock::now();
        return std::chrono::duration<float>(
            std::chrono::steady_clock::now() - processEpoch).count();
    }

    std::int32_t BuildCarriageRequest(
        RE::StaticFunctionTag*,
        const RE::BSFixedString a_requestId,
        const RE::BSFixedString a_originId,
        RE::TESObjectREFR* a_source,
        const bool a_freeRide)
    {
        const auto startedAt = std::chrono::steady_clock::now();
        const std::string requestId = a_requestId.c_str();
        const auto originId = NormalizeTravelId(a_originId.c_str());
        if (requestId.empty() || originId.empty() || !a_source ||
            !DNT::ParchmentMenu::IsAvailable() ||
            !DNT::TravelRuntime::IsCatalogReady()) {
            logger::warn(
                "CARRIAGE_NATIVE_REQUEST_REJECT request={} origin={} source={} menu_ready={} catalog_ready={}",
                requestId,
                originId,
                a_source ? a_source->GetFormID() : 0,
                DNT::ParchmentMenu::IsAvailable(),
                DNT::TravelRuntime::IsCatalogReady());
            return -1;
        }

        const auto locations = DNT::TravelRuntime::GetLocations();
        const auto originLocation = std::ranges::find_if(locations, [&](const auto& location) {
            return location.id == originId;
        });
        if (originLocation == locations.end()) {
            logger::warn(
                "CARRIAGE_NATIVE_REQUEST_REJECT request={} origin={} reason=origin_missing",
                requestId,
                originId);
            return -1;
        }

        if (!DNT::ParchmentMenu::BeginRequest(
                requestId,
                "carriage",
                a_source,
                "Data/textures/terrain/tamriel/skyrim.dds",
                1.414075F,
                0.088379F,
                0.187012F,
                0.932129F,
                0.783691F)) {
            logger::warn("CARRIAGE_NATIVE_REQUEST_REJECT request={} origin={} reason=begin_failed", requestId, originId);
            return -1;
        }

        bool configured = true;
        configured = DNT::ParchmentMenu::SetFallbackArtwork(
                         requestId,
                         FormalMapFallbackArtwork()) && configured;
        configured = DNT::ParchmentMenu::SetSourceLabel(requestId, originLocation->name) && configured;
        configured = DNT::ParchmentMenu::SetPaymentLabelPosition(requestId, 0.615551F, 0.922189F) && configured;
        configured = DNT::ParchmentMenu::SetMarkerTextures(
                         requestId,
                         "Data/textures/DiegeticTravel/norden-town.dds",
                         "Data/textures/DiegeticTravel/norden-town.dds") && configured;
        configured = DNT::ParchmentMenu::SetSelectionRingTexture(
                         requestId,
                         "Data/textures/DiegeticTravel/norden-roundtrip-selection-ring.dds") && configured;

        const auto pricing = DNT::TravelRuntime::GetPricingSettings();
        std::vector<std::string> destinationIds;
        destinationIds.reserve(locations.size());
        for (const auto& location : locations) {
            if (location.id == originId || !IsCarriageLocationAvailable(location)) {
                continue;
            }
            const auto quote = DNT::TravelRuntime::EstimateQuote(
                "carriage",
                originId,
                location.id,
                DNT::Travel::QuoteOptions{ .freeRide = a_freeRide });
            if (!quote) {
                logger::warn(
                    "CARRIAGE_NATIVE_DESTINATION_SKIPPED request={} origin={} destination={} reason=quote_missing",
                    requestId,
                    originId,
                    location.id);
                continue;
            }

            const auto style = GetCarriageMarkerStyle(location.id);
            auto label = location.name + " ";
            if (pricing.showEstimatedHours) {
                label = pricing.markHoursAsApproximate ?
                    std::format("{} (~{:.1f} hours) ", location.name, quote->hours) :
                    std::format("{} ({:.1f} hours) ", location.name, quote->hours);
            }
            bool added = DNT::ParchmentMenu::AddStyledDestination(
                requestId,
                location.id,
                label,
                quote->fare,
                location.normalizedX,
                location.normalizedY,
                style.texture,
                style.markerScale,
                style.ringOffsetX,
                style.ringOffsetY,
                style.ringScale);
            if (added && location.availability == DNT::Travel::Availability::kOneWay) {
                added = DNT::ParchmentMenu::SetDestinationSelectionRingTexture(
                    requestId,
                    location.id,
                    "Data/textures/DiegeticTravel/norden-oneway-selection-ring.dds");
            }
            configured = added && configured;
            if (added) {
                destinationIds.push_back(location.id);
            }
        }

        if (!configured || destinationIds.empty()) {
            const bool cancelled = DNT::ParchmentMenu::Cancel(requestId);
            logger::warn(
                "CARRIAGE_NATIVE_REQUEST_REJECT request={} origin={} reason=destination_setup configured={} destinations={} cancelled={}",
                requestId,
                originId,
                configured,
                destinationIds.size(),
                cancelled);
            return -1;
        }

        const auto destinationCount = static_cast<std::int32_t>(destinationIds.size());
        {
            std::scoped_lock lock(carriageRequestLock);
            carriageRequestDestinations.insert_or_assign(requestId, std::move(destinationIds));
        }
        const auto buildMs = std::chrono::duration<double, std::milli>(
            std::chrono::steady_clock::now() - startedAt).count();
        logger::info(
            "CARRIAGE_NATIVE_REQUEST_READY request={} origin={} destinations={} free={} build_ms={:.3f}",
            requestId,
            originId,
            destinationCount,
            a_freeRide,
            buildMs);
        return destinationCount;
    }

    std::int32_t BuildWizardRequest(
        RE::StaticFunctionTag*,
        const RE::BSFixedString a_requestId,
        RE::TESObjectREFR* a_source,
        const std::int32_t a_fare)
    {
        const auto startedAt = std::chrono::steady_clock::now();
        const std::string requestId = a_requestId.c_str();
        if (requestId.empty() || !a_source || a_fare < 0 ||
            !DNT::ParchmentMenu::IsAvailable()) {
            logger::warn(
                "WIZARD_NATIVE_REQUEST_REJECT request={} source={} fare={} menu_ready={}",
                requestId,
                a_source ? a_source->GetFormID() : 0,
                a_fare,
                DNT::ParchmentMenu::IsAvailable());
            return -1;
        }

        if (!DNT::ParchmentMenu::BeginRequest(
                requestId,
                "college",
                a_source,
                "Data/textures/terrain/tamriel/skyrim.dds",
                1.414075F,
                0.088379F,
                0.187012F,
                0.932129F,
                0.783691F)) {
            logger::warn("WIZARD_NATIVE_REQUEST_REJECT request={} reason=begin_failed", requestId);
            return -1;
        }

        bool configured = true;
        configured = DNT::ParchmentMenu::SetFallbackArtwork(
                         requestId,
                         FormalMapFallbackArtwork()) && configured;
        configured = DNT::ParchmentMenu::SetSourceLabel(requestId, "College of Winterhold") && configured;
        configured = DNT::ParchmentMenu::SetPaymentLabelPosition(requestId, 0.616470F, 0.924230F) && configured;
        configured = DNT::ParchmentMenu::SetMarkerTextures(
                         requestId,
                         "Data/textures/DiegeticTravel/norden-town.dds",
                         "Data/textures/DiegeticTravel/norden-town.dds") && configured;
        configured = DNT::ParchmentMenu::SetOriginMarkerTexture(
                         requestId,
                         "Data/textures/DiegeticTravel/norden-winterhold-capital.dds") && configured;
        configured = DNT::ParchmentMenu::SetSelectionRingTexture(
                         requestId,
                         "Data/textures/DiegeticTravel/norden-roundtrip-selection-ring.dds") && configured;
        configured = DNT::ParchmentMenu::SetRouteOrigin(requestId, 0.750802F, 0.167836F) && configured;

        std::int32_t destinationCount = 0;
        for (const auto& destination : WizardDestinations) {
            const auto label = std::format("{} ", destination.name);
            const bool added = DNT::ParchmentMenu::AddStyledDestination(
                requestId,
                destination.id,
                label,
                a_fare,
                destination.normalizedX,
                destination.normalizedY,
                destination.texture,
                destination.markerScale,
                destination.ringOffsetX,
                destination.ringOffsetY,
                destination.ringScale);
            configured = added && configured;
            if (added) {
                ++destinationCount;
            }
        }

        if (!configured || destinationCount != static_cast<std::int32_t>(WizardDestinations.size())) {
            const bool cancelled = DNT::ParchmentMenu::Cancel(requestId);
            logger::warn(
                "WIZARD_NATIVE_REQUEST_REJECT request={} reason=destination_setup configured={} destinations={} cancelled={}",
                requestId,
                configured,
                destinationCount,
                cancelled);
            return -1;
        }

        const auto buildMs = std::chrono::duration<double, std::milli>(
            std::chrono::steady_clock::now() - startedAt).count();
        logger::info(
            "WIZARD_NATIVE_REQUEST_READY request={} destinations={} fare={} build_ms={:.3f}",
            requestId,
            destinationCount,
            a_fare,
            buildMs);
        return destinationCount;
    }

    RE::BSFixedString ConsumeCarriageSelectionId(
        RE::StaticFunctionTag*,
        const RE::BSFixedString a_requestId,
        const std::int32_t a_selectionIndex)
    {
        std::string destinationId;
        {
            std::scoped_lock lock(carriageRequestLock);
            const auto request = carriageRequestDestinations.find(a_requestId.c_str());
            if (request != carriageRequestDestinations.end()) {
                if (a_selectionIndex >= 0 &&
                    static_cast<std::size_t>(a_selectionIndex) < request->second.size()) {
                    destinationId = request->second[static_cast<std::size_t>(a_selectionIndex)];
                }
                carriageRequestDestinations.erase(request);
            }
        }
        return RE::BSFixedString(destinationId.c_str());
    }

    std::int32_t GetCarriageFare(
        RE::StaticFunctionTag*,
        const RE::BSFixedString a_originId,
        const RE::BSFixedString a_destinationId,
        const bool a_freeRide)
    {
        const auto quote = GetAvailableCarriageQuote(
            a_originId.c_str(),
            a_destinationId.c_str(),
            a_freeRide);
        return quote ? quote->fare : -1;
    }

    RE::TESObjectREFR* ResolveCarriageDestinationMarker(
        RE::StaticFunctionTag*,
        const RE::BSFixedString a_destinationId)
    {
        const auto destinationId = NormalizeTravelId(a_destinationId.c_str());
        const auto location = DNT::TravelRuntime::GetLocation(destinationId);
        if (!location) {
            logger::warn(
                "CARRIAGE_NATIVE_MARKER_REJECT destination={} reason=unknown_destination",
                destinationId);
            return nullptr;
        }
        auto* const marker = ResolveArrivalMarker(*location);
        if (!marker) {
            logger::warn(
                "CARRIAGE_NATIVE_MARKER_REJECT destination={} reason=form_unresolved plugin={} local_form={:06X}",
                destinationId,
                location->arrivalMarker.plugin,
                location->arrivalMarker.localFormId);
            return nullptr;
        }
        if (location->availability == DNT::Travel::Availability::kQuestLocked && marker->IsDisabled()) {
            logger::warn(
                "CARRIAGE_NATIVE_MARKER_REJECT destination={} reason=quest_locked marker={:08X}",
                destinationId,
                marker->GetFormID());
            return nullptr;
        }
        logger::info(
            "CARRIAGE_NATIVE_MARKER_READY destination={} marker={:08X}",
            destinationId,
            marker->GetFormID());
        return marker;
    }

    std::int32_t GetWizardFare(
        RE::StaticFunctionTag*,
        const std::int32_t a_fallbackFare)
    {
        return DNT::TravelRuntime::GetWizardFare(a_fallbackFare);
    }

    std::int32_t ResolveFerryFare(
        RE::StaticFunctionTag*,
        const RE::BSFixedString a_tier,
        const std::int32_t a_liveCftoFare)
    {
        return DNT::TravelRuntime::ResolveFerryFare(a_tier.c_str(), a_liveCftoFare);
    }

    bool RequestDialogueClose(RE::StaticFunctionTag*)
    {
        auto* ui = RE::UI::GetSingleton();
        if (!ui) {
            logger::warn("PARCHMENT_DIALOGUE_CLOSE_REJECT reason=ui_unavailable");
            return false;
        }

        if (!ui->IsMenuOpen(RE::DialogueMenu::MENU_NAME)) {
            logger::info("PARCHMENT_DIALOGUE_CLOSE_SKIPPED reason=already_closed");
            return true;
        }

        auto* messageQueue = RE::UIMessageQueue::GetSingleton();
        if (!messageQueue) {
            logger::warn("PARCHMENT_DIALOGUE_CLOSE_REJECT reason=message_queue_unavailable");
            return false;
        }

        messageQueue->AddMessage(
            RE::DialogueMenu::MENU_NAME,
            RE::UI_MESSAGE_TYPE::kHide,
            nullptr);
        logger::info("PARCHMENT_DIALOGUE_CLOSE_REQUESTED");
        return true;
    }

    bool BeginRequest(
        RE::StaticFunctionTag*,
        const RE::BSFixedString a_requestId,
        const RE::BSFixedString a_providerId,
        RE::TESObjectREFR* a_source,
        const RE::BSFixedString a_texturePath,
        const float a_artAspectRatio,
        const float a_textureUvMinX,
        const float a_textureUvMinY,
        const float a_textureUvMaxX,
        const float a_textureUvMaxY)
    {
        return DNT::ParchmentMenu::BeginRequest(
            a_requestId.c_str(),
            a_providerId.c_str(),
            a_source,
            a_texturePath.c_str(),
            a_artAspectRatio,
            a_textureUvMinX,
            a_textureUvMinY,
            a_textureUvMaxX,
            a_textureUvMaxY);
    }

    bool AddDestination(
        RE::StaticFunctionTag*,
        const RE::BSFixedString a_requestId,
        const RE::BSFixedString a_destinationId,
        const RE::BSFixedString a_label,
        const std::int32_t a_fare,
        const float a_normalizedX,
        const float a_normalizedY)
    {
        return DNT::ParchmentMenu::AddDestination(
            a_requestId.c_str(),
            a_destinationId.c_str(),
            a_label.c_str(),
            a_fare,
            a_normalizedX,
            a_normalizedY);
    }

    bool SetDestinationSelectionRingTexture(
        RE::StaticFunctionTag*,
        const RE::BSFixedString a_requestId,
        const RE::BSFixedString a_destinationId,
        const RE::BSFixedString a_texturePath)
    {
        return DNT::ParchmentMenu::SetDestinationSelectionRingTexture(
            a_requestId.c_str(),
            a_destinationId.c_str(),
            a_texturePath.c_str());
    }

    bool SetDestinationSelectionRingStyle(
        RE::StaticFunctionTag*,
        const RE::BSFixedString a_requestId,
        const RE::BSFixedString a_destinationId,
        const float a_offsetX,
        const float a_offsetY,
        const float a_scale)
    {
        return DNT::ParchmentMenu::SetDestinationSelectionRingStyle(
            a_requestId.c_str(),
            a_destinationId.c_str(),
            a_offsetX,
            a_offsetY,
            a_scale);
    }

    bool SetDestinationMarkerScale(
        RE::StaticFunctionTag*,
        const RE::BSFixedString a_requestId,
        const RE::BSFixedString a_destinationId,
        const float a_scale)
    {
        return DNT::ParchmentMenu::SetDestinationMarkerScale(
            a_requestId.c_str(),
            a_destinationId.c_str(),
            a_scale);
    }

    bool SetSourceLabel(
        RE::StaticFunctionTag*,
        const RE::BSFixedString a_requestId,
        const RE::BSFixedString a_sourceLabel)
    {
        return DNT::ParchmentMenu::SetSourceLabel(
            a_requestId.c_str(),
            a_sourceLabel.c_str());
    }

    bool SetMarkerTextures(
        RE::StaticFunctionTag*,
        const RE::BSFixedString a_requestId,
        const RE::BSFixedString a_idleTexturePath,
        const RE::BSFixedString a_selectedTexturePath)
    {
        return DNT::ParchmentMenu::SetMarkerTextures(
            a_requestId.c_str(),
            a_idleTexturePath.c_str(),
            a_selectedTexturePath.c_str());
    }

    bool SetOriginMarkerTexture(
        RE::StaticFunctionTag*,
        const RE::BSFixedString a_requestId,
        const RE::BSFixedString a_texturePath)
    {
        return DNT::ParchmentMenu::SetOriginMarkerTexture(
            a_requestId.c_str(),
            a_texturePath.c_str());
    }

    bool SetSelectionRingTexture(
        RE::StaticFunctionTag*,
        const RE::BSFixedString a_requestId,
        const RE::BSFixedString a_texturePath)
    {
        return DNT::ParchmentMenu::SetSelectionRingTexture(
            a_requestId.c_str(),
            a_texturePath.c_str());
    }

    bool SetSelectionRingScale(
        RE::StaticFunctionTag*,
        const RE::BSFixedString a_requestId,
        const float a_scale)
    {
        return DNT::ParchmentMenu::SetSelectionRingScale(
            a_requestId.c_str(),
            a_scale);
    }

    bool SetRouteOrigin(
        RE::StaticFunctionTag*,
        const RE::BSFixedString a_requestId,
        const float a_normalizedX,
        const float a_normalizedY)
    {
        return DNT::ParchmentMenu::SetRouteOrigin(
            a_requestId.c_str(),
            a_normalizedX,
            a_normalizedY);
    }

    bool SetPaymentLabelPosition(
        RE::StaticFunctionTag*,
        const RE::BSFixedString a_requestId,
        const float a_normalizedX,
        const float a_normalizedY)
    {
        return DNT::ParchmentMenu::SetPaymentLabelPosition(
            a_requestId.c_str(),
            a_normalizedX,
            a_normalizedY);
    }

    bool AddRouteLandmark(
        RE::StaticFunctionTag*,
        const RE::BSFixedString a_requestId,
        const float a_normalizedX,
        const float a_normalizedY)
    {
        return DNT::ParchmentMenu::AddRouteLandmark(
            a_requestId.c_str(),
            a_normalizedX,
            a_normalizedY);
    }

    bool Show(RE::StaticFunctionTag*, const RE::BSFixedString a_requestId)
    {
        return DNT::ParchmentMenu::Show(a_requestId.c_str());
    }

    bool Cancel(RE::StaticFunctionTag*, const RE::BSFixedString a_requestId)
    {
        return DNT::ParchmentMenu::Cancel(a_requestId.c_str());
    }

}

bool DNT::Papyrus::Register(RE::BSScript::IVirtualMachine* a_vm)
{
    a_vm->RegisterFunction("IsAvailable", PapyrusClass, IsAvailable);
    a_vm->RegisterFunction("GetMonotonicSeconds", PapyrusClass, GetMonotonicSeconds);
    a_vm->RegisterFunction("BuildCarriageRequest", PapyrusClass, BuildCarriageRequest);
    a_vm->RegisterFunction("BuildWizardRequest", PapyrusClass, BuildWizardRequest);
    a_vm->RegisterFunction("ConsumeCarriageSelectionId", PapyrusClass, ConsumeCarriageSelectionId);
    a_vm->RegisterFunction("GetCarriageFare", PapyrusClass, GetCarriageFare);
    a_vm->RegisterFunction("ResolveCarriageDestinationMarker", PapyrusClass, ResolveCarriageDestinationMarker);
    a_vm->RegisterFunction("GetWizardFare", PapyrusClass, GetWizardFare);
    a_vm->RegisterFunction("ResolveFerryFare", PapyrusClass, ResolveFerryFare);
    a_vm->RegisterFunction("RequestDialogueClose", PapyrusClass, RequestDialogueClose);
    a_vm->RegisterFunction("BeginRequest", PapyrusClass, BeginRequest);
    a_vm->RegisterFunction("SetSourceLabel", PapyrusClass, SetSourceLabel);
    a_vm->RegisterFunction("SetMarkerTextures", PapyrusClass, SetMarkerTextures);
    a_vm->RegisterFunction("SetOriginMarkerTexture", PapyrusClass, SetOriginMarkerTexture);
    a_vm->RegisterFunction("SetSelectionRingTexture", PapyrusClass, SetSelectionRingTexture);
    a_vm->RegisterFunction("SetSelectionRingScale", PapyrusClass, SetSelectionRingScale);
    a_vm->RegisterFunction("SetPaymentLabelPosition", PapyrusClass, SetPaymentLabelPosition);
    a_vm->RegisterFunction("SetRouteOrigin", PapyrusClass, SetRouteOrigin);
    a_vm->RegisterFunction("AddRouteLandmark", PapyrusClass, AddRouteLandmark);
    a_vm->RegisterFunction("AddDestination", PapyrusClass, AddDestination);
    a_vm->RegisterFunction("SetDestinationSelectionRingTexture", PapyrusClass, SetDestinationSelectionRingTexture);
    a_vm->RegisterFunction("SetDestinationMarkerScale", PapyrusClass, SetDestinationMarkerScale);
    a_vm->RegisterFunction("SetDestinationSelectionRingStyle", PapyrusClass, SetDestinationSelectionRingStyle);
    a_vm->RegisterFunction("Show", PapyrusClass, Show);
    a_vm->RegisterFunction("Cancel", PapyrusClass, Cancel);
    return true;
}
