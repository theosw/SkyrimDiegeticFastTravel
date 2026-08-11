#pragma once

#include "DNT/TravelCatalog.h"

#include <optional>
#include <string_view>
#include <vector>

namespace DNT::TravelRuntime
{
    [[nodiscard]] bool InitializeShadowCatalog();
    [[nodiscard]] bool IsShadowCatalogReady();
    [[nodiscard]] std::optional<Travel::Quote> EstimateShadowQuote(
        std::string_view a_providerId,
        std::string_view a_originId,
        std::string_view a_destinationId,
        Travel::QuoteOptions a_options = {});
    [[nodiscard]] std::vector<Travel::Location> GetShadowLocations();
}
