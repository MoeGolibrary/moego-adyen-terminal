//
//  AdyenTerminalManager.swift
//  adyen-react-native
//
//  Created by wangcheng on 2024/11/27.
//

import Foundation
import AdyenPOS
import React

let MyErrorDomain = "com.moego.adyen"

enum PaymentEvent: String, CaseIterable {
    case fetchSdkData = "onPayFetchSdkData"
    case deviceDiscovered = "onDeviceDiscovered"
    case deviceDiscoveryFailed = "onDeviceDiscoveryFailed"
    case deviceConnected = "onDeviceConnected"
    case deviceConnectFailure = "onDeviceConnectFailure"
    case deviceDisconnected = "onDeviceDisconnected"
    case applyingFirmwareUpdate = "onApplyingFirmwareUpdate"
    case firmwareUpdateProgress = "onFirmwareUpdateProgress"
    case firmwareDownloadProgress = "onFirmwareDownloadProgress"
    case firmwareUpdateComplete = "onFirmwareUpdateComplete"
    case firmwareUpdateFailure = "onFirmwareUpdateFailure"
    case payFinished = "onPayFinished"
}

class Errors {
    class func createError(_ error: NSError) -> [String: Any] {
        return createError(code: error.code, message: error.localizedDescription)
    }
    
    class func createError(code: Int, message: String) -> [String: Any] {
        let error = [
            "code": code,
            "message": message,
            "domain": MyErrorDomain,
        ] as [String : Any]
        return ["error": error]
    }
}

extension UIViewController {
    internal static var topPresenter: UIViewController? {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }) {
    
            var topController: UIViewController? = keyWindow.rootViewController
            while let presenter = topController?.presentedViewController {
                topController = presenter
            }
            return topController
        }
        
        return nil
    }
}


internal extension Encodable {
    var jsonObject: [String: Any] {
        guard let data = try? JSONEncoder().encode(self),
              let object = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            return [:]
        }

        return object
    }
}

internal extension Decodable {
    init(from jsonObject: NSDictionary) throws {
        let data = try JSONSerialization.data(withJSONObject: jsonObject, options: [])
        self = try JSONDecoder().decode(Self.self, from: data)
    }
}

internal extension NSDictionary {
    func toJson<T: Decodable>() throws -> T {
        let data = try JSONSerialization.data(withJSONObject: self, options: [])
        return try JSONDecoder().decode(T.self, from: data)
    }
}


@available(iOS 17.0, *)
@objc(AdyenTerminal)
final class AdyenTerminalManager: RCTEventEmitter {
//    @objc func setup() async-> Void {
//        do {
//            // The warm-up function checks for a session and any configuration changes, and prepares the proximity reader on the iPhone.
//            try await paymentService.warmUp();
//            sendEvent(withName: ReactNativeConstants.SDK_SETUP_SUCCEED.rawValue, body: [:])
//        } catch {
//            sendEvent(withName: ReactNativeConstants.SDK_SETUP_FAILED.rawValue, body: Errors.createError(nsError: error as NSError))
//        }
//    }
    // 必须将events都抛出去，RN才能正确addListener，否则报错：”is not a supported event type“
    override func supportedEvents() -> [String]! {
        return PaymentEvent.allCases.map {
            $0.rawValue
        }
    }
    
    lazy var paymentService = {
        let paymentService = PaymentService(delegate: self)
        paymentService.deviceManager.delegate = self
        paymentService.deviceManager.firmwareDelegate = self
        return paymentService
    }()
    
    // 保存回调的字典
    private var callbackMap: [String: CheckedContinuation<String, Error>] = [:]
    
    private var deviceManager: DeviceManager & FirmwareManager  {
        return paymentService.deviceManager
    }
    
}

@available(iOS 17.0, *)
extension AdyenTerminalManager: PaymentServiceDelegate, DeviceManagerDelegate, FirmwareManagerDelegate {
    
    // MARK: PaymentServiceDelegate
    func register(with setupToken: String) async throws -> String {
        let callbackId = UUID().uuidString

        return try await withCheckedThrowingContinuation { continuation in
            self.callbackMap[callbackId] = continuation
            self.sendEvent(withName: PaymentEvent.fetchSdkData.rawValue,
                           body: ["token": setupToken, "callbackId": callbackId])
        }
    }
    
    // MARK: DeviceManagerDelegate
    func onDeviceDiscovered(device: AdyenPOS.Device, by manager: any AdyenPOS.DeviceManager) {
        sendEvent(withName: PaymentEvent.deviceDiscovered.rawValue,
                  body: ["serialNumber":device.serialNumber,"type":device.type.rawValue])
    }
    
    func onDeviceDiscoveryFailed(with error: any Error, by manager: any AdyenPOS.DeviceManager) {
        sendEvent(withName: PaymentEvent.deviceDiscoveryFailed.rawValue,
                  body: [:])
    }
    
    func onDeviceConnected(with error: (any Error)?, to manager: any AdyenPOS.DeviceManager) {
        if let error = error as? NSError {
            sendEvent(withName: PaymentEvent.deviceConnectFailure.rawValue,
                      body: Errors.createError(error))
        } else {
            Task {
                let device = await connectedDeviceInfo()
                sendEvent(withName: PaymentEvent.deviceConnected.rawValue,
                          body: device)
            }
        }
    }
    
    func onDeviceDisconnected(from manager: any AdyenPOS.DeviceManager) {
        sendEvent(withName: PaymentEvent.deviceDisconnected.rawValue,
                  body: [:])
    }
    
    // MARK: FirmwareManagerDelegate
    func applyingFirmwareUpdate() {
        sendEvent(withName: PaymentEvent.applyingFirmwareUpdate.rawValue,
                  body: [:])
    }
    
    func firmwareUpdateProgress(percent: Double) {
        sendEvent(withName: PaymentEvent.firmwareUpdateProgress.rawValue,
                  body: ["percent":percent])
    }
    
    func firmwareDownloadProgress(percent: Double) {
        sendEvent(withName: PaymentEvent.firmwareDownloadProgress.rawValue,
                  body: ["percent":percent])
    }
    
    func firmwareUpdateComplete() {
        sendEvent(withName: PaymentEvent.firmwareUpdateComplete.rawValue,
                  body: [:])
    }
    
    func firmwareUpdateFailure(error: AdyenPOS.AdyenPOSError) {
        sendEvent(withName: PaymentEvent.firmwareUpdateFailure.rawValue,
                  body: Errors.createError(error as NSError))
    }
    
}

// MARK: 暴露给RN的方法
@available(iOS 17.0, *)
extension AdyenTerminalManager {
    
    @objc func startDiscovery() {
        deviceManager.startDiscovery()
    }
    
    @objc func stopDiscovery() {
        deviceManager.stopDiscovery()
    }
    
    @objc(connectTo:)
    func connect(to: NSDictionary) {
        guard let serialNumber = to.value(forKey: "serialNumber") as? String, let device = device(by: serialNumber) else {
            sendEvent(withName: PaymentEvent.deviceConnectFailure.rawValue,
                      body: Errors.createError(code: -1, message: "can not found a devide"))
            return
        }
        
        deviceManager.connect(to: device)
    }
    
    @objc func disconnect() {
        deviceManager.disconnect()
    }
    
    @objc func startFirmwareUpdate() {
        Task {
            do {
                try await deviceManager.startFirmwareUpdate()
            } catch {
                sendEvent(withName: PaymentEvent.firmwareUpdateFailure.rawValue,
                          body: Errors.createError(error as NSError))
            }
        }
    }
    
    @objc(pay:requestData:)
    func pay(type: NSNumber, requestData: NSString) {
        // TODO: 验证是否在main线程，如果是，需要用Task{}包一下
        guard let presenter = UIViewController.topPresenter else {
            return sendEvent(withName: PaymentEvent.payFinished.rawValue,
                      body: Errors.createError(code: -1, message: "notKeyWindow"))
        }
        
        let sendableData = requestData as String
        
        Task {
            if let data = sendableData.data(using: .utf8) {
                let transaction = try Payment.Request(data: data)
                let paymentInterface = try await paymentService.getPaymentInterface(with: interfaceType(type.intValue))
                let presentationMode: TransactionPresentationMode = .presentingViewController(presenter, logo: nil)
                
                let response = await paymentService.performTransaction(
                    with: transaction,
                    paymentInterface: paymentInterface,
                    presentationMode: presentationMode
                )
                
                sendEvent(withName: PaymentEvent.payFinished.rawValue,
                          body: response.jsonObject)
            } else {
                sendEvent(withName: PaymentEvent.payFinished.rawValue,
                          body: Errors.createError(code: -1, message: "Failed to convert String to Data."))
            }
        }
    }
    
    
    @objc(setSdkData:value:)
    func setSdkData(callbackId: NSString, value: NSString?) {
        let callbackId = callbackId as String
        guard let continuation = callbackMap[callbackId as String] else {
            print("No continuation found for callbackId \(callbackId)")
            return
        }

        // 从字典中移除回调
        callbackMap.removeValue(forKey: callbackId)

        // 根据返回值决定是否恢复 continuation
        if let value = value as? String {
            continuation.resume(returning: value)
        } else {
            let errorInfo: [String: Any] = [
                NSLocalizedDescriptionKey: "fetch sdk data faled"
            ]
            continuation.resume(throwing: NSError(domain: MyErrorDomain, code: -1, userInfo: errorInfo))
        }
    }

}

// MARK: 私有方法
@available(iOS 17.0, *)
extension AdyenTerminalManager {
    
    func device(by serialNumber: String) -> Device? {
        return deviceManager.discoveredDevices.first { $0.serialNumber == serialNumber }
    }
    
    func interfaceType(_ type: Int) -> PaymentInterfaceType {
        switch type {
        case 0:
            .tapToPay
        case 1:
            .cardReader
        default:
            .tapToPay
        }
    }
    
    func connectedDeviceInfo() async -> [String: Any] {
        var info:[String: Any] = [:]
        
        if let device = deviceManager.connectedDevice {
            info = [
                "name": device.name ?? "",
                "isCharging": device.isCharging,
                "model": device.model ?? "",
                "serialNumber": device.serialNumber,
                "type":device.type.rawValue,
                "batteryCapacity": device.batteryCapacity
            ]
            
            if let updateSummary = try? await deviceManager.firmwareUpdateSummary {
                info["updateAvailable"] = true
                info["requiredDate"] = updateSummary.requiredDate?.timeIntervalSince1970 ?? 0
                info["requiresBluetoothConnection"] = updateSummary.requiresBluetoothConnection
            } else {
                info["updateAvailable"] = false
            }
        }
        
        return info;
    }
}
