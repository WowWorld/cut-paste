import Foundation

struct ClipboardItem: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var kind: ClipboardKind
    var title: String
    var subtitle: String
    var content: String
    var sourceApp: String
    var createdAt: Date
    var lastUsedAt: Date?
    var isPinned: Bool
    var fingerprint: String
    var imageData: Data?
    var imageFileName: String?
    var imagePixelSize: PixelSize?
    var filePaths: [String]
    var colorHex: String?

    init(
        id: UUID = UUID(),
        kind: ClipboardKind,
        title: String,
        subtitle: String,
        content: String,
        sourceApp: String,
        createdAt: Date = Date(),
        lastUsedAt: Date? = nil,
        isPinned: Bool = false,
        fingerprint: String,
        imageData: Data? = nil,
        imageFileName: String? = nil,
        imagePixelSize: PixelSize? = nil,
        filePaths: [String] = [],
        colorHex: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.content = content
        self.sourceApp = sourceApp
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
        self.isPinned = isPinned
        self.fingerprint = fingerprint
        self.imageData = imageData
        self.imageFileName = imageFileName
        self.imagePixelSize = imagePixelSize
        self.filePaths = filePaths
        self.colorHex = colorHex
    }

    enum CodingKeys: String, CodingKey {
        case id
        case kind
        case title
        case subtitle
        case content
        case sourceApp
        case createdAt
        case lastUsedAt
        case isPinned
        case fingerprint
        case imageData
        case imageFileName
        case imagePixelSize
        case filePaths
        case colorHex
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        kind = try container.decode(ClipboardKind.self, forKey: .kind)
        title = try container.decode(String.self, forKey: .title)
        subtitle = try container.decode(String.self, forKey: .subtitle)
        content = try container.decode(String.self, forKey: .content)
        sourceApp = try container.decode(String.self, forKey: .sourceApp)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        lastUsedAt = try container.decodeIfPresent(Date.self, forKey: .lastUsedAt)
        isPinned = try container.decode(Bool.self, forKey: .isPinned)
        fingerprint = try container.decode(String.self, forKey: .fingerprint)
        imageData = try container.decodeIfPresent(Data.self, forKey: .imageData)
        imageFileName = try container.decodeIfPresent(String.self, forKey: .imageFileName)
        imagePixelSize = try container.decodeIfPresent(PixelSize.self, forKey: .imagePixelSize)
        filePaths = try container.decode([String].self, forKey: .filePaths)
        colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(kind, forKey: .kind)
        try container.encode(title, forKey: .title)
        try container.encode(subtitle, forKey: .subtitle)
        try container.encode(content, forKey: .content)
        try container.encode(sourceApp, forKey: .sourceApp)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(lastUsedAt, forKey: .lastUsedAt)
        try container.encode(isPinned, forKey: .isPinned)
        try container.encode(fingerprint, forKey: .fingerprint)
        try container.encodeIfPresent(imageFileName, forKey: .imageFileName)
        try container.encodeIfPresent(imagePixelSize, forKey: .imagePixelSize)
        try container.encode(filePaths, forKey: .filePaths)
        try container.encodeIfPresent(colorHex, forKey: .colorHex)
    }
}

struct PixelSize: Codable, Hashable, Sendable {
    var width: Int
    var height: Int
}

enum ClipboardKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case text
    case link
    case image
    case file
    case color

    var id: String { rawValue }
}

enum ClipboardFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case links
    case images
    case files
    case colors
    case pinned

    var id: String { rawValue }
}

enum HistoryRetention: Int, CaseIterable, Identifiable {
    case forever = 0
    case oneDay = 1
    case sevenDays = 7
    case thirtyDays = 30
    case ninetyDays = 90

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .forever:
            return "Forever"
        case .oneDay:
            return "1 day"
        case .sevenDays:
            return "7 days"
        case .thirtyDays:
            return "30 days"
        case .ninetyDays:
            return "90 days"
        }
    }
}
