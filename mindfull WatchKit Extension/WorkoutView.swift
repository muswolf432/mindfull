/*
See LICENSE folder for this sample’s licensing information.

Abstract:
This file defines the workout view.
*/

import SwiftUI

// Models

// View Models

// Views
struct WorkoutView: View {
    @EnvironmentObject var workoutSession: WorkoutManager
    @State private var isAnimating = false
    @State private var SR = 1.0
    @State private var offsetCopies = false // Offset breathing circles
    
    @EnvironmentObject var bleManager: BLEManager

    
    var body: some View {
        
        
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            ZStack {
                ForEach(0..<6) {
                    LinearGradient(gradient: Gradient(colors: [Color(red: 0, green: 1, blue: 1), Color(red: 0, green: 1, blue: 1)]), startPoint: .leading, endPoint: .trailing)
                        .clipShape(Circle())
                        .foregroundColor(Color(red: 0, green: 1, blue: 1))
                        .frame(width: 60, height: 60)
                        .opacity(0.5)
                        .blendMode(.hardLight)
                        .offset(x: workoutSession.breathing ? 30 : 0)
                        .rotationEffect(.degrees(Double($0) * 60))
                }
            }
            .rotationEffect(.degrees(workoutSession.breathing ? 120 : 0))
            .scaleEffect(workoutSession.breathing ? 1.45 : 0.5)
            .animation(Animation.easeInOut(duration: 4))
            .onAppear() {
                workoutSession.breathing = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                    withAnimation(Animation.easeInOut(duration: 6)) {
                        workoutSession.breathing = false
                        workoutSession.getHRVAverage()
                    }
                }
            }
            Image(systemName: "arrow.up.heart")
                .resizable()
                .frame(width: 50, height: 50)
                .foregroundColor(.red)
                .opacity(workoutSession.success ? 0.8 : 0)
                .animation(.default)
            VStack {
                Spacer()
                
                RoundedRectangle(cornerRadius: 20)
                    .frame(width: workoutSession.SDNNScore, height: 20, alignment: .leading)
                    .opacity(/*@START_MENU_TOKEN@*/0.8/*@END_MENU_TOKEN@*/)
                    .foregroundColor(.green)
                    .animation(.easeInOut)

            }
            
            VStack {
                Text(String(format: "HRV: %.0f ms", workoutSession.SDNNScore > 1 ? workoutSession.SDNNScore : workoutSession.avgSDNN))
//                Text(String(format: "avgHRV: %.0f ms", workoutSession.avgHRV))
                Text("\(bleManager.blBPM)")
                Spacer()
            }


        } // End of Z-stack

        }
    }

    // Compute the spring response if not nil
    func springResponse(liveHR: Double) -> Double {
        if liveHR == 0 {
            return 1
        }
        else {
            return liveHR/60
        }
    }

    // Every 10s, call haptics function
    func resonantHaptics(liveHR: Double) {
        if liveHR < 65 {
            print("success")
            WKInterfaceDevice.current().play(.success)
        }
        else {
            print("playing haptics")
            DispatchQueue.main.async {
                WKInterfaceDevice.current().play(.directionUp)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) { WKInterfaceDevice.current().play(.directionDown)}
            DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
                // Wait 6s
            }
        }
    }



struct WorkoutView_Previews: PreviewProvider {
    static var previews: some View {
        WorkoutView().environmentObject(WorkoutManager())
    }
}

// Enables printing to console
extension View {
    func Print(_ vars: Any...) -> some View {
        for v in vars { print(v) }
        return EmptyView()
    }
}
