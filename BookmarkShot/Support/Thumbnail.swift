//
//  Thumbnail.swift
//  밑줄
//
//  표지 · 원본 사진을 칸 크기로 줄여 그린다.
//
//  표지와 페이지 사진은 카메라 원본(12MP 이상) JPEG 로 저장돼 있다. 예전에는 그것을 화면이
//  다시 그려질 때마다 `UIImage(data:)` 로 만들어, 110×154 칸 하나에 원본 전체를 메인 스레드에서
//  풀었다(장마다 수십~백수십 ms). 첫 화면인 서재에 표지가 여러 장이면 그만큼 멈칫했다.
//  이제 칸에 맞는 크기로 한 번만 줄이되 뒤에서 하고, 결과는 기억해 둔다.
//

import SwiftUI
import ImageIO

enum Thumbnail {
    private static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 200
        return cache
    }()

    static func cached(_ key: String) -> UIImage? { cache.object(forKey: key as NSString) }

    /// 원본을 다 풀지 않고 긴 변이 `maxPixel` 인 그림으로 바로 읽는다.
    static func make(from data: Data, maxPixel: CGFloat) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary)
        else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, Int(maxPixel.rounded()))
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: image)
    }

    static func load(_ data: Data, key: String, maxPixel: CGFloat) async -> UIImage? {
        if let hit = cached(key) { return hit }
        let made = await Task.detached(priority: .userInitiated) { make(from: data, maxPixel: maxPixel) }.value
        if let made { cache.setObject(made, forKey: key as NSString) }
        return made
    }

    /// 저장할 때 줄인다. 표지는 화면에서 가장 커도 상세의 72×100 이라 원본을 둘 까닭이 없다.
    static func jpeg(_ image: UIImage, maxPixel: CGFloat, quality: CGFloat) -> Data? {
        let side = max(image.size.width, image.size.height) * image.scale
        guard side > maxPixel else { return image.jpegData(compressionQuality: quality) }
        let ratio = maxPixel / side
        let size = CGSize(width: (image.size.width * image.scale * ratio).rounded(),
                          height: (image.size.height * image.scale * ratio).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let small = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return small.jpegData(compressionQuality: quality)
    }
}

/// 저장된 그림 데이터를 칸 크기로 줄여 칸을 채워 그린다. 줄이는 동안과 데이터가 없을 때는 `placeholder`.
struct ThumbnailImage<Placeholder: View>: View {
    let data: Data?
    /// 같은 그림이면 같은 열쇠 — 모델 ID 와 데이터 크기로 만든다.
    let id: AnyHashable
    let maxPixel: CGFloat
    @ViewBuilder var placeholder: () -> Placeholder

    @State private var image: UIImage?

    private var key: String? {
        data.map { "\(id.hashValue)-\($0.count)-\(Int(maxPixel))" }
    }

    var body: some View {
        Group {
            if let shown = image ?? key.flatMap(Thumbnail.cached) {
                Image(uiImage: shown).resizable().scaledToFill()
            } else {
                placeholder()
            }
        }
        .task(id: key) {
            guard let data, let key else { image = nil; return }
            image = await Thumbnail.load(data, key: key, maxPixel: maxPixel)
        }
    }
}
