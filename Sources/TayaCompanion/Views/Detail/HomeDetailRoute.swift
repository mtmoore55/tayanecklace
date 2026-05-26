import Foundation

/// One of the three entity sheets that Today's People / Places / Themes
/// chips can present. Identifiable so `.sheet(item:)` can switch between
/// them without state collisions.
enum HomeDetailRoute: Identifiable, Hashable {
    case person(Person.ID)
    case place(String)
    case theme(String)

    var id: String {
        switch self {
        case .person(let id): return "person-\(id.uuidString)"
        case .place(let p):   return "place-\(p)"
        case .theme(let t):   return "theme-\(t)"
        }
    }
}
