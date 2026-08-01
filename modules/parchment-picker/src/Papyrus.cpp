#include "DNT/Papyrus.h"

#include "DNT/ParchmentMenu.h"

namespace
{
    constexpr std::string_view PapyrusClass = "DNT_ParchmentNative";

    bool IsAvailable(RE::StaticFunctionTag*)
    {
        return DNT::ParchmentMenu::IsAvailable();
    }

    bool BeginRequest(
        RE::StaticFunctionTag*,
        const RE::BSFixedString a_requestId,
        const RE::BSFixedString a_providerId,
        RE::TESObjectREFR* a_source,
        const RE::BSFixedString a_texturePath,
        const float a_artAspectRatio,
        const float a_textureUvMinX,
        const float a_textureUvMinY,
        const float a_textureUvMaxX,
        const float a_textureUvMaxY)
    {
        return DNT::ParchmentMenu::BeginRequest(
            a_requestId.c_str(),
            a_providerId.c_str(),
            a_source,
            a_texturePath.c_str(),
            a_artAspectRatio,
            a_textureUvMinX,
            a_textureUvMinY,
            a_textureUvMaxX,
            a_textureUvMaxY);
    }

    bool AddDestination(
        RE::StaticFunctionTag*,
        const RE::BSFixedString a_requestId,
        const RE::BSFixedString a_destinationId,
        const RE::BSFixedString a_label,
        const std::int32_t a_fare,
        const float a_normalizedX,
        const float a_normalizedY)
    {
        return DNT::ParchmentMenu::AddDestination(
            a_requestId.c_str(),
            a_destinationId.c_str(),
            a_label.c_str(),
            a_fare,
            a_normalizedX,
            a_normalizedY);
    }

    bool SetRouteOrigin(
        RE::StaticFunctionTag*,
        const RE::BSFixedString a_requestId,
        const float a_normalizedX,
        const float a_normalizedY)
    {
        return DNT::ParchmentMenu::SetRouteOrigin(
            a_requestId.c_str(),
            a_normalizedX,
            a_normalizedY);
    }

    bool Show(RE::StaticFunctionTag*, const RE::BSFixedString a_requestId)
    {
        return DNT::ParchmentMenu::Show(a_requestId.c_str());
    }

    bool Cancel(RE::StaticFunctionTag*, const RE::BSFixedString a_requestId)
    {
        return DNT::ParchmentMenu::Cancel(a_requestId.c_str());
    }
}

bool DNT::Papyrus::Register(RE::BSScript::IVirtualMachine* a_vm)
{
    a_vm->RegisterFunction("IsAvailable", PapyrusClass, IsAvailable);
    a_vm->RegisterFunction("BeginRequest", PapyrusClass, BeginRequest);
    a_vm->RegisterFunction("SetRouteOrigin", PapyrusClass, SetRouteOrigin);
    a_vm->RegisterFunction("AddDestination", PapyrusClass, AddDestination);
    a_vm->RegisterFunction("Show", PapyrusClass, Show);
    a_vm->RegisterFunction("Cancel", PapyrusClass, Cancel);
    return true;
}
