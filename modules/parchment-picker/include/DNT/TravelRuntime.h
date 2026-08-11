#pragma once

#include "DNT/TravelCatalog.h"

#include <optional>
#include <string_view>
#include <vector>

namespace DNT::TravelRuntime
{
    [[nodiscard]] bool InitializeCatalog();
    [[nodiscard]] bool IsCatalogReady();
    [[nodiscard]] std::optional<Travel::Quote> EstimateQuote(
        std::string_view a_providerId,
        std::string_view a_originId,
        std::string_view a_destinationId,
        Travel::QuoteOptions a_options = {});
    [[nodiscard]] std::vector<Travel::Location> GetLocations();
}
