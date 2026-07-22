//
//  DocumentScanner.swift
//  책갈피샷
//
//  촬영/선택한 책 페이지를 "종이처럼 납작하게" 만든다.
//  - detectCorners: Vision 문서 세그먼테이션으로 페이지 네 모서리를 자동 추정(초기값).
//  - flatten(_:corners:): 사용자가 조정한 네 모서리로 원근 보정 + 크롭.
//  배경(책상/손/그림자)을 걷어내고 페이지를 반듯하게 펴준다.
//

import UIKit
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

/// 페이지 영역 네 모서리. 정규화 좌표(0~1), 좌상단 원점.
struct QuadCorners: Equatable {
    var topLeft: CGPoint
    var topRight: CGPoint
    var bottomRight: CGPoint
    var bottomLeft: CGPoint

    /// 이미지 전체에서 살짝 안쪽으로 들어간 기본 사각형 (자동 추정 실패 시 사용)
    static let defaultInset = QuadCorners(
        topLeft: CGPoint(x: 0.06, y: 0.06),
        topRight: CGPoint(x: 0.94, y: 0.06),
        bottomRight: CGPoint(x: 0.94, y: 0.94),
        bottomLeft: CGPoint(x: 0.06, y: 0.94)
    )
}

enum DocumentFlattener {
    private static let ciContext = CIContext(options: nil)

    // MARK: - 네 모서리 자동 추정

    /// 사진에서 페이지 영역을 찾아 네 모서리를 추정한다. 못 찾으면 nil.
    static func detectCorners(_ image: UIImage) async -> QuadCorners? {
        guard let cgImage = image.cgImage else { return nil }
        let orientation = cgOrientation(from: image.imageOrientation)

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNDetectDocumentSegmentationRequest()
                let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation)
                do {
                    try handler.perform([request])
                    guard
                        let observation = (request.results ?? []).first,
                        observation.confidence >= 0.5
                    else {
                        continuation.resume(returning: nil)
                        return
                    }
                    // Vision: 정규화 + 좌하단 원점 → 좌상단 원점(y 반전)
                    func flip(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x, y: 1 - p.y) }
                    continuation.resume(returning: QuadCorners(
                        topLeft: flip(observation.topLeft),
                        topRight: flip(observation.topRight),
                        bottomRight: flip(observation.bottomRight),
                        bottomLeft: flip(observation.bottomLeft)
                    ))
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    // MARK: - 원근 보정

    /// 네 모서리(정규화·좌상단 원점)로 원근 보정 + 크롭한 이미지를 만든다.
    static func flatten(_ image: UIImage, corners: QuadCorners) async -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        let orientation = cgOrientation(from: image.imageOrientation)

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let ciImage = CIImage(cgImage: cgImage).oriented(orientation)
                let width = ciImage.extent.width
                let height = ciImage.extent.height
                guard width > 0, height > 0 else {
                    continuation.resume(returning: image)
                    return
                }

                // 좌상단 원점 정규화 → 좌하단 원점 픽셀 (Core Image 좌표계)
                func pixel(_ n: CGPoint) -> CGPoint {
                    CGPoint(x: n.x * width, y: (1 - n.y) * height)
                }

                let filter = CIFilter.perspectiveCorrection()
                filter.inputImage = ciImage
                filter.topLeft = pixel(corners.topLeft)
                filter.topRight = pixel(corners.topRight)
                filter.bottomLeft = pixel(corners.bottomLeft)
                filter.bottomRight = pixel(corners.bottomRight)

                guard
                    let output = filter.outputImage,
                    let result = ciContext.createCGImage(output, from: output.extent)
                else {
                    continuation.resume(returning: image)
                    return
                }
                continuation.resume(returning: UIImage(cgImage: result))
            }
        }
    }

    private static func cgOrientation(from uiOrientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch uiOrientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}
