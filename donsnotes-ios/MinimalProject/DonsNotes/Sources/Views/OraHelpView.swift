import SwiftUI

// MARK: - Ora Help / Tutorial
// Accessible from the Profile screen (? button in toolbar).
// Covers every feature in the app — always available, no first-launch gating.

struct OraHelpView: View {
    @Environment(\.dismiss) var dismiss
    @State private var expandedSection: String? = nil

    var body: some View {
        ZStack {
            LM.Colors.void.ignoresSafeArea()

            // Subtle grid
            GeometryReader { geo in
                Path { p in
                    let s: CGFloat = 44
                    var x: CGFloat = 0
                    while x < geo.size.width { p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: geo.size.height)); x += s }
                    var y: CGFloat = 0
                    while y < geo.size.height { p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: geo.size.width, y: y)); y += s }
                }
                .stroke(LM.Colors.cyan.opacity(0.03), lineWidth: 0.5)
            }
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: LM.Space.md) {

                    // ── Hero ──────────────────────────────────────────────
                    VStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(LM.Colors.cyan.opacity(0.12))
                                .frame(width: 72, height: 72)
                            Circle()
                                .stroke(LM.Colors.cyan.opacity(0.5), lineWidth: 1)
                                .frame(width: 72, height: 72)
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 28, weight: .ultraLight))
                                .foregroundColor(LM.Colors.cyan)
                                .shadow(color: LM.Colors.cyan.opacity(0.8), radius: 8)
                        }
                        Text("ORA GUIDE")
                            .font(LM.Fonts.mono(13, weight: .bold))
                            .foregroundColor(LM.Colors.cyan)
                            .tracking(4)
                        Text("Everything Ora can do — in one place")
                            .font(LM.Fonts.text(13))
                            .foregroundColor(LM.Colors.textTertiary)
                    }
                    .padding(.top, LM.Space.lg)
                    .padding(.bottom, LM.Space.sm)

                    // ── Sections ─────────────────────────────────────────
                    Group {
                        HelpSection(
                            id: "start",
                            title: "Starting a Meeting",
                            icon: "mic.fill",
                            iconColor: LM.Colors.cyan,
                            expanded: expandedSection == "start",
                            onToggle: { toggle("start") },
                            steps: [
                                HelpStep(icon: "plus.circle.fill", color: LM.Colors.cyan,
                                         title: "Tap the + button",
                                         detail: "The cyan circle in the top-right corner of your meetings list opens a new recording session."),
                                HelpStep(icon: "person.badge.plus", color: LM.Colors.cyan,
                                         title: "Add attendees (optional)",
                                         detail: "Type a name and email, then tap Add — or tap a saved contact from Quick Add at the top. Attendees appear in your recap email automatically."),
                                HelpStep(icon: "mic.fill", color: .green,
                                         title: "Tap Start Recording",
                                         detail: "Ora begins capturing everything. The timer starts and you'll see the live orb. No bot joins your call — Ora runs entirely on your device."),
                                HelpStep(icon: "waveform", color: .green,
                                         title: "Just talk",
                                         detail: "Ora transcribes in real time. You don't need to do anything — just run your meeting normally."),
                            ]
                        )

                        HelpSection(
                            id: "voice",
                            title: "Say \"Ora\" Mid-Meeting",
                            icon: "waveform.badge.mic",
                            iconColor: .green,
                            expanded: expandedSection == "voice",
                            onToggle: { toggle("voice") },
                            steps: [
                                HelpStep(icon: "waveform.badge.mic", color: .green,
                                         title: "Speak the wake word",
                                         detail: "Say \"Ora\" (the app hears it as \"aura\") at any point during a recording. The orb lights up — you're now in AI mode."),
                                HelpStep(icon: "questionmark.bubble.fill", color: .green,
                                         title: "Ask anything",
                                         detail: "\"Ora, what did we decide about the budget?\" or \"Ora, summarize what's been said so far.\" Ora answers out loud in Lily's voice."),
                                HelpStep(icon: "hand.tap.fill", color: LM.Colors.cyan,
                                         title: "Or tap the orb",
                                         detail: "Tapping the orb during recording also activates Ora — useful in a quiet room where speaking feels awkward."),
                                HelpStep(icon: "stop.fill", color: .red,
                                         title: "Stop Ora speaking",
                                         detail: "If Ora is mid-answer and you need to cut it off, tap the red STOP button that appears below the orb."),
                            ]
                        )

                        HelpSection(
                            id: "brief",
                            title: "Pre-Meeting Brief",
                            icon: "clock.arrow.circlepath",
                            iconColor: LM.Colors.cyan,
                            expanded: expandedSection == "brief",
                            onToggle: { toggle("brief") },
                            steps: [
                                HelpStep(icon: "clock.arrow.circlepath", color: LM.Colors.cyan,
                                         title: "Automatic — no setup needed",
                                         detail: "The moment you add an attendee before recording, Ora checks if you've ever met with them before."),
                                HelpStep(icon: "doc.text.magnifyingglass", color: LM.Colors.cyan,
                                         title: "See the last meeting instantly",
                                         detail: "A card appears showing the date, what was discussed, and any open action items from your last session with those people."),
                                HelpStep(icon: "chevron.down.circle", color: LM.Colors.textTertiary,
                                         title: "Tap to expand or collapse",
                                         detail: "The brief is collapsed by default so it stays out of the way. Tap it to read the full summary before you start."),
                            ]
                        )

                        HelpSection(
                            id: "after",
                            title: "After the Meeting",
                            icon: "checkmark.circle.fill",
                            iconColor: .green,
                            expanded: expandedSection == "after",
                            onToggle: { toggle("after") },
                            steps: [
                                HelpStep(icon: "stop.circle.fill", color: .red,
                                         title: "Tap Stop Recording",
                                         detail: "Ora immediately starts transcribing and summarizing. You'll see a processing spinner — this usually takes 15–30 seconds."),
                                HelpStep(icon: "envelope.fill", color: LM.Colors.cyan,
                                         title: "Recap email is sent automatically",
                                         detail: "As soon as Ora finishes, a full recap email fires to everyone you listed as an attendee. It includes the summary, action items, Ora Insights, and the full transcript."),
                                HelpStep(icon: "checkmark.circle", color: .green,
                                         title: "Status turns to Email Sent",
                                         detail: "The badge on your meeting card turns green and shows \"Email Sent\" once the recap has been delivered."),
                            ]
                        )

                        HelpSection(
                            id: "detail",
                            title: "Inside a Meeting",
                            icon: "doc.text.fill",
                            iconColor: LM.Colors.cyan,
                            expanded: expandedSection == "detail",
                            onToggle: { toggle("detail") },
                            steps: [
                                HelpStep(icon: "pencil", color: LM.Colors.cyan,
                                         title: "Rename the meeting",
                                         detail: "Tap the meeting title (or the pencil icon next to it) at the top of the detail screen. Type a new name and tap the checkmark — or press Done on the keyboard. The name is saved permanently."),
                                HelpStep(icon: "play.fill", color: LM.Colors.cyan,
                                         title: "Play back the recording",
                                         detail: "The audio player is at the top of every meeting. Tap play, scrub the bar to jump around, or use the ±15s skip buttons. Tap the speed bar to play at 0.5×, 1×, 1.5×, or 2×."),
                                HelpStep(icon: "checkmark.circle.fill", color: .green,
                                         title: "Action items",
                                         detail: "Ora automatically extracts every task, commitment, and next step mentioned in the meeting. They appear in the green card below the attendees."),
                                HelpStep(icon: "sparkles", color: .purple,
                                         title: "Ora Insights",
                                         detail: "Any questions you asked Ora during the recording appear here as a Q&A log — so you can review every AI answer without re-reading the full transcript."),
                                HelpStep(icon: "doc.text.fill", color: LM.Colors.textTertiary,
                                         title: "Full transcript",
                                         detail: "Every word, scrollable. Long-press any text to copy a passage. Use the search bar on the meetings list to find specific words across all your meetings."),
                                HelpStep(icon: "person.2.fill", color: LM.Colors.cyan,
                                         title: "Speaker ID",
                                         detail: "When attendees are added before the meeting, Ora automatically identifies who said what. The transcript shows each turn as \"Name: text\" with names highlighted in cyan — and a SPEAKERS badge appears at the top of the transcript card. The recap email also sends the attributed version so everyone sees who said what."),
                            ]
                        )

                        HelpSection(
                            id: "chat",
                            title: "Ask ORA About This Meeting",
                            icon: "bubble.left.and.bubble.right.fill",
                            iconColor: LM.Colors.cyan,
                            expanded: expandedSection == "chat",
                            onToggle: { toggle("chat") },
                            steps: [
                                HelpStep(icon: "chevron.down", color: LM.Colors.cyan,
                                         title: "Tap Ask ORA to expand",
                                         detail: "On any completed meeting, scroll down to the Ask ORA section and tap the chevron to open the chat."),
                                HelpStep(icon: "sparkle", color: LM.Colors.cyan,
                                         title: "Tap a suggested question",
                                         detail: "Ora starts you off with \"What decisions were made?\", \"List all action items\", \"What were the key topics?\", and \"Who said what?\" — tap any to send instantly."),
                                HelpStep(icon: "keyboard", color: LM.Colors.textSecondary,
                                         title: "Or type anything",
                                         detail: "\"Did anyone commit to a deadline?\", \"What was the mood of the meeting?\", \"Give me a one-sentence summary for my boss.\" Ora answers using only what was said in this meeting."),
                            ]
                        )

                        HelpSection(
                            id: "askoraall",
                            title: "Ask ORA Across All Meetings",
                            icon: "brain.head.profile",
                            iconColor: LM.Colors.cyan,
                            expanded: expandedSection == "askoraall",
                            onToggle: { toggle("askoraall") },
                            steps: [
                                HelpStep(icon: "brain.head.profile", color: LM.Colors.cyan,
                                         title: "Tap the brain icon in the toolbar",
                                         detail: "On your meetings list, tap the cyan brain icon (top right, next to your profile). This opens Ask Ora — your cross-meeting memory search."),
                                HelpStep(icon: "magnifyingglass", color: LM.Colors.cyan,
                                         title: "Search across every meeting at once",
                                         detail: "Ask \"What action items are still open?\", \"When did we last discuss the budget?\", or \"Summarize last week's meetings.\" Ora searches your entire history and answers in plain language."),
                                HelpStep(icon: "sparkle", color: LM.Colors.cyan,
                                         title: "Use the suggested prompts",
                                         detail: "Six ready-made prompts appear on the empty state — tap one to get started without typing anything."),
                                HelpStep(icon: "trash", color: LM.Colors.textTertiary,
                                         title: "Clear the conversation",
                                         detail: "Tap Clear (top right) to reset the chat and start a fresh question."),
                            ]
                        )

                        HelpSection(
                            id: "emails",
                            title: "Emails & Sharing",
                            icon: "envelope.fill",
                            iconColor: LM.Colors.cyan,
                            expanded: expandedSection == "emails",
                            onToggle: { toggle("emails") },
                            steps: [
                                HelpStep(icon: "envelope.fill", color: LM.Colors.cyan,
                                         title: "Send Recap Email",
                                         detail: "Sends the full meeting recap — summary, action items, Ora Insights, and transcript — to all attendees. When Speaker ID ran successfully, the email includes an attributed transcript (\"Name: text\" format) so recipients know who said what. Tap Resend Recap if you need to send it again."),
                                HelpStep(icon: "wand.and.stars", color: LM.Colors.cyan,
                                         title: "Draft Follow-Up Email",
                                         detail: "Ora writes a professional follow-up email (~200 words) using your action items and meeting summary. Tap it and Mail opens with the To: field already filled in from your attendees. Edit before sending."),
                                HelpStep(icon: "square.and.arrow.up", color: LM.Colors.textSecondary,
                                         title: "Share Meeting Notes",
                                         detail: "Exports the full meeting as plain text — great for pasting into Slack, Notion, or sending to someone who wasn't on the call."),
                            ]
                        )

                        HelpSection(
                            id: "repeat",
                            title: "Repeat Meeting",
                            icon: "arrow.clockwise",
                            iconColor: LM.Colors.cyan,
                            expanded: expandedSection == "repeat",
                            onToggle: { toggle("repeat") },
                            steps: [
                                HelpStep(icon: "arrow.clockwise", color: LM.Colors.cyan,
                                         title: "Tap Repeat Meeting",
                                         detail: "Appears at the bottom of any meeting that had attendees. Opens a new recording session with the same attendees already loaded — no re-entering names or emails."),
                                HelpStep(icon: "clock.arrow.circlepath", color: LM.Colors.cyan,
                                         title: "Brief shows automatically",
                                         detail: "Because attendees are pre-loaded, the pre-meeting brief card also appears immediately — showing what you covered last time with these same people."),
                            ]
                        )

                        HelpSection(
                            id: "list",
                            title: "Managing Your Meetings",
                            icon: "list.bullet.rectangle",
                            iconColor: LM.Colors.textSecondary,
                            expanded: expandedSection == "list",
                            onToggle: { toggle("list") },
                            steps: [
                                HelpStep(icon: "magnifyingglass", color: LM.Colors.textSecondary,
                                         title: "Search all meetings",
                                         detail: "The search bar at the top searches meeting titles, summaries, transcripts, and attendee names simultaneously. Results update as you type."),
                                HelpStep(icon: "archivebox", color: LM.Colors.textSecondary,
                                         title: "Archive a meeting",
                                         detail: "Swipe left on any meeting card to reveal Archive. Archived meetings move out of your main list. Tap the archive icon in the toolbar to view them. Swipe left again to unarchive."),
                                HelpStep(icon: "trash.fill", color: .red,
                                         title: "Delete a meeting",
                                         detail: "Swipe left on any meeting card. Tap Delete (red). You'll see a confirmation before anything is removed — this cannot be undone."),
                                HelpStep(icon: "tray.full", color: LM.Colors.cyan,
                                         title: "View archived meetings",
                                         detail: "Tap the archive box icon in the top-right toolbar. The list switches to show only archived meetings. Tap again to return to active meetings."),
                            ]
                        )

                        HelpSection(
                            id: "profile",
                            title: "Profile & Settings",
                            icon: "person.circle.fill",
                            iconColor: LM.Colors.textSecondary,
                            expanded: expandedSection == "profile",
                            onToggle: { toggle("profile") },
                            steps: [
                                HelpStep(icon: "person.circle", color: LM.Colors.textSecondary,
                                         title: "Open Profile",
                                         detail: "Tap the person icon in the top-right of your meetings list. Set your display name — it appears as the organizer on every recap email."),
                                HelpStep(icon: "gift.fill", color: LM.Colors.cyan,
                                         title: "Refer a friend",
                                         detail: "Share your 6-character referral code. When a friend enters it, they get 30 days of Ora Pro free — and so do you. Tap Copy or Share to send your code."),
                                HelpStep(icon: "chart.bar.fill", color: LM.Colors.textSecondary,
                                         title: "Ora Usage",
                                         detail: "See how many chat calls and transcriptions you've used today. Ora runs on Groq's free tier — limits reset daily. You'll almost never hit them in normal use."),
                                HelpStep(icon: "creditcard.fill", color: LM.Colors.cyan,
                                         title: "Upgrade to Ora Pro",
                                         detail: "Tap View Plans & Pricing to see subscription options. Ora Pro removes limits and unlocks advanced features. Tap Restore Purchases if you've already subscribed on another device."),
                            ]
                        )
                    }

                    // ── Tips footer ──────────────────────────────────────
                    LUMENCard {
                        VStack(alignment: .leading, spacing: 12) {
                            LUMENSectionHeader(title: "Pro Tips", icon: "lightbulb.fill", color: .yellow)
                            VStack(alignment: .leading, spacing: 10) {
                                TipRow(text: "You don't tap to activate Ora — just say \"Ora\" and it wakes up mid-meeting.")
                                TipRow(text: "Add attendees before starting so the recap email fires automatically when you stop.")
                                TipRow(text: "Use Repeat Meeting for weekly standups — same team, no setup, brief appears instantly.")
                                TipRow(text: "Draft Follow-Up Email is fastest way to send action items after a client call.")
                                TipRow(text: "Ask Ora (brain icon) is your meeting memory — use it before any follow-up to catch what was decided.")
                                TipRow(text: "Rename meetings right after they end — it makes search much more useful over time.")
                                TipRow(text: "Add attendees before recording so Speaker ID can label who said what in your transcript and recap email.")
                            }
                        }
                    }
                    .padding(.horizontal, LM.Space.md)

                    Spacer(minLength: LM.Space.xl)
                }
                .padding(.horizontal, LM.Space.md)
                .padding(.bottom, LM.Space.xl)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("HOW TO USE ORA")
                    .font(LM.Fonts.mono(11, weight: .bold))
                    .foregroundColor(LM.Colors.cyan)
                    .tracking(3)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") { dismiss() }
                    .font(LM.Fonts.text(14))
                    .foregroundColor(LM.Colors.cyan)
            }
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
        .preferredColorScheme(.dark)
    }

    private func toggle(_ id: String) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            expandedSection = expandedSection == id ? nil : id
        }
    }
}

// MARK: - Help Section (accordion)
private struct HelpSection: View {
    let id: String
    let title: String
    let icon: String
    let iconColor: Color
    let expanded: Bool
    let onToggle: () -> Void
    let steps: [HelpStep]

    var body: some View {
        VStack(spacing: 0) {
            // Header button
            Button(action: onToggle) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(iconColor.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: icon)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(iconColor)
                    }
                    Text(title)
                        .font(LM.Fonts.text(14, weight: .semibold))
                        .foregroundColor(LM.Colors.textPrimary)
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(LM.Colors.textTertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)

            // Steps (collapsed by default)
            if expanded {
                Divider()
                    .background(LM.Colors.borderCyan.opacity(0.3))

                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
                        HStack(alignment: .top, spacing: 12) {
                            // Step number + icon
                            VStack(spacing: 4) {
                                ZStack {
                                    Circle()
                                        .fill(step.color.opacity(0.12))
                                        .frame(width: 30, height: 30)
                                    Image(systemName: step.icon)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(step.color)
                                }
                                if i < steps.count - 1 {
                                    Rectangle()
                                        .fill(LM.Colors.borderDim)
                                        .frame(width: 1, height: 20)
                                }
                            }
                            .frame(width: 30)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(step.title)
                                    .font(LM.Fonts.text(13, weight: .semibold))
                                    .foregroundColor(LM.Colors.textPrimary)
                                Text(step.detail)
                                    .font(LM.Fonts.text(12))
                                    .foregroundColor(LM.Colors.textTertiary)
                                    .lineSpacing(4)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.bottom, i < steps.count - 1 ? 20 : 8)
                        }
                        .padding(.horizontal, 14)
                        .padding(.top, i == 0 ? 14 : 0)
                    }
                }
            }
        }
        .background(LM.Colors.surface)
        .cornerRadius(LM.Radius.md)
        .overlay(
            RoundedRectangle(cornerRadius: LM.Radius.md)
                .stroke(expanded ? LM.Colors.borderCyan : LM.Colors.borderDim, lineWidth: 1)
        )
    }
}

// MARK: - Step model
private struct HelpStep {
    let icon: String
    let color: Color
    let title: String
    let detail: String
}

// MARK: - Pro Tip row
private struct TipRow: View {
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 10))
                .foregroundColor(.yellow)
                .padding(.top, 3)
            Text(text)
                .font(LM.Fonts.text(12))
                .foregroundColor(LM.Colors.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    NavigationView {
        OraHelpView()
    }
}
