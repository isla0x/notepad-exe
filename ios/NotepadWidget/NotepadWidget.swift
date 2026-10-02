// notepad.exe 홈 화면 · 잠금화면 위젯
//
// 앱(Flutter)이 App Group 저장소에 "snapshot" 키로 JSON 을 넣으면 이 위젯이 읽어서 그린다.
// JSON 모양은 lib/widget_sync.dart 의 widgetSnapshot() 과 같다.
// 잠긴(숨긴) 메모는 앱이 아예 넣지 않는다.
//
// 지원 크기
//   홈 화면   : 작게 (고정한 메모) / 중간 (메모 + 파일 목록)
//   잠금 화면 : 직사각형 / 시계 위 한 줄

import SwiftUI
import WidgetKit

private let appGroupId = "group.com.isla0x.notepadexe"
private let snapshotKey = "snapshot"
/// ?homeWidget 은 home_widget 플러그인이 알아보는 표시
private let newURL = URL(string: "notepadexe://new?homeWidget")!
private func openURL(_ id: Int) -> URL { URL(string: "notepadexe://open?id=\(id)&homeWidget")! }

// MARK: - 데이터

struct WidgetNote: Decodable {
    let id: Int
    let name: String
    let pinned: Bool?
    /// "10-02 16:40"
    let when: String
    let lines: [String]
    /// 전체 줄 수
    let more: Int?
}

struct RecentItem: Decodable, Hashable {
    let id: Int
    let name: String
    let when: String
    /// <TXT> · <LOG>
    let kind: String
}

struct NotepadSnapshot: Decodable {
    let pro: Bool?
    /// auto | light | dark
    let mode: String?
    let count: Int
    let note: WidgetNote?
    let recent: [RecentItem]

    var isPro: Bool { pro ?? false }

    func isLight(_ scheme: ColorScheme) -> Bool {
        switch mode ?? "auto" {
        case "light": return true
        case "dark": return false
        default: return scheme == .light
        }
    }

    static let empty = NotepadSnapshot(pro: false, mode: "auto", count: 0, note: nil, recent: [])

    static let sample = NotepadSnapshot(
        pro: true, mode: "auto", count: 4,
        note: WidgetNote(id: 1, name: "장보기.txt", pinned: true, when: "10-02 16:40",
                         lines: ["우유 2개", "계란 한 판", "두부", "대파"], more: 4),
        recent: [
            RecentItem(id: 1, name: "장보기.txt", when: "10-02 16:40", kind: "<TXT>"),
            RecentItem(id: 2, name: "빠른 메모.txt", when: "10-02 15:31", kind: "<TXT>"),
            RecentItem(id: 3, name: "소설 아이디어.txt", when: "10-01 23:12", kind: "<TXT>"),
            RecentItem(id: 4, name: "출근 기록.txt", when: "10-01 09:03", kind: "<LOG>"),
        ]
    )

    static func load() -> NotepadSnapshot {
        guard
            let defaults = UserDefaults(suiteName: appGroupId),
            let raw = defaults.string(forKey: snapshotKey),
            let data = raw.data(using: .utf8),
            let snap = try? JSONDecoder().decode(NotepadSnapshot.self, from: data)
        else { return .empty }
        return snap
    }
}

// MARK: - 색 (앱과 같은 cmd 팔레트, 라이트면 종이 색)

struct TermColors {
    let bg, fg, hi, dim, acc, tag, cmd, warn, line: Color

    static func of(light: Bool) -> TermColors {
        if light {
            return TermColors(bg: Color(hex: 0xF5F2E8), fg: Color(hex: 0x2B2B2B), hi: Color(hex: 0x111111),
                              dim: Color(hex: 0x6B6B6B), acc: Color(hex: 0x1F5FD1), tag: Color(hex: 0x7A5F00),
                              cmd: Color(hex: 0x0B6E8A), warn: Color(hex: 0xC0282F), line: Color(hex: 0xD6D1C2))
        }
        return TermColors(bg: Color(hex: 0x0C0C0C), fg: Color(hex: 0xCCCCCC), hi: Color(hex: 0xF2F2F2),
                          dim: Color(hex: 0x8A8A8A), acc: Color(hex: 0x6CA6FF), tag: Color(hex: 0xF9F1A5),
                          cmd: Color(hex: 0x61D6D6), warn: Color(hex: 0xE74856), line: Color(hex: 0x2A2A2A))
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

private func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
    .system(size: size, weight: weight, design: .monospaced)
}

// MARK: - 타임라인

struct NotepadEntry: TimelineEntry {
    let date: Date
    let snap: NotepadSnapshot
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> NotepadEntry {
        NotepadEntry(date: .now, snap: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (NotepadEntry) -> Void) {
        completion(NotepadEntry(date: .now, snap: context.isPreview ? .sample : NotepadSnapshot.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NotepadEntry>) -> Void) {
        // 메모가 바뀌면 앱이 다시 그려 달라고 한다. 그 전엔 그대로.
        completion(Timeline(entries: [NotepadEntry(date: .now, snap: NotepadSnapshot.load())], policy: .never))
    }
}

// MARK: - 홈 화면 위젯

struct Header: View {
    let c: TermColors

    var body: some View {
        HStack(spacing: 5) {
            Text(">_").font(mono(11, .bold)).foregroundColor(c.acc)
            Text("notepad.exe").font(mono(11, .bold)).foregroundColor(c.hi)
        }
    }
}

struct PromptLine: View {
    let c: TermColors

    var body: some View {
        HStack(spacing: 4) {
            Text("C:\\notes>").font(mono(11)).foregroundColor(c.hi)
            Rectangle().fill(c.acc).frame(width: 7, height: 13)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .frame(height: 28)
        .overlay(Rectangle().stroke(c.line, lineWidth: 1))
    }
}

/// 고정한 메모(또는 최근 메모) 내용
struct NoteColumn: View {
    let note: WidgetNote?
    let c: TermColors
    let maxLines: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let n = note {
                HStack(spacing: 4) {
                    Text(n.name).font(mono(11, .bold)).foregroundColor(c.acc).lineLimit(1)
                    if n.pinned ?? false {
                        Text("pin").font(mono(9)).foregroundColor(c.dim)
                    }
                }
                if n.lines.isEmpty {
                    Text("(빈 파일)").font(mono(11)).foregroundColor(c.dim)
                } else {
                    ForEach(Array(n.lines.prefix(maxLines).enumerated()), id: \.offset) { _, line in
                        Text(line).font(mono(11)).foregroundColor(c.fg).lineLimit(1)
                    }
                }
            } else {
                Text("파일이 없어요").font(mono(11)).foregroundColor(c.dim)
                Text("edit 장보기").font(mono(11)).foregroundColor(c.cmd)
            }
            Spacer(minLength: 0)
        }
    }
}

struct SmallView: View {
    let snap: NotepadSnapshot
    let c: TermColors

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Header(c: c)
            NoteColumn(note: snap.note, c: c, maxLines: 5)
        }
        .padding(14)
        .widgetURL(snap.note.map { openURL($0.id) } ?? newURL)
    }
}

struct MediumView: View {
    let snap: NotepadSnapshot
    let c: TermColors

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Header(c: c)
                if let n = snap.note {
                    Link(destination: openURL(n.id)) { NoteColumn(note: n, c: c, maxLines: 5) }
                } else {
                    NoteColumn(note: nil, c: c, maxLines: 5)
                }
            }
            .frame(width: 138, alignment: .leading)
            Rectangle().fill(c.line).frame(width: 1)
            VStack(alignment: .leading, spacing: 3) {
                Text("dir · \(snap.count)개 파일").font(mono(10)).foregroundColor(c.dim)
                ForEach(snap.recent.prefix(3), id: \.self) { r in
                    Link(destination: openURL(r.id)) {
                        HStack(spacing: 5) {
                            Text(r.kind).font(mono(9)).foregroundColor(r.kind == "<LOG>" ? c.tag : c.dim)
                            Text(r.name).font(mono(11)).foregroundColor(c.hi).lineLimit(1)
                            Spacer(minLength: 0)
                        }
                    }
                }
                Spacer(minLength: 0)
                Link(destination: newURL) { PromptLine(c: c) }
            }
        }
        .padding(14)
        .widgetURL(newURL)
    }
}

// MARK: - 잠금화면 위젯

struct LockRectView: View {
    let snap: NotepadSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            if let n = snap.note {
                Text("> " + n.name).font(mono(12, .bold)).lineLimit(1).widgetAccentable()
                ForEach(Array(n.lines.prefix(2).enumerated()), id: \.offset) { _, line in
                    Text(line).font(mono(12)).lineLimit(1)
                }
            } else {
                Text("C:\\notes>").font(mono(12, .bold)).widgetAccentable()
                Text("파일이 없어요").font(mono(12))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(snap.note.map { openURL($0.id) } ?? newURL)
    }
}

struct LockInlineView: View {
    let snap: NotepadSnapshot

    var body: some View {
        if let n = snap.note {
            Text(">_ " + (n.lines.first ?? n.name))
        } else {
            Text(">_ notepad.exe")
        }
    }
}

// MARK: - PRO 가 아닐 때

struct LockedHomeView: View {
    let c: TermColors

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Header(c: c)
            (Text("C:\\notes> ").foregroundColor(c.dim) + Text("widget").foregroundColor(c.cmd))
                .font(mono(11))
            Text("Access is denied.").font(mono(12, .bold)).foregroundColor(c.warn)
            Text("위젯은 PRO 기능이에요.").font(mono(11)).foregroundColor(c.fg)
            Spacer(minLength: 0)
            (Text("앱에서 ").foregroundColor(c.dim) + Text("upgrade").foregroundColor(c.cmd))
                .font(mono(11))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .widgetURL(newURL)
    }
}

struct LockedAccessoryView: View {
    let family: WidgetFamily

    var body: some View {
        switch family {
        case .accessoryInline:
            Text(">_ notepad.exe · PRO 필요")
        default:
            VStack(alignment: .leading, spacing: 1) {
                Text("C:\\notes> widget").font(mono(12, .bold)).widgetAccentable()
                Text("Access is denied.").font(mono(12))
                Text("앱에서 upgrade").font(mono(12))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - 위젯 정의

struct NotepadWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var scheme
    let entry: NotepadEntry

    private var c: TermColors { TermColors.of(light: entry.snap.isLight(scheme)) }

    var body: some View {
        let snap = entry.snap
        let accessory = family == .accessoryRectangular || family == .accessoryInline
        if !snap.isPro {
            if accessory {
                LockedAccessoryView(family: family).containerBackground(for: .widget) { Color.clear }
            } else {
                LockedHomeView(c: c).containerBackground(for: .widget) { c.bg }
            }
        } else {
            switch family {
            case .accessoryRectangular:
                LockRectView(snap: snap).containerBackground(for: .widget) { Color.clear }
            case .accessoryInline:
                LockInlineView(snap: snap).containerBackground(for: .widget) { Color.clear }
            case .systemMedium:
                MediumView(snap: snap, c: c).containerBackground(for: .widget) { c.bg }
            default:
                SmallView(snap: snap, c: c).containerBackground(for: .widget) { c.bg }
            }
        }
    }
}

struct NotepadWidget: Widget {
    /// Flutter 쪽 WidgetSync.iOSWidgetKind 와 같아야 한다.
    let kind = "NotepadWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            NotepadWidgetView(entry: entry)
        }
        .configurationDisplayName("notepad.exe")
        .description("고정한 메모(pin)나 최근 메모를 보여줘요. 누르면 바로 열려요.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
        .contentMarginsDisabled()
    }
}

// MARK: - Xcode 미리보기

#Preview("작게", as: .systemSmall) {
    NotepadWidget()
} timeline: {
    NotepadEntry(date: .now, snap: .sample)
}

#Preview("중간", as: .systemMedium) {
    NotepadWidget()
} timeline: {
    NotepadEntry(date: .now, snap: .sample)
}

#Preview("잠금 직사각형", as: .accessoryRectangular) {
    NotepadWidget()
} timeline: {
    NotepadEntry(date: .now, snap: .sample)
}

#Preview("PRO 아님", as: .systemSmall) {
    NotepadWidget()
} timeline: {
    NotepadEntry(date: .now, snap: .empty)
}
