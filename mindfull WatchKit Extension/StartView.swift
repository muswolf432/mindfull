/*
See LICENSE folder for this sample’s licensing information.

Abstract:
This file defines the start view, where the user can start a workout.
*/

import SwiftUI
import Combine

struct StartView: View {
    
    @EnvironmentObject var workoutSession: WorkoutManager
    @EnvironmentObject var bleManager: BLEManager

    
    let startAction: (() -> Void)? // The start action callback.
    
    
    
    var body: some View {
        VStack {
            ZStack {
            Rectangle()
                .cornerRadius(0)
                .foregroundColor(bleManager.isConnected ? Color.green : Color.blue )
                .cornerRadius(30)
                .scaledToFit()
                Text(bleManager.isConnected ? "\(bleManager.peripheralName) \(bleManager.blBPM)" : "Searching")

            }

        RunButton(action: {
            self.startAction!() // FixMe!
        }).onAppear() {
            // Request HealthKit store authorization.
            self.workoutSession.requestAuthorization()
            // Pull avg HRV
            self.workoutSession.getHRVAverage()
            self.workoutSession.setup(self.bleManager)
            
        }
        
//         The HRV
        Text("Today's HRV: \(workoutSession.avgHRV, specifier: "%.0f") ms")
        Text("Last session: \(workoutSession.avgSDNN, specifier: "%.0f") ms")
        }
    }
}

struct InitialView_Previews: PreviewProvider {
    static var startAction = { }
    
    static var previews: some View {
        StartView(startAction: startAction)
        .environmentObject(WorkoutManager())
    }
}
