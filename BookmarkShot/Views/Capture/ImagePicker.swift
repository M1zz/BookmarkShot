//
//  ImagePicker.swift
//  밑줄
//
//  카메라/앨범 공용 이미지 피커. 시뮬레이터처럼 카메라가 없는 환경에서는 자동으로 앨범으로 폴백.
//

import SwiftUI
import UIKit

struct ImagePicker: UIViewControllerRepresentable {
    enum Source {
        case camera
        case photoLibrary
    }

    let source: Source
    let onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        if source == .camera && UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
        } else {
            picker.sourceType = .photoLibrary
        }
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImage(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

/// "카메라로 찍기 / 앨범에서 선택" 선택지를 보여주는 공용 버튼 그룹.
/// 카메라를 주 행동(강조), 앨범을 보조 행동으로 두어 위계를 명확히 한다.
struct PhotoSourceButtons: View {
    /// 버튼 위에 얹을 안내 문구(비우면 표시하지 않음)
    var title: String = ""
    let onPick: (ImagePicker.Source) -> Void

    var body: some View {
        VStack(spacing: 12) {
            if !title.isEmpty {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button {
                onPick(.camera)
            } label: {
                Label("카메라로 찍기", systemImage: "camera.fill")
            }
            .buttonStyle(.brandPrimary)

            Button {
                onPick(.photoLibrary)
            } label: {
                Label("앨범에서 선택", systemImage: "photo.on.rectangle")
            }
            .buttonStyle(.brandSecondary)
        }
        .padding(.horizontal, Theme.screenPadding)
    }
}
