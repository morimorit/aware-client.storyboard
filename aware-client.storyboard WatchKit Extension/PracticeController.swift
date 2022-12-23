//
//  PracticeController.swift
//  aware-client.storyboard WatchKit Extension
//
//  Created by 森谷太郎 on 2022/12/10.
//

import Foundation
import WatchKit

class PracticeController: WKInterfaceController {
    @IBOutlet weak var labelHeartRateLatest: WKInterfaceLabel!
    var sensorData : SensorData? = nil
    
    var heartRateLatest: Double = 0.0 {
        didSet {
            if self.sensorData!.hr < 0.0 {
                labelHeartRateLatest.setText("最新 : ----")
            } else {
                labelHeartRateLatest.setText("最新 : \(self.sensorData!.hr)")
            }
        }
    }
}
