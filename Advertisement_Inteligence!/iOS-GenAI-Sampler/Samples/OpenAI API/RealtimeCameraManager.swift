//  RealtimeCameraManager.swift
//  iOS-GenAI-Sampler
//
//  Created by Shuichi Tsutsumi on 2024/05/20.

import AVFoundation
import CoreImage
import Foundation
import UIKit.UIImage

class RealtimeCameraManager: ObservableObject {
    // ビデオキャプチャオブジェクトを保持
    private(set) var videoCapture: VideoCapture?

    // 最後に処理した時間と蓄積した時間の記録
    private var lastProcessedTime: CFAbsoluteTime = 0 // 最後にフレームを処理した時間
    private var lastAccumulatedTime: CFAbsoluteTime = 0 // 最後にフレームを蓄積した時間
    let context = CIContext() // 画像処理用のコンテキスト
    let openAI = OpenAIClient() // OpenAIクライアント

    // 前回のテキスト、送信中フラグ、リセットフラグ、蓄積フレーム
    private var prevText: String? = nil // 前のフレームの説明テキスト
    private var isSending: Bool = false // 現在送信中かどうかのフラグ
    private var shouldResetText: Bool = false // テキストをリセットするべきかどうかのフラグ
    private var accumulatedFrames: [Data] = [] // 蓄積されたフレームのデータ

    // パラメータ設定
    static let processInterval: CFAbsoluteTime = 3 // フレーム処理の間隔（秒）
    static let accumulateInterval: CFAbsoluteTime = 6 // フレーム蓄積の間隔（秒）
    static let maxFrames: Int = 2 // 最大フレーム数
    static let maxImageSize: CGFloat = 512 // 最大画像サイズ

    @Published var useJP: Bool = true // 日本語モードの切り替えフラグ
    @Published var resultText: String = "" // 結果のテキスト

    // カメラアクセスをリクエストするメソッド
    func requestAccess() async -> Bool {
        return await AVCaptureDevice.requestAccess(for: .video) // カメラへのアクセス許可をリクエスト
    }

    // サンプルバッファから画像データを作成するメソッド
    private func createImageData(from sampleBuffer: CMSampleBuffer) -> Data? {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil } // サンプルバッファから画像バッファを取得
        let ciImage = CIImage(cvPixelBuffer: imageBuffer) // 画像バッファをCIImageに変換
        // 画像をリサイズしてクロップ
        let resizedImage = ciImage.resizedByShortestSide(to: RealtimeCameraManager.maxImageSize).cropped(to: RealtimeCameraManager.maxImageSize)

        // リサイズした画像をCGImageに変換
        guard let cgImage = context.createCGImage(resizedImage, from: resizedImage.extent) else { return nil }
        return cgImage.data // CGImageをJPEGデータに変換して返す
    }

    // 前のフレームに基づいたナレーションプロンプトを作成するメソッド
    private func videoNarratingPrompt(with prevText: String?) -> String {
        print("prevText: \(String(describing: prevText))") // 前回のテキストをログに出力
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

    // カメラの初期化メソッド
    func initialize(with view: UIView) {
        // バックカメラを使用してビデオキャプチャを初期化
        let videoCapture = VideoCapture(cameraType: .back, previewView: view, useAudio: false)

        videoCapture.videoOutputHandler = { _, sampleBuffer, _ in
            assert(!Thread.isMainThread) // メインスレッドで実行されていないことを確認

            // 前回の処理から指定した時間が経過しているかチェック
            let currentTime = CFAbsoluteTimeGetCurrent()
            guard currentTime - self.lastProcessedTime >= RealtimeCameraManager.processInterval else { return }
            self.lastProcessedTime = currentTime

            // 送信中の場合はスキップしてフレームを蓄積
            guard !self.isSending else {
                print("Sending")
                guard currentTime - self.lastAccumulatedTime >= RealtimeCameraManager.accumulateInterval else { return }
                if let imageData = self.createImageData(from: sampleBuffer) {
                    self.accumulatedFrames.append(imageData) // フレームを蓄積
                    self.lastAccumulatedTime = currentTime
                }
                return
            }
            self.isSending = true // 送信中フラグを設定

            // 新しいフレームを作成し蓄積
            guard let imageData = self.createImageData(from: sampleBuffer) else { return }
            self.accumulatedFrames.append(imageData)

            // ナレーションを追加するタスクを開始
            Task {
                await self.addNarration()
            }
        }

        self.videoCapture = videoCapture // ビデオキャプチャオブジェクトを保存
    }

    // キャプチャの開始メソッド
    func startCapture() {
        videoCapture?.startCapture() // キャプチャを開始
    }

    // キャプチャの停止メソッド
    func stopCapture() {
        videoCapture?.stopCapture {
            print("capture stopped") // キャプチャ停止時のログ出力
        }
    }

    // ナレーションを追加するメソッド
    private func addNarration() async {
        let startTime = CFAbsoluteTimeGetCurrent() // 処理開始時間を記録
        let userPrompt = videoNarratingPrompt(with: prevText) // ナレーションプロンプトを作成
        print("num accumlated: \(accumulatedFrames.count)") // 蓄積フレーム数をログに出力
        let stream = openAI.sendMessage(text: userPrompt, images: accumulatedFrames.suffix(RealtimeCameraManager.maxFrames), detail: .low, maxTokens: 80) // OpenAIにメッセージを送信
        accumulatedFrames = [] // 蓄積フレームをリセット
        do {
            for try await result in stream {
                guard let choice = result.choices.first else { return }
                if let finishReason = choice.finishReason {
                    print("Stream finished with reason:\(finishReason)") // ストリーム終了理由をログに出力
                    let endTime = CFAbsoluteTimeGetCurrent()
                    print("Final result: \(resultText)") // 最終結果をログに出力
                    print("Elapsed time: \(endTime - startTime)") // 処理にかかった時間を出力

                    prevText = resultText // 前回の結果を保存
                    isSending = false // 送信中フラグをリセット

                    // 次の結果が来るまでリセットフラグを立てておく
                    shouldResetText = true
                }
                guard let message = choice.delta.content else { return }
                await MainActor.run {
                    if self.shouldResetText {
                        // 前回までの結果の蓄積をリセットして新しい結果を入れていく
                        self.resultText = message
                        self.shouldResetText = false
                    } else {
                        self.resultText += message
                    }
                }
            }

        } catch {
            print("Failed to send messages with error: \(error)") // エラーが発生した場合のログ出力
            resultText = error.localizedDescription // エラーメッセージを結果テキストに設定
            isSending = false // 送信中フラグをリセット
            shouldResetText = true // リセットフラグを設定
        }
    }
}

// CGImageの拡張で、JPEGデータを生成するプロパティを追加
extension CGImage {
    var data: Data? {
        return UIImage(cgImage: self).jpegData(compressionQuality: 0.3) // JPEGデータに圧縮して返す
    }
}
