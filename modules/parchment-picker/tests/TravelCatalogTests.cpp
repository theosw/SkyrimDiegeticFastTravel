#include "DNT/TravelCatalog.h"

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

    void TestShippedCatalogue()
    {
        DNT::Travel::Catalog catalog;
        std::string error;
        const auto path = std::filesystem::path(DNT_SOURCE_DIR) /
            "modules/parchment-picker/mod/SKSE/Plugins/DiegeticTravel/travel_catalog.tsv";
        Require(catalog.LoadFile(path, error), error);
        Require(catalog.SchemaVersion() == 1, "shipped schema mismatch");
        Require(catalog.LocationCount() == 27, "shipped carriage catalogue must have 27 locations");
        Require(catalog.PolicyCount() == 1, "shipped catalogue must have one carriage policy");
        Require(catalog.Locations().size() == 27, "enumerable location view must expose every stop");
        Require(catalog.Locations().front().id == "windhelm", "enumeration must preserve authored selection order");
        Require(catalog.Locations().back().id == "winstad_manor", "enumeration tail must preserve authored selection order");
        Require(catalog.FindLocation("morthal") != nullptr, "morthal must be present");
        Require(catalog.FindLocation("winstad_manor") != nullptr, "Windstad Manor must be present");
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
        Require(catalog.EstimateQuote("carriage", "morthal", "falkreath").has_value(),
            "shipped catalogue must quote a representative route");

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
    TestShippedCatalogue();
    std::cout << "TravelCatalogTests: all checks passed\n";
    return EXIT_SUCCESS;
}
