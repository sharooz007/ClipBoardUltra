import Cocoa

/// Represents a single file or directory held temporarily in the Drop Shelf.
public struct DropShelfItem: Identifiable, Equatable {
    public let id: UUID
    public let url: URL
    public let name: String
    public let isDirectory: Bool
    public let fileSize: Int64
    public let icon: NSImage

    public init(url: URL) {
        self.id = UUID()
        self.url = url
        self.name = url.lastPathComponent
        
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) {
            self.isDirectory = isDir.boolValue
        } else {
            self.isDirectory = false
        }

        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? Int64 {
            self.fileSize = size
        } else {
            self.fileSize = 0
        }

        self.icon = NSWorkspace.shared.icon(forFile: url.path)
    }

    public var formattedSize: String {
        if isDirectory {
            return "Folder"
        }
        let bcf = ByteCountFormatter()
        bcf.allowedUnits = [.useAll]
        bcf.countStyle = .file
        return bcf.string(fromByteCount: fileSize)
    }

    public static func == (lhs: DropShelfItem, rhs: DropShelfItem) -> Bool {
        lhs.id == rhs.id || lhs.url == rhs.url
    }
}
