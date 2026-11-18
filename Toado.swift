import SwiftUI
import ServiceManagement

struct Item: Identifiable, Codable {
    var id = UUID()
    var title: String
    var done = false
}

final class Store: ObservableObject {
    @Published var items: [Item] = [] { didSet { save() } }
    @Published var adding = false
    private let key = "items"

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode([Item].self, from: data) {
            items = saved
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

struct ContentView: View {
    @ObservedObject var store: Store
    @State private var newTitle = ""
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("My List")
                    .font(.headline.weight(.semibold))
                Spacer()
                Button {
                    store.adding.toggle()
                } label: {
                    Image(systemName: store.adding ? "minus" : "plus")
                }
                .buttonStyle(.borderless)
                .help(store.adding ? "Cancel" : "Add item")
            }

            Divider()

            if store.adding {
                TextField("New item", text: $newTitle)
                    .textFieldStyle(.roundedBorder)
                    .focused($fieldFocused)
                    .onSubmit(add)
                    .onExitCommand { store.adding = false }
                    .onAppear { fieldFocused = true }
            }

            if store.items.isEmpty {
                Text("Nothing here yet").foregroundStyle(.secondary)
            }

            ForEach($store.items) { $item in
                HStack {
                    Toggle(isOn: $item.done) {
                        Text(item.title)
                            .strikethrough(item.done)
                            .foregroundStyle(item.done ? .secondary : .primary)
                    }
                    .toggleStyle(.checkbox)
                    Spacer()
                    Button {
                        store.items.removeAll { $0.id == item.id }
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.borderless)
                }
            }

            Divider()
            HStack {
                Button("Clear done") { store.items.removeAll { $0.done } }
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
            .buttonStyle(.borderless)
        }
        .padding(12)
        .frame(width: 260)
    }

    private func add() {
        let t = newTitle.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        store.items.append(Item(title: t))
        newTitle = ""
        store.adding = false
    }
}

@main
struct ToadoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = Store()
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private let menu = NSMenu()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let hosting = NSHostingController(rootView: ContentView(store: store))
        hosting.sizingOptions = .preferredContentSize
        popover.contentViewController = hosting
        popover.behavior = .transient

        menu.addItem(withTitle: "Add New Item", action: #selector(addNewItem), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Toado", action: #selector(quit), keyEquivalent: "q")
        menu.items.forEach { $0.target = self }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "checklist", accessibilityDescription: "Toado")
            button.action = #selector(statusItemClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    @objc private func statusItemClicked() {
        let event = NSApp.currentEvent
        let isRightClick = event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true
        if isRightClick {
            popover.performClose(nil)
            menu.item(withTitle: "Launch at Login")?.state =
                SMAppService.mainApp.status == .enabled ? .on : .off
            // Attach the menu just for this click so left-click still opens the list
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    @objc private func addNewItem() {
        store.adding = true
        showPopover()
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Couldn't change Launch at Login"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
