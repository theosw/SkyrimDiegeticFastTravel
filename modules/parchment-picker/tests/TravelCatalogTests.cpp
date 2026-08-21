#include "DNT/PricingConfig.h"
#include "DNT/TravelCatalog.h"

#include <algorithm>
#include <array>
#include <cmath>
#include <cstdlib>
#include <iostream>
#include <sstream>
#include <string>
#include <string_view>
#include <utility>
#include <vector>

namespace
{
    void Require(const bool a_condition, const std::string_view a_message)
    {
        if (!a_condition) {
            std::cerr << "TravelCatalogTests: " << a_message << '\n';
            std::exit(EXIT_FAILURE);
        }
    }

    DNT::Travel::Catalog LoadFixture()
    {
        std::istringstream input(
            "schema\t1\n"
            "policy\tcarriage\t10\t1600\t100\t50\n"
            "location\tmorthal\tMorthal\t0.4\t0.3\tCFTO.esp\t0xB6E4A\topen\n"
            "location\tfalkreath\tFalkreath\t0.4\t0.8\tCFTO.esp\t0xB6E43\topen\n"
            "location\thalfmoon_mill\tHalf-Moon Mill\t0.39\t0.71\tCFTO.esp\t0xB6E4F\tone_way\n"
            "override\tcarriage\tmorthal\thalfmoon_mill\t450\t3.25\n");
        DNT::Travel::Catalog catalog;
        std::string error;
        Require(catalog.Load(input, error), error);
        return catalog;
    }

    void TestFlatEstimate()
    {
        const auto catalog = LoadFixture();
        const auto quote = catalog.EstimateQuote("carriage", "morthal", "falkreath");
        Require(quote.has_value(), "direct quote should exist");
        Require(std::abs(quote->directDistance - 0.5F) < 0.0001F, "direct distance mismatch");
        Require(std::abs(quote->hours - 5.0F) < 0.0001F, "hours mismatch");
        Require(quote->fare == 800, "fare should round to the configured step");
        Require(!quote->usedOverride, "direct quote should not report an override");
    }

    void TestOverridesAndModes()
    {
        const auto catalog = LoadFixture();
        auto quote = catalog.EstimateQuote("carriage", "morthal", "halfmoon_mill");
        Require(quote && quote->fare == 450, "override fare mismatch");
        Require(quote && std::abs(quote->hours - 3.25F) < 0.0001F, "override hours mismatch");
        Require(quote && quote->usedOverride, "override should be reported");

        quote = catalog.EstimateQuote(
            "carriage",
            "morthal",
            "halfmoon_mill",
            { DNT::Travel::TravelMode::kInstant, true });
        Require(quote && quote->fare == 0, "free ride should zero the fare");
        Require(quote && quote->hours == 0.0F, "instant travel should zero elapsed hours");
    }

    void TestIdentifierCanonicalization()
    {
        const auto catalog = LoadFixture();
        Require(catalog.FindPolicy("Carriage") != nullptr, "provider lookup must ignore case");
        Require(catalog.FindLocation("MORTHAL") != nullptr, "location lookup must ignore case");

        const auto quote = catalog.EstimateQuote("CARRIAGE", "Morthal", "HALFMOON_MILL");
        Require(quote.has_value(), "mixed-case quote identifiers must resolve");
        Require(quote->usedOverride, "mixed-case quote must retain its route override");
        Require(quote->fare == 450, "mixed-case override fare mismatch");
    }

    void TestValidation()
    {
        std::istringstream duplicate(
            "schema\t1\n"
            "policy\tcarriage\t10\t1600\t100\t50\n"
            "location\tmorthal\tMorthal\t0.4\t0.3\tCFTO.esp\t0xB6E4A\topen\n"
            "location\tmorthal\tMorthal Again\t0.5\t0.4\tCFTO.esp\t0xB6E4A\topen\n");
        DNT::Travel::Catalog catalog;
        std::string error;
        Require(!catalog.Load(duplicate, error), "duplicate locations must fail");
        Require(error.find("duplicate location") != std::string::npos, "duplicate error should be specific");

        std::istringstream badSchema("schema\t2\n");
        Require(!catalog.Load(badSchema, error), "unsupported schemas must fail");

        std::istringstream caseDuplicate(
            "schema\t1\n"
            "policy\tcarriage\t10\t1600\t100\t50\n"
            "location\tmorthal\tMorthal\t0.4\t0.3\tCFTO.esp\t0xB6E4A\topen\n"
            "location\tMORTHAL\tMorthal Again\t0.5\t0.4\tCFTO.esp\t0xB6E4A\topen\n");
        Require(!catalog.Load(caseDuplicate, error), "case-only location duplicates must fail");
    }

    void TestPolicyOverride()
    {
        auto catalog = LoadFixture();
        Require(catalog.OverridePolicy("CARRIAGE", 8.0F, 1000.0F, 200, 25),
            "valid policy override should apply case-insensitively");
        const auto quote = catalog.EstimateQuote("carriage", "morthal", "falkreath");
        Require(quote && std::abs(quote->hours - 4.0F) < 0.0001F, "overridden hours mismatch");
        Require(quote && quote->fare == 500, "overridden fare mismatch");
        Require(!catalog.OverridePolicy("missing", 8.0F, 1000.0F, 200, 25),
            "unknown provider override must fail");
        Require(!catalog.OverridePolicy("carriage", 8.0F, 1000.0F, 200, 0),
            "zero fare step must fail");
    }

    void TestPricingConfig()
    {
        std::istringstream input(
            "[Carriage]\n"
            "HoursPerMapUnit=8.5\n"
            "FarePerMapUnit=1200\n"
            "MinimumFare=75\n"
            "FareStep=25\n"
            "[Wizard]\n"
            "FarePerTrip=300\n"
            "[Ferries]\n"
            "UseCFTOFares=no\n"
            "LocalFareOverride=40\n"
            "RegionalFareOverride=-1\n"
            "ExtraFareOverride=125\n"
            "[Display]\n"
            "ShowEstimatedHours=false\n"
            "MarkHoursAsApproximate=on\n"
            "PreferFormalMapArtwork=off\n");
        DNT::Pricing::Config config;
        std::vector<std::string> warnings;
        Require(config.Load(input, warnings), "valid pricing config should load");
        Require(warnings.empty(), "valid pricing config should not warn");
        const auto& settings = config.Get();
        Require(std::abs(settings.carriageHoursPerMapUnit - 8.5F) < 0.0001F,
            "configured carriage hours mismatch");
        Require(settings.carriageFarePerMapUnit == 1200.0F, "configured carriage fare rate mismatch");
        Require(settings.carriageMinimumFare == 75 && settings.carriageFareStep == 25,
            "configured carriage rounding mismatch");
        Require(settings.wizardFarePerTrip == 300, "configured wizard fare mismatch");
        Require(!settings.useCftoFares && settings.localFerryFareOverride == 40 &&
                settings.regionalFerryFareOverride == -1 && settings.extraFerryFareOverride == 125,
            "configured ferry settings mismatch");
        Require(!settings.showEstimatedHours && settings.markHoursAsApproximate &&
                !settings.preferFormalMapArtwork,
            "configured display settings mismatch");

        std::istringstream invalid(
            "[Carriage]\n"
            "HoursPerMapUnit=0\n"
            "FareStep=0\n"
            "[Wizard]\n"
            "FarePerTrip=-4\n"
            "[Display]\n"
            "PreferFormalMapArtwork=perhaps\n");
        Require(config.Load(invalid, warnings), "invalid fields should retain safe defaults");
        Require(warnings.size() == 4, "each invalid field should produce a warning");
        Require(config.Get().carriageHoursPerMapUnit == 10.0F &&
                config.Get().carriageFarePerMapUnit == 475.0F &&
                config.Get().carriageMinimumFare == 50 &&
                config.Get().carriageFareStep == 50 && config.Get().wizardFarePerTrip == 250 &&
                config.Get().preferFormalMapArtwork,
            "invalid fields must retain defaults");
    }

    void TestShippedCatalogue()
    {
        DNT::Travel::Catalog catalog;
        std::string error;
        const auto path = std::filesystem::path(DNT_SOURCE_DIR) /
            "modules/parchment-picker/mod/SKSE/Plugins/DiegeticTravel/travel_catalog.tsv";
        Require(catalog.LoadFile(path, error), error);
        Require(catalog.SchemaVersion() == 1, "shipped schema mismatch");
        Require(catalog.LocationCount() == 28, "shipped carriage catalogue must have 28 locations");
        Require(catalog.PolicyCount() == 1, "shipped catalogue must have one carriage policy");
        Require(catalog.Locations().size() == 28, "enumerable location view must expose every stop");
        Require(catalog.Locations().front().id == "windhelm", "enumeration must preserve authored selection order");
        Require(catalog.Locations().back().id == "winstad_manor", "enumeration tail must preserve authored selection order");
        Require(catalog.FindLocation("morthal") != nullptr, "morthal must be present");
        Require(catalog.FindLocation("winstad_manor") != nullptr, "Windstad Manor must be present");
        const auto* embassy = catalog.FindLocation("thalmor_embassy");
        Require(embassy != nullptr, "Thalmor Embassy must be present");
        Require(embassy->arrivalMarker.plugin == "CFTO.esp" &&
                embassy->arrivalMarker.localFormId == 0x0B6E54,
            "Thalmor Embassy must resolve CFTO's authored arrival marker");
        Require(embassy->availability == DNT::Travel::Availability::kOneWay,
            "Thalmor Embassy must remain destination-only");
        const std::array innOrigins{
            std::pair{ "riverwood", "Riverwood" },
            std::pair{ "old_hroldan", "Old Hroldan" },
            std::pair{ "rorikstead", "Rorikstead" },
            std::pair{ "dragon_bridge", "Dragon Bridge" },
            std::pair{ "nightgate_inn", "Nightgate Inn" },
            std::pair{ "kynesgrove", "Kynesgrove" },
            std::pair{ "ivarstead", "Ivarstead" }
        };
        for (const auto& [id, expectedName] : innOrigins) {
            const auto* location = catalog.FindLocation(id);
            Require(location != nullptr, std::string("WCI inn origin missing from shipped catalogue: ") + id);
            Require(location->name == expectedName, std::string("WCI inn origin has wrong source label: ") + id);
        }
        const std::array privateOrigins{
            std::pair{ "lakeview_manor", "Lakeview Manor" },
            std::pair{ "winstad_manor", "Windstad Manor" },
            std::pair{ "heljarchen_hall", "Heljarchen Hall" }
        };
        for (const auto& [id, expectedName] : privateOrigins) {
            const auto* location = catalog.FindLocation(id);
            Require(location != nullptr, std::string("private carriage origin missing: ") + id);
            Require(location->name == expectedName, std::string("private carriage origin has wrong source label: ") + id);
            Require(location->availability == DNT::Travel::Availability::kQuestLocked,
                std::string("private carriage origin must retain its live Hearthfire gate: ") + id);
            const auto quote = catalog.EstimateQuote(
                "carriage", id, "riften", { DNT::Travel::TravelMode::kTimed, true });
            Require(quote && quote->fare == 0,
                std::string("private carriage origin must retain zero-fare quotes: ") + id);
        }
        Require(catalog.EstimateQuote("carriage", "morthal", "falkreath").has_value(),
            "shipped catalogue must quote a representative route");

        DNT::Pricing::Config pricing;
        std::vector<std::string> pricingWarnings;
        const auto pricingPath = std::filesystem::path(DNT_SOURCE_DIR) /
            "modules/parchment-picker/mod/SKSE/Plugins/DiegeticTravel.ini";
        Require(pricing.LoadFile(pricingPath, pricingWarnings), "shipped pricing INI must load");
        Require(pricingWarnings.empty(), "shipped pricing INI must not warn");
        const auto& shippedPricing = pricing.Get();
        Require(shippedPricing.carriageHoursPerMapUnit == 10.0F &&
                shippedPricing.carriageFarePerMapUnit == 475.0F &&
                shippedPricing.carriageMinimumFare == 50 &&
                shippedPricing.carriageFareStep == 50,
            "shipped carriage pricing must use the public 475/50/50 policy");
        const auto* shippedPolicy = catalog.FindPolicy("carriage");
        Require(shippedPolicy != nullptr &&
                shippedPolicy->hoursPerMapUnit == shippedPricing.carriageHoursPerMapUnit &&
                shippedPolicy->farePerMapUnit == shippedPricing.carriageFarePerMapUnit &&
                shippedPolicy->minimumFare == shippedPricing.carriageMinimumFare &&
                shippedPolicy->fareStep == shippedPricing.carriageFareStep,
            "shipped INI and catalogue carriage policies must remain identical");

        const std::array physicalDriverOrigins{
            "dawnstar",
            "falkreath",
            "markarth",
            "morthal",
            "riften",
            "solitude",
            "whiterun",
            "windhelm",
            "winterhold"
        };
        std::int32_t minimumPhysicalFare = 1000000;
        std::int32_t maximumPhysicalFare = 0;
        for (const auto originId : physicalDriverOrigins) {
            for (const auto& destination : catalog.Locations()) {
                if (destination.id == originId) continue;
                const auto quote = catalog.EstimateQuote("carriage", originId, destination.id);
                Require(quote.has_value(),
                    std::string("physical-driver route must quote: ") + originId + " -> " + destination.id);
                minimumPhysicalFare = std::min(minimumPhysicalFare, quote->fare);
                maximumPhysicalFare = std::max(maximumPhysicalFare, quote->fare);
            }
        }
        Require(minimumPhysicalFare == 50 && maximumPhysicalFare == 400,
            "public physical-driver fare envelope must remain 50-400 gold");
        Require(catalog.EstimateQuote("carriage", "whiterun", "falkreath")->fare == 150,
            "Whiterun-to-Falkreath public balance anchor must remain 150 gold");
        Require(catalog.EstimateQuote("carriage", "whiterun", "riften")->fare == 200,
            "Whiterun-to-Riften public balance anchor must remain 200 gold");
        Require(catalog.EstimateQuote("carriage", "markarth", "riften")->fare == 400,
            "Markarth-to-Riften public balance anchor must remain 400 gold");

        const std::vector<std::string_view> liveFalkreathDestinationIds{
            "DARKWATER_CROSSING",
            "Dawnstar",
            "DRAGON_BRIDGE",
            "halfmoon_mill",
            "heartwood_mill",
            "Ivarstead",
            "Karthwasten",
            "Kynesgrove",
            "Markarth",
            "mixwater_mill",
            "Morthal",
            "nightgate_inn",
            "old_hroldan",
            "Riften",
            "Riverwood",
            "Rorikstead",
            "SHORS_STONE",
            "Solitude",
            "soljunds_sinkhole",
            "Stonehills",
            "thalmor_embassy",
            "Whiterun",
            "Windhelm",
            "Winterhold"
        };
        for (const auto destinationId : liveFalkreathDestinationIds) {
            Require(
                catalog.EstimateQuote("Carriage", "Falkreath", destinationId).has_value(),
                std::string("live Falkreath destination must resolve: ") + std::string(destinationId));
        }
    }
}

int main()
{
    TestFlatEstimate();
    TestOverridesAndModes();
    TestIdentifierCanonicalization();
    TestValidation();
    TestPolicyOverride();
    TestPricingConfig();
    TestShippedCatalogue();
    std::cout << "TravelCatalogTests: all checks passed\n";
    return EXIT_SUCCESS;
}
