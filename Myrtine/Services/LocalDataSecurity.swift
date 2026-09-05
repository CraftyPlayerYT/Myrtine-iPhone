import Foundation

enum LocalDataSecurity {
    private static let protection = FileProtectionType.completeUntilFirstUserAuthentication

    static func prepareProtectedStorage() throws {
        let directory = try applicationSupportDirectory()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: protection]
        )
        try protectItem(at: directory)
        try protectExistingFiles(in: directory)
    }

    static func sealExistingStoreFiles() throws {
        let directory = try applicationSupportDirectory()
        try protectExistingFiles(in: directory)
    }

    private static func applicationSupportDirectory() throws -> URL {
        guard let directory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw CocoaError(.fileNoSuchFile)
        }
        return directory
    }

    private static func protectExistingFiles(in directory: URL) throws {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        for case let url as URL in enumerator {
            try protectItem(at: url)
        }
    }

    private static func protectItem(at url: URL) throws {
        try FileManager.default.setAttributes(
            [.protectionKey: protection],
            ofItemAtPath: url.path
        )
    }
}
