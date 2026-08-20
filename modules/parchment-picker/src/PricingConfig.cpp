#include "DNT/PricingConfig.h"

#include <algorithm>
#include <charconv>
#include <cctype>
#include <cmath>
#include <fstream>
#include <ranges>
#include <string_view>
#include <unordered_set>

namespace
{
    std::string Trim(const std::string_view a_value)
    {
        const auto first = std::ranges::find_if_not(a_value, [](const unsigned char a_character) {
            return std::isspace(a_character) != 0;
        });
        const auto last = std::ranges::find_if_not(a_value | std::views::reverse, [](const unsigned char a_character) {
            return std::isspace(a_character) != 0;
        }).base();
        return first >= last ? std::string{} : std::string(first, last);
    }

    std::string Lower(const std::string_view a_value)
    {
        std::string lowered(a_value);
        std::ranges::transform(lowered, lowered.begin(), [](const unsigned char a_character) {
            return static_cast<char>(std::tolower(a_character));
        });
        return lowered;
    }

    template <class T>
    bool ParseInteger(const std::string_view a_text, T& a_value)
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

    bool ParseBool(const std::string_view a_text, bool& a_value)
    {
        const auto value = Lower(a_text);
        if (value == "true" || value == "yes" || value == "on" || value == "1") {
            a_value = true;
            return true;
        }
        if (value == "false" || value == "no" || value == "off" || value == "0") {
            a_value = false;
            return true;
        }
        return false;
    }

    std::string Warning(const std::size_t a_line, const std::string_view a_message)
    {
        return "line " + std::to_string(a_line) + ": " + std::string(a_message);
    }
}

bool DNT::Pricing::Config::Load(std::istream& a_input, std::vector<std::string>& a_warnings)
{
    settings = Settings{};
    a_warnings.clear();
    std::unordered_set<std::string> seenKeys;
    std::string section;
    std::string line;
    std::size_t lineNumber = 0;

    while (std::getline(a_input, line)) {
        ++lineNumber;
        if (!line.empty() && line.back() == '\r') {
            line.pop_back();
        }
        const auto comment = line.find_first_of(";#");
        const auto content = Trim(line.substr(0, comment));
        if (content.empty()) {
            continue;
        }
        if (content.front() == '[' && content.back() == ']') {
            section = Lower(Trim(std::string_view(content).substr(1, content.size() - 2)));
            if (section.empty()) {
                a_warnings.push_back(Warning(lineNumber, "empty section ignored"));
            }
            continue;
        }

        const auto equals = content.find('=');
        if (equals == std::string::npos || section.empty()) {
            a_warnings.push_back(Warning(lineNumber, "expected key=value inside a section"));
            continue;
        }
        const auto key = Lower(Trim(std::string_view(content).substr(0, equals)));
        const auto value = Trim(std::string_view(content).substr(equals + 1));
        const auto qualifiedKey = section + '.' + key;
        if (!seenKeys.insert(qualifiedKey).second) {
            a_warnings.push_back(Warning(lineNumber, "duplicate setting; last valid value wins"));
        }

        bool valid = false;
        if (qualifiedKey == "carriage.hourspermapunit") {
            float parsed = 0.0F;
            valid = ParseFloat(value, parsed) && parsed > 0.0F && parsed <= 1000.0F;
            if (valid) settings.carriageHoursPerMapUnit = parsed;
        } else if (qualifiedKey == "carriage.farepermapunit") {
            float parsed = 0.0F;
            valid = ParseFloat(value, parsed) && parsed >= 0.0F && parsed <= 1000000.0F;
            if (valid) settings.carriageFarePerMapUnit = parsed;
        } else if (qualifiedKey == "carriage.minimumfare") {
            std::int32_t parsed = 0;
            valid = ParseInteger(value, parsed) && parsed >= 0 && parsed <= 1000000;
            if (valid) settings.carriageMinimumFare = parsed;
        } else if (qualifiedKey == "carriage.farestep") {
            std::int32_t parsed = 0;
            valid = ParseInteger(value, parsed) && parsed > 0 && parsed <= 100000;
            if (valid) settings.carriageFareStep = parsed;
        } else if (qualifiedKey == "wizard.farepertrip") {
            std::int32_t parsed = 0;
            valid = ParseInteger(value, parsed) && parsed >= 0 && parsed <= 1000000;
            if (valid) settings.wizardFarePerTrip = parsed;
        } else if (qualifiedKey == "ferries.usecftofares") {
            bool parsed = false;
            valid = ParseBool(value, parsed);
            if (valid) settings.useCftoFares = parsed;
        } else if (qualifiedKey == "ferries.localfareoverride" ||
                   qualifiedKey == "ferries.regionalfareoverride" ||
                   qualifiedKey == "ferries.extrafareoverride") {
            std::int32_t parsed = 0;
            valid = ParseInteger(value, parsed) && parsed >= -1 && parsed <= 1000000;
            if (valid && qualifiedKey == "ferries.localfareoverride") settings.localFerryFareOverride = parsed;
            if (valid && qualifiedKey == "ferries.regionalfareoverride") settings.regionalFerryFareOverride = parsed;
            if (valid && qualifiedKey == "ferries.extrafareoverride") settings.extraFerryFareOverride = parsed;
        } else if (qualifiedKey == "display.showestimatedhours") {
            bool parsed = false;
            valid = ParseBool(value, parsed);
            if (valid) settings.showEstimatedHours = parsed;
        } else if (qualifiedKey == "display.markhoursasapproximate") {
            bool parsed = false;
            valid = ParseBool(value, parsed);
            if (valid) settings.markHoursAsApproximate = parsed;
        } else if (qualifiedKey == "display.preferformalmapartwork") {
            bool parsed = false;
            valid = ParseBool(value, parsed);
            if (valid) settings.preferFormalMapArtwork = parsed;
        } else {
            a_warnings.push_back(Warning(lineNumber, "unknown setting '" + qualifiedKey + "' ignored"));
            continue;
        }

        if (!valid) {
            a_warnings.push_back(Warning(lineNumber, "invalid value for '" + qualifiedKey + "'; previous value retained"));
        }
    }
    return true;
}

bool DNT::Pricing::Config::LoadFile(
    const std::filesystem::path& a_path,
    std::vector<std::string>& a_warnings)
{
    settings = Settings{};
    std::ifstream input(a_path);
    if (!input) {
        a_warnings = { "could not open " + a_path.string() + "; defaults retained" };
        return false;
    }
    return Load(input, a_warnings);
}

const DNT::Pricing::Settings& DNT::Pricing::Config::Get() const noexcept
{
    return settings;
}
