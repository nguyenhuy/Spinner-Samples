/*
	Copyright (C) 2016 Apple Inc. All Rights Reserved.
	See LICENSE.txt for this sample’s licensing information
	
	Abstract:
	This file contains the FilterUtilities class. FilterUtilities objects contain functions and data that is used by both the SimpleTunnel UI and the SimpleTunnel content filter providers.
*/

import Foundation
import NetworkExtension

/// Content Filter actions.
public enum FilterRuleAction : Int, CustomStringConvertible {
	case block = 1
	case allow = 2
	case needMoreRulesAndBlock = 3
	case needMoreRulesAndAllow = 4
	case needMoreRulesFromDataAndBlock = 5
	case needMoreRulesFromDataAndAllow = 6
	case examineData = 7
	case redirectToSafeURL = 8
	case remediate = 9

	public var description: String {
		switch self {
		case .block: return "Block"
		case .examineData: return "Examine Data"
		case .needMoreRulesAndAllow: return "Ask for more rules, then allow"
		case .needMoreRulesAndBlock: return "Ask for more rules, then block"
		case .needMoreRulesFromDataAndAllow: return "Ask for more rules, examine data, then allow"
		case .needMoreRulesFromDataAndBlock: return "Ask for more rules, examine data, then block"
		case .redirectToSafeURL: return "Redirect"
		case .remediate: return "Remediate"
		case .allow: return "Allow"
		}
	}
}

/// A class containing utility properties and functions for Content Filtering.
open class FilterUtilities {

    public static let defaultRules: [String: [String: AnyObject]] = [
        "*.reddit.com" : [
            "kRule" : FilterRuleAction.block.rawValue as AnyObject,
            "kRemediationKey" : "Remediate1" as AnyObject
        ]
    ]

	// MARK: Properties

	/// A reference to the SimpleTunnel user defaults.
    public static let defaults = UserDefaults(
        suiteName: "groups.dev.huynguyen.apple-samplecode.SimpleTunnel"
    )

	// MARK: Initializers

	/// Get rule parameters for a flow from the SimpleTunnel user defaults.
	open class func getRule(_ flow: NEFilterFlow) -> (FilterRuleAction, String, [String: AnyObject]) {
		let hostname = FilterUtilities.getFlowHostname(flow)
        
        let appIdentifier = flow.sourceAppIdentifier ?? ""
        simpleTunnelLog("get rule for \(appIdentifier)")
        if (appIdentifier.contains("reddit")) {
//            Thread.sleep(forTimeInterval: 10)
            return (.block, hostname, [:])
        }

		guard !hostname.isEmpty else { return (.allow, hostname, [:]) }

		guard let hostNameRule = (defaults?.object(forKey: "rules") as AnyObject).object(forKey: hostname) as? [String: AnyObject] else {
			simpleTunnelLog("\(hostname) is set for NO RULES")
			return (.allow, hostname, [:])
		}

		guard let ruleTypeInt = hostNameRule["kRule"] as? Int,
			let ruleType = FilterRuleAction(rawValue: ruleTypeInt)
			else { return (.allow, hostname, [:]) }

		return (ruleType, hostname, hostNameRule)
	}

	/// Get the hostname from a browser flow.
	open class func getFlowHostname(_ flow: NEFilterFlow) -> String {
		guard let browserFlow : NEFilterBrowserFlow = flow as? NEFilterBrowserFlow,
			let url = browserFlow.url,
			let hostname = url.host
			else { return "" }
		return hostname
	}

	/// Download a fresh set of rules from the rules server.
	open class func fetchRulesFromServer(_ serverAddress: String?) {
		simpleTunnelLog("fetch rules called")

		guard serverAddress != nil else { return }
		simpleTunnelLog("Fetching rules from \(serverAddress)")

		guard let infoURL = URL(string: "http://\(serverAddress!)/rules/") else {
            defaults?.setValue(defaultRules, forKey:"rules")
            return
        }
		simpleTunnelLog("Rules url is \(infoURL)")

		let content: String
		do {
			content = try String(contentsOf: infoURL, encoding: String.Encoding.utf8)
		}
		catch {
			simpleTunnelLog("Failed to fetch the rules from \(infoURL)")
			return
		}

		let contentArray = content.components(separatedBy: "<br/>")
		simpleTunnelLog("Content array is \(contentArray)")
		var urlRules = [String: [String: AnyObject]]()

		for rule in contentArray {
			if rule.isEmpty {
				continue
			}
			let ruleArray = rule.components(separatedBy: " ")

			guard !ruleArray.isEmpty else { continue }

			var redirectKey = "SafeYes"
			var remediateKey = "Remediate1"
			var remediateButtonKey = "RemediateButton1"
			var actionString = "9"

			let urlString = ruleArray[0]
			let ruleArrayCount = ruleArray.count

			if ruleArrayCount > 1 {
				actionString = ruleArray[1]
			}
			if ruleArrayCount > 2 {
				redirectKey = ruleArray[2]
			}
			if ruleArrayCount > 3 {
				remediateKey = ruleArray[3]
			}
			if ruleArrayCount > 4 {
				remediateButtonKey = ruleArray[4]
			}


			urlRules[urlString] = [
				"kRule" : actionString as AnyObject,
				"kRedirectKey" : redirectKey as AnyObject,
				"kRemediateKey" : remediateKey as AnyObject,
				"kRemediateButtonKey" : remediateButtonKey as AnyObject,
			]
		}
		defaults?.setValue(urlRules, forKey:"rules")
	}
}
