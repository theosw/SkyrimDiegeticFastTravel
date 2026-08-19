#include "DNT/MenuFrameworkAPI.h"

#include <filesystem>
#include <string>

DNT::MenuFramework::API& DNT::MenuFramework::API::GetSingleton()
{
    static API singleton;
    return singleton;
}

bool DNT::MenuFramework::API::Resolve()
{
    if (IsReady()) {
        return true;
    }

    module_ = GetModuleHandleW(L"SKSEMenuFramework.dll");
    if (!module_) {
        module_ = GetModuleHandleW(L"SKSEMenuFramework");
    }
    if (!module_) {
        return false;
    }

    addWindow_ = ResolveFunction<AddWindowFn>("AddWindow");
    addInputEvent_ = ResolveFunction<AddInputEventFn>("RegisterInpoutEvent");
    loadTexture_ = ResolveFunction<LoadTextureFn>("LoadTexture");
    disposeTexture_ = ResolveFunction<DisposeTextureFn>("DisposeTexture");
    getVersion_ = ResolveFunction<VersionFn>("GetMenuFrameworkVersion");
    setNextWindowPos_ = ResolveFunction<SetNextWindowPosFn>("igSetNextWindowPos");
    setNextWindowSize_ = ResolveFunction<SetNextWindowSizeFn>("igSetNextWindowSize");
    setNextWindowBgAlpha_ = ResolveFunction<SetNextWindowBgAlphaFn>("igSetNextWindowBgAlpha");
    begin_ = ResolveFunction<BeginFn>("igBegin");
    end_ = ResolveFunction<EndFn>("igEnd");
    setCursorScreenPos_ = ResolveFunction<SetCursorScreenPosFn>("igSetCursorScreenPos");
    getMousePos_ = ResolveFunction<GetMousePosFn>("igGetMousePos");
    setMouseCursor_ = ResolveFunction<SetMouseCursorFn>("igSetMouseCursor");
    image_ = ResolveFunction<ImageFn>("igImage");
    invisibleButton_ = ResolveFunction<InvisibleButtonFn>("igInvisibleButton");
    isItemHovered_ = ResolveFunction<ItemStateFn>("igIsItemHovered");
    isItemFocused_ = ResolveFunction<FocusedFn>("igIsItemFocused");
    pushStyleColor_ = ResolveFunction<PushStyleColorFn>("igPushStyleColor_U32");
    popStyleColor_ = ResolveFunction<PopStyleColorFn>("igPopStyleColor");
    setWindowFontScale_ = ResolveFunction<SetWindowFontScaleFn>("igSetWindowFontScale");
    calcTextSize_ = ResolveFunction<CalcTextSizeFn>("igCalcTextSize");
    textUnformatted_ = ResolveFunction<TextUnformattedFn>("igTextUnformatted");
    getForegroundDrawList_ = ResolveFunction<GetForegroundDrawListFn>("igGetForegroundDrawList_Nil");
    addLine_ = ResolveFunction<AddLineFn>("ImDrawList_AddLine");
    addImage_ = ResolveFunction<AddImageFn>("ImDrawList_AddImage");
    addPolyline_ = ResolveFunction<AddPolylineFn>("ImDrawList_AddPolyline");
    addConcavePolyFilled_ = ResolveFunction<AddConcavePolyFilledFn>("ImDrawList_AddConcavePolyFilled");
    addTriangleFilled_ = ResolveFunction<AddTriangleFilledFn>("ImDrawList_AddTriangleFilled");

    return IsReady();
}

bool DNT::MenuFramework::API::IsReady() const
{
    return module_ && addWindow_ && addInputEvent_ && loadTexture_ && disposeTexture_ &&
           setNextWindowPos_ && setNextWindowSize_ && setNextWindowBgAlpha_ && begin_ && end_ &&
           setCursorScreenPos_ && getMousePos_ && setMouseCursor_ && image_ &&
           invisibleButton_ && isItemHovered_ && isItemFocused_ &&
           pushStyleColor_ && popStyleColor_ && setWindowFontScale_ && calcTextSize_ && textUnformatted_ &&
           getForegroundDrawList_ && addLine_ && addImage_ && addPolyline_ &&
           addConcavePolyFilled_ && addTriangleFilled_;
}

float DNT::MenuFramework::API::Version() const
{
    return getVersion_ ? getVersion_() : 0.0F;
}

DNT::MenuFramework::Window* DNT::MenuFramework::API::AddWindow(const RenderCallback a_callback) const
{
    auto* window = addWindow_(a_callback);
    if (window) {
        window->blockUserInput = true;
    }
    return window;
}

std::int64_t DNT::MenuFramework::API::AddInputEvent(const InputCallback a_callback) const
{
    return addInputEvent_(a_callback);
}

DNT::MenuFramework::Texture DNT::MenuFramework::API::LoadTexture(const std::string_view a_path) const
{
    if (a_path.empty()) {
        return nullptr;
    }
    auto requestedSize = Vec2{};
    const auto path = std::string(a_path);
    return loadTexture_(path.c_str(), &requestedSize);
}

void DNT::MenuFramework::API::DisposeTexture(const std::string_view a_path) const
{
    if (!a_path.empty()) {
        const auto path = std::string(a_path);
        disposeTexture_(path.c_str());
    }
}

void DNT::MenuFramework::API::SetNextWindowPos(const Vec2 a_position) const
{
    setNextWindowPos_(a_position, 0, Vec2{});
}

void DNT::MenuFramework::API::SetNextWindowSize(const Vec2 a_size) const
{
    setNextWindowSize_(a_size, 0);
}

void DNT::MenuFramework::API::SetNextWindowBgAlpha(const float a_alpha) const
{
    setNextWindowBgAlpha_(a_alpha);
}

bool DNT::MenuFramework::API::Begin(const std::string_view a_name, const std::int32_t a_flags) const
{
    const auto name = std::string(a_name);
    return begin_(name.c_str(), nullptr, a_flags);
}

void DNT::MenuFramework::API::End() const
{
    end_();
}

void DNT::MenuFramework::API::SetCursorScreenPos(const Vec2 a_position) const
{
    setCursorScreenPos_(a_position);
}

DNT::MenuFramework::Vec2 DNT::MenuFramework::API::GetMousePos() const
{
    Vec2 position;
    getMousePos_(&position);
    return position;
}

void DNT::MenuFramework::API::SetMouseCursor(const std::int32_t a_cursor) const
{
    setMouseCursor_(a_cursor);
}

void DNT::MenuFramework::API::Image(
    const Texture a_texture,
    const Vec2 a_size,
    const Vec2 a_uv0,
    const Vec2 a_uv1,
    const Vec4 a_tint) const
{
    image_(a_texture, a_size, a_uv0, a_uv1, a_tint, Vec4{});
}

bool DNT::MenuFramework::API::InvisibleButton(
    const std::string_view a_label,
    const Vec2 a_size) const
{
    const auto label = std::string(a_label);
    return invisibleButton_(label.c_str(), a_size, 0);
}

bool DNT::MenuFramework::API::IsItemHovered() const
{
    return isItemHovered_(0);
}

bool DNT::MenuFramework::API::IsItemFocused() const
{
    return isItemFocused_();
}

void DNT::MenuFramework::API::PushStyleColor(
    const std::int32_t a_styleIndex,
    const Color a_color) const
{
    pushStyleColor_(a_styleIndex, a_color);
}

void DNT::MenuFramework::API::PopStyleColor(const std::int32_t a_count) const
{
    popStyleColor_(a_count);
}

void DNT::MenuFramework::API::SetWindowFontScale(const float a_scale) const
{
    setWindowFontScale_(a_scale);
}

DNT::MenuFramework::Vec2 DNT::MenuFramework::API::CalcTextSize(const std::string_view a_text) const
{
    const auto text = std::string(a_text);
    Vec2 size;
    calcTextSize_(&size, text.c_str(), nullptr, false, -1.0F);
    return size;
}

void DNT::MenuFramework::API::TextUnformatted(const std::string_view a_text) const
{
    const auto text = std::string(a_text);
    textUnformatted_(text.c_str(), nullptr);
}

DNT::MenuFramework::DrawList DNT::MenuFramework::API::GetForegroundDrawList() const
{
    return getForegroundDrawList_();
}

void DNT::MenuFramework::API::AddLine(
    const DrawList a_drawList,
    const Vec2 a_start,
    const Vec2 a_end,
    const Color a_color,
    const float a_thickness) const
{
    addLine_(a_drawList, a_start, a_end, a_color, a_thickness);
}

void DNT::MenuFramework::API::AddImage(
    const DrawList a_drawList,
    const Texture a_texture,
    const Vec2 a_min,
    const Vec2 a_max,
    const Vec2 a_uv0,
    const Vec2 a_uv1,
    const Color a_tint) const
{
    addImage_(a_drawList, a_texture, a_min, a_max, a_uv0, a_uv1, a_tint);
}

void DNT::MenuFramework::API::AddPolyline(
    const DrawList a_drawList,
    const Vec2* a_points,
    const std::int32_t a_pointCount,
    const Color a_color,
    const std::int32_t a_flags,
    const float a_thickness) const
{
    addPolyline_(a_drawList, a_points, a_pointCount, a_color, a_flags, a_thickness);
}

void DNT::MenuFramework::API::AddConcavePolyFilled(
    const DrawList a_drawList,
    const Vec2* a_points,
    const std::int32_t a_pointCount,
    const Color a_color) const
{
    addConcavePolyFilled_(a_drawList, a_points, a_pointCount, a_color);
}

void DNT::MenuFramework::API::AddTriangleFilled(
    const DrawList a_drawList,
    const Vec2 a_first,
    const Vec2 a_second,
    const Vec2 a_third,
    const Color a_color) const
{
    addTriangleFilled_(a_drawList, a_first, a_second, a_third, a_color);
}
