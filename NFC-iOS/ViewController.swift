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
import CryptorECC
import web3swift

struct Wallet {
    let address: String
    let data: Data
    let name: String
    let isHD: Bool
}


class ViewController: UIViewController, NFCTagReaderSessionDelegate {
    
    @IBOutlet weak var tb: UITextField!
    
    var tbText:String = ""
    var userPrivateKeyStr:String = ""
    var userPublicKeyStr:String = ""
    
    @IBOutlet weak var privateKeyBox: UITextView!
    @IBOutlet weak var publicKeyBox: UITextView!
    
    
    
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

                var payloadData = Data([0xFF,0xFF,0xFF,0xFF])
                
                payloadData.append(self.tbText.data(using: .utf8)!)
                
                payloadData.append(contentsOf: [0xFF,0xFF,0xFF,0xFF])

                let message = Web3.Utils.sha256("\(tag.identifier.hexEncodedString().lowercased())\(self.tbText.data(using: .utf8)!.toHexString().lowercased())".hexaData)
                
                print("message")
                print(message?.hexEncodedString())
                
                let sig = SECP256K1.signForRecovery(hash: message!, privateKey: Data(hex: self.userPrivateKeyStr))
                
                payloadData.append(sig.serializedSignature!)

                let payload = NFCNDEFPayload.init(
                    format: NFCTypeNameFormat.nfcWellKnown,
                    type: "T".data(using: .utf8)!,
                    identifier: Data.init(count: 0),
                    payload: payloadData,
                    chunkSize: 0)
                
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
                        
                               
                              tag.writeLock() { (error: Error?) in
                                  if error != nil {
                                      session.invalidate(errorMessage: "Lock failed.")
                                      return
                                  } else {
                                    session.alertMessage = "Writing success!"
                                    session.invalidate()
                                    return
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
        privateKeyBox.addDoneButton(title: "Done", target: self, selector: #selector(tapDone(sender:)))
        publicKeyBox.addDoneButton(title: "Done", target: self, selector: #selector(tapDone(sender:)))
        
        if UserDefaults.standard.object(forKey: "UserPrivateKey") != nil{
            print("non first time")
            userPrivateKeyStr = UserDefaults.standard.object(forKey: "UserPrivateKey") as! String
            userPublicKeyStr = UserDefaults.standard.object(forKey: "UserPublicKey") as! String
            print(userPrivateKeyStr)
        }
        else {
            print("first time")
            let privatekey:String = (SECP256K1.generatePrivateKey()?.hexEncodedString())!
            
            UserDefaults.standard.set(privatekey, forKey: "UserPrivateKey")
            userPrivateKeyStr = UserDefaults.standard.object(forKey: "UserPrivateKey") as! String
            print(userPrivateKeyStr)
            
            let publickey:String = (SECP256K1.privateToPublic(privateKey: Data(hex: privatekey))?.hexEncodedString())!
            
            UserDefaults.standard.set(publickey, forKey: "UserPublicKey")
            userPublicKeyStr = UserDefaults.standard.object(forKey: "UserPublicKey") as! String
            
        }
        
        privateKeyBox.text = userPrivateKeyStr
        publicKeyBox.text = userPublicKeyStr
        

        
        
        
        
        //let recoveredpublickey:String = (SECP256K1.recoverPublicKey(hash: message!, signature: sig.serializedSignature!)?.hexEncodedString())!

        
    }
    
    @objc func tapDone(sender: Any) {
        self.view.endEditing(true)
    }
    
    @IBAction func beginScanning(_ sender: Any) {
        if(tb.text!.count>=1){
            if(SECP256K1.privateToPublic(privateKey: privateKeyBox.text.hexaData) == publicKeyBox.text.hexaData){
                
                userPrivateKeyStr = UserDefaults.standard.object(forKey: "UserPrivateKey") as! String
                userPublicKeyStr = UserDefaults.standard.object(forKey: "UserPublicKey") as! String
            
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
                
                let alert = UIAlertController(title: "Error", message: "Given private key and public key pairs does not match.", preferredStyle: UIAlertController.Style.alert)
                alert.addAction(UIAlertAction(title: "Ok", style: UIAlertAction.Style.default, handler: nil))
                self.present(alert, animated: true, completion: nil)

                
        }
    }
            else {
                let alert = UIAlertController(title: "Error", message: "Please type something first.", preferredStyle: UIAlertController.Style.alert)
                alert.addAction(UIAlertAction(title: "Ok", style: UIAlertAction.Style.default, handler: nil))
                self.present(alert, animated: true, completion: nil)
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

extension String {
    func split(by length: Int) -> [String] {
        var startIndex = self.startIndex
        var results = [Substring]()
        
        while startIndex < self.endIndex {
            let endIndex = self.index(startIndex, offsetBy: length, limitedBy: self.endIndex) ?? self.endIndex
            results.append(self[startIndex..<endIndex])
            startIndex = endIndex
        }
        
        return results.map { String($0) }
    }
}
extension UITextView {
    
    func addDoneButton(title: String, target: Any, selector: Selector) {
        
        let toolBar = UIToolbar(frame: CGRect(x: 0.0,
                                              y: 0.0,
                                              width: UIScreen.main.bounds.size.width,
                                              height: 44.0))//1
        let flexible = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)//2
        let barButton = UIBarButtonItem(title: title, style: .plain, target: target, action: selector)//3
        toolBar.setItems([flexible, barButton], animated: false)//4
        self.inputAccessoryView = toolBar//5
    }
}
