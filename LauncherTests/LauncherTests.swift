//
//  LauncherTests.swift
//  LauncherTests
//
//  Created by Pierre Pagnoux on 22/06/2025.
//

import XCTest
@testable import Launcher

final class LauncherTests: XCTestCase {
    
    // MARK: - Test Data
    
    let testApps = [
        AppInfo(name: "Cursor", path: "/Applications/Cursor.app", icon: NSImage()),
        AppInfo(name: "Cider", path: "/Applications/Cider.app", icon: NSImage()),
        AppInfo(name: "1Password", path: "/Applications/1Password.app", icon: NSImage()),
        AppInfo(name: "Calculator", path: "/Applications/Calculator.app", icon: NSImage()),
        AppInfo(name: "Calendar", path: "/Applications/Calendar.app", icon: NSImage()),
        AppInfo(name: "Chrome", path: "/Applications/Chrome.app", icon: NSImage()),
        AppInfo(name: "Safari", path: "/Applications/Safari.app", icon: NSImage()),
        AppInfo(name: "Spotify", path: "/Applications/Spotify.app", icon: NSImage()),
        AppInfo(name: "System Preferences", path: "/Applications/System Preferences.app", icon: NSImage()),
        AppInfo(name: "Terminal", path: "/Applications/Terminal.app", icon: NSImage()),
        AppInfo(name: "App Store", path: "/Applications/App Store.app", icon: NSImage()),
        AppInfo(name: "AppCleaner", path: "/Applications/AppCleaner.app", icon: NSImage())
    ]
    
    // MARK: - Search Logic Tests (Using real implementation)
    
    func testEmptySearchReturnsAllApps() {
        let result = ApplicationLoader.filterApplications(testApps, searchText: "")
        XCTAssertEqual(result.count, testApps.count, "Empty search should return all apps")
    }
    
    func testExactMatchPrioritization() {
        let result = ApplicationLoader.filterApplications(testApps, searchText: "Safari")
        XCTAssertEqual(result.count, 1, "Should find exactly one Safari")
        XCTAssertEqual(result[0].name, "Safari", "Should find Safari")
    }
    
    func testPrefixMatchingExactMatch() {
        let result = ApplicationLoader.filterApplications(testApps, searchText: "Saf")
        XCTAssertEqual(result.count, 1, "Should find Safari with prefix 'Saf'")
        XCTAssertEqual(result[0].name, "Safari", "Should find Safari")
    }
    
    func testPrefixMatchingMultipleResults() {
        let result = ApplicationLoader.filterApplications(testApps, searchText: "C")
        XCTAssertGreaterThan(result.count, 1, "Should find multiple apps starting with 'C'")
        XCTAssertTrue(result.contains { $0.name == "Calculator" }, "Should find Calculator")
        XCTAssertTrue(result.contains { $0.name == "Calendar" }, "Should find Calendar")
        XCTAssertTrue(result.contains { $0.name == "Chrome" }, "Should find Chrome")
        XCTAssertTrue(result.contains { $0.name == "Cider" }, "Should find Cider")
        XCTAssertTrue(result.contains { $0.name == "Cursor" }, "Should find Cursor")
    }
    
    func testCaseInsensitiveSearch() {
        let result = ApplicationLoader.filterApplications(testApps, searchText: "safari")
        XCTAssertEqual(result.count, 1, "Should find Safari with lowercase")
        XCTAssertEqual(result[0].name, "Safari", "Should find Safari")
    }
    
    func testNoSubstringMatching() {
        let result = ApplicationLoader.filterApplications(testApps, searchText: "ari")
        XCTAssertEqual(result.count, 0, "Should not find Safari with substring 'ari'")
    }
    
    func testWhitespaceTrimming() {
        let result = ApplicationLoader.filterApplications(testApps, searchText: "  Safari  ")
        XCTAssertEqual(result.count, 1, "Should find Safari with whitespace")
        XCTAssertEqual(result[0].name, "Safari", "Should find Safari")
    }
    
    func testSpecialCharactersInSearch() {
        let result = ApplicationLoader.filterApplications(testApps, searchText: "1Password")
        XCTAssertEqual(result.count, 1, "Should find 1Password")
        XCTAssertEqual(result[0].name, "1Password", "Should find 1Password")
    }
    
    func testMultiWordSearch() {
        let result = ApplicationLoader.filterApplications(testApps, searchText: "App Store")
        XCTAssertEqual(result.count, 1, "Should find App Store")
        XCTAssertEqual(result[0].name, "App Store", "Should find App Store")
    }
    
    func testPartialWordSearch() {
        let result = ApplicationLoader.filterApplications(testApps, searchText: "App")
        XCTAssertGreaterThan(result.count, 0, "Should find apps starting with 'App'")
        XCTAssertTrue(result.contains { $0.name == "App Store" }, "Should find App Store")
        XCTAssertTrue(result.contains { $0.name == "AppCleaner" }, "Should find AppCleaner")
    }
    
    func testVeryShortQuery() {
        let result = ApplicationLoader.filterApplications(testApps, searchText: "A")
        XCTAssertGreaterThan(result.count, 0, "Should find apps starting with 'A'")
    }
    
    func testLongQueryNoMatch() {
        let result = ApplicationLoader.filterApplications(testApps, searchText: "SafariBrowser")
        XCTAssertEqual(result.count, 0, "Should not find SafariBrowser")
    }
    
    func testNoResults() {
        let result = ApplicationLoader.filterApplications(testApps, searchText: "XYZ")
        XCTAssertEqual(result.count, 0, "Should find no results for XYZ")
    }
    
    func testNoMatchesReturnsEmptyArray() {
        let result = ApplicationLoader.filterApplications(testApps, searchText: "NonExistentApp")
        XCTAssertEqual(result.count, 0, "Should return empty array for non-existent app")
    }
    
    func testOrderStability() {
        let result1 = ApplicationLoader.filterApplications(testApps, searchText: "C")
        let result2 = ApplicationLoader.filterApplications(testApps, searchText: "C")
        XCTAssertEqual(result1.map { $0.name }, result2.map { $0.name }, "Results should be stable")
    }
    
    func testAppPrefixOrderConsistency() {
        let result = ApplicationLoader.filterApplications(testApps, searchText: "App")
        let appNames = result.map { $0.name }
        XCTAssertTrue(appNames.contains("App Store"), "Should find App Store")
        XCTAssertTrue(appNames.contains("AppCleaner"), "Should find AppCleaner")
    }
    
    func testSafariMatching() {
        let result = ApplicationLoader.filterApplications(testApps, searchText: "Safari")
        XCTAssertEqual(result.count, 1, "Should find Safari")
        XCTAssertEqual(result[0].name, "Safari", "Should find Safari")
    }
    
    func testSafariLowerCaseMatching() {
        let result = ApplicationLoader.filterApplications(testApps, searchText: "safari")
        XCTAssertEqual(result.count, 1, "Should find Safari with lowercase")
        XCTAssertEqual(result[0].name, "Safari", "Should find Safari")
    }
    
    func testAppCleanerExactMatching() {
        let result = ApplicationLoader.filterApplications(testApps, searchText: "AppCleaner")
        XCTAssertEqual(result.count, 1, "Should find AppCleaner")
        XCTAssertEqual(result[0].name, "AppCleaner", "Should find AppCleaner")
    }
    
    func testAppCleanerLowerCaseMatching() {
        let result = ApplicationLoader.filterApplications(testApps, searchText: "appcleaner")
        XCTAssertEqual(result.count, 1, "Should find AppCleaner with lowercase")
        XCTAssertEqual(result[0].name, "AppCleaner", "Should find AppCleaner")
    }
    
    func testAppStoreExactMatching() {
        let result = ApplicationLoader.filterApplications(testApps, searchText: "App Store")
        XCTAssertEqual(result.count, 1, "Should find App Store")
        XCTAssertEqual(result[0].name, "App Store", "Should find App Store")
    }
    
    func testAppStoreLowerCaseMatching() {
        let result = ApplicationLoader.filterApplications(testApps, searchText: "app store")
        XCTAssertEqual(result.count, 1, "Should find App Store with lowercase")
        XCTAssertEqual(result[0].name, "App Store", "Should find App Store")
    }
    
    func testCaseInsensitivity() {
        let result = ApplicationLoader.filterApplications(testApps, searchText: "CALCULATOR")
        XCTAssertEqual(result.count, 1, "Should find Calculator with uppercase")
        XCTAssertEqual(result[0].name, "Calculator", "Should find Calculator")
    }
    
    func testSpecialCharacterAndNumberHandling() {
        let result = ApplicationLoader.filterApplications(testApps, searchText: "1Password")
        XCTAssertEqual(result.count, 1, "Should find 1Password")
        XCTAssertEqual(result[0].name, "1Password", "Should find 1Password")
    }
    
    func testAlphabeticalOrdering() {
        let searchText = "C"
        let result = ApplicationLoader.filterApplications(testApps, searchText: searchText)
        let expectedOrder = ["Calculator", "Calendar", "Chrome", "Cider", "Cursor"]
        XCTAssertEqual(result.map { $0.name }, expectedOrder, "Results should be in the expected order for prefix 'C'")
    }
    
    // MARK: - ApplicationLoader Tests
    
    func testApplicationLoaderLoadsApplications() {
        let apps = ApplicationLoader.loadApplications()
        
        // Should find some applications
        XCTAssertGreaterThan(apps.count, 0, "Should load at least some applications")
        
        // Should contain at least one common system app
        let appNames = apps.map { $0.name }
        let commonApps = ["Safari", "Calculator", "Mail", "Messages", "Calendar", "Photos", "Music", "App Store"]
        let foundCommonApps = commonApps.filter { appNames.contains($0) }
        XCTAssertGreaterThan(foundCommonApps.count, 0, "Should find at least one common system app. Found: \(foundCommonApps)")
        
        // Apps should be sorted alphabetically
        for i in 0..<(apps.count - 1) {
            let current = apps[i].name.lowercased()
            let next = apps[i + 1].name.lowercased()
            XCTAssertLessThanOrEqual(current, next, 
                                   "Apps should be sorted alphabetically: '\(apps[i].name)' should come before '\(apps[i + 1].name)'")
        }
    }
    
    func testApplicationLoaderFiltersCorrectly() {
        let testApps = [
            AppInfo(name: "Safari", path: "/Applications/Safari.app", icon: NSImage()),
            AppInfo(name: "Calculator", path: "/Applications/Calculator.app", icon: NSImage()),
            AppInfo(name: "Mail", path: "/Applications/Mail.app", icon: NSImage())
        ]
        
        // Test exact match
        let safariResults = ApplicationLoader.filterApplications(testApps, searchText: "Safari")
        XCTAssertEqual(safariResults.count, 1, "Should find exactly one Safari")
        XCTAssertEqual(safariResults[0].name, "Safari", "Should find Safari")
        
        // Test prefix match
        let calcResults = ApplicationLoader.filterApplications(testApps, searchText: "Calc")
        XCTAssertEqual(calcResults.count, 1, "Should find exactly one Calculator")
        XCTAssertEqual(calcResults[0].name, "Calculator", "Should find Calculator")
        
        // Test no match
        let noResults = ApplicationLoader.filterApplications(testApps, searchText: "XYZ")
        XCTAssertEqual(noResults.count, 0, "Should find no results for XYZ")
    }
    
    func testApplicationLoaderMaintainsOrder() {
        let testApps = [
            AppInfo(name: "Calculator", path: "/Applications/Calculator.app", icon: NSImage()),
            AppInfo(name: "Calendar", path: "/Applications/Calendar.app", icon: NSImage()),
            AppInfo(name: "Safari", path: "/Applications/Safari.app", icon: NSImage()),
            AppInfo(name: "Mail", path: "/Applications/Mail.app", icon: NSImage())
        ]
        let results = ApplicationLoader.filterApplications(testApps, searchText: "C")
        let expectedOrder = ["Calculator", "Calendar"]
        XCTAssertEqual(results.map { $0.name }, expectedOrder, "Results should be in the expected order for prefix 'C'")
    }
}
