#pragma once

#include <cstdint>
#include <filesystem>
#include <istream>
#include <optional>
#include <string>
#include <string_view>
#include <vector>

namespace DNT::Travel
{
    inline constexpr std::uint32_t SupportedSchemaVersion = 1;

    enum class Availability
    {
        kOpen,
        kOneWay,
        kQuestLocked
    };

    enum class TravelMode
    {
        kTimed,
        kInstant
    };

    struct FormSpec
    {
        std::string plugin;
        std::uint32_t localFormId{ 0 };
    };

    struct Location
    {
        std::string id;
        std::string name;
        float normalizedX{ 0.5F };
        float normalizedY{ 0.5F };
        FormSpec arrivalMarker;
        Availability availability{ Availability::kOpen };
    };

    struct ProviderPolicy
    {
        std::string id;
        float hoursPerMapUnit{ 1.0F };
        float farePerMapUnit{ 100.0F };
        std::int32_t minimumFare{ 0 };
        std::int32_t fareStep{ 1 };
    };

    struct RouteOverride
    {
        std::string providerId;
        std::string originId;
        std::string destinationId;
        std::optional<std::int32_t> fare;
        std::optional<float> hours;
    };

    struct QuoteOptions
    {
        TravelMode mode{ TravelMode::kTimed };
        bool freeRide{ false };
    };

    struct Quote
    {
        std::int32_t fare{ 0 };
        float hours{ 0.0F };
        float directDistance{ 0.0F };
        bool usedOverride{ false };
    };

    class Catalog
    {
    public:
        [[nodiscard]] bool Load(std::istream& a_input, std::string& a_error);
        [[nodiscard]] bool LoadFile(const std::filesystem::path& a_path, std::string& a_error);

        [[nodiscard]] const Location* FindLocation(std::string_view a_id) const;
        [[nodiscard]] const ProviderPolicy* FindPolicy(std::string_view a_id) const;
        [[nodiscard]] bool OverridePolicy(
            std::string_view a_id,
            float a_hoursPerMapUnit,
            float a_farePerMapUnit,
            std::int32_t a_minimumFare,
            std::int32_t a_fareStep);
        [[nodiscard]] std::optional<Quote> EstimateQuote(
            std::string_view a_providerId,
            std::string_view a_originId,
            std::string_view a_destinationId,
            QuoteOptions a_options = {}) const;

        [[nodiscard]] std::uint32_t SchemaVersion() const noexcept;
        [[nodiscard]] std::size_t LocationCount() const noexcept;
        [[nodiscard]] std::size_t PolicyCount() const noexcept;
        [[nodiscard]] std::size_t OverrideCount() const noexcept;
        [[nodiscard]] const std::vector<Location>& Locations() const noexcept;

    private:
        std::uint32_t schemaVersion{ 0 };
        std::vector<Location> locations;
        std::vector<ProviderPolicy> policies;
        std::vector<RouteOverride> overrides;
    };
}
