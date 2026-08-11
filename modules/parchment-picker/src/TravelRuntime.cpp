#include "DNT/TravelRuntime.h"

#include <chrono>
#include <filesystem>
#include <mutex>

namespace
{
    std::mutex catalogLock;
    DNT::Travel::Catalog shadowCatalog;
    bool shadowCatalogReady{ false };
    constexpr auto CatalogPath = "Data/SKSE/Plugins/DiegeticTravel/travel_catalog.tsv";
}

bool DNT::TravelRuntime::InitializeShadowCatalog()
{
    const auto startedAt = std::chrono::steady_clock::now();
    Travel::Catalog candidate;
    std::string error;
    if (!candidate.LoadFile(std::filesystem::path(CatalogPath), error)) {
        logger::error("TRAVEL_SHADOW_CATALOG_REJECT path={} reason={}", CatalogPath, error);
        std::scoped_lock lock(catalogLock);
        shadowCatalogReady = false;
        return false;
    }

    const auto loadMs = std::chrono::duration<double, std::milli>(
        std::chrono::steady_clock::now() - startedAt).count();
    {
        std::scoped_lock lock(catalogLock);
        shadowCatalog = std::move(candidate);
        shadowCatalogReady = true;
    }
    logger::info(
        "TRAVEL_SHADOW_CATALOG_READY schema={} locations={} policies={} overrides={} load_ms={:.3f} behavior=authoritative_carriage",
        shadowCatalog.SchemaVersion(),
        shadowCatalog.LocationCount(),
        shadowCatalog.PolicyCount(),
        shadowCatalog.OverrideCount(),
        loadMs);

    if (const auto probe = EstimateShadowQuote("carriage", "morthal", "falkreath")) {
        logger::info(
            "TRAVEL_SHADOW_PROBE provider=carriage origin=morthal destination=falkreath fare={} hours={:.3f} distance={:.5f}",
            probe->fare,
            probe->hours,
            probe->directDistance);
    }
    return true;
}

bool DNT::TravelRuntime::IsShadowCatalogReady()
{
    std::scoped_lock lock(catalogLock);
    return shadowCatalogReady;
}

std::optional<DNT::Travel::Quote> DNT::TravelRuntime::EstimateShadowQuote(
    const std::string_view a_providerId,
    const std::string_view a_originId,
    const std::string_view a_destinationId,
    const Travel::QuoteOptions a_options)
{
    std::scoped_lock lock(catalogLock);
    if (!shadowCatalogReady) {
        return std::nullopt;
    }
    return shadowCatalog.EstimateQuote(a_providerId, a_originId, a_destinationId, a_options);
}

std::vector<DNT::Travel::Location> DNT::TravelRuntime::GetShadowLocations()
{
    std::scoped_lock lock(catalogLock);
    if (!shadowCatalogReady) {
        return {};
    }
    return shadowCatalog.Locations();
}
