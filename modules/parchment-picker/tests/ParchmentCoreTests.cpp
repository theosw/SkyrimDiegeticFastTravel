#include "DNT/ParchmentCore.h"

#include <cmath>
#include <cstdlib>
#include <iostream>
#include <string>

namespace
{
    constexpr float CollegeArtAspect = 1.358090F;

    void Require(const bool a_condition, const char* a_message)
    {
        if (!a_condition) {
            std::cerr << "FAILED: " << a_message << '\n';
            std::exit(EXIT_FAILURE);
        }
    }

    void RequireClose(const float a_actual, const float a_expected, const float a_tolerance, const char* a_message)
    {
        Require(std::abs(a_actual - a_expected) <= a_tolerance, a_message);
    }

    DNT::Parchment::Request CollegeRequest()
    {
        DNT::Parchment::Request request{
            .requestId = "wizard-1",
            .providerId = "college",
            .texturePath = "Data/textures/dungeons/imperial/battlemap01.dds",
            .artAspectRatio = CollegeArtAspect,
            .textureUvMinX = 0.0F,
            .textureUvMinY = 0.0F,
            .textureUvMaxX = 1.0F,
            .textureUvMaxY = 0.736328F,
            .destinations = {}
        };
        std::string error;
        Require(DNT::Parchment::SetRouteOrigin(
            request,
            { 0.752F, 0.167F },
            error), "college route origin should validate");
        const DNT::Parchment::Destination destinations[]{
            { "whiterun", "Whiterun", 250, 0.554F, 0.507F },
            { "riften", "Riften", 250, 0.921F, 0.806F },
            { "solitude", "Solitude", 250, 0.330F, 0.150F },
            { "windhelm", "Windhelm", 250, 0.812F, 0.372F },
            { "markarth", "Markarth", 250, 0.079F, 0.474F },
        };
        for (const auto& destination : destinations) {
            Require(DNT::Parchment::AddDestination(request, destination, error), "college destination should validate");
        }
        return request;
    }

    void TestRequestValidation()
    {
        auto request = CollegeRequest();
        std::string error;
        Require(DNT::Parchment::ValidateReadyRequest(request, error), "college request should be ready");
        Require(request.destinations.size() == 5, "college request should contain five destinations");
        Require(request.routeOrigin.has_value(), "college request should define a route origin");

        Require(!DNT::Parchment::SetRouteOrigin(
            request,
            { 0.5F, 0.5F },
            error), "route origin may only be set once");

        auto invalidOrigin = CollegeRequest();
        invalidOrigin.routeOrigin = DNT::Parchment::RouteOrigin{ 1.1F, 0.5F };
        Require(!DNT::Parchment::ValidateReadyRequest(invalidOrigin, error), "out-of-range route origin must fail");

        Require(!DNT::Parchment::AddDestination(
            request,
            { "whiterun", "Duplicate", 250, 0.5F, 0.5F },
            error), "duplicate destination IDs must fail");
        Require(!DNT::Parchment::AddDestination(
            request,
            { "outside", "Outside", 250, 1.1F, 0.5F },
            error), "out-of-range coordinates must fail");
        Require(!DNT::Parchment::IsValidIdentifier("bad|event|payload"), "event delimiters must not be valid identifiers");

        auto invalidCrop = CollegeRequest();
        invalidCrop.textureUvMaxY = invalidCrop.textureUvMinY;
        Require(!DNT::Parchment::ValidateReadyRequest(invalidCrop, error), "empty texture crop must fail");

        auto outsideCrop = CollegeRequest();
        outsideCrop.textureUvMaxX = 1.1F;
        Require(!DNT::Parchment::ValidateReadyRequest(outsideCrop, error), "out-of-range texture crop must fail");

        DNT::Parchment::Request trimmedRequest{
            .requestId = "trim-1",
            .providerId = "college",
            .texturePath = "",
            .artAspectRatio = 1.5F,
            .destinations = {}
        };
        Require(DNT::Parchment::AddDestination(
            trimmedRequest,
            { "whiterun", "Whiterun ", 250, 0.5F, 0.5F },
            error), "presentation labels with a disambiguating trailing space should validate");
        Require(trimmedRequest.destinations[0].label == "Whiterun", "native boundary must trim presentation labels");
    }

    void CheckLayout(const float a_width, const float a_height, const float a_aspect)
    {
        const auto layout = DNT::Parchment::ComputeLayout(a_width, a_height, a_aspect);
        Require(layout.left >= 0.0F && layout.top >= 0.0F, "layout must start inside the viewport");
        Require(layout.left + layout.width <= a_width + 0.01F, "layout must fit viewport width");
        Require(layout.top + layout.height <= a_height + 0.01F, "layout must fit viewport height");
        RequireClose(layout.width / layout.height, a_aspect, 0.001F, "layout must preserve art aspect ratio");
        Require(layout.markerWidth > 0.0F && layout.markerHeight > 0.0F, "markers must have usable dimensions");
    }

    void TestAspectSafeLayouts()
    {
        CheckLayout(1920.0F, 1080.0F, CollegeArtAspect);
        CheckLayout(3440.0F, 1440.0F, CollegeArtAspect);
        CheckLayout(5120.0F, 1440.0F, CollegeArtAspect);

        const auto ultraWide = DNT::Parchment::ComputeLayout(5120.0F, 1440.0F, CollegeArtAspect);
        RequireClose(ultraWide.left, (5120.0F - ultraWide.width) * 0.5F, 0.001F, "32:9 map must remain centered");
        Require(ultraWide.width < 5120.0F * 0.5F, "32:9 layout should use a centered safe canvas instead of stretching");

        const auto portraitArt = DNT::Parchment::ComputeLayout(1920.0F, 1080.0F, 0.8F);
        RequireClose(portraitArt.width / portraitArt.height, 0.8F, 0.001F, "provider-specific portrait art must be supported");
    }

    void TestMarkerCentersRemainOnArt()
    {
        const auto request = CollegeRequest();
        const auto layout = DNT::Parchment::ComputeLayout(5120.0F, 1440.0F, request.artAspectRatio);
        for (const auto& destination : request.destinations) {
            const auto x = layout.left + destination.normalizedX * layout.width;
            const auto y = layout.top + destination.normalizedY * layout.height;
            Require(x >= layout.left && x <= layout.left + layout.width, "marker x must remain on the artwork");
            Require(y >= layout.top && y <= layout.top + layout.height, "marker y must remain on the artwork");
        }
    }
}

int main()
{
    TestRequestValidation();
    TestAspectSafeLayouts();
    TestMarkerCentersRemainOnArt();
    std::cout << "DNTParchmentCoreTests: all checks passed\n";
    return EXIT_SUCCESS;
}
