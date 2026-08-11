#include "DNT/TravelCatalog.h"

#include <algorithm>
#include <charconv>
#include <cctype>
#include <cmath>
#include <fstream>
#include <limits>
#include <sstream>

namespace
{
    using DNT::Travel::Availability;

    std::vector<std::string> SplitTabs(const std::string& a_line)
    {
        std::vector<std::string> fields;
        std::size_t start = 0;
        while (start <= a_line.size()) {
            const auto end = a_line.find('\t', start);
            fields.emplace_back(a_line.substr(start, end - start));
            if (end == std::string::npos) {
                break;
            }
            start = end + 1;
        }
        return fields;
    }

    bool IsIdentifier(const std::string_view a_value)
    {
        if (a_value.empty()) {
            return false;
        }
        return std::all_of(a_value.begin(), a_value.end(), [](const unsigned char a_character) {
            return std::isalnum(a_character) || a_character == '_' || a_character == '-';
        });
    }

    std::string CanonicalizeIdentifier(const std::string_view a_value)
    {
        std::string canonical;
        canonical.reserve(a_value.size());
        std::ranges::transform(a_value, std::back_inserter(canonical), [](const unsigned char a_character) {
            return static_cast<char>(std::tolower(a_character));
        });
        return canonical;
    }

    template <class T>
    bool ParseNumber(const std::string_view a_text, T& a_value)
    {
        const auto* first = a_text.data();
        const auto* last = first + a_text.size();
        const auto result = std::from_chars(first, last, a_value);
        return result.ec == std::errc{} && result.ptr == last;
    }

    bool ParseFloat(const std::string_view a_text, float& a_value)
    {
        try {
            std::size_t consumed = 0;
            a_value = std::stof(std::string(a_text), &consumed);
            return consumed == a_text.size() && std::isfinite(a_value);
        } catch (...) {
            return false;
        }
    }

    bool ParseFormId(const std::string_view a_text, std::uint32_t& a_value)
    {
        try {
            std::size_t consumed = 0;
            const auto parsed = std::stoul(std::string(a_text), &consumed, 0);
            if (consumed != a_text.size() || parsed > std::numeric_limits<std::uint32_t>::max()) {
                return false;
            }
            a_value = static_cast<std::uint32_t>(parsed);
            return true;
        } catch (...) {
            return false;
        }
    }

    std::optional<Availability> ParseAvailability(const std::string_view a_text)
    {
        if (a_text == "open") {
            return Availability::kOpen;
        }
        if (a_text == "one_way") {
            return Availability::kOneWay;
        }
        if (a_text == "quest_locked") {
            return Availability::kQuestLocked;
        }
        return std::nullopt;
    }

    std::optional<std::int32_t> ParseOptionalFare(const std::string_view a_text, bool& a_valid)
    {
        if (a_text.empty() || a_text == "-") {
            a_valid = true;
            return std::nullopt;
        }
        std::int32_t value = 0;
        a_valid = ParseNumber(a_text, value) && value >= 0;
        return a_valid ? std::optional<std::int32_t>(value) : std::nullopt;
    }

    std::optional<float> ParseOptionalHours(const std::string_view a_text, bool& a_valid)
    {
        if (a_text.empty() || a_text == "-") {
            a_valid = true;
            return std::nullopt;
        }
        float value = 0.0F;
        a_valid = ParseFloat(a_text, value) && value >= 0.0F;
        return a_valid ? std::optional<float>(value) : std::nullopt;
    }

    std::string LineError(const std::size_t a_line, const std::string_view a_reason)
    {
        return "line " + std::to_string(a_line) + ": " + std::string(a_reason);
    }
}

bool DNT::Travel::Catalog::Load(std::istream& a_input, std::string& a_error)
{
    Catalog candidate;
    std::string line;
    std::size_t lineNumber = 0;
    while (std::getline(a_input, line)) {
        ++lineNumber;
        if (!line.empty() && line.back() == '\r') {
            line.pop_back();
        }
        if (line.empty() || line.front() == '#') {
            continue;
        }

        const auto fields = SplitTabs(line);
        if (fields.empty()) {
            continue;
        }

        if (fields[0] == "schema") {
            if (fields.size() != 2 || candidate.schemaVersion != 0 ||
                !ParseNumber(fields[1], candidate.schemaVersion) ||
                candidate.schemaVersion != SupportedSchemaVersion) {
                a_error = LineError(lineNumber, "unsupported or duplicate schema");
                return false;
            }
            continue;
        }

        if (candidate.schemaVersion == 0) {
            a_error = LineError(lineNumber, "schema must be declared first");
            return false;
        }

        if (fields[0] == "policy") {
            if (fields.size() != 6 || !IsIdentifier(fields[1])) {
                a_error = LineError(lineNumber, "invalid policy record");
                return false;
            }
            ProviderPolicy policy;
            policy.id = CanonicalizeIdentifier(fields[1]);
            if (!ParseFloat(fields[2], policy.hoursPerMapUnit) || policy.hoursPerMapUnit <= 0.0F ||
                !ParseFloat(fields[3], policy.farePerMapUnit) || policy.farePerMapUnit < 0.0F ||
                !ParseNumber(fields[4], policy.minimumFare) || policy.minimumFare < 0 ||
                !ParseNumber(fields[5], policy.fareStep) || policy.fareStep <= 0 ||
                candidate.FindPolicy(policy.id)) {
                a_error = LineError(lineNumber, "invalid or duplicate policy");
                return false;
            }
            candidate.policies.push_back(std::move(policy));
            continue;
        }

        if (fields[0] == "location") {
            if (fields.size() != 8 || !IsIdentifier(fields[1]) || fields[2].empty() || fields[5].empty()) {
                a_error = LineError(lineNumber, "invalid location record");
                return false;
            }
            Location location;
            location.id = CanonicalizeIdentifier(fields[1]);
            location.name = fields[2];
            location.arrivalMarker.plugin = fields[5];
            const auto availability = ParseAvailability(fields[7]);
            if (!ParseFloat(fields[3], location.normalizedX) ||
                !ParseFloat(fields[4], location.normalizedY) ||
                location.normalizedX < 0.0F || location.normalizedX > 1.0F ||
                location.normalizedY < 0.0F || location.normalizedY > 1.0F ||
                !ParseFormId(fields[6], location.arrivalMarker.localFormId) ||
                location.arrivalMarker.localFormId == 0 || !availability ||
                candidate.FindLocation(location.id)) {
                a_error = LineError(lineNumber, "invalid or duplicate location");
                return false;
            }
            location.availability = *availability;
            candidate.locations.push_back(std::move(location));
            continue;
        }

        if (fields[0] == "override") {
            if (fields.size() != 6 || !IsIdentifier(fields[1]) ||
                !IsIdentifier(fields[2]) || !IsIdentifier(fields[3])) {
                a_error = LineError(lineNumber, "invalid override record");
                return false;
            }
            RouteOverride routeOverride;
            routeOverride.providerId = CanonicalizeIdentifier(fields[1]);
            routeOverride.originId = CanonicalizeIdentifier(fields[2]);
            routeOverride.destinationId = CanonicalizeIdentifier(fields[3]);
            bool fareValid = false;
            bool hoursValid = false;
            routeOverride.fare = ParseOptionalFare(fields[4], fareValid);
            routeOverride.hours = ParseOptionalHours(fields[5], hoursValid);
            const auto duplicate = std::ranges::any_of(candidate.overrides, [&](const auto& a_existing) {
                return a_existing.providerId == routeOverride.providerId &&
                       a_existing.originId == routeOverride.originId &&
                       a_existing.destinationId == routeOverride.destinationId;
            });
            if (!fareValid || !hoursValid || (!routeOverride.fare && !routeOverride.hours) || duplicate) {
                a_error = LineError(lineNumber, "invalid or duplicate override");
                return false;
            }
            candidate.overrides.push_back(std::move(routeOverride));
            continue;
        }

        a_error = LineError(lineNumber, "unknown record type");
        return false;
    }

    if (candidate.schemaVersion != SupportedSchemaVersion ||
        candidate.locations.empty() || candidate.policies.empty()) {
        a_error = "catalog must contain a supported schema, locations, and policies";
        return false;
    }
    for (const auto& routeOverride : candidate.overrides) {
        if (!candidate.FindPolicy(routeOverride.providerId) ||
            !candidate.FindLocation(routeOverride.originId) ||
            !candidate.FindLocation(routeOverride.destinationId) ||
            routeOverride.originId == routeOverride.destinationId) {
            a_error = "override references an unknown or identical endpoint";
            return false;
        }
    }

    *this = std::move(candidate);
    a_error.clear();
    return true;
}

bool DNT::Travel::Catalog::LoadFile(const std::filesystem::path& a_path, std::string& a_error)
{
    std::ifstream input(a_path);
    if (!input) {
        a_error = "could not open " + a_path.string();
        return false;
    }
    return Load(input, a_error);
}

const DNT::Travel::Location* DNT::Travel::Catalog::FindLocation(const std::string_view a_id) const
{
    const auto key = CanonicalizeIdentifier(a_id);
    const auto found = std::ranges::find(locations, key, &Location::id);
    return found == locations.end() ? nullptr : std::addressof(*found);
}

const DNT::Travel::ProviderPolicy* DNT::Travel::Catalog::FindPolicy(const std::string_view a_id) const
{
    const auto key = CanonicalizeIdentifier(a_id);
    const auto found = std::ranges::find(policies, key, &ProviderPolicy::id);
    return found == policies.end() ? nullptr : std::addressof(*found);
}

std::optional<DNT::Travel::Quote> DNT::Travel::Catalog::EstimateQuote(
    const std::string_view a_providerId,
    const std::string_view a_originId,
    const std::string_view a_destinationId,
    const QuoteOptions a_options) const
{
    const auto* policy = FindPolicy(a_providerId);
    const auto* origin = FindLocation(a_originId);
    const auto* destination = FindLocation(a_destinationId);
    if (!policy || !origin || !destination || origin == destination) {
        return std::nullopt;
    }

    const auto deltaX = destination->normalizedX - origin->normalizedX;
    const auto deltaY = destination->normalizedY - origin->normalizedY;
    Quote quote;
    quote.directDistance = std::hypot(deltaX, deltaY);
    quote.hours = quote.directDistance * policy->hoursPerMapUnit;
    const auto rawFare = std::max(
        static_cast<float>(policy->minimumFare),
        quote.directDistance * policy->farePerMapUnit);
    quote.fare = static_cast<std::int32_t>(
        std::lround(rawFare / static_cast<float>(policy->fareStep))) * policy->fareStep;

    const auto routeOverride = std::ranges::find_if(overrides, [&](const auto& a_override) {
        return a_override.providerId == policy->id &&
               a_override.originId == origin->id &&
               a_override.destinationId == destination->id;
    });
    if (routeOverride != overrides.end()) {
        if (routeOverride->fare) {
            quote.fare = *routeOverride->fare;
        }
        if (routeOverride->hours) {
            quote.hours = *routeOverride->hours;
        }
        quote.usedOverride = true;
    }

    if (a_options.freeRide) {
        quote.fare = 0;
    }
    if (a_options.mode == TravelMode::kInstant) {
        quote.hours = 0.0F;
    }
    return quote;
}

std::uint32_t DNT::Travel::Catalog::SchemaVersion() const noexcept
{
    return schemaVersion;
}

std::size_t DNT::Travel::Catalog::LocationCount() const noexcept
{
    return locations.size();
}

std::size_t DNT::Travel::Catalog::PolicyCount() const noexcept
{
    return policies.size();
}

std::size_t DNT::Travel::Catalog::OverrideCount() const noexcept
{
    return overrides.size();
}

const std::vector<DNT::Travel::Location>& DNT::Travel::Catalog::Locations() const noexcept
{
    return locations;
}
