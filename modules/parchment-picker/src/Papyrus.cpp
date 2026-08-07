#include "DNT/Papyrus.h"

#include "DNT/ParchmentCore.h"
#include "DNT/ParchmentMenu.h"

namespace
{
    constexpr std::string_view PapyrusClass = "DNT_ParchmentNative";
    constexpr REL::Version ExpectedRuntime{ 1, 6, 1170, 0 };
    constexpr std::uint64_t LegacyCompileAndRunId = 21890;
    constexpr std::uint64_t ModernCompileAndRunId = 441582;
    constexpr std::uintptr_t ExpectedCompileAndRunOffset = 0x33D6A0;
    constexpr RE::FormID MirabelleReferenceId = 0x0001C1B9;
    constexpr std::string_view MirabelleProbeVoicePath =
        "Voice/Skyrim.esm/FemaleUniqueMirabelleErvine/mg01__000d67d1_1.fuz";
    constexpr std::string_view MirabelleProbeSubtitle =
        "Very good. Then we're done here.";
    constexpr float MirabelleProbeDurationSeconds = 2.147846F;

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

    bool SetSourceLabel(
        RE::StaticFunctionTag*,
        const RE::BSFixedString a_requestId,
        const RE::BSFixedString a_sourceLabel)
    {
        return DNT::ParchmentMenu::SetSourceLabel(
            a_requestId.c_str(),
            a_sourceLabel.c_str());
    }

    bool SetOverlayTexture(
        RE::StaticFunctionTag*,
        const RE::BSFixedString a_requestId,
        const RE::BSFixedString a_texturePath)
    {
        return DNT::ParchmentMenu::SetOverlayTexture(
            a_requestId.c_str(),
            a_texturePath.c_str());
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

    bool AddRouteSegment(
        RE::StaticFunctionTag*,
        const RE::BSFixedString a_requestId,
        const float a_startNormalizedX,
        const float a_startNormalizedY,
        const float a_endNormalizedX,
        const float a_endNormalizedY)
    {
        return DNT::ParchmentMenu::AddRouteSegment(
            a_requestId.c_str(),
            a_startNormalizedX,
            a_startNormalizedY,
            a_endNormalizedX,
            a_endNormalizedY);
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

    bool PlayVoiceProbe(
        RE::StaticFunctionTag*,
        RE::TESObjectREFR* a_speaker,
        const RE::BSFixedString a_voicePath)
    {
        const std::string voicePath = a_voicePath.c_str();
        const auto speakerFormId = a_speaker ? a_speaker->GetFormID() : 0;
        if (speakerFormId != MirabelleReferenceId ||
            voicePath != MirabelleProbeVoicePath) {
            logger::error(
                "PARCHMENT_VOICE_PROBE_REJECT speaker={:08X} path={} reason=invalid_probe_contract",
                speakerFormId,
                voicePath);
            return false;
        }

        const auto presentationWindow = QueuePresentation(
            a_speaker,
            DNT::Parchment::Presentation{
                voicePath,
                std::string(MirabelleProbeSubtitle),
                MirabelleProbeDurationSeconds });
        if (presentationWindow > 0.0F) {
            logger::info(
                "PARCHMENT_VOICE_PROBE_QUEUED speaker={:08X} compatibility=1 presentationSeconds={}",
                speakerFormId,
                presentationWindow);
            return true;
        }
        return false;
    }

}

bool DNT::Papyrus::Register(RE::BSScript::IVirtualMachine* a_vm)
{
    a_vm->RegisterFunction("IsAvailable", PapyrusClass, IsAvailable);
    a_vm->RegisterFunction("RequestDialogueClose", PapyrusClass, RequestDialogueClose);
    a_vm->RegisterFunction("BeginRequest", PapyrusClass, BeginRequest);
    a_vm->RegisterFunction("SetSourceLabel", PapyrusClass, SetSourceLabel);
    a_vm->RegisterFunction("SetOverlayTexture", PapyrusClass, SetOverlayTexture);
    a_vm->RegisterFunction("SetMarkerTextures", PapyrusClass, SetMarkerTextures);
    a_vm->RegisterFunction("SetOriginMarkerTexture", PapyrusClass, SetOriginMarkerTexture);
    a_vm->RegisterFunction("SetPaymentLabelPosition", PapyrusClass, SetPaymentLabelPosition);
    a_vm->RegisterFunction("SetRouteOrigin", PapyrusClass, SetRouteOrigin);
    a_vm->RegisterFunction("AddRouteSegment", PapyrusClass, AddRouteSegment);
    a_vm->RegisterFunction("AddRouteLandmark", PapyrusClass, AddRouteLandmark);
    a_vm->RegisterFunction("AddDestination", PapyrusClass, AddDestination);
    a_vm->RegisterFunction("SetDestinationMarkerTexture", PapyrusClass, SetDestinationMarkerTexture);
    a_vm->RegisterFunction("Show", PapyrusClass, Show);
    a_vm->RegisterFunction("Cancel", PapyrusClass, Cancel);
    a_vm->RegisterFunction("PlayPresentation", PapyrusClass, PlayPresentation);
    a_vm->RegisterFunction("PlayVoiceProbe", PapyrusClass, PlayVoiceProbe);
    return true;
}
