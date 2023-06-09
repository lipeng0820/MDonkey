import SwiftUI
import AVFoundation
import CoreHaptics

struct ContentView: View {
    @State private var showStartButton = true
    @State private var numbers = [Int]()
    @State private var positions = [CGPoint]()
    @State private var startTime: Date?
    @State private var endTime: Date?
    @State private var currentNumber = 0
    @State private var gameOver = false
    @State private var showOverlay = false
    @State private var blockColors: [Color] = Array(repeating: .white, count: 10)
    @State private var elapsedTime: TimeInterval? // 新增用于显示耗时的变量
    @State private var showResult = false
    @State private var hideBlocks = false
    @State private var showAboutMe = false
    @StateObject private var motionDetector = MotionDetector()
    @State private var difficulty: TimeInterval = 2.0
    @State private var showHowView = true

    private let gridSize = 10
    private let maxRandomAttempts = 100

    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            if showHowView {
                HowView(isPresented: $showHowView)
                    .transition(.opacity.animation(.easeInOut(duration: 0.3)))
                    .zIndex(1)
            }
            
            if showStartButton {
                Circle()
                    .frame(width: 60, height: 60)
                    .foregroundColor(.white)
                    .padding(.bottom, 40)
                    .padding(.trailing, 600)
                    .onTapGesture(count: 1) { // 在此处添加 "count: 1" 参数
                        startGame()
                    }
                    .onLongPressGesture {
                        showDifficultyMenu()
                    }
                    .position(x: UIScreen.main.bounds.width - 30, y: UIScreen.main.bounds.height - 30)
            } else {
                ForEach(0..<gridSize, id: \.self) { index in
                    let position = positions[index]
                    let number = numbers[index]
                    let color = getColor(for: number)

                    ZStack {

                        if !hideBlocks {
                            Text("\(number)")
                                .font(.system(size: 60))
                                .foregroundColor(color)

                            if showOverlay && number >= currentNumber {
                                RoundedRectangle(cornerRadius: 0)
                                    .fill(blockColors[number])
                                    .frame(width: 60, height: 60)
                            }
                        }

                    }
                    .position(position)
                    .onTapGesture {
                        handleTap(on: number)
                    }
                }
            }

            // 将此部分代码移动到这里
            if showResult {
                VStack {
                    if let elapsedTime = elapsedTime {
                        Text("本次用时：\(elapsedTime, specifier: "%.3f")秒")
                            .font(.largeTitle)
                            .foregroundColor(.white) // 设置字体颜色为白色
                    }
                    Button(action: {
                        startGame()
                    }, label: {
                        Text("重置")
                            .font(.title)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.red)
                            .cornerRadius(10)
                    })
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
                .edgesIgnoringSafeArea(.all)
            }
            
            if showAboutMe {
                AboutMeView(isPresented: $showAboutMe)
                    .transition(.move(edge: .bottom))
                    .onChange(of: showAboutMe) { _ in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            self.showAboutMe.toggle()
                        }
                    }
            }
        }
        .edgesIgnoringSafeArea(.all)
        .onAppear {
            motionDetector.start()
            motionDetector.shakeDetected = {
                showAboutMe.toggle()
            }
        }
        .onDisappear {
            motionDetector.stop()
        }
    }

    private func startGame() {
        hideBlocks = false
        gameOver = false
        showResult = false
        showStartButton = false
        startTime = Date()
        numbers = Array(0..<gridSize).shuffled()
        positions = generateRandomPositions()
        currentNumber = 0
        blockColors = Array(repeating: .white, count: gridSize)
        DispatchQueue.main.asyncAfter(deadline: .now() + difficulty) { //难度设定
            showOverlay = true
        }

    }
    
    private func showDifficultyMenu() {
        let alertController = UIAlertController(title: "选择难度", message: nil, preferredStyle: .actionSheet)
            // ... 添加 UIAlertAction ...

        let easyAction = UIAlertAction(title: "过目不忘", style: .default) { _ in
            difficulty = 0.5
        }

        let normalAction = UIAlertAction(title: "平凡人类", style: .default) { _ in
            difficulty = 2.0
        }

        let hardAction = UIAlertAction(title: "死记硬背", style: .default) { _ in
            difficulty = 10.0
        }

        let cancelAction = UIAlertAction(title: "取消", style: .cancel, handler: nil)

        alertController.addAction(easyAction)
        alertController.addAction(normalAction)
        alertController.addAction(hardAction)
        alertController.addAction(cancelAction)

        // 此处需要获取到当前视图控制器以展示 alertController
        // 获取当前活跃的 UIWindowScene
        if let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            // 获取关联的 UIWindow
            if let window = windowScene.windows.first, let viewController = window.rootViewController {
                // 在根视图控制器上展示 UIAlertController
                viewController.present(alertController, animated: true, completion: nil)
            }
        }
    }
    

    private func endGame() {
        endTime = Date()
        elapsedTime = endTime?.timeIntervalSince(startTime ?? Date())
        gameOver = true
        showOverlay = false
        hideBlocks = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            showResult = true
            showStartButton = false
            // 播放胜利音效
            playTone(audioFilename: "victory")
        }
    }



    private func handleTap(on number: Int) {
        if !showOverlay {
            return // 如果 showOverlay 为 false，直接返回，不执行后续操作
        }

        if number == currentNumber {
            blockColors[number] = .black
            currentNumber += 1
            if showOverlay { // 添加这个条件检查
                playTone(audioFilename: "press2") // 添加这一行，播放 press2.mp3 音效
            }
            if currentNumber == gridSize {
                endGame()
            }
        } else {
            blockColors[number] = .red

            // 调用新增加的方法
            if showOverlay { // 添加这个条件检查
                playTone(audioFilename: "wrong")
            }
            triggerHapticFeedback()

            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                blockColors[number] = .white
                showStartButton = true
                showOverlay = false
            }
        }
    }






    private func getColor(for number: Int) -> Color {
        if gameOver && number != currentNumber {
            return .white
        }
        return number < currentNumber ? .black : .white
    }

    private func generateRandomPositions() -> [CGPoint] {
        var positions = [CGPoint]()
        for _ in 0..<gridSize {
            var attempts = 0
            var position: CGPoint
            repeat {
                position = randomPosition()
                attempts += 1
            } while !isPositionValid(position, in: positions) && attempts < maxRandomAttempts
            positions.append(position)
        }
        return positions
    }

    private func randomPosition() -> CGPoint {
        let screenwidth = UIScreen.main.bounds.width
        let x = CGFloat.random(in: (screenwidth * 0.03)..<(screenwidth * (1 - 0.03)))
        let screenHeight = UIScreen.main.bounds.height
        let y = CGFloat.random(in: (screenHeight * 0.08)..<(screenHeight * (1 - 0.05)))
        return CGPoint(x: x, y: y)
    }

    private func isPositionValid(_ position: CGPoint, in existingPositions: [CGPoint]) -> Bool {
        let minDistance: CGFloat = 80
        for existingPosition in existingPositions {
            let distance = sqrt(pow(position.x - existingPosition.x, 2) + pow(position.y - existingPosition.y, 2))
            if distance < minDistance {
                return false
            }
        }
        return true
    }
}

    private var audioPlayer: AVAudioPlayer?

    private func playTone(audioFilename: String) {
        guard let toneUrl = Bundle.main.url(forResource: audioFilename, withExtension: "mp3") else {
            print("Failed to find the audio file")
            return
        }

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true, options: [])

            audioPlayer = try AVAudioPlayer(contentsOf: toneUrl)
            audioPlayer?.play()
        } catch {
            print("Failed to play the audio file: \(error)")
        }
    }


    private func triggerHapticFeedback() {
        if #available(iOS 13.0, *) {
            let hapticEngine = try? CHHapticEngine()
            let hapticEvent = CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 1)
            ], relativeTime: 0)

            if let hapticPattern = try? CHHapticPattern(events: [hapticEvent], parameters: []), let hapticPlayer = try? hapticEngine?.makePlayer(with: hapticPattern) {
                try? hapticEngine?.start()
                try? hapticPlayer.start(atTime: CHHapticTimeImmediate)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    hapticEngine?.stop()
                }
            }
        } else {
            let feedbackGenerator = UIImpactFeedbackGenerator(style: .heavy)
            feedbackGenerator.impactOccurred()
        }
    }

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
