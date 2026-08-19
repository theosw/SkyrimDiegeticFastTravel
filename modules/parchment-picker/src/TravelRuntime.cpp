#include "DNT/TravelRuntime.h"

#include <algorithm>
#include <cctype>
#include <chrono>
#include <filesystem>
#include <mutex>

namespace
{
    std::mutex catalogLock;
    DNT::Travel::Catalog catalog;
    bool catalogReady{ false };
    DNT::Pricing::Settings pricingSettings;
    constexpr auto CatalogPath = "Data/SKSE/Plugins/DiegeticTravel/travel_catalog.tsv";
    constexpr auto PricingPath = "Data/SKSE/Plugins/DiegeticTravel.ini";

    std::string NormalizeTier(const std::string_view a_tier)
    {
        std::string normalized(a_tier);
        std::ranges::transform(normalized, normalized.begin(), [](const unsigned char a_character) {
            return static_cast<char>(std::tolower(a_character));
        });
        return normalized;
    }
}

bool DNT::TravelRuntime::InitializeCatalog()
{
    const auto startedAt = std::chrono::steady_clock::now();
    Pricing::Config pricingConfig;
    std::vector<std::string> pricingWarnings;
    const bool pricingFileLoaded = pricingConfig.LoadFile(PricingPath, pricingWarnings);
    for (const auto& warning : pricingWarnings) {
        logger::warn("PRICING_CONFIG_WARNING path={} detail={}", PricingPath, warning);
    }
    const auto loadedSettings = pricingConfig.Get();

    Travel::Catalog candidate;
    std::string error;
    if (!candidate.LoadFile(std::filesystem::path(CatalogPath), error)) {
        logger::error("TRAVEL_CATALOG_REJECT path={} reason={}", CatalogPath, error);
        std::scoped_lock lock(catalogLock);
        pricingSettings = loadedSettings;
        catalogReady = false;
        return false;
    }
    if (!candidate.OverridePolicy(
            "carriage",
            loadedSettings.carriageHoursPerMapUnit,
            loadedSettings.carriageFarePerMapUnit,
            loadedSettings.carriageMinimumFare,
            loadedSettings.carriageFareStep)) {
        logger::error("PRICING_CONFIG_REJECT reason=carriage_policy_missing");
        std::scoped_lock lock(catalogLock);
        pricingSettings = loadedSettings;
        catalogReady = false;
        return false;
    }

    const auto loadMs = std::chrono::duration<double, std::milli>(
        std::chrono::steady_clock::now() - startedAt).count();
    {
        std::scoped_lock lock(catalogLock);
        catalog = std::move(candidate);
        pricingSettings = loadedSettings;
        catalogReady = true;
    }
    logger::info(
        "PRICING_CONFIG_READY path={} file_loaded={} carriage_hours_per_unit={} carriage_fare_per_unit={} carriage_minimum={} carriage_step={} wizard_fare={} use_cfto={} ferry_overrides={}/{}/{} show_hours={} approximate_hours={}",
        PricingPath,
        pricingFileLoaded,
        loadedSettings.carriageHoursPerMapUnit,
        loadedSettings.carriageFarePerMapUnit,
        loadedSettings.carriageMinimumFare,
        loadedSettings.carriageFareStep,
        loadedSettings.wizardFarePerTrip,
        loadedSettings.useCftoFares,
        loadedSettings.localFerryFareOverride,
        loadedSettings.regionalFerryFareOverride,
        loadedSettings.extraFerryFareOverride,
        loadedSettings.showEstimatedHours,
        loadedSettings.markHoursAsApproximate);
    logger::info(
        "TRAVEL_CATALOG_READY schema={} locations={} policies={} overrides={} load_ms={:.3f}",
        catalog.SchemaVersion(),
        catalog.LocationCount(),
        catalog.PolicyCount(),
        catalog.OverrideCount(),
        loadMs);

    if (const auto probe = EstimateQuote("carriage", "morthal", "falkreath")) {
        logger::info(
            "TRAVEL_CATALOG_PROBE provider=carriage origin=morthal destination=falkreath fare={} hours={:.3f} distance={:.5f}",
            probe->fare,
            probe->hours,
            probe->directDistance);
    }
    return true;
}

bool DNT::TravelRuntime::IsCatalogReady()
{
    std::scoped_lock lock(catalogLock);
    return catalogReady;
}

DNT::Pricing::Settings DNT::TravelRuntime::GetPricingSettings()
{
    std::scoped_lock lock(catalogLock);
    return pricingSettings;
}

std::int32_t DNT::TravelRuntime::GetWizardFare(const std::int32_t a_fallbackFare)
{
    std::scoped_lock lock(catalogLock);
    return pricingSettings.wizardFarePerTrip >= 0 ?
        pricingSettings.wizardFarePerTrip : a_fallbackFare;
}

std::int32_t DNT::TravelRuntime::ResolveFerryFare(
    const std::string_view a_tier,
    const std::int32_t a_liveCftoFare)
{
    std::scoped_lock lock(catalogLock);
    const auto tier = NormalizeTier(a_tier);
    std::int32_t overrideFare = -1;
    std::int32_t auditedFallback = -1;
    if (tier == "local") {
        overrideFare = pricingSettings.localFerryFareOverride;
        auditedFallback = 30;
    } else if (tier == "regional") {
        overrideFare = pricingSettings.regionalFerryFareOverride;
        auditedFallback = 50;
    } else if (tier == "extra") {
        overrideFare = pricingSettings.extraFerryFareOverride;
        auditedFallback = 100;
    } else {
        return -1;
    }
    if (overrideFare >= 0) {
        return overrideFare;
    }
    if (pricingSettings.useCftoFares && a_liveCftoFare >= 0) {
        return a_liveCftoFare;
    }
    return auditedFallback;
}

std::optional<DNT::Travel::Quote> DNT::TravelRuntime::EstimateQuote(
    const std::string_view a_providerId,
    const std::string_view a_originId,
    const std::string_view a_destinationId,
    const Travel::QuoteOptions a_options)
{
    std::scoped_lock lock(catalogLock);
    if (!catalogReady) {
        return std::nullopt;
    }
    return catalog.EstimateQuote(a_providerId, a_originId, a_destinationId, a_options);
}

std::optional<DNT::Travel::Location> DNT::TravelRuntime::GetLocation(
    const std::string_view a_locationId)
{
    std::scoped_lock lock(catalogLock);
    if (!catalogReady) {
        return std::nullopt;
    }
    const auto* const location = catalog.FindLocation(a_locationId);
    return location ? std::optional{ *location } : std::nullopt;
}

std::vector<DNT::Travel::Location> DNT::TravelRuntime::GetLocations()
{
    std::scoped_lock lock(catalogLock);
    if (!catalogReady) {
        return {};
    }
    return catalog.Locations();
}
