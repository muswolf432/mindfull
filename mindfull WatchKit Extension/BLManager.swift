//
//  BLManager.swift
//  mindfull WatchKit Extension
//
//  Created by Mustafa Iqbal on 01/07/2021.
//  Copyright © 2021 Apple. All rights reserved.
//

import Foundation
import CoreBluetooth
import WatchKit

let heartRateServiceCBUUID = CBUUID(string: "0x180D")
let heartRateMeasurementCharacteristicCBUUID = CBUUID(string: "2A37")


class BLEManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {

    var myCentral: CBCentralManager!
    var heartRatePeripheral: CBPeripheral!

    

    @Published var isConnected = false
    @Published var peripheralName : String = ""
    @Published var blBPM : Int = 0
    @Published var accHRSamples = [Int]()
    @Published var RRArray = [Double]()
    @Published var timeMilliSeconds = [Int64]()
    @Published var invalidMeasurements: Int = 0
    var RRlast: Double = 0


    override init() {
        super.init()

        myCentral = CBCentralManager(delegate: self, queue: nil)
        myCentral.delegate = self
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            myCentral.scanForPeripherals(withServices: [heartRateServiceCBUUID])
        }
        else {
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        print(peripheral)
        heartRatePeripheral = peripheral
        heartRatePeripheral.delegate = self
        myCentral.stopScan()
        myCentral.connect(heartRatePeripheral)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected!")
        WKInterfaceDevice.current().play(.success) // Notify user
        self.isConnected = true
        self.peripheralName = peripheral.name!
        heartRatePeripheral.discoverServices([heartRateServiceCBUUID])
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
      guard let services = peripheral.services else { return }
      for service in services {
        print(service)
        peripheral.discoverCharacteristics(nil, for: service)
      }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
      guard let characteristics = service.characteristics else { return }

      for characteristic in characteristics {
        print(characteristic)

        if characteristic.properties.contains(.read) {
          print("\(characteristic.uuid): properties contains .read")
          peripheral.readValue(for: characteristic)
        }
        if characteristic.properties.contains(.notify) {
          print("\(characteristic.uuid): properties contains .notify")
          peripheral.setNotifyValue(true, for: characteristic)
        }
      }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
      switch characteristic.uuid {
      case heartRateMeasurementCharacteristicCBUUID:
        let bpm = heartRate(from: characteristic)
        let RR = RR(from: characteristic)
        let tol = 0.2 // Tolerance
        self.blBPM = bpm
        if RRlast > 0 { // If we have some RR data
            if RR > 100 && ((RR - RRlast) / RRlast).magnitude <= tol { // Only append RR interval if larger than 100ms, otherwise 0ms can be appended, artificially increasing the variance; second condition corrects for ectopic beats/noise/motion (only append if differs by less than 20% from last measurement
                self.RRArray.append(RR)
                print("Appending ", RR)
                RRlast = RR // update RR last
                }
            if RR > 100 && ((RR - RRlast) / RRlast).magnitude > tol { // Track the number of invalid measurements
                print("Invalid measurement!", RR)
                self.invalidMeasurements += 1
                RRlast = RR // update RR last
            }
        }
        else if RR > 800 && RR < 1200 { // Grab ~ 1000ms for first measurement, otherwise if grab 500ms is bad
            self.RRArray.append(RR)
            print("Appending without correction", RR)
            RRlast = RR
            }
        
        // Append data here, also need the time
        self.accHRSamples.append(bpm)
        self.timeMilliSeconds.append(Date().millisecondsSince1970) // measured in ms since 1970

      
      default:
        print("Unhandled Characteristic UUID: \(characteristic.uuid)")
      }
    }
    
    private func heartRate(from characteristic: CBCharacteristic) -> Int {
      guard let characteristicData = characteristic.value else { return -1 }
      let byteArray = [UInt8](characteristicData)

      // See: https://www.bluetooth.com/specifications/gatt/viewer?attributeXmlFile=org.bluetooth.characteristic.heart_rate_measurement.xml
      // The heart rate mesurement is in the 2nd, or in the 2nd and 3rd bytes, i.e. one one or in two bytes
      // The first byte of the first bit specifies the length of the heart rate data, 0 == 1 byte, 1 == 2 bytes
      let firstBitValue = byteArray[0] & 0x01
      if firstBitValue == 0 {
        // Heart Rate Value Format is in the 2nd byte
        return Int(byteArray[1])
      } else {
        // Heart Rate Value Format is in the 2nd and 3rd bytes
        return (Int(byteArray[1]) << 8) + Int(byteArray[2])
      }
    }
    
    private func RR(from characteristic: CBCharacteristic) -> Double {
        guard let characteristicData = characteristic.value else { return -1 }
                let byteArray = [UInt8](characteristicData)
                var rawRRinterval = 0
                //if fifth bit (index 4) is set -> RR-Inteval present (00010000 = 16)
                if (byteArray[0] & 16)  != 0 {
//                    print("One or more RR-Interval values are present.")
                
                    switch byteArray[0] {
                        case 16,18,20,22:
                            //rr-value in [2] und [3]
                            rawRRinterval = Int(byteArray[2]) + (Int(byteArray[3]) << 8)
                        case 17,19,21,23:
                            //rr-value in [3] und [4]
                            rawRRinterval = Int(byteArray[3]) + (Int(byteArray[4]) << 8)
                        case 24,26,28,30:
                            //rr-value in [4] und [5]
                            rawRRinterval = Int(byteArray[4]) + (Int(byteArray[5]) << 8)
                        case 25,27,29,31:
                            //rr-value in [5] und [6]
                            rawRRinterval = Int(byteArray[4]) + (Int(byteArray[5]) << 8)
                    default:
                        print("No bytes found")
                    }}
                else {
//                         print("RR-Interval values are not present.")
                        }
                
                //Resolution of 1/1024 second
                let rrInSeconds: Double = Double(rawRRinterval)/1024
//                print("💢 rrInSeconds: \(rrInSeconds)")
                let rrInMilSeconds: Double = Double(rrInSeconds) * 1000
//                print("💢 rrInMilSeconds: \(rrInMilSeconds)")
                
                let value = (Double(rawRRinterval) / 1024.0 ) * 1000.0
//                print("💢 value: \(value)")
                
                return rrInMilSeconds
                }
}

extension Date {
    var millisecondsSince1970:Int64 {
        return Int64((self.timeIntervalSince1970 * 1000.0).rounded())
    }

    init(milliseconds:Int64) {
        self = Date(timeIntervalSince1970: TimeInterval(milliseconds) / 1000)
    }
}
