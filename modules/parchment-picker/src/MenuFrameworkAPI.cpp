#include "DNT/MenuFrameworkAPI.h"

#include <algorithm>
#include <cctype>
#include <filesystem>
#include <format>
#include <fstream>
#include <optional>
#include <string>
#include <vector>

namespace
{
    constexpr std::uint32_t MaxArchivedTextureBytes = 128U * 1024U * 1024U;

    [[nodiscard]] bool EqualsAsciiInsensitive(
        const std::string_view a_left,
        const std::string_view a_right)
    {
        if (a_left.size() != a_right.size()) {
            return false;
        }
        for (std::size_t index = 0; index < a_left.size(); ++index) {
            const auto left = static_cast<unsigned char>(a_left[index]);
            const auto right = static_cast<unsigned char>(a_right[index]);
            if (std::tolower(left) != std::tolower(right)) {
                return false;
            }
        }
        return true;
    }

    [[nodiscard]] std::optional<std::string> MaterializeArchivedTexture(
        const std::string_view a_logicalPath)
    {
        constexpr std::string_view dataPrefix = "Data/";
        constexpr std::string_view dataPrefixBackslash = "Data\\";
        constexpr std::string_view texturePrefix = "textures/";
        constexpr std::string_view texturePrefixBackslash = "textures\\";

        auto resourcePath = std::string(a_logicalPath);
        if (resourcePath.size() >= dataPrefix.size() &&
            (EqualsAsciiInsensitive(resourcePath.substr(0, dataPrefix.size()), dataPrefix) ||
             EqualsAsciiInsensitive(resourcePath.substr(0, dataPrefixBackslash.size()), dataPrefixBackslash))) {
            resourcePath.erase(0, dataPrefix.size());
        }
        if (resourcePath.size() < texturePrefix.size() ||
            (!EqualsAsciiInsensitive(resourcePath.substr(0, texturePrefix.size()), texturePrefix) &&
             !EqualsAsciiInsensitive(resourcePath.substr(0, texturePrefixBackslash.size()), texturePrefixBackslash)) ||
            resourcePath.find("..") != std::string::npos) {
            return std::nullopt;
        }
        std::ranges::replace(resourcePath, '/', '\\');
        auto extension = std::filesystem::path(resourcePath).extension().string();
        std::ranges::transform(extension, extension.begin(), [](const unsigned char a_character) {
            return static_cast<char>(std::tolower(a_character));
        });
        if (extension != ".dds") {
            return std::nullopt;
        }

        RE::BSResourceNiBinaryStream stream(resourcePath);
        if (!stream.good() || !stream.stream) {
            return std::nullopt;
        }
        const auto byteCount = stream.stream->totalSize;
        if (byteCount == 0 || byteCount > MaxArchivedTextureBytes) {
            logger::warn(
                "MENU_TEXTURE_ARCHIVE_REJECT logical={} resource={} bytes={}",
                a_logicalPath,
                resourcePath,
                byteCount);
            return std::nullopt;
        }

        std::error_code error;
        auto cacheRoot = std::filesystem::temp_directory_path(error);
        if (error) {
            return std::nullopt;
        }
        cacheRoot /= "DiegeticTravel";
        cacheRoot /= "texture-cache";
        std::filesystem::create_directories(cacheRoot, error);
        if (error) {
            return std::nullopt;
        }

        std::uint64_t pathHash = 14695981039346656037ULL;
        for (const auto character : resourcePath) {
            pathHash ^= static_cast<unsigned char>(std::tolower(static_cast<unsigned char>(character)));
            pathHash *= 1099511628211ULL;
        }
        const auto cachePath = cacheRoot /
            std::format(
                "v1-{:016x}-{}-{}",
                pathHash,
                byteCount,
                std::filesystem::path(resourcePath).filename().string());
        if (!std::filesystem::exists(cachePath, error) ||
            error || std::filesystem::file_size(cachePath, error) != byteCount) {
            error.clear();
            std::vector<std::uint8_t> bytes(byteCount);
            if (!stream.read(bytes.data(), byteCount)) {
                logger::warn(
                    "MENU_TEXTURE_ARCHIVE_READ_FAILED logical={} resource={} bytes={}",
                    a_logicalPath,
                    resourcePath,
                    byteCount);
                return std::nullopt;
            }
            std::ofstream output(cachePath, std::ios::binary | std::ios::trunc);
            if (!output) {
                return std::nullopt;
            }
            output.write(
                reinterpret_cast<const char*>(bytes.data()),
                static_cast<std::streamsize>(bytes.size()));
            output.close();
            if (!output) {
                return std::nullopt;
            }
        }

        logger::info(
            "MENU_TEXTURE_ARCHIVE_READY logical={} resource={} cache={} bytes={}",
            a_logicalPath,
            resourcePath,
            cachePath.string(),
            byteCount);
        return cachePath.string();
    }
}

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
    if (auto texture = loadTexture_(path.c_str(), &requestedSize)) {
        return texture;
    }

    // SKSE Menu Framework's texture loader only checks the real filesystem.
    // Skyrim's own resource stream sees loose winners and Bethesda archives,
    // so materialize an archived DDS into a stable temp cache when no loose
    // file exists. This keeps vanilla map art usable without redistributing it.
    std::scoped_lock lock(archivedTextureLock_);
    if (archivedTextureMisses_.contains(path)) {
        return nullptr;
    }
    if (const auto cached = archivedTexturePaths_.find(path);
        cached != archivedTexturePaths_.end()) {
        return loadTexture_(cached->second.c_str(), &requestedSize);
    }

    const auto materializedPath = MaterializeArchivedTexture(path);
    if (!materializedPath) {
        archivedTextureMisses_.insert(path);
        return nullptr;
    }
    auto texture = loadTexture_(materializedPath->c_str(), &requestedSize);
    if (!texture) {
        archivedTextureMisses_.insert(path);
        logger::warn(
            "MENU_TEXTURE_ARCHIVE_LOAD_FAILED logical={} cache={}",
            path,
            *materializedPath);
        return nullptr;
    }
    archivedTexturePaths_.insert_or_assign(path, *materializedPath);
    return texture;
}

void DNT::MenuFramework::API::DisposeTexture(const std::string_view a_path) const
{
    if (!a_path.empty()) {
        const auto path = std::string(a_path);
        std::scoped_lock lock(archivedTextureLock_);
        if (const auto cached = archivedTexturePaths_.find(path);
            cached != archivedTexturePaths_.end()) {
            disposeTexture_(cached->second.c_str());
        } else {
            disposeTexture_(path.c_str());
        }
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
