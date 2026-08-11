#include "DNT/ParchmentCore.h"

#include <cmath>
#include <cstdlib>
#include <iostream>
#include <string>
#include <utility>

namespace
{
    constexpr float CollegeArtAspect = 1.414075F;

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
            .texturePath = "Data/textures/terrain/tamriel/skyrim.dds",
            .artAspectRatio = CollegeArtAspect,
            .textureUvMinX = 0.088379F,
            .textureUvMinY = 0.187012F,
            .textureUvMaxX = 0.932129F,
            .textureUvMaxY = 0.783691F,
            .destinations = {}
        };
        std::string error;
        Require(DNT::Parchment::SetMarkerTextures(
            request,
            "Data/textures/DiegeticTravel/norden-town.dds",
            "Data/textures/DiegeticTravel/norden-town.dds",
            error), "college marker theme should validate");
        Require(DNT::Parchment::SetOriginMarkerTexture(
            request,
            "Data/textures/DiegeticTravel/norden-winterhold-capital.dds",
            error), "college origin marker should validate");
        Require(DNT::Parchment::SetSelectionRingTexture(
            request,
            "Data/textures/DiegeticTravel/norden-roundtrip-selection-ring.dds",
            error), "college selection ring should validate");
        Require(DNT::Parchment::SetSourceLabel(
            request,
            "College of Winterhold",
            error), "college source label should validate");
        Require(DNT::Parchment::SetPaymentLabelPosition(
            request,
            { 0.616470F, 0.924230F },
            error), "college payment label position should validate");
        Require(DNT::Parchment::SetRouteOrigin(
            request,
            { 0.750802F, 0.167836F },
            error), "college route origin should validate");
        const std::pair<DNT::Parchment::Destination, const char*> destinations[]{
            { { "whiterun", "Whiterun", 250, 0.532756F, 0.548290F }, "norden-whiterun-capital.dds" },
            { { "riften", "Riften", 250, 0.880078F, 0.833512F }, "norden-riften-capital.dds" },
            { { "solitude", "Solitude", 250, 0.365471F, 0.191247F }, "norden-solitude-capital.dds" },
            { { "windhelm", "Windhelm", 250, 0.793249F, 0.410699F }, "norden-windhelm-capital.dds" },
            { { "markarth", "Markarth", 250, 0.094238F, 0.507741F }, "norden-markarth-capital.dds" },
            { { "dawnstar", "Dawnstar", 250, 0.557529F, 0.185081F }, "norden-dawnstar-capital.dds" },
            { { "morthal", "Morthal", 250, 0.400452F, 0.311110F }, "norden-morthal-capital.dds" },
        };
        for (const auto& [destination, markerFile] : destinations) {
            Require(DNT::Parchment::AddDestination(request, destination, error), "college destination should validate");
            Require(DNT::Parchment::SetDestinationMarkerTexture(
                request,
                destination.id,
                std::string("Data/textures/DiegeticTravel/") + markerFile,
                error), "college destination marker should validate");
        }
        return request;
    }

    void TestRequestValidation()
    {
        auto request = CollegeRequest();
        std::string error;
        Require(DNT::Parchment::ValidateReadyRequest(request, error), "college request should be ready");
        Require(request.destinations.size() == 7, "college request should contain seven destinations");
        Require(request.sourceLabel == "College of Winterhold", "college request should retain its source label");
        Require(request.routeOrigin.has_value(), "college request should define a route origin");
        Require(request.paymentLabelPosition.has_value(), "college request should define a payment label position");
        Require(request.idleMarkerTexturePath ==
            "Data/textures/DiegeticTravel/norden-town.dds",
            "college request should retain its idle marker texture");
        Require(request.selectedMarkerTexturePath ==
            "Data/textures/DiegeticTravel/norden-town.dds",
            "college request should use the generic hold marker only as a selection fallback");
        Require(request.originMarkerTexturePath ==
            "Data/textures/DiegeticTravel/norden-winterhold-capital.dds",
            "college request should retain its distinct origin marker texture");
        Require(request.selectionRingTexturePath ==
            "Data/textures/DiegeticTravel/norden-roundtrip-selection-ring.dds",
            "college request should retain its round-trip selection ring");
        RequireClose(request.selectionRingScale, 2.0F, 0.0001F,
            "college request should default to the established global ring scale");
        Require(request.destinations[0].idleMarkerTexturePath ==
            "Data/textures/DiegeticTravel/norden-whiterun-capital.dds",
            "each college destination should retain its neutral city marker");
        Require(DNT::Parchment::AddDestination(
            request,
            {
                .id = "styled_stop",
                .label = "Styled Stop",
                .fare = 50,
                .normalizedX = 0.25F,
                .normalizedY = 0.75F,
                .idleMarkerTexturePath = "Data/textures/DiegeticTravel/norden-town.dds",
                .markerScale = 0.8F,
                .selectionRingOffsetX = 0.02F,
                .selectionRingOffsetY = 0.15F,
                .selectionRingScale = 1.0F,
            },
            error), "fully styled destinations should validate atomically");
        Require(request.destinations.back().idleMarkerTexturePath ==
            "Data/textures/DiegeticTravel/norden-town.dds",
            "styled destinations should retain their marker texture");
        Require(!DNT::Parchment::AddDestination(
            request,
            {
                .id = "invalid_styled_stop",
                .label = "Invalid Styled Stop",
                .fare = 50,
                .normalizedX = 0.25F,
                .normalizedY = 0.75F,
                .idleMarkerTexturePath = "Data/textures/DiegeticTravel/norden-town.dds",
                .markerScale = 0.8F,
                .selectionRingOffsetX = 1.1F,
                .selectionRingOffsetY = 0.0F,
                .selectionRingScale = 1.0F,
            },
            error), "atomic styled destinations should reject invalid ring optics");
        Require(!DNT::Parchment::SetDestinationMarkerTexture(
            request,
            "whiterun",
            "Data/textures/DiegeticTravel/duplicate.dds",
            error), "destination marker textures may only be set once");
        Require(!DNT::Parchment::SetDestinationMarkerTexture(
            request,
            "missing",
            "Data/textures/DiegeticTravel/missing.dds",
            error), "destination marker textures must target an existing destination");

        Require(!DNT::Parchment::SetMarkerTextures(
            request,
            "Data/textures/DiegeticTravel/docks-marker.dds",
            "Data/textures/DiegeticTravel/shipwreck-marker.dds",
            error), "marker textures may only be set once");

        Require(!DNT::Parchment::SetOriginMarkerTexture(
            request,
            "Data/textures/DiegeticTravel/docks-marker.dds",
            error), "origin marker texture may only be set once");

        Require(!DNT::Parchment::SetSelectionRingTexture(
            request,
            "Data/textures/DiegeticTravel/duplicate-ring.dds",
            error), "selection-ring texture may only be set once");

        Require(DNT::Parchment::SetSelectionRingScale(
            request,
            2.25F,
            error), "selection-ring scale should accept a bounded global multiplier");
        RequireClose(request.selectionRingScale, 2.25F, 0.0001F,
            "selection-ring scale should be retained");
        Require(!DNT::Parchment::SetSelectionRingScale(
            request,
            4.1F,
            error), "selection-ring scale should reject oversized values");

        Require(DNT::Parchment::SetDestinationMarkerScale(
            request,
            "whiterun",
            1.2F,
            error), "destination marker scale should accept a bounded multiplier");
        RequireClose(request.destinations[0].markerScale, 1.2F, 0.0001F,
            "destination marker scale should be retained");
        Require(!DNT::Parchment::SetDestinationMarkerScale(
            request,
            "missing",
            1.0F,
            error), "destination marker scale must target an existing destination");
        Require(!DNT::Parchment::SetDestinationMarkerScale(
            request,
            "whiterun",
            2.1F,
            error), "destination marker scale should reject oversized values");

        Require(DNT::Parchment::SetDestinationSelectionRingStyle(
            request,
            "whiterun",
            0.12F,
            -0.08F,
            1.15F,
            error), "destination selection-ring optics should validate");
        RequireClose(request.destinations[0].selectionRingOffsetX, 0.12F, 0.0001F,
            "destination ring X offset should be retained");
        RequireClose(request.destinations[0].selectionRingOffsetY, -0.08F, 0.0001F,
            "destination ring Y offset should be retained");
        RequireClose(request.destinations[0].selectionRingScale, 1.15F, 0.0001F,
            "destination ring scale should be retained");
        Require(!DNT::Parchment::SetDestinationSelectionRingStyle(
            request,
            "missing",
            0.0F,
            0.0F,
            1.0F,
            error), "destination ring optics must target an existing destination");
        Require(!DNT::Parchment::SetDestinationSelectionRingStyle(
            request,
            "whiterun",
            1.1F,
            0.0F,
            1.0F,
            error), "destination ring optics should reject out-of-range offsets");

        Require(DNT::Parchment::SetDestinationSelectionRingTexture(
            request,
            "whiterun",
            "Data/textures/DiegeticTravel/norden-oneway-selection-ring.dds",
            error), "destination selection-ring texture should validate");
        Require(request.destinations[0].selectionRingTexturePath ==
            "Data/textures/DiegeticTravel/norden-oneway-selection-ring.dds",
            "destination selection-ring texture should be retained");
        Require(!DNT::Parchment::SetDestinationSelectionRingTexture(
            request,
            "whiterun",
            "Data/textures/DiegeticTravel/duplicate-oneway-ring.dds",
            error), "destination selection-ring texture may only be set once");
        Require(!DNT::Parchment::SetDestinationSelectionRingTexture(
            request,
            "missing",
            "Data/textures/DiegeticTravel/missing-oneway-ring.dds",
            error), "destination selection-ring texture must target an existing destination");

        Require(!DNT::Parchment::SetSourceLabel(
            request,
            "Winterhold",
            error), "source label may only be set once");

        Require(!DNT::Parchment::SetPaymentLabelPosition(
            request,
            { 0.5F, 0.9F },
            error), "payment label position may only be set once");

        Require(!DNT::Parchment::SetRouteOrigin(
            request,
            { 0.5F, 0.5F },
            error), "route origin may only be set once");

        auto invalidOrigin = CollegeRequest();
        invalidOrigin.routeOrigin = DNT::Parchment::RouteOrigin{ 1.1F, 0.5F };
        Require(!DNT::Parchment::ValidateReadyRequest(invalidOrigin, error), "out-of-range route origin must fail");

        auto invalidPaymentLabel = CollegeRequest();
        invalidPaymentLabel.paymentLabelPosition = DNT::Parchment::RoutePoint{ 0.5F, 1.1F };
        Require(!DNT::Parchment::ValidateReadyRequest(
            invalidPaymentLabel,
            error), "out-of-range payment label position must fail");

        auto invalidDestinationMarkerScale = CollegeRequest();
        invalidDestinationMarkerScale.destinations[0].markerScale = 0.49F;
        Require(!DNT::Parchment::ValidateReadyRequest(
            invalidDestinationMarkerScale,
            error), "out-of-range destination marker scale must fail ready validation");

        auto missingSourceLabel = CollegeRequest();
        missingSourceLabel.sourceLabel.clear();
        Require(!DNT::Parchment::ValidateReadyRequest(
            missingSourceLabel,
            error), "ready requests must identify their origin");

        Require(!DNT::Parchment::AddDestination(
            request,
            { "whiterun", "Duplicate", 250, 0.5F, 0.5F },
            error), "duplicate destination IDs must fail");
        Require(!DNT::Parchment::AddDestination(
            request,
            { "outside", "Outside", 250, 1.1F, 0.5F },
            error), "out-of-range coordinates must fail");
        Require(!DNT::Parchment::IsValidIdentifier("bad|event|payload"), "event delimiters must not be valid identifiers");

        Require(DNT::Parchment::AddRouteLandmark(
            request,
            { 0.25F, 0.75F },
            error), "inactive route landmark should validate");
        Require(!DNT::Parchment::AddRouteLandmark(
            request,
            { 0.25F, 0.75F },
            error), "duplicate inactive route landmarks must fail");
        Require(!DNT::Parchment::AddRouteLandmark(
            request,
            { -0.1F, 0.75F },
            error), "out-of-range route landmarks must fail");

        auto invalidCrop = CollegeRequest();
        invalidCrop.textureUvMaxY = invalidCrop.textureUvMinY;
        Require(!DNT::Parchment::ValidateReadyRequest(invalidCrop, error), "empty texture crop must fail");

        auto outsideCrop = CollegeRequest();
        outsideCrop.textureUvMaxX = 1.1F;
        Require(!DNT::Parchment::ValidateReadyRequest(outsideCrop, error), "out-of-range texture crop must fail");

        auto incompleteMarkerTheme = CollegeRequest();
        incompleteMarkerTheme.selectedMarkerTexturePath.clear();
        Require(!DNT::Parchment::ValidateReadyRequest(
            incompleteMarkerTheme,
            error), "marker texture paths must be supplied as a pair");

        auto oversizedMarkerTheme = CollegeRequest();
        oversizedMarkerTheme.idleMarkerTexturePath.assign(513, 'x');
        oversizedMarkerTheme.selectedMarkerTexturePath.assign(513, 'x');
        Require(!DNT::Parchment::ValidateReadyRequest(
            oversizedMarkerTheme,
            error), "oversized marker texture paths must fail");

        auto oversizedSelectionRing = CollegeRequest();
        oversizedSelectionRing.selectionRingTexturePath.assign(513, 'x');
        Require(!DNT::Parchment::ValidateReadyRequest(
            oversizedSelectionRing,
            error), "oversized selection-ring paths must fail");

        auto oversizedDestinationMarker = CollegeRequest();
        oversizedDestinationMarker.destinations[0].idleMarkerTexturePath.assign(513, 'x');
        Require(!DNT::Parchment::ValidateReadyRequest(
            oversizedDestinationMarker,
            error), "oversized destination marker texture paths must fail");

        auto oversizedDestinationRing = CollegeRequest();
        oversizedDestinationRing.destinations[0].selectionRingTexturePath.assign(513, 'x');
        Require(!DNT::Parchment::ValidateReadyRequest(
            oversizedDestinationRing,
            error), "oversized destination selection-ring texture paths must fail");

        DNT::Parchment::Request trimmedRequest{
            .requestId = "trim-1",
            .providerId = "college",
            .texturePath = "",
            .artAspectRatio = 1.5F,
            .destinations = {}
        };
        Require(DNT::Parchment::SetSourceLabel(
            trimmedRequest,
            "  Winterhold  ",
            error), "source labels with surrounding whitespace should validate");
        Require(trimmedRequest.sourceLabel == "Winterhold", "native boundary must trim source labels");
        Require(DNT::Parchment::AddDestination(
            trimmedRequest,
            { "whiterun", "Whiterun ", 250, 0.5F, 0.5F },
            error), "presentation labels with a disambiguating trailing space should validate");
        Require(trimmedRequest.destinations[0].label == "Whiterun", "native boundary must trim presentation labels");
    }

    void TestExplicitRouteNetwork()
    {
        DNT::Parchment::Request request{
            .requestId = "boat-1",
            .providerId = "boat",
            .texturePath = "",
            .artAspectRatio = 1.5F,
            .destinations = {}
        };
        std::string error;
        Require(DNT::Parchment::SetSourceLabel(
            request,
            "West Ferry",
            error), "boat source label should validate");
        Require(DNT::Parchment::SetRouteOrigin(request, { 0.1F, 0.5F }, error), "boat origin should validate");
        Require(DNT::Parchment::SetOverlayTexture(
            request,
            "Data/textures/DiegeticTravel/boat-route-chalk-overlay.dds",
            error), "boat route overlay should validate");
        Require(!DNT::Parchment::SetOverlayTexture(
            request,
            "Data/textures/DiegeticTravel/second-overlay.dds",
            error), "a request may only define one route overlay");
        Require(DNT::Parchment::AddDestination(
            request,
            { "east_port", "East Port", 50, 0.9F, 0.5F },
            error), "boat destination should validate");
        Require(DNT::Parchment::AddRouteLandmark(
            request,
            { 0.2F, 0.8F },
            error), "inactive network landmark should validate");
        Require(DNT::Parchment::AddRouteSegment(
            request,
            { { 0.1F, 0.5F }, { 0.4F, 0.2F } },
            error), "first water lane should validate");
        Require(DNT::Parchment::AddRouteSegment(
            request,
            { { 0.4F, 0.2F }, { 0.7F, 0.2F } },
            error), "second water lane should validate");
        Require(DNT::Parchment::AddRouteSegment(
            request,
            { { 0.7F, 0.2F }, { 0.9F, 0.5F } },
            error), "third water lane should validate");
        Require(DNT::Parchment::ValidateReadyRequest(request, error), "connected route network should be ready");
        Require(request.routeLandmarks.size() == 1, "boat request should retain its inactive landmark");
        const auto path = DNT::Parchment::FindRoutePath(request, request.destinations[0]);
        Require(path.size() == 4, "water lane should resolve through its two bends");
        RequireClose(path[1].normalizedX, 0.4F, 0.0001F, "first bend should be preserved");

        Require(!DNT::Parchment::AddRouteSegment(
            request,
            { { 0.4F, 0.2F }, { 0.1F, 0.5F } },
            error), "reversed duplicate route segment must fail");
        Require(!DNT::Parchment::AddRouteSegment(
            request,
            { { 0.3F, 0.3F }, { 0.3F, 0.3F } },
            error), "zero-length route segment must fail");

        auto disconnected = request;
        disconnected.destinations.push_back({ "island", "Island", 50, 0.8F, 0.8F });
        Require(!DNT::Parchment::ValidateReadyRequest(
            disconnected,
            error), "disconnected destination must fail ready validation");
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

    void TestDestinationHitAreasDoNotOverlap()
    {
        const auto request = CollegeRequest();
        const auto layout = DNT::Parchment::ComputeLayout(5120.0F, 1440.0F, request.artAspectRatio);
        const auto sizes = DNT::Parchment::ComputeDestinationHitSizes(request, layout);
        Require(sizes.size() == request.destinations.size(), "every destination needs one hit size");
        for (std::size_t index = 0; index < sizes.size(); ++index) {
            Require(sizes[index] > 0.0F, "destination hit areas must remain usable");
            for (std::size_t otherIndex = index + 1; otherIndex < sizes.size(); ++otherIndex) {
                const auto& destination = request.destinations[index];
                const auto& other = request.destinations[otherIndex];
                const auto horizontal = std::abs(
                    destination.normalizedX - other.normalizedX) * layout.width;
                const auto vertical = std::abs(
                    destination.normalizedY - other.normalizedY) * layout.height;
                const auto requiredSeparation = (sizes[index] + sizes[otherIndex]) * 0.5F;
                Require(
                    horizontal >= requiredSeparation || vertical >= requiredSeparation,
                    "destination hit-area squares must not overlap");
            }
        }

        auto oneDestination = CollegeRequest();
        oneDestination.destinations.resize(1);
        const auto singleSize = DNT::Parchment::ComputeDestinationHitSizes(oneDestination, layout);
        Require(singleSize.size() == 1 && singleSize[0] >= 84.0F,
            "a lone destination should receive the preferred enlarged hit area");
    }

    void TestDestinationCapacitySupportsFullCarriageSheet()
    {
        DNT::Parchment::Request request{
            .requestId = "carriage-capacity",
            .providerId = "carriage",
            .sourceLabel = "Winterhold",
            .texturePath = "",
            .artAspectRatio = 1.5F,
            .destinations = {}
        };
        std::string error;

        for (std::size_t index = 0; index < DNT::Parchment::MaxDestinations; ++index) {
            Require(DNT::Parchment::AddDestination(
                request,
                { "stop_" + std::to_string(index), "Stop " + std::to_string(index), 50, 0.5F, 0.5F },
                error), "the bounded request must accept the full carriage destination capacity");
        }

        Require(!DNT::Parchment::AddDestination(
            request,
            { "one_too_many", "One Too Many", 50, 0.5F, 0.5F },
            error), "the bounded request must still reject destinations beyond its capacity");
        Require(error == "destination limit exceeded", "capacity rejection should explain the limit");
    }

    void TestDirectionalDestinationNavigation()
    {
        DNT::Parchment::Request request{
            .requestId = "controller-navigation",
            .providerId = "carriage",
            .sourceLabel = "Dawnstar",
            .texturePath = "Data/textures/DiegeticTravel/map.dds",
            .artAspectRatio = 1.5F,
            .destinations = {
                { "left", "Left", 50, 0.10F, 0.50F },
                { "center", "Center", 50, 0.50F, 0.50F },
                { "right", "Right", 50, 0.90F, 0.50F },
                { "upper", "Upper", 50, 0.50F, 0.10F },
                { "lower", "Lower", 50, 0.50F, 0.90F }
            }
        };

        const auto enterFromLeft = DNT::Parchment::FindDirectionalDestination(
            request, std::nullopt, 1.0F, 0.0F);
        Require(enterFromLeft && *enterFromLeft == 0,
            "first right press should enter from the left edge without a default focus");

        const auto moveRight = DNT::Parchment::FindDirectionalDestination(
            request, enterFromLeft, 1.0F, 0.0F);
        Require(moveRight && *moveRight == 1,
            "right navigation should choose the nearest aligned destination");

        const auto moveDown = DNT::Parchment::FindDirectionalDestination(
            request, moveRight, 0.0F, 1.0F);
        Require(moveDown && *moveDown == 4,
            "down navigation should follow normalized map coordinates");

        const auto noDestinationBelow = DNT::Parchment::FindDirectionalDestination(
            request, moveDown, 0.0F, 1.0F);
        Require(!noDestinationBelow,
            "directional navigation should stop at a map edge instead of wrapping unexpectedly");

        Require(!DNT::Parchment::FindDirectionalDestination(
            request, std::nullopt, 0.0F, 0.0F),
            "zero-length navigation input must be ignored");
    }

    void TestPresentationValidation()
    {
        constexpr float mirabelleDuration = 2.147846F;
        DNT::Parchment::Presentation presentation{
            .voicePath = "Voice/Skyrim.esm/FemaleUniqueMirabelleErvine/mg01__000d67d1_1.fuz",
            .subtitle = "Very good. Then we're done here.",
            .voiceDurationSeconds = mirabelleDuration
        };
        std::string error;
        Require(DNT::Parchment::ValidatePresentation(
            presentation,
            error), "the measured Mirabelle presentation should validate");
        RequireClose(
            DNT::Parchment::PresentationWindowSeconds(presentation.voiceDurationSeconds),
            mirabelleDuration + DNT::Parchment::PresentationTaskMarginSeconds,
            0.0001F,
            "presentation window should add only the documented task margin");

        auto injection = presentation;
        injection.voicePath = "Voice/Skyrim.esm/FemaleUnique/test.fuz\"; quit";
        Require(!DNT::Parchment::ValidatePresentation(
            injection,
            error), "console-command delimiters must fail voice-path validation");

        auto traversal = presentation;
        traversal.voicePath = "Voice/Skyrim.esm/../test.fuz";
        Require(!DNT::Parchment::ValidatePresentation(
            traversal,
            error), "parent traversal must fail voice-path validation");

        auto wrongRoot = presentation;
        wrongRoot.voicePath = "Sound/Skyrim.esm/test.fuz";
        Require(!DNT::Parchment::ValidatePresentation(
            wrongRoot,
            error), "presentation paths outside Voice must fail");

        auto controlSubtitle = presentation;
        controlSubtitle.subtitle = "Unsafe\nsubtitle";
        Require(!DNT::Parchment::ValidatePresentation(
            controlSubtitle,
            error), "subtitle control characters must fail");

        auto invalidDuration = presentation;
        invalidDuration.voiceDurationSeconds = 0.0F;
        Require(!DNT::Parchment::ValidatePresentation(
            invalidDuration,
            error), "zero-duration presentations must fail");
    }
}

int main()
{
    TestRequestValidation();
    TestExplicitRouteNetwork();
    TestAspectSafeLayouts();
    TestMarkerCentersRemainOnArt();
    TestDestinationHitAreasDoNotOverlap();
    TestDestinationCapacitySupportsFullCarriageSheet();
    TestDirectionalDestinationNavigation();
    TestPresentationValidation();
    std::cout << "DNTParchmentCoreTests: all checks passed\n";
    return EXIT_SUCCESS;
}
