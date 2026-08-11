#include "DNT/Papyrus.h"

#include "DNT/ParchmentCore.h"
#include "DNT/ParchmentMenu.h"
#include "DNT/TravelRuntime.h"

#include <algorithm>
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
    constexpr REL::Version ExpectedRuntime{ 1, 6, 1170, 0 };
    constexpr std::uint64_t LegacyCompileAndRunId = 21890;
    constexpr std::uint64_t ModernCompileAndRunId = 441582;
    constexpr std::uintptr_t ExpectedCompileAndRunOffset = 0x33D6A0;
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

    [[nodiscard]] bool IsOneWayCarriageDestination(const std::string_view a_destinationId)
    {
        return a_destinationId == "darkwater_crossing" ||
               a_destinationId == "mixwater_mill" ||
               a_destinationId == "halfmoon_mill" ||
               a_destinationId == "karthwasten" ||
               a_destinationId == "soljunds_sinkhole" ||
               a_destinationId == "shors_stone" ||
               a_destinationId == "heartwood_mill" ||
               a_destinationId == "stonehills";
    }

    [[nodiscard]] std::string_view GetCarriageSourceLabel(const std::string_view a_originId)
    {
        if (a_originId == "dawnstar") return "Dawnstar";
        if (a_originId == "falkreath") return "Falkreath";
        if (a_originId == "markarth") return "Markarth";
        if (a_originId == "morthal") return "Morthal";
        if (a_originId == "riften") return "Riften";
        if (a_originId == "solitude") return "Solitude";
        if (a_originId == "whiterun") return "Whiterun";
        if (a_originId == "windhelm") return "Windhelm";
        if (a_originId == "winterhold") return "Winterhold";
        return {};
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
        if (a_id == "darkwater_crossing" || a_id == "kynesgrove" || a_id == "karthwasten" || a_id == "shors_stone" || a_id == "stonehills") {
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
        const auto locations = DNT::TravelRuntime::GetLocations();
        const auto location = std::ranges::find_if(locations, [&](const auto& candidate) {
            return candidate.id == destinationId;
        });
        if (location == locations.end() || !IsCarriageLocationAvailable(*location)) {
            return std::nullopt;
        }
        return DNT::TravelRuntime::EstimateQuote(
            "carriage",
            originId,
            destinationId,
            DNT::Travel::QuoteOptions{ .freeRide = a_freeRide });
    }

    constexpr std::uint64_t SelectCompileAndRunId(const REL::Version& a_version)
    {
        return a_version.patch() < 1130 ? LegacyCompileAndRunId : ModernCompileAndRunId;
    }

    static_assert(SelectCompileAndRunId(REL::Version{ 1, 6, 640, 0 }) == LegacyCompileAndRunId);
    static_assert(SelectCompileAndRunId(ExpectedRuntime) == ModernCompileAndRunId);

    void CompileAndRunWithRuntimeRelocation(
        RE::Script* a_script,
        RE::TESObjectREFR* a_target,
        const std::uint64_t a_relocationId)
    {
        using func_t = void(
            RE::Script*,
            RE::ScriptCompiler*,
            RE::COMPILER_NAME,
            RE::TESObjectREFR*);

        RE::ScriptCompiler compiler;
        REL::Relocation<func_t> compileAndRun{ REL::ID(a_relocationId) };
        compileAndRun(
            a_script,
            &compiler,
            RE::COMPILER_NAME::kSystemWindowCompiler,
            a_target);
    }

    bool AddPresentationSubtitle(
        RE::Actor* a_speaker,
        const std::string_view a_subtitleText)
    {
        auto* const subtitleManager = RE::SubtitleManager::GetSingleton();
        if (!a_speaker || !subtitleManager) {
            return false;
        }

        RE::SubtitleInfo subtitle{};
        subtitle.speaker = a_speaker->GetHandle();
        subtitle.subtitle = a_subtitleText.data();
        subtitle.targetDistance = 0.0F;
        subtitle.forceDisplay = true;

        RE::BSSpinLockGuard lock(subtitleManager->lock);
        subtitleManager->subtitles.push_back(std::move(subtitle));
        return true;
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
        configured = DNT::ParchmentMenu::SetSourceLabel(requestId, GetCarriageSourceLabel(originId)) && configured;
        configured = DNT::ParchmentMenu::SetPaymentLabelPosition(requestId, 0.615551F, 0.922189F) && configured;
        configured = DNT::ParchmentMenu::SetMarkerTextures(
                         requestId,
                         "Data/textures/DiegeticTravel/norden-town.dds",
                         "Data/textures/DiegeticTravel/norden-town.dds") && configured;
        configured = DNT::ParchmentMenu::SetSelectionRingTexture(
                         requestId,
                         "Data/textures/DiegeticTravel/thin-circle-selection-ring.dds") && configured;

        std::vector<std::string> destinationIds;
        const auto locations = DNT::TravelRuntime::GetLocations();
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
            const auto label = std::format("{} ({:.1f} hours) ", location.name, quote->hours);
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
                    "Data/textures/DiegeticTravel/thin-circle-oneway-selection-ring.dds");
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

    float GetCarriageHours(
        RE::StaticFunctionTag*,
        const RE::BSFixedString a_originId,
        const RE::BSFixedString a_destinationId)
    {
        const auto quote = GetAvailableCarriageQuote(
            a_originId.c_str(),
            a_destinationId.c_str(),
            false);
        return quote ? quote->hours : -1.0F;
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

    bool SetDestinationMarkerTexture(
        RE::StaticFunctionTag*,
        const RE::BSFixedString a_requestId,
        const RE::BSFixedString a_destinationId,
        const RE::BSFixedString a_texturePath)
    {
        return DNT::ParchmentMenu::SetDestinationMarkerTexture(
            a_requestId.c_str(),
            a_destinationId.c_str(),
            a_texturePath.c_str());
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

    float QueuePresentation(
        RE::TESObjectREFR* a_speaker,
        DNT::Parchment::Presentation a_presentation)
    {
        const auto runtime = REL::Module::get().version();
        const auto speakerFormId = a_speaker ? a_speaker->GetFormID() : 0;
        std::string validationReason;
        if (!DNT::Parchment::ValidatePresentation(
                a_presentation,
                validationReason)) {
            logger::error(
                "PARCHMENT_PRESENTATION_REJECT speaker={:08X} reason={} path={}",
                speakerFormId,
                validationReason,
                a_presentation.voicePath);
            return 0.0F;
        }
        if (runtime != ExpectedRuntime) {
            logger::error(
                "PARCHMENT_PRESENTATION_REJECT runtime={} expected={} reason=unsupported_runtime",
                runtime,
                ExpectedRuntime);
            return 0.0F;
        }
        auto* speaker = a_speaker ? a_speaker->As<RE::Actor>() : nullptr;
        if (!speaker) {
            logger::error(
                "PARCHMENT_PRESENTATION_REJECT speaker={:08X} reason=invalid_speaker",
                speakerFormId);
            return 0.0F;
        }

        const auto relocationId = SelectCompileAndRunId(runtime);
        const auto resolvedAddress = REL::ID(relocationId).address();
        const auto resolvedOffset = resolvedAddress - REL::Module::get().base();
        if (relocationId != ModernCompileAndRunId ||
            resolvedOffset != ExpectedCompileAndRunOffset) {
            logger::critical(
                "PARCHMENT_PRESENTATION_REJECT runtime={} relocationId={} offset=0x{:X} expected=0x{:X} reason=relocation_mismatch",
                runtime,
                relocationId,
                resolvedOffset,
                ExpectedCompileAndRunOffset);
            return 0.0F;
        }

        const auto presentationWindow =
            DNT::Parchment::PresentationWindowSeconds(
                a_presentation.voiceDurationSeconds);
        const auto queuedVoicePath = a_presentation.voicePath;
        const auto speakerHandle = speaker->GetHandle();
        SKSE::GetTaskInterface()->AddTask(
            [speakerFormId,
             speakerHandle,
             presentation = std::move(a_presentation),
             relocationId,
             resolvedOffset]() {
                const auto speakerReference = speakerHandle.get();
                auto* speaker = speakerReference ? speakerReference->As<RE::Actor>() : nullptr;
                if (!speaker) {
                    logger::error(
                        "PARCHMENT_PRESENTATION_ABORT speaker={:08X} reason=actor_unavailable",
                        speakerFormId);
                    return;
                }

                auto* const scriptFactory =
                    RE::IFormFactory::GetConcreteFormFactoryByType<RE::Script>();
                auto* script = scriptFactory ? scriptFactory->Create() : nullptr;
                if (!script) {
                    logger::error(
                        "PARCHMENT_PRESENTATION_ABORT speaker={:08X} reason=script_factory_failed",
                        speakerFormId);
                    return;
                }

                speaker->PauseCurrentDialogue();
                script->SetCommand(
                    std::format("SpeakSound \"{}\"", presentation.voicePath));
                CompileAndRunWithRuntimeRelocation(script, speaker, relocationId);
                delete script;
                const bool subtitleAdded = AddPresentationSubtitle(
                    speaker,
                    presentation.subtitle);
                if (!subtitleAdded) {
                    logger::error(
                        "PARCHMENT_PRESENTATION_SUBTITLE speaker={:08X} added=0 reason=subtitle_manager_unavailable",
                        speakerFormId);
                }
                logger::info(
                    "PARCHMENT_PRESENTATION_DISPATCH speaker={:08X} relocationId={} offset=0x{:X} subtitleAdded={} durationSeconds={} path={}",
                    speakerFormId,
                    relocationId,
                    resolvedOffset,
                    subtitleAdded,
                    presentation.voiceDurationSeconds,
                    presentation.voicePath);
            });

        logger::info(
            "PARCHMENT_PRESENTATION_QUEUED speaker={:08X} runtime={} relocationId={} offset=0x{:X} presentationSeconds={} path={}",
            speakerFormId,
            runtime,
            relocationId,
            resolvedOffset,
            presentationWindow,
            queuedVoicePath);
        return presentationWindow;
    }

    float PlayPresentation(
        RE::StaticFunctionTag*,
        RE::TESObjectREFR* a_speaker,
        const RE::BSFixedString a_voicePath,
        const RE::BSFixedString a_subtitleText,
        const float a_voiceDurationSeconds)
    {
        return QueuePresentation(
            a_speaker,
            DNT::Parchment::Presentation{
                a_voicePath.c_str(),
                a_subtitleText.c_str(),
                a_voiceDurationSeconds });
    }

}

bool DNT::Papyrus::Register(RE::BSScript::IVirtualMachine* a_vm)
{
    a_vm->RegisterFunction("IsAvailable", PapyrusClass, IsAvailable);
    a_vm->RegisterFunction("GetMonotonicSeconds", PapyrusClass, GetMonotonicSeconds);
    a_vm->RegisterFunction("BuildCarriageRequest", PapyrusClass, BuildCarriageRequest);
    a_vm->RegisterFunction("ConsumeCarriageSelectionId", PapyrusClass, ConsumeCarriageSelectionId);
    a_vm->RegisterFunction("GetCarriageFare", PapyrusClass, GetCarriageFare);
    a_vm->RegisterFunction("GetCarriageHours", PapyrusClass, GetCarriageHours);
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
    a_vm->RegisterFunction("SetDestinationMarkerTexture", PapyrusClass, SetDestinationMarkerTexture);
    a_vm->RegisterFunction("SetDestinationSelectionRingTexture", PapyrusClass, SetDestinationSelectionRingTexture);
    a_vm->RegisterFunction("SetDestinationMarkerScale", PapyrusClass, SetDestinationMarkerScale);
    a_vm->RegisterFunction("SetDestinationSelectionRingStyle", PapyrusClass, SetDestinationSelectionRingStyle);
    a_vm->RegisterFunction("Show", PapyrusClass, Show);
    a_vm->RegisterFunction("Cancel", PapyrusClass, Cancel);
    a_vm->RegisterFunction("PlayPresentation", PapyrusClass, PlayPresentation);
    return true;
}
