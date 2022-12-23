//
//  InterfaceController.swift
//  aware-client.storyboard WatchKit Extension
//
//  Created by 森谷太郎 on 2022/11/28.
//

///Message from debugger: Xcode has killed the LLDB RPC server to allow the debugger to detach from your process. You may need to manually terminate your process.
///lldbが使用するデバッグプロトコルにはユビキティの利点がありますが、高速データ転送用に設計されていません。lldbがデバッグされているプロセスからすべてのシンボル情報を読み取らなければならないとき、それはかなり遅くなります。
import WatchKit
import Foundation
import WatchConnectivity
import HealthKit
import UserNotifications
//filetransferの実装
//swiftの構造　書き直し
///filetrasferの概要
///class WCSessionFileTransfer : NSObject     このクラスのインスタンスを自分で作成しないでください。ファイル転送を開始すると、システムは転送されたファイルを表す新しいファイル転送オブジェクトを作成します。
///ファイル転送操作を開始するには、アプリのsWCSessionオブジェクトのtransferFile(_:metadata:)メソッドを呼び出します。
///transferfile このメソッドを使用して、ローカルなファイルを現在のデバイスに送信します。ファイルは、バックグラウンドスレッドで非同期に対応するものに転送されます。システムはできるだけ早くファイルを送信しようとしますが、パフォーマンスと電力の懸念に対応するために配信速度を抑制する可能性があります。
//hrがどのように動いているか確認→self.sensorData!.hrの値は動いていない　センサー系の値が全て0になってしまっている。
//ファイルを分ける クラス名にWKInterfaceControllerを入れればstoryboardの画面選択にInterfeceが表示されるようになる。
//willactivtate内にsyncを削除 → 削除しなくても動くようになった。　画面ごとにInterfaceをわけていなかったことが原因かも
class InterfaceController: WKInterfaceController {
    var wcsession:WCSession!
    
    let healthStore = HKHealthStore()
    var timer:Timer? = nil
    
    var session : HKWorkoutSession?
    let heartRateUnit = HKUnit(from: "count/min")
    var currenQuery : HKQuery?
    var sensorData : SensorData? = nil
    var labelNumber: Int = 0
    var sending_state : Bool = false
    
    let center = UNUserNotificationCenter.current()
    var lastSyncTime: String = "まだ同期していません"
    
    
    @IBOutlet weak var lastSyncLabel: WKInterfaceLabel!
    
    override func awake(withContext context: Any?) {
        // Configure interface objects here.
        super.awake(withContext: context)
        if WCSession.isSupported() {
            wcsession = WCSession.default
            wcsession.delegate = self
            wcsession.activate()
        }
        print(HKHealthStore.isHealthDataAvailable())
        guard HKHealthStore.isHealthDataAvailable() == true else {
            return
        }
        
        guard let quantityType = HKQuantityType.quantityType(forIdentifier:HKQuantityTypeIdentifier.heartRate) else {//数値と単位をもつ。HKQUantityTypeIdentifierは数量型オブジェクトを作成する識別子
            displayNotAllowed()//デフォルトで用意された関数　今回は用いない
            return
        }
        print(quantityType)
        let dataTypes = Set(arrayLiteral: quantityType)//arrayとsetは性質が似ているが、arrayは値の重複可能setは値が重複しない時に用いる。
        print(dataTypes)
        healthStore.requestAuthorization(toShare: nil, read: dataTypes) { (success, error) -> Void in
            //ヘルスケアデータへのアクセス許可のリクエスト
            print("requestAuthorization")
            print(success)//true
            print(error)//nill
            if success == false {//アクセスが失敗したなら
                self.displayNotAllowed()
            }
        }
        startWorkout()
        fileLifeCycle()//requestAuthorizationプリントの直後にfileLife来るはずだが、順番が前後している
    }
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        // This method is called when watch view controller is about to be visible to user
        //画面が立ち上がる直前に実行　毎回タイミングは違う
        super.willActivate()
        print("willActivate")
        if WCSession.isSupported() {//WCSessionでiphone,applewatch間のデータのやり取り
            wcsession = WCSession.default
            wcsession.delegate = self
            wcsession.activate()//アプリが通信可能なときこのメソッドを呼び出す
        }
        print(HKHealthStore.isHealthDataAvailable())
        print(lastSyncTime)
        lastSyncLabel.setText(lastSyncTime)//AppleWatch最初の画面で"まだ同期していません"と表示する
        //lastSyncLabel.setText(lastSyncTime) error:Fatal error: Unexpectedly found nil while implicitly unwrapping an Optional valueこれは「nilを入れようとしたから」ではなく「nilのまま使おうとしたから」
    }
    
    func displayNotAllowed() {
        // label.setText("not allowed")
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
    }
    
    func getFileSize(path: String) -> UInt64{
        do {
            let attr = try FileManager.default.attributesOfItem(atPath: path)//ファイルは作成されたときにさまざまな属性値がついている。attributesOfItemでファイルの属性値を取得
            let filesize = attr[FileAttributeKey.size] as! UInt64//UInt64値型は、0から18446744073709551615までの値を持つ符号なし整数を表します
            return filesize
        } catch {
            print("Error: \(error)")
            return 0
        }
    }
    
    func fileLifeCycle(){
        print("fileLife")
        self.sensorData = SensorData(String(Date().timeIntervalSince1970)+"_data.csv")
        self.sensorData?.label = self.labelNumber
        Timer.scheduledTimer(withTimeInterval: 1, repeats:true) { timer in
            self.sensorData?.save()//繰り返しsave()をおこなう
            let filesize = self.getFileSize(path:(self.sensorData?.filePath!.path)!)
            print(filesize)
            if filesize > 1000000 {
                print("send 1MB size file to iphone")//WCSessionを実装しているから、完成したファイルは1MG(filesizeが1000000)より大きくなったらファイルを送信する
                timer.invalidate()
                self.sensorData?.close()
                self.sendFile()
                self.labelNumber += 1
                self.fileLifeCycle()
            }
        }
    }
    
    func sendFile() {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM月dd日 HH:mm:ss"//日付の枠組みを作る
        lastSyncTime = formatter.string(from: Date())
        if let fileURL = self.sensorData?.filePath{//sensorDatafunctionの中のfilePath
            WCSession.default.transferFile(fileURL, metadata: nil)//ローカルなファイルを現在のデバイスに送信
        }//完成したfileURLを代入し、
    }
    
    @IBAction func pushedSyncButton() {
        print("pushSyncButton")
        self.sendFile()//ボタンを押した際にデバイスにファイルを送信　その後はデータ送信しながら自動でファイル送信
    }
    
    func startWorkout() {
        // If we have already started the workout, then do nothing.
        if (session != nil) {
            return
        }//もしworkoutがスタートしているならば、実行しなくて良い
        // Configure the workout session.
        let workoutConfiguration = HKWorkoutConfiguration()//ワークアウトの設定
        workoutConfiguration.activityType = .crossTraining//有酸素運動など、さまざまな分野が含まれている
        workoutConfiguration.locationType = .indoor//室内用
        do {
            session = try HKWorkoutSession.init(healthStore: healthStore, configuration: workoutConfiguration)// 例外がなければ実行　ワークアウト機能の初期化
            if let uwSession = session {
                uwSession.delegate = self
                uwSession.startActivity(with: Date())
            }
        } catch {
            fatalError("Unable to create the workout session!")//例外を受けて発生する処理
        }
    }
    
    func createHeartRateStreamingQuery(_ workoutStartDate: Date) -> HKQuery? {//心拍数あれこれ
        print("createHeartRateStreamingQuery")
        guard let quantityType = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRate) else { return nil }//Healthkitstoreに保存できる数量サンプルを作成アクセスしたいデータタイプの指定
        print(quantityType)
        let datePredicate = HKQuery.predicateForSamples(withStart: workoutStartDate, end: nil, options: .strictEndDate )//HKQuery Healthkitストアからデータを取得するすべてのデータ管理の問い合わせ
        //SQLに変更　データを取り扱う言語
        //let devicePredicate = HKQuery.predicateForObjects(from: [HKDevice.local()])
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates:[datePredicate])
        //Xcode上から簡単にDBのようにデータ構造を設定できたり、アプリ上で扱うデータを保存、削除、更新するプログラムを簡単に書けるようになる仕組み
        
        
        let heartRateQuery = HKAnchoredObjectQuery(type: quantityType, predicate: predicate, anchor: nil, limit: Int(HKObjectQueryNoLimit)) { (query, sampleObjects, deletedObjects, newAnchor, error) -> Void in//アンカー値リンクに使われる値
            //guard let newAnchor = newAnchor else {return}
            //self.anchor = newAnchor
            //クエリがHealthKitストアで一致するすべてのサンプルを返すことを示す値。
            //複数のアプリを組み合わせて同じデータを扱う場合に用いられる
            print(sampleObjects)
            print(query)
            print(newAnchor)
            print(error)
            self.updateHeartRate(sampleObjects)
        }
        
        heartRateQuery.updateHandler = {(query, samples, deleteObjects, newAnchor, error) -> Void in
            //self.anchor = newAnchor!
            self.updateHeartRate(samples)//すぐ下にあるfunction
        }
        return heartRateQuery
    }
    
    func updateHeartRate(_ samples: [HKSample]?) {
        print("updateHeartRate")
        print(samples)
        guard let heartRateSamples = samples as? [HKQuantitySample] else {return}
        // DispatchQueue.main.async {
        guard let sample = heartRateSamples.first else{return}
        print(sample)
        let hr = sample.quantity.doubleValue(for: self.heartRateUnit)//数量の値を目的の単位に変換する
        //ここで最新の心拍数が代入されるはず
        // self.heartRateLabel.setText(String(hr))
        print(hr)//中身はoptional([])
        self.sensorData!.hr = hr//sensorDataファイルのhrに新たな心拍数を代入し、そのhrがファイルとして送信される
                                //ここのhrはletで宣言されているけど、値は動くのかわからない
        print(self.sensorData!.hr)
        // }
    }
}

//workoutのactivate後にすぐ実行されている。どうやら通信が可能になり次第実行される
extension InterfaceController:WCSessionDelegate{//拡張機能 //データの送受信に関わる
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        switch activationState {
        case .activated:
            print("activate")
            // label.setText("activate")//デバッグではこのすぐ後にSensorDataファイルのlineが一度プリントされているが、コードの順番的におかしい
            break
        case .inactive:
            print("inactive")
            // label.setText("inactive")
            break
        case .notActivated:
            print("not activate")
            // label.setText("not activated")
            break
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        if(session.isReachable){
            print("reachable")
            // label.setText("reachable")
        }else{
            print("not reachable")
            // label.setText("not reachable")
        }
    }
    
    func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {//転送されたファイルを表す新しいオブジェクトを作成
        print("did finish file transfer")
        if error == nil {
            let filepath = fileTransfer.file.fileURL
            do {
                try FileManager.default.removeItem(at: filepath)//送信完了したファイルを削除
                print("success to remove file")
            } catch {
                print("file do not exist")
            }
        }else{
            print(error)
        }
    }
}

extension InterfaceController:HKWorkoutSessionDelegate{//通常時の心拍数蓄積は数分毎だが、Workout中は数秒毎に変更されるため、Workoutの開始・終了の制御ができるようにした。
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        switch toState {//条件分岐文switch toState(HKWorkoutSessionState)が.runnnigならworkoutDidStartを実行.....
        case .running:
            workoutDidStart(date)
        case .ended:
            workoutDidEnd(date)
        default:
            print("Unexpected state \(toState)")
        }
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("Workout error")//エラーが発生した時にコール
    }
    
    //ワークアウト開始直後
    func workoutDidStart(_ date : Date) {
        print("workoutDidStart")
        if let query = createHeartRateStreamingQuery(date) {//クエリの作成
            self.currenQuery = query
            healthStore.execute(query)//createHeartRateStreamingQueryの実行
        } else {
            // label.setText("cannot start")
        }
    }
    
    //ワークアウト終了直後
    func workoutDidEnd(_ date : Date) {
        if let query = self.currenQuery{
            healthStore.stop(query)
            // label.setText("---")
        }
        session = nil
    }
}
