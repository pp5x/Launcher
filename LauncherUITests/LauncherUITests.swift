//
//  LauncherUITests.swift
//  LauncherUITests
//
//  Created by Pierre Pagnoux on 22/06/2025.
//

import XCTest

final class LauncherUITests: XCTestCase {

    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        
        // Wait for app to be ready
        Thread.sleep(forTimeInterval: 2.0)
        
        // Make the window visible for testing by activating the app
        app.activate()
        
        // Wait for the window to appear
        Thread.sleep(forTimeInterval: 1.0)
    }

    override func tearDownWithError() throws {
        // Clean up after each test
    }
    
    // MARK: - Helper Methods
    
    private func waitForLauncherToAppear() {
        // Since we can't reliably trigger global hotkeys, we'll test the UI elements directly
        // The app should show the search field when it becomes active
        let searchField = app.textFields["Search applications..."]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5.0), "Search field should appear")
    }
    
    private func clearSearchField() {
        let searchField = app.textFields["Search applications..."]
        searchField.tap()
        // Try to tap the clear button if it exists
        let clearButton = searchField.buttons["Clear text"]
        if clearButton.exists {
            clearButton.tap()
        } else {
            // Fallback: select all and delete
            searchField.typeKey("a", modifierFlags: .command)
            searchField.typeKey(XCUIKeyboardKey.delete.rawValue, modifierFlags: [])
        }
    }
    
    private func searchForApp(_ query: String) -> [String] {
        let searchField = app.textFields["Search applications..."]
        searchField.tap()
        searchField.typeText(query)
        
        // Wait for search results
        Thread.sleep(forTimeInterval: 1.0)
        
        // Get all visible app names from static texts
        let appElements = app.staticTexts.allElementsBoundByIndex
            .filter { $0.label.count > 0 && $0.label != "Search applications..." }
        
        let appNames = appElements.map { $0.label }
        
        // Verify that each app name corresponds to a real application
        for appName in appNames {
            // Check if the app exists in common application directories
            let appDirectories = ["/Applications", "/System/Applications", "/Applications/Utilities"]
            var appFound = false
            var appPath = ""
            
            for directory in appDirectories {
                let potentialPath = "\(directory)/\(appName).app"
                if FileManager.default.fileExists(atPath: potentialPath) {
                    appFound = true
                    appPath = potentialPath
                    print("[UI TEST] Verified app '\(appName)' exists at: \(appPath)")
                    
                    // Verify the app has proper structure (Info.plist, executable)
                    let infoPlistPath = "\(potentialPath)/Contents/Info.plist"
                    let executablePath = "\(potentialPath)/Contents/MacOS"
                    
                    XCTAssertTrue(FileManager.default.fileExists(atPath: infoPlistPath), 
                                "App '\(appName)' should have Info.plist at: \(infoPlistPath)")
                    
                    // Check if there's at least one executable in MacOS directory
                    do {
                        let executableFiles = try FileManager.default.contentsOfDirectory(atPath: executablePath)
                        XCTAssertFalse(executableFiles.isEmpty, 
                                     "App '\(appName)' should have executable files in: \(executablePath)")
                        print("[UI TEST] App '\(appName)' has \(executableFiles.count) executable(s)")
                    } catch {
                        XCTFail("Failed to check executables for app '\(appName)': \(error)")
                    }
                    
                    break
                }
            }
            
            XCTAssertTrue(appFound, "App '\(appName)' should exist in the filesystem")
        }
        print("[UI TEST] Search for '\(query)' returned: \(appNames)")
        return appNames
    }
    
    private func verifySearchResults(_ query: String, expectedApps: [String]) {
        let results = searchForApp(query)
        XCTAssertEqual(results, expectedApps, "Search for '\(query)' should return apps in the correct order: \(expectedApps)")
    }
    
    // MARK: - Basic Functionality Tests
    
    func testAppLaunch() {
        let searchField = app.textFields["Search applications..."]
        XCTAssertTrue(searchField.exists, "Search field should exist after app launch")
    }
    
    func testSearchFieldFocus() {
        let searchField = app.textFields["Search applications..."]
        searchField.tap()
        XCTAssertTrue(searchField.exists, "Search field should exist after tapping")
    }
    
    func testEmptySearchShowsAllApps() {
        clearSearchField()
        let results = searchForApp("")
        XCTAssertGreaterThan(results.count, 20, "Empty search should show many apps")
    }
    
    // MARK: - Specific App Search Tests
    
    // MARK: - Test Data
    
    private struct SearchTestCase {
        let query: String
        let expectedApps: [String]
        let description: String
    }
    
    private let searchTestCases: [SearchTestCase] = [
        SearchTestCase(query: "Safari", expectedApps: ["Safari"], description: "exact match"),
        SearchTestCase(query: "Saf", expectedApps: ["Safari"], description: "prefix match"),
        SearchTestCase(query: "safari", expectedApps: ["Safari"], description: "case insensitive"),
        SearchTestCase(query: "Cursor", expectedApps: ["Cursor"], description: "exact match"),
        SearchTestCase(query: "Cur", expectedApps: ["Cursor"], description: "prefix match"),
        SearchTestCase(query: "Fi", expectedApps: ["Finder", "Find My", "Firefox"], description: "prefix match"),
        SearchTestCase(query: "Fir", expectedApps: ["Firefox"], description: "prefix match"),
        SearchTestCase(query: "Logseq", expectedApps: ["Logseq"], description: "exact match"),
        SearchTestCase(query: "Log", expectedApps: ["Logseq", "LogiPluginService", "logioptionsplus"], description: "prefix match"),
        SearchTestCase(query: "Mail", expectedApps: ["Mail"], description: "exact match"),
        SearchTestCase(query: "Messages", expectedApps: ["Messages"], description: "exact match"),
        SearchTestCase(query: "Photos", expectedApps: ["Photos"], description: "exact match"),
        SearchTestCase(query: "Music", expectedApps: ["Music"], description: "exact match"),
        SearchTestCase(query: "TV", expectedApps: ["TV"], description: "exact match"),
        SearchTestCase(query: "App Store", expectedApps: ["App Store"], description: "exact match")
    ]
    
    // MARK: - Parameterized Tests
    
    func testSearchForApps() {
        for testCase in searchTestCases {
            verifySearchResults(testCase.query, expectedApps: testCase.expectedApps)
        }
    }
    
    // MARK: - Prefix Matching Tests
    
    func testPrefixMatchingForS() {
        let results = searchForApp("S")
        let expectedApps = ["Safari", "Shortcuts", "Shut Up", "Signal", "Siri", "SponsorBlock", "Stickies", "Stocks", "System Settings"]
        XCTAssertEqual(results, expectedApps, "Search for 'S' should return apps in the correct order")
    }
    
    func testPrefixMatchingForC() {
        let results = searchForApp("C")
        let expectedApps = ["Calculator", "Calendar", "Chess", "Clock", "Contacts", "Cursor"]
        XCTAssertEqual(results, expectedApps, "Search for 'C' should return apps in the correct order")
    }

    func testPrefixMatchingForCa() {
        let results = searchForApp("Ca")
        let expectedApps = ["Calculator", "Calendar"]
        XCTAssertEqual(results, expectedApps, "Search for 'Ca' should return apps in the correct order")
    }
    
    func testPrefixMatchingForL() {
        let results = searchForApp("L")
        let expectedApps = ["Launchpad", "logioptionsplus", "LogiPluginService", "Logseq"]
        XCTAssertEqual(results, expectedApps, "Search for 'L' should return apps in the correct order")
    }

    func testPrefixMatchingForLogi() {
        let results = searchForApp("Logi")
        let expectedApps = ["logioptionsplus", "LogiPluginService"]
        XCTAssertEqual(results, expectedApps, "Search for 'Logi' should return apps in the correct order")
    }
    
    // MARK: - Edge Cases
    
    func testNoResultsForInvalidSearch() {
        let results = searchForApp("XYZ123")
        XCTAssertEqual(results.count, 0, "Invalid search should return no results")
    }
    
    func testWhitespaceHandling() {
        verifySearchResults("  Safari  ", expectedApps: ["Safari"])
    }
    
    func testCaseInsensitiveSearch() {
        verifySearchResults("safari", expectedApps: ["Safari"])
        verifySearchResults("SAFARI", expectedApps: ["Safari"])
        verifySearchResults("SafArI", expectedApps: ["Safari"])
    }
    
    // MARK: - Performance Tests
    
    func testSearchPerformance() {
        measure {
            _ = searchForApp("Safari")
        }
    }
    
    func testLaunchPerformance() {
        measure {
            app.launch()
            let searchField = app.textFields["Search applications..."]
            XCTAssertTrue(searchField.waitForExistence(timeout: 5.0))
        }
    }

    func testOrderOfPrefixResults() {
        let query = "App"
        let expectedOrder = ["AppCleaner", "App Store"] // Adjust if your UI shows a different order
        verifySearchResults(query, expectedApps: expectedOrder)
    }

    func testWindowShowsImmediately() {
        // This test should fail if the window doesn't show up immediately
        // and the search field is not accessible
        let searchField = app.textFields["Search applications..."]
        
        // The search field should be accessible immediately after app launch
        XCTAssertTrue(searchField.exists, "Search field should exist and be accessible")
        XCTAssertTrue(searchField.isEnabled, "Search field should be enabled")
        
        // The search field should be hittable (can be tapped)
        XCTAssertTrue(searchField.isHittable, "Search field should be hittable")
    }
    
    func testCanTypeInSearchField() {
        let searchField = app.textFields["Search applications..."]
        
        // Should be able to type in the search field
        searchField.tap()
        searchField.typeText("Test")
        
        // Verify the text was entered
        XCTAssertEqual(searchField.value as? String, "Test", "Should be able to type in search field")
    }
}
