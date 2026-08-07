#pragma once

#include <RE/Skyrim.h>

#include <Windows.h>

#include <atomic>
#include <cstdint>
#include <string_view>

namespace DNT::MenuFramework
{
    struct Vec2
    {
        float x{ 0.0F };
        float y{ 0.0F };
    };

    struct Vec4
    {
        float x{ 0.0F };
        float y{ 0.0F };
        float z{ 0.0F };
        float w{ 0.0F };
    };

    using Texture = void*;
    using DrawList = void*;
    using Color = std::uint32_t;
    using RenderCallback = void(__stdcall*)();
    using InputCallback = bool(__stdcall*)(RE::InputEvent*);

    // This two-atomic layout is the public v3 WindowInterface contract.
    struct Window
    {
        std::atomic<bool> isOpen{ false };
        std::atomic<bool> blockUserInput{ true };
    };

    enum WindowFlags : std::int32_t
    {
        kNoTitleBar = 1 << 0,
        kNoResize = 1 << 1,
        kNoMove = 1 << 2,
        kNoScrollbar = 1 << 3,
        kNoCollapse = 1 << 5,
        kNoBackground = 1 << 7,
        kNoSavedSettings = 1 << 8,
        kNoDocking = 1 << 19,
    };

    class API
    {
    public:
        [[nodiscard]] static API& GetSingleton();

        [[nodiscard]] bool Resolve();
        [[nodiscard]] bool IsReady() const;
        [[nodiscard]] float Version() const;

        [[nodiscard]] Window* AddWindow(RenderCallback a_callback) const;
        [[nodiscard]] std::int64_t AddInputEvent(InputCallback a_callback) const;
        [[nodiscard]] Texture LoadTexture(std::string_view a_path) const;
        void DisposeTexture(std::string_view a_path) const;

        void SetNextWindowPos(Vec2 a_position) const;
        void SetNextWindowSize(Vec2 a_size) const;
        void SetNextWindowBgAlpha(float a_alpha) const;
        [[nodiscard]] bool Begin(std::string_view a_name, std::int32_t a_flags) const;
        void End() const;
        void SetCursorScreenPos(Vec2 a_position) const;
        [[nodiscard]] Vec2 GetMousePos() const;
        void SetMouseCursor(std::int32_t a_cursor) const;
        void Image(
            Texture a_texture,
            Vec2 a_size,
            Vec2 a_uv0 = Vec2{},
            Vec2 a_uv1 = Vec2{ 1.0F, 1.0F },
            Vec4 a_tint = Vec4{ 1.0F, 1.0F, 1.0F, 1.0F }) const;
        [[nodiscard]] bool Button(std::string_view a_label, Vec2 a_size) const;
        [[nodiscard]] bool InvisibleButton(std::string_view a_label, Vec2 a_size) const;
        void SetItemDefaultFocus() const;
        [[nodiscard]] bool IsItemHovered() const;
        [[nodiscard]] bool IsItemFocused() const;
        void PushStyleColor(std::int32_t a_styleIndex, Color a_color) const;
        void PopStyleColor(std::int32_t a_count = 1) const;
        void SetWindowFontScale(float a_scale) const;
        [[nodiscard]] Vec2 CalcTextSize(std::string_view a_text) const;
        void TextUnformatted(std::string_view a_text) const;
        [[nodiscard]] DrawList GetForegroundDrawList() const;
        void AddLine(DrawList a_drawList, Vec2 a_start, Vec2 a_end, Color a_color, float a_thickness) const;
        void AddImage(
            DrawList a_drawList,
            Texture a_texture,
            Vec2 a_min,
            Vec2 a_max,
            Vec2 a_uv0 = Vec2{},
            Vec2 a_uv1 = Vec2{ 1.0F, 1.0F },
            Color a_tint = 0xFFFFFFFFU) const;
        void AddPolyline(
            DrawList a_drawList,
            const Vec2* a_points,
            std::int32_t a_pointCount,
            Color a_color,
            std::int32_t a_flags,
            float a_thickness) const;
        void AddConcavePolyFilled(
            DrawList a_drawList,
            const Vec2* a_points,
            std::int32_t a_pointCount,
            Color a_color) const;
        void AddTriangle(
            DrawList a_drawList,
            Vec2 a_first,
            Vec2 a_second,
            Vec2 a_third,
            Color a_color,
            float a_thickness) const;
        void AddTriangleFilled(
            DrawList a_drawList,
            Vec2 a_first,
            Vec2 a_second,
            Vec2 a_third,
            Color a_color) const;
        void AddCircle(
            DrawList a_drawList,
            Vec2 a_center,
            float a_radius,
            Color a_color,
            std::int32_t a_segments,
            float a_thickness) const;
        void AddCircleFilled(
            DrawList a_drawList,
            Vec2 a_center,
            float a_radius,
            Color a_color,
            std::int32_t a_segments) const;

    private:
        template <class T>
        [[nodiscard]] T ResolveFunction(const char* a_name) const
        {
            return reinterpret_cast<T>(GetProcAddress(module_, a_name));
        }

        using AddWindowFn = Window* (*)(RenderCallback);
        using AddInputEventFn = std::int64_t (*)(InputCallback);
        using LoadTextureFn = Texture (*)(const char*, Vec2*);
        using DisposeTextureFn = void (*)(const char*);
        using VersionFn = float (*)();
        using SetNextWindowPosFn = void (*)(Vec2, std::int32_t, Vec2);
        using SetNextWindowSizeFn = void (*)(Vec2, std::int32_t);
        using SetNextWindowBgAlphaFn = void (*)(float);
        using BeginFn = bool (*)(const char*, bool*, std::int32_t);
        using EndFn = void (*)();
        using SetCursorScreenPosFn = void (*)(Vec2);
        using GetMousePosFn = void (*)(Vec2*);
        using SetMouseCursorFn = void (*)(std::int32_t);
        using ImageFn = void (*)(Texture, Vec2, Vec2, Vec2, Vec4, Vec4);
        using ButtonFn = bool (*)(const char*, Vec2);
        using InvisibleButtonFn = bool (*)(const char*, Vec2, std::int32_t);
        using ActionFn = void (*)();
        using ItemStateFn = bool (*)(std::int32_t);
        using FocusedFn = bool (*)();
        using PushStyleColorFn = void (*)(std::int32_t, Color);
        using PopStyleColorFn = void (*)(std::int32_t);
        using SetWindowFontScaleFn = void (*)(float);
        using CalcTextSizeFn = void (*)(Vec2*, const char*, const char*, bool, float);
        using TextUnformattedFn = void (*)(const char*, const char*);
        using GetForegroundDrawListFn = DrawList (*)();
        using AddLineFn = void (*)(DrawList, Vec2, Vec2, Color, float);
        using AddImageFn = void (*)(DrawList, Texture, Vec2, Vec2, Vec2, Vec2, Color);
        using AddPolylineFn = void (*)(DrawList, const Vec2*, std::int32_t, Color, std::int32_t, float);
        using AddConcavePolyFilledFn = void (*)(DrawList, const Vec2*, std::int32_t, Color);
        using AddTriangleFn = void (*)(DrawList, Vec2, Vec2, Vec2, Color, float);
        using AddTriangleFilledFn = void (*)(DrawList, Vec2, Vec2, Vec2, Color);
        using AddCircleFn = void (*)(DrawList, Vec2, float, Color, std::int32_t, float);
        using AddCircleFilledFn = void (*)(DrawList, Vec2, float, Color, std::int32_t);

        HMODULE module_{ nullptr };
        AddWindowFn addWindow_{ nullptr };
        AddInputEventFn addInputEvent_{ nullptr };
        LoadTextureFn loadTexture_{ nullptr };
        DisposeTextureFn disposeTexture_{ nullptr };
        VersionFn getVersion_{ nullptr };
        SetNextWindowPosFn setNextWindowPos_{ nullptr };
        SetNextWindowSizeFn setNextWindowSize_{ nullptr };
        SetNextWindowBgAlphaFn setNextWindowBgAlpha_{ nullptr };
        BeginFn begin_{ nullptr };
        EndFn end_{ nullptr };
        SetCursorScreenPosFn setCursorScreenPos_{ nullptr };
        GetMousePosFn getMousePos_{ nullptr };
        SetMouseCursorFn setMouseCursor_{ nullptr };
        ImageFn image_{ nullptr };
        ButtonFn button_{ nullptr };
        InvisibleButtonFn invisibleButton_{ nullptr };
        ActionFn setItemDefaultFocus_{ nullptr };
        ItemStateFn isItemHovered_{ nullptr };
        FocusedFn isItemFocused_{ nullptr };
        PushStyleColorFn pushStyleColor_{ nullptr };
        PopStyleColorFn popStyleColor_{ nullptr };
        SetWindowFontScaleFn setWindowFontScale_{ nullptr };
        CalcTextSizeFn calcTextSize_{ nullptr };
        TextUnformattedFn textUnformatted_{ nullptr };
        GetForegroundDrawListFn getForegroundDrawList_{ nullptr };
        AddLineFn addLine_{ nullptr };
        AddImageFn addImage_{ nullptr };
        AddPolylineFn addPolyline_{ nullptr };
        AddConcavePolyFilledFn addConcavePolyFilled_{ nullptr };
        AddTriangleFn addTriangle_{ nullptr };
        AddTriangleFilledFn addTriangleFilled_{ nullptr };
        AddCircleFn addCircle_{ nullptr };
        AddCircleFilledFn addCircleFilled_{ nullptr };
    };
}
