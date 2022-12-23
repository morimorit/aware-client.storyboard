//
//  SensorData.swift
//  aware-client.storyboard WatchKit Extension
//
//  Created by 森谷太郎 on 2022/11/30.
//
//ファイル分ける
//willactivateにあるからだめ
//filetransferの概要　applewatchの中に保存されるはず
//デバッグで値が取れているか確認
//macのバージョン上げる 完
import Foundation

public class SensorData:NSObject{
    public var filePath:URL?
    let fileManager = FileManager.init()
    var fileHandle:FileHandle? = nil
    var isWriteable:Bool = false
    public var label = 0
    public var hr:Double = 0
    public var barometer:Double = 0
    
    public init(_ fileName:String) {
        //if let documentDirectoryFileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last {
        ///iosアプリのファイル保存が可能なディレクトリ
        ///iOS App
        ///├── Documents
        ///├── Library
        ///│   ├── Caches
        ///│   └── Preferences
        ///└── tmp
        ///
        if let documentDirectoryFileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {//Documentフォルダにあるurlを取得
            self.filePath = documentDirectoryFileURL.appendingPathComponent(fileName)//パソコンのどの位置にあるファイルなのかこれでfilePathが完成
            print("create")
            print(self.filePath!.absoluteString)
            //ファイルパスへの保存
            do {//
                let header = "label,timestamp,hr\n"
                try header.write(to: filePath!, atomically: true, encoding: .utf8 )//例外が発生する可能性のある処理
                //headerの内容を作ったファイルに書き込み
                fileHandle = try FileHandle.init(forWritingTo: self.filePath!)//init(forWritingTo: 指定されたURLでファイル、デバイス、または名前付きソケットに書き込むために初期化されたファイルハンドルを返します。tryが無事実行されれば実行
                // try header.write( to: self.filePath!, atomically: false, encoding: String.Encoding.utf8 )
                isWriteable = true//この文が実行されるということはtry文は成功しているはずなので、書き込み成功のisWriteableはtrue
            } catch {
                print("\(error)")//例外、なんらかのエラーが発生した時に実行する
            }
        }
    }
    
    public func save(){//データの書き込みを行なっている　加速度計とモーションセンサのデータ
        if let uwFileHandle = fileHandle {//ファイルを読み込みモードで開く
            // if let filehandleがnillでないならif文以下が実行
            if isWriteable {//先ほどのファイルの書き込みが成功しているならば、実行
                uwFileHandle.seekToEndOfFile()//一番後ろにシーク
                let now:Double = Date().timeIntervalSince1970 //Dateは現在の日時
                let line = "\(String(label)),\(now),\(hr)\n"//一行ずつファイルに書き出し
                uwFileHandle.write(line.data(using: String.Encoding.utf8)!)//データの書き込み
                print(line)//ここの値を確認
                //lineの心拍数は常に0 どうにかしてInterfafcecontrollerのupdateheartrateから心拍数を引っ張ってこなければいけない
            }
        }
    }
    
    public func close(){
        if let uwFileHandle = fileHandle {
            if isWriteable{
                uwFileHandle.closeFile()
                isWriteable = false
            }//書き込み許可変数をfalseにしてファイルの書き込みを終了する
        }
    }
}
