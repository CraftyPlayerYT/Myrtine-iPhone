import SwiftUI
import MessageUI

struct MessageComposer: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let recipients: [String]

    func makeCoordinator() -> Coordinator { Coordinator(dismiss: dismiss) }
    func makeUIViewController(context: Context) -> UIViewController {
        guard MFMessageComposeViewController.canSendText() else {
            let controller = UIAlertController(title: "SMS indisponibles", message: "Cet appareil ne peut pas envoyer de SMS.", preferredStyle: .alert)
            controller.addAction(UIAlertAction(title: "Fermer", style: .cancel) { _ in dismiss() })
            return controller
        }
        let controller = MFMessageComposeViewController()
        controller.messageComposeDelegate = context.coordinator
        controller.recipients = recipients
        return controller
    }
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) { }

    final class Coordinator: NSObject, @MainActor MFMessageComposeViewControllerDelegate {
        let dismiss: DismissAction
        init(dismiss: DismissAction) { self.dismiss = dismiss }
        func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) { dismiss() }
    }
}
