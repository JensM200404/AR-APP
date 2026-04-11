import SwiftUI

@main
struct ARCemeteryNavigatorApp: App {
    var body: some Scene {
        WindowGroup {
            RootViewControllerRepresentable()
                .ignoresSafeArea()
                .statusBarHidden(true)
        }
    }
}


struct RootViewControllerRepresentable: UIViewControllerRepresentable {

    func makeUIViewController(context: Context) -> ViewController {
        return ViewController()
    }

    func updateUIViewController(_ uiViewController: ViewController, context: Context) {
        
    }
}
