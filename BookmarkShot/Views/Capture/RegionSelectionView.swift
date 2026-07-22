//
//  RegionSelectionView.swift
//  책갈피샷
//
//  촬영/선택한 사진 위에서 페이지 영역(네 모서리)을 손가락으로 조정하는 화면.
//  네 모서리를 페이지 꼭짓점에 맞추면, 이후 그 영역만 원근 보정해 반듯하게 편다.
//

import SwiftUI

struct RegionSelectionView: View {
    let image: UIImage
    @Binding var corners: QuadCorners

    private let handleSize: CGFloat = 26

    var body: some View {
        GeometryReader { geo in
            let fitted = fittedRect(for: image.size, in: geo.size)

            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width, height: geo.size.height)

                // 선택 영역 바깥은 어둡게 + 테두리
                Canvas { context, size in
                    let quad = quadPath(fitted: fitted)
                    var outside = Path(CGRect(origin: .zero, size: size))
                    outside.addPath(quad)
                    context.fill(outside, with: .color(.black.opacity(0.5)), style: FillStyle(eoFill: true))
                    context.stroke(quad, with: .color(.yellow), lineWidth: 2)
                }
                .allowsHitTesting(false)

                handle(for: \.topLeft, fitted: fitted)
                handle(for: \.topRight, fitted: fitted)
                handle(for: \.bottomRight, fitted: fitted)
                handle(for: \.bottomLeft, fitted: fitted)
            }
            .coordinateSpace(name: "region")
        }
    }

    // MARK: - 모서리 핸들

    private func handle(for keyPath: WritableKeyPath<QuadCorners, CGPoint>,
                        fitted: CGRect) -> some View {
        let position = point(corners[keyPath: keyPath], fitted: fitted)
        return Circle()
            .fill(Color.white)
            .overlay(Circle().stroke(Color.yellow, lineWidth: 2))
            .frame(width: handleSize, height: handleSize)
            .contentShape(Rectangle().inset(by: -handleSize))
            .position(position)
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("region"))
                    .onChanged { value in
                        corners[keyPath: keyPath] = clamp01(normalized(value.location, fitted: fitted))
                    }
            )
    }

    private func quadPath(fitted: CGRect) -> Path {
        var path = Path()
        path.move(to: point(corners.topLeft, fitted: fitted))
        path.addLine(to: point(corners.topRight, fitted: fitted))
        path.addLine(to: point(corners.bottomRight, fitted: fitted))
        path.addLine(to: point(corners.bottomLeft, fitted: fitted))
        path.closeSubpath()
        return path
    }

    // MARK: - 좌표 변환

    private func fittedRect(for imageSize: CGSize, in containerSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }
        let scale = min(containerSize.width / imageSize.width,
                        containerSize.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let origin = CGPoint(x: (containerSize.width - size.width) / 2,
                             y: (containerSize.height - size.height) / 2)
        return CGRect(origin: origin, size: size)
    }

    /// 정규화(좌상단 원점) → 화면 좌표
    private func point(_ normalized: CGPoint, fitted: CGRect) -> CGPoint {
        CGPoint(x: fitted.minX + normalized.x * fitted.width,
                y: fitted.minY + normalized.y * fitted.height)
    }

    /// 화면 좌표 → 정규화(좌상단 원점)
    private func normalized(_ point: CGPoint, fitted: CGRect) -> CGPoint {
        guard fitted.width > 0, fitted.height > 0 else { return .zero }
        return CGPoint(x: (point.x - fitted.minX) / fitted.width,
                       y: (point.y - fitted.minY) / fitted.height)
    }

    private func clamp01(_ p: CGPoint) -> CGPoint {
        CGPoint(x: min(max(p.x, 0), 1), y: min(max(p.y, 0), 1))
    }
}
