//
//  RealtimeARManager.swift
//  iOS-GenAI-Sampler-With-AI
//
//  Created by Koki Shibata on 2024/10/10.
//
import ARKit
import RealityKit
import AVFoundation
import CoreImage
import UIKit

class RealtimeARManager: NSObject, ObservableObject, ARSessionDelegate {
    let context = CIContext()
    let openAI = OpenAIClient()

    private var lastProcessedTime: CFAbsoluteTime = 0
    private var lastAccumulatedTime: CFAbsoluteTime = 0

    private var prevText: String? = nil
    private var isSending: Bool = false
    private var shouldResetText: Bool = false
    private var accumulatedFrames: [Data] = []

    static let processInterval: CFAbsoluteTime = 3
    static let accumulateInterval: CFAbsoluteTime = 6
    static let maxFrames: Int = 2
    static let maxImageSize: CGFloat = 512

    @Published var useJP: Bool = true
    @Published var resultText: String = ""

    // ARセッションの設定
    func configureSession(for arView: ARView) {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical] // 水平および垂直面の検出を有効化
        arView.session.run(configuration)
    }

    // ARセッションを開始するメソッド
    func startSession() {
        // 追加の設定が必要な場合はここに記述
    }

    // ARセッションを停止するメソッド
    func stopSession() {
        // ARセッションを停止
        // 通常は必要に応じて停止処理を実装
    }

    // ARSessionDelegateメソッド：フレーム更新時に呼び出される
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // 指定した間隔でフレームを処理
        let currentTime = CFAbsoluteTimeGetCurrent()
        guard currentTime - self.lastProcessedTime >= RealtimeARManager.processInterval else { return }
        self.lastProcessedTime = currentTime

        // 送信中かどうかを確認し、フレームを蓄積
        guard !self.isSending else {
            guard currentTime - self.lastAccumulatedTime >= RealtimeARManager.accumulateInterval else { return }
            if let imageData = self.createImageData(from: frame.capturedImage) {
                self.accumulatedFrames.append(imageData)
                self.lastAccumulatedTime = currentTime
            }
            return
        }
        self.isSending = true

        // 新しいフレームを作成し蓄積
        if let imageData = self.createImageData(from: frame.capturedImage) {
            self.accumulatedFrames.append(imageData)
        }

        // ナレーションを追加するタスクを開始
        Task {
            await self.addNarration()
        }
    }

    // CVPixelBufferから画像データを作成
    private func createImageData(from pixelBuffer: CVPixelBuffer) -> Data? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        // 画像をリサイズしてクロップ
        let resizedImage = ciImage.resizedByShortestSide(to: RealtimeARManager.maxImageSize).cropped(to: RealtimeARManager.maxImageSize)

        // リサイズした画像をCGImageに変換
        guard let cgImage = context.createCGImage(resizedImage, from: resizedImage.extent) else { return nil }
        return cgImage.jpegData
    }

    // 前のフレームに基づいたプロンプトを作成
    private func videoNarratingPrompt(with prevText: String?) -> String {
        print("prevText: \(String(describing: prevText))")
        if useJP {
            return
                """
                これは動画の連続したフレームです。
                あなたは優秀な広告アドバイザです．
                動画の内容に沿った効果的な広告を選定して下さい。
                動画の中の状況をよく観察し，動画撮影者が今何を求めているのかをよく考察して下さい．
                動画内のものを解説するのではなく，付属品や周辺機器等を勧め購買意欲を高めて下さい
                最終的な出力は『10文字以内の短い検索ワード』と『選んだ理由の説明文』にして下さい
                - 前のフレームの説明: \(prevText ?? "なし")
                - 前のフレームと同じ状況の描写は省略し、変わった部分について描写してください。
                - 文字があれば優先して広告の題材にして下さい。読めなければ描写不要です。
                - 「現在のフレームでは」といった接頭辞は省略してください。
                """
        } else {
            return
                """
                This is a sequence of video frames.
                Please add a narration in 20 words that follow the flow of the video, considering the content of the previous frame.
                - Description of the previous frame: \(prevText ?? "None")
                - Omit descriptions of unchanged situations from the previous frame, and describe only what has changed.
                - If there are any texts, please read them. If not readable, no description is needed.
                - Omit prefixes like "In the current frame".
                """
        }
    }

    // ナレーションを追加するメソッド
    private func addNarration() async {
        let startTime = CFAbsoluteTimeGetCurrent()
        let userPrompt = videoNarratingPrompt(with: prevText)
        print("num accumulated: \(accumulatedFrames.count)")
        let stream = openAI.sendMessage(text: userPrompt, images: accumulatedFrames.suffix(RealtimeARManager.maxFrames), detail: .low, maxTokens: 80)
        accumulatedFrames = []
        do {
            for try await result in stream {
                guard let choice = result.choices.first else { return }
                if let finishReason = choice.finishReason {
                    print("Stream finished with reason: \(finishReason)")
                    let endTime = CFAbsoluteTimeGetCurrent()
                    print("Final result: \(resultText)")
                    print("Elapsed time: \(endTime - startTime)")

                    prevText = resultText
                    isSending = false
                    shouldResetText = true
                }
                guard let message = choice.delta.content else { return }
                await MainActor.run {
                    if self.shouldResetText {
                        self.resultText = message
                        self.shouldResetText = false
                    } else {
                        self.resultText += message
                    }
                }
            }
        } catch {
            print("Failed to send messages with error: \(error)")
            resultText = error.localizedDescription
            isSending = false
            shouldResetText = true
        }
    }
}

// CGImageの拡張で、JPEGデータを生成するプロパティを追加
extension CGImage {
    var jpegData: Data? {
        return UIImage(cgImage: self).jpegData(compressionQuality: 0.3)
    }
}
