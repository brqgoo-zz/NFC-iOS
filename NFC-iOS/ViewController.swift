//
//  ViewController.swift
//  NFC-iOS
//
//  Created by Burak Keceli on 12.10.20.
//  Copyright © 2020 Burak Keceli. All rights reserved.
//

import UIKit
import CoreNFC
import CryptoKit

class ViewController: UIViewController, NFCTagReaderSessionDelegate {
    
    @IBOutlet weak var tb: UITextField!
    
    var tbText:String = ""
    
    
    var PWD:Data = Data(bytes: [0xA2,0x2B,0xFF,0xFF,0xFF,0xFF], count: [0xA2,0x2B,0xFF,0xFF,0xFF,0xFF].count)

    
    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
        print("errpr1")
    }
    
    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        print("errpr2")
    }
    
    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
        if case let NFCTag.miFare(tag) = tags.first! {

            session.connect(to: tags.first!) { (error: Error?) in
                
                print("connected to tag")
                

                tag.sendMiFareCommand(commandPacket: self.PWD, completionHandler: { (data0, error) in
                    
                    debugPrint(data0.hexEncodedString())
                    debugPrint(error as Any)
 
                })

                var byteData = [UInt8]()
                tag.identifier.withUnsafeBytes { byteData.append(contentsOf: $0) }
                var uid = "0"
                byteData.forEach {
                    uid.append(String($0, radix: 16))
                }
                print("UID: \(uid)")
                
                var payloadData = Data([0x02,0x65,0x6E]) // 0x02 + 'en' = Locale Specifier
                let hashed = SHA256.hash(data: Data("\(uid)\(self.tbText)".utf8))
                let hashString = hashed.compactMap { String(format: "%02x", $0) }.joined()
                
                payloadData.append("nfcauth?uidnaber=\(uid)&data=\(self.tbText)&hash=\(hashString)".data(using: .utf8)!)

                let payload = NFCNDEFPayload.init(
                    format: NFCTypeNameFormat.nfcWellKnown,
                    type: "T".data(using: .utf8)!,
                    identifier: Data.init(count: 0),
                    payload: payloadData,
                    chunkSize: 0)
                
                print("yua")
    
                tag.queryNDEFStatus() { (status: NFCNDEFStatus, capacity: Int, error: Error?) in
                    if error != nil {
                        session.invalidate(errorMessage: "Fail to determine NDEF status. Please try again.")
                        return
                    }
                    
                    if status == .readOnly {
                        print("readOnly")
  
                        session.invalidate(errorMessage: "This tag is already used. You can write each tag only once.")
                        return
                        
                    } else if status == .readWrite {
                        print("readWrite")
                        
                              tag.writeNDEF(NFCNDEFMessage(records: [payload])) { (error: Error?) in
                                  if error != nil {
                                      session.invalidate(errorMessage: "Update tag failed. Please try again.")
                                  } else {
                                      
                                  }
                              }
                        
                        /*
                               
                              tag.writeLock() { (error: Error?) in
                                  if error != nil {
                                      session.invalidate(errorMessage: "Lock failed.")
                                      return
                                  } else {
                                  }
                              }
                        
                        */
                              
                              tag.readNDEF { (message: NFCNDEFMessage?, error: Error?) in

                                  for record in message!.records {
                                          

                                      if record.payload.count >= 3{
                                          print("mua")
                                          print(String(decoding: Data(String(record.payload.hexEncodedString()).hexaData), as: UTF8.self))
                                          
                                          session.alertMessage = "Writing success!"
                                          session.invalidate()
                                          return
                                          
                                          }
                                          else {
                                              
                                          }
                                          
                                      }

                              }
                        
                    } else {
                        session.invalidate(errorMessage: "This tag might have been damaged.")
                        return
                    }
                }
                
            }
            
        }
    }

    



    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        title = "Write"
        tb.addDoneButtonOnKeyboard()
        
    }
    
    @IBAction func beginScanning(_ sender: Any) {
        if(tb.text!.count>=1){
            
            tbText = self.tb.text!
            
        guard NFCNDEFReaderSession.readingAvailable else {
            let alertController = UIAlertController(
                title: "Scanning Not Supported",
                message: "This device doesn't support tag scanning.",
                preferredStyle: .alert
            )
            alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.present(alertController, animated: true, completion: nil)
            return
        }
        
        let session:NFCTagReaderSession = NFCTagReaderSession(pollingOption: .iso14443, delegate: self)!
        session.alertMessage = "Hold your iPhone near the item to learn more about it."
        session.begin()
    }
        else {
            
        }
    }
    
    


}

extension Data {
    struct HexEncodingOptions: OptionSet {
        let rawValue: Int
        static let upperCase = HexEncodingOptions(rawValue: 1 << 0)
    }

    func hexEncodedString(options: HexEncodingOptions = []) -> String {
        let format = options.contains(.upperCase) ? "%02hhX" : "%02hhx"
        return map { String(format: format, $0) }.joined()
    }
}

extension StringProtocol {
    var hexaData: Data { .init(hexa) }
    var hexaBytes: [UInt8] { .init(hexa) }
    private var hexa: UnfoldSequence<UInt8, Index> {
        sequence(state: startIndex) { start in
            guard start < self.endIndex else { return nil }
            let end = self.index(start, offsetBy: 2, limitedBy: self.endIndex) ?? self.endIndex
            defer { start = end }
            return UInt8(self[start..<end], radix: 16)
        }
    }
}

extension UITextField{
    
    @IBInspectable var doneAccessory: Bool{
        get{
            return self.doneAccessory
        }
        set (hasDone) {
            if hasDone{
                addDoneButtonOnKeyboard()
            }
        }
    }
    
    func addDoneButtonOnKeyboard()
    {
        let doneToolbar: UIToolbar = UIToolbar(frame: CGRect.init(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 50))
        doneToolbar.barStyle = .default
        
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let done: UIBarButtonItem = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(self.doneButtonAction))
        
        let items = [flexSpace, done]
        doneToolbar.items = items
        doneToolbar.sizeToFit()
        
        self.inputAccessoryView = doneToolbar
    }
    
    @objc func doneButtonAction()
    {
        self.resignFirstResponder()
    }
}

