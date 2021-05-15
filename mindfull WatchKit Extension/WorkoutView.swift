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
    
    var body: some View {
        VStack(alignment: .center) {
            // The current heartrate.
            Text("\(workoutSession.heartrate, specifier: "%.0f") BPM")
            
            Text("\(workoutSession.HRV, specifier: "%.0f") ms")
            
            Text("\(workoutSession.elapsedSeconds) s")
                        
            Image("undertaleHeart")
                .resizable()
                .scaledToFit()
                .scaleEffect(self.isAnimating ? 0.9 : 1)
                        .onAppear(perform: {
                            // Call functions here
                            isAnimating = true
                        })
                .animation(
                    Animation.spring(response: SR).repeatForever(autoreverses: false))
                
                // Update animation to follow user heartrate
                .onChange(of: workoutSession.heartrate, perform: { value in
                    DispatchQueue.main.async {
                    SR = springResponse(liveHR: workoutSession.heartrate)
                    }
                })
            
//                .onChange(of: workoutSession.elapsedSeconds, perform: { value in
//                    print(workoutSession.elapsedSeconds)
//                    if workoutSession.elapsedSeconds % 10 == 0 {
//                        resonantHaptics(liveHR: workoutSession.heartrate)
//                    }
//                })
            
            Text("breathe with me")
                        
//            Print(workoutSession.elapsedSeconds, workoutSession.heartrate)
            
            }
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
