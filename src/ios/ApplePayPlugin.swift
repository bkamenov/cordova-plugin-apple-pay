import Foundation
import PassKit

@objc(ApplePayPlugin) class ApplePayPlugin : CDVPlugin, PKPaymentAuthorizationViewControllerDelegate {
    var paymentCallbackId: String?
    var successfulPayment = false
    var paymentResult: [String: Any]?

    @objc(canMakePayment:) func canMakePayment(command: CDVInvokedUrlCommand) {
        let callbackID = command.callbackId
        guard let args = command.arguments[0] as? [String: Any],
              let supportedNetworks = args["supportedNetworks"] as? [String],
              let merchantCapabilities = args["merchantCapabilities"] as? [String] else {
            let result = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: "Invalid arguments")
            commandDelegate.send(result, callbackId: callbackID)
            return
        }

        let supportedNetworksLowerCase = supportedNetworks.map { $0.lowercased() }
        let networks = supportedNetworksLowerCase.map { networkString in
            switch networkString {
            case "visa":
                return PKPaymentNetwork.visa
            case "mastercard":
                return PKPaymentNetwork.masterCard
            case "amex":
                return PKPaymentNetwork.amex
            default:
                return nil
            }
        }.compactMap { $0 }

        let capabilities = merchantCapabilities.map { capabilityString in
            switch capabilityString {
            case "3DS":
                return PKMerchantCapability.capability3DS
            case "CREDIT_CARD":
                return PKMerchantCapability.capabilityCredit
            case "DEBIT_CARD":
                return PKMerchantCapability.capabilityDebit
            default:
                return nil
            }
        }.reduce([], { $0.union([$1]) })

        let canMakePayments = PKPaymentAuthorizationViewController.canMakePayments(usingNetworks: networks, capabilities: capabilities)
        
        let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: ["canMakePayments": canMakePayments])
        commandDelegate.send(result, callbackId: callbackID)
    }

    @objc(requestPayment:) func requestPayment(command: CDVInvokedUrlCommand) {
        self.paymentCallbackId = command.callbackId

        do {
            guard let args = command.arguments[0] as? [String: Any] else {
                throw ValidationError.missingArgument("Invalid arguments")
            }

            let countryCode = try getFromRequest(fromArguments: args, key: "countryCode") as! String
            let currencyCode = try getFromRequest(fromArguments: args, key: "currencyCode") as! String
            let merchantId = try getFromRequest(fromArguments: args, key: "merchantIdentifier") as! String
            let supportedNetworks = try getFromRequest(fromArguments: args, key: "supportedNetworks") as! [String]
            let merchantCapabilities = try getFromRequest(fromArguments: args, key: "merchantCapabilities") as! [String]
            let paymentSummaryItems = try getFromRequest(fromArguments: args, key: "paymentSummaryItems") as! [[String: Any]]

            let request = PKPaymentRequest()
            request.merchantIdentifier = merchantId
            request.supportedNetworks = supportedNetworks.map { PKPaymentNetwork(rawValue: $0.lowercased()) }
            request.merchantCapabilities = merchantCapabilities.map { PKMerchantCapability(rawValue: UInt($0) ?? 0) }.reduce([], { $0.union($1) })
            request.countryCode = countryCode
            request.currencyCode = currencyCode
            request.paymentSummaryItems = paymentSummaryItems.map { item in
                PKPaymentSummaryItem(label: item["label"] as! String, amount: NSDecimalNumber(string: item["amount"] as? String))
            }

            if let vc = PKPaymentAuthorizationViewController(paymentRequest: request) {
                vc.delegate = self
                viewController.present(vc, animated: true, completion: nil)
            } else {
                throw ValidationError.missingArgument("Unable to present Apple Pay authorization view controller")
            }
        } catch ValidationError.missingArgument(let message) {
            failWithError(message)
        } catch {
            failWithError(error.localizedDescription)
        }
    }

    private func failWithError(_ error: String) {
        let result = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: error)
        commandDelegate.send(result, callbackId: paymentCallbackId)
    }

    private func getFromRequest(fromArguments arguments: [String: Any], key: String) throws -> Any {
        if let val = arguments[key] {
            return val
        } else {
            throw ValidationError.missingArgument("\(key) is required")
        }
    }

    func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController, didAuthorizePayment payment: PKPayment, handler completion: @escaping (PKPaymentAuthorizationResult) -> Void) {
        completion(PKPaymentAuthorizationResult(status: .success, errors: nil))
        successfulPayment = true

        let paymentDataString = String(data: payment.token.paymentData, encoding: .utf8) ?? ""
        let networkString: String = {
          switch paymentMethod.network {
          case .visa:
              return "VISA"
          case .masterCard:
              return "MASTERCARD"
          case .amex:
              return"AMEX"
          default:
              return "UNKNOWN"
          }
        }()
        let paymentMethodTypeString: String = {
            switch payment.token.paymentMethod.type {
            case .debit:
                return "debit"
            case .credit:
                return "credit"
            case .store:
                return "store"
            case .prepaid:
                return "prepaid"
            default:
                return "unknown"
            }
        }()
        let paymentMethod: [String: Any] = [
            "displayName": payment.token.paymentMethod.displayName ?? "",
            "network": payment.token.paymentMethod.network?.rawValue ?? "",
            "type": paymentMethodTypeString
        ]

        paymentResult = [
            "transactionIdentifier": payment.token.transactionIdentifier,
            "paymentData": paymentDataString,
            "paymentMethod": paymentMethod
        ]
    }

    func paymentAuthorizationViewControllerDidFinish(_ controller: PKPaymentAuthorizationViewController) {
        if successfulPayment {
            if let paymentResult = paymentResult, let data = try? JSONSerialization.data(withJSONObject: paymentResult, options: []), let jsonString = String(data: data, encoding: .utf8) {
                let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: jsonString)
                commandDelegate.send(result, callbackId: paymentCallbackId)
            } else {
                failWithError("Failed to parse payment result")
            }
        } else {
            let result = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: "Payment cancelled")
            commandDelegate.send(result, callbackId: paymentCallbackId)
        }

        successfulPayment = false
        controller.dismiss(animated: true, completion: nil)
    }
}

enum ValidationError: Error {
    case missingArgument(String)
}
