#pragma once

#include "DNT/PricingConfig.h"
#include "DNT/TravelCatalog.h"

#include <optional>
#include <string_view>
#include <vector>

namespace DNT::TravelRuntime
{
    [[nodiscard]] bool InitializeCatalog();
    [[nodiscard]] bool IsCatalogReady();
    [[nodiscard]] Pricing::Settings GetPricingSettings();
    [[nodiscard]] std::int32_t GetWizardFare(std::int32_t a_fallbackFare);
    [[nodiscard]] std::int32_t ResolveFerryFare(
        std::string_view a_tier,
        std::int32_t a_liveCftoFare);
    [[nodiscard]] std::optional<Travel::Quote> EstimateQuote(
        std::string_view a_providerId,
        std::string_view a_originId,
        std::string_view a_destinationId,
        Travel::QuoteOptions a_options = {});
    [[nodiscard]] std::vector<Travel::Location> GetLocations();
}
