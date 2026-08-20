#pragma once

#include <cstdint>
#include <filesystem>
#include <istream>
#include <string>
#include <vector>

namespace DNT::Pricing
{
    struct Settings
    {
        float carriageHoursPerMapUnit{ 10.0F };
        float carriageFarePerMapUnit{ 475.0F };
        std::int32_t carriageMinimumFare{ 50 };
        std::int32_t carriageFareStep{ 50 };

        std::int32_t wizardFarePerTrip{ 250 };

        bool useCftoFares{ true };
        std::int32_t localFerryFareOverride{ -1 };
        std::int32_t regionalFerryFareOverride{ -1 };
        std::int32_t extraFerryFareOverride{ -1 };

        bool showEstimatedHours{ true };
        bool markHoursAsApproximate{ true };
    };

    class Config
    {
    public:
        [[nodiscard]] bool Load(std::istream& a_input, std::vector<std::string>& a_warnings);
        [[nodiscard]] bool LoadFile(
            const std::filesystem::path& a_path,
            std::vector<std::string>& a_warnings);
        [[nodiscard]] const Settings& Get() const noexcept;

    private:
        Settings settings;
    };
}
