/*
See LICENSE folder for this sample’s licensing information.

Abstract:
This file defines the Run button.
*/

import SwiftUI
import UIKit

// Custom button style of the run button.
struct RunStyle: ButtonStyle {
    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        Circle()
            .fill(Color(UIColor.white))
            .overlay(
                configuration.label
                    .foregroundColor(.black)
            )
            .frame(width: 130, height: 130)
    }
}

struct RunButton: View {
    var action = { print("Run button tapped!") }
    
    var body: some View {
        Button(action: { self.action() }) {
            Text("mindfull")
                .font(.title3)
                .fontWeight(.bold)
            Text("tap to start")
                .font(.subheadline)
        }
        .buttonStyle(RunStyle())
    }
}

struct RunButton_Previews: PreviewProvider {
    static var previews: some View {
        RunButton()
    }
}
