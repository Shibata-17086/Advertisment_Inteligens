//
//  RealtimeARView.swift
//  iOS-GenAI-Sampler-With-AI
//
//  Created by Koki Shibata on 2024/10/10.
//

import SwiftUI
import RealityKit
import ARKit
import Combine

struct RealtimeARView: View {
    @StateObject var arManager = RealtimeARManager()
    
    var body: some View {
        // ARViewを全画面表示
        ARViewContainer(arManager: arManager)
            .edgesIgnoringSafeArea(.all)
            .onAppear {
                // ARセッションの設定を開始
                arManager.startSession()
            }
            .onDisappear {
                // ARセッションを停止
                arManager.stopSession()
            }
        Text(arManager.resultText)
    }
}

struct ARViewContainer: UIViewRepresentable {
    var arManager: RealtimeARManager

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        // arManagerをARSessionのデリゲートに設定
        arView.session.delegate = arManager

        // CoordinatorにarViewを渡す
        context.coordinator.arView = arView

        // resultTextの変更を監視
        context.coordinator.setupSubscriptions()

        // ARセッションの設定
        arManager.configureSession(for: arView)

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        // 必要に応じてUIViewを更新
    }

    class Coordinator: NSObject {
        var parent: ARViewContainer
        var arView: ARView?
        var cancellable: AnyCancellable?

        // テキストエンティティへの参照を保持
        var posterAnchor: AnchorEntity?
        var textEntities: [ModelEntity] = []

        init(_ parent: ARViewContainer) {
            self.parent = parent
        }

        // resultTextの変更を監視するメソッド
        func setupSubscriptions() {
            cancellable = parent.arManager.$resultText
                .receive(on: DispatchQueue.main)
                .sink { [weak self] newText in
                    self?.updateTextEntities(with: newText)
                }
        }

        // ARシーン上のテキストエンティティを更新するメソッド
        func updateTextEntities(with text: String) {
            guard let arView = arView else { return }

            // ポスターアンカーがまだ作成されていない場合、作成
            if posterAnchor == nil {
                createPosterAnchor(in: arView)
            }

            guard let anchor = posterAnchor else { return }

            // 既存のテキストエンティティを削除
            for textEntity in textEntities {
                textEntity.removeFromParent()
            }
            textEntities.removeAll()

            // テキストを複数行に分割
            let lines = splitTextIntoLines(text: text, maxCharactersPerLine: 100)  // 最大文字数を増やす

            // 各行をテキストエンティティとして作成し、ポスター上に配置
            for (index, line) in lines.enumerated() {
                let textEntity = createTextEntity(with: line)
                // テキストのY位置を調整（ポスターの中央から上下に配置）
                let lineSpacing: Float = 0.05  // 行間の調整（小さく）
                let totalHeight = Float(lines.count) * lineSpacing
                let yPosition = Float(lines.count / 2 - index) * lineSpacing - (totalHeight / 2) + lineSpacing / 2
                textEntity.position = SIMD3<Float>(0, yPosition, 0.001)  // 少しポスターから浮かせる

                anchor.addChild(textEntity)
                textEntities.append(textEntity)
            }
        }

        // ポスターアンカーを作成してシーンに追加
        func createPosterAnchor(in arView: ARView) {
            let posterSize: SIMD2<Float> = [0.42, 0.594] // A2サイズのメートル単位（420mm x 594mm）
            let posterMesh = MeshResource.generatePlane(width: posterSize.x, depth: posterSize.y,cornerRadius: 0.01)
            let posterMaterial = SimpleMaterial(color: .systemGray, isMetallic: false)
            let posterEntity = ModelEntity(mesh: posterMesh, materials: [posterMaterial])

            // ポスターのアンカーを作成してシーンに追加
            let anchor = AnchorEntity(plane: .vertical, classification: .wall ,minimumBounds: posterSize)
            anchor.addChild(posterEntity)
            arView.scene.addAnchor(anchor)
            self.posterAnchor = anchor
        }

        // テキストエンティティを作成
        func createTextEntity(with text: String) -> ModelEntity {
            let fontSize: Float = 0.03  // フォントサイズの調整（小さくする）
            let extrusionDepth: Float = 0.005  // テキストの厚み

            // 回転角と回転軸の設定
            let angle: Float = -.pi / 2
            let rotationAxis = simd_float3(1, 0, 0)

            let arText = MeshResource.generateText(text,
                                                   extrusionDepth: extrusionDepth,
                                                   font: .systemFont(ofSize: CGFloat(fontSize)),
                                                   containerFrame: CGRect(x: -0.2, y: -0.3, width: 0.4, height: 0.56),  // A2サイズに合わせる
                                                   alignment: .center,
                                                   lineBreakMode: .byWordWrapping)

            let textModel = ModelEntity(mesh: arText)
            textModel.model?.materials = [SimpleMaterial(color: .white, isMetallic: false)]
            let quaternion = simd_quatf(angle: angle, axis: rotationAxis)
            textModel.transform.rotation = quaternion
            
            return textModel
        }

        // テキストを複数行に分割するヘルパー関数
        func splitTextIntoLines(text: String, maxCharactersPerLine: Int) -> [String] {
            var lines: [String] = []
            var currentLine = ""

            for word in text.split(separator: " ") {
                if currentLine.count + word.count + 1 <= maxCharactersPerLine {
                    if currentLine.isEmpty {
                        currentLine = String(word)
                    } else {
                        currentLine += " " + String(word)
                    }
                } else {
                    lines.append(currentLine)
                    currentLine = String(word)
                }
            }

            if !currentLine.isEmpty {
                lines.append(currentLine)
            }

            return lines
        }

        deinit {
            // サブスクリプションをキャンセル
            cancellable?.cancel()
        }
    }
}

#Preview {
    RealtimeARView()
}
