import AppKit

/// Block views conform to this to provide their copyable text.
protocol CopyableBlock {
    var copyableText: String { get }
}
