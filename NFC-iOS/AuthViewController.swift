//
//  AuthViewController.swift
//  NFC-iOS
//
//  Created by Burak Keceli on 13.10.20.
//  Copyright © 2020 Burak Keceli. All rights reserved.
//

import UIKit
import CoreNFC
import web3swift

class AuthViewController: UIViewController, NFCTagReaderSessionDelegate {
    
    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
        print("errpr1")
    }
    
    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        print("errpr2")
    }
    
    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
    if case let NFCTag.miFare(tag) = tags.first! {

        session.connect(to: tags.first!) { (error: Error?) in
            
            tag.readNDEF { (message: NFCNDEFMessage?, error: Error?) in

                for record in message!.records {
                        
                    var byteData = [UInt8]()
                    tag.identifier.withUnsafeBytes { byteData.append(contentsOf: $0) }
                    var uid = "0"
                    byteData.forEach {
                        uid.append(String($0, radix: 16))
                    }
                    print("UID: \(uid)")

                    
                    if record.payload.count >= 3{
                        print("record")
                        print(record.payload.hexEncodedString())
                        
                        let decodedHexData = record.payload.hexEncodedString().components(separatedBy: "ffffffff")[1].components(separatedBy: "ffffffff")[0]
                        print("decodedHexData")
                        print(decodedHexData)
                        
                        let message = Web3.Utils.sha256("\(uid)\(decodedHexData)".data(using: .utf8)!)
                        
                        print("message")
                        print(message?.hexEncodedString())
                        
                        
                        let decodedHexSig = record.payload.hexEncodedString().components(separatedBy: "ffffffff")[2]
                        print("decodedHexSig")
                        print(decodedHexSig)
                        
                        let recoveredpubkey = try! SECP256K1.recoverPublicKey(hash: message!, signature: decodedHexSig.hexaData)
                        
                        print("recoveredpubkey")
                        print(recoveredpubkey?.hexEncodedString())
                        
                        return
                        
                        }
                        else {
                            session.invalidate(errorMessage: "Could not read tag.")
                        }
                    
                    
                    
                        
                    }

            }
            
        }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    
    @IBAction func beginScanning(_ sender: Any) {
        
        let session:NFCTagReaderSession = NFCTagReaderSession(pollingOption: .iso14443, delegate: self)!
        session.alertMessage = "Hold your iPhone near the item to learn more about it."
        session.begin()
        
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
