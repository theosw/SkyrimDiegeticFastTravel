#include "DNT/TravelRuntime.h"

#include <chrono>
#include <filesystem>
#include <mutex>

namespace
{
    std::mutex catalogLock;
    DNT::Travel::Catalog catalog;
    bool catalogReady{ false };
    constexpr auto CatalogPath = "Data/SKSE/Plugins/DiegeticTravel/travel_catalog.tsv";
}

bool DNT::TravelRuntime::InitializeCatalog()
{
    const auto startedAt = std::chrono::steady_clock::now();
    Travel::Catalog candidate;
    std::string error;
    if (!candidate.LoadFile(std::filesystem::path(CatalogPath), error)) {
        logger::error("TRAVEL_CATALOG_REJECT path={} reason={}", CatalogPath, error);
        std::scoped_lock lock(catalogLock);
        catalogReady = false;
        return false;
    }

    const auto loadMs = std::chrono::duration<double, std::milli>(
        std::chrono::steady_clock::now() - startedAt).count();
    {
        std::scoped_lock lock(catalogLock);
        catalog = std::move(candidate);
        catalogReady = true;
    }
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

std::vector<DNT::Travel::Location> DNT::TravelRuntime::GetLocations()
{
    std::scoped_lock lock(catalogLock);
    if (!catalogReady) {
        return {};
    }
    return catalog.Locations();
}
