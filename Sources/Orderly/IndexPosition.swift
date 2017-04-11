/// Option that indices which insertion index to use when multiple
/// possibilities exist (in the case of duplicate matching elements).
public enum IndexPosition {
    /// The least possible index.
    case least
    /// The greatest possible index.
    case greatest
    /// The most efficient index to locate.
    case any
}
