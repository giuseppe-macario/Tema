// ContentView.swift

import SwiftUI

struct ContentView: View {
    
    // MARK: - State
    
    @StateObject private var viewModel = ViewModel()
    @FocusState private var isInputFocused: Bool
    @GestureState private var isPressing = false
    @State private var feedback = UINotificationFeedbackGenerator()
    
    private let cardColor = Color(uiColor: .secondarySystemBackground)
    private let cornerRadius: CGFloat = 16
    
    private var isInputValid: Bool {
        !viewModel.userInput
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            VStack {
                VStack(spacing: 8) {
                    inputArea
                    responseArea
                }
                if viewModel.shouldShowBottomArea {
                    Spacer()
                }
                bottomBar
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 8)
            
            .onReceive(viewModel.dismissKeyboard) { _ in
                isInputFocused = false
            }
            .onChange(of: isInputFocused) { _, isFocused in
                if isFocused {
                    feedback.prepare()
                    feedback.notificationOccurred(.success)
                }
            }
        }
    }
    
    // MARK: - Input Area
    
    private var inputArea: some View {
        ZStack(alignment: .topLeading) {
            
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(cardColor)
            
            if viewModel.userInput.isEmpty {
                Text("Scrivere qui la traccia del tema\ne andare a capo due volte per inviare")
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
            }
            
            if viewModel.isAwaitingConfirmation {
                
                // modalità lettura (scrollabile)
                ScrollView {
                    Text(viewModel.userInput)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                }
                
            } else {
                
                // modalità editing
                TextEditor(text: $viewModel.userInput)
                    .padding(12)
                    .focused($isInputFocused)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .autocorrectionDisabled(false)
                    .textInputAutocapitalization(.never)
                    .onChange(of: viewModel.userInput) { _, newValue in
                        viewModel.handleTypingChange(newValue: newValue)
                    }
            }
        }
        .frame(height: 120)
    }
    
    // MARK: - Response Area
    
    private var responseArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView {
                Text(viewModel.responseText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .foregroundColor(viewModel.hasResponse ? .primary : .secondary)
            }
            .frame(maxHeight: 260)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(cardColor)
            )
        }
        .contentShape(Rectangle())
    }
    
    // MARK: - Send Button
    
    private var bottomBar: some View {
        VStack(spacing: 8) {
            
            Button(action: {
                if viewModel.isAwaitingConfirmation {
                    viewModel.confirmSend()
                } else {
                    viewModel.submit()
                }
            }) {
                Text(buttonLabel)
                    .fontWeight(.medium)
                    .opacity(isInputValid && !viewModel.isLoading ? 1 : 0.5)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        (viewModel.isLoading || !isInputValid)
                        ? Color.gray.opacity(0.4)
                        : Color.accentColor
                    )
            )
            .foregroundColor(.white)
            .disabled(viewModel.isLoading || (!isInputValid && !viewModel.isAwaitingConfirmation))
            
            // Area tappabile (solo quando serve)
            if viewModel.shouldShowBottomArea {
                bottomTapArea
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 120)
            }
        }
    }
    
    private var buttonLabel: String {
        viewModel.isAwaitingConfirmation ? "Conferma" : "Invia"
    }
    
    // MARK: - Bottom Tap Area
    
    private var bottomTapArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.accentColor.opacity(isPressing ? 0.25 : 0.1))
            
            VStack(spacing: 4) {
                Image(systemName: "hand.tap")
                    .font(.system(size: 30))
                
                Text("Tap breve: frase successiva")
                    .font(.footnote)
                
                Text("Tap lungo: riascolta")
                    .font(.footnote)
            }
            .foregroundColor(.accentColor)
            .multilineTextAlignment(.center)
        }
        .scaleEffect(isPressing ? 0.97 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isPressing)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        
        .highPriorityGesture(
            LongPressGesture(minimumDuration: 0.4)
                .updating($isPressing) { current, state, _ in
                    state = current
                }
                .onEnded { _ in
                    if viewModel.isAwaitingConfirmation {
                        viewModel.cancelSend()
                    } else {
                        viewModel.replayLastChunk()
                    }
                }
        )
        
        .simultaneousGesture(
            TapGesture()
                .onEnded {
                    if viewModel.isAwaitingConfirmation {
                        viewModel.confirmSend()
                    } else {
                        viewModel.readNextChunk()
                    }
                }
        )
    }
}

#Preview {
    ContentView()
}
