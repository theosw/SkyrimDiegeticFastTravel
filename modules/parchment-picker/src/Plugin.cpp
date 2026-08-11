#include "DNT/Papyrus.h"
#include "DNT/ParchmentMenu.h"
#include "DNT/TravelRuntime.h"

namespace
{
    void SetupLog()
    {
        const auto logDirectory = SKSE::log::log_directory();
        if (!logDirectory) {
            SKSE::stl::report_and_fail("DNT Parchment Picker: SKSE log directory unavailable");
        }

        const auto logPath = *logDirectory / "DNTParchmentPicker.log";
        auto sink = std::make_shared<spdlog::sinks::basic_file_sink_mt>(logPath.string(), true);
        auto log = std::make_shared<spdlog::logger>("DNTParchmentPicker", std::move(sink));
        spdlog::set_default_logger(std::move(log));
        spdlog::set_level(spdlog::level::info);
        spdlog::flush_on(spdlog::level::info);
    }

    void OnMessage(SKSE::MessagingInterface::Message* a_message)
    {
        if (a_message->type == SKSE::MessagingInterface::kPostLoad ||
            a_message->type == SKSE::MessagingInterface::kDataLoaded) {
            if (!DNT::ParchmentMenu::IsAvailable() && !DNT::ParchmentMenu::Initialize()) {
                logger::warn("PARCHMENT_INIT_RETRY_FAILED messageType={}", a_message->type);
            }
        }
        if (a_message->type == SKSE::MessagingInterface::kDataLoaded) {
            if (!DNT::TravelRuntime::InitializeShadowCatalog()) {
                logger::warn("TRAVEL_SHADOW_INIT_FAILED behavior=legacy_unchanged");
            }
        }
    }
}

SKSEPluginLoad(const SKSE::LoadInterface* a_skse)
{
    SKSE::Init(a_skse);
    SetupLog();

    if (!SKSE::GetPapyrusInterface()->Register(DNT::Papyrus::Register)) {
        SKSE::stl::report_and_fail("DNT Parchment Picker: Papyrus registration failed");
    }
    SKSE::GetMessagingInterface()->RegisterListener(OnMessage);
    logger::info("PARCHMENT_PLUGIN_LOAD version={}",
        SKSE::PluginDeclaration::GetSingleton()->GetVersion().string());
    return true;
}
