/// Option that indices which insertion index to use when multiple
/// possibilities exist (in the case of duplicate matching elements).
public enum IndexPosition {
    /// The first possible index.
    case first
    /// The last possible index.
    case last
    /// The most efficient index to locate.
    case any
}

