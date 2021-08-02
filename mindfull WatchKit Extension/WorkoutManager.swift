/*
See LICENSE folder for this sample’s licensing information.

Abstract:
This file contains the business logic, which is the interface to HealthKit.
*/

import Foundation
import HealthKit
import Combine
import WatchKit
import Smooth


class WorkoutManager: NSObject, ObservableObject {
    
    /// - Tag: DeclareSessionBuilder
    let healthStore = HKHealthStore()
    var session: HKWorkoutSession!
    var builder: HKLiveWorkoutBuilder!
    var heartRateSamples = [Double]()
    var accurateHRSamples = [Int]()
    
    
    var bleManager: BLEManager?
      
    func setup(_ bleManager: BLEManager) {
        self.bleManager = bleManager
    }

    
    // Publish the following:
    // - heartrate
    // - active calories
    // - distance moved
    // - elapsed time
    
    /// - Tag: Publishers
    @Published var heartrate: Double = 0
    @Published var activeCalories: Double = 0
    @Published var distance: Double = 0
    @Published var elapsedSeconds: Int = 0
    @Published var HRV: Double = 0
    @Published var breathing = false // Track inhale/exhales
    @Published var success = false // Track user success
    @Published var SDNNScore: CGFloat = 0.1
    @Published var oldSDNNScore: CGFloat = 0.1
    @Published var avgHRV: Double = 0
    @Published var avgSDNN: Double = 0
    @Published var successCount = 0
    @Published var failCount = 0
    @Published var smoothBeatsArray = [Double]()
    @Published var smoothRRArray = [Double]()

    

    
    
    // The app's workout state.
    var running: Bool = false
    
    /// - Tag: TimerSetup
    // The cancellable holds the timer publisher.
    var start: Date = Date()
    var cancellable: Cancellable?
    var accumulatedTime: Int = 0
    var timer: Timer? // my timer
    var breatheTimer: Timer?
    
    // Set up and start the timer.
    func setUpTimer() {
        start = Date()
        cancellable = Timer.publish(every: 1, on: .main, in: .default)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.elapsedSeconds = self.incrementElapsedTime()
            }
    }
    
    // Calculate the elapsed time.
    func incrementElapsedTime() -> Int {
        let runningTime: Int = Int(-1 * (self.start.timeIntervalSinceNow))
        return self.accumulatedTime + runningTime
    }
    
    // Request authorization to access HealthKit.
    func requestAuthorization() {
        // Requesting authorization.
        /// - Tag: RequestAuthorization
        // The quantity type to write to the health store.
        let typesToShare: Set = [
            HKQuantityType.workoutType(),
            HKObjectType.categoryType(forIdentifier: HKCategoryTypeIdentifier.mindfulSession)!,
            HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKQuantityType.quantityType(forIdentifier: .heartRate)!
        ]
        
        // The quantity types to read from the health store.
        let typesToRead: Set = [
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKObjectType.categoryType(forIdentifier: HKCategoryTypeIdentifier.mindfulSession)!
            
        ]
        
        // Request authorization for those quantity types.
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { (success, error) in
            // Handle error.
        }
    }
    
    // Provide the workout configuration.
    func workoutConfiguration() -> HKWorkoutConfiguration {
        /// - Tag: WorkoutConfiguration
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .mindAndBody
        configuration.locationType = .unknown

        
        return configuration
    }
    

    
    // Start the workout.
    func startWorkout() {
        self.resetWorkout() // Reset again as it records whilst not in workout...
        var delay : Int
        // Start the timer.
        setUpTimer()
        self.running = true
        
        
        // Create the session and obtain the workout builder.
        /// - Tag: CreateWorkout
        do {
            session = try HKWorkoutSession(healthStore: healthStore, configuration: self.workoutConfiguration())
            builder = session.associatedWorkoutBuilder()
        } catch {
            // Handle any exceptions.
            return
        }
        
        // Setup session and builder.
        session.delegate = self
        builder.delegate = self
        
        // Set the workout builder's data source.
        /// - Tag: SetDataSource
        builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore,
                                                     workoutConfiguration: workoutConfiguration())
        
        // Start the workout session and begin data collection.
        /// - Tag: StartSession
        session.startActivity(with: Date())
        builder.beginCollection(withStart: Date()) { (success, error) in
        // The workout has started.
        }
        
//        self.getHRVSampleQuery() // Get last HRV

        
        // Start resonant haptics
        var counter = 0
        
        self.breathe()
        
        delay = 121 // How much data we need to wait for
//        if delay == 24 {
//            // Call breathe again after 1 min if we are waiting for 2 mins to give feedback
//            DispatchQueue.main.asyncAfter(deadline: .now() + 60) {
//                self.breathe()
//            }
//        }

        

        self.timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { timer in
                DispatchQueue.main.async {

//                    if self.bleManager!.accHRSamples.count > delay {
                    if self.bleManager?.RRArray.count ?? -1 > delay {

//                        self.zendoHRV() // Update SDNN values using zendo function
                        self.myHRV() // Use my function
                        counter = self.resonantHaptics(SDNN: 10, counter: counter) // use zendo

//                        counter = self.resonantHaptics(SDNN: self.HRArrayToSDNN(HRArray: self.heartRateSamples), counter: counter) // old line

                        print(self.oldSDNNScore, self.SDNNScore)



                    }
                    else {
                        // Call breathe function (has timer, runs 6 times)
                        self.breathe()
                        print("waiting for more data, current HRV:")
                        self.computeHRV()
                        print(self.HRV)
                    }
//                    self.getHRVSampleQuery()
                }
            }
        
        
    }
    
    // MARK: - State Control
    func togglePause() {
        // If you have a timer, then the workout is in progress, so pause it.
        if running == true {
            self.pauseWorkout()
        } else {// if session.state == .paused { // Otherwise, resume the workout.
            resumeWorkout()
        }
    }
    
    func pauseWorkout() {
        // Pause the workout.
        session.pause()
        // Stop the timer.
        cancellable?.cancel()
        // Save the elapsed time.
        accumulatedTime = elapsedSeconds
        running = false
        
        // Stop resonant haptics
        self.timer?.invalidate()
    }
    
    func resumeWorkout() {
        // Resume the workout.
        session.resume()
        // Start the timer.
        setUpTimer()
        running = true
        
        // Start resonant haptics
        var counter = 0
        self.timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { timer in
                DispatchQueue.main.async {
                    print("heartrate = ", self.heartrate)
                    counter = self.resonantHaptics(SDNN: self.HRArrayToSDNN(HRArray: self.heartRateSamples), counter: counter)
                }
            }
       
    }
    
    func endWorkout() {
        // End the workout session.
        session.end()
        cancellable?.cancel()
    
        // Stop timers
        self.timer?.invalidate()
        breatheTimer?.invalidate()
        
        // Reset success state
        self.success = false
        self.breathing = false // reset breathing too
        
        print(String(format: "Avg SDNN: %.0f ms", self.avgSDNN))
                
        print(self.bleManager?.timeMilliSeconds)
//        print(self.bleManager?.accHRSamples) // log the HR data
//        print(self.smoothBeatsArray)
        print(self.bleManager?.RRArray)
        print(self.bleManager?.RRArray.count)
        print(self.bleManager?.invalidMeasurements)
        
        let accuracy = (Int((self.bleManager?.RRArray.count)!) / (Int((self.bleManager?.RRArray.count)!) + Int(self.bleManager!.invalidMeasurements))) * 100
        print(String(format: "Accuracy: %.0f ", accuracy))
                
    }
    
    func resetWorkout() {
        // Reset the published values.
        print("Resetting workout")
        DispatchQueue.main.async {
            self.elapsedSeconds = 0
            self.heartrate = 0
            self.HRV = 0
            
            // Reset success state
            self.success = false
            self.breathing = false // reset breathing too
            
            // and HR array
            self.heartRateSamples = []
            
            // And RR stuff
            self.bleManager?.RRArray = []
            self.bleManager?.invalidMeasurements = 0
            
        }
        print(self.bleManager?.RRArray) // Currently bugged, doesn't reset
        print(self.bleManager?.invalidMeasurements)
    }
    
    // MARK: - Update the UI
    // Update the published values.
    func updateForStatistics(_ statistics: HKStatistics?) {
        guard let statistics = statistics else { return }
        
        DispatchQueue.main.async {
            switch statistics.quantityType {
            case HKQuantityType.quantityType(forIdentifier: .heartRate):
                /// - Tag: SetLabel
                let heartRateUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
                let value = statistics.mostRecentQuantity()?.doubleValue(for: heartRateUnit)
//                print(value!)
                let roundedValue = Double( round( 1 * value! ) / 1 )
                self.heartrate = roundedValue
                self.heartRateSamples.append(self.heartrate) // Append to array
            case HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN):
                let HRVUnit = HKUnit.secondUnit(with: .milli)
                let value = statistics.mostRecentQuantity()?.doubleValue(for: HRVUnit)
                print("HRV = ",value!)
                let roundedValue = Double( round( 1 * value! ) / 1 )
                self.HRV = roundedValue
            default:
                return
            }
        }
    }
}

// MARK: - HKWorkoutSessionDelegate
extension WorkoutManager: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState,
                        from fromState: HKWorkoutSessionState, date: Date) {
        // Wait for the session to transition states before ending the builder.
        /// - Tag: SaveWorkout
        if toState == .ended {
            print("The workout has now ended.")
            builder.discardWorkout()
            self.resetWorkout() // Reset the workout
//            builder.endCollection(withEnd: Date()) { (success, error) in
//                self.builder.finishWorkout { (workout, error) in
//                    // Optionally display a workout summary to the user.
//                    self.resetWorkout()
//                }
//            }
        }
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        
    }

// MARK: - My Functions
    func repeatResonantHaptics(liveHR: Double, elapsedSeconds: Int) {
        while running { // Call whilst workout is running
            print(elapsedSeconds, elapsedSeconds % 10)
            if elapsedSeconds % 10 == 0 { // Call the below every 10s
                if liveHR < 70 && liveHR > 30 {
                    print("success")
                    WKInterfaceDevice.current().play(.success)
                }
                else {
                    print("breathe with me")
                    WKInterfaceDevice.current().play(.directionUp)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                        WKInterfaceDevice.current().play(.directionDown)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
                        // Wait 6s
                    }
                }
            }

        }
    }
    
    func resonantHaptics(SDNN: Double, counter: Int) -> Int{
        var counter = counter

//        if self.SDNNScore > self.oldSDNNScore && counter < 100 { // old line
//        if self.SDNNScore > 100 { // my numbers not accurate enough to go for 100ms
        if self.SDNNScore > 200 || self.SDNNScore > self.oldSDNNScore { // If hit target HRV or it's increasing
            counter += 1
            
            self.breathing = true // Grow breathing circle
            self.success = true // User is doing well!
            print("success, counter = ", counter)
            WKInterfaceDevice.current().play(.success)
//            self.breathe()
//            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
//                print("breathe out through your mouth")
//                self.breathing = false // Shrink breathing circle
//                WKInterfaceDevice.current().play(.stop)
//            }
        }
//        else if self.SDNNScore <= self.oldSDNNScore { // old line
        else {
            counter = 0 // Reset the counter
//            self.breathe() // Call breathe function 6 times

            print("playing haptics")
            self.success = false // Reset success status
//            DispatchQueue.main.async {
//                self.breathing = true // Grow breathing circle
//                print("breathe in through your nose")
//                WKInterfaceDevice.current().play(.start)
//            }
//            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
//                self.breathing = false // Shrink breathing circle
//                print("breathe out through your mouth")
//                WKInterfaceDevice.current().play(.stop)
//            }
        }
        
        return counter
    }
    
    
    func getHRVSampleQuery() {
        let HRVType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)

        let sortDescriptor = NSSortDescriptor(key:HKSampleSortIdentifierStartDate, ascending: false)

        let startDate = Date() - 6 * 60 * 60 // start date is 6 hours ago
//        let startDate = Date() // start now
        //  Set the Predicates & Interval
        let predicate: NSPredicate? = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: HKQueryOptions.strictEndDate)

        let sampleQuery = HKSampleQuery(sampleType: HRVType!, predicate: predicate, limit: 30, sortDescriptors: [sortDescriptor]) { sampleQuery, results, error  in
            if(error == nil) {
                for result in results! {
                    print("Startdate")
                    print(result.startDate)
                    print(result.sampleType)
//                    print(result.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli)))
                    print(result)
                }
            }
        }
        healthStore.execute(sampleQuery)
    }
    
    func standardDeviation(arr : [Double]) -> Double {
        let length = Double(arr.count)
        let avg = arr.reduce(0, {$0 + $1}) / length
        let sumOfSquaredAvgDiff = arr.map { pow($0 - avg, 2.0)}.reduce(0, {$0 + $1})
        return sqrt(sumOfSquaredAvgDiff / length)
    }
    
    func HRArrayToSDNN(HRArray: [Double]) -> Double {
        var SDNN: Double
        var oldSDNN: Double
//        let array = HRArray.map {$0 * 1000/60} // Convert BPM to RR
        let array = HRArray.map {1000 * 60 / $0} // Convert BPM to RR - zendo

        
        SDNN = standardDeviation(arr: Array(array[(array.count-12) ..< array.count]))
//        print(String(format: "HRV: %.0f ms", SDNN))
        
        oldSDNN = standardDeviation(arr: Array(array[0..<(array.count-12)]))
                
        self.SDNNScore = CGFloat(round(SDNN))
        self.oldSDNNScore = CGFloat(round(oldSDNN))
        
        
        return SDNN
    
    }
    
    func zendoHRV() {
        let bpm = self.bleManager!.accHRSamples.compactMap{ $0 }
        let beatsAsFloat : Array<Float> = bpm.map
        {
            Float(1000 * 60 / $0) // *60 to convert to BPS
            //            Float($0 * 1000 / 60) // This one corroborates with EliteHRV!!
        }
                
        
        let smoothBeats = CubicInterpolator(points:
            CubicInterpolator(points: beatsAsFloat, tension: 0.1).resample(interval: 3)
                          , tension: 0.1).resample(interval: 0.25).map { $0 }
        
        let smoothBeatsAsDouble = smoothBeats.map
        {
                Double($0)
        }
        
        self.smoothBeatsArray = smoothBeatsAsDouble
        
        
       
        // Use segments of data
        self.SDNNScore = CGFloat(standardDeviation(arr: Array(smoothBeatsAsDouble[(smoothBeatsAsDouble.count-(1*60)) ..< (smoothBeatsAsDouble.count)])))
        self.oldSDNNScore = CGFloat(standardDeviation(arr: Array(smoothBeatsAsDouble[(smoothBeatsAsDouble.count-(2*60)) ..< (smoothBeatsAsDouble.count-(1*60))])))
        
        // Use all data
//        self.SDNNScore = CGFloat(standardDeviation(arr: Array(smoothBeatsAsDouble)))
//        self.oldSDNNScore = CGFloat(standardDeviation(arr: Array(smoothBeatsAsDouble[0 ..< (smoothBeatsAsDouble.count-(1*60))])))
        
        // Save overall average
        self.avgSDNN = standardDeviation(arr: Array(smoothBeatsAsDouble))
        
        
    }
    

    func getHRVAverage() {
    
        let hkType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
        
        let today = Calendar.autoupdatingCurrent.startOfDay(for: Date())

        let hkPredicate = HKQuery.predicateForSamples(withStart: today, end: Date(), options: .strictStartDate)
        
        let options = HKStatisticsOptions.discreteAverage
        
        let hkQuery = HKStatisticsQuery(quantityType: hkType,
                                        quantitySamplePredicate: hkPredicate,
                                        options: options)
                {
                query, result, error in
                    if error == nil {
                        if let result = result {
                            if let value = result.averageQuantity()?.doubleValue(for: HKUnit(from: "ms"))
                            {
                                DispatchQueue.main.async {
                                    self.avgHRV = value
//                                    print(value)
                                }
                            }
                        }
                    }
            }
        
            healthStore.execute(hkQuery)
        
        }
    
    func breathe() {
        var runCount = 0

        breatheTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { timer in
            runCount += 1
            self.breathing = true
            if self.success == true {
                print("good job! breathe in")
                WKInterfaceDevice.current().play(.success)
            }
            else {
                print("it's okay, relax and breathe in")
                WKInterfaceDevice.current().play(.start)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                print("breathe out")
                self.breathing = false // Shrink breathing circle
                WKInterfaceDevice.current().play(.stop)
            if runCount == 6 {
                timer.invalidate()
            }
        }
        }
    }
    
    func computeHRV() {
        self.HRV = self.standardDeviation(arr: self.bleManager!.RRArray.map{ Double($0) })
    }
    
    func myHRV() {
        let RR = self.bleManager!.RRArray.compactMap{ $0 }
        let RRAsFloat : Array<Float> = RR.map
        {
            Float($0)
        }
                
        
        let smoothRR = CubicInterpolator(points:
            CubicInterpolator(points: RRAsFloat, tension: 0.1).resample(interval: 3)
                          , tension: 0.1).resample(interval: 0.25).map { $0 }
        
        let smoothRRAsDouble = smoothRR.map
        {
                Double($0)
        }
        
        self.smoothRRArray = smoothRRAsDouble
        
        
       
        // Use segments of data
        self.SDNNScore = CGFloat(standardDeviation(arr: Array(smoothRRAsDouble[(smoothRRAsDouble.count-(1*60)) ..< (smoothRRAsDouble.count)])))
        self.oldSDNNScore = CGFloat(standardDeviation(arr: Array(smoothRRAsDouble[(smoothRRAsDouble.count-(2*60)) ..< (smoothRRAsDouble.count-(1*60))])))
        
        // Use all data
//        self.SDNNScore = CGFloat(standardDeviation(arr: Array(smoothBeatsAsDouble)))
//        self.oldSDNNScore = CGFloat(standardDeviation(arr: Array(smoothBeatsAsDouble[0 ..< (smoothBeatsAsDouble.count-(1*60))])))
        
        // Save overall average
        self.avgSDNN = standardDeviation(arr: Array(smoothRRAsDouble))
        
        
    }

    
}
    
// MARK: - HKLiveWorkoutBuilderDelegate
extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        
    }
    
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else {
                return // Nothing to do.
            }
            
            /// - Tag: GetStatistics
            let statistics = workoutBuilder.statistics(for: quantityType)
            
            // Update the published values.
            updateForStatistics(statistics)
        }
    }
}


