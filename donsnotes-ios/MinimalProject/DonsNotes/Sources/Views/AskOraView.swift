import SwiftUI

// MARK: - Ask Ora
// Cross-meeting memory: query all past meetings with a single natural-language question.
// Uses Groq (llama-3.3-70b) with all meeting summaries + transcripts as context.

struct AskOraView: View {
    let meetings: [Meeting]

    @State private var query = ""
    @State private var answer = ""
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var history: [(q: String, a: String)] = []
    @FocusState private var inputFocused: Bool

    // Build context from all completed meetings (summaries preferred, transcripts as fallback)
    private var meetingContext: String {
        let completed = meetings.filter { $0.status == .completed || $0.status == .sent }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(30) // cap at 30 meetings to stay inside token limits

        guard !completed.isEmpty else { return "" }

        return completed.enumerated().map { i, m in
            let date = m.createdAt.formatted(date: .abbreviated, time: .omitted)
            let title = m.title ?? "Meeting \(i + 1)"
            let attendeeNames = m.attendees.map { $0.name }.joined(separator: ", ")
            let attendeeStr = attendeeNames.isEmpty ? "" : " · Attendees: \(attendeeNames)"
            let content = m.summary ?? m.transcript ?? "(no content)"
            let actions = m.actionItems?.map { "• \($0)" }.joined(separator: "\n") ?? ""
            let actionStr = actions.isEmpty ? "" : "\nAction Items:\n\(actions)"
            return "[\(date) — \(title)\(attendeeStr)]\n\(content)\(actionStr)"
        }.joined(separator: "\n\n---\n\n")
    }

    var body: some View {
        ZStack {
            LM.Colors.void.ignoresSafeArea()

            VStack(spacing: 0) {

                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ASK ORA")
                            .font(LM.Fonts.mono(11, weight: .bold))
                            .foregroundColor(LM.Colors.cyan)
                            .tracking(3)
                        Text("Search across all your meetings")
                            .font(LM.Fonts.text(12))
                            .foregroundColor(LM.Colors.textTertiary)
                    }
                    Spacer()
                    if !history.isEmpty {
                        Button("Clear") {
                            withAnimation { history = []; answer = ""; errorMessage = nil }
                        }
                        .font(LM.Fonts.text(12))
                        .foregroundColor(LM.Colors.textTertiary)
                    }
                }
                .padding(.horizontal, LM.Space.md)
                .padding(.top, LM.Space.md)
                .padding(.bottom, LM.Space.sm)

                // Empty state / suggestions
                if history.isEmpty && answer.isEmpty && !isLoading {
                    ScrollView {
                        VStack(spacing: 12) {
                            Spacer(minLength: 20)

                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 36))
                                .foregroundColor(LM.Colors.cyan.opacity(0.4))
                                .padding(.bottom, 4)

                            Text("Ask anything about your past meetings")
                                .font(LM.Fonts.text(14))
                                .foregroundColor(LM.Colors.textSecondary)
                                .multilineTextAlignment(.center)

                            Text("Ora searches across all \(meetings.filter { $0.status == .completed || $0.status == .sent }.count) recorded meetings")
                                .font(LM.Fonts.text(12))
                                .foregroundColor(LM.Colors.textTertiary)
                                .multilineTextAlignment(.center)
                                .padding(.bottom, 16)

                            // Suggested prompts
                            let suggestions = [
                                "What action items are still open?",
                                "What did we decide about the budget?",
                                "Who mentioned the product launch?",
                                "Summarize last week's meetings",
                                "What were the main blockers discussed?",
                                "Which meetings had the most action items?"
                            ]

                            ForEach(suggestions, id: \.self) { s in
                                Button(action: { query = s; sendQuery() }) {
                                    HStack {
                                        Image(systemName: "sparkle")
                                            .font(.system(size: 11))
                                            .foregroundColor(LM.Colors.cyan)
                                        Text(s)
                                            .font(LM.Fonts.text(13))
                                            .foregroundColor(LM.Colors.textPrimary)
                                            .multilineTextAlignment(.leading)
                                        Spacer()
                                        Image(systemName: "arrow.right")
                                            .font(.system(size: 11))
                                            .foregroundColor(LM.Colors.textTertiary)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .background(LM.Colors.surface)
                                    .cornerRadius(LM.Radius.sm)
                                    .overlay(RoundedRectangle(cornerRadius: LM.Radius.sm)
                                        .stroke(LM.Colors.borderDim, lineWidth: 1))
                                }
                            }
                            .padding(.horizontal, LM.Space.md)
                        }
                        .padding(.bottom, 100)
                    }
                } else {
                    // Conversation history
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(history.indices, id: \.self) { i in
                                    // User bubble
                                    HStack {
                                        Spacer()
                                        Text(history[i].q)
                                            .font(LM.Fonts.text(13))
                                            .foregroundColor(.black)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 10)
                                            .background(LM.Colors.cyan)
                                            .cornerRadius(LM.Radius.md)
                                            .frame(maxWidth: 280, alignment: .trailing)
                                    }
                                    // Ora answer bubble
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("ORA")
                                                .font(LM.Fonts.mono(9, weight: .bold))
                                                .foregroundColor(LM.Colors.cyan)
                                                .tracking(2)
                                            Text(history[i].a)
                                                .font(LM.Fonts.text(13))
                                                .foregroundColor(LM.Colors.textPrimary)
                                                .lineSpacing(4)
                                                .textSelection(.enabled)
                                        }
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
                                        .background(LM.Colors.surface)
                                        .cornerRadius(LM.Radius.md)
                                        .overlay(RoundedRectangle(cornerRadius: LM.Radius.md)
                                            .stroke(LM.Colors.borderCyan, lineWidth: 1))
                                        .frame(maxWidth: 300, alignment: .leading)
                                        Spacer()
                                    }
                                    .id("answer-\(i)")
                                }

                                // Loading indicator
                                if isLoading {
                                    HStack {
                                        HStack(spacing: 8) {
                                            ProgressView()
                                                .tint(LM.Colors.cyan)
                                                .scaleEffect(0.8)
                                            Text("Searching your meetings...")
                                                .font(LM.Fonts.text(12))
                                                .foregroundColor(LM.Colors.textTertiary)
                                        }
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
                                        .background(LM.Colors.surface)
                                        .cornerRadius(LM.Radius.md)
                                        Spacer()
                                    }
                                    .id("loading")
                                }

                                if let err = errorMessage {
                                    HStack {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.orange)
                                            .font(.system(size: 12))
                                        Text(err)
                                            .font(LM.Fonts.text(12))
                                            .foregroundColor(LM.Colors.textSecondary)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(Color.orange.opacity(0.1))
                                    .cornerRadius(LM.Radius.sm)
                                    .padding(.horizontal, LM.Space.md)
                                }
                            }
                            .padding(LM.Space.md)
                            .padding(.bottom, 80)
                        }
                        .onChange(of: history.count) { _ in
                            if let last = history.indices.last {
                                withAnimation { proxy.scrollTo("answer-\(last)", anchor: .bottom) }
                            }
                        }
                        .onChange(of: isLoading) { loading in
                            if loading { withAnimation { proxy.scrollTo("loading", anchor: .bottom) } }
                        }
                    }
                }

                Spacer(minLength: 0)

                // Input bar
                VStack(spacing: 0) {
                    Divider().background(LM.Colors.borderDim)
                    HStack(spacing: 10) {
                        TextField("", text: $query, axis: .vertical)
                            .placeholder(when: query.isEmpty) {
                                Text("Ask about any past meeting...").foregroundColor(LM.Colors.textGhost)
                            }
                            .foregroundColor(LM.Colors.textPrimary)
                            .font(LM.Fonts.text(14))
                            .lineLimit(1...4)
                            .focused($inputFocused)
                            .onSubmit { if !query.trimmingCharacters(in: .whitespaces).isEmpty { sendQuery() } }

                        Button(action: sendQuery) {
                            ZStack {
                                Circle()
                                    .fill(query.trimmingCharacters(in: .whitespaces).isEmpty || isLoading
                                          ? LM.Colors.surface
                                          : LM.Colors.cyan)
                                    .frame(width: 34, height: 34)
                                Image(systemName: isLoading ? "ellipsis" : "arrow.up")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(query.trimmingCharacters(in: .whitespaces).isEmpty || isLoading
                                                     ? LM.Colors.textTertiary
                                                     : .black)
                            }
                        }
                        .disabled(query.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                    }
                    .padding(.horizontal, LM.Space.md)
                    .padding(.vertical, 12)
                    .background(LM.Colors.deep)
                }
            }
        }
        .onAppear { inputFocused = true }
    }

    private func sendQuery() {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty, !isLoading else { return }
        let ctx = meetingContext
        guard !ctx.isEmpty else {
            errorMessage = "No completed meetings to search yet. Record a meeting first."
            return
        }

        query = ""
        errorMessage = nil
        isLoading = true

        Task {
            do {
                let systemPrompt = """
You are Ora, an AI meeting assistant with access to the user's complete meeting history.
Answer the user's question using only the information in the meeting transcripts and summaries provided.
Be specific — cite dates, names, and decisions when relevant.
If the answer isn't in any meeting, say so clearly.
Keep answers concise and actionable. Use bullet points for lists.
"""
                let userMessage = """
MEETING HISTORY:
\(ctx)

USER QUESTION: \(q)
"""
                let result = try await GroqClient.chat(messages: [
                    .init(role: "system", content: systemPrompt),
                    .init(role: "user", content: userMessage)
                ], temperature: 0.2, timeoutSeconds: 30)

                await MainActor.run {
                    history.append((q: q, a: result))
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}
