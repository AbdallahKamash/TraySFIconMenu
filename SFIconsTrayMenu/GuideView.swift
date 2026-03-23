import SwiftUI

struct GuideView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How to Use TraySFIconMenu")
                .font(.title2)
                .bold()
                .padding(.bottom, 4)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    Image(systemName: "keyboard")
                        .frame(width: 24)
                    Text("Show & Hide Menu:\nPress Shift + Cmd + T")
                }
                
                HStack(alignment: .top) {
                    Image(systemName: "doc.on.doc")
                        .frame(width: 24)
                    Text("Copy Icons:\nRight-click, Space, or Enter on an icon")
                }
                
                HStack(alignment: .top) {
                    Image(systemName: "arrow.right.to.line")
                        .frame(width: 24)
                    Text("Navigate menu items:\nUse Tab to move focus.")
                }
            }
            .font(.body)
            
            Spacer()
            
            HStack {
                Spacer()
                Button("Got it") {
                    presentationMode.wrappedValue.dismiss()
                    if let win = NSApp.windows.first(where: { $0.title == "Guide" }) {
                        win.close()
                    }
                }
                .keyboardShortcut(.defaultAction)
                Spacer()
            }
        }
        .padding(20)
        .frame(width: 380, height: 260)
    }
}
