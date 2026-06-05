import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// SwiftUI wrapper around `UITableView` that delivers the real system
/// swipe-to-act experience (UIKit's `UISwipeActionsConfiguration`) inside
/// a container that intrinsically sizes to its content. Use when a
/// vertically-bounded layout — e.g. a glass `Card` inside the home
/// `ScrollView` — needs native swipe behaviour that SwiftUI's `List`
/// can't deliver in a non-list parent.
///
/// Rows render arbitrary SwiftUI content via `UIHostingConfiguration`,
/// and the table reports its full `contentSize.height` as its intrinsic
/// size so the surrounding SwiftUI layout can place it like any other
/// naturally-sized vertical view.
///
/// macOS: falls back to a plain `VStack` (no swipe affordance — AppKit
/// has no direct equivalent and the package's macOS slice exists mainly
/// for previews/tests).
struct SwipeListView<Item: Identifiable, Cell: View>: View {
    let items: [Item]
    let trailingActions: (Item) -> [SwipeAction]
    let cell: (Item) -> Cell

    init(
        items: [Item],
        trailingActions: @escaping (Item) -> [SwipeAction] = { _ in [] },
        @ViewBuilder cell: @escaping (Item) -> Cell
    ) {
        self.items = items
        self.trailingActions = trailingActions
        self.cell = cell
    }

    var body: some View {
        #if canImport(UIKit)
        SwipeListRepresentable(
            items: items,
            trailingActions: trailingActions,
            cell: cell
        )
        #else
        VStack(spacing: 0) {
            ForEach(items) { cell($0) }
        }
        #endif
    }
}

#if canImport(UIKit)

private struct SwipeListRepresentable<Item: Identifiable, Cell: View>: UIViewRepresentable {
    let items: [Item]
    let trailingActions: (Item) -> [SwipeAction]
    let cell: (Item) -> Cell

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> SelfSizingTableView {
        let table = SelfSizingTableView(frame: .zero, style: .plain)
        table.dataSource = context.coordinator
        table.delegate = context.coordinator
        table.backgroundColor = .clear
        table.separatorColor = UIColor(white: 1, alpha: 0.15)
        table.separatorInset = UIEdgeInsets(top: 0, left: 14, bottom: 0, right: 14)
        table.rowHeight = UITableView.automaticDimension
        table.estimatedRowHeight = 64
        table.isScrollEnabled = false
        table.contentInsetAdjustmentBehavior = .never
        table.contentInset = .zero
        table.register(HostingCell.self, forCellReuseIdentifier: HostingCell.reuseID)
        return table
    }

    func updateUIView(_ table: SelfSizingTableView, context: Context) {
        context.coordinator.parent = self
        table.reloadData()
    }

    final class Coordinator: NSObject, UITableViewDataSource, UITableViewDelegate {
        var parent: SwipeListRepresentable<Item, Cell>

        init(parent: SwipeListRepresentable<Item, Cell>) {
            self.parent = parent
        }

        func tableView(_: UITableView, numberOfRowsInSection: Int) -> Int {
            parent.items.count
        }

        func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            let cell = tableView.dequeueReusableCell(
                withIdentifier: HostingCell.reuseID, for: indexPath
            )
            let item = parent.items[indexPath.row]
            let cellBuilder = parent.cell
            cell.contentConfiguration = UIHostingConfiguration { cellBuilder(item) }
                .margins(.all, 0)
            cell.backgroundColor = .clear
            return cell
        }

        func tableView(
            _: UITableView,
            trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
        ) -> UISwipeActionsConfiguration? {
            let item = parent.items[indexPath.row]
            let actions = parent.trailingActions(item)
            guard !actions.isEmpty else { return nil }

            let ui = actions.map { spec -> UIContextualAction in
                let style: UIContextualAction.Style =
                    spec.role == .destructive ? .destructive : .normal
                // Title is intentionally empty: UIKit picks the title's
                // text colour from a contrast heuristic against the
                // background, and there's no API to override it. We bake
                // icon + label into one white image so we control the
                // foreground colour explicitly.
                let action = UIContextualAction(style: style, title: "") { _, _, completion in
                    spec.action()
                    completion(true)
                }
                action.image = Self.iconWithLabel(
                    systemImage: spec.systemImage,
                    label: spec.label
                )
                action.backgroundColor = UIColor(spec.tint)
                action.accessibilityLabel = spec.label
                return action
            }
            return UISwipeActionsConfiguration(actions: ui)
        }

        private static func iconWithLabel(systemImage: String, label: String) -> UIImage? {
            let iconConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
            guard let raw = UIImage(systemName: systemImage, withConfiguration: iconConfig) else {
                return nil
            }
            let icon = raw.withTintColor(.white, renderingMode: .alwaysOriginal)
            let labelFont = UIFont.systemFont(ofSize: 12, weight: .semibold)
            let labelAttrs: [NSAttributedString.Key: Any] = [
                .font: labelFont,
                .foregroundColor: UIColor.white
            ]
            let labelSize = (label as NSString).size(withAttributes: labelAttrs)
            let spacing: CGFloat = 4
            let width = ceil(max(icon.size.width, labelSize.width))
            let height = ceil(icon.size.height + spacing + labelSize.height)
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
            let composite = renderer.image { _ in
                icon.draw(in: CGRect(
                    x: (width - icon.size.width) / 2,
                    y: 0,
                    width: icon.size.width,
                    height: icon.size.height
                ))
                (label as NSString).draw(
                    at: CGPoint(
                        x: (width - labelSize.width) / 2,
                        y: icon.size.height + spacing
                    ),
                    withAttributes: labelAttrs
                )
            }
            // alwaysOriginal so UIKit doesn't re-tint our hand-rendered
            // white pixels against the action's tint colour.
            return composite.withRenderingMode(.alwaysOriginal)
        }
    }
}

/// `UITableView` subclass that reports `contentSize.height` as its
/// intrinsic height. With `isScrollEnabled = false` and this override,
/// SwiftUI places the table by its real measured size — no estimated
/// row heights, no PreferenceKey acrobatics.
private final class SelfSizingTableView: UITableView {
    override var intrinsicContentSize: CGSize {
        layoutIfNeeded()
        return CGSize(width: UIView.noIntrinsicMetric, height: contentSize.height)
    }

    override var contentSize: CGSize {
        didSet {
            if oldValue.height != contentSize.height {
                invalidateIntrinsicContentSize()
            }
        }
    }
}

/// `UITableViewCell` that hosts arbitrary SwiftUI content via its
/// `contentConfiguration`. One reuse identifier is enough because
/// `UIHostingConfiguration` handles content type internally.
private final class HostingCell: UITableViewCell {
    static let reuseID = "SwipeListView.HostingCell"

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }
}

#endif
